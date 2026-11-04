/// The passphrase sheets, and the Backup screens that use them.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart' show AppButton, AppTextField;
import 'package:tablet_remainder/features/backup/presentation/screens/backup_settings_screen.dart';
import 'package:tablet_remainder/features/backup/presentation/widgets/passphrase_sheet.dart';
import 'package:tablet_remainder/features/backup/services/backup_service.dart';

/// A backup service that records what it was asked and never touches the disk.
class FakeBackupService implements BackupService {
  final created = <String?>[];
  final shared = <File>[];
  bool restoreCalled = false;
  String? passphraseGiven;

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

  /// The picker "finds" an encrypted file: the passphrase prompt is what is driven.
  @override
  Future<bool> restoreBackup({AskBackupPassphrase? askPassphrase}) async {
    restoreCalled = true;
    final p = await askPassphrase!(wrong: false);
    passphraseGiven = p;
    return p != null;
  }

  @override
  Future<bool> restoreFromBytes(Uint8List bytes, {AskBackupPassphrase? askPassphrase}) async =>
      true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> show(WidgetTester tester, Widget home) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(411, 1600);
    addTearDown(tester.view.reset);
    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    try {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: home));
      await settle(tester);
    } finally {
      FlutterError.onError = prev;
    }
  }

  Widget host(Future<void> Function(BuildContext) action) => Scaffold(
        body: Center(
          child: Builder(
            builder: (c) => TextButton(onPressed: () => action(c), child: const Text('go')),
          ),
        ),
      );

  Finder field(String label) => find.widgetWithText(AppTextField, label);

  group('choosing a passphrase', () {
    String? chosen;
    var returned = false;

    Future<void> open(WidgetTester tester) async {
      chosen = null;
      returned = false;
      await show(tester, host((c) async {
        chosen = await PassphraseSheet.askNew(c);
        returned = true;
      }));
      await tester.tap(find.text('go'));
      await settle(tester);
    }

    testWidgets('says plainly that it cannot be recovered', (tester) async {
      await open(tester);

      expect(find.text('Protect this backup'), findsOneWidget);
      expect(find.textContaining('no way to recover this passphrase'), findsOneWidget);
      expect(find.textContaining('not by you, and not by us'), findsOneWidget);
    });

    testWidgets('a matching passphrase of enough length is returned as typed',
        (tester) async {
      await open(tester);

      await tester.enterText(field('Passphrase'), 'correct horse 42');
      await tester.enterText(field('Type it again'), 'correct horse 42');
      await tester.tap(find.text('Create encrypted backup'));
      await settle(tester);

      expect(chosen, 'correct horse 42');
    });

    testWidgets('one that is too short is refused, with the reason', (tester) async {
      await open(tester);

      await tester.enterText(field('Passphrase'), 'short');
      await tester.enterText(field('Type it again'), 'short');
      await tester.tap(find.text('Create encrypted backup'));
      await settle(tester);

      expect(returned, isFalse, reason: 'the sheet stays open');
      expect(find.text('Use at least 8 characters.'), findsOneWidget);
    });

    testWidgets('two that differ are refused', (tester) async {
      await open(tester);

      await tester.enterText(field('Passphrase'), 'correct horse 42');
      await tester.enterText(field('Type it again'), 'correct horse 43');
      await tester.tap(find.text('Create encrypted backup'));
      await settle(tester);

      expect(returned, isFalse);
      expect(find.text('The two passphrases are not the same.'), findsOneWidget);
    });

    testWidgets('typing again clears the complaint', (tester) async {
      await open(tester);
      await tester.enterText(field('Passphrase'), 'short');
      await tester.enterText(field('Type it again'), 'short');
      await tester.tap(find.text('Create encrypted backup'));
      await settle(tester);
      expect(find.text('Use at least 8 characters.'), findsOneWidget);

      await tester.enterText(field('Passphrase'), 'longer now');
      await settle(tester);

      expect(find.text('Use at least 8 characters.'), findsNothing);
    });

    testWidgets('Cancel gives nothing back', (tester) async {
      await open(tester);

      await tester.tap(find.text('Cancel'));
      await settle(tester);

      expect(returned, isTrue);
      expect(chosen, isNull);
    });

    testWidgets('the passphrase is hidden until asked for', (tester) async {
      await open(tester);

      expect(tester.widget<AppTextField>(field('Passphrase')).obscureText, isTrue);
      await tester.tap(find.byTooltip('Show passphrase'));
      await settle(tester);
      expect(tester.widget<AppTextField>(field('Passphrase')).obscureText, isFalse);
      expect(tester.widget<AppTextField>(field('Type it again')).obscureText, isFalse);
    });

    testWidgets('shown or hidden, the keyboard is told it is not a word', (tester) async {
      // Hidden, a keyboard leaves a password field alone. Shown, it is ordinary text,
      // and a keyboard would correct it in one box and not the other, or learn it —
      // and a backup passphrase cannot be recovered.
      await open(tester);

      void expectLeftAlone() {
        for (final label in ['Passphrase', 'Type it again']) {
          final input = tester.widget<TextField>(
              find.descendant(of: field(label), matching: find.byType(TextField)));
          expect(input.autocorrect, isFalse, reason: label);
          expect(input.enableSuggestions, isFalse, reason: label);
          expect(input.keyboardType, TextInputType.visiblePassword, reason: label);
          expect(input.textCapitalization, TextCapitalization.none, reason: label);
        }
      }

      expectLeftAlone();
      await tester.tap(find.byTooltip('Show passphrase'));
      await settle(tester);
      expectLeftAlone();
    });
  });

  group('giving a passphrase', () {
    String? given;
    var returned = false;

    Future<void> open(WidgetTester tester, {bool wrong = false}) async {
      given = null;
      returned = false;
      await show(tester, host((c) async {
        given = await PassphraseSheet.askExisting(c, wrong: wrong);
        returned = true;
      }));
      await tester.tap(find.text('go'));
      await settle(tester);
    }

    testWidgets('returns exactly what was typed, spaces included', (tester) async {
      await open(tester);

      await tester.enterText(field('Passphrase'), ' padded passphrase ');
      await tester.tap(find.text('Open backup'));
      await settle(tester);

      expect(given, ' padded passphrase ');
    });

    testWidgets('an empty one is not submitted', (tester) async {
      await open(tester);

      await tester.tap(find.text('Open backup'));
      await settle(tester);

      expect(returned, isFalse);
    });

    testWidgets('after a wrong one it says so', (tester) async {
      await open(tester, wrong: true);

      expect(find.text('That passphrase did not open the backup. Try again.'), findsOneWidget);
    });

    testWidgets('the first time it does not', (tester) async {
      await open(tester);

      expect(find.textContaining('did not open the backup'), findsNothing);
    });

    testWidgets('the keyboard is told it is not a word, shown or hidden', (tester) async {
      await open(tester);

      void expectLeftAlone() {
        final input = tester.widget<TextField>(
            find.descendant(of: field('Passphrase'), matching: find.byType(TextField)));
        expect(input.autocorrect, isFalse);
        expect(input.enableSuggestions, isFalse);
        expect(input.keyboardType, TextInputType.visiblePassword);
      }

      expectLeftAlone();
      await tester.tap(find.byTooltip('Show passphrase'));
      await settle(tester);
      expectLeftAlone();
    });

    testWidgets('Cancel gives nothing back', (tester) async {
      await open(tester);

      await tester.tap(find.text('Cancel'));
      await settle(tester);

      expect(returned, isTrue);
      expect(given, isNull);
    });
  });

  group('on the Backup & Restore screen', () {
    late FakeBackupService fake;

    Future<void> openScreen(WidgetTester tester) async {
      fake = FakeBackupService();
      await show(tester, BackupSettingsScreen(service: fake));
    }

    testWidgets('the plain backup is made with no passphrase', (tester) async {
      await openScreen(tester);

      await tester.tap(find.widgetWithText(AppButton, 'Create backup'));
      await settle(tester);

      expect(fake.created, [null]);
      expect(fake.shared, hasLength(1));
    });

    testWidgets('the encrypted one asks first, then is made with that passphrase',
        (tester) async {
      await openScreen(tester);

      await tester.tap(find.widgetWithText(AppButton, 'Create encrypted backup'));
      await settle(tester);
      expect(fake.created, isEmpty, reason: 'nothing is made before the passphrase is chosen');
      expect(find.text('Protect this backup'), findsOneWidget);

      await tester.enterText(field('Passphrase'), 'correct horse 42');
      await tester.enterText(field('Type it again'), 'correct horse 42');
      await tester.tap(find.text('Create encrypted backup').last);
      await settle(tester);

      expect(fake.created, ['correct horse 42']);
      expect(fake.shared, hasLength(1));
      expect(find.textContaining('Keep the passphrase safe'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('backing out of the passphrase makes nothing', (tester) async {
      await openScreen(tester);

      await tester.tap(find.widgetWithText(AppButton, 'Create encrypted backup'));
      await settle(tester);
      await tester.tap(find.text('Cancel'));
      await settle(tester);

      expect(fake.created, isEmpty);
      expect(fake.shared, isEmpty);
    });

    testWidgets('says what the encrypted option is for, and its cost', (tester) async {
      await openScreen(tester);

      expect(find.textContaining('Without it nobody can open the file'), findsOneWidget);
    });

    testWidgets('restoring an encrypted backup asks for its passphrase', (tester) async {
      await openScreen(tester);

      await tester.tap(find.widgetWithText(AppButton, 'Restore from file'));
      await settle(tester);
      await tester.tap(find.widgetWithText(AppButton, 'Restore'));
      await settle(tester);

      expect(fake.restoreCalled, isTrue);
      expect(find.text('This backup is protected'), findsOneWidget);

      await tester.enterText(field('Passphrase'), 'correct horse 42');
      await tester.tap(find.text('Open backup'));
      await settle(tester);

      expect(fake.passphraseGiven, 'correct horse 42');
      expect(find.text('Data restored.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('closing the passphrase prompt is "canceled", not a failure',
        (tester) async {
      await openScreen(tester);

      await tester.tap(find.widgetWithText(AppButton, 'Restore from file'));
      await settle(tester);
      await tester.tap(find.widgetWithText(AppButton, 'Restore'));
      await settle(tester);
      await tester.tap(find.text('Cancel'));
      await settle(tester);

      expect(find.text('Restore canceled.'), findsOneWidget);
      expect(find.textContaining('failed'), findsNothing);
      await tester.pump(const Duration(seconds: 8));
    });
  });
}
