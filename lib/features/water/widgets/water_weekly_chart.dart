import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'dart:math' as math;

/// Premium weekly progress chart with modern visualization
/// Glassmorphism design with animated bars
class WaterWeeklyChart extends StatefulWidget {
  final List<DailyWaterSummary> weekData;
  final int goalMl;
  final VoidCallback? onTapHistory;

  const WaterWeeklyChart({
    super.key,
    required this.weekData,
    required this.goalMl,
    this.onTapHistory,
  });

  @override
  State<WaterWeeklyChart> createState() => _WaterWeeklyChartState();
}

class _WaterWeeklyChartState extends State<WaterWeeklyChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.green.shade400,
                      Colors.teal.shade400,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Symbols.bar_chart_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'This Week',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (widget.onTapHistory != null)
                GestureDetector(
                  onTap: widget.onTapHistory,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Symbols.calendar_month_rounded,
                          size: 14,
                          color: Colors.green.shade400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'History',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Chart container
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Stats row
              _buildStatsRow(),
              const SizedBox(height: 20),
              // Bar chart
              SizedBox(
                height: 160,
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return _buildBarChart();
                  },
                ),
              ),
              const SizedBox(height: 12),
              // Day labels
              _buildDayLabels(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    final totalMl = widget.weekData.fold<int>(0, (sum, d) => sum + d.intakeMl);
    final avgMl = widget.weekData.isNotEmpty
        ? (totalMl / widget.weekData.length).round()
        : 0;
    final daysGoalMet = widget.weekData.where((d) => d.goalReached).length;

    return Row(
      children: [
        _buildStatItem(
          '${(totalMl / 1000).toStringAsFixed(1)}L',
          'Total',
          Colors.blue,
        ),
        _buildStatDivider(),
        _buildStatItem(
          '${(avgMl / 1000).toStringAsFixed(1)}L',
          'Avg/day',
          Colors.cyan,
        ),
        _buildStatDivider(),
        _buildStatItem(
          '$daysGoalMet/${widget.weekData.length}',
          'Goals met',
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildStatItem(String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 30,
      color: Colors.grey.shade200,
    );
  }

  Widget _buildBarChart() {
    final maxValue = math.max(
      widget.goalMl.toDouble(),
      widget.weekData.fold<double>(
        0,
        (max, d) => math.max(max, d.intakeMl.toDouble()),
      ),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (index) {
        if (index < widget.weekData.length) {
          final data = widget.weekData[index];
          final progress = (data.intakeMl / maxValue).clamp(0.0, 1.0);
          final goalProgress = (widget.goalMl / maxValue).clamp(0.0, 1.0);
          final isToday = index == widget.weekData.length - 1;

          return _buildBar(
            progress * _animation.value,
            goalProgress,
            data.goalReached,
            isToday,
            data.intakeMl,
          );
        }
        return _buildEmptyBar();
      }),
    );
  }

  Widget _buildBar(
    double progress,
    double goalProgress,
    bool goalReached,
    bool isToday,
    int intakeMl,
  ) {
    final barColor = goalReached
        ? Colors.green
        : isToday
            ? Colors.blue
            : Colors.blue.shade300;

    return Tooltip(
      message: '${intakeMl}ml',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Bar
          Container(
            width: 32,
            height: 140 * progress,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  barColor.withOpacity(0.7),
                  barColor,
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
              boxShadow: isToday
                  ? [
                      BoxShadow(
                        color: barColor.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Goal line indicator
                if (!goalReached)
                  Positioned(
                    bottom: 140 * goalProgress - (140 * progress),
                    left: -4,
                    right: -4,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                // Check mark for goal reached
                if (goalReached)
                  Positioned(
                    top: -8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Symbols.check_rounded,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Today indicator
          if (isToday)
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyBar() {
    return Container(
      width: 32,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(8),
        ),
      ),
    );
  }

  Widget _buildDayLabels() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = DateTime.now().weekday - 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(7, (index) {
        final isToday = index == today;
        return SizedBox(
          width: 32,
          child: Text(
            days[index],
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              color: isToday ? Colors.blue : Colors.grey.shade600,
            ),
          ),
        );
      }),
    );
  }
}

/// Data model for daily water summary
class DailyWaterSummary {
  final DateTime date;
  final int intakeMl;
  final int goalMl;
  final bool goalReached;

  DailyWaterSummary({
    required this.date,
    required this.intakeMl,
    required this.goalMl,
  }) : goalReached = intakeMl >= goalMl;

  factory DailyWaterSummary.empty(DateTime date, int goalMl) {
    return DailyWaterSummary(
      date: date,
      intakeMl: 0,
      goalMl: goalMl,
    );
  }
}

/// Recent history timeline widget
class WaterHistoryTimeline extends StatelessWidget {
  final List<WaterLogEntry> entries;
  final Function(WaterLogEntry)? onTapEntry;
  final VoidCallback? onTapViewAll;

  const WaterHistoryTimeline({
    super.key,
    required this.entries,
    this.onTapEntry,
    this.onTapViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.indigo.shade400,
                      Colors.blue.shade400,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Symbols.history_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (onTapViewAll != null)
                GestureDetector(
                  onTap: onTapViewAll,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.indigo.shade400,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Timeline
        if (entries.isEmpty)
          _buildEmptyState()
        else
          ...entries.take(5).map((entry) => _buildTimelineEntry(entry)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Column(
          children: [
            const Text('💧', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 12),
            Text(
              'No drinks logged yet',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Start tracking your hydration!',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineEntry(WaterLogEntry entry) {
    final color = Color(int.parse(entry.colorHex.replaceFirst('#', '0xFF')));

    return GestureDetector(
      onTap: () => onTapEntry?.call(entry),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            // Timeline dot
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  entry.emoji,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.beverageName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTime(entry.time),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            // Amount
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '+${entry.amountMl}ml',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}

/// Data model for water log entry
class WaterLogEntry {
  final String id;
  final String beverageName;
  final String emoji;
  final String colorHex;
  final int amountMl;
  final DateTime time;

  WaterLogEntry({
    required this.id,
    required this.beverageName,
    required this.emoji,
    required this.colorHex,
    required this.amountMl,
    required this.time,
  });
}
