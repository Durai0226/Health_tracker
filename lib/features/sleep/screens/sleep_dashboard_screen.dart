import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/health/insight.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/health_data_service.dart';
import 'package:tablet_remainder/core/services/home_widget_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import 'package:tablet_remainder/core/widgets/app/personal_best_card.dart';
import 'package:tablet_remainder/core/milestones/milestones_screen.dart';
import 'package:tablet_remainder/core/milestones/milestones_service.dart';
import '../models/sleep_schedule.dart';
import '../models/sleep_session.dart';
import '../models/sleep_consistency.dart';
import '../services/sleep_service.dart';
import '../widgets/sleep_consistency_card.dart';
import '../widgets/sleep_manual_log_sheet.dart';
import '../widgets/sleep_permission_card.dart';
import '../widgets/sleep_score_ring.dart';
import '../widgets/sleep_stage_timeline.dart';
import '../widgets/sleep_weekly_trend.dart';
import 'sleep_history_screen.dart';
import 'sleep_schedule_settings_screen.dart';
import '../../../core/health/coach_text.dart';

/// The Sleep home: last-night summary (score ring + duration/efficiency),
/// an honest stage timeline, the 7-night trend vs target with a regularity
/// band, a deterministic insight, and the always-available manual-log path.
class SleepDashboardScreen extends StatefulWidget {
  /// When embedded in the Health hub the hub owns the header + chrome, so this
  /// drops its own header/scaffold and surfaces an inline "Log sleep" button.
  final bool embedded;
  const SleepDashboardScreen({super.key, this.embedded = false});

  @override
  State<SleepDashboardScreen> createState() => _SleepDashboardScreenState();
}

class _SleepDashboardScreenState extends State<SleepDashboardScreen>
    with WidgetsBindingObserver {
  bool _loading = true;
  HealthAvailability _availability = HealthAvailability.notDetermined;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Granting health access happens *outside* the app (the Health Connect /
  /// Apple Health consent screen), so the only reliable moment to notice it is on
  /// resume. Without this the card kept saying "Connect" after the user had
  /// already allowed access.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshAvailability();
  }

  Future<void> _refreshAvailability() async {
    HealthAvailability avail;
    try {
      avail = await HealthDataService.instance.availability();
    } catch (_) {
      return; // keep what we had; never downgrade on a transient failure
    }
    final becameAvailable =
        avail == HealthAvailability.available && !_healthAvailable;
    if (!mounted) return;
    setState(() => _availability = avail);
    // Access just appeared — pull the nights we couldn't read before.
    if (becameAvailable) await SleepService.syncFromHealth();
  }

  Future<void> _load() async {
    await SleepService.init();
    // Keep the daily wind-down reminder alive across app opens, but only for
    // users who already opted in (so opening Sleep never triggers a permission
    // prompt on its own).
    final sched = SleepService.getSchedule();
    if (sched.reminderEnabled) {
      NotificationService().scheduleBedtimeReminder(
        enabled: true,
        minuteOfDay: sched.reminderMinuteOfDay,
      );
    }
    if (sched.alarmEnabled) {
      NotificationService().scheduleWakeAlarm(
        enabled: true,
        hour: sched.wakeHour,
        minute: sched.wakeMinute,
      );
    }
    HomeWidgetService.pushSnapshot(); // refresh the home-screen widget (if any)
    await _refreshAvailability();
    if (mounted) setState(() => _loading = false);
    _checkMilestones();
  }

  void _openMilestones() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MilestonesScreen(feature: 'sleep', accentOf: (ext) => ext.sleep),
      ),
    );
  }

  /// Quietly surface a just-unlocked milestone (in-app only, never a push).
  /// Persist-based dedup means it toasts at most once, ever.
  Future<void> _checkMilestones() async {
    final r = await MilestonesService.sync();
    if (!mounted || r.newlyEarned.isEmpty) return;
    context.toastSuccess('Milestone reached · ${r.newlyEarned.first.title}');
  }

  bool get _healthAvailable => _availability == HealthAvailability.available;

  /// Anything short of "no provider on this device" is worth a CTA: a refused
  /// grant can be retried and a stale Health Connect can be updated. Only
  /// [HealthAvailability.unavailable] is a genuine dead end.
  bool get _canConnect => _availability != HealthAvailability.available &&
      _availability != HealthAvailability.unavailable;
  bool get _hasData => SleepService.getLastNight() != null;

  /// Whether to show the gentle morning "log last night" prompt.
  ///
  /// Manual path only (Health-connected users' nights sync automatically, so a
  /// manual nudge would be noise), during a generous morning window, and only
  /// while today's night is still unlogged. It vanishes on its own the moment a
  /// session is saved — no dismiss needed, never a push.
  bool get _shouldPromptMorningLog {
    if (_healthAvailable) return false;
    final now = DateTime.now();
    if (now.hour >= 14) return false; // morning window (until 2pm)
    final today = DateTime(now.year, now.month, now.day);
    return SleepService.getForDate(today) == null;
  }

  Future<void> _openManualLog() async {
    final result = await SleepManualLogSheet.show(
      context,
      schedule: SleepService.getSchedule(),
    );
    if (result == null) return;
    final session = await SleepService.logManualSession(
      bedtime: result.bedtime,
      wakeTime: result.wakeTime,
      quality: result.quality,
      note: result.note,
    );
    if (!mounted) return;

    // Calm celebration for a genuinely well-rested night (score ≥ 85), at most
    // once per night, in-app only. Otherwise a plain confirmation.
    const key = 'sleep.celebratedNight';
    final wellRested = session.sleepScore >= 85;
    final already =
        CleanStorageService.getAppPreference(key, '') == session.dateKey;
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    if (wellRested && !already) {
      CleanStorageService.setAppPreference(key, session.dateKey);
      HapticFeedback.mediumImpact();
      messenger.showSnackBar(SnackBar(
        content: Text('Well rested — score ${session.sleepScore}. Nice night.'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ));
    } else {
      messenger.showSnackBar(const SnackBar(
        content: Text('Sleep logged'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _connect() async {
    // Capture the messenger before any await so we never touch context across
    // an async gap, and always give the user explicit feedback — the old
    // handler was silent, so denial / no-data / success all looked identical.
    final messenger = ScaffoldMessenger.of(context);

    // Health Connect missing/outdated: the consent sheet can't open at all, so
    // send the user to the Play Store instead of failing silently.
    if (_availability == HealthAvailability.needsProviderUpdate) {
      await HealthDataService.instance.installHealthConnect();
      messenger.showSnackBar(const SnackBar(
        content: Text('Install Health Connect, then come back to connect.'),
      ));
      return;
    }

    final ok = await HealthDataService.instance.requestPermissions();
    var imported = 0;
    if (ok) imported = await SleepService.syncFromHealth();
    final avail = await HealthDataService.instance.availability();
    if (!mounted) return;
    setState(() => _availability = avail);

    final String msg;
    if (avail == HealthAvailability.unavailable) {
      msg = "Health data isn't available on this device.";
    } else if (avail == HealthAvailability.needsProviderUpdate) {
      msg = 'Health Connect needs to be installed or updated first.';
    } else if (!ok) {
      msg = 'Sleep access not granted. Allow it in ${_storeName()} to sync.';
    } else if (imported > 0) {
      msg = 'Connected — imported $imported night${imported == 1 ? '' : 's'}.';
    } else {
      msg = "Connected. No sleep data found yet — it'll sync as it appears.";
    }
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  }

  static String _storeName() =>
      Platform.isIOS ? 'Apple Health' : 'Health Connect';

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SleepScheduleSettingsScreen()),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SleepHistoryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = _loading
        ? _buildLoading(context)
        : ValueListenableBuilder<Map<String, SleepSession>>(
            valueListenable: SleepService.listenToSessions(),
            builder: (context, _, _) => _buildScroll(context),
          );

    if (widget.embedded) {
      return AccentScope(feature: FeatureAccent.sleep, child: content);
    }
    return AccentScope(
      feature: FeatureAccent.sleep,
      child: AppScaffold(
        body: content,
        // Only float the FAB once there's data to add to. The empty state and
        // permission card carry their own "Log sleep" / "Log manually" CTA, so a
        // FAB there just duplicates and (with a long card) overlaps them.
        floatingActionButton: _hasData
            ? AppFab(
                icon: Symbols.add_rounded,
                label: 'Log sleep',
                onPressed: _openManualLog,
              )
            : null,
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        if (!widget.embedded)
          AppHeader(
            title: 'Sleep',
            icon: Symbols.bedtime_rounded,
            accent: AppColorsExt.of(context).sleep,
          ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
          child: Column(
            children: [
              SizedBox(height: AppSpacing.sm),
              LoadingSkeleton(height: 180, radius: AppRadius.card),
              SizedBox(height: AppSpacing.lg),
              LoadingSkeleton(height: 96, radius: AppRadius.card),
              SizedBox(height: AppSpacing.lg),
              LoadingSkeleton(height: 160, radius: AppRadius.card),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScroll(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final lastNight = SleepService.getLastNight();
    final schedule = SleepService.getSchedule();

    final sections = <Widget>[];
    if (lastNight == null) {
      if (!_healthAvailable) {
        sections.add(SleepPermissionCard(
          availability: _availability,
          onLogManually: _openManualLog,
          onConnect: _canConnect ? _connect : null,
        ));
        sections.add(const SizedBox(height: AppSpacing.lg));
      }
      sections.add(_buildEmptyState(context));
    } else {
      final trend = SleepService.getWeeklyTrend();
      final regularity = SleepService.regularityIndex();
      final consistency = SleepConsistency.fromIndex(
        regularity,
        sampleSize: SleepService.regularitySampleSize(),
      );
      final nightsLogged = trend.where((d) => d.hasData).length;
      final debt = SleepService.sleepDebtMinutes();

      if (_shouldPromptMorningLog) {
        sections
          ..add(_buildMorningPrompt(context))
          ..add(const SizedBox(height: AppSpacing.md));
      }

      sections
        ..add(_buildSummaryCard(context, lastNight))
        ..add(const SizedBox(height: AppSpacing.md))
        // Hero metric: bedtime consistency ("your rhythm") — the one thing a
        // manual logger controls, framed gently.
        ..add(SleepConsistencyCard(
          consistency: consistency,
          index: regularity,
          nightsLoggedThisWeek: nightsLogged,
        ))
        ..add(const SizedBox(height: AppSpacing.md))
        ..add(_buildBedtimeTip(context))
        ..add(const SizedBox(height: AppSpacing.md))
        ..add(_buildStatRow(context, lastNight))
        ..add(const SizedBox(height: AppSpacing.md))
        ..add(SleepStageTimeline(session: lastNight))
        ..add(const SizedBox(height: AppSpacing.md))
        ..add(SleepWeeklyTrend(
          days: trend,
          targetMinutes: schedule.targetMinutes,
        ))
        ..add(_buildBestNight(context))
        ..add(const SizedBox(height: AppSpacing.lg))
        ..add(_coachCard(context, lastNight, debt, regularity, schedule))
        ..add(const SizedBox(height: AppSpacing.lg))
        ..add(SectionHeader(
          title: 'Insights',
          icon: Symbols.insights_rounded,
          accent: ext.sleep,
        ))
        ..add(InsightCard(
          insight: _buildInsight(lastNight, debt, regularity, schedule),
        ));

      if (!_healthAvailable && _canConnect) {
        sections
          ..add(const SizedBox(height: AppSpacing.lg))
          ..add(SleepPermissionCard(
            availability: _availability,
            onLogManually: _openManualLog,
            onConnect: _connect,
          ));
      }
    }

    if (widget.embedded) {
      sections
        ..add(const SizedBox(height: AppSpacing.lg))
        ..add(AppButton(
          label: 'Log sleep',
          leadingIcon: Symbols.add_rounded,
          fullWidth: true,
          accent: ext.sleep,
          onPressed: _openManualLog,
        ));
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        if (!widget.embedded)
          AppHeader(
            title: 'Sleep',
            greeting: _greeting(),
            icon: Symbols.bedtime_rounded,
            accent: ext.sleep,
            actions: [
              AppIconButton(
                icon: Symbols.military_tech_rounded,
                tooltip: 'Milestones',
                accent: ext.sleep,
                onPressed: _openMilestones,
              ),
              AppIconButton(
                icon: Symbols.history_rounded,
                tooltip: 'Sleep history',
                accent: ext.sleep,
                onPressed: _openHistory,
              ),
              AppIconButton(
                icon: Symbols.tune_rounded,
                tooltip: 'Sleep schedule',
                accent: ext.sleep,
                onPressed: _openSettings,
              ),
            ],
          )
        else
          const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: sections,
          ),
        ),
      ],
    );
  }

  /// Self-loading generative AI sleep coach (on-device rule engine default).
  Widget _coachCard(BuildContext context, SleepSession last, int debt,
      double regularity, SleepSchedule schedule) {
    final ext = AppColorsExt.of(context);
    return TipCard(
      title: 'Sleep coach',
      icon: Symbols.bedtime_rounded,
      accent: ext.sleep,
      text: const CoachText().sleepTip(
        lastNightMinutes: last.asleepMinutes,
        targetMinutes: schedule.targetMinutes,
        debtMinutes: debt,
        regularity: regularity,
        // Suppresses the debt line on a partly-logged week — otherwise unlogged
        // nights read as sleep the user didn't get.
        loggedNights: SleepService.regularitySampleSize(),
      ),
    );
  }

  /// Gentle "aim for bed around HH:MM" tip — a soft target, never a hard time.
  Widget _buildBedtimeTip(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final bed = SleepService.suggestedBedtimeMinuteOfDay();
    return AppCard(
      child: Row(
        children: [
          Icon(Symbols.nights_stay_rounded, size: 18, color: ext.mark(ext.sleep)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
                children: [
                  const TextSpan(text: 'Aim for bed around '),
                  TextSpan(
                    text: _formatMinuteOfDay(bed),
                    style: TextStyle(
                        color: ext.textPrimary, fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: ' to reach your wake goal.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatMinuteOfDay(int m) {
    final h24 = (m ~/ 60) % 24;
    final min = m % 60;
    final period = h24 >= 12 ? 'PM' : 'AM';
    var h = h24 % 12;
    if (h == 0) h = 12;
    return '$h:${min.toString().padLeft(2, '0')} $period';
  }

  /// Most-rested night on record (self-referential personal best). Carries its
  /// own top spacing so it collapses cleanly when there's nothing to show.
  Widget _buildBestNight(BuildContext context) {
    final best = SleepService.getBestNight();
    if (best == null) return const SizedBox.shrink();
    final all = SleepService.getAllSessions();
    final isNew = all.length > 1 && all.first.id == best.id;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: PersonalBestCard(
        icon: Symbols.emoji_events_rounded,
        value: 'Score ${best.sleepScore}',
        sublabel: 'Most rested · ${_dateLabel(best.wakeTime)}',
        isNew: isNew,
        accent: AppColorsExt.of(context).sleep,
      ),
    );
  }

  /// Gentle in-app morning nudge: "how did you sleep?" → one-tap prefilled log.
  Widget _buildMorningPrompt(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: ext.sleep.container,
                  borderRadius: AppRadius.brMd,
                ),
                child: Icon(Symbols.wb_twilight_rounded,
                    size: 20, color: ext.sleep.onContainer),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('How did you sleep?', style: tt.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      'Add last night in a few taps to keep your rhythm up to date.',
                      style: tt.bodySmall?.copyWith(color: ext.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Log last night',
            leadingIcon: Symbols.bedtime_rounded,
            fullWidth: true,
            accent: ext.sleep,
            onPressed: _openManualLog,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.huge),
      child: EmptyState(
        icon: Symbols.bedtime_rounded,
        title: 'No sleep logged yet',
        message:
            'Log last night to see your sleep score, stage breakdown and 7-night trend.',
        accent: AppColorsExt.of(context).sleep,
        action: AppButton(
          label: 'Log sleep',
          leadingIcon: Symbols.add_rounded,
          accent: AppColorsExt.of(context).sleep,
          onPressed: _openManualLog,
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, SleepSession night) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SleepScoreRing(
            score: night.sleepScore,
            measured: night.isMeasured,
            size: 120,
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'LAST NIGHT',
                  style: tt.labelSmall
                      ?.copyWith(color: ext.textTertiary, letterSpacing: 0.6),
                ),
                const SizedBox(height: 6),
                Text(
                  night.durationLabel,
                  style: tt.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: kTabular,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'asleep of ${night.inBedLabel} in bed',
                  style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(Symbols.calendar_today_rounded,
                        size: 13, color: ext.textTertiary),
                    const SizedBox(width: 6),
                    Text(
                      _dateLabel(night.wakeTime),
                      style:
                          tt.bodySmall?.copyWith(color: ext.textTertiary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, SleepSession night) {
    final ext = AppColorsExt.of(context);
    return StatTileRow(
      tiles: [
        StatTile(
          icon: Symbols.bedtime_rounded,
          value: night.durationLabel,
          label: 'Asleep',
          accent: ext.sleep,
        ),
        StatTile(
          icon: Symbols.king_bed_rounded,
          value: night.inBedLabel,
          label: 'In bed',
          accent: ext.sleep,
        ),
        StatTile(
          icon: Symbols.speed_rounded,
          value: '${night.efficiencyPercent}%',
          label: 'Efficiency',
          accent: ext.sleep,
        ),
      ],
    );
  }

  /// Deterministic sleep insight from debt / regularity / last night vs target.
  Insight _buildInsight(
    SleepSession night,
    int debt,
    double regularity,
    SleepSchedule schedule,
  ) {
    final target = schedule.targetMinutes;
    final asleep = night.asleepMinutes;
    final loggedNights =
        SleepService.getWeeklyTrend().where((d) => d.hasData).length;

    // Sleep balance — a gentle, symmetric note. Never a guilt-inducing "debt"
    // headline; consistency ("your rhythm") is the real hero elsewhere.
    if (debt >= 180 && loggedNights >= 4) {
      return Insight(
        id: 'sleep_balance_low',
        feature: InsightFeature.sleep,
        severity: InsightSeverity.info,
        title: 'A little behind on rest',
        detail:
            'You\'re about ${SleepSession.formatMinutes(debt)} under your target across the last 7 nights. An earlier night or two helps you get ahead.',
        metric: '${SleepSession.formatMinutes(debt)} under',
        why:
            'Your ${schedule.targetLabel} nightly target × 7, minus what you actually slept.',
        rank: 34,
      );
    }
    if (debt <= -120 && loggedNights >= 4) {
      return Insight(
        id: 'sleep_balance_up',
        feature: InsightFeature.sleep,
        severity: InsightSeverity.good,
        title: 'Rest in credit',
        detail:
            'You\'re about ${SleepSession.formatMinutes(-debt)} over your target this week — nicely rested.',
        metric: '${SleepSession.formatMinutes(-debt)} ahead',
        why:
            'What you slept over the last 7 nights vs your ${schedule.targetLabel} nightly target × 7.',
        rank: 22,
      );
    }
    if (regularity < 0.5) {
      return Insight(
        id: 'sleep_regularity',
        feature: InsightFeature.sleep,
        severity: InsightSeverity.info,
        title: 'Bedtime is drifting',
        detail:
            'Your bedtimes have varied a lot lately. A steadier schedule tends to lift sleep quality.',
        metric: '${(regularity * 100).round()}% regular',
        why: 'Based on the spread (standard deviation) of your recent bedtimes.',
        rank: 40,
      );
    }
    if (asleep >= target && night.efficiencyFraction >= 0.85) {
      return Insight(
        id: 'sleep_good',
        feature: InsightFeature.sleep,
        severity: InsightSeverity.good,
        title: 'Well rested',
        detail:
            'You met your target with high efficiency last night — keep the routine going.',
        metric: '${night.sleepScore}',
        why: 'Duration met your target and time asleep vs in bed was high.',
        rank: 24,
      );
    }
    if (asleep < target - 60) {
      return Insight(
        id: 'sleep_short',
        feature: InsightFeature.sleep,
        severity: InsightSeverity.attention,
        title: 'Short night',
        detail:
            'Last night ran ${SleepSession.formatMinutes(target - asleep)} under your target. Try winding down a little earlier tonight.',
        metric: night.durationLabel,
        why: 'Last night\'s time asleep vs your nightly target.',
        rank: 38,
      );
    }
    return Insight(
      id: 'sleep_ok',
      feature: InsightFeature.sleep,
      severity: InsightSeverity.info,
      title: 'Sleep on track',
      detail:
          'Last night was close to your target. Steady nights compound into better rest.',
      metric: night.durationLabel,
      why: 'Last night\'s duration vs your nightly target.',
      rank: 20,
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 11) return 'Good morning — how did you sleep?';
    if (h < 18) return 'Your recent sleep at a glance.';
    return 'Winding down soon? Here\'s your sleep.';
  }

  static String _dateLabel(DateTime d) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    if (that == today) return 'Today';
    if (that == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${weekdays[(d.weekday - 1) % 7]}, ${months[d.month - 1]} ${d.day}';
  }
}
