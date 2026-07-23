import 'package:flutter/material.dart';
import '../theme/aqua_theme.dart';

/// A self-contained, asset-free, theme-aware shimmer effect.
///
/// Wrap any tree of opaque skeleton "bones" in an [AquaShimmer]. A single
/// [AnimationController] drives a [LinearGradient] highlight band that sweeps
/// left-to-right across every opaque pixel of the child (via [ShaderMask] +
/// [BlendMode.srcATop]), leaving transparent gaps untouched.
///
/// Reduced-motion safe: when [MediaQuery.disableAnimations] is set (OS
/// "reduce motion" / accessibility), the sweep is skipped and the static
/// bones are rendered instead — no controller churn.
class AquaShimmer extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const AquaShimmer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1400),
  });

  @override
  State<AquaShimmer> createState() => _AquaShimmerState();
}

class _AquaShimmerState extends State<AquaShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    // Reduced-motion / accessibility: render a static block, no sweep.
    if (reduceMotion) {
      if (_controller.isAnimating) _controller.stop();
      return widget.child;
    }
    if (!_controller.isAnimating) _controller.repeat();

    final isDark = AquaTheme.isDark(context);
    // Highlight band. Fading to fully-transparent (highlight.withOpacity(0))
    // rather than Colors.transparent avoids the grey/black fringe that
    // interpolating toward premultiplied-black transparent can produce.
    final highlight = isDark
        ? Colors.white.withOpacity(0.14)
        : Colors.white.withOpacity(0.70);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                highlight.withOpacity(0),
                highlight,
                highlight.withOpacity(0),
              ],
              stops: const [0.35, 0.5, 0.65],
              transform: _SlideGradient(_controller.value),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Slides a gradient horizontally from one full width off the left edge to one
/// full width off the right edge as [value] goes 0 -> 1.
class _SlideGradient extends GradientTransform {
  final double value; // 0..1
  const _SlideGradient(this.value);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final dx = (value * 2 - 1) * bounds.width;
    return Matrix4.translationValues(dx, 0, 0);
  }
}

/// A single opaque skeleton "bone". Solid, theme-aware fill; the sweep is
/// supplied by an ancestor [AquaShimmer].
class AquaSkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  final BoxShape shape;

  const AquaSkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = AquaTheme.radiusMedium,
    this.shape = BoxShape.rectangle,
  });

  @override
  Widget build(BuildContext context) {
    final color = AquaTheme.isDark(context)
        ? Colors.white.withOpacity(0.10)
        : const Color(0xFFE4E9EF);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        shape: shape,
        borderRadius:
            shape == BoxShape.circle ? null : BorderRadius.circular(radius),
      ),
    );
  }
}

/// Skeleton placeholder that mirrors the Aqua water dashboard structure:
/// hero gauge circle, Quick Add header + row of 4, an AI insight card, a
/// Today's Log block, and the Weekly progress block. Wrapped in a single
/// [AquaShimmer] so one controller animates the whole screen.
class AquaDashboardSkeleton extends StatelessWidget {
  /// Matches [AquaWaterDashboard.embedded]: drops the top safe-area inset and
  /// tightens the leading gap when the Health hub owns the header.
  final bool embedded;

  const AquaDashboardSkeleton({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    return AquaShimmer(
      child: SafeArea(
        top: !embedded,
        bottom: false,
        child: SingleChildScrollView(
          // Non-interactive: the skeleton is transient, never scrolled by the
          // user, but scrollable physics guard against overflow on short
          // screens.
          physics: const NeverScrollableScrollPhysics(),
          padding:
              const EdgeInsets.symmetric(horizontal: AquaTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                  height:
                      embedded ? AquaTheme.spacingM : AquaTheme.spacingL),

              // Hero hydration gauge (232px circle in the real dashboard).
              const Center(
                child: AquaSkeletonBox(
                  width: 232,
                  height: 232,
                  shape: BoxShape.circle,
                ),
              ),

              const SizedBox(height: AquaTheme.spacingXL),

              // Quick Add section header.
              const AquaSkeletonBox(
                width: 140,
                height: 20,
                radius: AquaTheme.radiusSmall,
              ),
              const SizedBox(height: AquaTheme.spacingM),

              // Quick Add grid: a row of 4 rounded tiles.
              Row(
                children: List.generate(
                  4,
                  (i) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          right: i < 3 ? AquaTheme.spacingS : 0),
                      child: const AquaSkeletonBox(
                        height: 76,
                        radius: AquaTheme.radiusMedium,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AquaTheme.spacingXL),

              // AI insight card.
              const AquaSkeletonBox(
                height: 112,
                radius: AquaTheme.radiusLarge,
              ),

              const SizedBox(height: AquaTheme.spacingXL),

              // Today's Log header + list block.
              const AquaSkeletonBox(
                width: 120,
                height: 20,
                radius: AquaTheme.radiusSmall,
              ),
              const SizedBox(height: AquaTheme.spacingM),
              const AquaSkeletonBox(
                height: 132,
                radius: AquaTheme.radiusLarge,
              ),

              const SizedBox(height: AquaTheme.spacingXL),

              // Weekly progress block.
              const AquaSkeletonBox(
                height: 160,
                radius: AquaTheme.radiusLarge,
              ),

              const SizedBox(height: AquaTheme.spacingXL),
            ],
          ),
        ),
      ),
    );
  }
}
