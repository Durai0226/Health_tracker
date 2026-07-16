import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../design/app_design.dart';

/// One custom-painted progress arc. Replaces the 6-style HydrationProgressRing,
/// the per-day painter, and the ad-hoc CircularProgressIndicator rings.
///
/// Fill uses the AA-safe [AppColorsExt.mark] variant so cyan/amber rings clear
/// the 3:1 graphical threshold on light surfaces. Animates on value change only
/// (no idle loop).
class ProgressRing extends StatelessWidget {
  final double progress; // 0..1
  final double size;
  final double stroke;
  final Color? fillColor;
  final Color? trackColor;
  final Widget? center;
  final AccentSwatch? accent;
  final bool animate;

  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 84,
    this.stroke = 8,
    this.fillColor,
    this.trackColor,
    this.center,
    this.accent,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final s = accent ?? AccentScope.swatchOf(context);
    final fill = fillColor ?? ext.mark(s);
    final track = trackColor ?? s.container;
    final value = progress.clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (animate)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value),
              duration: AppMotion.fill,
              curve: AppMotion.emphasized,
              builder: (context, v, _) => CustomPaint(
                size: Size.square(size),
                painter: _RingPainter(v, fill, track, stroke),
              ),
            )
          else
            CustomPaint(
              size: Size.square(size),
              painter: _RingPainter(value, fill, track, stroke),
            ),
          if (center != null) Padding(padding: EdgeInsets.all(stroke), child: center),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color fill;
  final Color track;
  final double stroke;

  _RingPainter(this.value, this.fill, this.track, this.stroke);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.width - stroke) / 2;
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    final fillPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      ..color = fill;

    canvas.drawCircle(center, radius, trackPaint);
    if (value > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * value,
        false,
        fillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.fill != fill || old.track != track || old.stroke != stroke;
}
