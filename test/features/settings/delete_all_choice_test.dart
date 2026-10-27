/// "Delete all data" asks how far to go when a copy of the data is in the cloud.
///
/// With cloud sync on, a wipe of the device alone is undone at the next start —
/// the sync brings the copy straight back — so the person is asked what should
/// happen to that copy, and each answer says what it leaves behind.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/auth_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/delete_all_data.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';
import 'package:tablet_remainder/features/settings/screens/settings_screen.dart';
import 'package:tablet_remainder/features/settings/widgets/delete_all_choice_sheet.dart';

import '../../support/font_free_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the sheet', () {
    DeleteAllScope? chosen;
    var cancelled = 0;

    Future<void> pumpBody(WidgetTester tester) async {
      chosen = null;
      cancelled = 0;
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(430, 1400);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: fontFreeTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: DeleteAllChoiceBody(
              onChoose: (s) => chosen = s,
              onCancel: () => cancelled++,
            ),
          ),
        ),
      ));
    }

    void quietOverflow() {
      final prev = FlutterError.onError;
      FlutterError.onError = (d) {
        if (!'${d.exception}'.contains('overflowed')) prev?.call(d);
      };
      addTearDown(() => FlutterError.onError = prev);
    }

    testWidgets('says that sync would bring the data back, and offers both ways out',
        (tester) async {
      quietOverflow();
      await pumpBody(tester);

      expect(find.textContaining('Cloud sync is on'), findsOneWidget);
      expect(find.textContaining('bring all of it back'), findsOneWidget);
      expect(find.text('Delete here and in the cloud'), findsOneWidget);
      expect(find.text('Delete here, turn sync off'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('each button answers with its own scope', (tester) async {
      quietOverflow();
      await pumpBody(tester);

      await tester.tap(find.text('Delete here and in the cloud'));
      expect(chosen, DeleteAllScope.deviceAndCloud);

      await tester.tap(find.text('Delete here, turn sync off'));
      expect(chosen, DeleteAllScope.deviceOnly);

      chosen = null;
      await tester.tap(find.text('Cancel'));
      expect(chosen, isNull, reason: 'backing out chooses nothing');
      expect(cancelled, 1);
    });

    for (final (width, scale) in [(320.0, 1.0), (320.0, 2.0)]) {
      testWidgets('fits $width wide at ${scale}x text', (tester) async {
        final errors = <FlutterErrorDetails>[];
        final prev = FlutterError.onError;
        FlutterError.onError = errors.add;
        try {
          tester.view.devicePixelRatio = 1.0;
          tester.view.physicalSize = Size(width, 2400);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          addTearDown(tester.view.reset);
          await tester.pumpWidget(MaterialApp(
            theme: fontFreeTheme(),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: DeleteAllChoiceBody(onChoose: (_) {}, onCancel: () {}),
              ),
            ),
          ));
        } finally {
          FlutterError.onError = prev;
        }
        expect(errors.where((e) => '${e.exception}'.contains('overflowed')), isEmpty);
      });
    }
  });

  group('in Settings', () {
    late AppDatabase db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.forTesting(NativeDatabase.memory());
      AppDatabase.setInstanceForTesting(db);
      CleanStorageService.resetForTesting();
      await CleanStorageService.init();
      ActiveProfileService().resetForTesting();
    });

    tearDown(() async {
      AuthService().setUserForTesting(null);
      AuthService().cloudCopyDeleterForTesting = null;
      await db.close();
    });

    final signedIn = UserModel(id: 'u1', name: 'Sam', email: 'sam@example.com');

    Future<void> openSettings(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(430, 3000);
      addTearDown(tester.view.reset);
      final prev = FlutterError.onError;
      FlutterError.onError = (d) {
        if (!'${d.exception}'.contains('overflowed')) prev?.call(d);
      };
      addTearDown(() => FlutterError.onError = prev);
      await tester.pumpWidget(
          MaterialApp(theme: fontFreeTheme(), home: const SettingsScreen()));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> tapDeleteAll(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Delete all data'));
      await tester.pump();
      await tester.tap(find.text('Delete all data'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(seconds: 8));
    }

    Future<void> seedReminder(WidgetTester tester) async {
      await tester.runAsync(() => CleanStorageService.saveReminder(Reminder(
            id: 'r1',
            title: 'Stretch',
            body: '',
            scheduledTime: DateTime(2030, 1, 1, 9),
          )));
    }

    /// Whether sync is on once the preferences are read back from the database —
    /// what the next start will see, not what is cached in this process.
    Future<bool> syncOnAfterRestart(WidgetTester tester) async {
      await tester.runAsync(() => CleanStorageService.loadAppPreferences());
      return CleanStorageService.cloudSyncEnabled;
    }

    Future<int> reminderCount(WidgetTester tester) async =>
        (await tester.runAsync(() => CleanStorageService.getAllReminders()))!.length;

    var cloudDeletions = 0;

    setUp(() {
      cloudDeletions = 0;
      AuthService().cloudCopyDeleterForTesting = () async {
        cloudDeletions++;
        return const [];
      };
    });

    testWidgets('signed in with sync on, it asks how far to go — and "here only" turns sync off',
        (tester) async {
      await CleanStorageService.setCloudSyncEnabled(true);
      AuthService().setUserForTesting(signedIn);
      await openSettings(tester);
      await seedReminder(tester);

      await tapDeleteAll(tester);
      expect(find.text('Delete here, turn sync off'), findsOneWidget,
          reason: 'the choice, not the plain confirmation');
      expect(find.text('Delete everything'), findsNothing);

      await tester.tap(find.text('Delete here, turn sync off'));
      await settle(tester);

      expect(await syncOnAfterRestart(tester), isFalse,
          reason: 'left on, the next start would bring the cloud copy straight back');
      expect(await reminderCount(tester), 0, reason: 'and the device is wiped');
      expect(find.textContaining('cloud copy stays where it is'), findsOneWidget);
      expect(cloudDeletions, 0, reason: 'the cloud copy was not asked to go');
    });

    testWidgets('"here and in the cloud" also ends sync and says both are gone',
        (tester) async {
      await CleanStorageService.setCloudSyncEnabled(true);
      AuthService().setUserForTesting(signedIn);
      await openSettings(tester);
      await seedReminder(tester);

      await tapDeleteAll(tester);
      await tester.tap(find.text('Delete here and in the cloud'));
      await settle(tester);

      expect(await syncOnAfterRestart(tester), isFalse);
      expect(await reminderCount(tester), 0);
      expect(cloudDeletions, 1, reason: 'the cloud copy was deleted, once');
      expect(find.textContaining('here and in the cloud'), findsOneWidget);
    });

    testWidgets('a cloud copy that cannot be deleted leaves the device as it was',
        (tester) async {
      await CleanStorageService.setCloudSyncEnabled(true);
      AuthService().setUserForTesting(signedIn);
      AuthService().cloudCopyDeleterForTesting = () async {
        cloudDeletions++;
        return ['medicines'];
      };
      await openSettings(tester);
      await seedReminder(tester);

      await tapDeleteAll(tester);
      await tester.tap(find.text('Delete here and in the cloud'));
      await settle(tester);

      expect(find.textContaining('Could not delete your cloud copy (medicines)'),
          findsOneWidget);
      expect(await reminderCount(tester), 1,
          reason: 'an empty device over a surviving copy reads as "gone"');
      expect(await syncOnAfterRestart(tester), isTrue);
    });

    testWidgets('cancelling changes nothing, sync included', (tester) async {
      await CleanStorageService.setCloudSyncEnabled(true);
      AuthService().setUserForTesting(signedIn);
      await openSettings(tester);
      await seedReminder(tester);

      await tapDeleteAll(tester);
      await tester.tap(find.text('Cancel'));
      await settle(tester);

      expect(await syncOnAfterRestart(tester), isTrue);
      expect(await reminderCount(tester), 1);
      expect(cloudDeletions, 0);
    });

    testWidgets('with no cloud copy it is the plain confirmation, and sync is left alone',
        (tester) async {
      // Signed out, sync flag set: nothing is uploaded, so nothing is at stake.
      await CleanStorageService.setCloudSyncEnabled(true);
      AuthService().setUserForTesting(null);
      await openSettings(tester);
      await seedReminder(tester);

      await tapDeleteAll(tester);
      expect(find.text('Delete everything'), findsOneWidget);
      expect(find.text('Delete here and in the cloud'), findsNothing);

      await tester.tap(find.text('Delete everything'));
      await settle(tester);

      expect(await reminderCount(tester), 0);
      expect(find.text('All data deleted.'), findsOneWidget);
    });

    testWidgets('signed in but never opted in to sync: the plain confirmation',
        (tester) async {
      AuthService().setUserForTesting(signedIn);
      await openSettings(tester);

      await tapDeleteAll(tester);
      expect(find.text('Delete everything'), findsOneWidget);
      expect(find.text('Delete here, turn sync off'), findsNothing);

      await tester.tap(find.text('Cancel'));
      await settle(tester);
    });
  });
}
