import 'dart:io' show Platform;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/health/insight.dart';
import 'package:tablet_remainder/core/utils/calendar_day.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/health_data_service.dart';
import 'package:tablet_remainder/core/services/home_widget_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/core/services/rest_day_store.dart';
import 'package:tablet_remainder/core/health/rest_days.dart' show RestKind;
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import 'package:tablet_remainder/core/widgets/app/personal_best_card.dart';
import 'package:tablet_remainder/core/milestones/milestones_screen.dart';
import 'package:tablet_remainder/core/milestones/milestones_service.dart';
import '../models/sleep_schedule.dart';
import '../models/sleep_session.dart';
import '../models/sleep_consistency.dart';
import '../services/overnight_body_service.dart';
import '../services/sleep_mover_service.dart';
import '../widgets/overnight_body_card.dart';
import '../services/sleep_service.dart';
import '../services/day_rhythm_service.dart';
import '../services/wind_down_service.dart';
import '../widgets/bedtime_plan_card.dart';
import '../widgets/day_rhythm_card.dart';
import '../widgets/sleep_consistency_card.dart';
import '../widgets/sleep_manual_log_sheet.dart';
import '../widgets/sleep_permission_card.dart';
import '../widgets/sleep_score_ring.dart';
import '../widgets/sleep_stage_timeline.dart';
import '../widgets/sleep_weekly_trend.dart';
import 'sleep_history_screen.dart';
import 'sleep_schedule_settings_screen.dart';
import '../../../core/health/coach_text.dart';
import '../../../core/health/sleep_debt.dart';
import '../widgets/sleep_score_breakdown_sheet.dart';

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

  /// Today was marked a rest day from the overnight card, and can be taken back.
  bool _restMarkedHere = false;

  Future<void> _takeRestDay() async {
    await RestDayStore.markToday(RestKind.rest);
    if (mounted) setState(() => _restMarkedHere = true);
  }

  Future<void> _undoRestDay() async {
    await RestDayStore.clear(clock.now());
    if (mounted) setState(() => _restMarkedHere = false);
  }

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
        minuteOfDay: WindDownService.minuteOfDay(),
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
    showAppToast(
      context,
      'Milestone reached · ${r.newlyEarned.first.title}',
      variant: AppToastVariant.success,
      duration: const Duration(seconds: 3),
    );
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
    if (wellRested && !already) {
      CleanStorageService.setAppPreference(key, session.dateKey);
      HapticFeedback.mediumImpact();
      showAppToast(
        context,
        'Well rested — score ${session.sleepScore}. Nice night.',
        variant: AppToastVariant.success,
        duration: const Duration(seconds: 3),
      );
    } else {
      context.toastSuccess('Sleep logged');
    }
  }

  Future<void> _connect() async {
    // Always give the user explicit feedback — the old handler was silent, so
    // denial / no-data / success all looked identical.

    // Health Connect missing/outdated: the consent sheet can't open at all, so
    // send the user to the Play Store instead of failing silently.
    if (_availability == HealthAvailability.needsProviderUpdate) {
      await HealthDataService.instance.installHealthConnect();
      // An ordinary async gap in a State method: a mounted guard is enough, so
      // the toast can take `context` rather than a pre-captured messenger.
      if (!mounted) return;
      context.toastInfo('Install Health Connect, then come back to connect.');
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
    context.toastInfo(msg);
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
            // Also on the loading state, or the way back appears only once the
            // data arrives — worst exactly when a slow load makes leaving most
            // likely.
            leading: Navigator.of(context).canPop()
                ? AppIconButton(
                    icon: Symbols.arrow_back_rounded,
                    filled: false,
                    tooltip: 'Back',
                    accent: AppColorsExt.of(context).sleep,
                    onPressed: () => Navigator.of(context).maybePop(),
                  )
                : null,
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
        ..add(_buildDayRhythm(context))
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
        ..add(_buildBedtimeGuidance(context))
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

      // The body overnight, against the person's own usual — only when a
      // wearable has given something to compare.
      final body = OvernightBody.checkFor(clock.now());
      final dip = OvernightBody.dipFor(clock.now());
      if (body != null || dip != null) {
        sections
          ..add(const SizedBox(height: AppSpacing.lg))
          ..add(OvernightBodyCard(
            accent: ext.sleep,
            check: body,
            dip: dip,
            offerRest: OvernightBody.restOffered(),
            restMarked: _restMarkedHere,
            onRest: _takeRestDay,
            onUndoRest: _undoRestDay,
          ));
      }

      // What goes with the person's longer and shorter nights (from five nights
      // on each side of a factor). Nothing at all until there is something to say.
      final movers = SleepMovers.insights();
      if (movers.isNotEmpty) {
        sections
          ..add(const SizedBox(height: AppSpacing.lg))
          ..add(SectionHeader(
            title: 'What moves your sleep',
            icon: Symbols.moving_rounded,
            accent: ext.sleep,
          ));
        for (final m in movers) {
          sections
            ..add(const SizedBox(height: AppSpacing.sm))
            ..add(InsightCard(insight: m));
        }
      }

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

    // Pull down to read the health app again: the import otherwise ran when the
    // app started and nowhere else, so last night could be in the health app and
    // not here until the next launch.
    return RefreshIndicator(
      color: ext.mark(ext.sleep),
      onRefresh: () async {
        await SleepService.syncFromHealth();
      },
      child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: AppInsets.underNav(context)),
      children: [
        if (!widget.embedded) ...[
          AppHeader(
            title: 'Sleep',
            // Sleep was the only pushed tracker with NO back affordance. Water
            // and Steps both carry one; this screen had three `actions` and no
            // `leading`, so opening it from the Health hub or the Log sheet
            // left the on-screen chrome with no way out — the user had to fall
            // back to the platform gesture.
            leading: Navigator.of(context).canPop()
                ? AppIconButton(
                    icon: Symbols.arrow_back_rounded,
                    filled: false,
                    tooltip: 'Back',
                    accent: ext.sleep,
                    onPressed: () => Navigator.of(context).maybePop(),
                  )
                : null,
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
          ),
          // The greeting, now body content rather than header chrome. It gets
          // the full content width here, so the header's one-line clamp is not
          // carried over — a greeting wrapping inside a scroller costs the
          // reader nothing, whereas in fixed chrome it cost three lines of a
          // header that never scrolled away.
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.sm),
            child: Text(
              _greeting(),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: ext.textSecondary),
            ),
          ),
        ] else
          const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: sections,
          ),
        ),
      ],
    ),
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
        weightedDebt: SleepService.sleepDebt(),
        regularity: regularity,
        // Suppresses the debt line on a partly-logged week — otherwise unlogged
        // nights read as sleep the user didn't get.
        loggedNights: SleepService.regularitySampleSize(),
      ),
    );
  }

  /// Tonight's bedtime, with its working. A soft target, never a hard time.
  Widget _buildBedtimeTip(BuildContext context) {
    final s = SleepService.getSchedule();
    return BedtimePlanCard(
      plan: SleepService.bedtimePlan(),
      windDownLeadMinutes: s.windDownMinutes,
      reminderEnabled: s.reminderEnabled,
      followPlan: s.followPlan,
      fixedReminderMinuteOfDay: s.reminderMinuteOfDay,
      onFollowPlan: () => _followPlan(true),
    );
  }

  /// A typical day from the person's wake time. Carries its own top spacing so
  /// it collapses cleanly when there is no day to lay it on.
  Widget _buildDayRhythm(BuildContext context) {
    final view = DayRhythmService.current();
    if (view == null) return const SizedBox.shrink();
    final now = clock.now();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: DayRhythmCard(
        spans: view.spans,
        wakeMinute: view.wakeMinute,
        fromNights: view.fromNights,
        nowMinute: now.hour * 60 + now.minute,
      ),
    );
  }

  /// Have the wind-down reminder follow tonight's plan (or stop), and say so.
  Future<void> _followPlan(bool follow) async {
    await SleepService.saveSchedule(
        SleepService.getSchedule().copyWith(followPlan: follow));
    await WindDownService.rearm();
    if (!mounted) return;
    if (follow) {
      context.toastSuccess(
        'The wind-down reminder now follows tonight\'s plan.',
        action: AppToastAction(label: 'Undo', onPressed: () => _followPlan(false)),
      );
    }
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

  /// What the user's best nights had in common, as a bedtime they can act on.
  ///
  /// The card above this one reports the single top-scoring night, which is an
  /// anecdote. This is the pattern behind it — and it deliberately says nothing
  /// at all rather than guessing: `BedtimeGuidance` returns null below seven
  /// scored nights, for a shift under twenty minutes, or when the best nights
  /// are not measurably better than the rest. All three of those would otherwise
  /// produce a confident sentence with nothing behind it.
  Widget _buildBedtimeGuidance(BuildContext context) {
    final g = SleepService.bedtimeGuidance();
    if (g == null) return const SizedBox.shrink();
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final t = TimeOfDay(hour: g.bedMinutes ~/ 60, minute: g.bedMinutes % 60);
    final mins = g.shiftMinutes.abs();
    final when = g.isEarlier ? 'earlier' : 'later';

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: AppCard(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: ext.sleep.container,
                borderRadius: AppRadius.brMd,
              ),
              child: Icon(Symbols.bedtime_rounded,
                  size: 20, color: ext.sleep.onContainer),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your best nights started around '
                      '${t.format(context)}',
                      style: tt.titleMedium?.copyWith(color: ext.textPrimary)),
                  const SizedBox(height: 2),
                  // The denominator, stated. "Try going to bed earlier" is
                  // advice; "your five best-scoring nights averaged 40 minutes
                  // earlier" is a fact the reader can check against their own
                  // log and disagree with.
                  Text(
                    '$mins min $when than usual, across your '
                    '${g.sampleCount} best-scoring nights',
                    style: tt.bodySmall?.copyWith(color: ext.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
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
          // Tapping the ring says what the number is made of.
          Semantics(
            button: true,
            label: 'Sleep score ${night.sleepScore}. Show how it is made',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => SleepScoreBreakdownSheet.show(context, night),
              child: SleepScoreRing(
                score: night.sleepScore,
                measured: night.isMeasured,
                size: 120,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AppEyebrow(sleepSummaryEyebrow(night.wakeTime)),
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
    // Judged and worded from the WEIGHTED 14-night debt: recent nights count
    // more, one lie-in cannot erase a week, and the line says what would clear
    // it. The credit side below stays on the plain figure, which reports a
    // surplus honestly where a capped credit would not.
    final behind = SleepService.sleepDebt();
    if (behind.debtMinutes >= 180 && behind.nights >= SleepDebt.minNights) {
      return Insight(
        id: 'sleep_balance_low',
        feature: InsightFeature.sleep,
        severity: InsightSeverity.info,
        title: 'A little behind on rest',
        detail: behind.behindLine,
        metric: '${SleepSession.formatMinutes(behind.debtMinutes)} behind',
        // Unlogged nights are missing data, never zero sleep — the defect the
        // old "× 7" total had, and the reason this says so.
        why: 'Your ${schedule.targetLabel} nightly target minus what you '
            'slept, over the ${behind.nights} night${behind.nights == 1 ? '' : 's'} '
            'you logged in the last 14. Recent nights count more, one long '
            'night pays back at most an hour, and nights you did not log are '
            'not counted.',
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
            'You\'re about ${SleepSession.formatMinutes(-debt)} over your '
            'target across the $loggedNights night${loggedNights == 1 ? '' : 's'} '
            'you logged — nicely rested.',
        metric: '${SleepSession.formatMinutes(-debt)} ahead',
        // The mirror of `sleep_balance_low`'s note above, and stale for the
        // same reason it was: "last 7 nights … × 7" described the OLD
        // `sleepDebtMinutes`, which charged every un-logged night a full
        // night's target. It now divides by logged nights only, so the credit
        // side has to say so too — a surplus quoted against seven nights when
        // four were logged is as invented as the debt was.
        why: 'What you actually slept across the $loggedNights logged '
            'night${loggedNights == 1 ? '' : 's'}, minus your '
            '${schedule.targetLabel} nightly target for each of them. Nights '
            'you did not log are not counted.',
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

/// "LAST NIGHT" only when the card really is showing last night.
///
/// The summary card renders the most recent *logged* session, which on a
/// morning you have not logged yet is an older night. On device it read
/// "LAST NIGHT · 7h 39m · Mon, Sep 28" on Sep 30 — directly beneath a "Log
/// last night" button, which is only offered because last night has no
/// session at all. The card and the button contradicted each other.
///
/// A wake time today is plainly last night. One yesterday still is, for
/// somebody reading this after midnight and before they have slept.
@visibleForTesting
String sleepSummaryEyebrow(DateTime wakeTime, {DateTime? now}) =>
    calendarDaysBetween(wakeTime, now ?? clock.now()) <= 1
        ? 'LAST NIGHT'
        : 'MOST RECENT';
