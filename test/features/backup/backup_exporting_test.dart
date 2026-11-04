/// "Make a backup and hand it to the share sheet", proved once for the two screens
/// that offer it.
///
/// Settings' "Export a copy" and Backup & Restore's "Create backup" each had their
/// own copy of the whole flow — ask for a passphrase, make the file, share it, say
/// one of three things — and the copies had already drifted: neither guarded the row
/// while the passphrase sheet was up, so a second tap in the same frame opened a
/// second sheet. Both now use [BackupExporting]; the screens' own tests cover what
/// they say and show, this covers the order of events.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart' show AppTextField;
import 'package:tablet_remainder/features/backup/presentation/backup_exporting.dart';
import 'package:tablet_remainder/features/backup/services/backup_service.dart';

class _FakeBackup implements BackupService {
  final created = <String?>[];
  final shared = <File>[];
  File? file = File('/tmp/backup');
  Object? createError;
  Completer<void>? createGate;

  @override
  int get encryptionIterations => 1;

  @override
  Future<Uint8List> buildBackupBytes({String? passphrase}) async => Uint8List(0);

  @override
  Future<File?> createBackup({String? passphrase}) async {
    created.add(passphrase);
    if (createGate != null) await createGate!.future;
    if (createError != null) throw createError!;
    return file;
  }

  @override
  Future<void> shareBackup(File file) async => shared.add(file);

  @override
  Future<bool> restoreBackup({AskBackupPassphrase? askPassphrase}) async => false;

  @override
  Future<bool> restoreFromBytes(Uint8List bytes, {AskBackupPassphrase? askPassphrase}) async =>
      false;
}

class _Host extends StatefulWidget {
  const _Host({super.key, required this.service});

  final BackupService service;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with BackupExporting<_Host> {
  bool busy = false;
  final said = <(String, bool)>[];
  int started = 0;

  @override
  BackupService get exportService => widget.service;

  @override
  bool get exportBusy => busy;

  @override
  void setExportBusy(bool b) => setState(() => busy = b);

  @override
  void reportExport(String message, {required bool isError}) => said.add((message, isError));

  @override
  String get exportFailureLead => 'Lead';

  @override
  void exportStarted() => started++;

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late _FakeBackup fake;

  setUp(() => fake = _FakeBackup());

  Future<_HostState> mount(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(430, 1600);
    addTearDown(tester.view.reset);
    final key = GlobalKey<State<_Host>>();
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: _Host(key: key, service: fake),
    ));
    await tester.pump();
    return key.currentState! as _HostState;
  }

  Future<void> pumpFor(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> choosePassphrase(WidgetTester tester, String passphrase) async {
    await tester.enterText(find.widgetWithText(AppTextField, 'Passphrase'), passphrase);
    await tester.enterText(find.widgetWithText(AppTextField, 'Type it again'), passphrase);
    await tester.tap(find.text('Create encrypted backup'));
    await pumpFor(tester);
  }

  testWidgets('plain: made, shared, said — with no question', (tester) async {
    final host = await mount(tester);

    unawaited(host.exportBackup());
    await pumpFor(tester);

    expect(fake.created, [null]);
    expect(fake.shared, hasLength(1));
    expect(host.said, [('Backup ready to share.', false)]);
    expect(host.started, 1);
    expect(host.busy, isFalse, reason: 'and the screen is free again');
    expect(find.text('Protect this backup'), findsNothing);
  });

  testWidgets('encrypted: asks first, and nothing is made until it is chosen', (tester) async {
    final host = await mount(tester);

    unawaited(host.exportBackup(encrypted: true));
    await pumpFor(tester);
    expect(find.text('Protect this backup'), findsOneWidget);
    expect(fake.created, isEmpty);
    expect(host.started, 0);

    await choosePassphrase(tester, 'correct horse 42');

    expect(fake.created, ['correct horse 42']);
    expect(fake.shared, hasLength(1));
    expect(host.said.single.$1, contains('Encrypted backup ready to share'));
    expect(host.said.single.$1, contains('Keep the passphrase safe'));
    expect(host.said.single.$2, isFalse);
  });

  testWidgets('two taps in the same frame open ONE passphrase sheet', (tester) async {
    final host = await mount(tester);

    unawaited(host.exportBackup(encrypted: true));
    unawaited(host.exportBackup(encrypted: true));
    await pumpFor(tester);

    expect(find.text('Protect this backup'), findsOneWidget,
        reason: 'the busy flag is only set once a passphrase is chosen, so the row used '
            'to be live for as long as the sheet was up');
    await tester.tap(find.text('Cancel'));
    await pumpFor(tester);
    expect(find.text('Protect this backup'), findsNothing,
        reason: 'and nothing is hiding behind it');
  });

  testWidgets('and once the sheet is closed the row works again', (tester) async {
    final host = await mount(tester);
    unawaited(host.exportBackup(encrypted: true));
    await pumpFor(tester);
    await tester.tap(find.text('Cancel'));
    await pumpFor(tester);

    unawaited(host.exportBackup());
    await pumpFor(tester);

    expect(fake.created, [null]);
  });

  testWidgets('backing out of the passphrase makes and shares nothing, and says nothing',
      (tester) async {
    final host = await mount(tester);

    unawaited(host.exportBackup(encrypted: true));
    await pumpFor(tester);
    await tester.tap(find.text('Cancel'));
    await pumpFor(tester);

    expect(fake.created, isEmpty);
    expect(fake.shared, isEmpty);
    expect(host.said, isEmpty);
    expect(host.started, 0);
    expect(host.busy, isFalse);
  });

  testWidgets('a file that could not be made is said, as an error, and nothing is shared',
      (tester) async {
    fake.file = null;
    final host = await mount(tester);

    unawaited(host.exportBackup());
    await pumpFor(tester);

    expect(host.said, [('Could not create the backup file.', true)]);
    expect(fake.shared, isEmpty);
    expect(host.busy, isFalse);
  });

  testWidgets('a failure starts with the screen\'s own words, and frees the screen',
      (tester) async {
    fake.createError = StateError('disk full');
    final host = await mount(tester);

    unawaited(host.exportBackup());
    await pumpFor(tester);

    expect(host.said.single.$1, startsWith('Lead: '));
    expect(host.said.single.$1, contains('disk full'));
    expect(host.said.single.$2, isTrue);
    expect(host.busy, isFalse);
  });

  testWidgets('busy with something else: nothing happens', (tester) async {
    final host = await mount(tester);
    host.busy = true;

    unawaited(host.exportBackup());
    unawaited(host.exportBackup(encrypted: true));
    await pumpFor(tester);

    expect(fake.created, isEmpty);
    expect(find.text('Protect this backup'), findsNothing);
    expect(host.said, isEmpty);
  });

  testWidgets('while it is being made, the screen is busy, and a second call is ignored',
      (tester) async {
    fake.createGate = Completer<void>();
    final host = await mount(tester);

    unawaited(host.exportBackup());
    await tester.pump();
    expect(host.busy, isTrue);

    unawaited(host.exportBackup());
    await tester.pump();
    expect(fake.created, hasLength(1));

    fake.createGate!.complete();
    await pumpFor(tester);
    expect(host.busy, isFalse);
  });

  testWidgets('a screen that is gone by the time the file is ready is not spoken to',
      (tester) async {
    fake.createGate = Completer<void>();
    final host = await mount(tester);

    unawaited(host.exportBackup());
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    fake.createGate!.complete();
    await pumpFor(tester);

    expect(host.said, isEmpty);
    expect(fake.shared, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
