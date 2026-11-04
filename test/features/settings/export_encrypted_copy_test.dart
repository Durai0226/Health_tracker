/// "Export an encrypted copy" in Settings: the passphrase is chosen first, and the
/// plain "Export a copy" is unchanged.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart' show AppTextField;
import 'package:tablet_remainder/features/backup/services/backup_service.dart';
import 'package:tablet_remainder/features/settings/screens/settings_screen.dart';

import '../../support/font_free_theme.dart';

class _FakeBackup implements BackupService {
  final created = <String?>[];
  final shared = <File>[];

  @override
  int get encryptionIterations => 1;

  @override
  Future<Uint8List> buildBackupBytes({String? passphrase}) async => Uint8List(0);

  @override
  Future<File?> createBackup({String? passphrase}) async {
    created.add(passphrase);
    return File('/tmp/backup');
  }

  @override
  Future<void> shareBackup(File file) async => shared.add(file);

  @override
  Future<bool> restoreBackup({AskBackupPassphrase? askPassphrase}) async => false;

  @override
  Future<bool> restoreFromBytes(Uint8List bytes, {AskBackupPassphrase? askPassphrase}) async =>
      false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late _FakeBackup fake;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    ActiveProfileService().resetForTesting();
    fake = _FakeBackup();
  });

  tearDown(() async => db.close());

  Future<void> openSettings(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(430, 3000);
    addTearDown(tester.view.reset);
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      if (!'${d.exception}'.contains('overflowed')) prev?.call(d);
    };
    addTearDown(() => FlutterError.onError = prev);
    await tester.pumpWidget(MaterialApp(
        theme: fontFreeTheme(), home: SettingsScreen(backupService: fake)));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpFor(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tapRow(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).first);
    await tester.pump();
    await tester.tap(find.text(text).first);
    await pumpFor(tester);
  }

  testWidgets('both rows are there, the encrypted one saying what it does',
      (tester) async {
    await openSettings(tester);
    await tester.ensureVisible(find.text('Export an encrypted copy'));

    expect(find.text('Export a copy'), findsOneWidget);
    expect(find.text('Export an encrypted copy'), findsOneWidget);
    expect(find.text('Protected with a passphrase you choose'), findsOneWidget);
  });

  testWidgets('"Export a copy" is as it was: no passphrase, no question', (tester) async {
    await openSettings(tester);

    await tapRow(tester, 'Export a copy');

    expect(find.text('Protect this backup'), findsNothing);
    expect(fake.created, [null]);
    expect(fake.shared, hasLength(1));
    expect(find.text('Backup ready to share.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('the encrypted copy asks first, then is made with the passphrase',
      (tester) async {
    await openSettings(tester);

    await tapRow(tester, 'Export an encrypted copy');
    expect(fake.created, isEmpty, reason: 'nothing is made before it is chosen');
    expect(find.text('Protect this backup'), findsOneWidget);

    await tester.enterText(find.widgetWithText(AppTextField, 'Passphrase'), 'correct horse 42');
    await tester.enterText(find.widgetWithText(AppTextField, 'Type it again'), 'correct horse 42');
    await tester.tap(find.text('Create encrypted backup'));
    await pumpFor(tester);

    expect(fake.created, ['correct horse 42']);
    expect(fake.shared, hasLength(1));
    expect(find.textContaining('Keep the passphrase safe'), findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('backing out of the passphrase makes and shares nothing', (tester) async {
    await openSettings(tester);

    await tapRow(tester, 'Export an encrypted copy');
    await tester.tap(find.text('Cancel'));
    await pumpFor(tester);

    expect(fake.created, isEmpty);
    expect(fake.shared, isEmpty);
  });
}
