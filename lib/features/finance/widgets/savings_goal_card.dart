import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/finance_theme.dart';
import '../models/finance_models.dart';
import '../services/finance_service.dart';

/// Savings goal card with progress ring
class SavingsGoalCard extends StatelessWidget {
  final FinanceSavingsGoal goal;
  final VoidCallback? onTap;
  final VoidCallback? onAddContribution;

  const SavingsGoalCard({
    super.key,
    required this.goal,
    this.onTap,
    this.onAddContribution,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(FinanceTheme.spacingM),
        decoration: BoxDecoration(
          color: FinanceTheme.surface,
          borderRadius: FinanceTheme.borderRadiusL,
          boxShadow: FinanceTheme.shadowSoft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: goal.color.withValues(alpha: 0.15),
                    borderRadius: FinanceTheme.borderRadiusM,
                  ),
                  child: Icon(goal.icon, color: goal.color, size: 24),
                ),
                const SizedBox(width: FinanceTheme.spacingM),
                // Title and deadline
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.name,
                        style: FinanceTheme.bodyL.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (goal.deadline != null)
                        Text(
                          _formatDeadline(),
                          style: FinanceTheme.bodyS.copyWith(
                            color: goal.isOnTrack 
                                ? FinanceTheme.textSecondary 
                                : FinanceTheme.expense,
                          ),
                        ),
                    ],
                  ),
                ),
                // Progress ring
                _ProgressRing(
                  progress: goal.progress,
                  color: goal.color,
                  size: 56,
                ),
              ],
            ),
            
            const SizedBox(height: FinanceTheme.spacingM),
            
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: goal.progress / 100,
                backgroundColor: goal.color.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(goal.color),
                minHeight: 8,
              ),
            ),
            
            const SizedBox(height: FinanceTheme.spacingM),
            
            // Amount row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saved',
                      style: FinanceTheme.labelS.copyWith(
                        color: FinanceTheme.textSecondary,
                      ),
                    ),
                    Text(
                      FinanceService.formatCurrency(goal.currentAmount),
                      style: FinanceTheme.bodyL.copyWith(
                        fontWeight: FontWeight.w600,
                        color: goal.color,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Target',
                      style: FinanceTheme.labelS.copyWith(
                        color: FinanceTheme.textSecondary,
                      ),
                    ),
                    Text(
                      FinanceService.formatCurrency(goal.targetAmount),
                      style: FinanceTheme.bodyL.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            // Add contribution button
            if (!goal.isCompleted && onAddContribution != null) ...[
              const SizedBox(height: FinanceTheme.spacingM),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onAddContribution,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Contribution'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: goal.color,
                    side: BorderSide(color: goal.color),
                    shape: RoundedRectangleBorder(
                      borderRadius: FinanceTheme.borderRadiusS,
                    ),
                  ),
                ),
              ),
            ],
            
            // Completed badge
            if (goal.isCompleted) ...[
              const SizedBox(height: FinanceTheme.spacingS),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: FinanceTheme.spacingS,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: FinanceTheme.income.withValues(alpha: 0.15),
                  borderRadius: FinanceTheme.borderRadiusS,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, 
                        color: FinanceTheme.income, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Goal Completed!',
                      style: FinanceTheme.labelS.copyWith(
                        color: FinanceTheme.income,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDeadline() {
    final days = goal.daysUntilDeadline;
    if (days == null) return '';
    if (days < 0) return '${-days} days overdue';
    if (days == 0) return 'Due today';
    if (days == 1) return '1 day left';
    if (days < 30) return '$days days left';
    final months = (days / 30).round();
    return '$months month${months > 1 ? 's' : ''} left';
  }
}

/// Compact savings goal tile for lists
class SavingsGoalTile extends StatelessWidget {
  final FinanceSavingsGoal goal;
  final VoidCallback? onTap;

  const SavingsGoalTile({
    super.key,
    required this.goal,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: goal.color.withValues(alpha: 0.15),
          borderRadius: FinanceTheme.borderRadiusS,
        ),
        child: Icon(goal.icon, color: goal.color, size: 22),
      ),
      title: Text(
        goal.name,
        style: FinanceTheme.bodyM.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: LinearProgressIndicator(
        value: goal.progress / 100,
        backgroundColor: goal.color.withValues(alpha: 0.15),
        valueColor: AlwaysStoppedAnimation(goal.color),
        minHeight: 4,
      ),
      trailing: Text(
        '${goal.progress.toStringAsFixed(0)}%',
        style: FinanceTheme.bodyM.copyWith(
          fontWeight: FontWeight.w600,
          color: goal.color,
        ),
      ),
    );
  }
}

/// Circular progress ring widget
class _ProgressRing extends StatelessWidget {
  final double progress;
  final Color color;
  final double size;

  const _ProgressRing({
    required this.progress,
    required this.color,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ProgressRingPainter(
          progress: progress,
          color: color,
        ),
        child: Center(
          child: Text(
            '${progress.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: size * 0.22,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _ProgressRingPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 8) / 2;
    const strokeWidth = 6.0;

    // Background circle
    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = (progress / 100) * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
