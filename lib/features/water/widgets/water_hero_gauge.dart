import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/widgets/app/app_widgets.dart';

/// Calm Clarity hydration hero — a bold progress ring around a gentle wave-fill
/// disc, with the amount centered. Always in the water accent (never tinted by
/// the selected beverage), no floating emoji, no glass. Animates on value change
/// only. Replaces the old teardrop `AquaDropletWidget`.
class WaterHeroGauge extends StatelessWidget {
  final double progress; // 0..1
  final int currentMl;
  final int goalMl;
  final VoidCallback? onTap;
  final double size;

  const WaterHeroGauge({
    super.key,
    required this.progress,
    required this.currentMl,
    required this.goalMl,
    this.onTap,
    this.size = 232,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final s = ext.water;
    final tt = Theme.of(context).textTheme;
    final pct = (progress.clamp(0.0, 1.0) * 100).round();
    final reached = goalMl > 0 && currentMl >= goalMl;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
          duration: AppMotion.fill,
          curve: AppMotion.emphasized,
          builder: (context, v, _) {
            return Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size.square(size),
                  painter: _GaugePainter(
                    value: v,
                    ring: ext.mark(s), // AA-safe accent for the arc
                    ringTrack: s.container,
                    fill: s.base.withOpacity(0.90),
                    fillSoft: s.base.withOpacity(0.55),
                    discBg: ext.isDark ? ext.surfaceVariant : s.container.withOpacity(0.35),
                  ),
                ),
                // Center readout
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$currentMl',
                      style: tt.displayLarge?.copyWith(
                        color: v > 0.62 ? s.on : s.strong,
                        fontWeight: FontWeight.w800,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'of $goalMl ml',
                      style: tt.bodyMedium?.copyWith(
                        color: v > 0.55 ? s.on.withOpacity(0.8) : ext.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: reached ? ext.success.base : s.strong,
                        borderRadius: AppRadius.brFull,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            reached ? Symbols.check_rounded : Symbols.local_drink_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            reached ? 'Goal reached' : '$pct%',
                            style: tt.labelSmall?.copyWith(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double value;
  final Color ring;
  final Color ringTrack;
  final Color fill;
  final Color fillSoft;
  final Color discBg;

  _GaugePainter({
    required this.value,
    required this.ring,
    required this.ringTrack,
    required this.fill,
    required this.fillSoft,
    required this.discBg,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const stroke = 12.0;
    final ringRadius = (size.width - stroke) / 2;
    final discRadius = ringRadius - stroke * 1.4;

    // Inner disc background.
    canvas.drawCircle(center, discRadius, Paint()..color = discBg);

    // Wave fill inside the disc, clipped to the disc circle.
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: discRadius)));
    final top = center.dy + discRadius; // empty
    final bottom = center.dy - discRadius; // full
    final levelY = top + (bottom - top) * value;
    final amp = 7.0 * (value > 0 && value < 1 ? 1 : 0.3);
    final left = center.dx - discRadius;
    final right = center.dx + discRadius;

    Path wave(double phase, double dy) {
      final p = Path()..moveTo(left, levelY + dy);
      const seg = 16;
      for (int i = 0; i <= seg; i++) {
        final x = left + (right - left) * (i / seg);
        final y = levelY + dy + math.sin((i / seg) * 2 * math.pi + phase) * amp;
        p.lineTo(x, y);
      }
      p.lineTo(right, center.dy + discRadius);
      p.lineTo(left, center.dy + discRadius);
      p.close();
      return p;
    }

    if (value > 0.001) {
      canvas.drawPath(wave(math.pi, 4), Paint()..color = fillSoft);
      canvas.drawPath(wave(0, 0), Paint()..color = fill);
    }
    canvas.restore();

    // Track ring + progress arc.
    canvas.drawCircle(
      center,
      ringRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = ringTrack,
    );
    if (value > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: ringRadius),
        -math.pi / 2,
        2 * math.pi * value,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke
          ..color = ring,
      );
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.value != value;
}
