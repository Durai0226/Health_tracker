import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Premium water insights card with streak system
/// Glassmorphism design with smooth animations
class WaterInsightsCard extends StatefulWidget {
  final int currentStreak;
  final int longestStreak;
  final double todayProgress;
  final int todayCaffeine;
  final int todayAlcohol;
  final int avgDailyMl;
  final int goalMl;
  final VoidCallback? onTapDetails;

  const WaterInsightsCard({
    super.key,
    required this.currentStreak,
    required this.longestStreak,
    required this.todayProgress,
    this.todayCaffeine = 0,
    this.todayAlcohol = 0,
    this.avgDailyMl = 0,
    this.goalMl = 2000,
    this.onTapDetails,
  });

  @override
  State<WaterInsightsCard> createState() => _WaterInsightsCardState();
}

class _WaterInsightsCardState extends State<WaterInsightsCard>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shimmerController.dispose();
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
                      Colors.purple.shade400,
                      Colors.pink.shade400,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.insights,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Smart Insights',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (widget.onTapDetails != null)
                GestureDetector(
                  onTap: widget.onTapDetails,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.purple.shade400,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Streak card
        _buildStreakCard(),
        const SizedBox(height: 12),
        // Insights row
        Row(
          children: [
            Expanded(child: _buildCaffeineCard()),
            const SizedBox(width: 12),
            Expanded(child: _buildHydrationScoreCard()),
          ],
        ),
        const SizedBox(height: 12),
        // Tips card
        _buildTipsCard(),
      ],
    );
  }

  Widget _buildStreakCard() {
    final isOnStreak = widget.currentStreak > 0;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = isOnStreak ? 1.0 + (_pulseController.value * 0.02) : 1.0;
        return Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isOnStreak
                    ? [
                        Colors.orange.shade400,
                        Colors.deepOrange.shade400,
                      ]
                    : [
                        Colors.grey.shade300,
                        Colors.grey.shade400,
                      ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (isOnStreak ? Colors.orange : Colors.grey)
                      .withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                // Streak fire icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      isOnStreak ? '🔥' : '💤',
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Streak info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isOnStreak ? 'Current Streak' : 'Start Your Streak!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${widget.currentStreak}',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              widget.currentStreak == 1 ? 'day' : 'days',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Best streak
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Best',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    Row(
                      children: [
                        const Text('🏆', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.longestStreak}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCaffeineCard() {
    final caffeineLevel = _getCaffeineLevel();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                caffeineLevel.emoji,
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 8),
              Text(
                'Caffeine',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.todayCaffeine} mg',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: caffeineLevel.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              caffeineLevel.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: caffeineLevel.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHydrationScoreCard() {
    final score = _calculateHydrationScore();
    final scoreColor = _getScoreColor(score);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('💯', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                'Score',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$score',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: scoreColor,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '/100',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Score bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(scoreColor),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsCard() {
    final tip = _getSmartTip();

    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade50,
                Colors.cyan.shade50,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  tip.emoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tip.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tip.message,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  _CaffeineLevel _getCaffeineLevel() {
    if (widget.todayCaffeine == 0) {
      return _CaffeineLevel('☕', 'None', Colors.grey);
    } else if (widget.todayCaffeine < 100) {
      return _CaffeineLevel('☕', 'Low', Colors.green);
    } else if (widget.todayCaffeine < 200) {
      return _CaffeineLevel('☕', 'Moderate', Colors.orange);
    } else if (widget.todayCaffeine < 400) {
      return _CaffeineLevel('⚡', 'High', Colors.deepOrange);
    } else {
      return _CaffeineLevel('⚠️', 'Very High', Colors.red);
    }
  }

  int _calculateHydrationScore() {
    double score = 0;

    // Progress contribution (50 points max)
    score += (widget.todayProgress.clamp(0.0, 1.0) * 50);

    // Streak bonus (20 points max)
    score += math.min(widget.currentStreak * 2, 20);

    // Average consistency bonus (15 points max)
    if (widget.avgDailyMl > 0) {
      final avgRatio = widget.avgDailyMl / widget.goalMl;
      score += math.min(avgRatio * 15, 15);
    }

    // Caffeine penalty (up to -10 points)
    if (widget.todayCaffeine > 400) {
      score -= 10;
    } else if (widget.todayCaffeine > 200) {
      score -= 5;
    }

    // Alcohol penalty (up to -15 points)
    score -= math.min(widget.todayAlcohol * 5, 15);

    return score.clamp(0, 100).round();
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.lightGreen;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  _SmartTip _getSmartTip() {
    final hour = DateTime.now().hour;

    // Morning tips
    if (hour >= 6 && hour < 10) {
      if (widget.todayProgress < 0.1) {
        return _SmartTip(
          '🌅',
          'Start Your Day Right',
          'Drink a glass of water to boost your metabolism!',
        );
      }
    }

    // Midday tips
    if (hour >= 11 && hour < 14) {
      if (widget.todayProgress < 0.4) {
        return _SmartTip(
          '☀️',
          'Stay Hydrated',
          'You should be at 40% by now. Time to catch up!',
        );
      }
    }

    // Afternoon tips
    if (hour >= 14 && hour < 18) {
      if (widget.todayCaffeine > 200) {
        return _SmartTip(
          '🍃',
          'Balance Your Caffeine',
          'Try switching to herbal tea for better hydration.',
        );
      }
    }

    // Evening tips
    if (hour >= 18 && hour < 22) {
      if (widget.todayProgress < 0.8) {
        return _SmartTip(
          '🌙',
          'Final Push',
          'Drink water now, but ease off before bed.',
        );
      }
    }

    // Streak tips
    if (widget.currentStreak > 0 && widget.currentStreak % 7 == 0) {
      return _SmartTip(
        '🎉',
        'Week Milestone!',
        '${widget.currentStreak} days strong! Keep going!',
      );
    }

    // Default tip based on progress
    if (widget.todayProgress >= 1.0) {
      return _SmartTip(
        '🏆',
        'Goal Achieved!',
        'Amazing job! You\'ve hit your daily target!',
      );
    }

    return _SmartTip(
      '💧',
      'Stay Consistent',
      'Regular small sips are better than large gulps.',
    );
  }
}

class _CaffeineLevel {
  final String emoji;
  final String label;
  final Color color;

  _CaffeineLevel(this.emoji, this.label, this.color);
}

class _SmartTip {
  final String emoji;
  final String title;
  final String message;

  _SmartTip(this.emoji, this.title, this.message);
}

/// Compact streak widget for header usage
class CompactStreakWidget extends StatelessWidget {
  final int streak;
  final bool isActive;

  const CompactStreakWidget({
    super.key,
    required this.streak,
    this.isActive = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: isActive
            ? LinearGradient(
                colors: [Colors.orange.shade400, Colors.deepOrange.shade400],
              )
            : null,
        color: isActive ? null : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isActive ? '🔥' : '💤',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 6),
          Text(
            '$streak',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.white : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
