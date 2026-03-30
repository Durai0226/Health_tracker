import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/aqua_theme.dart';

/// Weekly progress widget with mini circular indicators
class AquaWeeklyProgress extends StatelessWidget {
  final List<DayProgress> weekData;
  final int goalMl;
  final VoidCallback? onTapHistory;
  final String beverageId;

  const AquaWeeklyProgress({
    super.key,
    required this.weekData,
    required this.goalMl,
    this.onTapHistory,
    this.beverageId = 'water',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AquaTheme.isDark(context);
    final beverage = AquaTheme.getBeverage(beverageId);
    final today = DateTime.now().weekday;
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      padding: const EdgeInsets.all(AquaTheme.spacingM),
      decoration: AquaTheme.getCardDecoration(context, accentColor: beverage.primary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: beverage.gradient,
                  borderRadius: BorderRadius.circular(AquaTheme.radiusSmall),
                ),
                child: const Icon(
                  Icons.calendar_today_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: AquaTheme.spacingS),
              Text(
                'This Week',
                style: AquaTheme.heading3.copyWith(
                  color: AquaTheme.getTextPrimary(context),
                ),
              ),
              const Spacer(),
              if (onTapHistory != null)
                GestureDetector(
                  onTap: onTapHistory,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'History',
                        style: AquaTheme.labelMedium.copyWith(
                          color: beverage.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: beverage.primary,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: AquaTheme.spacingL),
          
          // Day indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              final dayNum = index + 1;
              final isToday = dayNum == today;
              final isPast = dayNum < today;
              final isFuture = dayNum > today;
              
              // Get progress for this day
              double progress = 0;
              if (index < weekData.length) {
                progress = (weekData[index].intakeMl / goalMl).clamp(0.0, 1.0);
              } else if (isPast) {
                progress = 0.7 + (index * 0.05); // Demo data for past days
              }

              return _DayIndicator(
                day: days[index],
                progress: progress,
                isToday: isToday,
                isPast: isPast,
                isFuture: isFuture,
                beverage: beverage,
              );
            }),
          ),
          
          const SizedBox(height: AquaTheme.spacingM),
          
          // Summary stats
          _buildSummaryStats(context, beverage, isDark),
        ],
      ),
    );
  }

  Widget _buildSummaryStats(BuildContext context, BeverageThemeData beverage, bool isDark) {
    // Calculate weekly stats
    final totalIntake = weekData.fold<int>(0, (sum, day) => sum + day.intakeMl);
    final daysWithData = weekData.where((d) => d.intakeMl > 0).length;
    final avgIntake = daysWithData > 0 ? (totalIntake / daysWithData).round() : 0;
    final goalReachedDays = weekData.where((d) => d.intakeMl >= goalMl).length;

    return Container(
      padding: const EdgeInsets.all(AquaTheme.spacingM),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            beverage.primary.withOpacity(isDark ? 0.15 : 0.08),
            beverage.secondary.withOpacity(isDark ? 0.1 : 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(AquaTheme.radiusMedium),
      ),
      child: Row(
        children: [
          _buildStatItem(
            context,
            '${(totalIntake / 1000).toStringAsFixed(1)}L',
            'Total',
            beverage,
          ),
          _buildDivider(isDark),
          _buildStatItem(
            context,
            '${avgIntake}ml',
            'Daily Avg',
            beverage,
          ),
          _buildDivider(isDark),
          _buildStatItem(
            context,
            '$goalReachedDays/7',
            'Goals Hit',
            beverage,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String value, String label, BeverageThemeData beverage) {
    return Expanded(
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => beverage.gradient.createShader(bounds),
            child: Text(
              value,
              style: AquaTheme.heading2.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AquaTheme.caption.copyWith(
              color: AquaTheme.getTextSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      width: 1,
      height: 30,
      color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
    );
  }
}

/// Single day indicator with circular progress
class _DayIndicator extends StatelessWidget {
  final String day;
  final double progress;
  final bool isToday;
  final bool isPast;
  final bool isFuture;
  final BeverageThemeData beverage;

  const _DayIndicator({
    required this.day,
    required this.progress,
    required this.isToday,
    required this.isPast,
    required this.isFuture,
    required this.beverage,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AquaTheme.isDark(context);
    final isComplete = progress >= 1.0;

    return Column(
      children: [
        SizedBox(
          width: 38,
          height: 38,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background circle
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFuture 
                      ? (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100)
                      : null,
                ),
              ),
              
              // Progress ring
              if (!isFuture)
                CustomPaint(
                  size: const Size(38, 38),
                  painter: _CircularProgressPainter(
                    progress: progress,
                    strokeWidth: 3,
                    backgroundColor: isDark 
                        ? Colors.white.withOpacity(0.1) 
                        : Colors.grey.shade200,
                    progressColor: isComplete 
                        ? AquaTheme.success 
                        : beverage.primary,
                    gradientColors: isComplete 
                        ? [AquaTheme.success, const Color(0xFF34D399)]
                        : [beverage.primary, beverage.secondary],
                  ),
                ),
              
              // Center content
              if (isComplete)
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF34D399)],
                    ),
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 14,
                  ),
                )
              else if (!isFuture && progress > 0)
                Text(
                  '${(progress * 100).toInt()}',
                  style: AquaTheme.caption.copyWith(
                    color: beverage.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            gradient: isToday ? beverage.gradient : null,
            color: isToday ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(AquaTheme.radiusFull),
          ),
          child: Text(
            day,
            style: AquaTheme.labelMedium.copyWith(
              color: isToday 
                  ? Colors.white 
                  : (isFuture 
                      ? AquaTheme.textTertiary 
                      : AquaTheme.getTextSecondary(context)),
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// Circular progress painter
class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color backgroundColor;
  final Color progressColor;
  final List<Color> gradientColors;

  _CircularProgressPainter({
    required this.progress,
    required this.strokeWidth,
    required this.backgroundColor,
    required this.progressColor,
    required this.gradientColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    
    // Background circle
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    
    canvas.drawCircle(center, radius, bgPaint);
    
    // Progress arc
    if (progress > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      final progressPaint = Paint()
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: math.pi * 1.5,
          colors: gradientColors,
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Data class for daily progress
class DayProgress {
  final DateTime date;
  final int intakeMl;
  final int goalMl;

  DayProgress({
    required this.date,
    required this.intakeMl,
    required this.goalMl,
  });

  double get progress => goalMl > 0 ? (intakeMl / goalMl).clamp(0.0, 1.0) : 0.0;
}
