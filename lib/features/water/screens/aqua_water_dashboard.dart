import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import '../../../core/design/app_design.dart';
import '../../../core/ai/ai_assistant.dart';
import '../../../core/ai/insight_engine.dart';
import '../../../core/ai/hydration_pacer.dart';
import '../../../core/widgets/app/ai_insight_kit.dart';
import '../../../core/widgets/app/ai_widgets.dart';
import 'package:tablet_remainder/core/widgets/app/app_toast.dart';
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
import 'hydration_challenges_screen.dart';
import 'caffeine_insights_screen.dart';

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
  String _selectedBeverageId = 'water';
  List<DayProgress> _weekData = [];

  // Scroll controller
  final _scrollController = ScrollController();
  double _headerOpacity = 1.0;

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
    final offset = _scrollController.offset;
    setState(() {
      _headerOpacity = (1 - (offset / 150)).clamp(0.0, 1.0);
    });
  }

  /// [showLoading] gates the full-screen shimmer skeleton. Only the first load
  /// (from initState) shows it; post-add/undo/return refreshes update data in
  /// place so the skeleton doesn't flash over the content on every tap.
  Future<void> _loadData({bool showLoading = false}) async {
    if (showLoading) setState(() => _isLoading = true);

    try {
      await WaterService.init();
      final todayData = WaterService.getTodayData();
      final goal = WaterService.getDailyGoal();

      // Build week data
      final weekData = <DayProgress>[];
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));

      for (int i = 0; i < 7; i++) {
        final date = weekStart.add(Duration(days: i));
        if (date.isAfter(now)) break;

        final dayData = WaterService.getDataForDate(date);
        weekData.add(DayProgress(
          date: date,
          intakeMl: dayData?.effectiveHydrationMl ?? 0,
          goalMl: goal,
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
      // id so the SnackBar can undo it.
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
        // The SnackBar reads as the water app, not the beverage — keep the
        // chrome on the single water accent.
        final water = AquaTheme.getBeverage('water');

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Text(beverage.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Text(
                    '+${amountMl}ml ${beverage.name}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              backgroundColor: water.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AquaTheme.radiusMedium),
              ),
              duration: const Duration(seconds: 3),
              // Without this, SnackBar.persist defaults to `action != null`
              // (SDK snack_bar.dart) so the Undo action would keep the toast on
              // screen forever. Keep Undo but let it auto-dismiss after 3s.
              persist: false,
              action: addedLogId == null
                  ? null
                  : SnackBarAction(
                      label: 'Undo',
                      textColor: Colors.white,
                      onPressed: () async {
                        HapticFeedback.lightImpact();
                        await WaterService.removeWaterLog(addedLogId);
                        await _loadData();
                      },
                    ),
            ),
          );
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
    // Goal editing is a chrome/header CTA — keep it on the water accent.
    final beverage = AquaTheme.getBeverage('water');

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
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setModalState(() {
                        newGoal = (newGoal - 250).clamp(500, 5000);
                      });
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: beverage.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Symbols.remove_rounded, color: beverage.primary),
                    ),
                  ),
                  const SizedBox(width: AquaTheme.spacingL),
                  Column(
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => beverage.gradient.createShader(bounds),
                        child: Text(
                          '${newGoal}ml',
                          style: Theme.of(context)
                              .textTheme
                              .displayLarge
                              ?.copyWith(color: Colors.white),
                        ),
                      ),
                      Text(
                        '${(newGoal / 250).round()} glasses',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AquaTheme.getTextSecondary(context),
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(width: AquaTheme.spacingL),
                  IconButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setModalState(() {
                        newGoal = (newGoal + 250).clamp(500, 5000);
                      });
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: beverage.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Symbols.add_rounded, color: beverage.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AquaTheme.spacingXL),
              GestureDetector(
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  final profile = WaterService.getProfile();
                  final updatedProfile = profile.copyWith(
                    customGoalMl: newGoal,
                    useCustomGoal: true,
                  );
                  await WaterService.saveProfile(updatedProfile);

                  final todayData = WaterService.getTodayData();
                  final updatedData = todayData.copyWith(dailyGoalMl: newGoal);
                  await WaterService.saveDailyData(updatedData);

                  if (context.mounted) {
                    Navigator.pop(context);
                    _loadData();
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: beverage.gradient,
                    borderRadius: BorderRadius.circular(AquaTheme.radiusMedium),
                    boxShadow: [
                      BoxShadow(
                        color: beverage.primary.withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Symbols.check_rounded, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'Save Goal',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Colors.white,
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
                        // Always available: backed by the free on-device rule
                        // engine via AiAssistant, so the tip always renders.
                        AiInsightCard(
                          title: 'Hydration tips',
                          icon: Symbols.water_drop_rounded,
                          accent: AppColorsExt.of(context).water,
                          // Cache per data signature (100ml + 3h buckets, plus
                          // streak — the tip text embeds it) so re-opening the
                          // tab doesn't re-hit a cloud engine or show a stale tip.
                          cacheKey:
                              'hydration:${todayData.effectiveHydrationMl ~/ 100}:${todayData.dailyGoalMl}:${WaterService.getCurrentStreak()}:${DateTime.now().hour ~/ 3}',
                          loader: () => AiAssistant().hydrationTip(
                            intakeMl: todayData.effectiveHydrationMl,
                            goalMl: todayData.dailyGoalMl,
                            streakDays: WaterService.getCurrentStreak(),
                            hour: DateTime.now().hour,
                          ),
                        ),
                        _buildWaterInsight(
                            todayData.effectiveHydrationMl, todayData.dailyGoalMl),

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
                        
                        const SizedBox(height: 100),
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
    final isDark = AquaTheme.isDark(context);
    
    return SliverAppBar(
      expandedHeight: 110,
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
                boxShadow: AquaTheme.subtleShadow,
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
          child: Opacity(
            opacity: _headerOpacity,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => beverage.gradient.createShader(bounds),
                          child: Text(
                            'Hydration',
                            style: Theme.of(context)
                                .textTheme
                                .displayMedium
                                ?.copyWith(color: Colors.white),
                          ),
                        ),
                        const Spacer(),
                        if (streak > 0) AquaStreakBadge(streak: streak),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getGreeting(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AquaTheme.getCardBg(context).withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              boxShadow: AquaTheme.subtleShadow,
            ),
            child: Icon(
              icon,
              size: 20,
              color: beverage.primary,
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
      _FeatureEntry(Symbols.flag_rounded, 'Challenges', _navigateToChallenges),
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
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.85,
          children: [
            for (final e in entries)
              _buildFeatureCard(
                icon: e.icon,
                label: e.label,
                water: water,
                onTap: e.onTap,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String label,
    required BeverageThemeData water,
    required VoidCallback onTap,
  }) {
    final isDark = AquaTheme.isDark(context);

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
          color: AquaTheme.getCardBg(context),
          borderRadius: BorderRadius.circular(AquaTheme.radiusMedium),
          border: Border.all(
            color: water.primary.withOpacity(isDark ? 0.18 : 0.12),
            width: 1,
          ),
          boxShadow: AquaTheme.subtleShadow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: water.primary.withOpacity(isDark ? 0.18 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: water.primary, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AquaTheme.caption.copyWith(
                color: AquaTheme.getTextPrimary(context),
                fontWeight: FontWeight.w600,
              ),
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

  void _navigateToChallenges() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HydrationChallengesScreen()),
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
  Widget _buildWaterInsight(int intakeMl, int goalMl) {
    final now = DateTime.now();
    final pace = HydrationPacer.compute(
        intakeMl: intakeMl, goalMl: goalMl, nowMinutes: now.hour * 60 + now.minute);
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
