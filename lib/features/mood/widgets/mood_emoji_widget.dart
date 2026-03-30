import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/mood_theme.dart';
import '../models/mood_type.dart';

/// Large animated 3D emoji widget for mood selection
/// Enhanced with gradient backgrounds, glow effects, and smooth animations
class MoodEmojiWidget extends StatefulWidget {
  final MoodType mood;
  final double size;
  final bool isSelected;
  final bool showLabel;
  final bool showGlow;
  final bool show3DEffect;
  final VoidCallback? onTap;

  const MoodEmojiWidget({
    super.key,
    required this.mood,
    this.size = 72,
    this.isSelected = false,
    this.showLabel = true,
    this.showGlow = true,
    this.show3DEffect = true,
    this.onTap,
  });

  @override
  State<MoodEmojiWidget> createState() => _MoodEmojiWidgetState();
}

class _MoodEmojiWidgetState extends State<MoodEmojiWidget>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _pulseController;
  late AnimationController _floatController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    
    // Scale bounce animation
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    // Pulse glow animation (continuous when selected)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Subtle float animation for 3D effect
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _floatAnimation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    if (widget.isSelected) {
      _scaleController.forward();
      _pulseController.repeat(reverse: true);
      if (widget.show3DEffect) _floatController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(MoodEmojiWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _scaleController.forward(from: 0);
        _pulseController.repeat(reverse: true);
        if (widget.show3DEffect) _floatController.repeat(reverse: true);
      } else {
        _scaleController.reverse();
        _pulseController.stop();
        _floatController.stop();
      }
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _pulseController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moodColor = MoodTheme.getMoodColor(widget.mood.value);
    final moodLightColor = MoodTheme.getMoodLightColor(widget.mood.value);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap?.call();
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_scaleAnimation, _pulseAnimation, _floatAnimation]),
        builder: (context, child) {
          final floatOffset = widget.isSelected && widget.show3DEffect 
              ? _floatAnimation.value 
              : 0.0;
          
          return Transform.translate(
            offset: Offset(0, floatOffset),
            child: Transform.scale(
              scale: widget.isSelected ? _scaleAnimation.value : 1.0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 3D Emoji container with enhanced effects
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer glow ring (pulsing)
                      if (widget.isSelected && widget.showGlow)
                        Container(
                          width: widget.size + 40,
                          height: widget.size + 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                moodColor.withOpacity(0.3 * _pulseAnimation.value),
                                moodColor.withOpacity(0.1 * _pulseAnimation.value),
                                Colors.transparent,
                              ],
                              stops: const [0.4, 0.7, 1.0],
                            ),
                          ),
                        ),
                      // Main emoji container
                      Container(
                        width: widget.size + 24,
                        height: widget.size + 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: widget.isSelected
                              ? LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    moodLightColor,
                                    moodLightColor.withOpacity(0.7),
                                  ],
                                )
                              : null,
                          color: widget.isSelected ? null : Colors.transparent,
                          border: widget.isSelected
                              ? Border.all(
                                  color: moodColor.withOpacity(0.3),
                                  width: 2,
                                )
                              : null,
                          boxShadow: widget.isSelected
                              ? [
                                  BoxShadow(
                                    color: moodColor.withOpacity(0.25),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 4),
                                  ),
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.8),
                                    blurRadius: 8,
                                    spreadRadius: -2,
                                    offset: const Offset(-2, -2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Transform(
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001)
                              ..rotateX(widget.isSelected ? 0.05 : 0)
                              ..rotateY(widget.isSelected ? -0.05 : 0),
                            alignment: Alignment.center,
                            child: Text(
                              widget.mood.emoji,
                              style: TextStyle(
                                fontSize: widget.size,
                                height: 1.1,
                                shadows: widget.isSelected && widget.show3DEffect
                                    ? [
                                        Shadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 8,
                                          offset: const Offset(2, 4),
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Label with animated color
                  if (widget.showLabel) ...[
                    const SizedBox(height: MoodTheme.spacingSm),
                    AnimatedDefaultTextStyle(
                      duration: MoodTheme.animationFast,
                      style: MoodTheme.titleSm.copyWith(
                        color: widget.isSelected
                            ? moodColor
                            : MoodTheme.textSecondary,
                        fontWeight: widget.isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                      child: Text(widget.mood.label),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Horizontal mood selector with all mood options
class MoodSelector extends StatelessWidget {
  final MoodType? selectedMood;
  final ValueChanged<MoodType> onMoodSelected;
  final bool showAllMoods;
  final double emojiSize;

  const MoodSelector({
    super.key,
    this.selectedMood,
    required this.onMoodSelected,
    this.showAllMoods = false,
    this.emojiSize = 48,
  });

  @override
  Widget build(BuildContext context) {
    final moods = showAllMoods ? MoodType.allMoods : MoodType.primaryMoods;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: MoodTheme.spacingMd),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: moods.map((mood) {
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MoodTheme.spacingSm,
            ),
            child: MoodEmojiWidget(
              mood: mood,
              size: emojiSize,
              isSelected: selectedMood == mood,
              onTap: () => onMoodSelected(mood),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Compact mood indicator for lists/calendar
class MoodIndicator extends StatelessWidget {
  final MoodType mood;
  final double size;
  final bool showEmoji;

  const MoodIndicator({
    super.key,
    required this.mood,
    this.size = 32,
    this.showEmoji = true,
  });

  @override
  Widget build(BuildContext context) {
    final moodColor = MoodTheme.getMoodColor(mood.value);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: moodColor.withOpacity(0.2),
        border: Border.all(
          color: moodColor,
          width: 2,
        ),
      ),
      child: Center(
        child: showEmoji
            ? Text(
                mood.emoji,
                style: TextStyle(fontSize: size * 0.5),
              )
            : null,
      ),
    );
  }
}

/// Mood badge for displaying mood with color
class MoodBadge extends StatelessWidget {
  final MoodType mood;
  final bool compact;

  const MoodBadge({
    super.key,
    required this.mood,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final moodColor = MoodTheme.getMoodColor(mood.value);
    final moodLightColor = MoodTheme.getMoodLightColor(mood.value);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: moodLightColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: moodColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            mood.emoji,
            style: TextStyle(fontSize: compact ? 14 : 18),
          ),
          if (!compact) ...[
            const SizedBox(width: 6),
            Text(
              mood.label,
              style: MoodTheme.titleSm.copyWith(
                color: moodColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
