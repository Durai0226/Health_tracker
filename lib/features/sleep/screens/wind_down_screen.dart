import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import '../../focus/models/breathing_exercise.dart';
import '../../focus/models/relaxation_music.dart';
import '../../focus/screens/relaxation_screen.dart';
import '../../focus/services/focus_service.dart';
import '../../focus/services/relaxation_service.dart';
import '../../focus/widgets/breathing_widget.dart';
import '../services/wind_down_link.dart';

/// Wind down in one tap: a short 4-7-8 breath, a low steady sound for twenty
/// minutes, and then quiet.
///
/// Opened from the Sleep screen and from the wind-down reminder. It chains what
/// the Focus and Relaxation features already do; nothing here is new audio or a new
/// kind of session, so what they record (a breathing exercise in the history, a
/// session in Relaxation) is recorded the same way.
class WindDownScreen extends StatefulWidget {
  const WindDownScreen({super.key});

  @override
  State<WindDownScreen> createState() => _WindDownScreenState();
}

class _WindDownScreenState extends State<WindDownScreen> {
  bool _breathing = false;
  bool _starting = false;
  DateTime? _breathingStartedAt;

  /// The sound is offered only while the track has audio behind it, and never on top
  /// of a relaxation session that is already playing.
  bool get _soundAvailable =>
      AudioService.hasRelaxationAudio(WindDownRoutine.track.assetKey);

  bool get _alreadyPlaying => RelaxationService().isRunning;

  void _startBreathing() {
    setState(() {
      _breathing = true;
      _breathingStartedAt = clock.now();
    });
  }

  Future<void> _breathingDone() async {
    final focus = FocusService();
    focus.incrementBreathingCount(
      pattern: WindDownRoutine.pattern,
      cycles: WindDownRoutine.pattern.recommendedCycles,
    );
    final started = _breathingStartedAt;
    if (started != null) {
      focus.writeBreathingMindfulness(start: started, end: clock.now());
    }
    _breathingStartedAt = null;
    await _startSound();
  }

  /// Closed part-way: nothing is recorded (a part of an exercise is not a practice)
  /// and nothing starts. Someone who stopped breathing has not asked for a sound.
  void _breathingClosed() {
    _breathingStartedAt = null;
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _startSound() async {
    if (_starting) return;
    _starting = true;
    final navigator = Navigator.of(context);
    if (_soundAvailable && !_alreadyPlaying) {
      final relax = RelaxationService();
      await relax.init();
      if (!relax.isRunning) {
        relax.setMusic(WindDownRoutine.track);
        relax.setDuration(WindDownRoutine.soundMinutes);
        await relax.startSession();
        if (!mounted) return;
        // The running session, where it can be paused or ended.
        await navigator.pushReplacement(MaterialPageRoute<void>(
            builder: (_) => const RelaxationScreen()));
        return;
      }
    }
    if (!mounted) return;
    _starting = false;
    if (_breathing) {
      setState(() => _breathing = false);
      context.toastInfo('Breathing exercise completed.');
    }
    navigator.maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;

    if (_breathing) {
      return AccentScope(
        feature: FeatureAccent.sleep,
        child: Scaffold(
          backgroundColor: ext.background,
          body: BreathingWidget(
            pattern: WindDownRoutine.pattern,
            targetCycles: WindDownRoutine.pattern.recommendedCycles,
            onComplete: _breathingDone,
            onClose: _breathingClosed,
          ),
        ),
      );
    }

    final minutes = WindDownRoutine.breathingMinutes;
    return AccentScope(
      feature: FeatureAccent.sleep,
      child: AppScaffold(
        body: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            AppHeader(
              title: 'Wind down',
              leading: AppHeader.backButton(context),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Step(
                          icon: Symbols.air_rounded,
                          title: '4-7-8 breathing',
                          detail: 'Breathe in for 4, hold for 7, out for 8. '
                              'About ${minutes == 1 ? 'a minute' : '$minutes minutes'}.',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (_alreadyPlaying)
                          const _Step(
                            icon: Symbols.music_note_rounded,
                            title: 'Your relaxation session',
                            detail: 'One is already playing, so it carries on '
                                'as it is.',
                          )
                        else if (_soundAvailable)
                          _Step(
                            icon: Symbols.music_note_rounded,
                            title: WindDownRoutine.track.name,
                            detail: 'A low, steady sound for '
                                '${WindDownRoutine.soundMinutes} minutes.',
                          ),
                        if (_soundAvailable || _alreadyPlaying)
                          const SizedBox(height: AppSpacing.md),
                        const _Step(
                          icon: Symbols.volume_off_rounded,
                          title: 'Then quiet',
                          detail: 'When it ends, nothing else plays.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'Start',
                    leadingIcon: Symbols.play_arrow_rounded,
                    fullWidth: true,
                    onPressed: _startBreathing,
                  ),
                  if (_soundAvailable && !_alreadyPlaying) ...[
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      label: 'Skip the breathing',
                      variant: AppButtonVariant.ghost,
                      fullWidth: true,
                      onPressed: _startSound,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'A way to settle before bed, not a treatment. Stop at any '
                    'time.',
                    textAlign: TextAlign.center,
                    style: tt.bodySmall?.copyWith(color: ext.textTertiary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.title, required this.detail});

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ext.sleep.container,
            borderRadius: AppRadius.brSm,
          ),
          child: Icon(icon, size: 20, color: ext.sleep.onContainer),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: tt.titleMedium),
              const SizedBox(height: 2),
              Text(detail,
                  style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}
