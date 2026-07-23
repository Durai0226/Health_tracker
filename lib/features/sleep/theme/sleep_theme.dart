import 'package:flutter/widgets.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import '../models/sleep_stage.dart';

/// Token-derived colours for the four sleep stages, resolved for the current
/// brightness. Kept inside the Calm Clarity contract (accents + lerps between
/// tokens only — no hard-coded hues), so the hypnogram reads correctly in both
/// light and dark.
///
/// - deep  → the strong sleep indigo (the anchor colour)
/// - light → sleep indigo lifted toward the surface (a paler indigo)
/// - rem   → the info accent (a distinct blue-cyan)
/// - awake → the warning accent (amber; awake-in-bed reads as a soft caution)
class SleepStageColors {
  final Color awake;
  final Color light;
  final Color deep;
  final Color rem;

  const SleepStageColors({
    required this.awake,
    required this.light,
    required this.deep,
    required this.rem,
  });

  factory SleepStageColors.of(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final deep = ext.mark(ext.sleep);
    return SleepStageColors(
      deep: deep,
      light: Color.lerp(deep, ext.surface, ext.isDark ? 0.42 : 0.5)!,
      rem: ext.mark(ext.info),
      awake: ext.mark(ext.warning),
    );
  }

  Color forStage(SleepStage stage) {
    switch (stage) {
      case SleepStage.awake:
        return awake;
      case SleepStage.light:
        return light;
      case SleepStage.deep:
        return deep;
      case SleepStage.rem:
        return rem;
    }
  }
}
