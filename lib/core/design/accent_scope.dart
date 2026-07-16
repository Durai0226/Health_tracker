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
class AccentScope extends InheritedWidget {
  final FeatureAccent feature;

  const AccentScope({
    super.key,
    required this.feature,
    required super.child,
  });

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
