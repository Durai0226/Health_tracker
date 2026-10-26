import '../../../core/health/insight.dart';
import '../../../core/health/insight_engine.dart';
import '../../../core/health/vitals_pattern_detector.dart';
import '../../../core/health/adherence_analyzer.dart';
import '../../../core/health/streak_engine.dart';
import '../../../core/health/refill_predictor.dart';
import '../../../core/health/hydration_pacer.dart';
import '../../../core/health/focus_insights.dart';
import '../../../core/health/correlation_engine.dart';
import 'package:tablet_remainder/core/health/cycle_hydration_insight.dart';
import '../../medication/services/medicine_storage_service.dart';
import '../../medication/services/vitals_storage_service.dart';
import '../../water/services/water_service.dart';
import '../../focus/services/focus_service.dart';
import '../../period/services/period_service.dart';
import '../../period/models/cycle_prediction.dart';
import '../../steps/services/step_service.dart';
import '../../sleep/services/sleep_service.dart';
import '../../../core/utils/calendar_day.dart';
import 'package:clock/clock.dart';
import '../../medication/services/bp_sessions.dart';

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
    // BOUNDED to the last 180 days, not the whole table.
    //
    // `medicine_logs` gains a row per scheduled slot per day and is never
    // pruned, so `getAllLogs()` grew without limit — every row mapped to a
    // domain object, deduped and turned into a DoseEvent list, on the UI
    // isolate, on the first frame of the tab the user landed on. A year of
    // three-times-daily medicines is ~1,100 rows before any of that starts.
    //
    // 180 days is not arbitrary: `getStreakResult` already caps its own walk
    // there, so the streak these logs feed cannot see further back anyway, and
    // adherence and the refill consumption rate are both recent-behaviour
    // signals. Anything that genuinely needs lifetime history reads it itself.
    final insightWindowStart = dayOffset(clock.now(), -180);
    final allBp = await _tryList(VitalsStorageService.getAllBp);
    final allLogsRaw = await _tryList(
      () => MedicineCleanStorageService.getLogsForDateRange(
          insightWindowStart, clock.now()),
    );

    // Water — today's intake vs goal + pace + streak.
    try {
      final t = WaterService.getTodayData();
      final now = DateTime.now();
      final w = WaterService.wakingWindow();
      final pace = HydrationPacer.compute(
        intakeMl: t.effectiveHydrationMl,
        goalMl: t.dailyGoalMl,
        nowMinutes: now.hour * 60 + now.minute,
        wakeMinutes: w.wakeMinutes,
        sleepMinutes: w.sleepMinutes,
      );
      out.add(InsightEngine.water(
        intakeMl: t.effectiveHydrationMl,
        goalMl: t.dailyGoalMl,
        streakDays: WaterService.getCurrentStreak(),
        behind: pace.behind,
        deficitMl: pace.deficitMl,
        // Already in hand — it is passed to CycleHydrationInsight.forPhase
        // further down this same method.
        isRestricted: WaterService.isFluidRestricted,
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
        suggestedMinutes: FocusInsights.suggestedMinutes(refs),
      ));

      // Focus vs sleep. Zero extra queries: both `FocusService.sessions` and
      // `SleepService.getAllSessions()` are already in memory, which is why this
      // sits inside the existing try rather than getting its own.
      out.add(CorrelationEngine.focusVsSleep(_focusVsSleepDays(fs)));
      out.add(
          CorrelationEngine.hydrationVsSleep(_hydrationVsSleepDays()));
    } catch (_) {}

    // Vitals — BP + glucose pattern detection.
    try {
      // One point per measurement session: two readings a minute apart are one
      // measurement, so they must not count as two toward the 3-point gate or
      // double-weight a trend.
      final bp = BpSessions.collapse(allBp);
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

    // Hydration x cycle phase. Context, not a target change — see
    // CycleHydrationInsight for why no millilitres are invented here.
    try {
      out.add(CycleHydrationInsight.forPhase(
        PeriodService.getPrediction().phaseToday,
        isRestricted: WaterService.isFluidRestricted,
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
        weightedDebt: SleepService.sleepDebt(),
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
    // before them (today excluded so a partial day never skews it). Each window
    // yields [total, loggedDays] and BOTH go to the engine: it divides one by
    // the other, so a week with more days logged no longer reads as a week with
    // better behaviour. The minimum sample is the engine's
    // `InsightEngine.minTrendLoggedDays`, not a literal repeated here — a second
    // copy of the number is how the two drift apart.
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      List<int> waterWindow(int startAgo, int endAgoExclusive) {
        var total = 0, days = 0;
        for (var i = startAgo; i < endAgoExclusive; i++) {
          final d = WaterService.getDataForDate(dayOffset(today, -i));
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
      out.add(InsightEngine.trend(
        feature: InsightFeature.water,
        id: 'water_trend',
        label: 'water',
        thisWeek: tw[0],
        lastWeek: lw[0],
        thisWeekDays: tw[1],
        lastWeekDays: lw[1],
        higherIsBetter: true,
      ));
    } catch (_) {}
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      List<int> stepWindow(int startAgo, int endAgoExclusive) {
        var total = 0, days = 0;
        for (var i = startAgo; i < endAgoExclusive; i++) {
          final d = StepService.getDataForDate(dayOffset(today, -i));
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
      out.add(InsightEngine.trend(
        feature: InsightFeature.steps,
        id: 'steps_trend',
        label: 'steps',
        thisWeek: tw[0],
        lastWeek: lw[0],
        thisWeekDays: tw[1],
        lastWeekDays: lw[1],
        higherIsBetter: true,
      ));
    } catch (_) {}

    // Cross-cutting — mood/BP vs same-day medication adherence. Both need a
    // day-by-day adherent/non-adherent split, built once and reused.
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      const lookbackDays = 30;
      final start = dayOffset(today, -(lookbackDays - 1));

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
          for (final r in BpSessions.collapse(allBp)) {
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

        try {
          // Hydration against that day's adherence. Days with nothing logged
          // are excluded, not zeroed — a zero would measure app-opening, not
          // drinking.
          //
          // The two fields are read for two different questions, deliberately:
          // `totalIntakeMl` answers "did anything get logged", and
          // `effectiveHydrationMl` is the value compared. Gating on the
          // effective figure instead would drop the day a heavy drinker nets a
          // negative — the day this insight most needs to see — and every other
          // water surface (the trend window above, trends_data_service, the
          // weekly stats) already reports the effective figure.
          final waterDays = <DayMetric>[];
          for (final entry in adherentByDay.entries) {
            final date = DateTime.tryParse(entry.key);
            if (date == null) continue;
            final day = WaterService.getDataForDate(date);
            if (day == null || day.totalIntakeMl <= 0) continue;
            waterDays.add(DayMetric(
              day: date,
              adherent: entry.value,
              value: day.effectiveHydrationMl.toDouble(),
            ));
          }
          out.add(CorrelationEngine.hydrationVsAdherence(waterDays));
        } catch (_) {}
      }
    } catch (_) {}

    return InsightEngine.rankAll(out);
  }

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Days grouped by whether that night's sleep beat the user's own median,
  /// with the day's total water intake as the metric.
  ///
  /// Mirrors [_focusVsSleepDays] exactly, and for the same reasons:
  ///
  ///  * **The user's own median**, not a 7-hour constant — a six-hour sleeper is
  ///    not "deprived" against their own baseline.
  ///  * **`SleepSession.dateKey` is the WAKE-UP date**, so the night that ended
  ///    on the 15th is paired with the 15th's drinking. Keying off bedtime would
  ///    be off by one for every night that crosses midnight, i.e. all of them,
  ///    and would silently reverse the arrow.
  ///  * **Days with no water logged are excluded.** A zero would make this a
  ///    measure of whether the user opened the app. The exclusion tests
  ///    `totalIntakeMl` — "was anything logged" — while the value compared is
  ///    `effectiveHydrationMl`, so an alcohol-heavy day stays in the sample at
  ///    the hydration it actually delivered instead of at its volume.
  static List<GroupedDay> _hydrationVsSleepDays() {
    final nights = SleepService.getAllSessions();
    if (nights.length < CorrelationResult.minPerGroup * 2) return const [];

    final asleepByDay = <String, int>{
      for (final n in nights) n.dateKey: n.asleepMinutes,
    };
    final values = asleepByDay.values.toList()..sort();
    final mid = values.length ~/ 2;
    final median = values.length.isOdd
        ? values[mid]
        : ((values[mid - 1] + values[mid]) / 2).round();

    final out = <GroupedDay>[];
    asleepByDay.forEach((key, slept) {
      final date = DateTime.tryParse(key);
      if (date == null) return;
      final day = WaterService.getDataForDate(date);
      if (day == null || day.totalIntakeMl <= 0) return;
      out.add(GroupedDay(
        day: date,
        inGroup: slept >= median,
        value: day.effectiveHydrationMl.toDouble(),
      ));
    });
    return out;
  }

  /// Days the user ATTEMPTED a focus session, grouped by whether the preceding
  /// night beat their own median, with that day's completion rate as the metric.
  ///
  /// Three things this does deliberately:
  ///
  ///  * **Only attempted days are returned.** A day with no session started is
  ///    absent, not a zero. Including them would make the insight a measure of
  ///    whether the user opened the app — the same defect
  ///    `SleepService.sleepDebtMinutes` documents for its own average.
  ///  * **The grouping is the user's own median**, not a 7-hour constant: a
  ///    six-hour sleeper is not deprived against their own baseline.
  ///  * **The night is the one BEFORE the day.** Sleep is keyed to the morning it
  ///    ends, so a session on the 15th is matched against the night that ended on
  ///    the 15th. Getting this off by one would silently reverse the arrow.
  static List<GroupedDay> _focusVsSleepDays(FocusService fs) {
    final nights = SleepService.getAllSessions();
    if (nights.length < CorrelationResult.minPerGroup * 2) return const [];

    // `SleepSession.dateKey` is documented as "the night's WAKE-UP date", which
    // is exactly the pairing wanted: a session on the 15th is matched against the
    // night that ended on the 15th. Deriving a key from `bedtime` instead would
    // have been off by one for every night that crosses midnight — i.e. all of
    // them — and would have silently reversed the arrow.
    final asleepByDay = <String, int>{
      for (final n in nights) n.dateKey: n.asleepMinutes,
    };
    final values = asleepByDay.values.toList()..sort();
    final mid = values.length ~/ 2;
    final median = values.length.isOdd
        ? values[mid]
        : ((values[mid - 1] + values[mid]) / 2).round();

    // started / completed per calendar day.
    final started = <String, int>{};
    final completed = <String, int>{};
    for (final s in fs.sessions) {
      final key = _dayKey(s.startedAt);
      started[key] = (started[key] ?? 0) + 1;
      if (s.wasCompleted) completed[key] = (completed[key] ?? 0) + 1;
    }

    final out = <GroupedDay>[];
    started.forEach((key, count) {
      final slept = asleepByDay[key];
      if (slept == null || count == 0) return;
      out.add(GroupedDay(
        day: DateTime.parse(key),
        inGroup: slept >= median,
        value: (completed[key] ?? 0) / count,
      ));
    });
    return out;
  }
}
