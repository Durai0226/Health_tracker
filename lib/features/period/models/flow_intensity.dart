import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Menstrual flow level. The index maps 1:1 to the persisted `flowIndex`
/// column on `PeriodDays` (0 = none … 4 = heavy), so ordering is load-bearing.
enum FlowIntensity { none, spotting, light, medium, heavy }

extension FlowIntensityX on FlowIntensity {
  /// The persisted integer (== [Enum.index]).
  int get flowIndex => index;

  String get label {
    switch (this) {
      case FlowIntensity.none:
        return 'None';
      case FlowIntensity.spotting:
        return 'Spotting';
      case FlowIntensity.light:
        return 'Light';
      case FlowIntensity.medium:
        return 'Medium';
      case FlowIntensity.heavy:
        return 'Heavy';
    }
  }

  /// Segment glyph. The bleeding levels form an intentional, distinct ramp
  /// (drop → medium → full) so no two adjacent levels share a glyph; None is a
  /// block to read as "no flow".
  IconData get icon {
    switch (this) {
      case FlowIntensity.none:
        return Symbols.block_rounded;
      case FlowIntensity.spotting:
        return Symbols.circle_rounded;
      case FlowIntensity.light:
        return Symbols.water_drop_rounded;
      case FlowIntensity.medium:
        return Symbols.water_medium_rounded;
      case FlowIntensity.heavy:
        return Symbols.water_full_rounded;
    }
  }

  /// True for any actual bleeding (used to derive period runs).
  bool get isBleeding => index > 0;

  /// Relative fill 0..1 for meters / heatmap opacity.
  double get intensity => index / (FlowIntensity.values.length - 1);

  static FlowIntensity fromIndex(int? i) {
    if (i == null || i < 0 || i >= FlowIntensity.values.length) {
      return FlowIntensity.none;
    }
    return FlowIntensity.values[i];
  }
}
