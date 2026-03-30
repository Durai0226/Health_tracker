import 'package:flutter/material.dart';
import '../models/mood_entry.dart';
import '../models/quick_mood_level.dart';
import '../theme/mood_theme.dart';

/// Mood trend line chart matching Behance design
/// Shows mood scores over time with smooth curve
class MoodLineChart extends StatelessWidget {
  final List<MoodEntry> entries;
  final int daysToShow;
  final double height;

  const MoodLineChart({
    super.key,
    required this.entries,
    this.daysToShow = 7,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'No mood data yet',
            style: MoodTheme.bodyMd.copyWith(
              color: MoodTheme.textMuted,
            ),
          ),
        ),
      );
    }

    return Container(
      height: height,
      padding: const EdgeInsets.all(MoodTheme.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: MoodTheme.borderRadiusMd,
        boxShadow: MoodTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mood Chart',
            style: MoodTheme.titleSm.copyWith(
              color: MoodTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _MoodChartPainter(
                entries: entries,
                daysToShow: daysToShow,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildTimeLabels(),
        ],
      ),
    );
  }

  Widget _buildTimeLabels() {
    final now = DateTime.now();
    final labels = <String>[];
    
    for (int i = daysToShow - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final hour = date.hour;
      labels.add('${hour.toString().padLeft(2, '0')}:00');
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: labels.take(5).map((label) {
        return Text(
          label,
          style: MoodTheme.caption.copyWith(
            color: MoodTheme.textMuted,
            fontSize: 10,
          ),
        );
      }).toList(),
    );
  }
}

class _MoodChartPainter extends CustomPainter {
  final List<MoodEntry> entries;
  final int daysToShow;

  _MoodChartPainter({
    required this.entries,
    required this.daysToShow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.isEmpty) return;

    final paint = Paint()
      ..color = MoodTheme.purple400
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          MoodTheme.purple400.withOpacity(0.3),
          MoodTheme.purple400.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final dotPaint = Paint()
      ..color = MoodTheme.purple500
      ..style = PaintingStyle.fill;

    final dotBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Calculate points
    final points = <Offset>[];
    final sortedEntries = List<MoodEntry>.from(entries)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final now = DateTime.now();
    final startTime = now.subtract(Duration(days: daysToShow));
    final totalDuration = now.difference(startTime).inMilliseconds.toDouble();

    for (final entry in sortedEntries) {
      if (entry.timestamp.isBefore(startTime)) continue;
      
      final timeDiff = entry.timestamp.difference(startTime).inMilliseconds.toDouble();
      final x = (timeDiff / totalDuration) * size.width;
      
      final quickMood = QuickMoodLevel.fromMoodType(entry.mood);
      final score = quickMood.score; // 1-5
      final y = size.height - ((score - 1) / 4) * size.height;
      
      points.add(Offset(x.clamp(0, size.width), y.clamp(0, size.height)));
    }

    if (points.isEmpty) return;

    // Draw fill area
    final fillPath = Path();
    fillPath.moveTo(points.first.dx, size.height);
    for (final point in points) {
      fillPath.lineTo(point.dx, point.dy);
    }
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);

    // Draw smooth curve line
    if (points.length > 1) {
      final path = Path();
      path.moveTo(points.first.dx, points.first.dy);

      for (int i = 0; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];
        
        final controlX = (p0.dx + p1.dx) / 2;
        path.cubicTo(
          controlX, p0.dy,
          controlX, p1.dy,
          p1.dx, p1.dy,
        );
      }
      
      canvas.drawPath(path, paint);
    }

    // Draw dots
    for (final point in points) {
      canvas.drawCircle(point, 6, dotBorderPaint);
      canvas.drawCircle(point, 4, dotPaint);
    }

    // Draw emoji at last point
    if (points.isNotEmpty) {
      final lastEntry = sortedEntries.last;
      final quickMood = QuickMoodLevel.fromMoodType(lastEntry.mood);
      
      // Draw emoji indicator below the last point
      final textPainter = TextPainter(
        text: TextSpan(
          text: quickMood.emoji,
          style: const TextStyle(fontSize: 16),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      
      final lastPoint = points.last;
      final emojiOffset = Offset(
        lastPoint.dx - textPainter.width / 2,
        lastPoint.dy + 10,
      );
      
      if (emojiOffset.dy + textPainter.height < size.height) {
        textPainter.paint(canvas, emojiOffset);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MoodChartPainter oldDelegate) {
    return oldDelegate.entries != entries;
  }
}

/// Mood emoji calendar grid for analytics
class MoodCalendarGrid extends StatelessWidget {
  final DateTime month;
  final Map<DateTime, MoodEntry> entries;
  final ValueChanged<DateTime>? onDayTap;

  const MoodCalendarGrid({
    super.key,
    required this.month,
    required this.entries,
    this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final firstWeekday = firstDayOfMonth.weekday; // 1 = Monday

    final dayNames = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

    return Column(
      children: [
        // Day name headers
        Row(
          children: dayNames.map((name) {
            return Expanded(
              child: Center(
                child: Text(
                  name,
                  style: MoodTheme.caption.copyWith(
                    color: MoodTheme.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),

        // Calendar grid
        ...List.generate(6, (weekIndex) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: List.generate(7, (dayIndex) {
                final dayNumber = weekIndex * 7 + dayIndex - firstWeekday + 2;
                
                if (dayNumber < 1 || dayNumber > daysInMonth) {
                  return const Expanded(child: SizedBox(height: 40));
                }

                final date = DateTime(month.year, month.month, dayNumber);
                final entry = entries[DateTime(date.year, date.month, date.day)];
                final isToday = _isToday(date);

                return Expanded(
                  child: _CalendarDayCell(
                    date: dayNumber,
                    entry: entry,
                    isToday: isToday,
                    onTap: () => onDayTap?.call(date),
                  ),
                );
              }),
            ),
          );
        }),
      ],
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && 
           date.month == now.month && 
           date.day == now.day;
  }
}

class _CalendarDayCell extends StatelessWidget {
  final int date;
  final MoodEntry? entry;
  final bool isToday;
  final VoidCallback? onTap;

  const _CalendarDayCell({
    required this.date,
    this.entry,
    this.isToday = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasEntry = entry != null;
    final quickMood = hasEntry ? QuickMoodLevel.fromMoodType(entry!.mood) : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isToday 
              ? MoodTheme.purple100 
              : (hasEntry ? MoodTheme.purple50 : Colors.transparent),
          borderRadius: MoodTheme.borderRadiusSm,
          border: isToday 
              ? Border.all(color: MoodTheme.purple400, width: 2)
              : null,
        ),
        child: Center(
          child: hasEntry
              ? Text(
                  quickMood!.emoji,
                  style: const TextStyle(fontSize: 20),
                )
              : Text(
                  '$date',
                  style: MoodTheme.bodySm.copyWith(
                    color: isToday 
                        ? MoodTheme.purple600 
                        : MoodTheme.textSecondary,
                    fontWeight: isToday 
                        ? FontWeight.bold 
                        : FontWeight.normal,
                  ),
                ),
        ),
      ),
    );
  }
}
