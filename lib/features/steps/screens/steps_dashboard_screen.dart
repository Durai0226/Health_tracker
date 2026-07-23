import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import 'package:tablet_remainder/core/widgets/app/personal_best_card.dart';
import 'package:tablet_remainder/core/milestones/milestones_screen.dart';
import 'package:tablet_remainder/core/milestones/milestones_service.dart';
import 'package:tablet_remainder/core/ai/ai_assistant.dart';
import 'package:tablet_remainder/core/ai/insight.dart';
import 'package:tablet_remainder/core/ai/ai_types.dart';
import 'package:tablet_remainder/core/ai/streak_engine.dart';
import 'package:tablet_remainder/core/services/health_data_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/home_widget_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import '../models/step_daily_data.dart';
import '../models/step_source.dart';
import '../services/step_service.dart';
import '../theme/steps_theme.dart';
import '../widgets/step_activity_ring.dart';
import '../widgets/step_weekly_chart.dart';
import '../widgets/step_hourly_chart.dart';
import '../widgets/step_manual_entry_sheet.dart';
import '../widgets/steps_permission_card.dart';
import 'steps_goal_settings_screen.dart';
import 'steps_history_screen.dart';

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
    with SingleTickerProviderStateMixin {
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
    _init();
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
      NotificationService().scheduleStepReminder(
        enabled: true,
        minuteOfDay: StepService.getReminderMinuteOfDay(),
      );
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
    _celebrateCtrl.dispose();
    StepService.stopLiveTracking();
    super.dispose();
  }

  /// Fire a calm celebration only on a genuine false→true goal crossing observed
  /// while this screen is open, and only once per calendar day. Opening the app
  /// already-past-goal never retro-celebrates (the crossing happened off-screen).
  void _maybeCelebrate(StepDailyData today) {
    final reached = today.goalReached;
    final prev = _lastGoalReached;
    _lastGoalReached = reached;
    if (prev != false || !reached) return;
    final key = _todayKey();
    if (CleanStorageService.getAppPreference(_kCelebratedDay, '') == key) return;
    CleanStorageService.setAppPreference(_kCelebratedDay, key);
    if (!mounted) return;

    final met = (StepService.getWeeklyStats()['daysGoalMet'] as int?) ?? 0;
    HapticFeedback.mediumImpact();
    if (!MediaQuery.of(context).disableAnimations) {
      _celebrateCtrl.forward(from: 0);
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(_celebrationLine(met)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ));
  }

  static String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  /// A small rotating message pool — the "variable" element, kept calm.
  static String _celebrationLine(int daysMet) {
    const prefixes = ['Goal reached', 'Goal closed', 'Nicely done'];
    final p = prefixes[daysMet % prefixes.length];
    return '$p · $daysMet/7 this week';
  }

  Future<void> _enableHealth() async {
    // Capture the messenger before awaiting so we never use context across an
    // async gap; always give explicit feedback (the old handler was silent).
    final messenger = ScaffoldMessenger.of(context);
    final ok = await HealthDataService.instance.requestPermissions();
    var imported = 0;
    if (ok) imported = await StepService.syncFromHealth();
    final avail = await HealthDataService.instance.availability();
    if (!mounted) return;
    setState(() => _availability = avail);

    final String msg;
    if (!ok && avail == HealthAvailability.unavailable) {
      msg = "Health data isn't available on this device.";
    } else if (!ok) {
      msg = 'Health access not granted. Enable it in Settings › Health.';
    } else if (imported > 0) {
      msg = 'Connected — imported $imported day${imported == 1 ? '' : 's'} of steps.';
    } else {
      msg = "Connected. No step data found yet — it'll sync as it appears.";
    }
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Resolve the once-a-week fresh-start recap. Marks the week as seen so it
  /// won't re-appear on later opens, and only surfaces when last week has data.
  void _resolveFreshStart() {
    final now = DateTime.now();
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Milestone reached · ${r.newlyEarned.first.title}'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ));
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
    final showFab = _availability == HealthAvailability.available;
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
            icon: Symbols.directions_walk_rounded,
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
    final weekly = StepService.getWeeklyStats();
    final healthy = _availability == HealthAvailability.available;

    // Check for a fresh goal crossing after this frame paints.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _maybeCelebrate(today));

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
              '${today.source.label} · ${StepsTheme.bandLabel(today.progress)}',
              style: tt.bodySmall?.copyWith(color: ext.textTertiary),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Key stats.
          StatTileRow(
            tiles: [
              StatTile(
                icon: Symbols.directions_walk_rounded,
                value: _fmt(today.effectiveSteps),
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
                value: _fmt(today.activeCalories.round()),
                label: 'Kcal',
                accent: ext.steps,
              ),
            ],
          ),
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
              value: '${_fmt(best.steps)} steps',
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
          _aiCoachCard(today, streak),

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

  /// Self-loading generative AI activity coach (on-device rule engine default).
  Widget _aiCoachCard(StepDailyData today, int streak) {
    final ext = AppColorsExt.of(context);
    return AiInsightCard(
      title: 'Activity coach',
      icon: kAiSparkle,
      accent: ext.steps,
      cacheKey:
          'steps:${today.effectiveSteps ~/ 500}:${today.goalSteps}:$streak:${DateTime.now().hour ~/ 3}',
      loader: () => AiAssistant().stepsTip(
        steps: today.effectiveSteps,
        goal: today.goalSteps,
        streakDays: streak,
        hour: DateTime.now().hour,
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: now.weekday - 1));
    final bars = <StepDayBar>[];
    for (int i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
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
        engine: AiEngineKind.ruleBased,
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
            'You hit ${_fmt(steps)} steps — $pctText of your ${_fmt(goal)} goal. Keep the momentum up.',
        metric: pctText,
        why:
            'Effective steps (${_fmt(steps)}) reached or passed today\'s goal (${_fmt(goal)}).',
        engine: AiEngineKind.ruleBased,
      );
    }

    return Insight(
      id: 'steps.behind',
      feature: InsightFeature.steps,
      severity:
          progress >= 0.6 ? InsightSeverity.info : InsightSeverity.attention,
      title: progress >= 0.6 ? 'Almost there' : 'Room to move today',
      detail:
          '${_fmt(remaining)} steps to your ${_fmt(goal)} goal — about a ${_walkMinutes(remaining)} min walk.',
      metric: pctText,
      why:
          'Effective steps (${_fmt(steps)}) are below today\'s goal (${_fmt(goal)}).',
      actionLabel: 'Add steps',
      engine: AiEngineKind.ruleBased,
    );
  }

  /// Rough minutes-to-walk estimate (~100 steps/min).
  int _walkMinutes(int steps) {
    final m = (steps / 100).ceil();
    if (m < 1) return 1;
    if (m > 999) return 999;
    return m;
  }

  static String _fmt(int n) {
    final str = n.abs().toString();
    final buf = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write(',');
      buf.write(str[i]);
    }
    return '${n < 0 ? '-' : ''}$buf';
  }

  static String _shortDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final now = DateTime.now();
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
                Text(
                  'THIS WEEK',
                  style: tt.labelSmall
                      ?.copyWith(color: ext.textTertiary, letterSpacing: 0.6),
                ),
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
