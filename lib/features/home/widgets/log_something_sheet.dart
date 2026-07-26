import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/app/app_widgets.dart';
import '../../medication/services/today_schedule_service.dart';
import '../../medication/screens/nunito_take_medication_sheet.dart';
import '../../medication/screens/vitals/blood_pressure_screen.dart';
import '../../medication/screens/vitals/blood_sugar_screen.dart';
import '../../water/services/water_service.dart';
import '../../water/models/beverage_type.dart';
import '../../steps/services/step_service.dart';
import '../../steps/widgets/step_manual_entry_sheet.dart';
import '../../sleep/services/sleep_service.dart';
import '../../sleep/widgets/sleep_manual_log_sheet.dart';
import '../../period/widgets/log_today_sheet.dart';

/// One unified "Log something" entry point — the center ➕ action and the Today
/// quick-log chips both route through here, so there's a single mental model for
/// capture. Each option reuses that feature's existing sheet/flow.
class LogSomethingSheet {
  const LogSomethingSheet._();

  static Future<void> show(BuildContext context) {
    final ext = AppColorsExt.of(context);
    return AppBottomSheet.show<void>(
      context,
      title: 'Log something',
      icon: Symbols.add_rounded,
      accent: ext.brand,
      builder: (ctx) {
        void run(void Function() action) {
          Navigator.pop(ctx);
          action();
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _tile(ext, Symbols.medication_rounded, ext.medicine, 'Medicine dose',
                'Take a scheduled dose', () => run(() => logDose(context))),
            _tile(ext, Symbols.water_drop_rounded, ext.water, 'Water',
                'Add a drink', () => run(() => logWater(context))),
            _tile(ext, Symbols.monitor_heart_rounded, ext.medicine,
                'Blood pressure', 'Log a reading',
                () => run(() => logBloodPressure(context))),
            _tile(ext, Symbols.bloodtype_rounded, ext.medicine, 'Blood sugar',
                'Log a glucose reading',
                () => run(() => logBloodSugar(context))),
            _tile(ext, Symbols.directions_walk_rounded, ext.steps, 'Steps',
                'Add steps', () => run(() => logSteps(context))),
            _tile(ext, Symbols.bedtime_rounded, ext.sleep, 'Sleep',
                'Log last night', () => run(() => logSleep(context))),
            _tile(ext, Symbols.favorite_rounded, ext.period, 'Period / mood',
                'Log today', () => run(() => logPeriod(context))),
            const SizedBox(height: AppSpacing.sm),
          ],
        );
      },
    );
  }

  static Widget _tile(AppColorsExt ext, IconData icon, AccentSwatch accent,
          String title, String subtitle, VoidCallback onTap) =>
      AppListTile(
        icon: icon,
        iconColor: ext.mark(accent),
        title: title,
        subtitle: subtitle,
        onTap: onTap,
      );

  // --- Individual log actions (also used directly by the Today quick-log chips).

  /// Pick a pending dose (or jump straight in if only one) → take sheet.
  static Future<void> logDose(BuildContext context) async {
    final now = DateTime.now();
    final doses = await TodayScheduleService.getTodaysDoses(now);
    final pending = doses.where((d) => !d.isTaken && !d.isSkipped).toList()
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    if (!context.mounted) return;
    if (pending.isEmpty) {
      context.toastInfo('No doses due right now');
      return;
    }
    if (pending.length == 1) {
      await _openTake(context, pending.first);
      return;
    }
    final ext = AppColorsExt.of(context);
    await AppBottomSheet.show<void>(
      context,
      title: 'Which dose?',
      icon: Symbols.medication_rounded,
      accent: ext.medicine,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final d in pending)
            AppListTile(
              icon: Symbols.medication_rounded,
              iconColor: ext.mark(ext.medicine),
              title: d.medicine.name,
              subtitle: DateFormat('h:mm a').format(d.scheduledTime),
              onTap: () {
                Navigator.pop(ctx);
                _openTake(context, d);
              },
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  static Future<void> _openTake(BuildContext context, ScheduledDose dose) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NunitoTakeMedicationSheet(
        medicine: dose.medicine,
        scheduledTime: dose.scheduledTime,
      ),
    );
  }

  static Future<void> logWater(BuildContext context) async {
    final beverage =
        WaterService.getBeverage('water') ?? BeverageType.defaultBeverages.first;
    await WaterService.addWaterLog(amountMl: 250, beverage: beverage);
    if (context.mounted) {
      context.toastSuccess('Added 250 ml of water');
    }
  }

  static Future<void> logBloodPressure(BuildContext context) =>
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const BloodPressureScreen()));

  static Future<void> logBloodSugar(BuildContext context) =>
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const BloodSugarScreen()));

  static Future<void> logSteps(BuildContext context) => StepManualEntrySheet.show(
        context,
        onSubmit: (steps, note, date) =>
            StepService.addManualStepsForDate(date, steps, note: note),
      );

  static Future<void> logSleep(BuildContext context) async {
    final result = await SleepManualLogSheet.show(context,
        schedule: SleepService.getSchedule());
    if (result != null) {
      await SleepService.logManualSession(
        bedtime: result.bedtime,
        wakeTime: result.wakeTime,
        quality: result.quality,
        note: result.note,
      );
    }
  }

  static Future<void> logPeriod(BuildContext context) =>
      LogTodaySheet.show(context);
}
