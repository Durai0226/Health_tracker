@Tags(['performance'])
library;

/// One open of a medication screen must read each table ONCE.
///
/// Both screens fanned the same rows out to several consumers and let each
/// consumer fetch its own copy:
///
///  * **Detail** — `_loadData` issued two byte-identical
///    `getLogsForMedicine(_medicine.id)` calls (one for the history list, one
///    for the refill/insight engines) and then called
///    `getAdherenceStatsForMedicine` WITHOUT `allLogs:`, which read them a
///    third time.
///  * **Report** — `_loadData` read the window, `getAdherenceStats` re-read the
///    same window internally, `getCurrentStreak` read medicines AND logs again,
///    and `_calculateDailyStats` issued a fourth log read.
///
/// The numbers below are measured from a real in-memory database, not guessed.
///
/// NOTE ON THE MATCHER: the Drift tables are `enhanced_medicines` and
/// `medicine_logs`. An earlier query test in this repo matched `from
/// "medicines"`, matched nothing, and passed with the bug deliberately
/// restored — so every threshold here is printed from a real run first.
///
/// NOTE ON THE ASSERTIONS: they are EQUALITIES, not budgets. A
/// `lessThanOrEqualTo(1)` is satisfied by ZERO, so it passes just as happily
/// when the screen never loads at all — verified: with both `_loadData`
/// bodies short-circuited to a bare `return`, the budget form of this test
/// was still green 2/2. Build errors are swallowed here (`FlutterError.
/// onError`) precisely because these screens log some in a host VM, so there
/// is nothing else in the pump to notice an empty screen. An equality is the
/// floor as well as the ceiling.
import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_log.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/screens/analytics/nunito_adherence_report_screen.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_medication_detail_screen.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

import '../support/counting_executor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CountingExecutor counter;
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    counter = CountingExecutor(NativeDatabase.memory())..recording = false;
    db = AppDatabase.forTesting(counter);
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
  });

  tearDown(() async => db.close());

  final fixedNow = DateTime(2026, 3, 18, 14, 30);
  final today = DateTime(fixedNow.year, fixedNow.month, fixedNow.day);

  EnhancedMedicine twiceDaily(String id) => EnhancedMedicine(
        id: id,
        name: 'Med $id',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        currentStock: 40,
        createdAt: DateTime(today.year, today.month, today.day - 40),
        schedule: MedicineSchedule(
          frequencyType: FrequencyType.twiceDaily,
          times: [
            ScheduledTime(hour: 8, minute: 0),
            ScheduledTime(hour: 20, minute: 0),
          ],
        ),
      );

  Future<void> seed({int medicines = 3, int days = 20}) async {
    for (var i = 0; i < medicines; i++) {
      final med = twiceDaily('m$i');
      await MedicineCleanStorageService.addMedicine(med,
          stampActiveProfile: false);
      for (var d = 1; d <= days; d++) {
        final slot = DateTime(today.year, today.month, today.day - d, 8, 0);
        await MedicineCleanStorageService.addLog(MedicineLog.taken(
          id: MedicineCleanStorageService.doseLogId(med.id, slot),
          medicineId: med.id,
          scheduledTime: slot,
          actionTime: slot.add(const Duration(minutes: 20)),
        ));
      }
    }
  }

  Future<Map<String, int>> measure(
      WidgetTester tester, Widget screen) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    try {
      counter.reset();
      counter.recording = true;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: screen,
      ));
      await tester.pumpAndSettle();
      counter.recording = false;
    } finally {
      FlutterError.onError = prev;
    }
    return counter.tally;
  }

  testWidgets('one detail-screen open reads each table once', (tester) async {
    await withClock(Clock.fixed(fixedNow), () async {
      await seed(medicines: 1);
      final med = (await MedicineCleanStorageService.getAllMedicines()).single;
      final t = await measure(
          tester, NunitoMedicationDetailScreen(medicine: med));

      expect(
        t['medicine_logs'] ?? 0,
        1,
        reason: 'medicine_logs was read ${t['medicine_logs']} times for one '
            'detail open. Measured: 3 when the history list, the refill/'
            'insight engines and getAdherenceStatsForMedicine each pulled '
            'their own copy — and 0 if the screen never loaded, which is why '
            'this is an equality. Full tally: $t',
      );
      expect(
        t['enhanced_medicines'] ?? 0,
        1,
        reason: 'enhanced_medicines was read ${t['enhanced_medicines']} times '
            'for one detail open. Measured: 2 — the screen loaded the list, '
            'and getAdherenceStatsForMedicine re-read the row it was already '
            'looking at because no `medicine:` was passed. Full tally: $t',
      );
    });
  });

  testWidgets('one adherence-report open reads each table once',
      (tester) async {
    await withClock(Clock.fixed(fixedNow), () async {
      await seed();
      final t = await measure(tester, const NunitoAdherenceReportScreen());

      expect(
        t['medicine_logs'] ?? 0,
        1,
        reason: 'medicine_logs was read ${t['medicine_logs']} times for one '
            'report open. Measured: 4 when _loadData, getAdherenceStats, '
            'getCurrentStreak and _calculateDailyStats each read the window '
            'themselves — and 0 if the screen never loaded. Full tally: $t',
      );
      expect(
        t['enhanced_medicines'] ?? 0,
        1,
        reason: 'enhanced_medicines was read ${t['enhanced_medicines']} times '
            'for one report open. Measured: 2 — the screen loads the list and '
            'getCurrentStreak loaded it again. Full tally: $t',
      );
    });
  });
}
