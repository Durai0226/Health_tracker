import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/widgets/app/app_widgets.dart';

/// Calm Clarity hydration hero — a bold progress ring around a gentle wave-fill
/// disc, with the amount centered. Always in the water accent (never tinted by
/// the selected beverage), no floating emoji, no glass. Animates on value change
/// only. Replaces an older teardrop gauge, now deleted.
class WaterHeroGauge extends StatelessWidget {
  final double progress; // 0..1
  final int currentMl;
  final int goalMl;

  /// A prescribed daily fluid CEILING, when the person is on one. The gauge then
  /// counts down to it instead of up to a goal: the number in the middle is what
  /// is left, and reaching it is a limit, not an achievement.
  ///
  /// [currentMl] is then the raw volume swallowed, because that is what a
  /// clinician's limit is about; the caller passes it, and [progress] with it.
  final int? limitMl;
  final VoidCallback? onTap;
  final double size;

  const WaterHeroGauge({
    super.key,
    required this.progress,
    required this.currentMl,
    required this.goalMl,
    this.limitMl,
    this.onTap,
    this.size = 232,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final s = ext.water;
    final tt = Theme.of(context).textTheme;
    final pct = (progress.clamp(0.0, 1.0) * 100).round();
    final limit = limitMl != null && limitMl! > 0 ? limitMl : null;
    final reached = goalMl > 0 && currentMl >= goalMl;
    // On a limit "reached" is not a win but the line not to cross, so it is
    // checked first everywhere below and `reached` never shows for such a person.
    final atLimit = limit != null && currentMl >= limit;
    final overBy = limit != null ? currentMl - limit : 0;
    final leftMl = limit != null ? (limit - currentMl).clamp(0, limit) : 0;

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
                // Center readout.
                //
                // Inside a `FittedBox(scaleDown)` because this box is a CIRCLE:
                // the gauge cannot grow to fit its text the way a list row can,
                // so at 2.0x the readout ran 26px past the disc. Padding the
                // inset to ~62% of the diameter keeps the block inside the ring
                // rather than merely inside the square. `scaleDown` never
                // enlarges, so the default rendering is untouched.
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: size * 0.19),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      limit != null ? '$leftMl' : '$currentMl',
                      style: tt.displayLarge?.copyWith(
                        color: v > 0.62 ? s.on : s.strong,
                        fontWeight: FontWeight.w800,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      limit != null ? 'ml left of $limit' : 'of $goalMl ml',
                      style: tt.bodyMedium?.copyWith(
                        color: v > 0.55 ? s.on.withOpacity(0.8) : ext.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        // `fillBg`/`fillFg`, not `success.base`/`s.strong`
                        // with a hardcoded white: on light `success.base`
                        // (#10B981) takes white to 2.20:1, and this pill is
                        // the gauge's readout.
                        color: atLimit
                            ? ext.fillBg(overBy > 0 ? ext.error : ext.warning)
                            : reached
                                ? ext.fillBg(ext.success)
                                : ext.fillBg(s),
                        borderRadius: AppRadius.brFull,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            atLimit
                                ? Symbols.warning_rounded
                                : reached
                                    ? Symbols.check_rounded
                                    : Symbols.local_drink_rounded,
                            size: 13,
                            color: atLimit
                                ? ext.fillFg(overBy > 0 ? ext.error : ext.warning)
                                : reached
                                    ? ext.fillFg(ext.success)
                                    : ext.fillFg(s),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            atLimit
                                ? (overBy > 0
                                    ? 'Over by $overBy ml'
                                    : 'Limit reached')
                                : reached
                                    ? 'Goal reached'
                                    : limit != null
                                        ? '$pct% of limit'
                                        : '$pct%',
                            style: tt.labelSmall?.copyWith(
                                color: atLimit
                                    ? ext.fillFg(
                                        overBy > 0 ? ext.error : ext.warning)
                                    : reached
                                        ? ext.fillFg(ext.success)
                                        : ext.fillFg(s)),
                          ),
                        ],
                      ),
                    ),
                  ],
                    ),
                  ),
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
