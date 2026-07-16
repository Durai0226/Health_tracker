import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/ai/ai_assistant.dart';
import '../../../core/services/clean_storage_service.dart';
import '../../medication/services/medicine_storage_service.dart';
import '../../medication/models/medicine_log.dart';
import '../../water/services/water_service.dart';
import '../../water/models/enhanced_water_log.dart';
import '../../water/models/beverage_type.dart';
import '../../focus/services/focus_service.dart';
import '../../reminders/models/reminder_model.dart';
import '../../reminders/screens/add_reminder_screen.dart';
import '../../settings/screens/settings_screen.dart';

/// The unified landing screen — one calm "today" snapshot across every feature.
/// The only greeting in the app.
class HomeDashboard extends StatefulWidget {
  /// Switches the shell destination; [healthTab] selects Medicine(0)/Water(1).
  final void Function(int index, {int? healthTab}) onNavigate;

  /// Bumped by the shell whenever Home is re-selected. Lets the sync-only
  /// surfaces (reminders roll-up + card) refresh when the user returns to Home,
  /// since — unlike medicine/water/focus — they have no change notifier.
  final int refreshTick;

  const HomeDashboard({
    super.key,
    required this.onNavigate,
    this.refreshTick = 0,
  });

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  final AuthService _authService = AuthService();
  final FocusService _focus = FocusService();

  // Medicine data is async; memoize it against the service revision so it only
  // re-queries when medicine data actually changed (a dose logged, a medicine
  // added/removed, …) rather than on every unrelated rebuild.
  int _medRev = -1;
  Future<_MedicineHomeData>? _medFuture;

  Future<_MedicineHomeData> _medicineData(int rev) {
    if (_medFuture == null || _medRev != rev) {
      _medRev = rev;
      _medFuture = _loadMedicineData();
    }
    return _medFuture!;
  }

  Future<_MedicineHomeData> _loadMedicineData() async {
    final now = DateTime.now();
    final summary = await MedicineCleanStorageService.getDailySummaryAsync(now);
    final meds = await MedicineCleanStorageService.getAllMedicines();
    final streak = await MedicineCleanStorageService.getCurrentStreak();
    return _MedicineHomeData(
      summary: summary,
      hasMedicines: meds.isNotEmpty,
      streak: streak,
    );
  }

  @override
  void didUpdateWidget(covariant HomeDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Returning to Home recomputes the sync parts (reminders have no notifier).
    if (oldWidget.refreshTick != widget.refreshTick && mounted) {
      setState(() {});
    }
  }

  Future<void> _refreshAll() async {
    setState(() => _medFuture = null); // force a fresh medicine query
    await Future.delayed(const Duration(milliseconds: 300));
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _dateLabel => DateFormat('EEEE, MMM d').format(DateTime.now());

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    ).then((_) => mounted ? setState(() {}) : null);
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final name = _authService.currentUser?.name ?? '';
    return AppScaffold(
      body: RefreshIndicator(
        color: ext.brand.base,
        onRefresh: _refreshAll,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: AppHeader(
                greeting: '$_greeting · $_dateLabel',
                title: name.isNotEmpty ? name : 'Welcome back',
                accent: ext.brand,
                actions: [
                  AppIconButton(
                    icon: Icons.settings_rounded,
                    accent: ext.brand,
                    onPressed: _openSettings,
                    tooltip: 'Settings',
                  ),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter, AppSpacing.xs, AppSpacing.gutter, 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildContextLine(ext),
                  _buildQuickActions(ext),
                  const SizedBox(height: AppSpacing.xl),
                  _buildRollup(ext),
                  const SizedBox(height: AppSpacing.xl),
                  SectionHeader(title: 'Today', accent: ext.brand),
                  const SizedBox(height: AppSpacing.xs),
                  _buildMedicineCard(ext),
                  const SizedBox(height: AppSpacing.lg),
                  _buildWaterCard(ext),
                  const SizedBox(height: AppSpacing.lg),
                  _buildWeeklyStrip(ext),
                  const SizedBox(height: AppSpacing.lg),
                  // IntrinsicHeight keeps the two cards equal to the taller one
                  // and lets them grow with text scale instead of overflowing a
                  // fixed 132px box. Stretch makes both fill that shared height.
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _buildFocusCard(ext)),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(child: _buildRemindersCard(ext)),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- daily roll-up hero --------------------------------------------------

  /// A single "X of 4 done today" hero, combining the four daily wins:
  /// medicine (all due doses taken), water (goal reached), focus (any minutes),
  /// reminders (all of today's complete). Wrapped in every relevant notifier so
  /// it stays live while Home is parked in the shell's IndexedStack.
  Widget _buildRollup(AppColorsExt ext) {
    final waterListenable = WaterService.listenToDailyData();
    return ValueListenableBuilder<int>(
      valueListenable: MedicineCleanStorageService.revision,
      builder: (context, rev, _) {
        return ListenableBuilder(
          listenable: _focus,
          builder: (context, __) {
            Widget content() => FutureBuilder<_MedicineHomeData>(
                  future: _medicineData(rev),
                  builder: (context, snapshot) {
                    final s = snapshot.data?.summary;
                    final medTotal = s?.totalScheduled ?? 0;
                    final medTaken = s?.taken ?? 0;
                    // Nothing due today counts as done — you can't do more.
                    final medDone = medTotal == 0 || medTaken >= medTotal;

                    final water = WaterService.getTodayData();
                    final goal = WaterService.getDailyGoal();
                    final waterDone = goal > 0 && water.goalReached;

                    final focusDone = _focus.todayMinutes > 0;

                    final now = DateTime.now();
                    final todaysReminders = CleanStorageService.getReminders()
                        .where((r) => _isSameDay(r.scheduledTime, now))
                        .toList();
                    final remindersDone = todaysReminders.isEmpty ||
                        todaysReminders.every((r) => r.isCompleted);

                    final done = [medDone, waterDone, focusDone, remindersDone]
                        .where((b) => b)
                        .length;
                    return _rollupCard(ext, done);
                  },
                );

            if (waterListenable == null) return content();
            return ValueListenableBuilder<Map<String, DailyWaterData>>(
              valueListenable: waterListenable,
              builder: (context, ___, ____) => content(),
            );
          },
        );
      },
    );
  }

  Widget _rollupCard(AppColorsExt ext, int done) {
    final tt = Theme.of(context).textTheme;
    final String line;
    if (done >= 4) {
      line = 'Every daily goal met — beautifully done.';
    } else if (done == 0) {
      line = 'A fresh start. Small steps count.';
    } else {
      line = "Keep going — you're building momentum.";
    }
    return AppCard(
      child: Row(
        children: [
          ProgressRing(
            progress: done / 4,
            size: 76,
            stroke: 7,
            accent: ext.brand,
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$done',
                    style: tt.headlineSmall?.copyWith(
                        color: ext.brand.strong, fontWeight: FontWeight.w800)),
                Text('of 4',
                    style: tt.labelSmall?.copyWith(color: ext.textTertiary)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$done of 4 done today', style: tt.titleLarge),
                const SizedBox(height: 4),
                Text(line,
                    style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- contextual nudge ----------------------------------------------------

  /// One subtle line above the quick actions, sourced from live insights:
  /// A warm one/two-sentence AI "daily briefing" across all four features.
  /// Always shown — the AiAssistant always answers (free on-device rule engine),
  /// so there is no configured/unconfigured branch anymore.
  Widget _buildContextLine(AppColorsExt ext) => _buildAiBriefing(ext);

  /// AI "daily briefing" — a warm one/two-sentence summary across the four
  /// features. Always available; the [AiInsightCard] self-loads, shows a
  /// thinking/retry state, and offers a manual refresh.
  Widget _buildAiBriefing(AppColorsExt ext) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: AiInsightCard(
        title: 'Daily briefing',
        icon: Icons.auto_awesome_rounded,
        accent: ext.brand,
        loader: () async {
          final d = await _briefingData();
          return AiAssistant().dailyBriefing(
            medsTaken: d.medsTaken,
            medsTotal: d.medsTotal,
            waterPct: d.waterPct,
            focusMinutes: d.focusMinutes,
            remindersLeft: d.remindersLeft,
            hour: DateTime.now().hour,
          );
        },
      ),
    );
  }

  /// Gathers today's four-feature roll-up as the numeric inputs the
  /// [AiAssistant.dailyBriefing] intent expects. Reuses the exact same live
  /// sources the manual dashboard reads.
  Future<_BriefingData> _briefingData() async {
    final now = DateTime.now();

    final med = await _medicineData(MedicineCleanStorageService.revision.value);
    final s = med.summary;
    final medsTotal = s.totalScheduled;
    final medsTaken = s.taken;

    final goal = WaterService.getDailyGoal();
    final water = WaterService.getTodayData();
    final waterPct = goal > 0
        ? ((water.effectiveHydrationMl / goal) * 100).round().clamp(0, 100)
        : 0;

    final focusMinutes = _focus.todayMinutes;

    final todays = CleanStorageService.getReminders()
        .where((r) => _isSameDay(r.scheduledTime, now))
        .toList();
    final remindersLeft = todays.where((r) => !r.isCompleted).length;

    return _BriefingData(
      medsTaken: medsTaken,
      medsTotal: medsTotal,
      waterPct: waterPct,
      focusMinutes: focusMinutes,
      remindersLeft: remindersLeft,
    );
  }

  // ---- quick actions -------------------------------------------------------

  Widget _buildQuickActions(AppColorsExt ext) {
    return Row(
      children: [
        _quickAction(ext.water, Icons.water_drop_rounded, '+250ml', _quickAddWater),
        const SizedBox(width: AppSpacing.md),
        _quickAction(ext.medicine, Icons.medication_rounded, 'Meds',
            () => widget.onNavigate(1, healthTab: 0)),
        const SizedBox(width: AppSpacing.md),
        _quickAction(ext.focus, Icons.self_improvement_rounded, 'Focus',
            () => widget.onNavigate(2)),
        const SizedBox(width: AppSpacing.md),
        _quickAction(ext.reminders, Icons.add_alert_rounded, 'Remind', _addReminder),
      ],
    );
  }

  Widget _quickAction(AccentSwatch s, IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: s.container,
        borderRadius: AppRadius.brLg,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              children: [
                Icon(icon, color: s.onContainer, size: 24),
                const SizedBox(height: 6),
                Text(label,
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: s.onContainer)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _quickAddWater() async {
    final water =
        WaterService.getBeverage('water') ?? BeverageType.defaultBeverages.first;
    await WaterService.addWaterLog(amountMl: 250, beverage: water);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('+250 ml logged'), duration: Duration(seconds: 1)),
      );
    }
  }

  void _addReminder() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AddReminderScreen()))
        .then((_) => mounted ? setState(() {}) : null);
  }

  // ---- shared feature card -------------------------------------------------

  Widget _featureCard({
    required AccentSwatch accent,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
    Widget? badge,
  }) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: accent.container, borderRadius: AppRadius.brMd),
            child: Icon(icon, color: accent.onContainer, size: 24),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(title, style: tt.titleLarge)),
                    if (badge != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      badge,
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          trailing ?? Icon(Icons.chevron_right_rounded, color: ext.textTertiary),
        ],
      ),
    );
  }

  /// A "fire" streak badge, shown on a feature card when the streak is > 0.
  Widget _streakChip(AccentSwatch accent, int streak) => AppChip(
        label: '$streak',
        icon: Icons.local_fire_department_rounded,
        accent: accent,
        selected: true,
      );

  /// A card-shaped empty state with a CTA into the relevant setup flow.
  Widget _emptyCard({
    required AccentSwatch accent,
    required IconData icon,
    required String title,
    required String message,
    required String ctaLabel,
    required VoidCallback onCta,
  }) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: EmptyState(
        icon: icon,
        title: title,
        message: message,
        accent: accent,
        action: AppButton(
          label: ctaLabel,
          onPressed: onCta,
          accent: accent,
          variant: AppButtonVariant.tonal,
          size: AppButtonSize.sm,
          leadingIcon: Icons.add_rounded,
        ),
      ),
    );
  }

  /// A compact empty-state CTA sized for the 2-up row (Focus / Reminders).
  /// Tapping the whole card runs [onCta]; a subtle "add" affordance signals it.
  Widget _compactEmptyCard({
    required AccentSwatch accent,
    required IconData icon,
    required String title,
    required String ctaLabel,
    required VoidCallback onCta,
  }) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return AppCard(
      onTap: onCta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration:
                BoxDecoration(color: accent.container, borderRadius: AppRadius.brMd),
            child: Icon(icon, color: accent.onContainer, size: 22),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: tt.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(Icons.add_rounded, size: 16, color: ext.mark(accent)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(ctaLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.labelMedium?.copyWith(color: ext.mark(accent))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---- medicine ------------------------------------------------------------

  Widget _buildMedicineCard(AppColorsExt ext) {
    return ValueListenableBuilder<int>(
      valueListenable: MedicineCleanStorageService.revision,
      builder: (context, rev, _) {
        return FutureBuilder<_MedicineHomeData>(
          future: _medicineData(rev),
          builder: (context, snapshot) {
            final data = snapshot.data;

            // No medicines at all → CTA into the add-medicine flow.
            if (data != null && !data.hasMedicines) {
              return _emptyCard(
                accent: ext.medicine,
                icon: Icons.medication_rounded,
                title: 'No medicines yet',
                message: 'Add a medicine to start tracking your doses.',
                ctaLabel: 'Add medicine',
                onCta: () => widget.onNavigate(1, healthTab: 0),
              );
            }

            final s = data?.summary;
            final total = s?.totalScheduled ?? 0;
            final taken = s?.taken ?? 0;
            final missed = s?.missed ?? 0;
            final adherence = s?.adherenceRate ?? 0;
            final streak = data?.streak ?? 0;

            final String status;
            if (total == 0) {
              status = 'No doses scheduled today';
            } else if (taken >= total) {
              status = 'All doses taken — nice work';
            } else if (missed > 0) {
              status = '$missed missed · ${total - taken - missed} left today';
            } else {
              status = '${total - taken} of $total doses left today';
            }

            return _featureCard(
              accent: ext.medicine,
              icon: Icons.medication_rounded,
              title: 'Medicine',
              subtitle: status,
              onTap: () => widget.onNavigate(1, healthTab: 0),
              badge: streak > 0 ? _streakChip(ext.medicine, streak) : null,
              trailing: total > 0
                  ? ProgressRing(
                      progress: taken / total,
                      size: 48,
                      stroke: 5,
                      accent: ext.medicine,
                      center: Text('${(adherence * 100).round()}%',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: ext.medicine.strong,
                              fontWeight: FontWeight.w800)),
                    )
                  : null,
            );
          },
        );
      },
    );
  }

  // ---- water ---------------------------------------------------------------

  Widget _buildWaterCard(AppColorsExt ext) {
    final listenable = WaterService.listenToDailyData();
    if (listenable == null) return _waterCardBody(ext, WaterService.getTodayData());
    return ValueListenableBuilder<Map<String, DailyWaterData>>(
      valueListenable: listenable,
      builder: (context, _, __) => _waterCardBody(ext, WaterService.getTodayData()),
    );
  }

  Widget _waterCardBody(AppColorsExt ext, DailyWaterData data) {
    final goal = WaterService.getDailyGoal();

    // No goal configured → CTA into the hydration setup flow.
    if (goal <= 0) {
      return _emptyCard(
        accent: ext.water,
        icon: Icons.water_drop_rounded,
        title: 'Set a hydration goal',
        message: 'Tell us a bit about you to get a daily water target.',
        ctaLabel: 'Set goal',
        onCta: () => widget.onNavigate(1, healthTab: 1),
      );
    }

    final progress = data.effectiveHydrationMl / goal;
    final remaining = (goal - data.effectiveHydrationMl).clamp(0, goal);
    final streak = WaterService.getCurrentStreak();
    return _featureCard(
      accent: ext.water,
      icon: Icons.water_drop_rounded,
      title: 'Hydration',
      subtitle: (data.effectiveHydrationMl >= goal)
          ? 'Goal reached · ${data.effectiveHydrationMl} ml'
          : '${data.effectiveHydrationMl} / $goal ml · $remaining ml to go',
      onTap: () => widget.onNavigate(1, healthTab: 1),
      badge: streak > 0 ? _streakChip(ext.water, streak) : null,
      trailing: ProgressRing(
        progress: progress.clamp(0.0, 1.0),
        size: 48,
        stroke: 5,
        accent: ext.water,
        center: Text('${(progress * 100).round()}%',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: ext.water.strong, fontWeight: FontWeight.w800)),
      ),
    );
  }

  // ---- weekly strip --------------------------------------------------------

  /// A compact 7-day mini-bar strip for water and focus. Wrapped in both the
  /// water and focus notifiers so it tracks live like the rest of the dashboard.
  Widget _buildWeeklyStrip(AppColorsExt ext) {
    final waterListenable = WaterService.listenToDailyData();
    return ListenableBuilder(
      listenable: _focus,
      builder: (context, _) {
        Widget content() => _weeklyStripBody(ext);
        if (waterListenable == null) return content();
        return ValueListenableBuilder<Map<String, DailyWaterData>>(
          valueListenable: waterListenable,
          builder: (context, __, ___) => content(),
        );
      },
    );
  }

  Widget _weeklyStripBody(AppColorsExt ext) {
    final tt = Theme.of(context).textTheme;
    final now = DateTime.now();
    final days = List<DateTime>.generate(
        7, (i) => DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: 6 - i)));
    final labels =
        days.map((d) => DateFormat('E').format(d).substring(0, 1)).toList();

    // Water: fraction of each day's goal reached (capped at 1.0).
    final waterValues = days.map((d) {
      final data = WaterService.getDataForDate(d);
      if (data == null) return 0.0;
      final goal = data.dailyGoalMl > 0 ? data.dailyGoalMl : WaterService.getDailyGoal();
      if (goal <= 0) return 0.0;
      return (data.effectiveHydrationMl / goal).clamp(0.0, 1.0);
    }).toList();

    // Focus: completed minutes per day, normalized to the busiest day.
    final focusMinutes = days.map((d) {
      return _focus.sessions
          .where((s) => s.wasCompleted && _isSameDay(s.startedAt, d))
          .fold<int>(0, (sum, s) => sum + s.actualMinutes);
    }).toList();
    final maxFocus = focusMinutes.fold<int>(0, (m, v) => v > m ? v : m);
    final focusValues = focusMinutes
        .map((m) => maxFocus > 0 ? m / maxFocus : 0.0)
        .toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('This week', style: tt.titleMedium),
          const SizedBox(height: AppSpacing.md),
          _miniBars(ext, ext.water, 'Water', waterValues, labels, 6),
          const SizedBox(height: AppSpacing.md),
          _miniBars(ext, ext.focus, 'Focus', focusValues, labels, 6),
        ],
      ),
    );
  }

  Widget _miniBars(AppColorsExt ext, AccentSwatch accent, String label,
      List<double> values, List<String> labels, int todayIndex) {
    final tt = Theme.of(context).textTheme;
    const barsHeight = 34.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 46,
          child: Text(label,
              style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final v = values[i].clamp(0.0, 1.0);
              final isToday = i == todayIndex;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: AppRadius.brSm,
                        child: Container(
                          height: barsHeight,
                          color: accent.container,
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor: v == 0 ? 0.0 : v,
                            child: Container(color: ext.mark(accent)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(labels[i],
                          style: tt.labelSmall?.copyWith(
                              color: isToday ? ext.mark(accent) : ext.textTertiary,
                              fontWeight:
                                  isToday ? FontWeight.w800 : FontWeight.w500)),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  // ---- focus (tamed to sibling parity, keeps purple accent) ----------------

  // Compact card for the 2-up row (Focus / Reminders).
  Widget _compactCard({
    required AccentSwatch accent,
    required IconData icon,
    required String title,
    required String value,
    required String sub,
    required VoidCallback onTap,
    Widget? badge,
  }) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration:
                    BoxDecoration(color: accent.container, borderRadius: AppRadius.brMd),
                child: Icon(icon, color: accent.onContainer, size: 22),
              ),
              const Spacer(),
              if (badge != null) badge,
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(title, style: tt.titleMedium),
          const SizedBox(height: 2),
          Text(sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildFocusCard(AppColorsExt ext) {
    return ListenableBuilder(
      listenable: _focus,
      builder: (context, _) {
        final mins = _focus.todayMinutes;
        final streak = _focus.stats.currentStreak;
        return _compactCard(
          accent: ext.focus,
          icon: Icons.self_improvement_rounded,
          title: 'Focus',
          value: mins > 0 ? '$mins min' : 'Start',
          sub: streak > 0 ? '$streak-day streak' : 'Ready to focus?',
          onTap: () => widget.onNavigate(2),
          badge: streak > 0
              ? Icon(Icons.local_fire_department_rounded,
                  size: 18, color: ext.focus.strong)
              : null,
        );
      },
    );
  }

  // ---- reminders -----------------------------------------------------------

  Widget _buildRemindersCard(AppColorsExt ext) {
    final reminders = CleanStorageService.getReminders();
    final now = DateTime.now();
    final pending = reminders.where((r) => !r.isCompleted).toList()
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    final today = pending
        .where((r) => _isSameDay(r.scheduledTime, now))
        .toList();
    // Today's reminders split by urgency: overdue (slot already passed) vs later.
    final overdue = today.where((r) => r.scheduledTime.isBefore(now)).toList();
    final upcoming = pending.where((r) => r.scheduledTime.isAfter(now)).toList();
    final Reminder? next =
        today.isNotEmpty ? today.first : (upcoming.isNotEmpty ? upcoming.first : null);

    // No reminders at all → compact CTA that fits the 2-up row footprint.
    if (reminders.isEmpty) {
      return _compactEmptyCard(
        accent: ext.reminders,
        icon: Icons.notifications_rounded,
        title: 'No reminders',
        ctaLabel: 'Add reminder',
        onCta: _addReminder,
      );
    }

    return _compactCard(
      accent: ext.reminders,
      icon: Icons.notifications_rounded,
      title: 'Reminders',
      value: overdue.isNotEmpty
          ? '${overdue.length} overdue'
          : (today.isNotEmpty
              ? '${today.length} today'
              : (next != null ? _formatTime(next.scheduledTime) : 'All clear')),
      sub: next == null ? 'Nothing upcoming' : next.title,
      onTap: () => widget.onNavigate(3),
      // Overdue gets a warning-tone count; otherwise the calm today count.
      badge: overdue.isNotEmpty
          ? CountBadge(count: overdue.length, accent: ext.warning)
          : (today.isNotEmpty
              ? CountBadge(count: today.length, accent: ext.reminders)
              : null),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatTime(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.hour >= 12 ? 'PM' : 'AM'}';
  }
}

/// Numeric roll-up of today's four features, fed to [AiAssistant.dailyBriefing].
class _BriefingData {
  final int medsTaken;
  final int medsTotal;
  final int waterPct;
  final int focusMinutes;
  final int remindersLeft;

  const _BriefingData({
    required this.medsTaken,
    required this.medsTotal,
    required this.waterPct,
    required this.focusMinutes,
    required this.remindersLeft,
  });
}

/// Bundled medicine data for the Home dashboard, loaded once per revision.
class _MedicineHomeData {
  final DailyMedicineSummary summary;
  final bool hasMedicines;
  final int streak;

  const _MedicineHomeData({
    required this.summary,
    required this.hasMedicines,
    required this.streak,
  });
}
