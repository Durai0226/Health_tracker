import 'package:flutter/material.dart';
import '../theme/mood_theme.dart';

/// "Days Together" streak counter card matching Behance design
/// Shows large number display with "Days Together" label
class DaysTogetherCard extends StatelessWidget {
  final int dayCount;
  final VoidCallback? onTap;

  const DaysTogetherCard({
    super.key,
    required this.dayCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: MoodTheme.spacingLg,
          vertical: MoodTheme.spacingMd,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: MoodTheme.borderRadiusLg,
          boxShadow: MoodTheme.softShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Large number
            Text(
              '$dayCount',
              style: TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.w700,
                color: MoodTheme.textPrimary,
                height: 1.0,
                letterSpacing: -2,
              ),
            ),
            const SizedBox(height: 4),
            // Label
            Text(
              'Days Together',
              style: MoodTheme.titleMd.copyWith(
                color: MoodTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact version for home screen row
class DaysTogetherCompact extends StatelessWidget {
  final int dayCount;

  const DaysTogetherCompact({
    super.key,
    required this.dayCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(MoodTheme.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: MoodTheme.borderRadiusMd,
        boxShadow: MoodTheme.softShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$dayCount',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w700,
              color: MoodTheme.textPrimary,
              height: 1.0,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Days Together',
            style: MoodTheme.caption.copyWith(
              color: MoodTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
