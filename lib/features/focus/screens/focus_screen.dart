import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/ai/ai_assistant.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/services/vitavibe_service.dart';
import '../models/focus_session.dart';
import '../models/focus_plant.dart';
import '../services/focus_service.dart';
import '../services/tag_service.dart';
import '../widgets/plant_animation_widget.dart';
import '../widgets/breathing_widget.dart';
import '../models/breathing_exercise.dart';
import '../widgets/ambient_sound_widget.dart';
import '../models/ambient_sound.dart';
import '../models/custom_tag.dart';
import 'focus_garden_screen.dart';
import 'relaxation_screen.dart';
import 'plant_real_trees_screen.dart';
import 'app_allow_list_screen.dart';
import 'custom_tags_screen.dart';
import 'detailed_stats_screen.dart';
import '../services/coins_service.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  final FocusService _focusService = FocusService();
  final CoinsService _coinsService = CoinsService();
  final TagService _tagService = TagService();
  final HapticService _hapticService = HapticService();
  final VitaVibeService _vitaVibeService = VitaVibeService();

  bool _showBreathing = false;
  BreathingPattern? _selectedBreathingPattern;

  @override
  void initState() {
    super.initState();
    _focusService.init();
    _tagService.init();
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);

    return AccentScope(
      feature: FeatureAccent.focus,
      child: ListenableBuilder(
        listenable: Listenable.merge([_focusService, _coinsService, _tagService]),
        builder: (context, _) {
          if (_showBreathing && _selectedBreathingPattern != null) {
            return Scaffold(
              backgroundColor: ext.background,
              body: BreathingWidget(
                pattern: _selectedBreathingPattern!,
                targetCycles: _selectedBreathingPattern!.recommendedCycles,
                onComplete: () {
                  _focusService.incrementBreathingCount();
                  setState(() => _showBreathing = false);
                  _showCompletionSnackbar('Breathing exercise completed!');
                },
                onClose: () => setState(() => _showBreathing = false),
              ),
            );
          }

          return PopScope(
            canPop: !_focusService.isRunning,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop && _focusService.isRunning) {
                _showLeaveSessionDialog();
              }
            },
            child: AppScaffold(
              body: Column(
                children: [
                  _buildHeader(ext),
                  Expanded(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: AppMotion.slow,
                      curve: AppMotion.standard,
                      builder: (context, t, child) => Opacity(
                        opacity: t,
                        child: Transform.translate(
                          offset: Offset(0, (1 - t) * 12),
                          child: child,
                        ),
                      ),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            const SizedBox(height: AppSpacing.xs),
                            _buildTimerSection(ext),
                            const SizedBox(height: AppSpacing.xl),
                            if (!_focusService.isRunning) ...[
                              _buildModeToggle(ext),
                              const SizedBox(height: AppSpacing.xl),
                              if (_focusService.mode == FocusMode.single)
                                _buildDurationSelector(ext)
                              else
                                _buildPomodoroConfig(ext),
                              const SizedBox(height: AppSpacing.xl),
                              _buildFocusCoachCard(ext),
                              const SizedBox(height: AppSpacing.xl),
                              _buildActivitySelector(ext),
                              const SizedBox(height: AppSpacing.xl),
                              _buildTagSelector(ext),
                              const SizedBox(height: AppSpacing.xl),
                              _buildPlantSelector(ext),
                              const SizedBox(height: AppSpacing.xl),
                            ] else ...[
                              _buildActiveSessionCard(ext),
                              const SizedBox(height: AppSpacing.xl),
                            ],
                            _buildSoundSelector(ext),
                            const SizedBox(height: AppSpacing.xl),
                            if (!_focusService.isRunning) ...[
                              _buildBreathingSection(ext),
                              const SizedBox(height: AppSpacing.xl),
                              _buildRelaxationCard(ext),
                              const SizedBox(height: AppSpacing.xl),
                              _buildFeaturesGrid(ext),
                              const SizedBox(height: AppSpacing.xl),
                            ],
                            _buildQuickStats(ext),
                            const SizedBox(height: 120),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _buildHeader(AppColorsExt ext) {
    return AppHeader(
      title: 'Focus',
      greeting: _focusService.isRunning ? 'Stay focused' : 'Ready to focus?',
      icon: Icons.center_focus_strong_rounded,
      accent: ext.focus,
      actions: [
        AppIconButton(
          icon: Icons.spa_rounded,
          accent: ext.success,
          onPressed: () {
            _hapticService.navigation();
            Navigator.push(context, _buildPageRoute(const RelaxationScreen()));
          },
        ),
        AppIconButton(
          icon: Icons.park_rounded,
          accent: ext.focus,
          onPressed: () {
            _hapticService.navigation();
            Navigator.push(context, _buildPageRoute(const FocusGardenScreen()));
          },
        ),
        AppIconButton(
          icon: Icons.insights_rounded,
          accent: ext.info,
          onPressed: () {
            _hapticService.navigation();
            Navigator.push(context, _buildPageRoute(const DetailedStatsScreen()));
          },
        ),
      ],
      bottom: Row(
        children: [
          AppChip(
            label: '${_focusService.stats.currentStreak} day streak',
            icon: Icons.local_fire_department_rounded,
            selected: true,
            accent: ext.warning,
          ),
          const SizedBox(width: AppSpacing.sm),
          // Live coin balance (FOCUS-1). Rebuilds via the merged ListenableBuilder.
          AppChip(
            label: '${_coinsService.totalCoins} coins',
            icon: Icons.monetization_on_rounded,
            selected: true,
            accent: ext.focus,
          ),
        ],
      ),
    );
  }

  PageRoute _buildPageRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.05, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        );
      },
      transitionDuration: AppMotion.slow,
    );
  }

  // ---------------------------------------------------------------------------
  // Timer
  // ---------------------------------------------------------------------------

  Widget _buildTimerSection(AppColorsExt ext) {
    final progress = _focusService.progress;
    final bool isPomodoro = _focusService.mode == FocusMode.pomodoro;
    final bool onBreak = _focusService.isRunning && _focusService.isOnBreak;
    // Focus accent for work; a calmer info tone for breaks (FOCUS-2).
    final AccentSwatch accentSwatch = onBreak ? ext.info : ext.focus;
    // Idle preview shows the length of the first interval.
    final int idleMinutes =
        isPomodoro ? _focusService.workMinutes : _focusService.selectedMinutes;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.xl),
        pressEffect: false,
        child: Column(
          children: [
            if (isPomodoro && _focusService.isRunning) ...[
              _buildPhasePill(ext, accentSwatch, onBreak),
              const SizedBox(height: AppSpacing.md),
            ],
            ProgressRing(
              progress: progress,
              size: 210,
              stroke: 12,
              accent: accentSwatch,
              animate: true,
              center: PlantAnimationWidget(
                plantType: _focusService.selectedPlant,
                progress: progress,
                isAlive: true,
                isAnimating: _focusService.isRunning && !onBreak,
                size: 84,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              _focusService.isRunning
                  ? _focusService.formattedTime
                  : '$idleMinutes:00',
              style: TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
                color: ext.mark(accentSwatch),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (_focusService.isRunning) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                onBreak
                    ? 'Break • ${(progress * 100).toInt()}%'
                    : '${(progress * 100).toInt()}% completed',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: ext.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
            if (isPomodoro) ...[
              const SizedBox(height: AppSpacing.md),
              _buildRoundIndicator(ext),
            ],
            const SizedBox(height: AppSpacing.xl),
            _buildControlButtons(ext, accentSwatch),
          ],
        ),
      ),
    );
  }

  /// Small pill above the ring naming the active pomodoro phase (FOCUS-2).
  Widget _buildPhasePill(AppColorsExt ext, AccentSwatch accent, bool onBreak) {
    final String label = onBreak
        ? (_focusService.isLongBreak ? 'Long Break' : 'Short Break')
        : 'Focus';
    final IconData icon =
        onBreak ? Icons.self_improvement_rounded : Icons.center_focus_strong_rounded;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: accent.container,
        borderRadius: AppRadius.brFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent.onContainer),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: accent.onContainer,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

  /// Round progress dots, e.g. ●●○○ (FOCUS-2). Filled = completed work rounds,
  /// the active round pulses with the focus accent while working.
  Widget _buildRoundIndicator(AppColorsExt ext) {
    final int total = _focusService.totalRounds;
    final int done = _focusService.currentRound;
    final bool working = _focusService.isRunning && !_focusService.isOnBreak;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < total; i++) ...[
          () {
            final bool filled = i < done;
            final bool active = i == done && working;
            return Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled
                    ? ext.mark(ext.focus)
                    : (active ? ext.focus.container : Colors.transparent),
                border: Border.all(
                  color: filled || active ? ext.mark(ext.focus) : ext.outlineStrong,
                  width: active ? 2 : 1.4,
                ),
              ),
            );
          }(),
          if (i != total - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _buildControlButtons(AppColorsExt ext, AccentSwatch accent) {
    if (!_focusService.isRunning) {
      return AppButton(
        label: _focusService.mode == FocusMode.pomodoro
            ? 'Start Pomodoro'
            : 'Start Focus',
        leadingIcon: Icons.play_arrow_rounded,
        accent: ext.focus,
        size: AppButtonSize.lg,
        fullWidth: true,
        onPressed: () {
          _hapticService.focusStart();
          _vitaVibeService.focusStart();
          _focusService.startSession();
        },
      );
    }

    return Row(
      children: [
        Expanded(
          child: AppButton(
            label: _focusService.isPaused ? 'Resume' : 'Pause',
            leadingIcon: _focusService.isPaused
                ? Icons.play_arrow_rounded
                : Icons.pause_rounded,
            accent: accent,
            size: AppButtonSize.lg,
            fullWidth: true,
            onPressed: () {
              _hapticService.focusPause();
              _vitaVibeService.playPattern(VibePattern.doubleTap);
              if (_focusService.isPaused) {
                _focusService.resumeSession();
              } else {
                _focusService.pauseSession();
              }
            },
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: AppButton(
            label: 'Give Up',
            leadingIcon: Icons.close_rounded,
            variant: AppButtonVariant.danger,
            size: AppButtonSize.lg,
            fullWidth: true,
            onPressed: _showAbandonDialog,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Mode toggle (FOCUS-2)
  // ---------------------------------------------------------------------------

  Widget _buildModeToggle(AppColorsExt ext) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: SegmentedToggle(
        accent: ext.focus,
        index: _focusService.mode.index,
        onChanged: (i) {
          _hapticService.selection();
          _focusService.setMode(FocusMode.values[i]);
        },
        items: const [
          SegmentItem(icon: Icons.timer_outlined, label: 'Single'),
          SegmentItem(icon: Icons.repeat_rounded, label: 'Pomodoro'),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // AI focus coach
  // ---------------------------------------------------------------------------

  /// Self-loading AI card offering one short, actionable focus suggestion based
  /// on real stats. Always available via the free on-device rule engine.
  Widget _buildFocusCoachCard(AppColorsExt ext) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: AiInsightCard(
        title: 'Focus coach',
        icon: Icons.psychology_rounded,
        accent: ext.focus,
        cacheKey:
            'focus:${_focusService.todayMinutes ~/ 15}:${_focusService.stats.currentStreak}:${_focusService.stats.totalSessions}',
        loader: () {
          final stats = _focusService.stats;
          return AiAssistant().focusCoach(
            todayMinutes: _focusService.todayMinutes,
            streakDays: stats.currentStreak,
            totalSessions: stats.totalSessions,
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Pomodoro config (FOCUS-2)
  // ---------------------------------------------------------------------------

  Widget _buildPomodoroConfig(AppColorsExt ext) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Pomodoro',
            icon: Icons.repeat_rounded,
            accent: ext.focus,
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildConfigRow(
            ext,
            label: 'Focus',
            options: const [15, 25, 30, 45, 50],
            current: _focusService.workMinutes,
            suffix: 'min',
            onSelect: (v) => _focusService.setPomodoroConfig(workMinutes: v),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildConfigRow(
            ext,
            label: 'Short break',
            options: const [3, 5, 10],
            current: _focusService.shortBreakMinutes,
            suffix: 'min',
            onSelect: (v) => _focusService.setPomodoroConfig(shortBreakMinutes: v),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildConfigRow(
            ext,
            label: 'Long break',
            options: const [15, 20, 30],
            current: _focusService.longBreakMinutes,
            suffix: 'min',
            onSelect: (v) => _focusService.setPomodoroConfig(longBreakMinutes: v),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildConfigRow(
            ext,
            label: 'Long break every',
            options: const [2, 3, 4, 5],
            current: _focusService.roundsBeforeLongBreak,
            suffix: 'rounds',
            onSelect: (v) =>
                _focusService.setPomodoroConfig(roundsBeforeLongBreak: v),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildConfigRow(
            ext,
            label: 'Total rounds',
            options: const [2, 3, 4, 6, 8],
            current: _focusService.totalRounds,
            suffix: 'rounds',
            onSelect: (v) => _focusService.setPomodoroConfig(totalRounds: v),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigRow(
    AppColorsExt ext, {
    required String label,
    required List<int> options,
    required int current,
    required String suffix,
    required ValueChanged<int> onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: ext.textSecondary, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.xs),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              for (final value in options) ...[
                AppChip(
                  label: '$value $suffix',
                  selected: current == value,
                  accent: ext.focus,
                  onTap: () {
                    _hapticService.selection();
                    onSelect(value);
                  },
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Duration
  // ---------------------------------------------------------------------------

  Widget _buildDurationSelector(AppColorsExt ext) {
    const durations = [5, 10, 15, 25, 30, 45, 60, 90];
    final isCustom = !durations.contains(_focusService.selectedMinutes);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: 'Duration', icon: Icons.timer_outlined, accent: ext.focus),
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (final mins in durations) ...[
                  AppChip(
                    label: '$mins min',
                    selected: _focusService.selectedMinutes == mins,
                    accent: ext.focus,
                    onTap: () {
                      _hapticService.selection();
                      _focusService.setDuration(mins);
                    },
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                AppChip(
                  label: isCustom
                      ? '${_focusService.selectedMinutes} min'
                      : 'Custom',
                  icon: Icons.tune_rounded,
                  selected: isCustom,
                  accent: ext.focus,
                  onTap: _showCustomDurationSheet,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCustomDurationSheet() {
    _hapticService.selection();
    final controller =
        TextEditingController(text: '${_focusService.selectedMinutes}');
    String? errorText;

    AppBottomSheet.show(
      context,
      title: 'Custom duration',
      icon: Icons.tune_rounded,
      accent: AppColorsExt.of(context).focus,
      builder: (ctx) {
        final ext = AppColorsExt.of(ctx);
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Set any focus length between 1 and 600 minutes.',
                  style: Theme.of(ctx)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: ext.textSecondary),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  controller: controller,
                  label: 'Minutes',
                  hint: 'e.g. 50',
                  prefixIcon: Icons.timer_outlined,
                  accent: ext.focus,
                  keyboardType: TextInputType.number,
                  errorText: errorText,
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Set duration',
                  accent: ext.focus,
                  fullWidth: true,
                  onPressed: () {
                    final value = int.tryParse(controller.text.trim());
                    if (value == null || value < 1 || value > 600) {
                      setSheet(() => errorText = 'Enter a number from 1 to 600');
                      return;
                    }
                    _hapticService.selection();
                    _focusService.setDuration(value);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(controller.dispose);
  }

  // ---------------------------------------------------------------------------
  // Activity
  // ---------------------------------------------------------------------------

  Widget _buildActivitySelector(AppColorsExt ext) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: 'Activity', icon: Icons.category_outlined, accent: ext.focus),
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (final activity in FocusActivityType.values) ...[
                  AppChip(
                    label: '${activity.emoji}  ${activity.name}',
                    selected: _focusService.selectedActivity == activity,
                    accent: ext.focus,
                    onTap: () {
                      _hapticService.selection();
                      _focusService.setActivity(activity);
                    },
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tags (FOCUS-3)
  // ---------------------------------------------------------------------------

  Widget _buildTagSelector(AppColorsExt ext) {
    final tags = _tagService.tags;
    final selectedIds = _focusService.selectedTagIds;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Tags',
            icon: Icons.label_outline_rounded,
            accent: ext.focus,
            actionLabel: 'Manage',
            onAction: () {
              _hapticService.navigation();
              Navigator.push(context, _buildPageRoute(const CustomTagsScreen()));
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          if (tags.isEmpty)
            Text(
              'Create tags to organize your sessions',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: ext.textSecondary),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  for (final tag in tags) ...[
                    _buildTagChip(ext, tag, selectedIds.contains(tag.id)),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTagChip(AppColorsExt ext, FocusTag tag, bool isSelected) {
    // Tag colors are user data — used directly for the selected accent.
    final Color tagColor = tag.color;
    return GestureDetector(
      onTap: () {
        _hapticService.selection();
        _focusService.toggleTag(tag.id);
      },
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? tagColor.withOpacity(ext.isDark ? 0.24 : 0.14) : ext.surfaceVariant,
          borderRadius: AppRadius.brFull,
          border: Border.all(
            color: isSelected ? tagColor : ext.outline,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Icon(Icons.check_rounded, size: 15, color: tagColor),
              const SizedBox(width: 6),
            ] else if (tag.emoji != null) ...[
              Text(tag.emoji!, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
            ],
            Text(
              tag.name,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: isSelected ? tagColor : ext.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Plant selector
  // ---------------------------------------------------------------------------

  Widget _buildPlantSelector(AppColorsExt ext) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SectionHeader(
                  title: 'Choose Plant',
                  icon: Icons.local_florist_outlined,
                  accent: ext.focus,
                ),
              ),
              AppChip(
                label:
                    '${_focusService.unlockedPlants.length}/${PlantType.values.length}',
                accent: ext.focus,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 122,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: PlantType.values.length,
              itemBuilder: (context, index) {
                final plant = PlantType.values[index];
                final isUnlocked = _focusService.unlockedPlants.contains(plant);
                final isSelected = _focusService.selectedPlant == plant;
                final plantColor = plant.primaryColor;

                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  child: GestureDetector(
                    onTap: isUnlocked
                        ? () {
                            _hapticService.selection();
                            _focusService.setPlant(plant);
                          }
                        : null,
                    child: AnimatedContainer(
                      duration: AppMotion.fast,
                      curve: AppMotion.standard,
                      width: 96,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? plantColor.withOpacity(ext.isDark ? 0.2 : 0.12)
                            : ext.surface,
                        borderRadius: AppRadius.brCard,
                        border: Border.all(
                          color: isSelected ? plantColor : ext.outline,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Opacity(
                            opacity: isUnlocked ? 1 : 0.5,
                            child: Text(
                              isUnlocked ? plant.emoji : '🔒',
                              style: const TextStyle(fontSize: 32),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            plant.name,
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isUnlocked
                                      ? (isSelected ? plantColor : ext.textPrimary)
                                      : ext.textSecondary,
                                ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (!isUnlocked)
                            Text(
                              '${plant.unlockMinutes}m',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: ext.textTertiary,
                                  ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Ambient sound
  // ---------------------------------------------------------------------------

  Widget _buildSoundSelector(AppColorsExt ext) {
    final sound = _focusService.selectedSound;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Ambient Sound',
            icon: Icons.music_note_outlined,
            accent: ext.focus,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            onTap: _showSoundPicker,
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: ext.focus.container,
                    borderRadius: AppRadius.brMd,
                  ),
                  child: Center(
                    child: Text(sound.emoji, style: const TextStyle(fontSize: 26)),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sound.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sound.category,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: ext.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                AppIconButton(
                  icon: _focusService.isAudioPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  accent: ext.focus,
                  onPressed: () => _focusService.toggleAudio(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Breathing
  // ---------------------------------------------------------------------------

  Widget _buildBreathingSection(AppColorsExt ext) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: 'Breathing', icon: Icons.air_outlined, accent: ext.focus),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 112,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: BreathingPattern.values.length,
              itemBuilder: (context, index) {
                final pattern = BreathingPattern.values[index];
                final patternColor = pattern.color;
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  child: SizedBox(
                    width: 132,
                    child: AppCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      onTap: () {
                        _hapticService.selection();
                        setState(() {
                          _selectedBreathingPattern = pattern;
                          _showBreathing = true;
                        });
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: patternColor.withOpacity(ext.isDark ? 0.24 : 0.14),
                              borderRadius: AppRadius.brSm,
                            ),
                            child: Icon(pattern.icon, color: patternColor, size: 20),
                          ),
                          const Spacer(),
                          Text(
                            pattern.name,
                            style: Theme.of(context).textTheme.labelLarge,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Relaxation entry
  // ---------------------------------------------------------------------------

  Widget _buildRelaxationCard(AppColorsExt ext) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: AppCard(
        onTap: () {
          _hapticService.navigation();
          _vitaVibeService.tap();
          Navigator.push(context, _buildPageRoute(const RelaxationScreen()));
        },
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: ext.focus.container,
                borderRadius: AppRadius.brMd,
              ),
              child: const Center(child: Text('🧘', style: TextStyle(fontSize: 28))),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Relaxation Zone',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 3),
                  Text(
                    'Binaural beats, 432Hz healing & more',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: ext.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded, color: ext.mark(ext.focus), size: 22),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Today's progress
  // ---------------------------------------------------------------------------

  Widget _buildQuickStats(AppColorsExt ext) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: "Today's Progress",
            icon: Icons.trending_up_rounded,
            accent: ext.focus,
            actionLabel: 'View All',
            onAction: () => Navigator.push(
                context, _buildPageRoute(const DetailedStatsScreen())),
          ),
          const SizedBox(height: AppSpacing.sm),
          StatTileRow(
            tiles: [
              StatTile(
                icon: Icons.timer_rounded,
                value: '${_focusService.todayMinutes}',
                label: 'Minutes',
                accent: ext.info,
              ),
              StatTile(
                icon: Icons.local_florist_rounded,
                value: '${_focusService.todayPlants.length}',
                label: 'Plants',
                accent: ext.success,
              ),
              StatTile(
                icon: Icons.local_fire_department_rounded,
                value: '${_focusService.stats.currentStreak}',
                label: 'Streak',
                accent: ext.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // More features
  // ---------------------------------------------------------------------------

  Widget _buildFeaturesGrid(AppColorsExt ext) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: 'More Features', icon: Icons.apps_rounded, accent: ext.focus),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _buildFeatureCard(
                  ext,
                  emoji: '🌍',
                  title: 'Plant Trees',
                  subtitle: '${_coinsService.totalCoins} coins',
                  accent: ext.success,
                  onTap: () => Navigator.push(
                      context, _buildPageRoute(const PlantRealTreesScreen())),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildFeatureCard(
                  ext,
                  emoji: '📊',
                  title: 'Statistics',
                  subtitle: 'Analytics',
                  accent: ext.info,
                  onTap: () => Navigator.push(
                      context, _buildPageRoute(const DetailedStatsScreen())),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _buildFeatureCard(
                  ext,
                  emoji: '🏷️',
                  title: 'Tags',
                  subtitle: 'Organize',
                  accent: ext.reminders,
                  onTap: () => Navigator.push(
                      context, _buildPageRoute(const CustomTagsScreen())),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildFeatureCard(
                  ext,
                  emoji: '📱',
                  title: 'App List',
                  subtitle: 'Focus Mode',
                  accent: ext.focus,
                  onTap: () => Navigator.push(
                      context, _buildPageRoute(const AppAllowListScreen())),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
    AppColorsExt ext, {
    required String emoji,
    required String title,
    required String subtitle,
    required AccentSwatch accent,
    required VoidCallback onTap,
  }) {
    return AppCard(
      onTap: () {
        _hapticService.navigation();
        onTap();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.container,
              borderRadius: AppRadius.brSm,
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: ext.textSecondary),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Active session card
  // ---------------------------------------------------------------------------

  Widget _buildActiveSessionCard(AppColorsExt ext) {
    final bool onBreak = _focusService.isOnBreak;
    final AccentSwatch accent = onBreak ? ext.info : ext.focus;
    final String title = onBreak ? 'On a Break' : 'Session Active';
    final String subtitle = onBreak
        ? 'Relax and recharge — focus resumes soon.'
        : 'Stay focused! Your plant is growing...';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: AppCard(
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accent.container,
                    borderRadius: AppRadius.brMd,
                  ),
                  child: Icon(
                    onBreak ? Icons.self_improvement_rounded : Icons.lock_rounded,
                    color: accent.onContainer,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: ext.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                if (_focusService.isPaused)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: ext.warning.container,
                      borderRadius: AppRadius.brSm,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pause_circle_rounded,
                            color: ext.warning.onContainer, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Paused',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: ext.warning.onContainer,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _buildActiveSessionInfoItem(
                    ext,
                    emoji: _focusService.selectedActivity.emoji,
                    label: 'Activity',
                    value: _focusService.selectedActivity.name,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _buildActiveSessionInfoItem(
                    ext,
                    emoji: _focusService.selectedPlant.emoji,
                    label: 'Plant',
                    value: _focusService.selectedPlant.name,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSessionInfoItem(
    AppColorsExt ext, {
    required String emoji,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: ext.surfaceVariant,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: ext.outline),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: ext.textSecondary),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.labelLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sound picker sheet
  // ---------------------------------------------------------------------------

  void _showSoundPicker() {
    AppBottomSheet.show(
      context,
      title: 'Ambient Sounds',
      icon: Icons.music_note_rounded,
      accent: AppColorsExt.of(context).focus,
      builder: (ctx) => AmbientSoundSelector(
        selectedSound: _focusService.selectedSound,
        volume: _focusService.soundVolume,
        onSoundChanged: (sound) {
          _focusService.setSound(sound);
          Navigator.pop(ctx);
        },
        onVolumeChanged: (volume) {
          _focusService.setSoundVolume(volume);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dialogs
  // ---------------------------------------------------------------------------

  void _showAbandonDialog() {
    final ext = AppColorsExt.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: ext.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brSheet),
        title: const Row(
          children: [
            Text('🥀', style: TextStyle(fontSize: 28)),
            SizedBox(width: 12),
            Text('Give up?'),
          ],
        ),
        content: Text(
          'Your plant will wither if you stop now. Are you sure you want to abandon this session?',
          style: Theme.of(dialogCtx)
              .textTheme
              .bodyMedium
              ?.copyWith(color: ext.textSecondary),
        ),
        actions: [
          AppButton(
            label: 'Keep Going',
            variant: AppButtonVariant.secondary,
            accent: ext.focus,
            onPressed: () => Navigator.pop(dialogCtx),
          ),
          AppButton(
            label: 'Give Up',
            variant: AppButtonVariant.danger,
            onPressed: () {
              Navigator.pop(dialogCtx);
              _focusService.abandonSession();
              _showCompletionSnackbar('Session abandoned. Your plant has withered 🥀');
            },
          ),
        ],
      ),
    );
  }

  void _showLeaveSessionDialog() {
    final ext = AppColorsExt.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: ext.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brSheet),
        title: Row(
          children: [
            Icon(Icons.lock_rounded, color: ext.mark(ext.warning), size: 28),
            const SizedBox(width: 12),
            const Text('Session Locked'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _focusService.selectedPlant.emoji,
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 16),
            Text(
              'Your focus session is still running! Leaving now will kill your plant.',
              textAlign: TextAlign.center,
              style: Theme.of(dialogCtx)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: ext.textSecondary),
            ),
            const SizedBox(height: 12),
            Text(
              'Time remaining: ${_focusService.formattedTime}',
              style: Theme.of(dialogCtx).textTheme.titleLarge?.copyWith(
                    color: ext.mark(ext.focus),
                  ),
            ),
          ],
        ),
        actions: [
          AppButton(
            label: 'Stay Focused',
            variant: AppButtonVariant.secondary,
            accent: ext.focus,
            onPressed: () => Navigator.pop(dialogCtx),
          ),
          AppButton(
            label: 'Abandon & Leave',
            variant: AppButtonVariant.danger,
            onPressed: () {
              Navigator.pop(dialogCtx);
              // abandonSession() flips isRunning → the ListenableBuilder rebuilds
              // this screen into its idle state. Do NOT pop the screen itself —
              // it's a tab root, so popping leaves a black screen.
              _focusService.abandonSession();
              _showCompletionSnackbar('Session abandoned. Your plant has withered 🥀');
            },
          ),
        ],
      ),
    );
  }

  void _showCompletionSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
        margin: const EdgeInsets.all(AppSpacing.lg),
      ),
    );
  }
}
