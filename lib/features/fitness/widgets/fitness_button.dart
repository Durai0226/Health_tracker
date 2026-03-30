import 'package:flutter/material.dart';
import '../theme/fitness_theme.dart';

/// Primary button with neon glow effect
class FitnessPrimaryButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isEnabled;
  final IconData? icon;
  final double? width;
  final double? height;

  const FitnessPrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.icon,
    this.width,
    this.height,
  });

  @override
  State<FitnessPrimaryButton> createState() => _FitnessPrimaryButtonState();
}

class _FitnessPrimaryButtonState extends State<FitnessPrimaryButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.isEnabled && !widget.isLoading) {
      setState(() => _isPressed = true);
      _controller.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = !widget.isEnabled || widget.isLoading;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: isDisabled ? null : widget.onPressed,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.width ?? double.infinity,
              height: widget.height ?? 56,
              decoration: BoxDecoration(
                gradient: isDisabled
                    ? LinearGradient(
                        colors: [
                          FitnessTheme.primary.withOpacity(0.3),
                          FitnessTheme.primaryDark.withOpacity(0.3),
                        ],
                      )
                    : FitnessTheme.primaryGradient,
                borderRadius: FitnessTheme.borderRadiusMd,
                boxShadow: isDisabled
                    ? null
                    : [
                        BoxShadow(
                          color: FitnessTheme.primary.withOpacity(_isPressed ? 0.5 : 0.3),
                          blurRadius: _isPressed ? 25 : 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
              ),
              child: Center(
                child: widget.isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(FitnessTheme.textOnPrimary),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(
                              widget.icon,
                              color: FitnessTheme.textOnPrimary,
                              size: 20,
                            ),
                            const SizedBox(width: FitnessTheme.spacingSm),
                          ],
                          Text(
                            widget.text,
                            style: FitnessTheme.button,
                          ),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Secondary outline button
class FitnessOutlineButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final Color? color;
  final double? width;
  final double? height;

  const FitnessOutlineButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.color,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final buttonColor = color ?? FitnessTheme.primary;

    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Container(
        width: width ?? double.infinity,
        height: height ?? 56,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: FitnessTheme.borderRadiusMd,
          border: Border.all(color: buttonColor, width: 2),
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(buttonColor),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: buttonColor, size: 20),
                      const SizedBox(width: FitnessTheme.spacingSm),
                    ],
                    Text(
                      text,
                      style: FitnessTheme.button.copyWith(color: buttonColor),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Icon button with circle background
class FitnessIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? iconColor;
  final double size;
  final bool showGlow;

  const FitnessIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.backgroundColor,
    this.iconColor,
    this.size = 48,
    this.showGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ?? FitnessTheme.surface,
          shape: BoxShape.circle,
          boxShadow: showGlow
              ? [
                  BoxShadow(
                    color: (iconColor ?? FitnessTheme.primary).withOpacity(0.4),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          color: iconColor ?? FitnessTheme.textPrimary,
          size: size * 0.5,
        ),
      ),
    );
  }
}

/// Floating action button for workouts
class FitnessFloatingButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? label;

  const FitnessFloatingButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: label != null ? FitnessTheme.spacingMd : FitnessTheme.spacingMd,
          vertical: FitnessTheme.spacingMd,
        ),
        decoration: BoxDecoration(
          gradient: FitnessTheme.primaryGradient,
          borderRadius: label != null
              ? FitnessTheme.borderRadiusRound
              : BorderRadius.circular(100),
          boxShadow: FitnessTheme.primaryShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: FitnessTheme.textOnPrimary),
            if (label != null) ...[
              const SizedBox(width: FitnessTheme.spacingSm),
              Text(
                label!,
                style: FitnessTheme.button,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Chip/Tag button
class FitnessChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final Color? color;
  final IconData? icon;

  const FitnessChip({
    super.key,
    required this.label,
    this.isSelected = false,
    this.onTap,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? FitnessTheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: FitnessTheme.animationFast,
        padding: const EdgeInsets.symmetric(
          horizontal: FitnessTheme.spacingMd,
          vertical: FitnessTheme.spacingSm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : Colors.transparent,
          borderRadius: FitnessTheme.borderRadiusRound,
          border: Border.all(
            color: isSelected ? chipColor : FitnessTheme.textMuted,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected ? FitnessTheme.textOnPrimary : FitnessTheme.textSecondary,
              ),
              const SizedBox(width: FitnessTheme.spacingXs),
            ],
            Text(
              label,
              style: FitnessTheme.titleSm.copyWith(
                color: isSelected ? FitnessTheme.textOnPrimary : FitnessTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Workout control button (play, pause, skip)
class WorkoutControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final double size;
  final Color? color;

  const WorkoutControlButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.isPrimary = false,
    this.size = 64,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: isPrimary ? FitnessTheme.primaryGradient : null,
          color: isPrimary ? null : (color ?? FitnessTheme.surface),
          shape: BoxShape.circle,
          border: isPrimary
              ? null
              : Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 2,
                ),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: FitnessTheme.primary.withOpacity(0.4),
                    blurRadius: 25,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          color: isPrimary ? FitnessTheme.textOnPrimary : FitnessTheme.textPrimary,
          size: size * 0.45,
        ),
      ),
    );
  }
}
