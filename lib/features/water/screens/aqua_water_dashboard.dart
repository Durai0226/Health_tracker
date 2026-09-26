import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/health/insight_engine.dart';
import '../../../core/health/hydration_pacer.dart';
import '../../../core/widgets/app/insight_kit.dart';
import '../../../core/widgets/app/tip_card.dart';
import 'package:tablet_remainder/core/widgets/app/app_toast.dart';
import 'package:tablet_remainder/core/health/medication_hydration.dart';
import '../services/medication_hydration_service.dart';
import '../theme/aqua_theme.dart';
import '../widgets/water_hero_gauge.dart';
import '../widgets/aqua_shimmer.dart';
import '../widgets/aqua_glass_card.dart';
import '../widgets/aqua_quick_add_grid.dart';
import '../widgets/aqua_timeline_list.dart';
import '../widgets/aqua_weekly_progress.dart';
import '../widgets/aqua_beverage_sheet.dart';
import '../models/enhanced_water_log.dart';
import '../models/water_container.dart';
import '../services/water_service.dart';
import 'custom_cup_creator_screen.dart';
import 'water_statistics_screen.dart';
import 'water_calendar_screen.dart';
import 'water_reminder_settings_screen.dart';
import 'water_history_edit_screen.dart';
import 'water_achievements_screen.dart';
import 'hydration_profile_screen.dart';
import 'caffeine_insights_screen.dart';
import '../../../core/health/coach_text.dart';
import '../../../core/utils/calendar_day.dart';

/// Modern Aqua Water Dashboard
/// Features: Animated droplet, dynamic beverage gradients, glassmorphism
class AquaWaterDashboard extends StatefulWidget {
  /// When embedded in the Health hub, drops its own SliverAppBar (the hub owns
  /// the single header) and uses a transparent background.
  final bool embedded;
  const AquaWaterDashboard({super.key, this.embedded = false});

  @override
  State<AquaWaterDashboard> createState() => _AquaWaterDashboardState();
}

class _AquaWaterDashboardState extends State<AquaWaterDashboard>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _headerController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _headerSlideAnimation;

  // Data
  DailyWaterData? _todayData;
  int _dailyGoal = 2500;
  bool _isLoading = true;
  bool _savingGoal = false; // reentrancy guard for the quick-goal sheet
  String _selectedBeverageId = 'water';
  List<DayProgress> _weekData = [];

  // Scroll controller
  final _scrollController = ScrollController();
  /// Header fade, driven by scroll offset.
  ///
  /// This used to be a plain field mutated inside `setState`, which rebuilt the
  /// ENTIRE screen (~1379 widgets — the largest tree in the water feature) on
  /// every scroll notification. The value is read in exactly one place, and it
  /// stops changing once the offset passes 150, so most of those rebuilds
  /// produced an identical frame. A ValueNotifier + ValueListenableBuilder
  /// scopes the rebuild to the header alone.
  final ValueNotifier<double> _headerOpacity = ValueNotifier<double>(1.0);

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadData(showLoading: true);
    _scrollController.addListener(_onScroll);
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: AquaTheme.curveDefault,
    );

    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _headerSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _headerController,
      curve: AquaTheme.curveDefault,
    ));

    _fadeController.forward();
    _headerController.forward();
  }

  void _onScroll() {
    final next = (1 - (_scrollController.offset / 150)).clamp(0.0, 1.0);
    // Assign only on a real change: past 150px of scroll this clamps to 0.0 and
    // stays there, so the rest of the gesture costs nothing. (ValueNotifier
    // already suppresses identical assignments, but the explicit guard makes
    // the intent obvious.)
    if (next != _headerOpacity.value) _headerOpacity.value = next;
  }

  /// [showLoading] gates the full-screen shimmer skeleton. Only the first load
  /// (from initState) shows it; post-add/undo/return refreshes update data in
  /// place so the skeleton doesn't flash over the content on every tap.
  /// Fluid guidance driven by what the user is taking. Empty for almost
  /// everyone, which is why it is only rendered when it has something to say.
  MedicationHydrationAdvice _medAdvice = MedicationHydrationAdvice.empty;

  Future<void> _loadData({bool showLoading = false}) async {
    if (showLoading) setState(() => _isLoading = true);

    try {
      await WaterService.init();
      final todayData = WaterService.getTodayData();
      // Today's STORED goal — the number every gauge on this screen already
      // renders from `todayData.dailyGoalMl`, and the one `goalReached` is
      // judged against. `_dailyGoal` feeds the quick-goal sheet and the
      // pre-load placeholder, so reading the profile here offered to "keep" a
      // figure that was nowhere on screen once the weather had moved the day.
      final goal = WaterService.goalForDay(todayData);

      // Build week data
      final weekData = <DayProgress>[];
      final now = DateTime.now();
      final weekStart = startOfWeek(now);

      for (int i = 0; i < 7; i++) {
        final date = dayOffset(weekStart, i);
        if (date.isAfter(now)) break;

        final dayData = WaterService.getDataForDate(date);
        weekData.add(DayProgress(
          date: date,
          intakeMl: dayData?.effectiveHydrationMl ?? 0,
          // Each day carries the goal it was actually measured against — see
          // WaterService.goalForDay. Passing today's goal for all seven made
          // "Goals Hit n/7" move whenever the user edited their goal.
          goalMl: WaterService.goalForDay(dayData),
        ));
      }

      if (mounted) {
        setState(() {
          _todayData = todayData;
          _dailyGoal = goal;
          _weekData = weekData;
          _isLoading = false;
        });
      }

      // Reads the medicine list, so it must not block the water numbers — and
      // it was awaited above them, which is how "+" ended up waiting on a
      // medicine read before the Undo toast appeared. The advice card is empty
      // for almost everyone and never part of the gauge, so it lands in a
      // second frame of its own.
      final medAdvice = await MedicationHydrationService.current();
      if (mounted) setState(() => _medAdvice = medAdvice);
    } catch (e) {
      debugPrint('Error loading water data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addWater(
    int amountMl,
    String beverageId, {
    WaterContainer? container,
  }) async {
    try {
      // Resolve the real beverage from the catalog — no silent fallback to
      // Water. An unknown id must not be credited as 100% hydration water.
      final beverage = WaterService.getBeverage(beverageId);
      if (beverage == null) {
        debugPrint('⚠️ Unknown beverage id "$beverageId" — skipping log');
        if (mounted) {
          context.toastWarning('Unknown beverage — not logged');
        }
        return;
      }

      // addWaterLog computes effective hydration / caffeine / alcohol from the
      // BeverageType, so beer/energy drinks are recorded correctly. It returns
      // the updated day whose last log is the one we just added — capture its
      // id so the toast can undo it.
      final updated = await WaterService.addWaterLog(
        amountMl: amountMl,
        beverage: beverage,
        container: container,
      );
      final addedLogId =
          updated.logs.isNotEmpty ? updated.logs.last.id : null;

      await _loadData();

      if (mounted) {
        HapticFeedback.mediumImpact();
        showAppToast(
          context,
          // The old SnackBar led with the beverage glyph (a Row of
          // `beverage.emoji` and the text), so coffee and beer confirmed as
          // themselves. The kit's content is a String, so the glyph rides in
          // the message — exactly how the achievement toast below carries
          // `first.emoji`.
          '${beverage.emoji} +${amountMl}ml ${beverage.name}',
          variant: AppToastVariant.success,
          duration: const Duration(seconds: 3),
          action: addedLogId == null
              ? null
              : AppToastAction(
                  label: 'Undo',
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    await WaterService.removeWaterLog(addedLogId);
                    await _loadData();
                  },
                ),
        );

        // Celebrate anything that just unlocked. `_lastNewlyUnlocked` has been
        // filled on every single log since the achievements system shipped and
        // `consumeNewlyUnlockedAchievements()` had zero callers — the unlock
        // moment, which is the entire emotional payoff of a 21-badge system,
        // was computed and discarded. The user could only ever find out by
        // navigating to the Awards screen and noticing a badge had changed
        // colour.
        final unlocked = WaterService.consumeNewlyUnlockedAchievements();
        if (unlocked.isNotEmpty && mounted) {
          // One toast even if several land together, so a milestone day does
          // not become a stack of interruptions.
          final first = unlocked.first;
          final more = unlocked.length - 1;
          context.toastSuccess(
            more > 0
                ? '${first.emoji} ${first.title} unlocked, +$more more'
                : '${first.emoji} ${first.title} unlocked',
            action: AppToastAction(
              label: 'View',
              onPressed: _navigateToAchievements,
            ),
          );
        }

        // Over-hydration guardrail. This app — like every other in the
        // category — was built entirely around "more is better", and its
        // achievements actively reward volume. Maximal renal free-water
        // clearance is ~800-1000 ml/h, and drinking past it is the mechanism
        // behind exercise-associated hyponatremia. IOM's stated reason for
        // setting no upper limit on water is that healthy kidneys cope with
        // "more than 0.7 L per hour" — which is an upper bound, quietly put.
        //
        // Deliberately shown AFTER the confirmation and as information, not an
        // interruption: the drink is already logged, nothing is blocked, and
        // this is not a diagnosis.
        if (WaterService.isDrinkingTooFast()) {
          final hourMl = WaterService.intakeInLastHourMl();
          context.toastWarning(
            'That is ${hourMl}ml in the last hour. Your kidneys clear about '
            '1 litre an hour — it is worth easing off for a while.',
          );
        }
      }
    } catch (e) {
      debugPrint('Error adding water: $e');
      if (mounted) {
        context.toastError('Failed to add water: $e');
      }
    }
  }

  /// One-tap logging of a saved cup/container with the selected beverage.
  void _addWaterFromContainer(WaterContainer container) {
    _addWater(container.capacityMl, _selectedBeverageId, container: container);
  }

  /// Open the custom cup creator, then refresh so new cups appear as chips.
  void _openCupCreator() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CustomCupCreatorScreen()),
    ).then((_) => _loadData());
  }

  void _showBeverageSelector() async {
    final result = await AquaBeverageSheet.show(context, _selectedBeverageId);
    if (result != null && mounted) {
      setState(() => _selectedBeverageId = result);
    }
  }

  void _showCustomAmountDialog() {
    showDialog(
      context: context,
      builder: (context) => AquaCustomAmountDialog(
        beverageId: _selectedBeverageId,
        onConfirm: (amount) => _addWater(amount, _selectedBeverageId),
      ),
    );
  }

  void _showGoalDialog() {
    int newGoal = _dailyGoal;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            left: AquaTheme.spacingL,
            right: AquaTheme.spacingL,
            top: AquaTheme.spacingL,
            bottom: MediaQuery.of(context).viewInsets.bottom + AquaTheme.spacingL,
          ),
          decoration: BoxDecoration(
            color: AquaTheme.getCardBg(context),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AquaTheme.radiusLarge),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColorsExt.of(context).outline,
                  borderRadius: AppRadius.brSm,
                ),
              ),
              const SizedBox(height: AquaTheme.spacingL),
              Text(
                'Daily Goal',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AquaTheme.getTextPrimary(context),
                    ),
              ),
              const SizedBox(height: AquaTheme.spacingXL),
              // AppStepper: the shared -/+ control. This was the third copy of
              // it in the water feature alone.
              AppStepper(
                value: '${newGoal}ml',
                subLabel: '${(newGoal / 250).round()} glasses',
                valueStyle: Theme.of(context).textTheme.displayLarge,
                accent: AppColorsExt.of(context).water,
                decrementTooltip: 'Decrease goal by 250 ml',
                incrementTooltip: 'Increase goal by 250 ml',
                onDecrement: newGoal <= 500
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        setModalState(
                            () => newGoal = (newGoal - 250).clamp(500, 5000));
                      },
                onIncrement: newGoal >= 5000
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        setModalState(
                            () => newGoal = (newGoal + 250).clamp(500, 5000));
                      },
              ),
              const SizedBox(height: AquaTheme.spacingXL),
              GestureDetector(
                onTap: () async {
                  // Reentrancy guard: a rapid double-tap otherwise saved twice
                  // AND popped twice — the second pop closed the dashboard route.
                  if (_savingGoal) return;
                  _savingGoal = true;
                  HapticFeedback.mediumImpact();
                  final profile = WaterService.getProfile();
                  final updatedProfile = profile.copyWith(
                    customGoalMl: newGoal,
                    useCustomGoal: true,
                  );
                  // Single canonical write: saveProfile already recomputes and
                  // persists today's goal from effectiveGoalMl, so the separate
                  // saveDailyData was redundant (and a second source of truth).
                  try {
                    await WaterService.saveProfile(updatedProfile);
                  } finally {
                    _savingGoal = false;
                  }

                  if (context.mounted && Navigator.canPop(context)) {
                    Navigator.pop(context);
                    _loadData();
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColorsExt.of(context).fillBg(
                        AppColorsExt.of(context).water),
                    borderRadius: AppRadius.brMd,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Symbols.check_rounded,
                          color: AppColorsExt.of(context)
                              .fillFg(AppColorsExt.of(context).water)),
                      const SizedBox(width: 8),
                      Text(
                        'Save Goal',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColorsExt.of(context)
                                  .fillFg(AppColorsExt.of(context).water),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _headerController.dispose();
    _scrollController.dispose();
    _headerOpacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      final loading = AquaDashboardSkeleton(embedded: widget.embedded);
      if (widget.embedded) return loading;
      return Scaffold(
        backgroundColor: AquaTheme.getBackground(context),
        body: loading,
      );
    }

    final listenable = WaterService.listenToDailyData();
    if (listenable == null) {
      return _buildContent(context);
    }

    return ValueListenableBuilder(
      valueListenable: listenable,
      builder: (context, _, __) {
        final todayData = WaterService.getTodayData();
        return _buildContentWithData(context, todayData);
      },
    );
  }

  Widget _buildContent(BuildContext context) {
    final todayData = _todayData ?? DailyWaterData(
      id: '',
      date: DateTime.now(),
      dailyGoalMl: _dailyGoal,
    );
    return _buildContentWithData(context, todayData);
  }

  Widget _buildContentWithData(BuildContext context, DailyWaterData todayData) {
    final isDark = AquaTheme.isDark(context);
    // The screen chrome (background, app bar, gauge, primary CTAs) always reads
    // as the water app — the selected beverage only tints its own chip in the
    // quick-add selector, so switching to coffee/juice no longer turns the whole
    // dashboard brown/orange.
    final water = AquaTheme.getBeverage('water');
    final progress = todayData.progress.clamp(0.0, 1.0);
    final currentStreak = WaterService.getCurrentStreak();

    final body = Stack(
        children: [
          // Background gradient
          if (!widget.embedded) _buildBackground(water, isDark),

          // Main content
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // App bar
              if (!widget.embedded) _buildSliverAppBar(water, currentStreak),
              if (widget.embedded)
                const SliverToBoxAdapter(child: SizedBox(height: 8)),

              // Content
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AquaTheme.spacingM),
                    child: Column(
                      children: [
                        const SizedBox(height: AquaTheme.spacingM),

                        // Hydration gauge (always water accent, never beverage-tinted)
                        WaterHeroGauge(
                          progress: progress,
                          currentMl: todayData.effectiveHydrationMl,
                          goalMl: todayData.dailyGoalMl,
                          onTap: _showBeverageSelector,
                        ),

                        const SizedBox(height: AquaTheme.spacingXL),
                        
                        // Quick add section
                        AquaSectionHeader(
                          title: 'Quick Add',
                          icon: Symbols.add_circle_rounded,
                          beverageId: _selectedBeverageId,
                        ),
                        const SizedBox(height: AquaTheme.spacingS),
                        AquaQuickAddGrid(
                          selectedBeverageId: _selectedBeverageId,
                          onQuickAdd: _addWater,
                          onCustomAmount: _showCustomAmountDialog,
                          onBeverageSelect: _showBeverageSelector,
                          onContainerAdd: _addWaterFromContainer,
                          onCreateCup: _openCupCreator,
                        ),
                        
                        const SizedBox(height: AquaTheme.spacingXL),

                        // AI hydration insight — self-loading Calm Clarity card.
                        // Computed synchronously from today's numbers, so it
                        // renders instantly with no spinner and cannot fail.
                        TipCard(
                          title: 'Hydration tips',
                          icon: Symbols.water_drop_rounded,
                          accent: AppColorsExt.of(context).water,
                          text: const CoachText().hydrationTip(
                            // Under a fluid restriction the number that matters
                            // is the raw volume swallowed, not our
                            // hydration-adjusted figure — a clinician's limit is
                            // about litres of liquid.
                            intakeMl: WaterService.isFluidRestricted
                                ? todayData.totalIntakeMl
                                : todayData.effectiveHydrationMl,
                            goalMl: todayData.dailyGoalMl,
                            streakDays: WaterService.getCurrentStreak(),
                            hour: clock.now().hour,
                            isRestricted: WaterService.isFluidRestricted,
                            wakeMinutes:
                                WaterService.wakingWindow().wakeMinutes,
                            sleepMinutes:
                                WaterService.wakingWindow().sleepMinutes,
                          ),
                        ),
                        _buildWaterInsight(
                            todayData.effectiveHydrationMl, todayData.dailyGoalMl),
                        _buildMedicationAdvice(),

                        const SizedBox(height: AquaTheme.spacingXL),

                        // Today's log
                        AquaSectionHeader(
                          title: "Today's Log",
                          icon: Symbols.history_rounded,
                          actionText: 'Edit',
                          onAction: () => _navigateToHistory(),
                          beverageId: _selectedBeverageId,
                        ),
                        const SizedBox(height: AquaTheme.spacingS),
                        AquaTimelineList(
                          logs: todayData.logs,
                          maxItems: 5,
                          onViewAll: () => _navigateToHistory(),
                        ),
                        
                        const SizedBox(height: AquaTheme.spacingXL),
                        
                        // Weekly progress
                        AquaWeeklyProgress(
                          weekData: _weekData,
                          goalMl: todayData.dailyGoalMl,
                          beverageId: _selectedBeverageId,
                          onTapHistory: () => _navigateToCalendar(),
                        ),
                        
                        const SizedBox(height: AquaTheme.spacingXL),
                        
                        // Quick access menu
                        _buildQuickAccessMenu(water, isDark),
                        
                        SizedBox(height: AppInsets.underNav(context)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );

    if (widget.embedded) return body;
    return Scaffold(
      backgroundColor: AquaTheme.getBackground(context),
      body: body,
    );
  }

  Widget _buildBackground(BeverageThemeData beverage, bool isDark) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              beverage.primary.withOpacity(isDark ? 0.15 : 0.1),
              AquaTheme.getBackground(context),
            ],
            stops: const [0.0, 0.35],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(BeverageThemeData beverage, int streak) {
    final tt = Theme.of(context).textTheme;
    final scaler = MediaQuery.textScalerOf(context);
    // The expanded header is a fixed-height box holding a display-size title
    // and a greeting line, so its height has to track Dynamic Type or the
    // column is clipped (verified: 64px overflow at accessibility sizes).
    // Measured off the real styles rather than a magic number: 56pt of
    // clearance for the toolbar row, one title line, and up to two greeting
    // lines. Never smaller than the original 170.
    final titleLine = scaler.scale(tt.displayMedium?.fontSize ?? 28) * 1.25;
    final greetingLine = scaler.scale(tt.bodyMedium?.fontSize ?? 14) * 1.45;
    final expandedHeight =
        (56 + titleLine + 4 + greetingLine * 2 + 8).clamp(170.0, 340.0);

    return SliverAppBar(
      // Tall enough for the toolbar row plus the title and greeting beneath
      // it. At 110 the title+greeting overflowed by 4px once they were moved
      // clear of the back button, and the greeting was clipped.
      expandedHeight: expandedHeight,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Semantics(
        button: true,
        label: 'Back',
        excludeSemantics: true,
        child: Tooltip(
          message: 'Back',
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AquaTheme.getCardBg(context),
                shape: BoxShape.circle,
                boxShadow: AppShadows.card(context),
              ),
              child: Icon(
                Symbols.arrow_back_rounded,
                color: AquaTheme.getTextPrimary(context),
                size: 18,
              ),
            ),
          ),
        ),
      ),
      actions: [
        _buildHeaderAction(
          Symbols.flag_rounded,
          () => _showGoalDialog(),
          beverage,
          label: 'Set daily goal',
        ),
        _buildHeaderAction(
          Symbols.bar_chart_rounded,
          () => _navigateToStats(),
          beverage,
          label: 'Statistics',
        ),
        _buildHeaderAction(
          Symbols.settings_rounded,
          () => _navigateToProfile(),
          beverage,
          label: 'Settings',
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: SlideTransition(
          position: _headerSlideAnimation,
          child: ValueListenableBuilder<double>(
            valueListenable: _headerOpacity,
            builder: (context, opacity, child) =>
                Opacity(opacity: opacity, child: child),
            child: SafeArea(
              child: Padding(
                // The toolbar row (leading back button + actions) paints on
                // top of flexibleSpace, so the title has to start below it —
                // at 16 the back button covered the "H" of "Hydration".
                padding: const EdgeInsets.fromLTRB(20, 56, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // "Hydration" is a single word, so it cannot reflow —
                        // at large text sizes it simply ran past the streak
                        // badge and off the row. Expanded (not Spacer) keeps
                        // the badge pinned right exactly as before, while
                        // scaleDown shrinks the title only when it no longer
                        // fits; it never enlarges, so the default header is
                        // pixel-identical.
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: ShaderMask(
                              shaderCallback: (bounds) => beverage.gradient.createShader(bounds),
                              child: Text(
                                'Hydration',
                                maxLines: 1,
                                softWrap: false,
                                // The ShaderMask replaces this colour outright;
                                // it only has to be fully opaque. `fillFg` says
                                // that without a raw literal.
                                style: tt.displayMedium?.copyWith(
                                    color: AppColorsExt.of(context)
                                        .fillFg(AppColorsExt.of(context).water)),
                              ),
                            ),
                          ),
                        ),
                        if (streak > 0) ...[
                          const SizedBox(width: AquaTheme.spacingS),
                          AquaStreakBadge(
                            streak: streak,
                            gracesRemaining:
                                WaterService.getStreakResult().gracesRemaining,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getGreeting(),
                      // Two lines is what `expandedHeight` above budgets for.
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodyMedium?.copyWith(
                            color: AquaTheme.getTextSecondary(context),
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderAction(
      IconData icon, VoidCallback onTap, BeverageThemeData beverage,
      {required String label}) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            // 44pt floor: a 20pt icon with 10pt padding is 40x40. These are the
            // dashboard's header actions — icon-only, in the top corner, and
            // the hardest kind of target to hit one-handed.
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            alignment: Alignment.center,
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColorsExt.of(context).surface,
              borderRadius: AppRadius.brMd,
              boxShadow: AppShadows.card(context),
            ),
            child: Icon(
              icon,
              size: 20,
              color: AppColorsExt.of(context).mark(AppColorsExt.of(context).water),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAccessMenu(BeverageThemeData water, bool isDark) {
    // A single calm water accent (no rainbow). Entries already reachable from
    // the app bar (Stats via bar-chart, Profile via settings) are dropped when
    // the app bar is present; in embedded mode the hub owns the header, so we
    // keep them here to preserve access. "Cups" routes to the cup creator; a
    // "Drinks" tile is omitted since the beverage selector already surfaces it.
    final entries = <_FeatureEntry>[
      if (widget.embedded)
        _FeatureEntry(Symbols.analytics_rounded, 'Stats', _navigateToStats),
      _FeatureEntry(
          Symbols.calendar_month_rounded, 'Calendar', _navigateToCalendar),
      _FeatureEntry(
          Symbols.local_cafe_rounded, 'Cups', _openCupCreator),
      _FeatureEntry(
          Symbols.emoji_events_rounded, 'Awards', _navigateToAchievements),
      _FeatureEntry(Symbols.coffee_rounded, 'Caffeine', _navigateToCaffeine),
      _FeatureEntry(
          Symbols.notifications_rounded, 'Reminders', _navigateToReminders),
      if (widget.embedded)
        _FeatureEntry(Symbols.person_rounded, 'Profile', _navigateToProfile),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AquaSectionHeader(
          title: 'More Features',
          icon: Symbols.apps_rounded,
          beverageId: 'water',
        ),
        const SizedBox(height: AquaTheme.spacingS),
        // A hardcoded childAspectRatio clipped these tiles: at 320pt the cells
        // are 61pt wide, so "Reminders"/"Calendar" wrap to two lines and the
        // column needed 82pt inside a 72pt tile (10px bottom overflow, worse at
        // large Dynamic Type). Measure the real label height at the real tile
        // width instead and give the grid an explicit mainAxisExtent, floored at
        // the original 0.85 ratio so nothing shrinks anywhere it already fit.
        LayoutBuilder(
          builder: (context, constraints) {
            const crossAxisCount = 4;
            const spacing = 12.0;
            final tileWidth =
                (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
                    crossAxisCount;
            // `context` here (not the State's) is the one below the Scaffold's
            // Material, so the DefaultTextStyle it sees is the one the tile
            // labels actually inherit.
            final extent = _featureTileExtent(context, entries, tileWidth);

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: entries.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: spacing,
                crossAxisSpacing: spacing,
                mainAxisExtent: extent,
              ),
              itemBuilder: (context, i) {
                final e = entries[i];
                return _buildFeatureCard(
                  icon: e.icon,
                  label: e.label,
                  water: water,
                  onTap: e.onTap,
                );
              },
            );
          },
        ),
      ],
    );
  }

  /// The exact style `_buildFeatureCard` renders its label with — shared so the
  /// measurement in [_featureTileExtent] can never drift from what is painted.
  TextStyle get _featureLabelStyle =>
      Theme.of(context).textTheme.labelSmall!.copyWith(fontWeight: FontWeight.w600);

  /// Height a "More Features" tile actually needs: the icon chip, the gap, and
  /// however many lines the longest label takes at [tileWidth]. Measured rather
  /// than assumed, so both a narrow phone and large Dynamic Type grow the tile
  /// instead of clipping it. Floored at the original 0.85 aspect ratio so tiles
  /// are never smaller than they were.
  double _featureTileExtent(
      BuildContext context, List<_FeatureEntry> entries, double tileWidth) {
    const chipPadding = 10.0 * 2; // Container(padding: EdgeInsets.all(10))
    const border = 2.0; // 1pt card border, top + bottom
    const gap = 8.0; // SizedBox between chip and label
    final scaler = MediaQuery.textScalerOf(context);
    final glyph = (IconTheme.of(context).applyTextScaling ?? false)
        ? scaler.scale(22)
        : 22.0;

    // Measure what Text actually paints: an inheriting style is merged onto the
    // ambient DefaultTextStyle (font family, line height), and bold-text
    // accessibility thickens it. Measuring the bare style instead reports one
    // line where two get rendered.
    var effective = DefaultTextStyle.of(context).style.merge(_featureLabelStyle);
    if (MediaQuery.boldTextOf(context)) {
      effective = effective.merge(const TextStyle(fontWeight: FontWeight.bold));
    }

    var labelHeight = 0.0;
    for (final e in entries) {
      final painter = TextPainter(
        text: TextSpan(text: e.label, style: effective),
        textDirection: Directionality.of(context),
        textAlign: TextAlign.center,
        textScaler: scaler,
      )..layout(maxWidth: math.max(0.0, tileWidth - border));
      labelHeight = math.max(labelHeight, painter.height);
      painter.dispose();
    }

    // +1 of slack so a sub-pixel rounding difference can't re-introduce a
    // hairline overflow.
    final needed = border + chipPadding + glyph + gap + labelHeight + 1;
    return math.max(tileWidth / 0.85, needed);
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String label,
    required BeverageThemeData water,
    required VoidCallback onTap,
  }) {
    final ext = AppColorsExt.of(context);

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          color: ext.surface,
          borderRadius: AppRadius.brLg,
          border: Border.all(color: ext.outline, width: 1),
          boxShadow: AppShadows.card(context),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ext.water.container,
                borderRadius: AppRadius.brMd,
              ),
              child: Icon(icon, color: ext.water.onContainer, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: _featureLabelStyle.copyWith(color: ext.textPrimary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning! Stay hydrated today.';
    } else if (hour < 17) {
      return 'Good afternoon! Keep up the hydration.';
    } else {
      return 'Good evening! How\'s your hydration?';
    }
  }

  void _navigateToStats() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WaterStatisticsScreen()),
    );
  }

  void _navigateToCalendar() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WaterCalendarScreen()),
    );
  }

  void _navigateToAchievements() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WaterAchievementsScreen()),
    );
  }

  void _navigateToCaffeine() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CaffeineInsightsScreen()),
    );
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HydrationProfileScreen()),
    );
  }

  void _navigateToReminders() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WaterReminderSettingsScreen()),
    );
  }

  void _navigateToHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => WaterHistoryEditScreen(date: DateTime.now())),
    ).then((_) => _loadData());
  }

  /// Deterministic hydration insight (streak / behind-pace), surfaced as an
  /// InsightCard beneath the tips.
  /// Fluid guidance tied to the user's medicines.
  ///
  /// Nothing else in this category can show this: a pure hydration app does not
  /// know what you take, and the "medicine + water reminder" apps on the stores
  /// keep the two features entirely separate. Rendered only when a rule
  /// actually matched, so it is invisible for most people rather than another
  /// empty card.
  ///
  /// Framed as "worth knowing", with the drug named and the source given —
  /// never as an instruction. The decision belongs to the user and whoever
  /// prescribed the drug.
  Widget _buildMedicationAdvice() {
    if (_medAdvice.isEmpty) return const SizedBox.shrink();
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;

    final lines = <MedicationHydrationRule>[
      ..._medAdvice.increases,
      ..._medAdvice.cautions,
    ];

    return Padding(
      padding: const EdgeInsets.only(top: AquaTheme.spacingM),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ext.surface,
          borderRadius: AppRadius.brCard,
          border: Border.all(color: ext.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Symbols.medication_rounded,
                    size: 18, color: ext.mark(ext.medicine)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Because of your medicines',
                    style: tt.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: ext.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final rule in lines) ...[
              Text(rule.advice,
                  style: tt.bodyMedium?.copyWith(color: ext.textPrimary)),
              const SizedBox(height: 2),
              Text(rule.source,
                  style: tt.labelSmall?.copyWith(color: ext.textSecondary)),
              const SizedBox(height: 10),
            ],
            Text(
              'General guidance, not advice for you personally — your '
              'clinician’s instructions come first.',
              style: tt.labelSmall?.copyWith(color: ext.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaterInsight(int intakeMl, int goalMl) {
    final now = clock.now();
    final w = WaterService.wakingWindow();
    final pace = HydrationPacer.compute(
      intakeMl: intakeMl,
      goalMl: goalMl,
      nowMinutes: now.hour * 60 + now.minute,
      wakeMinutes: w.wakeMinutes,
      sleepMinutes: w.sleepMinutes,
    );
    final insight = InsightEngine.water(
      intakeMl: intakeMl,
      goalMl: goalMl,
      streakDays: WaterService.getCurrentStreak(),
      behind: pace.behind,
      deficitMl: pace.deficitMl,
    );
    if (insight == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AquaTheme.spacingL),
      child: InsightCard(insight: insight),
    );
  }
}

/// A single calm "More Features" tile entry (icon + label + destination).
class _FeatureEntry {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FeatureEntry(this.icon, this.label, this.onTap);
}
