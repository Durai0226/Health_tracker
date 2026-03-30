import 'package:flutter/material.dart';
import '../theme/mood_theme.dart';
import 'bloom_glass_container.dart';

/// Stats card for displaying mood analytics
class MoodStatsCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color? accentColor;
  final VoidCallback? onTap;

  const MoodStatsCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? MoodTheme.primary;

    return BloomAnimatedGlassCard(
      onTap: onTap,
      accentColor: color,
      padding: const EdgeInsets.all(MoodTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon and title row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: MoodTheme.borderRadiusSm,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: MoodTheme.spacingSm),
              Expanded(
                child: Text(
                  title,
                  style: MoodTheme.bodySm.copyWith(
                    color: MoodTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: MoodTheme.spacingMd),
          
          // Value
          Text(
            value,
            style: MoodTheme.headingLg.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          // Subtitle
          if (subtitle != null) ...[
            const SizedBox(height: MoodTheme.spacingXs),
            Text(
              subtitle!,
              style: MoodTheme.caption.copyWith(
                color: MoodTheme.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Streak card with fire animation
class StreakCard extends StatefulWidget {
  final int currentStreak;
  final int longestStreak;
  final String motivationalMessage;
  final VoidCallback? onTap;

  const StreakCard({
    super.key,
    required this.currentStreak,
    required this.longestStreak,
    required this.motivationalMessage,
    this.onTap,
  });

  @override
  State<StreakCard> createState() => _StreakCardState();
}

class _StreakCardState extends State<StreakCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final streakColor = widget.currentStreak > 0
        ? const Color(0xFFFF6B35) // Fire orange
        : MoodTheme.textMuted;

    return BloomAnimatedGlassCard(
      onTap: widget.onTap,
      accentColor: streakColor,
      padding: const EdgeInsets.all(MoodTheme.spacingLg),
      child: Row(
        children: [
          // Animated fire emoji
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: widget.currentStreak > 0 ? _pulseAnimation.value : 1.0,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        streakColor.withOpacity(0.3),
                        streakColor.withOpacity(0.1),
                      ],
                    ),
                    boxShadow: widget.currentStreak > 0
                        ? [
                            BoxShadow(
                              color: streakColor.withOpacity(0.4),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      widget.currentStreak > 0 ? '🔥' : '⭐',
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: MoodTheme.spacingMd),
          
          // Streak info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${widget.currentStreak}',
                      style: MoodTheme.headingXl.copyWith(
                        color: streakColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.currentStreak == 1 ? 'Day' : 'Days',
                      style: MoodTheme.titleMd.copyWith(
                        color: MoodTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  widget.motivationalMessage,
                  style: MoodTheme.bodySm.copyWith(
                    color: MoodTheme.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  'Best: ${widget.longestStreak} days',
                  style: MoodTheme.caption.copyWith(
                    color: MoodTheme.textMuted,
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

/// Quick action button with gradient
class MoodQuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final bool isPrimary;

  const MoodQuickActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final buttonColor = color ?? MoodTheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: MoodTheme.borderRadiusMd,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MoodTheme.spacingMd,
            vertical: MoodTheme.spacingSm,
          ),
          decoration: BoxDecoration(
            gradient: isPrimary
                ? LinearGradient(
                    colors: [buttonColor, buttonColor.withOpacity(0.8)],
                  )
                : null,
            color: isPrimary ? null : buttonColor.withOpacity(0.1),
            borderRadius: MoodTheme.borderRadiusMd,
            border: isPrimary
                ? null
                : Border.all(
                    color: buttonColor.withOpacity(0.3),
                    width: 1,
                  ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isPrimary ? Colors.white : buttonColor,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: MoodTheme.titleSm.copyWith(
                  color: isPrimary ? Colors.white : buttonColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
