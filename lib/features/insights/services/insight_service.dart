import '../../../core/ai/insight.dart';
import '../../../core/ai/insight_engine.dart';
import '../../../core/ai/vitals_pattern_detector.dart';
import '../../../core/ai/adherence_analyzer.dart';
import '../../../core/ai/streak_engine.dart';
import '../../../core/ai/refill_predictor.dart';
import '../../../core/ai/hydration_pacer.dart';
import '../../../core/ai/focus_insights.dart';
import '../../medication/services/medicine_storage_service.dart';
import '../../medication/services/vitals_storage_service.dart';
import '../../water/services/water_service.dart';
import '../../focus/services/focus_service.dart';

/// Gathers the top deterministic insight from every feature and returns them
/// ranked (urgent → good) for the Insights hub / proactive nudges. Reads the
/// existing storage services; each feature is independently guarded so one
/// failure can't blank the hub. All on-device, offline, free.
class InsightService {
  const InsightService._();

  static Future<List<Insight>> gatherAll() async {
    final out = <Insight?>[];

    // Water — today's intake vs goal + pace + streak.
    try {
      final t = WaterService.getTodayData();
      final now = DateTime.now();
      final pace = HydrationPacer.compute(
        intakeMl: t.effectiveHydrationMl,
        goalMl: t.dailyGoalMl,
        nowMinutes: now.hour * 60 + now.minute,
      );
      out.add(InsightEngine.water(
        intakeMl: t.effectiveHydrationMl,
        goalMl: t.dailyGoalMl,
        streakDays: WaterService.getCurrentStreak(),
        behind: pace.behind,
        deficitMl: pace.deficitMl,
      ));
    } catch (_) {}

    // Focus — best hour / completion / streak.
    try {
      final fs = FocusService();
      final refs = fs.sessions
          .map((s) => FocusSessionRef(
              startHour: s.startedAt.hour,
              minutes: s.actualMinutes,
              completed: s.wasCompleted))
          .toList();
      out.add(InsightEngine.focus(
        bestFocusHour: FocusInsights.bestFocusHour(refs),
        completionRate: FocusInsights.completionRate(refs),
        sessionCount: refs.length,
        streakDays: fs.stats.currentStreak,
      ));
    } catch (_) {}

    // Vitals — BP + glucose pattern detection.
    try {
      final bp = await VitalsStorageService.getAllBp();
      out.add(InsightEngine.bloodPressure(bp
          .map((r) => BpPoint(at: r.takenAt, systolic: r.systolic, diastolic: r.diastolic))
          .toList()));
    } catch (_) {}
    try {
      final gl = await VitalsStorageService.getAllGlucose();
      out.add(InsightEngine.bloodSugar(gl
          .map((r) => GlucosePoint(at: r.takenAt, mgdl: r.valueMgdl, context: r.context))
          .toList()));
    } catch (_) {}

    // Medicine — adherence + streak (all logs) + lowest days-of-supply.
    try {
      final logs = await MedicineCleanStorageService.getAllLogs();
      final history = logs
          .where((l) => l.isTaken || l.isMissed || l.isSkipped)
          .map((l) => DoseEvent(
                l.scheduledTime,
                l.isTaken
                    ? DoseOutcome.taken
                    : (l.isMissed ? DoseOutcome.missed : DoseOutcome.skipped),
              ))
          .toList();
      final adherence = history.isEmpty ? null : AdherenceAnalyzer.adherence(history);
      final takenDays = logs
          .where((l) => l.isTaken)
          .map((l) => DateTime(l.scheduledTime.year, l.scheduledTime.month, l.scheduledTime.day))
          .toSet();
      final streak = StreakEngine.compute(completedDays: takenDays, today: DateTime.now());

      int? minSupply;
      final meds = await MedicineCleanStorageService.getAllMedicines();
      for (final m in meds) {
        if (m.currentStock == null) continue;
        final taken =
            (await MedicineCleanStorageService.getLogsForMedicine(m.id))
                .where((l) => l.isTaken)
                .toList();
        final pred = RefillPredictor.predict(
          currentStock: m.currentStock!,
          doseTimes: taken.map((l) => l.actionTime ?? l.scheduledTime).toList(),
          doseAmounts: taken.map((l) => l.dosageTaken).toList(),
          windowDays: 21,
        );
        final d = pred.daysRemaining;
        if (d != null && (minSupply == null || d < minSupply)) minSupply = d;
      }

      out.add(InsightEngine.medicine(
        adherence: adherence,
        streakDays: streak.current,
        daysOfSupply: minSupply,
      ));
    } catch (_) {}

    return InsightEngine.rankAll(out);
  }
}
