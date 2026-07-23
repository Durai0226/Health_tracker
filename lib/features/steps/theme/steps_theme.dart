import 'package:flutter/material.dart';
import 'package:tablet_remainder/core/design/app_colors_ext.dart';

/// The goal-progress band a day's activity falls into. Drives the ring/chart
/// tone so a glance reads intent without relying on numbers alone.
enum StepBand {
  /// Nothing (or almost nothing) logged yet.
  idle,

  /// On the way but under goal.
  building,

  /// Close to goal (>= 75%).
  almost,

  /// Goal reached (100%+).
  reached,

  /// Well past goal (>= 150%).
  crushing,
}

/// Steps colour language, derived entirely from design tokens (no raw hex, dark
/// and light correct). The steps accent carries "building"; success carries
/// "reached / crushing"; a muted outline carries "idle".
class StepsTheme {
  StepsTheme._();

  static StepBand bandFor(double progress) {
    if (progress <= 0.02) return StepBand.idle;
    if (progress >= 1.5) return StepBand.crushing;
    if (progress >= 1.0) return StepBand.reached;
    if (progress >= 0.75) return StepBand.almost;
    return StepBand.building;
  }

  /// AA-safe mark colour for the given [progress] band, drawn on app/card
  /// surfaces (rings, bars, numerals).
  static Color bandColor(AppColorsExt ext, double progress) {
    switch (bandFor(progress)) {
      case StepBand.idle:
        return ext.textTertiary;
      case StepBand.building:
      case StepBand.almost:
        return ext.mark(ext.steps);
      case StepBand.reached:
      case StepBand.crushing:
        return ext.mark(ext.success);
    }
  }

  /// The lighter tone for the second-lap (over-achievement) arc.
  static Color overflowColor(AppColorsExt ext) =>
      ext.success.base.withValues(alpha: ext.isDark ? 0.55 : 0.45);

  /// Subtle track behind the ring/bars.
  static Color trackColor(AppColorsExt ext) => ext.steps.container;

  /// Short band label for chips / accessibility.
  static String bandLabel(double progress) {
    switch (bandFor(progress)) {
      case StepBand.idle:
        return 'Just getting started';
      case StepBand.building:
        return 'Building momentum';
      case StepBand.almost:
        return 'Almost there';
      case StepBand.reached:
        return 'Goal reached';
      case StepBand.crushing:
        return 'Crushing it';
    }
  }
}
