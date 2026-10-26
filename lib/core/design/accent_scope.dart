import 'package:flutter/widgets.dart';
import 'app_colors_ext.dart';

/// Propagates the *active feature* down the tree so components resolve the
/// correct (brightness-aware) [AccentSwatch] without threading a color through
/// every constructor. Wrap a feature's body:
///
/// ```dart
/// AccentScope(
///   feature: FeatureAccent.water,
///   child: AquaWaterDashboard(),
/// )
/// ```
///
/// Widgets read it via `AccentScope.swatchOf(context)` (or `.featureOf`).
///
/// An [InheritedTheme], not a plain `InheritedWidget`, so the accent survives a
/// route boundary that the widget tree does not cross.
///
/// `showModalBottomSheet` and `showDialog` mount their content on a NEW route,
/// a child of the Navigator rather than of the caller. Flutter carries styling
/// across that gap with `InheritedTheme.capture`
/// (`bottom_sheet.dart:1320`, `dialog.dart:1640`) — and that captures
/// `InheritedTheme` subclasses ONLY. While this was a plain `InheritedWidget`
/// every sheet and dialog in the app silently lost the accent and
/// [featureOf] fell back to [FeatureAccent.brand], so a sheet opened from a
/// pink screen drew teal rows under its own pink header. Call sites worked
/// around it one at a time by passing `accent:` by hand; the ones that forgot
/// are the whole family of defects this fixes at the source.
class AccentScope extends InheritedTheme {
  final FeatureAccent feature;

  const AccentScope({
    super.key,
    required this.feature,
    required super.child,
  });

  /// How `InheritedTheme.capture` re-applies this scope inside the new route.
  @override
  Widget wrap(BuildContext context, Widget child) =>
      AccentScope(feature: feature, child: child);

  static FeatureAccent featureOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AccentScope>();
    return scope?.feature ?? FeatureAccent.brand;
  }

  /// The active feature's swatch, already resolved for the current brightness.
  static AccentSwatch swatchOf(BuildContext context) {
    return AppColorsExt.of(context).accent(featureOf(context));
  }

  @override
  bool updateShouldNotify(AccentScope oldWidget) => oldWidget.feature != feature;
}
