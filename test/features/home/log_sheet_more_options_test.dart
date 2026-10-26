import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/diary/screens/diary_entry_screen.dart';
import 'package:tablet_remainder/features/focus/screens/focus_screen.dart';
import 'package:tablet_remainder/features/home/widgets/log_something_sheet.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';
import 'package:tablet_remainder/features/reminders/screens/add_reminder_screen.dart';

/// The Log (+) sheet could capture doses, water, vitals, steps, sleep and
/// period — and nothing for a focus session, a reminder or a diary entry, each
/// of which had a screen and no way in from here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
  });

  tearDown(() async => db.close());

  Future<void> openSheet(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final prev = FlutterError.onError;
    FlutterError.onError = (_) {}; // the screens behind are covered elsewhere
    addTearDown(() => FlutterError.onError = prev);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
                onPressed: () => LogSomethingSheet.show(context),
                child: const Text('log')),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('log'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tapTile(WidgetTester tester, String title) async {
    final tile = find.text(title);
    await tester.ensureVisible(tile);
    await tester.pump();
    await tester.tap(tile);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('the three new options are on the sheet, reachable by scrolling',
      (tester) async {
    await openSheet(tester);
    for (final t in ['Focus session', 'Reminder', 'Diary entry']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    // The ones that were always there are still there.
    for (final t in ['Water', 'Steps', 'Sleep', 'Period']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
  });

  testWidgets('Focus session opens the focus screen', (tester) async {
    await openSheet(tester);
    await tapTile(tester, 'Focus session');
    expect(find.byType(FocusScreen), findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('Reminder opens a new reminder', (tester) async {
    await openSheet(tester);
    await tapTile(tester, 'Reminder');
    expect(find.byType(AddReminderScreen), findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('Diary entry opens a blank entry', (tester) async {
    await openSheet(tester);
    await tapTile(tester, 'Diary entry');
    final screen =
        tester.widget<DiaryEntryScreen>(find.byType(DiaryEntryScreen));
    expect(screen.existing, isNull, reason: 'a new entry, not an edit');
    await tester.pump(const Duration(seconds: 8));
  });

  group('as-needed medicines', () {
    EnhancedMedicine med(String id, String name,
            {bool prn = true, bool archived = false}) =>
        EnhancedMedicine(
          id: id,
          name: name,
          dosageForm: DosageForm.tablet,
          dosageAmount: 1,
          isArchived: archived,
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
          schedule: prn
              ? MedicineSchedule(
                  frequencyType: FrequencyType.asNeeded,
                  isPRN: true,
                  times: const [])
              : MedicineSchedule(
                  frequencyType: FrequencyType.onceDaily,
                  times: [ScheduledTime(hour: 23, minute: 59)]),
        );

    testWidgets('a lone as-needed medicine goes straight to the take sheet',
        (tester) async {
      await MedicineCleanStorageService.addMedicine(med('p1', 'Ibuprofen'));
      await openSheet(tester);
      await tapTile(tester, 'Medicine dose');
      expect(find.text('Take medicine'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('with a scheduled dose too, both are offered', (tester) async {
      await MedicineCleanStorageService.addMedicine(med('p1', 'Ibuprofen'));
      await MedicineCleanStorageService.addMedicine(
          med('s1', 'Metformin', prn: false));
      await openSheet(tester);
      await tapTile(tester, 'Medicine dose');
      expect(find.text('Which dose?'), findsOneWidget);
      expect(find.text('Ibuprofen'), findsOneWidget);
      expect(find.text('As needed'), findsOneWidget);
      expect(find.text('Metformin'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('an archived as-needed medicine is not offered',
        (tester) async {
      await MedicineCleanStorageService.addMedicine(
          med('p1', 'Ibuprofen', archived: true));
      await openSheet(tester);
      await tapTile(tester, 'Medicine dose');
      expect(find.text('Take medicine'), findsNothing);
      expect(find.text('No doses due right now'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('nothing to log still says so', (tester) async {
      await openSheet(tester);
      await tapTile(tester, 'Medicine dose');
      expect(find.text('No doses due right now'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });
  });
}
