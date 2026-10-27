/// Mood tags: picked by hand, added from the day, shown in the history, and the
/// "what goes with better days" section.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_log.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/models/mood_entry.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/mood_screen.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';
import 'package:tablet_remainder/features/medication/services/mood_day_tags.dart';
import 'package:tablet_remainder/features/medication/services/vitals_storage_service.dart';
import 'package:tablet_remainder/features/period/models/period_day.dart';
import 'package:tablet_remainder/features/period/services/period_service.dart';
import 'package:tablet_remainder/features/sleep/services/sleep_service.dart';
import 'package:tablet_remainder/features/steps/services/step_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;
  // Real date (the storage layer reads "today" itself), fixed time: 14:00.
  final real = DateTime.now();
  final today = DateTime(real.year, real.month, real.day);
  final now = DateTime(real.year, real.month, real.day, 14);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    await ActiveProfileService().init();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    PeriodService.clearInMemory();
    await PeriodService.resetForTesting();
    await PeriodService.init();
    await SleepService.resetForTesting();
    await StepService.resetForTesting();
    MedicineCleanStorageService.revision.value = 0;
  });

  tearDown(() async {
    ActiveProfileService().resetForTesting();
    await db.close();
  });

  void pinned(String name, Future<void> Function(WidgetTester) body) =>
      testWidgets(name, (tester) => withClock(Clock.fixed(now), () => body(tester)));

  Future<void> open(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(430, 2600);
    addTearDown(tester.view.reset);
    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    try {
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme, home: const MoodScreen()));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    } finally {
      FlutterError.onError = prev;
    }
  }

  Future<void> pumpFor(WidgetTester tester, [int n = 6]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> logMood(DateTime at, int index, {List<String> tags = const []}) =>
      VitalsStorageService.saveMood(MoodEntry(
        id: 'm${at.microsecondsSinceEpoch}',
        moodIndex: index,
        takenAt: at,
        tags: tags,
        createdAt: at,
      ));

  Future<void> openLogSheet(WidgetTester tester) async {
    await open(tester);
    await tester.tap(find.text('Log mood'));
    await pumpFor(tester);
  }

  /// The hand-picked tags start closed, so Save stays within reach on a small
  /// screen.
  Future<void> openManualTags(WidgetTester tester) async {
    await tester.tap(find.text('What went with it?'));
    await pumpFor(tester, 3);
  }

  group('picked by hand', () {
    pinned('the sheet offers the tags; a tap toggles one; they are saved',
        (tester) async {
      await openLogSheet(tester);
      expect(find.text('What went with it?'), findsOneWidget);
      expect(find.text('Walk'), findsNothing,
          reason: 'closed to begin with: Save has to stay in reach');
      await openManualTags(tester);
      for (final label in ['Walk', 'Exercise', 'Friends', 'Family', 'Work']) {
        expect(find.text(label), findsOneWidget);
      }

      await tester.tap(find.text('Walk'));
      await tester.tap(find.text('Friends'));
      await tester.pump();
      await tester.tap(find.text('Walk')); // and off again
      await tester.pump();

      await tester.tap(find.text('Good'));
      await tester.pump();
      await tester.tap(find.text('Save entry'));
      await pumpFor(tester, 10);

      final saved = (await VitalsStorageService.getAllMood()).single;
      expect(saved.tags, ['friends']);
    });

    pinned('closing the row hides the chips but keeps what was picked',
        (tester) async {
      await openLogSheet(tester);
      await openManualTags(tester);
      await tester.tap(find.text('Walk'));
      await tester.pump();
      await tester.tap(find.text('Friends'));
      await tester.pump();

      await tester.tap(find.text('What went with it?')); // close
      await pumpFor(tester, 3);
      expect(find.text('Walk'), findsNothing);
      expect(find.text('2 picked'), findsOneWidget);

      await tester.tap(find.text('Good'));
      await tester.pump();
      await tester.tap(find.text('Save entry'));
      await pumpFor(tester, 10);
      expect((await VitalsStorageService.getAllMood()).single.tags.toSet(),
          {'walk', 'friends'});
    });

    pinned('an entry with no tags saves with none', (tester) async {
      await openLogSheet(tester);
      await tester.tap(find.text('Good'));
      await tester.pump();
      await tester.tap(find.text('Save entry'));
      await pumpFor(tester, 10);
      expect((await VitalsStorageService.getAllMood()).single.tags, isEmpty);
    });
  });

  group('from the day', () {
    pinned('a short night and a step goal met are added, and shown as such',
        (tester) async {
      // 02:00 to 07:00 in bed: an estimated 4h 24m asleep.
      await SleepService.logManualSession(
        bedtime: DateTime(today.year, today.month, today.day, 2),
        wakeTime: DateTime(today.year, today.month, today.day, 7),
      );
      StepService.storeHealthDayForTesting(now, 9000, isToday: true);

      await openLogSheet(tester);

      expect(find.text('From your day'), findsOneWidget);
      expect(find.text('Short night'), findsOneWidget);
      expect(find.text('Active day'), findsOneWidget);

      await tester.tap(find.text('Good'));
      await tester.pump();
      await tester.tap(find.text('Save entry'));
      await pumpFor(tester, 10);

      expect((await VitalsStorageService.getAllMood()).single.tags.toSet(),
          {'short_night', 'active_day'});
    });

    pinned('and each can be taken off', (tester) async {
      await SleepService.logManualSession(
        bedtime: DateTime(today.year, today.month, today.day, 2),
        wakeTime: DateTime(today.year, today.month, today.day, 7),
      );
      await openLogSheet(tester);

      await tester.tap(find.text('Short night'));
      await tester.pump();
      await tester.tap(find.text('Good'));
      await tester.pump();
      await tester.tap(find.text('Save entry'));
      await pumpFor(tester, 10);

      expect((await VitalsStorageService.getAllMood()).single.tags, isEmpty);
    });

    pinned('a day that says nothing adds nothing and shows no heading',
        (tester) async {
      await openLogSheet(tester);
      expect(find.text('From your day'), findsNothing);
    });

    pinned('editing an entry keeps ITS tags and adds none of today\'s',
        (tester) async {
      await logMood(now.subtract(const Duration(hours: 3)), 1, tags: ['walk']);
      await SleepService.logManualSession(
        bedtime: DateTime(today.year, today.month, today.day, 2),
        wakeTime: DateTime(today.year, today.month, today.day, 7),
      );
      await open(tester);

      // "Good" is also the hero, the average and the row: the row's own line,
      // which names the tag, is the one thing only it says.
      await tester.tap(find.textContaining('Walk'));
      await pumpFor(tester);
      expect(find.text('Update entry'), findsOneWidget);
      expect(find.text('Exercise'), findsOneWidget,
          reason: 'it already has a hand-picked tag, so the chips are open');
      expect(find.text('From your day'), findsNothing,
          reason: 'it is an old entry; the day has moved on');
      await tester.tap(find.text('Update entry'));
      await pumpFor(tester, 10);

      expect((await VitalsStorageService.getAllMood()).single.tags, ['walk']);
    });
  });

  group('changing the date', () {
    /// Opens the date box (it reads "Today") and moves it to yesterday, which
    /// on the 1st of a month is on the previous page of the calendar.
    Future<void> pickYesterday(WidgetTester tester) async {
      await tester.tap(find.text('Today'));
      await pumpFor(tester);
      final y = DateTime(today.year, today.month, today.day - 1);
      if (y.month != today.month) {
        await tester.tap(find.byTooltip('Previous month'));
        await pumpFor(tester);
      }
      await tester.tap(find.text('${y.day}'));
      await pumpFor(tester);
      await tester.tap(find.text('Set date'));
      await pumpFor(tester);
    }

    /// A short night ending today, and a long one ending yesterday.
    Future<void> seedTwoNights() async {
      await SleepService.logManualSession(
        bedtime: DateTime(today.year, today.month, today.day, 2),
        wakeTime: DateTime(today.year, today.month, today.day, 7),
      );
      await SleepService.logManualSession(
        bedtime: DateTime(today.year, today.month, today.day - 2, 22),
        wakeTime: DateTime(today.year, today.month, today.day - 1, 7),
      );
    }

    pinned('a new entry is tagged from the day it is moved to; what was '
        'picked by hand stays', (tester) async {
      await seedTwoNights();
      await openLogSheet(tester);
      expect(find.text('Short night'), findsOneWidget);
      expect(find.text('Slept well'), findsNothing);

      await openManualTags(tester);
      await tester.tap(find.text('Walk'));
      await tester.pump();
      await pickYesterday(tester);

      expect(find.text('Slept well'), findsOneWidget);
      expect(find.text('Short night'), findsNothing,
          reason: 'that was today\'s night, not the one before');

      await tester.tap(find.text('Good'));
      await tester.pump();
      await tester.tap(find.text('Save entry'));
      await pumpFor(tester, 10);

      final saved = (await VitalsStorageService.getAllMood()).single;
      expect(saved.tags.toSet(), {'walk', 'slept_well'});
      expect(
          DateTime(saved.takenAt.year, saved.takenAt.month, saved.takenAt.day),
          DateTime(today.year, today.month, today.day - 1));
    });

    pinned('an entry being edited keeps its tags when its date moves',
        (tester) async {
      await seedTwoNights();
      await logMood(now.subtract(const Duration(hours: 3)), 1, tags: ['walk']);
      await open(tester);

      await tester.tap(find.textContaining('Walk'));
      await pumpFor(tester);
      await pickYesterday(tester);

      expect(find.text('Slept well'), findsNothing,
          reason: 'the person tagged this entry; moving it is not a new day to '
              'read the app\'s own figures into');
      expect(find.text('From your day'), findsNothing);
      await tester.tap(find.text('Update entry'));
      await pumpFor(tester, 10);

      expect((await VitalsStorageService.getAllMood()).single.tags, ['walk']);
    });
  });

  group('the day, worked out', () {
    pinned('sleep, steps and a period', (tester) async {
      await SleepService.logManualSession(
        bedtime: DateTime(today.year, today.month, today.day - 1, 22),
        wakeTime: DateTime(today.year, today.month, today.day, 7),
      );
      StepService.storeHealthDayForTesting(now, 9000, isToday: true);
      await PeriodService.logDay(PeriodDay(
          id: PeriodDay.keyFor(today), date: today, flowIndex: 2));

      expect(await MoodDayTags.forDate(now),
          ['slept_well', 'active_day', 'period']);
    });

    pinned('a family member\'s day never carries the account holder\'s period',
        (tester) async {
      await PeriodService.logDay(PeriodDay(
          id: PeriodDay.keyFor(today), date: today, flowIndex: 2));
      await ActiveProfileService().setActiveDependent('dep1');

      expect(await MoodDayTags.forDate(now), isNot(contains('period')));
    });

    pinned('doses: all taken, or one missed', (tester) async {
      await MedicineCleanStorageService.addMedicine(EnhancedMedicine(
        id: 'm1',
        name: 'Metformin',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        createdAt: today.subtract(const Duration(days: 5)),
        schedule: MedicineSchedule(
          frequencyType: FrequencyType.onceDaily,
          times: [ScheduledTime(hour: 9, minute: 0)],
        ),
      ));
      final slot = DateTime(today.year, today.month, today.day, 9);
      final id = MedicineCleanStorageService.doseLogId('m1', slot);

      await MedicineCleanStorageService.addLog(
          MedicineLog.taken(id: id, medicineId: 'm1', scheduledTime: slot));
      expect(await MoodDayTags.forDate(now), ['took_doses']);

      await MedicineCleanStorageService.addLog(
          MedicineLog.missed(id: id, medicineId: 'm1', scheduledTime: slot));
      expect(await MoodDayTags.forDate(now), ['missed_dose']);
    });

    pinned('"quiet" waits for the day to be over', (tester) async {
      // 500 steps at two in the afternoon is a day still being walked.
      StepService.storeHealthDayForTesting(now, 500, isToday: true);
      expect(await MoodDayTags.forDate(now), isEmpty);

      // The same day, asked at half past nine at night, is a quiet one.
      await withClock(
        Clock.fixed(DateTime(today.year, today.month, today.day, 21, 30)),
        () async => expect(await MoodDayTags.forDate(now), ['quiet_day']),
      );
    });

    pinned('and a day that has already ended is judged as over',
        (tester) async {
      final yesterday = DateTime(today.year, today.month, today.day - 1, 12);
      StepService.storeHealthDayForTesting(yesterday, 500, isToday: false);
      expect(await MoodDayTags.forDate(yesterday), ['quiet_day']);
    });

    pinned('a source with nothing in it adds no tag', (tester) async {
      expect(await MoodDayTags.forDate(now), isEmpty);
    });
  });

  group('in the history and the patterns', () {
    pinned('tags show in the history row', (tester) async {
      await logMood(now.subtract(const Duration(hours: 3)), 1,
          tags: ['walk', 'short_night']);
      await open(tester);
      expect(find.textContaining('Walk, Short night'), findsOneWidget);
    });

    pinned('with enough days, "what goes with better days" appears',
        (tester) async {
      // Six days with a walk, all Great; six without, all Bad.
      for (var i = 1; i <= 6; i++) {
        await logMood(DateTime(today.year, today.month, today.day - i, 9), 0,
            tags: ['walk']);
        await logMood(DateTime(today.year, today.month, today.day - i - 10, 9), 3);
      }
      await open(tester);

      expect(find.text('What goes with better days'), findsOneWidget);
      expect(find.text('Mood tends to be better on days with a walk'),
          findsOneWidget);
      expect(find.textContaining('Based on 6 vs 6 days'), findsOneWidget);
    });

    pinned('with too few days there is no heading', (tester) async {
      for (var i = 1; i <= 3; i++) {
        await logMood(DateTime(today.year, today.month, today.day - i, 9), 0,
            tags: ['walk']);
      }
      await open(tester);
      expect(find.text('What goes with better days'), findsNothing);
    });
  });
}
