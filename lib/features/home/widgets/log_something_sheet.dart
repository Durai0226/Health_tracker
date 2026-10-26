import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:intl/intl.dart';

import '../../../core/design/app_design.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../medication/services/today_schedule_service.dart';
import '../../medication/services/dose_undo.dart';
import '../../medication/screens/nunito_take_medication_sheet.dart';
import '../../medication/screens/vitals/blood_pressure_screen.dart';
import '../../medication/screens/vitals/blood_sugar_screen.dart';
import '../../medication/screens/vitals/weight_screen.dart';
import '../../medication/screens/vitals/mood_screen.dart';
import '../../water/services/water_service.dart';
import '../../water/models/beverage_type.dart';
import '../../steps/services/step_service.dart';
import '../../steps/widgets/step_manual_entry_sheet.dart';
import '../../sleep/services/sleep_service.dart';
import '../../sleep/widgets/sleep_manual_log_sheet.dart';
import '../../period/widgets/log_today_sheet.dart';
import '../../steps/utils/step_format.dart';
import '../../steps/models/step_manual_entry.dart';
import '../../sleep/models/sleep_stage.dart' show SleepSource;
import '../../period/services/period_service.dart';
import '../../period/models/period_day.dart';
import '../../focus/screens/focus_screen.dart';
import '../../reminders/screens/add_reminder_screen.dart';
import '../../diary/screens/diary_entry_screen.dart';
import '../../medication/services/medicine_storage_service.dart';
import '../../medication/models/enhanced_medicine.dart';

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
            _tile(ext, Symbols.monitor_weight_rounded, ext.medicine, 'Weight',
                'Log a reading', () => run(() => logWeight(context))),
            _tile(ext, Symbols.mood_rounded, ext.medicine, 'Mood',
                'Log how you feel', () => run(() => logMood(context))),
            _tile(ext, Symbols.directions_walk_rounded, ext.steps, 'Steps',
                'Add steps', () => run(() => logSteps(context))),
            _tile(ext, Symbols.bedtime_rounded, ext.sleep, 'Sleep',
                'Log last night', () => run(() => logSleep(context))),
            // 'Period', not 'Period / mood'.
            //
            // This row opens [LogTodaySheet], which writes `PeriodDay.mood` —
            // a 1..5 field on the cycle day. The 'Mood' row six above it opens
            // [MoodScreen], which writes a `MoodEntry`: the tracker behind the
            // Mood screen's average and the Mood trend card. Two different
            // stores, and only one of them is what "log my mood" means.
            //
            // Advertising mood in both titles sent anyone who read this row
            // first into the wrong one, where their entry would never show up
            // on the screen they went looking for it on.
            _tile(ext, Symbols.favorite_rounded, ext.period, 'Period',
                'Log flow, symptoms and cycle notes',
                () => run(() => logPeriod(context))),
            // The three captures that were missing: a focus session, a reminder
            // and a diary entry each had a screen and no way in from here.
            _tile(ext, Symbols.timer_rounded, ext.focus, 'Focus session',
                'Start a timer', () => run(() => startFocus(context))),
            _tile(ext, Symbols.notifications_active_rounded, ext.reminders,
                'Reminder', 'Set one for later',
                () => run(() => addReminder(context))),
            _tile(ext, Symbols.edit_note_rounded, ext.brand, 'Diary entry',
                'Write something down', () => run(() => writeDiary(context))),
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
    final pending = doses
        .where((d) => !d.isTaken && !d.isSkipped && !d.isPreLogged)
        .toList()
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    // As-needed medicines have no scheduled slot, so they never appear in
    // `pending` — and this sheet is the one place that offers to log a dose, so
    // they could only be logged from their own detail page.
    final asNeeded = (await MedicineCleanStorageService.getAllMedicines())
        .where((m) => m.isActive && !m.isArchived && m.schedule.isPRN)
        .toList();
    if (!context.mounted) return;
    if (pending.isEmpty && asNeeded.isEmpty) {
      context.toastInfo('No doses due right now');
      return;
    }
    if (pending.length == 1 && asNeeded.isEmpty) {
      await _openTake(context, pending.first);
      return;
    }
    if (pending.isEmpty && asNeeded.length == 1) {
      await _openTakeNow(context, asNeeded.first);
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
          for (final m in asNeeded)
            AppListTile(
              icon: Symbols.medication_rounded,
              iconColor: ext.mark(ext.medicine),
              title: m.name,
              subtitle: 'As needed',
              onTap: () {
                Navigator.pop(ctx);
                _openTakeNow(context, m);
              },
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  /// Log an as-needed [medicine] taken now. Same sheet and same Undo as a
  /// scheduled dose; the "slot" is the moment of taking.
  static Future<void> _openTakeNow(
      BuildContext context, EnhancedMedicine medicine) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NunitoTakeMedicationSheet(
        medicine: medicine,
        scheduledTime: DateTime.now(),
      ),
    );
    if (!context.mounted) return;
    DoseUndo.confirmSheetResult(context, result, medicine.name);
  }

  /// Show the take sheet and confirm whatever it wrote with an Undo — quick-log
  /// is the fastest way into a dose, so it's the one that most needs a way back
  /// out. [DoseUndo] also reverses the stock decrement, which deleting the log
  /// alone would not.
  static Future<void> _openTake(BuildContext context, ScheduledDose dose) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NunitoTakeMedicationSheet(
        medicine: dose.medicine,
        scheduledTime: dose.scheduledTime,
      ),
    );
    if (!context.mounted) return;
    DoseUndo.confirmSheetResult(context, result, dose.medicine.name);
  }

  static Future<void> logWater(BuildContext context) async {
    final beverage =
        WaterService.getBeverage('water') ?? BeverageType.defaultBeverages.first;
    // addWaterLog returns the updated day whose last log is the one just added —
    // capture its id so this one-tap write can be taken back (mirrors the water
    // dashboard's own quick-add Undo).
    final updated =
        await WaterService.addWaterLog(amountMl: 250, beverage: beverage);
    final addedLogId = updated.logs.isNotEmpty ? updated.logs.last.id : null;
    if (!context.mounted) return;
    context.toastSuccess(
      'Added 250 ml of water',
      action: addedLogId == null
          ? null
          : AppToastAction(
              label: 'Undo',
              onPressed: () async {
                await WaterService.removeWaterLog(addedLogId);
              },
            ),
    );
  }

  /// The four vitals screens, opened the way the Health hub opens them.
  ///
  /// These pushed bare `MaterialPageRoute`s, so the screens arrived with no
  /// `AccentScope` and every component on them that resolves its own swatch
  /// fell back to `FeatureAccent.brand` — while the SAME screen reached from
  /// the Health hub arrives inside `AccentScope(FeatureAccent.medicine)`
  /// (`health_browse_screen.dart:68-85`). One screen, two colours, decided by
  /// which door the user came through. `_vital` makes both doors agree.
  static Future<void> _vital(BuildContext context, Widget screen) =>
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AccentScope(
            feature: FeatureAccent.medicine,
            child: screen,
          ),
        ),
      );

  static Future<void> logBloodPressure(BuildContext context) =>
      _vital(context, const BloodPressureScreen());

  static Future<void> logBloodSugar(BuildContext context) =>
      _vital(context, const BloodSugarScreen());

  static Future<void> logWeight(BuildContext context) =>
      _vital(context, const WeightScreen());

  static Future<void> logMood(BuildContext context) =>
      _vital(context, const MoodScreen());

  /// The manual step entries on the last week of days, by id. The sheet can only
  /// write to that window, so it is also all the confirmation has to compare.
  static Map<String, StepManualEntry> _manualStepEntries() {
    final today = DateTime.now();
    return {
      for (final d in StepService.getDataForRange(
          DateTime(today.year, today.month, today.day - 8), today))
        for (final e in d.manualEntries) e.id: e,
    };
  }

  /// Log steps, then say what was added with one tap of regret. Steps, sleep and
  /// period were the three quick-logs that wrote silently and could only be
  /// undone by finding the entry again; water and doses already confirmed.
  static Future<void> logSteps(BuildContext context) async {
    final before = _manualStepEntries().keys.toSet();
    await StepManualEntrySheet.show(
      context,
      onSubmit: (steps, note, date) =>
          StepService.addManualStepsForDate(date, steps, note: note),
    );
    final added = [
      for (final e in _manualStepEntries().values)
        if (!before.contains(e.id)) e,
    ];
    if (added.isEmpty || !context.mounted) return;
    final total = added.fold<int>(0, (sum, e) => sum + e.steps);
    context.toastSuccess(
      total >= 0
          ? 'Added ${formatThousands(total)} steps'
          : 'Removed ${formatThousands(-total)} steps',
      action: AppToastAction(
        label: 'Undo',
        onPressed: () async {
          for (final e in added) {
            await StepService.removeManualEntry(e.id);
          }
        },
      ),
    );
  }

  static Future<void> logSleep(BuildContext context) async {
    final result = await SleepManualLogSheet.show(context,
        schedule: SleepService.getSchedule());
    if (result == null) return;

    // A second hand-logged night for the same date REPLACES the first, so Undo
    // has to put the first back rather than delete the night.
    final wakeDay = result.wakeTime;
    final previous = SleepService.getForDate(wakeDay);
    final saved = await SleepService.logManualSession(
      bedtime: result.bedtime,
      wakeTime: result.wakeTime,
      quality: result.quality,
      note: result.note,
    );
    if (!context.mounted) return;
    context.toastSuccess(
      'Sleep logged',
      action: AppToastAction(
        label: 'Undo',
        onPressed: () async {
          await SleepService.deleteSession(saved.id);
          final p = previous;
          if (p != null && p.source == SleepSource.manual) {
            await SleepService.restoreSession(p);
          }
        },
      ),
    );
  }

  static Future<void> startFocus(BuildContext context) => Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => const AccentScope(
              feature: FeatureAccent.focus, child: FocusScreen()),
        ),
      );

  static Future<void> addReminder(BuildContext context) => Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => const AddReminderScreen()),
      );

  static Future<void> writeDiary(BuildContext context) => Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => const DiaryEntryScreen()),
      );

  static Future<void> logPeriod(BuildContext context) async {
    final before = Map<String, PeriodDay>.of(PeriodService.days);
    await LogTodaySheet.show(context);
    final after = PeriodService.days;
    // Whichever days the sheet wrote: new, or changed from what they were.
    final changed = [
      for (final e in after.entries)
        if (before[e.key] != null
            ? before[e.key]!.updatedAt != e.value.updatedAt
            : true)
          e.key,
    ];
    if (changed.isEmpty || !context.mounted) return;
    context.toastSuccess(
      'Period log saved',
      action: AppToastAction(
        label: 'Undo',
        onPressed: () async {
          for (final id in changed) {
            final prior = before[id];
            if (prior == null) {
              await PeriodService.deleteDay(id);
            } else {
              await PeriodService.logDay(prior);
            }
          }
        },
      ),
    );
  }
}
