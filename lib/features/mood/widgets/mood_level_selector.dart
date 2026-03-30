import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/quick_mood_level.dart';
import '../theme/mood_theme.dart';

/// Horizontal 5-level mood selector matching Behance design
/// Shows: Awful, Bad, Ok, Good, Great with cute 3D emojis
class MoodLevelSelector extends StatefulWidget {
  final QuickMoodLevel? selectedLevel;
  final ValueChanged<QuickMoodLevel> onLevelSelected;
  final double emojiSize;
  final bool showLabels;
  final bool animated;

  const MoodLevelSelector({
    super.key,
    this.selectedLevel,
    required this.onLevelSelected,
    this.emojiSize = 56,
    this.showLabels = true,
    this.animated = true,
  });

  @override
  State<MoodLevelSelector> createState() => _MoodLevelSelectorState();
}

class _MoodLevelSelectorState extends State<MoodLevelSelector>
    with TickerProviderStateMixin {
  late List<AnimationController> _scaleControllers;
  late List<Animation<double>> _scaleAnimations;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _scaleControllers = List.generate(
      5,
      (index) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 200),
      ),
    );

    _scaleAnimations = _scaleControllers.map((controller) {
      return Tween<double>(begin: 1.0, end: 1.15).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOutBack),
      );
    }).toList();
  }

  @override
  void dispose() {
    for (var controller in _scaleControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onMoodTap(QuickMoodLevel level, int index) {
    HapticFeedback.mediumImpact();
    
    // Animate the tapped emoji
    _scaleControllers[index].forward().then((_) {
      _scaleControllers[index].reverse();
    });

    widget.onLevelSelected(level);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate emoji size based on available width
        final availableWidth = constraints.maxWidth;
        final itemCount = QuickMoodLevel.values.length;
        final maxItemWidth = availableWidth / itemCount;
        final adjustedEmojiSize = (maxItemWidth - 24).clamp(32.0, widget.emojiSize);
        
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: QuickMoodLevel.values.asMap().entries.map((entry) {
            final index = entry.key;
            final level = entry.value;
            final isSelected = widget.selectedLevel == level;

            return Flexible(
              child: AnimatedBuilder(
                animation: _scaleAnimations[index],
                builder: (context, child) {
                  return Transform.scale(
                    scale: isSelected ? _scaleAnimations[index].value : 1.0,
                    child: _MoodLevelItem(
                      level: level,
                      isSelected: isSelected,
                      emojiSize: adjustedEmojiSize,
                      showLabel: widget.showLabels,
                      onTap: () => _onMoodTap(level, index),
                    ),
                  );
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _MoodLevelItem extends StatelessWidget {
  final QuickMoodLevel level;
  final bool isSelected;
  final double emojiSize;
  final bool showLabel;
  final VoidCallback onTap;

  const _MoodLevelItem({
    required this.level,
    required this.isSelected,
    required this.emojiSize,
    required this.showLabel,
    required this.onTap,
  });

  Color get _levelColor {
    switch (level) {
      case QuickMoodLevel.awful:
        return const Color(0xFFE57373);
      case QuickMoodLevel.bad:
        return const Color(0xFFFFB74D);
      case QuickMoodLevel.ok:
        return const Color(0xFFFFD54F);
      case QuickMoodLevel.good:
        return const Color(0xFF81C784);
      case QuickMoodLevel.great:
        return const Color(0xFFFFD93D);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Emoji container with glow effect when selected
          AnimatedContainer(
            duration: MoodTheme.animationNormal,
            curve: Curves.easeOutCubic,
            width: emojiSize + 16,
            height: emojiSize + 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected 
                  ? _levelColor.withOpacity(0.15) 
                  : Colors.transparent,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: _levelColor.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: MoodTheme.animationNormal,
                style: TextStyle(
                  fontSize: isSelected ? emojiSize * 1.1 : emojiSize * 0.9,
                  height: 1.0,
                ),
                child: Text(level.emoji),
              ),
            ),
          ),
          
          // Label
          if (showLabel) ...[
            const SizedBox(height: 8),
            AnimatedDefaultTextStyle(
              duration: MoodTheme.animationNormal,
              style: MoodTheme.bodySm.copyWith(
                color: isSelected ? _levelColor : MoodTheme.textMuted,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              child: Text(level.label),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact inline mood level indicator (shows just emoji + label)
class MoodLevelIndicator extends StatelessWidget {
  final QuickMoodLevel level;
  final double size;

  const MoodLevelIndicator({
    super.key,
    required this.level,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          level.emoji,
          style: TextStyle(fontSize: size),
        ),
        const SizedBox(width: 6),
        Text(
          level.label,
          style: MoodTheme.titleSm.copyWith(
            color: MoodTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Large animated emoji for selected mood display
class MoodLevelDisplay extends StatefulWidget {
  final QuickMoodLevel level;
  final double size;
  final bool animate;

  const MoodLevelDisplay({
    super.key,
    required this.level,
    this.size = 80,
    this.animate = true,
  });

  @override
  State<MoodLevelDisplay> createState() => _MoodLevelDisplayState();
}

class _MoodLevelDisplayState extends State<MoodLevelDisplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    if (widget.animate) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color get _glowColor {
    switch (widget.level) {
      case QuickMoodLevel.awful:
        return const Color(0xFFE57373);
      case QuickMoodLevel.bad:
        return const Color(0xFFFFB74D);
      case QuickMoodLevel.ok:
        return const Color(0xFFFFD54F);
      case QuickMoodLevel.good:
        return const Color(0xFF81C784);
      case QuickMoodLevel.great:
        return const Color(0xFFFFD93D);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.animate ? _pulseAnimation.value : 1.0,
          child: Container(
            width: widget.size + 24,
            height: widget.size + 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _glowColor.withOpacity(0.2),
                  _glowColor.withOpacity(0.05),
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _glowColor.withOpacity(0.3),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: Text(
                widget.level.emoji,
                style: TextStyle(fontSize: widget.size),
              ),
            ),
          ),
        );
      },
    );
  }
}
