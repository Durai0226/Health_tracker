import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';

import '../models/cycle_phase.dart';
import '../theme/period_theme.dart';

/// The signature hero: an interactive-feeling ring whose four phase arcs are
/// sized by their real day-spans, with a fertile-window band whose opacity
/// encodes prediction confidence and an animated current-day marker. Center text
/// reads "Day X of ~Y" (or a next-period countdown). Animates once via
/// [TweenAnimationBuilder], gated on `disableAnimations`.
class CyclePhaseWheel extends StatelessWidget {
  final int cycleLength;
  final int periodLength;
  final int lutealLength;

  /// 1-based day of the cycle; null hides the marker (cold start).
  final int? dayOfCycle;

  /// Fertile window as day-of-cycle indices; null hides the band.
  final int? fertileStartDay;
  final int? fertileEndDay;

  /// 0..1 — drives the fertile band opacity (honest confidence signal).
  final double confidence;

  final CyclePhase? currentPhase;
  final String centerTop;
  final String centerBottom;
  final double size;

  const CyclePhaseWheel({
    super.key,
    required this.cycleLength,
    required this.periodLength,
    required this.lutealLength,
    this.dayOfCycle,
    this.fertileStartDay,
    this.fertileEndDay,
    this.confidence = 0.5,
    this.currentPhase,
    required this.centerTop,
    required this.centerBottom,
    this.size = 240,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final len = cycleLength < 1 ? 28 : cycleLength;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final ovIndex = (len - lutealLength).clamp(1, len - 1);
    final ovStart = (ovIndex - 1).clamp(0, len).toDouble();
    final ovEnd = (ovIndex + 2).clamp(0, len).toDouble();
    final pLen = periodLength.clamp(1, len).toDouble();

    final segments = <_PhaseSeg>[
      _PhaseSeg(0, pLen, ext.mark(PeriodTheme.phaseSwatch(ext, CyclePhase.menstrual))),
      if (pLen < ovStart)
        _PhaseSeg(pLen, ovStart,
            ext.mark(PeriodTheme.phaseSwatch(ext, CyclePhase.follicular))),
      _PhaseSeg(ovStart, ovEnd,
          ext.mark(PeriodTheme.phaseSwatch(ext, CyclePhase.ovulation))),
      if (ovEnd < len.toDouble())
        _PhaseSeg(ovEnd, len.toDouble(),
            ext.mark(PeriodTheme.phaseSwatch(ext, CyclePhase.luteal))),
    ];

    _Band? band;
    if (fertileStartDay != null && fertileEndDay != null) {
      final fs = fertileStartDay!.clamp(0, len).toDouble();
      final fe = fertileEndDay!.clamp(0, len).toDouble();
      if (fe > fs) {
        final swatch = PeriodTheme.fertileSwatch(ext);
        final opacity = (0.22 + 0.55 * confidence.clamp(0.0, 1.0));
        band = _Band(fs, fe, ext.mark(swatch).withValues(alpha: opacity));
      }
    }

    final markerColor = currentPhase != null
        ? ext.mark(PeriodTheme.phaseSwatch(ext, currentPhase!))
        : ext.mark(ext.period);
    final targetDay = dayOfCycle?.clamp(0, len).toDouble();

    Widget paint(double t) => CustomPaint(
          size: Size.square(size),
          painter: _WheelPainter(
            cycleLength: len.toDouble(),
            segments: segments,
            band: band,
            markerDay: targetDay,
            markerColor: markerColor,
            markerBorder: ext.surface,
            trackColor: ext.outline,
            progress: t,
          ),
        );

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (reduceMotion)
            paint(1)
          else
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: AppMotion.fill,
              curve: AppMotion.emphasized,
              builder: (context, t, _) => paint(t),
            ),
          Padding(
            padding: EdgeInsets.all(size * 0.24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    centerTop,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: tt.headlineSmall?.copyWith(
                      color: ext.textPrimary,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    centerBottom,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: tt.bodySmall?.copyWith(color: ext.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhaseSeg {
  final double startDay;
  final double endDay;
  final Color color;
  const _PhaseSeg(this.startDay, this.endDay, this.color);
}

class _Band {
  final double startDay;
  final double endDay;
  final Color color;
  const _Band(this.startDay, this.endDay, this.color);
}

class _WheelPainter extends CustomPainter {
  final double cycleLength;
  final List<_PhaseSeg> segments;
  final _Band? band;
  final double? markerDay;
  final Color markerColor;
  final Color markerBorder;
  final Color trackColor;
  final double progress; // 0..1 animation driver

  _WheelPainter({
    required this.cycleLength,
    required this.segments,
    required this.band,
    required this.markerDay,
    required this.markerColor,
    required this.markerBorder,
    required this.trackColor,
    required this.progress,
  });

  static const double _stroke = 16;
  static const double _gapRad = 0.045; // small gap between phase arcs

  double _angleFor(double day) => -math.pi / 2 + (day / cycleLength) * 2 * math.pi;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.width - _stroke) / 2 - 6;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..color = trackColor.withValues(alpha: 0.5),
    );

    // Fertile band — a thinner translucent arc just inside the ring.
    if (band != null) {
      final bandRadius = radius - _stroke * 0.5 - 5;
      final start = _angleFor(band!.startDay);
      final sweep = ((band!.endDay - band!.startDay) / cycleLength) * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: bandRadius),
        start,
        sweep * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..color = band!.color,
      );
    }

    // Phase arcs.
    for (final seg in segments) {
      final start = _angleFor(seg.startDay) + _gapRad;
      final rawSweep =
          ((seg.endDay - seg.startDay) / cycleLength) * 2 * math.pi - _gapRad * 2;
      final sweep = math.max(0.0, rawSweep) * progress;
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke
          ..strokeCap = StrokeCap.round
          ..color = seg.color,
      );
    }

    // Current-day marker — sweeps 0 → target once.
    if (markerDay != null) {
      final animDay = markerDay! * progress;
      final a = _angleFor(animDay);
      final mp = Offset(
        center.dx + radius * math.cos(a),
        center.dy + radius * math.sin(a),
      );
      canvas.drawCircle(mp, 9, Paint()..color = markerBorder);
      canvas.drawCircle(mp, 6.5, Paint()..color = markerColor);
    }
  }

  @override
  bool shouldRepaint(_WheelPainter old) =>
      old.progress != progress ||
      old.cycleLength != cycleLength ||
      old.markerDay != markerDay ||
      old.markerColor != markerColor ||
      old.band?.color != band?.color;
}
