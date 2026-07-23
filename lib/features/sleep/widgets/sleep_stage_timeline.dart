import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import '../models/sleep_session.dart';
import '../models/sleep_stage.dart';
import '../theme/sleep_theme.dart';

/// A bespoke, single-bar hypnogram: one rounded bar segmented across the night
/// (deep · light · rem · awake). When the session has no measured stages it
/// degrades honestly to an asleep-vs-in-bed split with an "Estimated" tag — we
/// never fabricate a stage breakdown we don't have.
class SleepStageTimeline extends StatelessWidget {
  final SleepSession session;
  const SleepStageTimeline({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final colors = SleepStageColors.of(context);
    final hasStages = session.hasStages;

    final segments = <_Seg>[];
    if (hasStages) {
      for (final stage in const [
        SleepStage.deep,
        SleepStage.light,
        SleepStage.rem,
        SleepStage.awake,
      ]) {
        final m = session.stageMinutes(stage);
        if (m > 0) {
          segments.add(_Seg(
            label: stage.label,
            minutes: m,
            color: colors.forStage(stage),
          ));
        }
      }
    } else {
      final awake = (session.inBedMinutes - session.asleepMinutes)
          .clamp(0, session.inBedMinutes);
      segments.add(_Seg(
        label: 'Asleep',
        minutes: session.asleepMinutes,
        color: colors.deep,
      ));
      if (awake > 0) {
        segments.add(_Seg(label: 'Awake in bed', minutes: awake, color: colors.awake));
      }
    }

    final total = segments.fold<int>(0, (a, s) => a + s.minutes);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Symbols.timeline_rounded, size: 16, color: ext.mark(ext.sleep)),
              const SizedBox(width: 8),
              Expanded(
                // Honest title: without measured stages this is a time-in-bed
                // split, not a hypnogram — so we don't call it "Sleep stages".
                child: Text(hasStages ? 'Sleep stages' : 'Time in bed',
                    style: tt.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, c) => CustomPaint(
              size: Size(c.maxWidth, 30),
              painter: _HypnogramPainter(
                segments: segments,
                total: total <= 0 ? 1 : total,
                track: ext.sleep.container,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_timeLabel(session.bedtime),
                  style: tt.labelSmall?.copyWith(color: ext.textTertiary)),
              Text(_timeLabel(session.wakeTime),
                  style: tt.labelSmall?.copyWith(color: ext.textTertiary)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: [
              for (final s in segments)
                _LegendItem(
                  color: s.color,
                  label: s.label,
                  value: SleepSession.formatMinutes(s.minutes),
                ),
            ],
          ),
          if (!hasStages) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Symbols.info_rounded, size: 14, color: ext.textTertiary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Deep · light · REM breakdown appears when sleep syncs '
                    'from Health.',
                    style: tt.bodySmall?.copyWith(color: ext.textTertiary),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _timeLabel(DateTime t) {
    final h24 = t.hour;
    final period = h24 >= 12 ? 'PM' : 'AM';
    var h = h24 % 12;
    if (h == 0) h = 12;
    return '$h:${t.minute.toString().padLeft(2, '0')} $period';
  }
}

class _Seg {
  final String label;
  final int minutes;
  final Color color;
  const _Seg({required this.label, required this.minutes, required this.color});
}

class _HypnogramPainter extends CustomPainter {
  final List<_Seg> segments;
  final int total;
  final Color track;

  _HypnogramPainter({
    required this.segments,
    required this.total,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, radius);

    // Track behind the segments.
    canvas.drawRRect(rrect, Paint()..color = track);

    canvas.save();
    canvas.clipRRect(rrect);
    final paint = Paint()..style = PaintingStyle.fill;
    var x = 0.0;
    for (final s in segments) {
      final w = (s.minutes / total) * size.width;
      paint.color = s.color;
      // +0.5 to avoid hairline gaps between adjacent segments from rounding.
      canvas.drawRect(Rect.fromLTWH(x, 0, w + 0.5, size.height), paint);
      x += w;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HypnogramPainter old) =>
      old.total != total || old.track != track || old.segments != segments;
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('$label ', style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
        Text(
          value,
          style: tt.bodySmall?.copyWith(
            color: ext.textPrimary,
            fontWeight: FontWeight.w700,
            fontFeatures: kTabular,
          ),
        ),
      ],
    );
  }
}

