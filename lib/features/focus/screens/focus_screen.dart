import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/health/focus_readiness.dart';
import '../../../core/health/insight.dart';
import '../../../core/health/insight_engine.dart';
import '../../../core/health/focus_insights.dart';
import '../../../core/services/audio_service.dart';
import '../../biometrics/services/biometrics_service.dart';
import '../../sleep/services/sleep_service.dart';
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
import '../models/app_allow_list.dart';
import '../models/custom_tag.dart';
import 'focus_garden_screen.dart';
import 'relaxation_screen.dart';
import 'plant_real_trees_screen.dart';
import 'app_allow_list_screen.dart';
import 'custom_tags_screen.dart';
import 'detailed_stats_screen.dart';
import 'settings/focus_reminders_settings_screen.dart';
import '../services/coins_service.dart';
import '../../../core/health/coach_text.dart';
import '../../../core/health/streak_milestones.dart';
import '../../../core/services/clean_storage_service.dart';
import '../../../core/widgets/toast/toast.dart';

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

  /// Owned by the screen, not the sheet: the sheet is its own route and is
  /// rebuilt on every selection, so a controller created there would lose the
  /// text the moment the user picked a plant.
  final TextEditingController _intentionController = TextEditingController();

  /// Set once the just-finished session has been rated or the card dismissed, so
  /// the review is asked once and never nags.
  String? _reviewedSessionId;

  bool _showBreathing = false;
  BreathingPattern? _selectedBreathingPattern;

  /// Set when the breathing exercise on screen is a pre-roll, so finishing OR
  /// closing it continues into the session instead of returning to the ring.
  bool _prerollThenStart = false;

  /// When the on-screen breathing exercise began, for the mindfulness record.
  /// Only a COMPLETED exercise is written, so this is cleared on close.
  DateTime? _breathingStartedAt;

  /// So a milestone is celebrated once, not on every rebuild after it is hit.
  static const _lastCelebratedMilestoneKey = 'focusLastCelebratedMilestone';

  @override
  void initState() {
    super.initState();
    _focusService.init();
    _tagService.init();
    _focusService.justCompleted.addListener(_onSessionCompleted);
    AudioService().addListener(_onAudioChanged);
  }

  @override
  void dispose() {
    _focusService.justCompleted.removeListener(_onSessionCompleted);
    AudioService().removeListener(_onAudioChanged);
    _intentionController.dispose();
    super.dispose();
  }

  /// The last audio error message actually shown, so one failure is one toast.
  String? _shownAudioError;

  /// Tell the user when the sound did not play.
  ///
  /// `AudioService.lastError` was written to be surfaced and then had no reader
  /// anywhere in the app, so a failed load was a `debugPrint`: the session ran on
  /// in silence and looked identical to one where the user had chosen no sound at
  /// all. Audio failing must never take the session down — but it must not be
  /// invisible either.
  ///
  /// Gated on the message rather than on a bool: `AudioService` notifies on every
  /// play, pause and stop, so an un-gated listener would re-toast the same
  /// failure on each one.
  void _onAudioChanged() {
    final error = AudioService().lastError;
    if (error == null) {
      _shownAudioError = null;
      return;
    }
    if (error == _shownAudioError || !mounted) return;
    _shownAudioError = error;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusToast.error(context, message: error);
    });
  }

  /// Celebrate a finished session, in the app, where the user is looking.
  ///
  /// `focus_toast.dart` has held a finished `sessionComplete` — achievement
  /// styling, expanding-ring particles, five second dwell — with **zero callers**
  /// since it was written. It is the usage example in the toast barrel file. All
  /// the moment ever needed was somebody to call it.
  void _onSessionCompleted() {
    final session = _focusService.justCompleted.value;
    if (session == null || !mounted) return;

    // After the frame, not during it. This runs inside a ValueNotifier callback
    // fired from `_completeSession`, and inserting an OverlayEntry while a build
    // or layout pass is in flight throws.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _hapticService.focusComplete();
      _vitaVibeService.celebrate();
      FocusToast.sessionComplete(context, minutes: session.actualMinutes);
      _celebrateStreakMilestone();
    });
  }

  /// A quiet nod at 7, 14, 30, 60, 100, 180 and 365 days.
  ///
  /// Medication already does this (`nunito_medication_dashboard.dart:202`) and
  /// Focus never did, using the same shared `streak_milestones.dart`. Deliberately
  /// a toast rather than Medication's modal dialog: a dialog you must dismiss to
  /// carry on is a poor reward for concentrating, and it would land on top of the
  /// completion toast.
  Future<void> _celebrateStreakMilestone() async {
    final streak = _focusService.stats.currentStreak;
    final last = CleanStorageService.getAppPreference(
        _lastCelebratedMilestoneKey) as int?;
    if (!isNewMilestone(streak, last)) return;
    final reached = highestMilestoneReached(streak);
    if (reached == null) return;
    await CleanStorageService.setAppPreference(
        _lastCelebratedMilestoneKey, reached);
    if (!mounted) return;
    FocusToast.streak(context, days: reached);
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
                  // Breathing is the clearest mindfulness case in the feature:
                  // guided practice with a real start and end. Unawaited, and a
                  // no-op unless the user opted in.
                  final started = _breathingStartedAt;
                  if (started != null) {
                    _focusService.writeBreathingMindfulness(
                        start: started, end: DateTime.now());
                  }
                  _breathingStartedAt = null;
                  setState(() => _showBreathing = false);
                  if (_prerollThenStart) {
                    _prerollThenStart = false;
                    _startSession();
                  } else {
                    _showCompletionSnackbar('Breathing exercise completed!');
                  }
                },
                onClose: () {
                  // Closed early: nothing to record. A partial exercise is not a
                  // practice, and writing one would inflate the user's mindful
                  // minutes with time they did not spend.
                  _breathingStartedAt = null;
                  setState(() => _showBreathing = false);
                  // Closing a PRE-ROLL still starts the session: the user tapped
                  // Start, and a skipped ritual must not swallow the action they
                  // actually asked for.
                  if (_prerollThenStart) {
                    _prerollThenStart = false;
                    _startSession();
                  }
                },
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
                    // Lazy list, not SingleChildScrollView + Column.
                    //
                    // Every section used to be constructed AND inflated on
                    // every build regardless of whether it was on screen —
                    // 2321 elements, ~4x the app median, for a screen where
                    // roughly two sections are visible at a time. The coach
                    // card alone maps every focus session and runs the insight
                    // engine synchronously, four screenfuls down.
                    //
                    // Each child is wrapped in `Center` deliberately: a Column
                    // (default crossAxisAlignment.center) hands children LOOSE
                    // width and centres them, while a sliver hands them TIGHT
                    // full width. `Center` reproduces the Column contract
                    // exactly — loose width, centred, intrinsic height — so
                    // this is layout-preserving by construction rather than by
                    // inspection, which matters because it cannot be eyeballed
                    // on a device from here.
                    //
                    // The whole-screen entrance fade was also removed. An
                    // `Opacity` between 0 and 1 forces a `saveLayer` over the
                    // full viewport every frame, and it was wrapping the
                    // largest tree in the app at the exact moment that tree
                    // was being built. The slide survives — `Transform` needs
                    // no layer.
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: AppMotion.slow,
                      curve: AppMotion.standard,
                      builder: (context, t, child) => Transform.translate(
                        offset: Offset(0, (1 - t) * 12),
                        child: child,
                      ),
                      child: Builder(builder: (context) {
                        final idle = !_focusService.isRunning;
                        // Computed ONCE per build and shared. `_sessionRefs` maps
                        // every session, and the coach line and the insight card
                        // both need it — deriving it twice would double the work
                        // this screen was already criticised for doing.
                        final refs = _sessionRefs();
                        final bestHour = FocusInsights.bestFocusHour(refs);
                        final suggested = FocusInsights.suggestedMinutes(refs);
                        final sections = <Widget>[
                          const SizedBox(height: AppSpacing.xs),
                          // Only the clock and the ring change per second.
                          ValueListenableBuilder<int>(
                            valueListenable: _focusService.tick,
                            builder: (context, _, __) =>
                                _buildTimerSection(ext),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          // The resting surface used to stack THIRTEEN sections:
                          // mode, duration, coach, activity, tags, plant, sound,
                          // breathing, relaxation, features and stats, all under
                          // the ring, on a screen whose entire purpose is calm.
                          // Nothing was broken about it — it laid out, contrasted
                          // and fitted correctly at every size, which is exactly
                          // why twelve structural dimensions rated it 4.75/5.
                          //
                          // At rest there are now four things: how long, what the
                          // setup is, Start, and one line of context. Everything
                          // else moved into the setup sheet or the grid below —
                          // moved, not removed, and every default already persists,
                          // so the ordinary path is open and Start.
                          if (idle) ...[
                            // Above the controls: it refers to what just
                            // happened, and burying it under the setup row would
                            // put it below the fold on a 375x812 phone — the same
                            // mistake the coach line was moved to avoid.
                            _buildSessionReview(ext),
                            if (_focusService.justCompleted.value != null)
                              const SizedBox(height: AppSpacing.lg),
                            // No duration picker in flow mode: there is nothing
                            // to pick. Offering one would be the UI implying a
                            // target the mode does not have.
                            if (_focusService.mode == FocusMode.single) ...[
                              _buildDurationSelector(ext, suggested),
                              const SizedBox(height: AppSpacing.lg),
                            ],
                            // The contextual line comes BEFORE the setup row.
                            // Ordered after it, this fell below the fold of a
                            // 375x812 phone and a lazy list never built it, so a
                            // new user saw a Start button and no suggestion.
                            _buildCoachLine(ext, bestHour, suggested),
                            const SizedBox(height: AppSpacing.lg),
                            _buildSessionSetupRow(ext),
                            const SizedBox(height: AppSpacing.xl),
                            _buildFocusInsight(ext, refs, bestHour, suggested),
                            const SizedBox(height: AppSpacing.xl),
                          ] else ...[
                            _buildActiveSessionCard(ext),
                            const SizedBox(height: AppSpacing.xl),
                            // Sound stays inline DURING a session: changing it is
                            // a mid-session need, and burying a live control two
                            // taps deep to tidy the resting screen would be the
                            // restructure making things worse.
                            _buildSoundSelector(ext),
                            const SizedBox(height: AppSpacing.xl),
                          ],
                          _buildFeaturesGrid(ext),
                          const SizedBox(height: AppSpacing.xl),
                          _buildQuickStats(ext),
                          const SizedBox(height: 120),
                        ];
                        return ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: sections.length,
                          itemBuilder: (context, i) =>
                              Center(child: sections[i]),
                        );
                      }),
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
      icon: Symbols.center_focus_strong_rounded,
      accent: ext.focus,
      actions: [
        AppIconButton(
          icon: Symbols.spa_rounded,
          accent: ext.success,
          tooltip: 'Relaxation',
          onPressed: () {
            _hapticService.navigation();
            Navigator.push(context, _buildPageRoute(const RelaxationScreen()));
          },
        ),
        AppIconButton(
          icon: Symbols.park_rounded,
          accent: ext.focus,
          tooltip: 'Your garden',
          onPressed: () {
            _hapticService.navigation();
            Navigator.push(context, _buildPageRoute(const FocusGardenScreen()));
          },
        ),
        AppIconButton(
          icon: Symbols.insights_rounded,
          accent: ext.info,
          tooltip: 'Statistics',
          onPressed: () {
            _hapticService.navigation();
            Navigator.push(context, _buildPageRoute(const DetailedStatsScreen()));
          },
        ),
      ],
      // Flexible so the pair shares the row instead of the second chip
      // running off the right edge at large text sizes.
      bottom: Row(
        children: [
          Flexible(
            child: AppChip(
              label: '${_focusService.stats.currentStreak} day streak',
              icon: Symbols.local_fire_department_rounded,
              selected: true,
              accent: ext.warning,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Live coin balance (FOCUS-1). Rebuilds via the merged ListenableBuilder.
          Flexible(
            child: AppChip(
              label: '${_coinsService.totalCoins} coins',
              icon: Symbols.monetization_on_rounded,
              selected: true,
              accent: ext.focus,
            ),
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

  /// Plural-correct duration in words, for spoken output only.
  ///
  /// "1 minutes remaining" is the kind of detail a sighted user never sees and a
  /// screen-reader user hears every single time.
  static String _spoken(int minutes, int seconds) {
    final parts = <String>[];
    if (minutes > 0) parts.add('$minutes minute${minutes == 1 ? '' : 's'}');
    if (seconds > 0) parts.add('$seconds second${seconds == 1 ? '' : 's'}');
    return parts.isEmpty ? 'no time' : parts.join(' ');
  }

  String _timerSemanticsLabel({
    required int idleMinutes,
    required double progress,
    required bool onBreak,
  }) {
    if (!_focusService.isRunning) {
      return _focusService.isCountUp
          // No length is selected in flow mode, so announcing one would be
          // announcing a target that does not exist.
          ? 'Flow timer, ready to start. Counts up until you stop.'
          : 'Focus timer, ready to start. '
              '${_spoken(idleMinutes, 0)} selected.';
    }
    final state = _focusService.isPaused ? ', paused' : '';
    if (_focusService.isCountUp) {
      // Elapsed, and NO percentage: a percentage needs a denominator, and the
      // only one available is the ten-hour safety cap — which would announce a
      // forty-minute session as "6 percent complete".
      final e = _focusService.elapsedSeconds;
      return 'Flow session$state. ${_spoken(e ~/ 60, e % 60)} so far.';
    }
    final total = _focusService.remainingSeconds;
    final remaining = _spoken(total ~/ 60, total % 60);
    final pct = (progress * 100).round();
    final what = onBreak ? 'Break' : 'Focus session';
    return '$what$state. $remaining remaining, $pct percent complete.';
  }

  Widget _buildTimerSection(AppColorsExt ext) {
    final progress = _focusService.progress;
    final bool isPomodoro = _focusService.mode == FocusMode.pomodoro;
    final bool onBreak = _focusService.isRunning && _focusService.isOnBreak;
    // Focus accent for work; a calmer info tone for breaks (FOCUS-2).
    final AccentSwatch accentSwatch = onBreak ? ext.info : ext.focus;
    // Idle preview shows the length of the first interval.
    final int idleMinutes =
        isPomodoro ? _focusService.workMinutes : _focusService.selectedMinutes;

    // The plant you just grew stays on screen.
    //
    // The instant the timer hit zero, `_resetSession` put progress back to 0 and
    // the plant snapped from full growth to a seed — the reward for finishing was
    // watching it undo itself. It now holds its grown form until the next session
    // begins (`startSession` clears `justCompleted`), so there is something to
    // come back to rather than an empty pot.
    //
    // State-driven, with no timer on purpose. A timed "hold for five seconds"
    // would read the same on screen and leave a pending timer behind, which is
    // both a teardown hazard for every Focus harness and one more thing to cancel
    // correctly on dispose.
    final FocusSession? lastCompleted = _focusService.justCompleted.value;
    final double plantProgress = _focusService.isRunning
        ? progress
        : (lastCompleted != null ? 1.0 : 0.0);
    final PlantType plantType =
        lastCompleted?.plantType ?? _focusService.selectedPlant;

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
            // One spoken sentence for the whole readout.
            //
            // The ring is a CustomPaint, so its progress reaches a screen reader
            // not at all, and the clock beneath it is a Text — announced
            // character by character as "two five colon zero zero". Between them
            // they are the entire point of the screen. `excludeSemantics` replaces
            // both with a sentence, the same way the medicine ring on the home
            // dashboard does it.
            //
            // Deliberately NOT a liveRegion: this rebuilds once a second, and a
            // live region would make VoiceOver interrupt itself every tick, which
            // is worse than silence on a screen whose purpose is calm.
            Semantics(
              label: _timerSemanticsLabel(
                  idleMinutes: idleMinutes, progress: progress, onBreak: onBreak),
              excludeSemantics: true,
              child: Column(
                children: [
                  ProgressRing(
                    progress: progress,
                    size: 210,
                    stroke: 12,
                    accent: accentSwatch,
                    animate: true,
                    center: PlantAnimationWidget(
                      plantType: plantType,
                      progress: plantProgress,
                      isAlive: true,
                      isAnimating: _focusService.isRunning && !onBreak,
                      size: 84,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // A clock must never wrap mid-number — at large text sizes this
                  // rendered as "25:0" / "0" on two lines. scaleDown keeps it on
                  // one.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _focusService.isRunning
                          ? _focusService.formattedTime
                          : (_focusService.isCountUp ? '00:00' : '$idleMinutes:00'),
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3,
                        color: ext.mark(accentSwatch),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  if (_focusService.isRunning) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      // Flow mode shows no percentage, for the same reason the
                      // ring stays empty: there is no target to be a percentage
                      // of, and dividing by the safety cap would report a good
                      // forty-minute session as 6% done.
                      _focusService.isCountUp
                          ? 'Counting up — stop when you\'re ready'
                          : onBreak
                              ? 'Break • ${(progress * 100).toInt()}%'
                              : '${(progress * 100).toInt()}% completed',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: ext.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ],
              ),
            ),
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
        onBreak ? Symbols.self_improvement_rounded : Symbols.center_focus_strong_rounded;
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
        label: switch (_focusService.mode) {
          FocusMode.pomodoro => 'Start Pomodoro',
          FocusMode.flow => 'Start Flow',
          FocusMode.single => 'Start Focus',
        },
        leadingIcon: Symbols.play_arrow_rounded,
        accent: ext.focus,
        size: AppButtonSize.lg,
        fullWidth: true,
        onPressed: _startSession,
      );
    }

    return Row(
      children: [
        Expanded(
          child: AppButton(
            label: _focusService.isPaused ? 'Resume' : 'Pause',
            leadingIcon: _focusService.isPaused
                ? Symbols.play_arrow_rounded
                : Symbols.pause_rounded,
            accent: accent,
            size: AppButtonSize.lg,
            fullWidth: true,
            onPressed: () {
              _hapticService.focusPause();
              _vitaVibeService.playPattern(VibePattern.doubleTap);
              if (_focusService.isPaused) {
                _focusService.resumeSession();
                FocusToast.sessionResumed(context);
              } else {
                _focusService.pauseSession();
                FocusToast.sessionPaused(context);
              }
            },
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          // In flow mode, stopping is SUCCESS — so it is a primary action, not a
          // danger one. "Give Up" would be the app disagreeing with its own
          // premise: there is no target to fall short of, so the moment the user
          // chooses to stop IS the end of the session.
          child: _focusService.isCountUp
              ? AppButton(
                  label: 'Done',
                  leadingIcon: Symbols.check_rounded,
                  accent: ext.focus,
                  size: AppButtonSize.lg,
                  fullWidth: true,
                  onPressed: _finishFlowSession,
                )
              : AppButton(
                  label: 'Give Up',
                  leadingIcon: Symbols.close_rounded,
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

  // ---------------------------------------------------------------------------
  // Session setup — one row at rest, the detail in a sheet
  // ---------------------------------------------------------------------------

  /// Everything the next session will do, in one line.
  ///
  /// The point of collapsing six sections into a sheet is only defensible if the
  /// user can still SEE what they are about to start without opening it.
  /// Otherwise this is not a tidier screen, it is a hidden one.
  String _setupSummary() {
    // The intention leads when there is one: it is the only part of the setup
    // that says what the session is FOR, and the whole justification for hiding
    // six sections behind a sheet is that the user can still see what they are
    // about to start without opening it.
    final intention = _focusService.pendingIntention;
    final parts = <String>[
      if (intention != null) '“$intention”',
      if (_focusService.mode == FocusMode.pomodoro)
        'Pomodoro ${_focusService.workMinutes}/${_focusService.shortBreakMinutes}'
      else
        'Single session',
      _focusService.selectedActivity.name,
      if (_focusService.selectedSound == AmbientSoundType.none)
        'no sound'
      else
        _focusService.selectedSound.name.toLowerCase(),
    ];
    final tags = _focusService.selectedTagIds.length;
    if (tags > 0) parts.add('$tags tag${tags == 1 ? '' : 's'}');
    return parts.join(' · ');
  }

  /// The intention field. One optional line: what are you working on?
  ///
  /// An implementation intention — naming the task before starting — is the
  /// best-supported mechanism in the behaviour-change literature this feature
  /// draws on, and it costs one text field because `FocusSession.note` already
  /// existed, already persisted and already rode the backup. It just had nothing
  /// writing to it.
  ///
  /// Optional, and never pre-filled from last time: turning the decision into a
  /// default is exactly how the mechanism stops working.
  Widget _buildIntentionField(AppColorsExt ext) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
              title: 'Intention',
              icon: Symbols.edit_note_rounded,
              accent: ext.focus),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: _intentionController,
            hint: 'What are you working on? (optional)',
            accent: ext.focus,
            maxLines: 1,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onChanged: _focusService.setIntention,
          ),
        ],
      ),
    );
  }

  /// "How did that go?" — three chips, once, after a session.
  ///
  /// A subjective rating is the one new metric worth collecting, and it earns its
  /// place specifically because this is a health app: *"sessions after a short
  /// night feel harder"* is the user's own report about their own day, which is a
  /// far more defensible correlation input than minutes, and nothing like the app
  /// inferring something about their brain.
  ///
  /// Inline and skippable rather than a modal. A form standing between the user
  /// and their finished session would turn the one moment in this feature that
  /// should feel good into paperwork — and an unanswered rating is a fine
  /// outcome, whereas a dialog you must dismiss is not.
  Widget _buildSessionReview(AppColorsExt ext) {
    final session = _focusService.justCompleted.value;
    if (session == null ||
        session.id == _reviewedSessionId ||
        session.quality != null) {
      return const SizedBox.shrink();
    }

    // 0 = went well … 2 = struggled. Lower is better, matching the mood index the
    // correlation engine is already written against; a second, opposite scale
    // convention is how sign errors ship.
    const options = [
      (0, 'Went well', Symbols.sentiment_satisfied_rounded),
      (1, 'Mixed', Symbols.sentiment_neutral_rounded),
      (2, 'Struggled', Symbols.sentiment_dissatisfied_rounded),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('How did that go?',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                AppIconButton(
                  icon: Symbols.close_rounded,
                  tooltip: 'Skip',
                  accent: ext.focus,
                  onPressed: () =>
                      setState(() => _reviewedSessionId = session.id),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final (value, label, icon) in options)
                  AppChip(
                    label: label,
                    icon: icon,
                    accent: ext.focus,
                    onTap: () async {
                      _hapticService.selection();
                      await _focusService.setLastSessionQuality(value);
                      if (!mounted) return;
                      setState(() => _reviewedSessionId = session.id);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// "Start with a few breaths" — off by default.
  ///
  /// `BreathingWidget` already existed with real patterns and was already
  /// reachable from the More grid. This offers it at the one moment it is a way
  /// IN rather than a separate activity.
  ///
  /// Nothing is claimed for it. one sec's 57% is friction placed before the
  /// distraction, not before the work, and borrowing that number for a calm
  /// on-ramp would be exactly the kind of unsupported claim the guard test bans
  /// elsewhere in this feature.
  Widget _buildPrerollToggle(AppColorsExt ext) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: SettingsSection(
        children: [
          SettingsTile(
            icon: Symbols.air_rounded,
            title: 'Start with a few breaths',
            subtitle: 'A short breathing exercise before the timer',
            accent: ext.focus,
            switchValue: _focusService.breathingPreroll,
            onSwitchChanged: (v) {
              _hapticService.toggle();
              _focusService.setBreathingPreroll(v);
            },
          ),
        ],
      ),
    );
  }

  /// Finish a flow session and offer the proportional break.
  ///
  /// The break is the Flowtime rule — focused time ÷ 5, clamped 5–30 — and it is
  /// OFFERED, never started. Auto-starting it would put a timer back in charge of
  /// deciding when the user's attention is finished, which is the one thing this
  /// mode exists to stop doing.
  Future<void> _finishFlowSession() async {
    final minutes = _focusService.elapsedSeconds ~/ 60;
    await _focusService.stopFlowSession();
    if (!mounted || minutes < 1) return;

    final rest = FocusService.suggestedBreakMinutes(minutes);
    FocusToast.breakReminder(
      context,
      action: ToastAction(
        label: 'Start $rest min',
        onPressed: () {
          _focusService.setMode(FocusMode.single);
          _focusService.setDuration(rest);
          _startSession();
        },
      ),
    );
  }

  /// Start a session, optionally after a few breaths.
  ///
  /// The pre-roll runs BEFORE `startSession()`, never during: the timer is
  /// anchored to an absolute end time, so starting it and then covering the
  /// screen with a breathing exercise would silently spend the first minute of
  /// the session on breathing. Closing the exercise early still starts the
  /// session — the user asked for a session, and a skipped ritual must not
  /// swallow the action.
  void _startSession() {
    if (_focusService.breathingPreroll && !_showBreathing) {
      setState(() {
        // `balancing` is 4-4-4-4 box breathing: symmetrical, so there is no
        // "wrong" half to land on if the user skips out mid-cycle, and it neither
        // winds down (relaxing/calming) nor winds up (energizing) — which is the
        // right shape for the thirty seconds before work.
        _selectedBreathingPattern = BreathingPattern.balancing;
        _showBreathing = true;
        _prerollThenStart = true;
        _breathingStartedAt = DateTime.now();
      });
      return;
    }
    _hapticService.focusStart();
    _vitaVibeService.focusStart();
    _focusService.startSession();
    FocusToast.sessionStarted(context,
        minutes: _focusService.mode == FocusMode.pomodoro
            ? _focusService.workMinutes
            : _focusService.selectedMinutes);
  }

  Widget _buildSessionSetupRow(AppColorsExt ext) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        onTap: () {
          _hapticService.selection();
          _showSessionSetupSheet(ext);
        },
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: ext.focus.container,
                borderRadius: AppRadius.brSm,
              ),
              child: Icon(Symbols.tune_rounded,
                  color: ext.focus.onContainer, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Session setup',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    _setupSummary(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ext.textSecondary,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Symbols.chevron_right_rounded, color: ext.textTertiary, size: 22),
          ],
        ),
      ),
    );
  }

  /// Mode, pomodoro config, activity, tags, plant and sound.
  ///
  /// Reuses the existing section builders verbatim rather than reimplementing
  /// them for the sheet — the same widgets, in a place the user opts into. The
  /// inner [ListenableBuilder] is load-bearing: a modal sheet is its own route,
  /// so the screen's own listener does not rebuild it and every selection would
  /// appear to do nothing until it was reopened.
  void _showSessionSetupSheet(AppColorsExt ext) {
    AppBottomSheet.show(
      context,
      title: 'Session setup',
      icon: Symbols.tune_rounded,
      accent: ext.focus,
      builder: (_) => ListenableBuilder(
        listenable: Listenable.merge([_focusService, _tagService]),
        builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // First, because it is the only decision here about the WORK rather
            // than about the timer.
            _buildIntentionField(ext),
            const SizedBox(height: AppSpacing.lg),
            _buildPrerollToggle(ext),
            const SizedBox(height: AppSpacing.xl),
            _buildModeToggle(ext),
            const SizedBox(height: AppSpacing.xl),
            if (_focusService.mode == FocusMode.pomodoro) ...[
              _buildPomodoroConfig(ext),
              const SizedBox(height: AppSpacing.xl),
            ],
            _buildActivitySelector(ext),
            const SizedBox(height: AppSpacing.xl),
            _buildTagSelector(ext),
            const SizedBox(height: AppSpacing.xl),
            _buildPlantSelector(ext),
            const SizedBox(height: AppSpacing.xl),
            _buildSoundSelector(ext),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  /// The breathing patterns, on demand.
  ///
  /// Was a permanent horizontal strip on the resting screen. Choosing a pattern
  /// pops the sheet first: `_showBreathing` swaps the whole Scaffold body, and
  /// leaving a modal route over that swap strands the user on a breathing
  /// exercise behind a sheet they have to dismiss to reach.
  void _showBreathingSheet(AppColorsExt ext) {
    AppBottomSheet.show(
      context,
      title: 'Breathing',
      icon: Symbols.air_rounded,
      accent: ext.focus,
      builder: (_) => _buildBreathingSection(ext),
    );
  }

  Widget _buildModeToggle(AppColorsExt ext) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: SegmentedToggle(
        accent: ext.focus,
        index: _focusService.mode.index,
        onChanged: (i) {
          // No haptic here: SegmentedToggle already fires one on tap, so this
          // produced TWO buzzes per switch — the documented "feels glitchy"
          // generator in docs/perf-rating.md.
          _focusService.setMode(FocusMode.values[i]);
        },
        items: const [
          SegmentItem(icon: Symbols.timer_rounded, label: 'Single'),
          SegmentItem(icon: Symbols.repeat_rounded, label: 'Pomodoro'),
          SegmentItem(icon: Symbols.waves_rounded, label: 'Flow'),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // AI focus coach
  // ---------------------------------------------------------------------------

  /// Self-loading AI card offering one short, actionable focus suggestion based
  /// on real stats. Always available via the free on-device rule engine.
  /// Every session, in the shape the pure insight functions want.
  List<FocusSessionRef> _sessionRefs() => _focusService.sessions
      .map((s) => FocusSessionRef(
          startHour: s.startedAt.hour,
          minutes: s.actualMinutes,
          completed: s.wasCompleted))
      .toList();

  /// The one contextual line, and it has to sit ABOVE THE FOLD.
  ///
  /// This was a `TipCard` — icon, "Focus coach" title, padding, ~110pt — placed
  /// after the setup row. On a 375x812 phone that put it off the bottom of a lazy
  /// `ListView`, so it was never even built: a brand-new user got a Start button
  /// and no suggestion of what to do with it. The first-run gate in
  /// `focus_first_run_test.dart` caught exactly that, reporting one "start" string
  /// on the whole screen — the button's own label.
  ///
  /// So it is now what the plan actually asked for: one line. A plain centred
  /// `Text` costs ~40pt instead of ~110, which is what lets it fit under the ring
  /// and the duration chips with the setup row still on screen.
  Widget _buildCoachLine(AppColorsExt ext, int? bestHour, int? suggested) {
    final readiness = _readiness(suggested);
    final line = const CoachText().focusCoach(
      todayMinutes: _focusService.todayMinutes,
      streakDays: _focusService.stats.currentStreak,
      totalSessions: _focusService.stats.totalSessions,
      // All three were already computed and none reached the user: the grace
      // day was discarded by `_checkAndUpdateStreak`, and the best hour was
      // visible only several taps deep inside Statistics.
      usedGraceDay: _focusService.streakUsedGrace,
      bestHour: bestHour,
      suggestedMinutes: suggested,
      readiness: readiness,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        children: [
          Text(
            line,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ext.textSecondary,
                  height: 1.35,
                ),
          ),
          // The `why` chip only appears when a readiness signal is what is being
          // shown. Every other coach line is about the user's own focus history,
          // which they can see; this one is the only one asserting something from
          // another feature's data, so it is the only one that owes an
          // explanation.
          if (readiness != null && line == readiness.line) ...[
            const SizedBox(height: AppSpacing.sm),
            WhyThisChip(why: readiness.why),
          ],
        ],
      ),
    );
  }

  /// Today's readiness note, or null.
  ///
  /// Reads the biometrics the user has already synced. Every input is optional
  /// and every threshold has a minimum history, so on a phone with no wearable
  /// this returns null and the coach line is exactly what it was before.
  ///
  /// Wrapped whole in a try/catch: a focus screen must never fail to build
  /// because a health read went wrong.
  FocusReadinessNote? _readiness(int? suggested) {
    try {
      final nights = SleepService.getAllSessions();
      int? lastNight;
      int? medianSleep;
      if (nights.isNotEmpty) {
        lastNight = nights.first.asleepMinutes;
        // Median over the last fourteen logged nights, and only LOGGED ones —
        // zero-filling a missing night would invent a sleepless one and drag the
        // baseline down, which is the defect `SleepService.sleepDebtMinutes`
        // already documents for its own average.
        final recent = nights.take(14).map((n) => n.asleepMinutes).toList()
          ..sort();
        if (recent.isNotEmpty) {
          final mid = recent.length ~/ 2;
          medianSleep = recent.length.isOdd
              ? recent[mid]
              : ((recent[mid - 1] + recent[mid]) / 2).round();
        }
      }

      final hrv = BiometricsService.hrvBaseline();
      final hrvSeries = BiometricsService.hrvTrend(days: 14, metric: hrv.metric);
      final rhr = BiometricsService.restingHrTrend(days: 14);
      final rhrValues = rhr.map((e) => e.bpm).toList()..sort();
      int? rhrMedian;
      if (rhrValues.isNotEmpty) {
        final mid = rhrValues.length ~/ 2;
        rhrMedian = rhrValues.length.isOdd
            ? rhrValues[mid]
            : ((rhrValues[mid - 1] + rhrValues[mid]) / 2).round();
      }

      return FocusReadiness.assess(
        lastNightMinutes: lastNight,
        sleepMedianMinutes: medianSleep,
        loggedNights: nights.take(14).length,
        hrvLastNightMs: hrvSeries.isEmpty ? null : hrvSeries.last.ms,
        hrvBaselineMs: hrv.ms,
        hrvNights: hrv.nights,
        // `hrvBaseline` resolves ONE metric and `hrvTrend` is restricted to it,
        // so the series cannot mix RMSSD and SDNN — which would invent a step
        // change out of a unit difference.
        hrvMetricConsistent: hrv.metric != null,
        restingHr: rhr.isEmpty ? null : rhr.last.bpm,
        restingHrMedian: rhrMedian,
        rhrDays: rhr.length,
        restingHrDerived: rhr.isEmpty ? true : rhr.last.derived,
        suggestedMinutes: suggested,
      );
    } catch (e) {
      debugPrint('Focus readiness unavailable: $e');
      return null;
    }
  }

  /// The deterministic best-hour / completion-rate insight, when there is one.
  ///
  /// Stays below the setup row: it is a reflection on history, not the thing a
  /// user came to the screen to do, and `InsightEngine.focus` returns null until
  /// there is enough data — so on a fresh install this renders nothing at all.
  Widget _buildFocusInsight(AppColorsExt ext, List<FocusSessionRef> refs,
      int? bestHour, int? suggested) {
    final insight = InsightEngine.focus(
      bestFocusHour: bestHour,
      completionRate: FocusInsights.completionRate(refs),
      sessionCount: refs.length,
      streakDays: _focusService.stats.currentStreak,
      suggestedMinutes: suggested,
    );
    if (insight == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: InsightCard(
        insight: insight,
        // The card renders the button only when BOTH an actionLabel and this
        // callback are present, so an insight with no sensible action here simply
        // stays a statement.
        onAction: _insightAction(insight, suggested, bestHour),
      ),
    );
  }

  /// What the insight's button does, or null if it should not be offered.
  ///
  /// Deliberately resolved by insight `id` rather than by rank or position: the
  /// engine is free to reorder or add insights, and a positional mapping would
  /// silently attach the wrong action to a new one.
  VoidCallback? _insightAction(
      Insight insight, int? suggested, int? bestHour) {
    switch (insight.id) {
      case 'focus_completion':
        if (suggested == null) return null;
        return () {
          _hapticService.selection();
          _focusService.setDuration(suggested);
          FocusToast.activitySaved(context,
              activityName: 'Duration set to ${suggested}m');
        };
      case 'focus_besthour':
        if (bestHour == null) return null;
        return () {
          _hapticService.navigation();
          Navigator.push(
              context, _buildPageRoute(const FocusRemindersSettingsScreen()));
        };
      default:
        return null;
    }
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
            icon: Symbols.repeat_rounded,
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

  /// Duration chips, led by the length this user actually finishes.
  ///
  /// [suggested] is `FocusInsights.suggestedMinutes` — the MEDIAN of completed
  /// sessions only, null under five of them. The app already computed it and said
  /// it in prose in the coach line, while the selector still defaulted to whatever
  /// was last persisted. So it was telling people their real session length and
  /// then not offering it.
  ///
  /// Offered, never applied. Silently changing the number the user chose is the
  /// coercion pattern this feature rejects everywhere else, and it would also
  /// make the suggestion unfalsifiable — you could never tell whether you picked
  /// 20 or the app did.
  Widget _buildDurationSelector(AppColorsExt ext, int? suggested) {
    const durations = [5, 10, 15, 25, 30, 45, 60, 90];
    final selected = _focusService.selectedMinutes;
    final isCustom = !durations.contains(selected);
    // Only worth a chip when it would actually change something: below five
    // minutes of difference this is noise competing with the real controls.
    final showUsual = suggested != null && (suggested - selected).abs() >= 5;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: 'Duration', icon: Symbols.timer_rounded, accent: ext.focus),
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                if (showUsual) ...[
                  AppChip(
                    label: 'Your usual · ${suggested}m',
                    icon: Symbols.insights_rounded,
                    accent: ext.focus,
                    onTap: () {
                      _hapticService.selection();
                      _focusService.setDuration(suggested);
                    },
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                for (final mins in durations) ...[
                  AppChip(
                    label: '$mins min',
                    selected: selected == mins,
                    accent: ext.focus,
                    onTap: () {
                      _hapticService.selection();
                      _focusService.setDuration(mins);
                    },
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                AppChip(
                  label: isCustom ? '$selected min' : 'Custom',
                  icon: Symbols.tune_rounded,
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
      icon: Symbols.tune_rounded,
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
                  prefixIcon: Symbols.timer_rounded,
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
          SectionHeader(title: 'Activity', icon: Symbols.category_rounded, accent: ext.focus),
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
            icon: Symbols.label_rounded,
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
              Icon(Symbols.check_rounded, size: 15, color: tagColor),
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
                  icon: Symbols.local_florist_rounded,
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
            // The tile is emoji + label, so the strip has to follow the text
            // scale: at 1.3x a flat 122 clips the label off the bottom.
            height: MediaQuery.textScalerOf(context).scale(122).clamp(122.0, 244.0),
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
            icon: Symbols.music_note_rounded,
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
                      ? Symbols.pause_rounded
                      : Symbols.play_arrow_rounded,
                  accent: ext.focus,
                  tooltip: _focusService.isAudioPlaying
                      ? 'Pause ambient sound'
                      : 'Play ambient sound',
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
          // No SectionHeader: the sheet that hosts this already has the title.
          SizedBox(
            // Each card is an icon plus a two-line pattern name, so the strip
            // has to follow the text scale exactly like the plant strip above:
            // a flat 112 clips the second label line at 200% text.
            height: MediaQuery.textScalerOf(context).scale(112).clamp(112.0, 260.0),
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
                        // Dismiss the sheet before swapping the Scaffold body,
                        // or the exercise starts underneath a modal route.
                        Navigator.pop(context);
                        setState(() {
                          _selectedBreathingPattern = pattern;
                          _showBreathing = true;
                          _breathingStartedAt = DateTime.now();
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
            icon: Symbols.trending_up_rounded,
            accent: ext.focus,
            actionLabel: 'View All',
            onAction: () => Navigator.push(
                context, _buildPageRoute(const DetailedStatsScreen())),
          ),
          const SizedBox(height: AppSpacing.sm),
          StatTileRow(
            tiles: [
              StatTile(
                icon: Symbols.timer_rounded,
                value: '${_focusService.todayMinutes}',
                label: 'Minutes',
                accent: ext.info,
              ),
              StatTile(
                icon: Symbols.local_florist_rounded,
                value: '${_focusService.todayPlants.length}',
                label: 'Plants',
                accent: ext.success,
              ),
              StatTile(
                icon: Symbols.local_fire_department_rounded,
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
          SectionHeader(title: 'More', icon: Symbols.apps_rounded, accent: ext.focus),
          const SizedBox(height: AppSpacing.sm),
          // Six cards, three rows. Breathing and Relaxation joined the grid when
          // they came off the resting surface: a permanent horizontal pattern
          // strip and a full-width promo card, for things a user reaches for
          // occasionally and on purpose.
          //
          // Built as pairs of Expanded rows rather than a GridView so every card
          // keeps the same width and the whole grid stays intrinsically sized
          // inside the parent ListView.
          ..._featureRows(ext),
        ],
      ),
    );
  }

  List<Widget> _featureRows(AppColorsExt ext) {
    final cards = <Widget>[
      _buildFeatureCard(
        ext,
        emoji: '🌬️',
        title: 'Breathing',
        subtitle: 'Wind down',
        accent: ext.focus,
        onTap: () => _showBreathingSheet(ext),
      ),
      _buildFeatureCard(
        ext,
        emoji: '🧘',
        title: 'Relaxation',
        subtitle: 'Ambient sound',
        accent: ext.success,
        onTap: () {
          _hapticService.navigation();
          _vitaVibeService.tap();
          Navigator.push(context, _buildPageRoute(const RelaxationScreen()));
        },
      ),
      _buildFeatureCard(
        ext,
        emoji: '📊',
        title: 'Statistics',
        subtitle: 'Your trends',
        accent: ext.info,
        onTap: () => Navigator.push(
            context, _buildPageRoute(const DetailedStatsScreen())),
      ),
      _buildFeatureCard(
        ext,
        emoji: '🌍',
        title: 'Plant Trees',
        subtitle: '${_coinsService.totalCoins} coins',
        accent: ext.success,
        onTap: () => Navigator.push(
            context, _buildPageRoute(const PlantRealTreesScreen())),
      ),
      _buildFeatureCard(
        ext,
        emoji: '🏷️',
        title: 'Tags',
        subtitle: 'Organise',
        accent: ext.reminders,
        onTap: () =>
            Navigator.push(context, _buildPageRoute(const CustomTagsScreen())),
      ),
      _buildFeatureCard(
        ext,
        emoji: '📱',
        title: 'Distractions',
        subtitle: 'What pulls you',
        accent: ext.focus,
        onTap: () => Navigator.push(
            context, _buildPageRoute(const AppAllowListScreen())),
      ),
    ];

    final rows = <Widget>[];
    for (var i = 0; i < cards.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: AppSpacing.md));
      // `IntrinsicHeight` is what equalises the pair, and it is required.
      //
      // Without it the cards size independently and the geometry gate measures
      // real drift — 189pt beside 169pt, 147pt beside 189pt — as soon as a title
      // like "Plant Trees" wraps and "Statistics" does not. A short card next to a
      // tall one reads as broken.
      //
      // `stretch` is kept to state the intent, but it is NOT what fixes this:
      // removing it on its own leaves the gate green, because IntrinsicHeight
      // already gives the Row a tight height. It also cannot be used WITHOUT
      // IntrinsicHeight — stretch needs a bounded cross axis, and a Row inside a
      // ListView item has unbounded height, so it throws a layout assertion that
      // a harness suppressing FlutterError turns into an unlaid-out sliver and
      // then a framework null-check crash in `debugVisitOnstageChildren`.
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: cards[i]),
            const SizedBox(width: AppSpacing.md),
            if (i + 1 < cards.length)
              Expanded(child: cards[i + 1])
            else
              const Expanded(child: SizedBox.shrink()),
          ],
        ),
      ));
    }
    return rows;
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
    // The stated intention replaces the generic line while a work interval runs.
    //
    // This is the half of the intention mechanism that does the work: naming the
    // task before starting is a plan, and seeing it on screen while the timer
    // runs is what makes it a commitment rather than a form field. "Stay focused!
    // Your plant is growing..." is the fallback, not the default.
    final String? intention = _focusService.pendingIntention;
    final String subtitle = onBreak
        ? 'Relax and recharge — focus resumes soon.'
        : (intention ?? 'Stay focused! Your plant is growing...');
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
                    onBreak ? Symbols.self_improvement_rounded : Symbols.lock_rounded,
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
                        Icon(Symbols.pause_circle_rounded,
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
      icon: Symbols.music_note_rounded,
      accent: AppColorsExt.of(context).focus,
      builder: (ctx) => AmbientSoundSelector(
        selectedSound: _focusService.selectedSound,
        volume: _focusService.soundVolume,
        onSoundChanged: (sound) {
          _focusService.setSound(sound);
          Navigator.pop(ctx);
        },
        onVolumeChanged: (volume) {
          _focusService.setSoundVolume(volume, persist: false);
        },
        onVolumeCommitted: (volume) {
          _focusService.setSoundVolume(volume);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dialogs
  // ---------------------------------------------------------------------------

  /// The abandon confirmation, with an optional "what pulled you away?".
  ///
  /// The attribution lives INSIDE this dialog rather than as a step after it.
  /// Someone pressing Give Up wants out, and interposing a second screen at
  /// exactly that moment is friction aimed at the wrong thing — the app's whole
  /// stance is that failure should be one deliberate press, not a punishment.
  /// Optional chips add nothing to that press and still capture the single most
  /// useful data point in the feature: which distraction actually won.
  ///
  /// Logged BEFORE `abandonSession()`, because the tally is copied onto the
  /// session record as it is written. Afterwards there would be nothing to
  /// attach it to.
  void _showAbandonDialog() {
    final ext = AppColorsExt.of(context);
    final distractions = _loadDistractionOptions();
    String? blamed;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
        backgroundColor: ext.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brSheet),
        title: const Row(
          children: [
            Text('🥀', style: TextStyle(fontSize: 28)),
            SizedBox(width: 12),
            Text('Give up?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your plant will wither if you stop now. Are you sure you want to abandon this session?',
              style: Theme.of(dialogCtx)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: ext.textSecondary),
            ),
            if (distractions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Text('What pulled you away? (optional)',
                  style: Theme.of(dialogCtx).textTheme.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final d in distractions)
                    AppChip(
                      label: d.name,
                      selected: blamed == d.id,
                      accent: ext.focus,
                      onTap: () {
                        _hapticService.selection();
                        setDialogState(
                            () => blamed = blamed == d.id ? null : d.id);
                      },
                    ),
                ],
              ),
            ],
          ],
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
              // Before abandoning: the tally is copied onto the session record as
              // it is written, so this is the last moment it can land.
              if (blamed != null) _focusService.logDistraction(blamed!);
              _focusService.abandonSession();
              _showCompletionSnackbar('Session abandoned. Your plant has withered 🥀');
            },
          ),
        ],
        ),
      ),
    );
  }

  /// The user's own distraction list, for the abandon dialog.
  ///
  /// Read straight from the preference the Distractions screen writes rather than
  /// held in state: this screen does not otherwise care about that list, and a
  /// second in-memory copy would be one more thing that can go stale.
  List<AllowedApp> _loadDistractionOptions() {
    try {
      final raw = CleanStorageService.getAppPreferences()['focusAppAllowList'];
      if (raw is! Map) return const [];
      return AppAllowList.fromJson(Map<String, dynamic>.from(raw)).apps;
    } catch (_) {
      return const [];
    }
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
            Icon(Symbols.lock_rounded, color: ext.mark(ext.warning), size: 28),
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
