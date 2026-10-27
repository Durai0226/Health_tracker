/// How many times a reminder can be snoozed, and how long before an unanswered
/// one counts as missed.
///
/// Both were settings the app already honoured — the alarm isolate reads the
/// snooze cap, and the missed sweep reads the threshold — with nothing on the
/// Notifications screen to change either, so everyone had 3 snoozes and a
/// 60-minute window whether they wanted them or not.
library;

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart'
    show AppDatabase, ReminderOccurrencesCompanion;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart'
    show AppSwitch, SegmentedToggle, SettingsTile;
import 'package:tablet_remainder/features/settings/screens/notification_settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
  });

  tearDown(() async => db.close());

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: NotificationSettingsScreen()));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();
  }

  bool switchValue(WidgetTester tester, String title) {
    final row = find.ancestor(
        of: find.text(title), matching: find.byType(SettingsTile));
    expect(row, findsOneWidget, reason: 'no settings row titled "$title"');
    return tester
        .widget<AppSwitch>(
            find.descendant(of: row, matching: find.byType(AppSwitch)))
        .value;
  }

  Finder picker(String label) => find.descendant(
        of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
        matching: find.byType(SegmentedToggle),
      );

  String selected(WidgetTester tester, String label) {
    final w = tester.widget<SegmentedToggle>(picker(label));
    return w.items[w.index].label;
  }

  List<String> options(WidgetTester tester, String label) =>
      [for (final i in tester.widget<SegmentedToggle>(picker(label)).items) i.label];

  Future<void> choose(WidgetTester tester, String label, String option) async {
    await tester.tap(find.descendant(of: picker(label), matching: find.text(option)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  Future<void> toggle(WidgetTester tester, String title) async {
    // The row, not the text: a section can carry the same word as its title.
    await tester.tap(find.widgetWithText(SettingsTile, title));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  group('snoozes allowed', () {
    testWidgets('starts at the three the app has always allowed', (tester) async {
      await open(tester);
      expect(options(tester, 'Snoozes allowed'), ['1', '2', '3', '5']);
      expect(selected(tester, 'Snoozes allowed'), '3');
    });

    testWidgets('a choice is saved, kept after leaving, and sent to the alarm isolate',
        (tester) async {
      await open(tester);
      await choose(tester, 'Snoozes allowed', '5');

      expect(CleanStorageService.getUserSettings().maxSnoozeCount, 5);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('max_snooze_count'), 5,
          reason: 'the alarm isolate reads its own copy, which is what enforces the cap');

      await close(tester);
      await open(tester);
      expect(selected(tester, 'Snoozes allowed'), '5',
          reason: 'the reopened screen showed the default, not the choice');
    });

    testWidgets('are not offered while snoozing is off', (tester) async {
      await open(tester);
      expect(picker('Snoozes allowed'), findsOneWidget);

      await toggle(tester, 'Snooze');

      expect(CleanStorageService.getUserSettings().snoozeEnabled, isFalse);
      expect(find.text('Snoozes allowed'), findsNothing,
          reason: 'a cap on something that is switched off');
      expect(find.text('Snooze duration (minutes)'), findsNothing);
    });

    testWidgets('a stored number the picker does not offer is shown, not hidden',
        (tester) async {
      await CleanStorageService.saveUserSettings(
          CleanStorageService.getUserSettings().copyWith(maxSnoozeCount: 7));

      await open(tester);

      expect(options(tester, 'Snoozes allowed'), ['1', '2', '3', '5', '7']);
      expect(selected(tester, 'Snoozes allowed'), '7',
          reason: 'it used to read as "1", a value it was never set to');

      await toggle(tester, 'Vibration');
      expect(CleanStorageService.getUserSettings().maxSnoozeCount, 7,
          reason: 'and an unrelated switch must not change it');
    });
  });

  group('marking as missed', () {
    testWidgets('starts on, after an hour — what the app has always done',
        (tester) async {
      await open(tester);
      expect(switchValue(tester, 'Mark as missed'), isTrue);
      expect(options(tester, 'After (minutes)'), ['30', '60', '120', '240']);
      expect(selected(tester, 'After (minutes)'), '60');
    });

    testWidgets('the wait is saved and kept after leaving', (tester) async {
      await open(tester);
      await choose(tester, 'After (minutes)', '120');

      expect(CleanStorageService.getUserSettings().missedThresholdMinutes, 120);

      await close(tester);
      await open(tester);
      expect(selected(tester, 'After (minutes)'), '120');
    });

    testWidgets('turning it off is saved and hides the wait', (tester) async {
      await open(tester);
      await toggle(tester, 'Mark as missed');

      expect(CleanStorageService.getUserSettings().autoMarkMissed, isFalse);
      expect(find.text('After (minutes)'), findsNothing,
          reason: 'a wait for something that is switched off');

      await close(tester);
      await open(tester);
      expect(switchValue(tester, 'Mark as missed'), isFalse);
      expect(find.text('After (minutes)'), findsNothing);
    });

    testWidgets('and the sweep really follows what was chosen', (tester) async {
      final now = DateTime(2026, 6, 20, 15);
      Future<void> pending(String id, DateTime due) => db.remindersDao
          .recordOccurrence(ReminderOccurrencesCompanion.insert(
              id: id,
              reminderId: 'r',
              scheduledFor: due,
              outcome: const Value('pending'),
              firedAt: Value(due)));

      await open(tester);
      await choose(tester, 'After (minutes)', '240');
      await close(tester);

      await tester.runAsync(() async {
        await pending('three-hours-old', now.subtract(const Duration(hours: 3)));
        await withClock(Clock.fixed(now), () async {
          expect(await CleanStorageService.reconcileMissedReminders(), 0,
              reason: 'three hours is inside the four-hour wait that was chosen');
        });
      });

      await open(tester);
      await choose(tester, 'After (minutes)', '30');
      await close(tester);

      await tester.runAsync(() async {
        await withClock(Clock.fixed(now), () async {
          expect(await CleanStorageService.reconcileMissedReminders(), 1,
              reason: 'and past a thirty-minute wait it is missed');
        });
      });
    });

    testWidgets('switched off, nothing is ever written off', (tester) async {
      final now = DateTime(2026, 6, 20, 15);
      await open(tester);
      await toggle(tester, 'Mark as missed');
      await close(tester);

      await tester.runAsync(() async {
        await db.remindersDao.recordOccurrence(ReminderOccurrencesCompanion.insert(
            id: 'old',
            reminderId: 'r',
            scheduledFor: now.subtract(const Duration(days: 2)),
            outcome: const Value('pending'),
            firedAt: Value(now.subtract(const Duration(days: 2)))));
        await withClock(Clock.fixed(now), () async {
          expect(await CleanStorageService.reconcileMissedReminders(), 0);
        });
      });
    });
  });

  testWidgets('the new controls do not disturb the old ones', (tester) async {
    await open(tester);
    await choose(tester, 'Snooze duration (minutes)', '15');
    await choose(tester, 'Snoozes allowed', '2');
    await choose(tester, 'After (minutes)', '240');

    final saved = CleanStorageService.getUserSettings();
    expect(saved.snoozeIntervalMinutes, 15);
    expect(saved.maxSnoozeCount, 2);
    expect(saved.missedThresholdMinutes, 240);
    expect(saved.soundEnabled, isTrue);
    expect(saved.snoozeEnabled, isTrue);
    expect(saved.autoMarkMissed, isTrue);
  });
}
