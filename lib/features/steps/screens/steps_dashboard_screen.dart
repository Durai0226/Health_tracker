import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import 'package:tablet_remainder/core/widgets/app/personal_best_card.dart';
import 'package:tablet_remainder/core/milestones/milestones_screen.dart';
import 'package:tablet_remainder/core/milestones/milestones_service.dart';
import 'package:tablet_remainder/core/health/insight.dart';
import 'package:tablet_remainder/core/health/streak_engine.dart';
import 'package:tablet_remainder/core/services/health_data_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/home_widget_service.dart';
import '../models/step_daily_data.dart';
import '../models/step_source.dart';
import '../services/step_service.dart';
import '../theme/steps_theme.dart';
import '../widgets/step_activity_ring.dart';
import '../widgets/step_weekly_chart.dart';
import '../widgets/step_hourly_chart.dart';
import '../widgets/step_manual_entry_sheet.dart';
import '../models/step_manual_entry.dart';
import '../widgets/manual_step_entries_card.dart';
import '../widgets/rest_day_card.dart';
import '../widgets/steps_permission_card.dart';
import 'package:tablet_remainder/core/health/rest_days.dart';
import 'package:tablet_remainder/core/services/rest_day_store.dart';
import 'steps_goal_settings_screen.dart';
import 'steps_history_screen.dart';
import '../utils/step_format.dart';
import '../../../core/health/coach_text.dart';
import '../../../core/utils/calendar_day.dart';
import 'package:clock/clock.dart';

/// Steps home: hero activity ring, key stats, streak, weekly + hourly charts,
/// a deterministic insight, and a permission/manual-entry fallback. Works with
/// zero health permissions via the manual path.
class StepsDashboardScreen extends StatefulWidget {
  /// When embedded in the Health hub, the hub owns the single header, so this
  /// drops its own scaffold/header chrome.
  final bool embedded;

  const StepsDashboardScreen({super.key, this.embedded = false});

  @override
  State<StepsDashboardScreen> createState() => _StepsDashboardScreenState();
}

class _StepsDashboardScreenState extends State<StepsDashboardScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  HealthAvailability _availability = HealthAvailability.notDetermined;
  bool _loading = true;

  // Goal-close celebration: a one-shot ring pulse when the goal is crossed
  // *while the screen is open*, at most once per day, in-app only (never a push).
  late final AnimationController _celebrateCtrl;
  late final Animation<double> _pulse;
  bool? _lastGoalReached;
  static const _kCelebratedDay = 'steps.celebratedDay';

  // Monday fresh-start recap: shown once on the first open of a new week, only
  // when there's a previous week to reflect on. Leads with what went well.
  static const _kFreshStartWeek = 'steps.freshStartWeek';
  bool _showFreshStart = false;
  int _lastWeekMet = 0;

  @override
  void initState() {
    super.initState();
    _celebrateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _pulse = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.06)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.06, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 60,
      ),
    ]).animate(_celebrateCtrl);
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  /// Health access is granted on a screen we don't own (the Health Connect /
  /// Apple Health consent UI), so resume is the only reliable moment to notice
  /// it. Without this the permission card kept offering "Enable" long after the
  /// user had allowed access.
  ///
  /// Leaving the foreground is the mirror case: live step persistence is
  /// throttled ([StepService.livePersistInterval]), and backgrounding is the
  /// last moment Dart is guaranteed to run before the OS may kill us — so the
  /// queued day is written out here rather than waiting for a timer that may
  /// never fire.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshAvailability();
      return;
    }
    unawaited(StepService.flushPendingLiveDay());
  }

  Future<void> _refreshAvailability() async {
    HealthAvailability avail;
    try {
      avail = await HealthDataService.instance
          .availability()
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      return; // keep whatever we had; never downgrade on a transient failure
    }
    final becameAvailable =
        avail == HealthAvailability.available && !_healthAvailable;
    if (!mounted || avail == _availability) return;
    setState(() => _availability = avail);
    // Access just appeared — import the days we couldn't read before.
    if (becameAvailable) await StepService.syncFromHealth();
  }

  Future<void> _init() async {
    // Never leave the screen on an infinite spinner: if health init or the
    // availability probe hangs or throws, time out and fall back to the
    // manual-entry path instead of spinning forever.
    var avail = HealthAvailability.notDetermined;
    try {
      await StepService.init().timeout(const Duration(seconds: 6));
      avail = await HealthDataService.instance
          .availability()
          .timeout(const Duration(seconds: 6));
      // Live sensor updates while the screen is open (no-op on Simulator).
      StepService.startLiveTracking();
    } catch (_) {
      avail = HealthAvailability.notDetermined;
    }
    _resolveFreshStart();
    _checkMilestones();
    // Keep the opt-in evening reminder alive across app opens (no prompt unless
    // already enabled).
    if (StepService.getReminderEnabled()) {
      unawaited(StepService.replanReminder(rearmIfUnknown: true));
    }
    HomeWidgetService.pushSnapshot(); // refresh the home-screen widget (if any)
    if (mounted) {
      setState(() {
        _availability = avail;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _celebrateCtrl.dispose();
    StepService.stopLiveTracking();
    super.dispose();
  }

  bool get _healthAvailable => _availability == HealthAvailability.available;

  /// Fire a calm celebration only on a genuine false→true goal crossing observed
  /// while this screen is open, and only once per calendar day. Opening the app
  /// already-past-goal never retro-celebrates (the crossing happened off-screen).
  void _maybeCelebrate(
      StepDailyData today, ScaffoldMessengerState messenger, bool reduceMotion) {
    final reached = today.goalReached;
    final prev = _lastGoalReached;
    _lastGoalReached = reached;
    // The goal was just met: today's evening reminder has nothing left to say.
    if (reached && prev != true) unawaited(StepService.replanReminder());
    if (prev != false || !reached) return;
    final key = _todayKey();
    if (CleanStorageService.getAppPreference(_kCelebratedDay, '') == key) return;
    // `mounted` BEFORE the write, not after: marking the day celebrated and
    // then bailing would spend the once-per-day token on a celebration the
    // user never saw.
    if (!mounted) return;
    CleanStorageService.setAppPreference(_kCelebratedDay, key);

    final met = (StepService.getWeeklyStats()['daysGoalMet'] as int?) ?? 0;
    HapticFeedback.mediumImpact();
    if (!reduceMotion) {
      _celebrateCtrl.forward(from: 0);
    }
    // showAppToastVia, not context.toastSuccess: this runs in a post-frame
    // callback, where the element can be deactivated while `mounted` is still
    // true — see the comment at the call site and the doc on showAppToastVia.
    // The kit hides the current toast itself, so the explicit hide is gone.
    showAppToastVia(messenger, _celebrationLine(met),
        duration: const Duration(seconds: 3));
  }

  /// Take one hand-typed entry off today's total, with a way back.
  Future<void> _removeManualEntry(StepManualEntry entry) async {
    await StepService.removeManualEntry(entry.id);
    if (!mounted) return;
    context.toastSuccess(
      'Entry removed',
      action: AppToastAction(
        label: 'Undo',
        // A new entry with the same amount and note: the id is not the point.
        onPressed: () => StepService.addManualSteps(entry.steps, note: entry.note),
      ),
    );
  }

  Future<void> _markRest(RestKind kind) async {
    await RestDayStore.markToday(kind);
    // The evening reminder has nothing to say about a paused goal.
    unawaited(StepService.replanReminder(rearmIfUnknown: true));
    if (mounted) setState(() {});
  }

  Future<void> _undoRest() async {
    await RestDayStore.clear(clock.now());
    unawaited(StepService.replanReminder(rearmIfUnknown: true));
    if (mounted) setState(() {});
  }

  static String _todayKey() {
    final n = clock.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  /// A small rotating message pool — the "variable" element, kept calm.
  static String _celebrationLine(int daysMet) {
    const prefixes = ['Goal reached', 'Goal closed', 'Nicely done'];
    final p = prefixes[daysMet % prefixes.length];
    return '$p · $daysMet/7 this week';
  }

  Future<void> _enableHealth() async {
    // Always give explicit feedback (the old handler was silent).

    // Health Connect missing/outdated: the consent sheet can't open at all, so
    // send the user to the Play Store rather than failing silently.
    if (_availability == HealthAvailability.needsProviderUpdate) {
      await HealthDataService.instance.installHealthConnect();
      // This is an ordinary async gap in a State method, so a mounted guard is
      // sufficient and the toast may take `context`.
      if (!mounted) return;
      context.toastInfo('Install Health Connect, then come back to connect.');
      return;
    }

    final ok = await HealthDataService.instance.requestPermissions();
    var imported = 0;
    if (ok) imported = await StepService.syncFromHealth();
    final avail = await HealthDataService.instance.availability();
    if (!mounted) return;
    setState(() => _availability = avail);

    final String msg;
    if (avail == HealthAvailability.unavailable) {
      msg = "Health data isn't available on this device.";
    } else if (avail == HealthAvailability.needsProviderUpdate) {
      msg = 'Health Connect needs to be installed or updated first.';
    } else if (!ok) {
      msg = Platform.isIOS
          ? 'Step access not granted. Allow it in Apple Health › Sharing.'
          : 'Step access not granted. Allow it in Health Connect › App permissions.';
    } else if (imported > 0) {
      msg = 'Connected — imported $imported day${imported == 1 ? '' : 's'} of steps.';
    } else {
      msg = "Connected. No step data found yet — it'll sync as it appears.";
    }
    context.toastInfo(msg);
  }

  /// Resolve the once-a-week fresh-start recap. Marks the week as seen so it
  /// won't re-appear on later opens, and only surfaces when last week has data.
  void _resolveFreshStart() {
    final now = clock.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final weekKey = '${weekStart.year}-${weekStart.month}-${weekStart.day}';
    final stored =
        (CleanStorageService.getAppPreference(_kFreshStartWeek, '') as String?) ??
            '';
    final isNewWeek = stored != weekKey;

    final lastWeekStart = weekStart.subtract(const Duration(days: 7));
    final lastWeekEnd = weekStart.subtract(const Duration(days: 1));
    final days = StepService.getDataForRange(lastWeekStart, lastWeekEnd);
    final tracked = days.where((d) => d.effectiveSteps > 0).length;
    _lastWeekMet = days.where((d) => d.goalReached).length;
    _showFreshStart = isNewWeek && tracked > 0;

    if (isNewWeek) {
      CleanStorageService.setAppPreference(_kFreshStartWeek, weekKey);
    }
  }

  Future<void> _openManualSheet() async {
    await StepManualEntrySheet.show(
      context,
      onSubmit: (steps, note, date) async {
        await StepService.addManualStepsForDate(date, steps, note: note);
        if (mounted) HapticFeedback.mediumImpact();
      },
    );
  }

  void _openGoalSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StepsGoalSettingsScreen()),
    );
  }

  void _openMilestones() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          MilestonesScreen(feature: 'steps', accentOf: (ext) => ext.steps),
    ));
  }

  /// Quietly surface a just-unlocked milestone (in-app only, never a push).
  /// Persist-based dedup means it toasts at most once, ever.
  Future<void> _checkMilestones() async {
    final r = await MilestonesService.sync();
    if (!mounted || r.newlyEarned.isEmpty) return;
    showAppToast(
      context,
      'Milestone reached · ${r.newlyEarned.first.title}',
      variant: AppToastVariant.success,
      duration: const Duration(seconds: 3),
    );
  }

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StepsHistoryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = AccentScope(
      feature: FeatureAccent.steps,
      child: Builder(builder: _buildScaffold),
    );
    return content;
  }

  Widget _buildScaffold(BuildContext context) {
    if (widget.embedded) {
      return _buildBody(context);
    }
    final canPop = Navigator.of(context).canPop();
    // Only float the FAB in health-connected (data) mode. When health is
    // unavailable the permission card owns the "Log manually" affordance, so the
    // FAB would just overlap that card and duplicate its CTA.
    final showFab = _healthAvailable;
    return AppScaffold(
      floatingActionButton: showFab
          ? AppFab(
              icon: Symbols.add_rounded,
              label: 'Add steps',
              onPressed: _openManualSheet,
            )
          : null,
      body: Column(
        children: [
          AppHeader(
            title: 'Steps',
            leading: canPop
                ? AppIconButton(
                    icon: Symbols.arrow_back_rounded,
                    filled: false,
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                  )
                : null,
            actions: [
              AppIconButton(
                icon: Symbols.military_tech_rounded,
                filled: false,
                tooltip: 'Milestones',
                onPressed: _openMilestones,
              ),
              AppIconButton(
                icon: Symbols.history_rounded,
                filled: false,
                tooltip: 'History',
                onPressed: _openHistory,
              ),
              AppIconButton(
                icon: Symbols.tune_rounded,
                filled: false,
                tooltip: 'Goal & profile',
                onPressed: _openGoalSettings,
              ),
            ],
          ),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final listenable = StepService.listenToDailyData();
    if (listenable == null) {
      return _buildContent(context, StepService.getTodayData());
    }
    return ValueListenableBuilder(
      valueListenable: listenable,
      builder: (context, _, _) =>
          _buildContent(context, StepService.getTodayData()),
    );
  }

  Widget _buildContent(BuildContext context, StepDailyData today) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final streakResult = StepService.getStreakResult();
    final streak = streakResult.current;
    final resting = RestDayStore.kindToday();
    final weekly = StepService.getWeeklyStats();
    final healthy = _healthAvailable;

    // Check for a fresh goal crossing after this frame paints.
    //
    // The messenger and the reduce-motion flag are resolved HERE, during build,
    // and handed to the callback. Looking them up inside it instead threw
    // "Looking up a deactivated widget's ancestor is unsafe": a post-frame
    // callback can run after the element has been deactivated — removed from
    // the tree but not yet unmounted — and `mounted` is still true at that
    // point, so the guard below does not cover it.
    final messenger = ScaffoldMessenger.of(context);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => _maybeCelebrate(today, messenger, reduceMotion));

    return RefreshIndicator(
      color: ext.mark(ext.steps),
      onRefresh: () async {
        await StepService.syncFromHealth();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          widget.embedded ? AppSpacing.sm : AppSpacing.md,
          AppSpacing.gutter,
          widget.embedded ? AppSpacing.xxl : 96,
        ),
        children: [
          if (_showFreshStart) ...[
            _buildFreshStart(context),
            const SizedBox(height: AppSpacing.lg),
          ],
          // Hero ring (pulses once on a fresh goal crossing).
          Center(
            child: ScaleTransition(
              scale: _pulse,
              child: StepActivityRing(
                progress: today.progress,
                steps: today.effectiveSteps,
                goalSteps: today.goalSteps,
                onTap: _openManualSheet,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Text(
              resting != null
                  ? '${resting.label} · goal paused'
                  : '${today.source.label} · ${StepsTheme.bandLabel(today.progress)}',
              style: tt.bodySmall?.copyWith(color: ext.textTertiary),
            ),
          ),
          // Offered until the goal is met, and always while a mark is on so it
          // can be taken back.
          if (resting != null || !today.goalReached) ...[
            const SizedBox(height: AppSpacing.md),
            RestDayCard(
              marked: resting,
              onMark: _markRest,
              onUndo: _undoRest,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),

          // Key stats.
          StatTileRow(
            tiles: [
              StatTile(
                icon: Symbols.directions_walk_rounded,
                value: formatThousands(today.effectiveSteps),
                label: 'Steps',
                accent: ext.steps,
              ),
              StatTile(
                icon: Symbols.straighten_rounded,
                value: today.distanceKm.toStringAsFixed(
                    today.distanceKm >= 10 ? 0 : 1),
                label: 'Km',
                accent: ext.steps,
              ),
              StatTile(
                icon: Symbols.local_fire_department_rounded,
                value: formatThousands(today.activeCalories.round()),
                label: 'Kcal',
                accent: ext.steps,
              ),
            ],
          ),
          if (today.manualEntries.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            ManualStepEntriesCard(
              entries: today.manualEntries,
              onRemove: _removeManualEntry,
            ),
          ],
          const SizedBox(height: AppSpacing.md),

          // Weekly goal-met headline + quiet forgiving streak line.
          _StreakStrip(
            result: streakResult,
            daysGoalMet: weekly['daysGoalMet'] as int,
          ),

          // Personal best (self-referential mastery cue).
          if (StepService.getBestDay() case final best?) ...[
            const SizedBox(height: AppSpacing.md),
            PersonalBestCard(
              icon: Symbols.emoji_events_rounded,
              value: '${formatThousands(best.steps)} steps',
              sublabel: 'Best day · ${_shortDate(best.date)}',
              isNew: StepService.isTodayNewBest(),
              accent: AppColorsExt.of(context).steps,
            ),
          ],

          // Permission / manual fallback.
          if (!healthy) ...[
            const SizedBox(height: AppSpacing.lg),
            StepsPermissionCard(
              availability: _availability,
              onEnable: _enableHealth,
              onLogManually: _openManualSheet,
            ),
          ],

          const SizedBox(height: AppSpacing.lg),
          // Weekly chart.
          StepWeeklyChart(
            data: _weekBars(),
            goalSteps: today.goalSteps,
          ),

          const SizedBox(height: AppSpacing.lg),
          // Hourly distribution.
          StepHourlyChart(hourly: today.hourly),

          const SizedBox(height: AppSpacing.lg),
          _coachCard(today, streak),

          const SizedBox(height: AppSpacing.lg),
          // Deterministic insight (dormant-engine surface / placeholder area).
          _buildInsight(today, streak),
        ],
      ),
    );
  }

  void _dismissFreshStart() => setState(() => _showFreshStart = false);

  /// The once-a-week "clean slate" moment — leads with last week's wins, never
  /// a red "you failed" number.
  Widget _buildFreshStart(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final positive = _lastWeekMet > 0;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: ext.steps.container,
                  borderRadius: AppRadius.brMd,
                ),
                child: Icon(Symbols.wb_sunny_rounded,
                    size: 20, color: ext.steps.onContainer),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text('New week — clean slate', style: tt.titleMedium),
              ),
              AppIconButton(
                icon: Symbols.close_rounded,
                filled: false,
                tooltip: 'Dismiss',
                onPressed: _dismissFreshStart,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            positive
                ? 'Last week you closed $_lastWeekMet/7 step goals. Fresh dots — keep it going.'
                : 'A fresh week and a clean slate. A short daily walk is a great start.',
            style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
          ),
        ],
      ),
    );
  }

  /// Plain activity tip, computed from today's numbers.
  Widget _coachCard(StepDailyData today, int streak) {
    final ext = AppColorsExt.of(context);
    return TipCard(
      title: 'Activity coach',
      icon: Symbols.directions_walk_rounded,
      accent: ext.steps,
      text: const CoachText().stepsTip(
        steps: today.effectiveSteps,
        goal: today.goalSteps,
        streakDays: streak,
        hour: clock.now().hour,
      ),
    );
  }

  Widget _buildInsight(StepDailyData today, int streak) {
    final insight = _stepsInsight(today, streak);
    if (insight == null) return const SizedBox.shrink();
    return InsightCard(insight: insight);
  }

  /// Build the seven Mon→Sun bars for the current week.
  List<StepDayBar> _weekBars() {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = startOfWeek(now);
    final bars = <StepDayBar>[];
    for (int i = 0; i < 7; i++) {
      final date = dayOffset(weekStart, i);
      final d = StepService.getDataForDate(date);
      final isToday = date == today;
      bars.add(StepDayBar(
        label: labels[i],
        steps: date.isAfter(today) ? 0 : (d?.effectiveSteps ?? 0),
        isToday: isToday,
        reached: d?.goalReached ?? false,
      ));
    }
    return bars;
  }

  Insight? _stepsInsight(StepDailyData today, int streak) {
    final progress = today.progress;
    final goal = today.goalSteps;
    final steps = today.effectiveSteps;
    final remaining = (goal - steps) <= 0 ? 0 : (goal - steps);
    final pctText = '${(progress * 100).round()}%';

    if (steps == 0) {
      return const Insight(
        id: 'steps.start',
        feature: InsightFeature.steps,
        severity: InsightSeverity.info,
        title: 'Get the ring moving',
        detail:
            'No steps logged yet today. A short walk — or a quick manual entry — starts your streak.',
        why: 'You have 0 effective steps recorded for today.',
        actionLabel: 'Add steps',
      );
    }

    if (today.goalReached) {
      return Insight(
        id: 'steps.reached',
        feature: InsightFeature.steps,
        severity: InsightSeverity.good,
        title: streak > 1
            ? '$streak-day streak going strong'
            : 'Goal reached today',
        detail:
            'You hit ${formatThousands(steps)} steps — $pctText of your ${formatThousands(goal)} goal. Keep the momentum up.',
        metric: pctText,
        why:
            'Effective steps (${formatThousands(steps)}) reached or passed today\'s goal (${formatThousands(goal)}).',
      );
    }

    return Insight(
      id: 'steps.behind',
      feature: InsightFeature.steps,
      severity:
          progress >= 0.6 ? InsightSeverity.info : InsightSeverity.attention,
      title: progress >= 0.6 ? 'Almost there' : 'Room to move today',
      detail:
          '${formatThousands(remaining)} steps to your ${formatThousands(goal)} goal — about a ${_walkMinutes(remaining)} min walk.',
      metric: pctText,
      why:
          'Effective steps (${formatThousands(steps)}) are below today\'s goal (${formatThousands(goal)}).',
      actionLabel: 'Add steps',
    );
  }

  /// Rough minutes-to-walk estimate (~100 steps/min).
  int _walkMinutes(int steps) {
    final m = (steps / 100).ceil();
    if (m < 1) return 1;
    if (m > 999) return 999;
    return m;
  }

  static String _shortDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    if (that == today) return 'Today';
    if (that == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${months[d.month - 1]} ${d.day}';
  }
}

/// Weekly goal-met headline (the steps north star) with a quiet, forgiving
/// streak line beneath. The streak never shows a red zero, never surfaces the
/// "at risk" state, and spends grace days silently — it stays secondary to the
/// days-met headline by design.
class _StreakStrip extends StatelessWidget {
  final StreakResult result;
  final int daysGoalMet;

  const _StreakStrip({required this.result, required this.daysGoalMet});

  String get _streakLine {
    final c = result.current;
    final l = result.longest;
    if (c > 0) return l > c ? '$c-day rhythm · best $l' : '$c-day rhythm';
    if (l > 0) return 'Fresh start — your best run was $l days';
    return 'Reach your goal to start a rhythm';
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final active = result.current > 0;
    return AppCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: active ? ext.warning.container : ext.steps.container,
              borderRadius: AppRadius.brMd,
            ),
            child: Icon(
              Symbols.local_fire_department_rounded,
              size: 22,
              color: active ? ext.warning.onContainer : ext.steps.onContainer,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppEyebrow('THIS WEEK'),
                const SizedBox(height: 2),
                Text('$daysGoalMet/7 goals met', style: tt.titleLarge),
                const SizedBox(height: 2),
                Text(
                  _streakLine,
                  style: tt.bodySmall?.copyWith(color: ext.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          WeekDotStrip(filled: daysGoalMet, accent: ext.steps),
        ],
      ),
    );
  }
}
