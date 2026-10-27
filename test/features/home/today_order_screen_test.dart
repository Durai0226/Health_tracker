/// Today puts the card that wants you now at the top, and says so.
///
/// The pure rules are in `today_order_test.dart`. What is pinned down here is
/// the wiring, which is where this kind of feature goes wrong: that each signal
/// reads the right live source, that the moved card is explained on screen, that
/// the switches do what they say, and that the two people who must never be
/// nudged (a fluid limit, someone who doesn't log water) are not.
library;

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/vacation_mode.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/utils/calendar_day.dart';
import 'package:tablet_remainder/features/home/screens/home_dashboard.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_log.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';
import 'package:tablet_remainder/features/water/models/hydration_profile.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late db.AppDatabase database;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  /// Midday on the real date. The storage layer resolves "today" through its own
  /// calendar reads, so the date has to be today's; the TIME is pinned so "a
  /// dose that is overdue" and "water behind pace" mean the same at any hour.
  final pinnedNow = () {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day, 13, 0);
  }();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    WaterService.clearInMemory();
    await WaterService.resetForTesting();
    MedicineCleanStorageService.revision.value = 0;
  });

  tearDown(() async => database.close());

  void pinned(String description, Future<void> Function(WidgetTester) body) {
    testWidgets(description,
        (tester) => withClock(Clock.fixed(pinnedNow), () => body(tester)));
  }

  /// Yesterday's water, so the person counts as someone who logs it.
  Future<void> drankYesterday() async {
    final day = dayOffset(pinnedNow, -1);
    await database.waterDao.saveDailyData(db.DailyWaterDataTableCompanion(
      id: Value(WaterService.dateKeyFor(day)),
      date: Value(day),
      dailyGoalMl: const Value(2500),
      totalIntakeMl: const Value(1800),
      effectiveHydrationMl: const Value(1800),
    ));
    await WaterService.init();
  }

  /// A medicine whose one dose is due at [hour]:[minute].
  Future<void> doseAt(int hour, int minute) async {
    await MedicineCleanStorageService.addMedicine(EnhancedMedicine(
      id: 'm1',
      name: 'Metformin',
      strength: '500mg',
      dosageForm: DosageForm.tablet,
      dosageAmount: 1,
      createdAt: pinnedNow.subtract(const Duration(days: 7)),
      schedule: MedicineSchedule(
        frequencyType: FrequencyType.onceDaily,
        times: [ScheduledTime(hour: hour, minute: minute)],
      ),
    ));
  }

  /// Due at 09:00, so at 13:00 it is overdue.
  Future<void> overdueDose() => doseAt(9, 0);

  Future<void> overdueReminder() => CleanStorageService.saveReminder(Reminder(
        id: 'r1',
        title: 'Call the clinic',
        body: '',
        scheduledTime: pinnedNow.subtract(const Duration(hours: 2)),
      ));

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(375, 3200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    try {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: HomeDashboard(onNavigate: (int i, {int? healthTab}) {}),
      ));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 400));
    } finally {
      FlutterError.onError = prev;
    }
  }

  Finder moved() => find.textContaining('moved up');

  /// Top of a card, by a line only it carries: Hydration's title, Medicine's
  /// (or its empty-state title), the Reminders half's "1 overdue".
  double topOf(WidgetTester tester, String title) =>
      tester.getTopLeft(find.text(title)).dy;

  group('what moves, and what it says', () {
    pinned('water far behind lifts Hydration above Medicine and says why',
        (tester) async {
      await drankYesterday();
      await pumpHome(tester);

      expect(find.textContaining(RegExp(r'Water moved up — about \d+ ml behind')),
          findsOneWidget);
      expect(topOf(tester, 'Hydration'),
          lessThan(topOf(tester, 'No medicines yet')),
          reason: 'Water was behind, and Medicine had nothing due');
    });

    pinned('a due dose keeps Medicine on top and says nothing: it did not move',
        (tester) async {
      await drankYesterday();
      await overdueDose();
      await pumpHome(tester);

      expect(moved(), findsNothing);
      expect(topOf(tester, 'Medicine'),
          lessThan(topOf(tester, 'Hydration')));
    });

    pinned('a due dose outranks water: with Water first, Medicine takes the top',
        (tester) async {
      await drankYesterday();
      await overdueDose();
      await CleanStorageService.setAppPreference(
          'today_card_order', ['water', 'medicine', 'weekly', 'activity']);
      await pumpHome(tester);

      expect(find.text('Medicine moved up — 1 dose is due'), findsOneWidget);
      expect(topOf(tester, 'Medicine'),
          lessThan(topOf(tester, 'Hydration')));
      await tester.pump(const Duration(seconds: 1));
    });

    pinned('a dose due within the hour counts as now; one this evening does not',
        (tester) async {
      await CleanStorageService.setAppPreference(
          'today_card_order', ['water', 'medicine', 'weekly', 'activity']);

      await doseAt(13, 40);
      await pumpHome(tester);
      expect(find.text('Medicine moved up — 1 dose is due'), findsOneWidget);
    });

    pinned('a dose due this evening is not yet a reason to move anything',
        (tester) async {
      await CleanStorageService.setAppPreference(
          'today_card_order', ['water', 'medicine', 'weekly', 'activity']);

      await doseAt(20, 0);
      await pumpHome(tester);
      expect(moved(), findsNothing);
    });

    pinned('a dose already marked missed is no longer "now"', (tester) async {
      await CleanStorageService.setAppPreference(
          'today_card_order', ['water', 'medicine', 'weekly', 'activity']);
      await overdueDose();
      await MedicineCleanStorageService.addLog(MedicineLog.missed(
        id: MedicineCleanStorageService.doseLogId(
            'm1', DateTime(pinnedNow.year, pinnedNow.month, pinnedNow.day, 9)),
        medicineId: 'm1',
        scheduledTime:
            DateTime(pinnedNow.year, pinnedNow.month, pinnedNow.day, 9),
      ));
      await pumpHome(tester);

      expect(moved(), findsNothing);
    });

    pinned('a dose already taken is not a reason either', (tester) async {
      await CleanStorageService.setAppPreference(
          'today_card_order', ['water', 'medicine', 'weekly', 'activity']);
      await overdueDose();
      await MedicineCleanStorageService.addLog(MedicineLog.taken(
        id: MedicineCleanStorageService.doseLogId(
            'm1', DateTime(pinnedNow.year, pinnedNow.month, pinnedNow.day, 9)),
        medicineId: 'm1',
        scheduledTime:
            DateTime(pinnedNow.year, pinnedNow.month, pinnedNow.day, 9),
      ));
      await pumpHome(tester);

      expect(moved(), findsNothing);
    });

    pinned('an overdue reminder lifts Focus & reminders', (tester) async {
      await overdueReminder();
      await pumpHome(tester);

      expect(
          find.text('Focus & reminders moved up — 1 reminder is overdue'),
          findsOneWidget);
      // The Reminders half of that card, which says what is overdue.
      expect(topOf(tester, '1 overdue'),
          lessThan(topOf(tester, 'No medicines yet')));
    });

    pinned("someone's own order is the order when nothing needs them",
        (tester) async {
      await CleanStorageService.setAppPreference(
          'today_card_order', ['weekly', 'activity', 'water', 'medicine']);
      await pumpHome(tester);

      expect(moved(), findsNothing);
      expect(topOf(tester, 'Hydration'),
          lessThan(topOf(tester, 'No medicines yet')),
          reason: 'water was dragged above medicine, and stays there');
    });
  });

  group('who is never nudged', () {
    pinned('a fluid limit is a ceiling: Water is never lifted for being "behind"',
        (tester) async {
      await drankYesterday();
      await WaterService.saveProfile(HydrationProfile(
        id: 'profile',
        weightKg: 70,
        activityLevel: ActivityLevel.sedentary,
        fluidCeilingMl: 1500,
        createdAt: pinnedNow,
      ));
      await pumpHome(tester);

      expect(moved(), findsNothing);
      expect(find.textContaining('ml behind'), findsNothing);
    });

    pinned('someone who has never logged water is not "behind" on it',
        (tester) async {
      await pumpHome(tester);

      expect(moved(), findsNothing);
    });

    pinned('away on vacation, an overdue reminder is not a thing to chase',
        (tester) async {
      await overdueReminder();
      await VacationMode.start(
          until: dayOffset(pinnedNow, 3), now: pinnedNow);
      await pumpHome(tester);

      expect(moved(), findsNothing);
    });

    pinned('a reminder from days ago is the Overdue list\'s, not Today\'s',
        (tester) async {
      await CleanStorageService.saveReminder(Reminder(
        id: 'old',
        title: 'Renew the form',
        body: '',
        scheduledTime: pinnedNow.subtract(const Duration(days: 3)),
      ));
      await pumpHome(tester);

      expect(moved(), findsNothing);
    });
  });

  group('the switches', () {
    pinned('"Bring forward what needs you" off: the order is exactly yours',
        (tester) async {
      await drankYesterday();
      await overdueDose();
      await CleanStorageService.setAppPreference(
          'today_card_order', ['water', 'medicine', 'weekly', 'activity']);
      await CleanStorageService.setAppPreference('today_auto_order', false);
      await pumpHome(tester);

      expect(moved(), findsNothing);
      expect(topOf(tester, 'Hydration'),
          lessThan(topOf(tester, 'Medicine')));
      await tester.pump(const Duration(seconds: 1));
    });

    pinned('a hidden card is not shown and not lifted', (tester) async {
      await drankYesterday();
      await CleanStorageService.setAppPreference(
          'today_hidden_cards', ['water']);
      await pumpHome(tester);

      expect(find.text('Hydration'), findsNothing);
      expect(moved(), findsNothing);
    });

    pinned('the sheet turns the lift off, and Today follows at once',
        (tester) async {
      await drankYesterday();
      await pumpHome(tester);
      expect(moved(), findsOneWidget);

      await tester.tap(find.text('Customize'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.text('Bring forward what needs you'));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(CleanStorageService.getAppPreference('today_auto_order', true),
          false);
      expect(moved(), findsNothing);
    });

    pinned('dragging a card in the sheet saves the order and Today follows',
        (tester) async {
      await pumpHome(tester);
      await tester.tap(find.text('Customize'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Medicine is first; one slot down puts it under Water. A real drag, a
      // finger moving in steps: a single jump is swallowed by the drag's start.
      final gesture = await tester.startGesture(
          tester.getCenter(find.byIcon(Symbols.drag_indicator_rounded).first));
      await tester.pump(const Duration(milliseconds: 50));
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(0, 10));
        await tester.pump(const Duration(milliseconds: 30));
      }
      await gesture.up();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(CleanStorageService.getAppPreference('today_card_order'),
          ['water', 'medicine', 'weekly', 'activity']);
      expect(topOf(tester, 'Hydration'),
          lessThan(topOf(tester, 'No medicines yet')));
    });

    pinned('Focus & reminders can be moved and switched off like the others',
        (tester) async {
      await pumpHome(tester);
      expect(find.text('No reminders'), findsOneWidget);

      await tester.tap(find.text('Customize'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Always shown'), findsNothing,
          reason: 'it used to be pinned: it was the only way in');
      expect(find.byIcon(Symbols.drag_indicator_rounded), findsNWidgets(4));
      expect(find.text('Also on the Health tab'), findsOneWidget,
          reason: 'switching it off must say where Focus and Reminders live now');

      await tester.tap(find.text('Focus & reminders'));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(CleanStorageService.getAppPreference('today_hidden_cards'),
          ['activity']);
      expect(find.text('No reminders'), findsNothing,
          reason: 'Today follows the switch at once');

      await tester.tap(find.text('Focus & reminders'));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(CleanStorageService.getAppPreference('today_hidden_cards'),
          isEmpty);
      expect(find.text('No reminders'), findsOneWidget);
    });

    pinned('hidden, an overdue reminder neither shows nor moves anything',
        (tester) async {
      await overdueReminder();
      await CleanStorageService.setAppPreference(
          'today_hidden_cards', ['activity']);
      await pumpHome(tester);

      expect(find.text('1 overdue'), findsNothing);
      expect(moved(), findsNothing);
    });
  });
}
