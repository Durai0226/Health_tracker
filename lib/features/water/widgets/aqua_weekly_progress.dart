import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'dart:math' as math;
import '../../../core/design/app_design.dart';
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
    final ext = AppColorsExt.of(context);
    final isDark = AquaTheme.isDark(context);
    final beverage = AquaTheme.getBeverage(beverageId);
    final today = DateTime.now().weekday;
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      padding: const EdgeInsets.all(AquaTheme.spacingM),
      decoration: AquaTheme.getCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ext.water.container,
                  borderRadius: AppRadius.brSm,
                ),
                child: Icon(
                  Symbols.calendar_today_rounded,
                  color: ext.water.onContainer,
                  size: 16,
                ),
              ),
              const SizedBox(width: AquaTheme.spacingS),
              // Unflexed title + Spacer + "History" action was 50px too wide on
              // a 320pt phone at default text size. Expanded replaces the
              // Spacer — the action stays flush right, the title yields.
              Expanded(
                child: Text(
                  'This Week',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                    color: ext.textPrimary,
                  ),
                ),
              ),
              if (onTapHistory != null)
                GestureDetector(
                  onTap: onTapHistory,
                  behavior: HitTestBehavior.opaque,
                  // A bare text+chevron link is only ~17pt tall — under even the
                  // WCAG 2.2 24pt floor, let alone Apple's 44pt. Reserve a 44pt
                  // hit box without moving the label.
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'History',
                            style: Theme.of(context).textTheme.labelMedium!.copyWith(
                              color: ext.mark(ext.water),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Symbols.arrow_forward_ios_rounded,
                            size: 12,
                            color: ext.mark(ext.water),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: AquaTheme.spacingL),
          
          // Day indicators.
          // Seven fixed 38pt dials need 266pt; a 320pt phone only leaves 256
          // inside the card, so spaceAround overflowed by 10pt. Each day gets
          // an equal Expanded slot instead — for seven equal-width children
          // that lays out identically to spaceAround wherever they already fit,
          // and on a narrow screen the dial shrinks to its slot (see
          // _DayIndicator) rather than running off the card.
          Row(
            children: List.generate(7, (index) {
              final dayNum = index + 1;
              final isToday = dayNum == today;
              final isPast = dayNum < today;
              final isFuture = dayNum > today;
              
              // Progress for this day. A day the caller supplied no entry for
              // is NOT invented: it renders as an empty dial, exactly like a
              // logged day with no intake. This used to fall back to
              // `0.7 + index * 0.05` for past days, so a patient-facing chart
              // reported 70-100% hydration nobody ever drank (and the "Goals
              // Hit" figure below it — which reads weekData directly —
              // disagreed with the dials).
              // Each day against ITS OWN goal (DayProgress.progress), not the
              // single `goalMl` this widget is handed: the caller now passes
              // the goal each day was actually measured against, so editing
              // the goal no longer retroactively rewrites the week.
              // DayProgress.progress guards the 0/0 case too — NaN.clamp(0, 1)
              // returns the UPPER limit, which would paint a bogus
              // "goal reached" tick.
              double progress = 0;
              if (index < weekData.length) {
                progress = weekData[index].progress;
              }

              return Expanded(
                child: _DayIndicator(
                  day: days[index],
                  progress: progress,
                  isToday: isToday,
                  isPast: isPast,
                  isFuture: isFuture,
                  beverage: beverage,
                ),
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
    final ext = AppColorsExt.of(context);
    // Calculate weekly stats
    final totalIntake = weekData.fold<int>(0, (sum, day) => sum + day.intakeMl);
    final daysWithData = weekData.where((d) => d.intakeMl > 0).length;
    final avgIntake = daysWithData > 0 ? (totalIntake / daysWithData).round() : 0;
    // Per-day goals here too, so "Goals Hit n/7" agrees with the dials above it.
    final goalReachedDays =
        weekData.where((d) => d.goalMl > 0 && d.intakeMl >= d.goalMl).length;

    return Container(
      padding: const EdgeInsets.all(AquaTheme.spacingM),
      decoration: BoxDecoration(
        color: ext.surfaceVariant,
        borderRadius: AppRadius.brLg,
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
    final ext = AppColorsExt.of(context);
    return Expanded(
      child: Column(
        children: [
          // The figure was painted through a `ShaderMask` of the beverage
          // gradient, i.e. white text tinted by two arbitrary hues — for milk
          // that is #FAFAFA on a #FAFAFA-tinted panel. A stat value is body
          // text: it reads in `textPrimary`.
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall!.copyWith(
              color: ext.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall!.copyWith(
              color: ext.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Builder(
      builder: (context) => Container(
        width: 1,
        height: 30,
        color: AppColorsExt.of(context).outline,
      ),
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
    final ext = AppColorsExt.of(context);
    final isComplete = progress >= 1.0;

    return LayoutBuilder(builder: (context, constraints) {
      // 38 is the design size; on a 320pt phone the seven slots are only ~36.6
      // wide, so the dial takes the slot instead of overflowing the card. It is
      // never enlarged, so every other phone renders exactly as before.
      final dial = constraints.maxWidth.isFinite
          ? math.min(38.0, constraints.maxWidth)
          : 38.0;
      return Column(
        children: [
          SizedBox(
            width: dial,
            height: dial,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background circle
                Container(
                  width: dial,
                  height: dial,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFuture ? ext.surfaceVariant : null,
                  ),
                ),

                // Progress ring
                if (!isFuture)
                  CustomPaint(
                    size: Size(dial, dial),
                    painter: _CircularProgressPainter(
                      progress: progress,
                      strokeWidth: 3,
                      backgroundColor: ext.outline,
                      // One hue per state, from the chart-mark set that was
                      // validated against these surfaces. The two-stop
                      // gradients here were decoration on a 3pt stroke.
                      progressColor: isComplete
                          ? ext.chartMark(ext.success)
                          : ext.chartMark(ext.water),
                      gradientColors: isComplete
                          ? [ext.chartMark(ext.success), ext.chartMark(ext.success)]
                          : [ext.chartMark(ext.water), ext.chartMark(ext.water)],
                    ),
                  ),

                // Center content
                if (isComplete)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ext.fillBg(ext.success),
                    ),
                    child: Icon(
                      Symbols.check_rounded,
                      color: ext.fillFg(ext.success),
                      size: 14,
                      applyTextScaling: false,
                    ),
                  )
                else if (!isFuture && progress > 0)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                    '${(progress * 100).toInt()}',
                    // 11 (labelSmall) is the scale's floor; the `fontSize: 10`
                    // override this had was the only sub-floor caption left in
                    // the feature. FittedBox keeps it inside the 38pt dial.
                    style: Theme.of(context).textTheme.labelSmall!.copyWith(
                      color: ext.mark(ext.water),
                    ),
                  ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isToday ? ext.fillBg(ext.water) : Colors.transparent,
              borderRadius: AppRadius.brFull,
            ),
            // A single-letter day never needs to wrap; keeping it on one line
            // stops a wide Dynamic Type letter from stretching the slot.
            child: Text(
              day,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium!.copyWith(
                color: isToday
                    ? ext.fillFg(ext.water)
                    : (isFuture ? ext.textTertiary : ext.textSecondary),
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    });
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
