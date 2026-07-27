import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/ai/ai_assistant.dart';
import '../../../core/services/clean_storage_service.dart';
import '../../medication/services/medicine_storage_service.dart';
import '../../medication/services/today_schedule_service.dart';
import '../../medication/screens/nunito_take_medication_sheet.dart';
import '../../medication/models/medicine_log.dart';
import '../../water/services/water_service.dart';
import '../../water/models/enhanced_water_log.dart';
import '../../focus/services/focus_service.dart';
import '../../steps/services/step_service.dart';
import '../../sleep/services/sleep_service.dart';
import '../../reminders/models/reminder_model.dart';
import '../../reminders/screens/add_reminder_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../insights/screens/insights_hub_screen.dart';
import '../../insights/screens/proactive_nudge.dart';
import '../widgets/log_something_sheet.dart';
import '../../../widgets/smart_ad_widgets.dart';
import '../../../core/widgets/app/vitals_theme.dart';
import '../../medication/services/vitals_storage_service.dart';
import '../../period/services/period_service.dart';

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

  // The daily-briefing sentence is loaded once (like the old AiInsightCard) and
  // reset on pull-to-refresh, so it doesn't re-run on every unrelated rebuild.
  Future<String?>? _briefingFuture;

  // Latest BP/glucose readings for the quick-log deck are async; memoize them
  // against the vitals revision so they only re-query on an actual vitals write.
  int _vitalsRev = -1;
  Future<_DeckVitals>? _vitalsFuture;

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
    final doses = await TodayScheduleService.getTodaysDoses(now);
    return _MedicineHomeData(
      summary: summary,
      hasMedicines: meds.isNotEmpty,
      streak: streak,
      nextDose: TodayScheduleService.nextDose(doses, now),
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
    setState(() {
      _medFuture = null; // force a fresh medicine query
      _briefingFuture = null; // re-run the daily briefing
      _vitalsFuture = null; // re-read latest BP/glucose
    });
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

  /// Open the take-medication sheet for a dose. The sheet self-persists and
  /// bumps [MedicineCleanStorageService.revision], so the hero + cards + roll-up
  /// all refresh automatically (they listen to that notifier).
  Future<void> _openTakeSheet(ScheduledDose dose) async {
    await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NunitoTakeMedicationSheet(
        medicine: dose.medicine,
        scheduledTime: dose.scheduledTime,
      ),
    );
  }

  // ---- shared live wiring + pillar maths -----------------------------------

  /// Wraps [child] in the exact notifier nesting the dashboard uses to stay live
  /// while Home is parked in the shell's IndexedStack: medicine revision → focus
  /// → water. [child] receives the current medicine revision for the future.
  Widget _liveBuilder(AppColorsExt ext, Widget Function(int rev) child) {
    final waterListenable = WaterService.listenToDailyData();
    return ValueListenableBuilder<int>(
      valueListenable: MedicineCleanStorageService.revision,
      builder: (context, rev, _) {
        return ListenableBuilder(
          listenable: _focus,
          builder: (context, __) {
            Widget content() => child(rev);
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

  /// The four daily pillars (medicine / water / focus / reminders) read from the
  /// same live sources the feature cards use. Shared by the hero fallback and
  /// the pulse row so a "done" count is computed in exactly one place.
  _PillarStats _pillarStats(DailyMedicineSummary? summary) {
    final medTotal = summary?.totalScheduled ?? 0;
    final medTaken = summary?.taken ?? 0;
    // Nothing due today counts as done — you can't do more.
    final medDone = medTotal == 0 || medTaken >= medTotal;

    final goal = WaterService.getDailyGoal();
    final water = WaterService.getTodayData();
    final waterMl = water.effectiveHydrationMl;
    final waterPct =
        goal > 0 ? ((waterMl / goal) * 100).round().clamp(0, 100) : 0;
    final waterDone = goal > 0 && water.goalReached;

    final focusMin = _focus.todayMinutes;
    final focusDone = focusMin > 0;

    final now = DateTime.now();
    final todays = CleanStorageService.getReminders()
        .where((r) => _isSameDay(r.scheduledTime, now))
        .toList();
    final remTotal = todays.length;
    final remDone = todays.where((r) => r.isCompleted).length;
    final remindersDone = remTotal == 0 || remDone >= remTotal;

    final done = [medDone, waterDone, focusDone, remindersDone]
        .where((b) => b)
        .length;
    return _PillarStats(
      medTaken: medTaken,
      medTotal: medTotal,
      waterMl: waterMl,
      waterGoal: goal,
      waterPct: waterPct,
      waterDone: waterDone,
      focusMin: focusMin,
      remDone: remDone,
      remTotal: remTotal,
      done: done,
    );
  }

  String _rollupLine(int done) {
    if (done >= 4) return 'Every daily goal met — beautifully done.';
    if (done == 0) return 'A fresh start. Small steps count.';
    return "Keep going — you're building momentum.";
  }

  /// The single ELEVATED tier on Today: flat surfaceElevated fill + the elevated
  /// shadow, with an outlineStrong hairline on dark only (light leans on shadow).
  /// No gradient/glass — figure/ground does the premium work.
  Widget _heroShell(AppColorsExt ext, {required Widget child, Color? color}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      decoration: BoxDecoration(
        color: color ?? ext.surfaceElevated,
        borderRadius: AppRadius.brCard,
        border: ext.isDark
            ? Border.all(color: ext.outlineStrong, width: 1)
            : null,
        boxShadow: AppShadows.elevated(context),
      ),
      child: child,
    );
  }

  /// The next-dose HERO — the single most important thing on Today, and the ONLY
  /// elevated card. It is ALWAYS present across three states: a due/overdue dose
  /// with a 1-tap "Take", a calm "all done" state, or an at-a-glance fallback
  /// (no medicines / guest). Never returns SizedBox.shrink.
  Widget _buildNextDoseHero(AppColorsExt ext) {
    final tt = Theme.of(context).textTheme;
    return _liveBuilder(ext, (rev) {
      return FutureBuilder<_MedicineHomeData>(
        future: _medicineData(rev),
        builder: (context, snap) {
          final data = snap.data;
          final hasMeds = data?.hasMedicines ?? false;
          final dose = data?.nextDose;
          final taken = data?.summary.taken ?? 0;
          final total = data?.summary.totalScheduled ?? 0;

          // NEXT-DOSE — meds exist and something is due.
          if (hasMeds && dose != null) {
            final overdue = dose.scheduledTime.isBefore(DateTime.now());
            final accent = overdue ? ext.error : ext.medicine;
            final timeLabel = DateFormat('h:mm a').format(dose.scheduledTime);
            final med = dose.medicine;
            return _heroShell(
              ext,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: ext.fillBg(accent),
                            borderRadius: AppRadius.brMd),
                        child: Icon(Symbols.medication_rounded,
                            color: ext.fillFg(accent), size: 28),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (overdue) ...[
                                  _PulseDot(color: ext.mark(accent)),
                                  const SizedBox(width: 6),
                                ],
                                Flexible(
                                  child: Text(
                                      overdue
                                          ? 'OVERDUE · $timeLabel'
                                          : 'UP NEXT · $timeLabel',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: tt.labelSmall?.copyWith(
                                          color: ext.mark(accent),
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                          fontFeatures: kTabular)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(med.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tt.titleLarge?.copyWith(
                                    color: ext.textPrimary,
                                    fontWeight: FontWeight.w700)),
                            if (med.strength != null &&
                                med.strength!.isNotEmpty)
                              Text(med.strength!,
                                  style: tt.bodySmall
                                      ?.copyWith(color: ext.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'Take',
                    leadingIcon: Symbols.check_rounded,
                    accent: accent,
                    emphasized: true,
                    fullWidth: true,
                    onPressed: () => _openTakeSheet(dose),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  GestureDetector(
                    onTap: () => widget.onNavigate(1, healthTab: 0),
                    child: Text('$taken of $total taken today · See all',
                        style:
                            tt.bodySmall?.copyWith(color: ext.textSecondary)),
                  ),
                ],
              ),
            );
          }

          // ALL-DONE — meds exist, nothing due, and everything's been taken.
          if (hasMeds && total > 0 && taken >= total) {
            return _heroShell(
              ext,
              color: Color.alphaBlend(
                  ext.success.container.withOpacity(ext.isDark ? 0.18 : 0.5),
                  ext.surfaceElevated),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: ext.fillBg(ext.success),
                        borderRadius: AppRadius.brMd),
                    child: Icon(Symbols.task_alt_rounded,
                        color: ext.fillFg(ext.success), size: 28),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Perfect day — everything's done",
                            style: tt.titleMedium?.copyWith(
                                color: ext.textPrimary,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('$taken of $total today · nice work',
                            style: tt.bodySmall
                                ?.copyWith(color: ext.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          // AT-A-GLANCE fallback — no medicines (or none scheduled). Never shrink.
          final p = _pillarStats(data?.summary);
          final done = p.done;
          return _heroShell(
            ext,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ProgressRing(
                  progress: done / 4,
                  size: 104,
                  stroke: 10,
                  accent: ext.brand,
                  animate: !MediaQuery.of(context).disableAnimations,
                  center: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$done',
                          style: tt.headlineLarge?.copyWith(
                              color: ext.mark(ext.brand),
                              fontWeight: FontWeight.w800,
                              fontFeatures: kTabular)),
                      Text('OF 4',
                          style: tt.labelSmall?.copyWith(
                              color: ext.textTertiary, letterSpacing: 0.5)),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Today at a glance',
                          style: tt.titleMedium?.copyWith(
                              color: ext.textPrimary,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(_rollupLine(done),
                          style: tt.bodyMedium
                              ?.copyWith(color: ext.textSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: 'Log something',
                        leadingIcon: Symbols.add_rounded,
                        accent: ext.brand,
                        variant: AppButtonVariant.tonal,
                        fullWidth: true,
                        onPressed: () => LogSomethingSheet.show(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    });
  }

  // --- Today card customization (show/hide, persisted) ---------------------
  static const List<String> _todayCardOrder = [
    'medicine',
    'water',
    'weekly',
    'activity'
  ];

  List<String> _hiddenTodayCards() {
    final raw = CleanStorageService.getAppPreference(
        'today_hidden_cards', const <String>[]);
    return raw is List ? raw.map((e) => e.toString()).toList() : const <String>[];
  }

  String _todayCardLabel(String id) {
    switch (id) {
      case 'medicine':
        return 'Medicine';
      case 'water':
        return 'Water';
      case 'weekly':
        return 'Weekly activity';
      case 'activity':
        return 'Focus & reminders';
    }
    return id;
  }

  Widget _todayCard(String id, AppColorsExt ext) {
    switch (id) {
      case 'medicine':
        return _buildMedicineCard(ext);
      case 'water':
        return _buildWaterCard(ext);
      case 'weekly':
        return _buildWeeklyStrip(ext);
      case 'activity':
        // IntrinsicHeight keeps the two cards equal to the taller one.
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildFocusCard(ext)),
              const SizedBox(width: AppSpacing.lg),
              Expanded(child: _buildRemindersCard(ext)),
            ],
          ),
        );
    }
    return const SizedBox.shrink();
  }

  Future<void> _openCustomizeToday() async {
    final ext = AppColorsExt.of(context);
    await AppBottomSheet.show<void>(
      context,
      title: 'Customize Today',
      icon: Symbols.tune_rounded,
      accent: ext.brand,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final hidden = _hiddenTodayCards();
          Future<void> setCardVisible(String id, bool v) async {
            final next = _hiddenTodayCards().toSet();
            if (v) {
              next.remove(id);
            } else {
              next.add(id);
            }
            await CleanStorageService.setAppPreference(
                'today_hidden_cards', next.toList());
            setSheet(() {});
            if (mounted) setState(() {});
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Choose which cards show on Today.',
                  style: Theme.of(ctx)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: ext.textSecondary)),
              const SizedBox(height: AppSpacing.xs),
              for (final id in _todayCardOrder)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_todayCardLabel(id)),
                  trailing: AppSwitch(
                    value: !hidden.contains(id),
                    onChanged: (v) => setCardVisible(id, v),
                  ),
                  onTap: () => setCardVisible(id, hidden.contains(id)),
                ),
              const SizedBox(height: AppSpacing.sm),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final name = _authService.currentUser?.name ?? '';
    final hidden = _hiddenTodayCards();
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
                  // Medicine streak pill — live via the revision notifier, shown
                  // only when the streak is > 0.
                  ValueListenableBuilder<int>(
                    valueListenable: MedicineCleanStorageService.revision,
                    builder: (context, rev, _) => FutureBuilder<_MedicineHomeData>(
                      future: _medicineData(rev),
                      builder: (context, snap) {
                        final streak = snap.data?.streak ?? 0;
                        if (streak <= 0) return const SizedBox.shrink();
                        return AppChip(
                          label: '$streak',
                          icon: Symbols.local_fire_department_rounded,
                          accent: ext.brand,
                          selected: true,
                        );
                      },
                    ),
                  ),
                  AppIconButton(
                    icon: Symbols.settings_rounded,
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
                  // 2 — flat AI whisper (deterministic → time-of-day glyph).
                  _buildBriefingStrip(ext),
                  const SizedBox(height: AppSpacing.lg),
                  // 3 — self-gating attention/urgent nudge, above the hero.
                  const ProactiveNudge(),
                  const SizedBox(height: AppSpacing.md),
                  // 4 — the single elevated focal card.
                  _buildNextDoseHero(ext),
                  const SizedBox(height: AppSpacing.xl),
                  // 5 — 4-up pulse row (Meds · Water · Focus · Reminders).
                  _buildPulseRow(ext),
                  const SizedBox(height: AppSpacing.xl),
                  // Today = one hero + one roll-up (pulse row) + the feed below.
                  // The old "Quick log" deck was removed — it restated the pulse
                  // row and the center "+ Log" action (three copies of the same
                  // four features). Quick logging still lives on "+ Log" and the
                  // feed cards.
                  SectionHeader(
                      title: 'Today',
                      accent: ext.brand,
                      actionLabel: 'Customize',
                      onAction: _openCustomizeToday),
                  const SizedBox(height: AppSpacing.xs),
                  for (final id in _todayCardOrder)
                    if (!hidden.contains(id)) ...[
                      _todayCard(id, ext),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  // 10 — Revenue banner: home overview only (never on the period,
                  // vitals, or sleep screens). Renders nothing until an ad loads.
                  const SmartDashboardBanner(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- pulse row -----------------------------------------------------------

  /// A flat 4-up KpiCell row that decomposes the day into Meds · Water · Focus ·
  /// Reminders rings, split by hairlines (StatTileRow's divider grammar). Wrapped
  /// in the shared live nesting so every ring tracks live in the IndexedStack.
  Widget _buildPulseRow(AppColorsExt ext) {
    return _liveBuilder(ext, (rev) {
      return FutureBuilder<_MedicineHomeData>(
        future: _medicineData(rev),
        builder: (context, snapshot) {
          final p = _pillarStats(snapshot.data?.summary);
          final cells = <Widget>[
            _StaggeredKpi(
              progress: p.medTotal == 0 ? 1 : p.medTaken / p.medTotal,
              value: p.medTotal == 0 ? '—' : '${p.medTaken}/${p.medTotal}',
              label: 'Meds',
              accent: ext.medicine,
              muted: p.medTotal == 0,
              delay: Duration.zero,
            ),
            _StaggeredKpi(
              progress: p.waterGoal > 0
                  ? (p.waterMl / p.waterGoal).clamp(0.0, 1.0)
                  : 0,
              value: '${p.waterPct}%',
              label: 'Water',
              accent: ext.water,
              muted: p.waterGoal <= 0,
              delay: const Duration(milliseconds: 60),
            ),
            _StaggeredKpi(
              progress: p.focusMin > 0 ? (p.focusMin / 60).clamp(0.0, 1.0) : 0,
              value: p.focusMin > 0 ? '${p.focusMin}m' : '0',
              label: 'Focus',
              accent: ext.focus,
              muted: p.focusMin == 0,
              delay: const Duration(milliseconds: 120),
            ),
            _StaggeredKpi(
              progress: p.remTotal == 0 ? 1 : p.remDone / p.remTotal,
              value: p.remTotal == 0 ? '—' : '${p.remDone}/${p.remTotal}',
              label: 'Reminders',
              accent: ext.reminders,
              muted: p.remTotal == 0,
              delay: const Duration(milliseconds: 180),
            ),
          ];
          final children = <Widget>[];
          for (var i = 0; i < cells.length; i++) {
            children.add(Expanded(child: cells[i]));
            if (i != cells.length - 1) {
              children.add(Container(width: 1, height: 40, color: ext.outline));
              children.add(const SizedBox(width: 4));
            }
          }
          return AppCard(
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: children),
          );
        },
      );
    });
  }

  // ---- daily briefing strip ------------------------------------------------

  /// The one AI touchpoint on Today — a flat, hairline-bounded whisper. The
  /// output is DETERMINISTIC (rule engine), so it wears a time-of-day glyph, not
  /// the AI sparkle. Loads through the same [_briefingData] + [AiAssistant]
  /// path (and SafetyGuard) as before; no AiSeal / auto_awesome anywhere.
  Widget _buildBriefingStrip(AppColorsExt ext) {
    final tt = Theme.of(context).textTheme;
    final hour = DateTime.now().hour;
    final IconData glyph = hour >= 21
        ? Symbols.bedtime_rounded
        : (hour < 8 || hour >= 18)
            ? Symbols.wb_twilight_rounded
            : Symbols.wb_sunny_rounded;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(height: 1, color: ext.outline),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: ext.brand.container, borderRadius: AppRadius.brSm),
                child: Icon(glyph, size: 16, color: ext.brand.onContainer),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FutureBuilder<String?>(
                  future: _briefingSentence(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const LoadingSkeleton.line(width: 220);
                    }
                    final t = snap.data?.trim();
                    final text = (t == null || t.isEmpty)
                        ? "Here's your day — one small step at a time."
                        : t;
                    return Text(text,
                        style:
                            tt.bodyMedium?.copyWith(color: ext.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis);
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              InkWell(
                borderRadius: AppRadius.brFull,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const InsightsHubScreen())),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Insights',
                          style: tt.labelMedium
                              ?.copyWith(color: ext.mark(ext.brand))),
                      Icon(Symbols.chevron_right_rounded,
                          size: 16, color: ext.textTertiary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(height: 1, color: ext.outline),
      ],
    );
  }

  /// Memoized daily-briefing loader: builds the numeric roll-up then runs the
  /// deterministic assistant with its EXACT args (routes through SafetyGuard).
  Future<String?> _briefingSentence() {
    return _briefingFuture ??= () async {
      final d = await _briefingData();
      return AiAssistant().dailyBriefing(
        medsTaken: d.medsTaken,
        medsTotal: d.medsTotal,
        waterPct: d.waterPct,
        focusMinutes: d.focusMinutes,
        remindersLeft: d.remindersLeft,
        hour: DateTime.now().hour,
        steps: d.steps,
        stepGoal: d.stepGoal,
        sleepMinutes: d.sleepMinutes,
      );
    }();
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

    int steps = 0, stepGoal = 0, sleepMinutes = 0;
    try {
      final st = StepService.getTodayData();
      steps = st.effectiveSteps;
      stepGoal = st.goalSteps;
    } catch (_) {}
    try {
      sleepMinutes = SleepService.getLastNight()?.asleepMinutes ?? 0;
    } catch (_) {}

    return _BriefingData(
      medsTaken: medsTaken,
      medsTotal: medsTotal,
      waterPct: waterPct,
      focusMinutes: focusMinutes,
      remindersLeft: remindersLeft,
      steps: steps,
      stepGoal: stepGoal,
      sleepMinutes: sleepMinutes,
    );
  }

  // ---- quick log deck ------------------------------------------------------

  /// A colorful 3×2 deck of capture tiles — each with its own accent badge and a
  /// live value (or an inviting "Log"). Row 1 groups the ambient trackers
  /// (Water · Steps · Sleep); row 2 the vitals/cycle (BP · Glucose · Period).
  /// Wrapped in the water/focus notifiers + vitals revision so values stay live.
  Widget _buildQuickLogDeck(AppColorsExt ext) {
    final waterListenable = WaterService.listenToDailyData();
    return ListenableBuilder(
      listenable: _focus,
      builder: (context, _) {
        Widget content() => ValueListenableBuilder<int>(
              valueListenable: VitalsStorageService.revision,
              builder: (context, vrev, __) => FutureBuilder<_DeckVitals>(
                future: _deckVitals(vrev),
                builder: (context, snap) => _deckBody(ext, snap.data),
              ),
            );
        if (waterListenable == null) return content();
        return ValueListenableBuilder<Map<String, DailyWaterData>>(
          valueListenable: waterListenable,
          builder: (context, ___, ____) => content(),
        );
      },
    );
  }

  Widget _deckBody(AppColorsExt ext, _DeckVitals? vitals) {
    // Ambient trackers — synchronous reads, each guarded (mirrors _briefingData).
    String? waterVal;
    bool waterDone = false;
    try {
      final goal = WaterService.getDailyGoal();
      final w = WaterService.getTodayData();
      waterVal = w.effectiveHydrationMl > 0
          ? _formatLitres(w.effectiveHydrationMl)
          : null;
      waterDone = goal > 0 && w.goalReached;
    } catch (_) {}

    String? stepsVal;
    bool stepsDone = false;
    try {
      final st = StepService.getTodayData();
      stepsVal = st.effectiveSteps > 0 ? _formatThousands(st.effectiveSteps) : null;
      stepsDone = st.goalReached;
    } catch (_) {}

    // Sleep tile reflects TODAY's night specifically, so it reads as a genuine
    // "log last night" prompt in the morning (empty → invites a log; logged →
    // shows the duration and a done check), not a stale older night.
    String? sleepVal;
    bool sleepDone = false;
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final s = SleepService.getForDate(today);
      if (s != null && s.asleepMinutes > 0) {
        sleepVal = _formatDuration(s.asleepMinutes);
        sleepDone = true;
      }
    } catch (_) {}

    String? periodVal;
    try {
      final day = PeriodService.getPrediction().dayOfCycle;
      if (day != null) periodVal = 'Day $day';
    } catch (_) {}

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _QuickLogTile(
                accent: ext.water,
                icon: Symbols.water_drop_rounded,
                label: 'Water',
                value: waterVal,
                done: waterDone,
                onTap: () => LogSomethingSheet.logWater(context),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _QuickLogTile(
                accent: ext.steps,
                icon: Symbols.footprint_rounded,
                label: 'Steps',
                value: stepsVal,
                done: stepsDone,
                onTap: () => LogSomethingSheet.logSteps(context),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _QuickLogTile(
                accent: ext.sleep,
                icon: Symbols.bedtime_rounded,
                label: 'Sleep',
                value: sleepVal,
                done: sleepDone,
                onTap: () => LogSomethingSheet.logSleep(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _QuickLogTile(
                accent: VitalsColors.bpAccent(ext.isDark),
                icon: Symbols.cardiology_rounded,
                label: 'BP',
                value: vitals?.bp,
                done: false,
                onTap: () => LogSomethingSheet.logBloodPressure(context),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _QuickLogTile(
                accent: VitalsColors.glucoseAccent(ext.isDark),
                icon: Symbols.glucose_rounded,
                label: 'Glucose',
                value: vitals?.glucose,
                done: false,
                onTap: () => LogSomethingSheet.logBloodSugar(context),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _QuickLogTile(
                accent: ext.period,
                icon: Symbols.menstrual_health_rounded,
                label: 'Period',
                value: periodVal,
                done: false,
                onTap: () => LogSomethingSheet.logPeriod(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<_DeckVitals> _deckVitals(int rev) {
    if (_vitalsFuture == null || _vitalsRev != rev) {
      _vitalsRev = rev;
      _vitalsFuture = _loadDeckVitals();
    }
    return _vitalsFuture!;
  }

  Future<_DeckVitals> _loadDeckVitals() async {
    String? bp;
    String? glucose;
    try {
      final list = await VitalsStorageService.getAllBp();
      if (list.isNotEmpty) {
        final r = list.first; // getAllBp is ordered newest-first
        bp = '${r.systolic}/${r.diastolic}';
      }
    } catch (_) {}
    try {
      final list = await VitalsStorageService.getAllGlucose();
      if (list.isNotEmpty) glucose = '${list.first.valueMgdl}';
    } catch (_) {}
    return _DeckVitals(bp: bp, glucose: glucose);
  }

  String _formatLitres(int ml) => '${(ml / 1000).toStringAsFixed(1)} L';

  String _formatThousands(int n) => NumberFormat.decimalPattern().format(n);

  String _formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h <= 0 ? '${m}m' : '${h}h ${m}m';
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
          trailing ?? Icon(Symbols.chevron_right_rounded, color: ext.textTertiary),
        ],
      ),
    );
  }

  /// A "fire" streak badge, shown on a feature card when the streak is > 0.
  Widget _streakChip(AccentSwatch accent, int streak) => AppChip(
        label: '$streak',
        icon: Symbols.local_fire_department_rounded,
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
          leadingIcon: Symbols.add_rounded,
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
              Icon(Symbols.add_rounded, size: 16, color: ext.mark(accent)),
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
                icon: Symbols.medication_rounded,
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
              icon: Symbols.medication_rounded,
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
        icon: Symbols.water_drop_rounded,
        title: 'Set a hydration goal',
        message: 'Tell us a bit about you to get a daily water target.',
        ctaLabel: 'Set goal',
        onCta: () => widget.onNavigate(1, healthTab: 1),
      );
    }

    final progress = data.effectiveHydrationMl / goal;
    final remaining = (goal - data.effectiveHydrationMl).clamp(0, goal);
    final streak = WaterService.getCurrentStreak();

    // Days the goal was hit over the last 7 (same source as the weekly strip) —
    // a WeekDotStrip so hydration doesn't twin the medicine adherence ring.
    final now = DateTime.now();
    int daysHit = 0;
    for (var i = 0; i < 7; i++) {
      final d = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: i));
      final dd = WaterService.getDataForDate(d);
      if (dd == null) continue;
      final g = dd.dailyGoalMl > 0 ? dd.dailyGoalMl : goal;
      if (g > 0 && dd.effectiveHydrationMl >= g) daysHit++;
    }

    return _featureCard(
      accent: ext.water,
      icon: Symbols.water_drop_rounded,
      title: 'Hydration',
      subtitle: (data.effectiveHydrationMl >= goal)
          ? 'Goal reached · ${data.effectiveHydrationMl} ml'
          : '${data.effectiveHydrationMl} / $goal ml · $remaining ml to go',
      onTap: () => widget.onNavigate(1, healthTab: 1),
      badge: streak > 0 ? _streakChip(ext.water, streak) : null,
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          WeekDotStrip(filled: daysHit, accent: ext.water),
          const SizedBox(height: 6),
          Text('${(progress * 100).round()}% today',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: ext.mark(ext.water),
                  fontWeight: FontWeight.w800,
                  fontFeatures: kTabular)),
        ],
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
          icon: Symbols.self_improvement_rounded,
          title: 'Focus',
          value: mins > 0 ? '$mins min' : 'Start',
          sub: streak > 0 ? '$streak-day streak' : 'Ready to focus?',
          onTap: () => widget.onNavigate(2),
          badge: streak > 0
              ? Icon(Symbols.local_fire_department_rounded,
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
        icon: Symbols.notifications_rounded,
        title: 'No reminders',
        ctaLabel: 'Add reminder',
        onCta: _addReminder,
      );
    }

    return _compactCard(
      accent: ext.reminders,
      icon: Symbols.notifications_rounded,
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
  final int steps;
  final int stepGoal;
  final int sleepMinutes;

  const _BriefingData({
    required this.medsTaken,
    required this.medsTotal,
    required this.waterPct,
    required this.focusMinutes,
    required this.remindersLeft,
    this.steps = 0,
    this.stepGoal = 0,
    this.sleepMinutes = 0,
  });
}

/// Bundled medicine data for the Home dashboard, loaded once per revision.
class _MedicineHomeData {
  final DailyMedicineSummary summary;
  final bool hasMedicines;
  final int streak;
  final ScheduledDose? nextDose;

  const _MedicineHomeData({
    required this.summary,
    required this.hasMedicines,
    required this.streak,
    this.nextDose,
  });
}

/// The four daily pillars, computed once from live sources and shared by the
/// hero fallback and the pulse row.
class _PillarStats {
  final int medTaken, medTotal;
  final int waterMl, waterGoal, waterPct;
  final bool waterDone;
  final int focusMin;
  final int remDone, remTotal;
  final int done; // 0..4

  const _PillarStats({
    required this.medTaken,
    required this.medTotal,
    required this.waterMl,
    required this.waterGoal,
    required this.waterPct,
    required this.waterDone,
    required this.focusMin,
    required this.remDone,
    required this.remTotal,
    required this.done,
  });
}

/// Latest BP / glucose readings for the quick-log deck (null → invite "Log").
class _DeckVitals {
  final String? bp;
  final String? glucose;
  const _DeckVitals({this.bp, this.glucose});
}

/// A slow-pulsing 8px dot (0.5↔1.0 over ~1.2s). Reduce-motion → a static dot.
class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    Widget dot(double opacity) => Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
              color: widget.color.withOpacity(opacity),
              shape: BoxShape.circle),
        );
    if (reduce) {
      if (_c.isAnimating) _c.stop();
      return dot(1.0);
    }
    if (!_c.isAnimating) _c.repeat(reverse: true);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => dot(0.5 + 0.5 * _c.value),
    );
  }
}

/// A [KpiCell] whose ring sweeps in after [delay] on first paint (staggering the
/// pulse row). Reduce-motion → reveals immediately. Live updates pass straight
/// through once revealed, so the ring stays in sync with the notifiers.
class _StaggeredKpi extends StatefulWidget {
  final double progress;
  final String value;
  final String label;
  final AccentSwatch accent;
  final bool muted;
  final Duration delay;

  const _StaggeredKpi({
    required this.progress,
    required this.value,
    required this.label,
    required this.accent,
    this.muted = false,
    this.delay = Duration.zero,
  });

  @override
  State<_StaggeredKpi> createState() => _StaggeredKpiState();
}

class _StaggeredKpiState extends State<_StaggeredKpi> {
  double _p = 0;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.of(context).disableAnimations) {
        setState(() {
          _p = widget.progress;
          _revealed = true;
        });
      } else {
        Future.delayed(widget.delay, () {
          if (!mounted) return;
          setState(() {
            _p = widget.progress;
            _revealed = true;
          });
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant _StaggeredKpi old) {
    super.didUpdateWidget(old);
    if (_revealed && widget.progress != _p) {
      setState(() => _p = widget.progress);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KpiCell(
      progress: _p,
      value: widget.value,
      label: widget.label,
      accent: widget.accent,
      muted: widget.muted,
    );
  }
}

/// One colorful capture tile in the quick-log deck: an accent badge + glyph over
/// a live value (or an inviting "Log"). Press → scale 0.97 + an accent flash and
/// the resting shadow drops. Reduce-motion → the scale is instant.
class _QuickLogTile extends StatefulWidget {
  final AccentSwatch accent;
  final IconData icon;
  final String label;
  final String? value; // null / empty → renders "Log" in the accent mark
  final bool done; // today's target met → completion dot
  final VoidCallback onTap;

  const _QuickLogTile({
    required this.accent,
    required this.icon,
    required this.label,
    required this.value,
    required this.done,
    required this.onTap,
  });

  @override
  State<_QuickLogTile> createState() => _QuickLogTileState();
}

class _QuickLogTileState extends State<_QuickLogTile> {
  bool _pressed = false;

  void _set(bool v) => setState(() => _pressed = v);

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final reduce = MediaQuery.of(context).disableAnimations;
    final filled = widget.value != null && widget.value!.trim().isNotEmpty;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: reduce ? Duration.zero : AppMotion.fast,
        curve: AppMotion.standard,
        child: AspectRatio(
          aspectRatio: 0.95,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: ext.surface,
              borderRadius: AppRadius.brLg,
              border: Border.all(color: ext.outline, width: 1),
              boxShadow: _pressed ? null : AppShadows.resting(context),
            ),
            child: Stack(
              children: [
                if (_pressed)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: widget.accent.container.withOpacity(0.6),
                        borderRadius: AppRadius.brLg,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: widget.accent.container,
                                borderRadius: AppRadius.brSm),
                            child: Icon(widget.icon,
                                size: 20, color: widget.accent.onContainer),
                          ),
                          const Spacer(),
                          if (widget.done)
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                  color: ext.mark(widget.accent),
                                  shape: BoxShape.circle),
                            ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              filled ? widget.value!.trim() : 'Log',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontFeatures: kTabular,
                                color: filled
                                    ? ext.textPrimary
                                    : ext.mark(widget.accent),
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(widget.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.labelSmall
                                  ?.copyWith(color: ext.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
