import 'dart:io';

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/utils/calendar_day.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_log.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_medication_dashboard.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

/// A phone left on the Medication tab overnight showed YESTERDAY as "today".
///
/// `_selectedDate` was set once, in a field initialiser, and never
/// re-evaluated. The screen is kept alive in the Health hub's IndexedStack, so
/// once the clock passed midnight it went on showing the previous day's doses
/// and the previous day's Taken count — and its Take buttons wrote their logs
/// against the wrong day, which then reads as a missed dose for the day that
/// actually happened.
///
/// The selection now rolls forward on resume (and on a data-revision refresh),
/// but ONLY when it still meant "today": a day the user deliberately tapped in
/// the date strip must stay where they put it.
///
/// The "Taken" tile is the observable — `takenToday/totalToday` for whichever
/// date is selected.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    await ActiveProfileService().init();
  });

  tearDown(() async {
    ActiveProfileService().resetForTesting();
    await db.close();
  });

  /// One daily tablet at noon, created [createdDaysAgo] days ago, with a taken
  /// log on the noon slot of [takenOn].
  Future<void> seedNoonTablet({
    required int createdDaysAgo,
    required DateTime takenOn,
  }) async {
    final today = startOfDay(DateTime.now());
    await MedicineCleanStorageService.addMedicine(EnhancedMedicine(
      id: 'm1',
      name: 'Metformin',
      strength: '500mg',
      dosageForm: DosageForm.tablet,
      dosageAmount: 1,
      createdAt: dayOffset(today, -createdDaysAgo).add(const Duration(minutes: 5)),
      schedule: MedicineSchedule(
        frequencyType: FrequencyType.onceDaily,
        times: [ScheduledTime(hour: 12, minute: 0)],
      ),
    ));
    final slot = DateTime(takenOn.year, takenOn.month, takenOn.day, 12);
    await MedicineCleanStorageService.addLog(MedicineLog.taken(
      // The canonical id, so the missed-dose sweep upserts onto this row
      // instead of adding a second one for the same slot.
      id: MedicineCleanStorageService.doseLogId('m1', slot),
      medicineId: 'm1',
      scheduledTime: slot,
      actionTime: slot,
      dosageTaken: 1,
    ));
  }

  Future<void> pumpDashboard(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const NunitoMedicationDashboard(),
    ));
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  Future<void> resume(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  testWidgets('a selection that meant "today" follows the clock past midnight',
      (tester) async {
    final today = startOfDay(DateTime.now());
    var fakeNow = today.add(const Duration(hours: 23, minutes: 50));

    await withClock(Clock(() => fakeNow), () async {
      await seedNoonTablet(createdDaysAgo: 0, takenOn: today);
      await pumpDashboard(tester);

      expect(find.text('1/1'), findsOneWidget,
          reason: 'today\'s single dose was taken');

      // Ten minutes later the phone comes back and it is a new day.
      fakeNow = dayOffset(today, 1).add(const Duration(minutes: 10));
      await resume(tester);

      expect(find.text('0/1'), findsOneWidget,
          reason: 'the new day\'s dose is outstanding; showing 1/1 would be '
              'yesterday\'s count, and Take would log against yesterday');
      expect(find.text('1/1'), findsNothing);
    });
  });

  testWidgets('a date the user tapped is NOT moved by the rollover',
      (tester) async {
    final today = startOfDay(DateTime.now());
    final yesterday = dayOffset(today, -1);
    var fakeNow = today.add(const Duration(hours: 23, minutes: 50));

    await withClock(Clock(() => fakeNow), () async {
      await seedNoonTablet(createdDaysAgo: 3, takenOn: yesterday);
      await pumpDashboard(tester);

      // The strip is built from the real calendar, so tap yesterday's chip by
      // its weekday label — unique among seven consecutive days.
      final label = DateFormat('EEE').format(yesterday).toUpperCase();
      await tester.tap(find
          .ancestor(
              of: find.text(label), matching: find.byType(GestureDetector))
          .first);
      await tester.pumpAndSettle();
      expect(find.text('1/1'), findsOneWidget,
          reason: 'yesterday\'s dose was taken');

      fakeNow = dayOffset(today, 1).add(const Duration(minutes: 10));
      await resume(tester);

      expect(find.text('1/1'), findsOneWidget,
          reason: 'the rollover must not drag a deliberately chosen day '
              'forward — the user was reviewing history');
    });
  });

  testWidgets('leaving the screen mid-date-change does not setState after '
      'dispose', (tester) async {
    final today = startOfDay(DateTime.now());
    final yesterday = dayOffset(today, -1);

    await withClock(Clock(() => today.add(const Duration(hours: 10))), () async {
      await seedNoonTablet(createdDaysAgo: 3, takenOn: yesterday);
      await pumpDashboard(tester);

      final label = DateFormat('EEE').format(yesterday).toUpperCase();
      await tester.tap(find
          .ancestor(
              of: find.text(label), matching: find.byType(GestureDetector))
          .first);
      // Deliberately not settled first: the new day's logs are being read.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(tester.takeException(), isNull);
    });

    // The runtime race above cannot be forced: an in-memory Drift read against
    // a handful of rows always resolves inside the tap's own pump, so the
    // continuation lands while the State is still mounted no matter what. On a
    // real device with a year of logs it does not, and the continuation ran
    // unguarded — so the guard itself is pinned here, in the window bounded by
    // the next declaration.
    final source = File(
            'lib/features/medication/screens/nunito_medication_dashboard.dart')
        .readAsStringSync()
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    final from = source.indexOf('void _onDateChanged(DateTime date) {');
    expect(from, greaterThan(-1), reason: '_onDateChanged was renamed');
    final to = source.indexOf("static const String _viewModeKey", from);
    expect(to, greaterThan(from), reason: 'the window anchor moved');
    final body = source.substring(from, to);
    final continuation = body.substring(body.indexOf('.then('));
    expect(continuation, contains('mounted'),
        reason: 'setState in the date-change continuation must be guarded, or '
            'leaving the screen mid-load throws setState-after-dispose');
  });
}
