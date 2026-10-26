import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/services/app_shortcuts.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_log.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/today_schedule_service.dart';

void main() {
  final med = EnhancedMedicine(
    id: 'm1',
    name: 'Metformin',
    strength: '500mg',
    dosageForm: DosageForm.tablet,
    dosageAmount: 1,
    schedule: MedicineSchedule(
      frequencyType: FrequencyType.twiceDaily,
      times: [ScheduledTime(hour: 8, minute: 0), ScheduledTime(hour: 20, minute: 0)],
    ),
  );

  ScheduledDose dose(DateTime at, {MedicineLog? log, int idx = 0}) =>
      ScheduledDose(medicine: med, scheduledTime: at, timeIndex: idx, log: log);

  final eight = DateTime(2026, 1, 1, 8, 0);

  List<AppShortcut> plan(List<ScheduledDose> doses, DateTime now,
          {bool restricted = false, bool hide = false}) =>
      AppShortcuts.plan(
          doses: doses,
          now: now,
          waterRestricted: restricted,
          hideMedicineNames: hide);

  group('which dose is offered', () {
    test('a dose due now is offered, with its name and time', () {
      final p = plan([dose(eight)], DateTime(2026, 1, 1, 8, 5));
      expect(p.first.title, 'Take Metformin 8:00 AM');
    });

    test('the window is 1 h ahead to 3 h late, inclusive', () {
      bool offered(DateTime now) => AppShortcuts.dueDose([dose(eight)], now) != null;
      expect(offered(DateTime(2026, 1, 1, 7, 0)), isTrue);
      expect(offered(DateTime(2026, 1, 1, 6, 59)), isFalse);
      expect(offered(DateTime(2026, 1, 1, 11, 0)), isTrue);
      expect(offered(DateTime(2026, 1, 1, 11, 1)), isFalse);
    });

    test('taken, skipped and missed doses are never offered', () {
      final now = DateTime(2026, 1, 1, 8, 5);
      final taken = MedicineLog.taken(id: 'a', medicineId: 'm1', scheduledTime: eight);
      final skipped = MedicineLog.skipped(
          id: 'b',
          medicineId: 'm1',
          scheduledTime: eight,
          reason: SkipReason.values.first);
      final missed = MedicineLog.missed(id: 'c', medicineId: 'm1', scheduledTime: eight);
      for (final log in [taken, skipped, missed]) {
        expect(AppShortcuts.dueDose([dose(eight, log: log)], now), isNull,
            reason: log.status.name);
      }
    });

    test('the earliest due dose wins', () {
      final nine = DateTime(2026, 1, 1, 9, 0);
      final r = AppShortcuts.dueDose(
          [dose(nine, idx: 1), dose(eight)], DateTime(2026, 1, 1, 8, 30));
      expect(r!.scheduledTime, eight);
    });
  });

  group('the shortcut list', () {
    test('no dose due: water, blood pressure, focus, in that order', () {
      final p = plan([dose(eight)], DateTime(2026, 1, 1, 15, 0));
      expect(p.map((s) => s.title),
          ['Log water', 'Log blood pressure', 'Start focus']);
    });

    test('the dose slot comes first when one is due', () {
      final p = plan([dose(eight)], DateTime(2026, 1, 1, 8, 5));
      expect(p.length, 4);
      expect(p.first.title, startsWith('Take '));
    });

    test('a fluid limit removes Log water', () {
      final p = plan([], DateTime(2026, 1, 1, 15, 0), restricted: true);
      expect(p.map((s) => s.title), ['Log blood pressure', 'Start focus']);
    });

    test('app lock keeps the medicine name off the launcher menu', () {
      final p = plan([dose(eight)], DateTime(2026, 1, 1, 8, 5), hide: true);
      expect(p.first.title, 'Take next dose');
      expect(p.any((s) => s.title.contains('Metformin')), isFalse);
    });

    test('never more than 4, the launcher minimum', () {
      expect(plan([dose(eight)], DateTime(2026, 1, 1, 8, 5)).length,
          lessThanOrEqualTo(4));
    });
  });

  group('AppShortcutTarget round trip', () {
    test('static shortcuts parse back to their kind', () {
      expect(AppShortcutTarget.parse(AppShortcutTarget.forWater())!.kind,
          AppShortcutKind.logWater);
      expect(AppShortcutTarget.parse(AppShortcutTarget.forBloodPressure())!.kind,
          AppShortcutKind.logBloodPressure);
      expect(AppShortcutTarget.parse(AppShortcutTarget.forFocus())!.kind,
          AppShortcutKind.startFocus);
    });

    test('a dose shortcut carries its exact slot', () {
      final t = AppShortcutTarget.parse(AppShortcutTarget.forDose('m1', eight))!;
      expect(t.kind, AppShortcutKind.takeDose);
      expect(t.medicineId, 'm1');
      expect(t.scheduledTime, eight);
    });

    test('strings this app did not create are ignored', () {
      expect(AppShortcutTarget.parse('nonsense'), isNull);
      expect(AppShortcutTarget.parse('take_dose'), isNull);
      expect(AppShortcutTarget.parse('take_dose||2026-01-01T08:00:00'), isNull);
      expect(AppShortcutTarget.parse('take_dose|m1|not-a-date'), isNull);
    });
  });
}
