import '../../../core/health/insight.dart';
import '../../../core/health/insight_engine.dart';
import '../../../core/health/vitals_pattern_detector.dart';
import '../../../core/health/adherence_analyzer.dart';
import '../../../core/health/streak_engine.dart';
import '../../../core/health/refill_predictor.dart';
import '../../../core/health/hydration_pacer.dart';
import '../../../core/health/focus_insights.dart';
import '../../../core/health/correlation_engine.dart';
import '../../medication/services/medicine_storage_service.dart';
import '../../medication/services/vitals_storage_service.dart';
import '../../water/services/water_service.dart';
import '../../focus/services/focus_service.dart';
import '../../period/services/period_service.dart';
import '../../period/models/cycle_prediction.dart';
import '../../steps/services/step_service.dart';
import '../../sleep/services/sleep_service.dart';

/// Gathers the top deterministic insight from every feature and returns them
/// ranked (urgent → good) for the Insights hub / proactive nudges. Reads the
/// existing storage services; each feature is independently guarded so one
/// failure can't blank the hub. All on-device, offline, free.
class InsightService {
  const InsightService._();

  /// Best-effort table read: one failing table must not take the whole
  /// insight set down with it.
  static Future<List<T>> _tryList<T>(Future<List<T>> Function() read) async {
    try {
      return await read();
    } catch (_) {
      return <T>[];
    }
  }

  static Future<List<Insight>> gatherAll() async {
    final out = <Insight?>[];

    // Fetch the shared tables ONCE, up front.
    //
    // This method runs from `ProactiveNudge.initState`, i.e. on the first
    // frame of the tab the user lands on. It used to read `vitals_bp` TWICE
    // (once for the pattern engine, once again for the correlation engine) and
    // issue one `getLogsForMedicine` per medicine on top of a full
    // `getAllLogs()` — so the cost grew with both row count and medicine
    // count, on the UI isolate, before anything was on screen.
    //
    // Reads are best-effort: a failure in one table must not take the whole
    // insight set down, which is why each is caught independently.
    final allBp = await _tryList(VitalsStorageService.getAllBp);
    final allLogsRaw = await _tryList(MedicineCleanStorageService.getAllLogs);

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
      final bp = allBp;
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
      // Deduped: a dose slot with more than one row (e.g. reconciled as
      // missed, then actually taken) would otherwise be counted once per row
      // instead of once per dose, skewing adherence/streak/miss-risk exactly
      // the way dedupeByDose's own doc warns against — the RefillPredictor
      // loop below already does this correctly; this earlier computation in
      // the same method had not.
      final logs = MedicineCleanStorageService.dedupeByDose(allLogsRaw);
      final history = logs
          .where((l) => l.countsAsTaken || l.isMissed || l.isSkipped)
          .map((l) => DoseEvent(
                l.scheduledTime,
                // A pre-logged dose was physically taken — same outcome as taken.
                l.countsAsTaken
                    ? DoseOutcome.taken
                    : (l.isMissed ? DoseOutcome.missed : DoseOutcome.skipped),
              ))
          .toList();
      final adherence = history.isEmpty ? null : AdherenceAnalyzer.adherence(history);
      final takenDays = logs
          .where((l) => l.countsAsTaken)
          .map((l) => DateTime(l.scheduledTime.year, l.scheduledTime.month, l.scheduledTime.day))
          .toSet();
      final streak = StreakEngine.compute(completedDays: takenDays, today: DateTime.now());

      int? minSupply;
      final meds = await MedicineCleanStorageService.getAllMedicines();
      for (final m in meds) {
        if (m.currentStock == null) continue;
        // Deduped per slot: a duplicated taken row would overstate the
        // consumption rate and forecast an early run-out.
        // Filter the logs already in hand rather than issuing a query per
        // medicine — this loop was the N+1 in this method.
        final taken = MedicineCleanStorageService.dedupeByDose(
                allLogsRaw.where((l) => l.medicineId == m.id))
            .where((l) => l.countsAsTaken)
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

      // Predictive miss-risk: find the worst (weekday, hour) dose slot in the
      // user's own history so the engine can nudge "this dose slot is missed
      // more than most" — turns the medicine insight from purely descriptive
      // into predictive, on-device.
      var missRisk = 0.0;
      final slots = history
          .map((e) => '${e.scheduled.weekday}-${e.scheduled.hour}')
          .toSet();
      for (final s in slots) {
        final parts = s.split('-');
        final r = AdherenceAnalyzer.missRisk(
          weekday: int.parse(parts[0]),
          hour: int.parse(parts[1]),
          history: history,
        );
        if (r > missRisk) missRisk = r;
      }

      out.add(InsightEngine.medicine(
        adherence: adherence,
        missRisk: missRisk,
        streakDays: streak.current,
        daysOfSupply: minSupply,
      ));
    } catch (_) {}

    // Period — next-period / fertile-window estimate / irregular / late.
    try {
      final p = PeriodService.getPrediction();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      bool inFertile = false;
      if (p.fertileStart != null && p.fertileEnd != null) {
        inFertile = !today.isBefore(p.fertileStart!) && !today.isAfter(p.fertileEnd!);
      }
      final isLate = p.state == CycleState.late;
      int lateDays = 0;
      if (isLate && p.predictedStart != null) {
        final ps = p.predictedStart!;
        lateDays = today.difference(DateTime(ps.year, ps.month, ps.day)).inDays;
        if (lateDays < 1) lateDays = 1;
      }
      out.add(InsightEngine.period(
        daysUntilNextPeriod: p.daysUntilNextPeriod,
        inFertileWindow: inFertile,
        isLate: isLate,
        lateDays: lateDays,
        irregular: p.state == CycleState.irregular,
        pregnancyMode: p.state == CycleState.pregnancy,
      ));
    } catch (_) {}

    // Steps — today vs goal + streak.
    try {
      final t = StepService.getTodayData();
      out.add(InsightEngine.steps(
        steps: t.effectiveSteps,
        goal: t.goalSteps,
        streakDays: StepService.getCurrentStreak(),
      ));
    } catch (_) {}

    // Sleep — last night vs target + debt + regularity, guarded by how many of
    // the last 7 nights are actually logged (so an empty week can't fabricate a
    // huge debt), plus a "last night vs your average" comparison.
    try {
      final last = SleepService.getLastNight();
      final trend = SleepService.getWeeklyTrend();
      final logged = trend.where((d) => d.asleepMinutes > 0).toList();
      final loggedNights = logged.length;
      final avgMinutes = logged.isEmpty
          ? 0
          : (logged.fold<int>(0, (a, d) => a + d.asleepMinutes) / logged.length)
              .round();
      final lastNight = last?.asleepMinutes ?? 0;
      out.add(InsightEngine.sleep(
        lastNightMinutes: lastNight,
        targetMinutes: SleepService.getSchedule().targetMinutes,
        debtMinutes: SleepService.sleepDebtMinutes(),
        regularity: SleepService.regularityIndex(),
        loggedNights: loggedNights,
      ));
      out.add(InsightEngine.sleepVsAverage(
        lastNightMinutes: lastNight,
        avgMinutes: avgMinutes,
        nightsLogged: loggedNights,
      ));
    } catch (_) {}

    // Water & Steps week-over-week trend — the last 7 complete days vs the 7
    // before them (today excluded so a partial day never skews it). Needs ≥3
    // logged days in each window to count as a real trend.
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      List<int> waterWindow(int startAgo, int endAgoExclusive) {
        var total = 0, days = 0;
        for (var i = startAgo; i < endAgoExclusive; i++) {
          final d = WaterService.getDataForDate(today.subtract(Duration(days: i)));
          final ml = d?.effectiveHydrationMl ?? 0;
          if (ml > 0) {
            total += ml;
            days++;
          }
        }
        return [total, days];
      }
      final tw = waterWindow(1, 8);
      final lw = waterWindow(8, 15);
      if (tw[1] >= 3 && lw[1] >= 3) {
        out.add(InsightEngine.trend(
          feature: InsightFeature.water,
          id: 'water_trend',
          label: 'water',
          thisWeek: tw[0],
          lastWeek: lw[0],
          higherIsBetter: true,
        ));
      }
    } catch (_) {}
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      List<int> stepWindow(int startAgo, int endAgoExclusive) {
        var total = 0, days = 0;
        for (var i = startAgo; i < endAgoExclusive; i++) {
          final d = StepService.getDataForDate(today.subtract(Duration(days: i)));
          final s = d?.effectiveSteps ?? 0;
          if (s > 0) {
            total += s;
            days++;
          }
        }
        return [total, days];
      }
      final tw = stepWindow(1, 8);
      final lw = stepWindow(8, 15);
      if (tw[1] >= 3 && lw[1] >= 3) {
        out.add(InsightEngine.trend(
          feature: InsightFeature.steps,
          id: 'steps_trend',
          label: 'steps',
          thisWeek: tw[0],
          lastWeek: lw[0],
          higherIsBetter: true,
        ));
      }
    } catch (_) {}

    // Cross-cutting — mood/BP vs same-day medication adherence. Both need a
    // day-by-day adherent/non-adherent split, built once and reused.
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      const lookbackDays = 30;
      final start = today.subtract(const Duration(days: lookbackDays - 1));

      // ONE pair of queries for the whole window. This used to await
      // getDailySummaryAsync per day — 30 iterations x 2 round trips (logs +
      // a full getAllMedicines() that re-decodes every schedule JSON) = ~60
      // serialized queries on the UI isolate, paid on every weekly-recap open
      // even for a user with almost no data.
      final adherentByDay = <String, bool>{};
      final summaries = await MedicineCleanStorageService
          .getDailySummariesForRange(start, today);
      for (final entry in summaries.entries) {
        // nothing due that day — not comparable
        if (entry.value.totalScheduled == 0) continue;
        adherentByDay[_dayKey(entry.key)] = entry.value.isComplete;
      }

      if (adherentByDay.isNotEmpty) {
        try {
          final moodByDay = <String, List<double>>{};
          for (final m in await VitalsStorageService.getAllMood()) {
            (moodByDay[_dayKey(m.takenAt)] ??= []).add(m.moodIndex.toDouble());
          }
          final moodDays = <DayMetric>[];
          for (final entry in adherentByDay.entries) {
            final vals = moodByDay[entry.key];
            if (vals == null || vals.isEmpty) continue;
            moodDays.add(DayMetric(
              day: DateTime.parse(entry.key),
              adherent: entry.value,
              value: vals.reduce((a, b) => a + b) / vals.length,
            ));
          }
          out.add(CorrelationEngine.moodVsAdherence(moodDays));
        } catch (_) {}

        try {
          final bpByDay = <String, List<int>>{};
          for (final r in allBp) {
            (bpByDay[_dayKey(r.takenAt)] ??= []).add(r.systolic);
          }
          final bpDays = <DayMetric>[];
          for (final entry in adherentByDay.entries) {
            final vals = bpByDay[entry.key];
            if (vals == null || vals.isEmpty) continue;
            bpDays.add(DayMetric(
              day: DateTime.parse(entry.key),
              adherent: entry.value,
              value: vals.reduce((a, b) => a + b) / vals.length,
            ));
          }
          out.add(CorrelationEngine.bloodPressureVsAdherence(bpDays));
        } catch (_) {}
      }
    } catch (_) {}

    return InsightEngine.rankAll(out);
  }

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
