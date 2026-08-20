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
          // A ring is a fixed-size circle, so its readout must shrink to fit
          // rather than reflow: at accessibility text sizes the centre column
          // overflowed and labels like "of 400 mg" / "OF 4" escaped onto the
          // card behind it. Doing this here covers every ring in the app.
          // scaleDown never enlarges, so default sizes render unchanged.
          if (center != null)
            Padding(
              padding: EdgeInsets.all(stroke),
              child: FittedBox(fit: BoxFit.scaleDown, child: center),
            ),
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
    // Guard the radius: a caller passing a stroke wider than the box would
    // otherwise ask Skia to stroke a negative-radius circle.
    final radius = math.max(0.0, (size.width - stroke) / 2);
    if (radius == 0) return;

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
    if (value <= 0) return;

    // A closed ring means DONE — so draw the full circle rather than a 2π arc.
    // An arc that sweeps the whole way round with round caps laps itself at the
    // 12-o'clock start, leaving a visible seam on the one state that has to look
    // perfect.
    if (value >= 1.0) {
      canvas.drawCircle(center, radius, fillPaint);
      return;
    }

    // ROUND CAPS ADD INK THE VALUE DIDN'T ASK FOR.
    //
    // StrokeCap.round extends the stroke by half its width past each end of the
    // arc, so the ink actually laid down spans `sweep + stroke/radius` radians,
    // not `sweep`. On the 104px hero ring (stroke 10, radius 47) that overshoot
    // is 0.213 rad — 3.4% of the circle — which meant **anything at or above
    // ~96.6% painted as a fully closed ring**: the two caps met and overlapped.
    // The user reads a closed ring as 100%, so a 97%-adherence day was
    // indistinguishable from a perfect one, and the centre caption then had to
    // argue with the picture around it.
    //
    // Subtracting the cap extension makes total ink equal the value again, and
    // makes the 1.0 case above the only way to draw a closed ring.
    final capRadians = stroke / radius;
    final sweep = 2 * math.pi * value - capRadians;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2 + capRadians / 2,
      // Below one cap's worth of arc there is no geometry left to shorten: a
      // round cap at sweep 0 is a dot of diameter `stroke`, which is the
      // smallest mark this ring can make. Clamping to 0 keeps a just-started
      // value visible instead of vanishing — the dot over-reads slightly, and
      // over-reading a first dose is the safe direction.
      sweep > 0 ? sweep : 0,
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.fill != fill || old.track != track || old.stroke != stroke;
}
