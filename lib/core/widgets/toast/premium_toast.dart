import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'toast_theme.dart';
import 'toast_animations.dart';
import 'toast_particles.dart';

/// Toast action button configuration
class ToastAction {
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  const ToastAction({
    required this.label,
    required this.onPressed,
    this.color,
  });
}

/// Premium toast widget with glassmorphism and animations
class PremiumToast extends StatefulWidget {
  final ToastType type;
  final ToastFeature feature;
  final String title;
  final String? message;
  final ToastAction? action;
  final Duration autoDismissDuration;
  final VoidCallback onDismiss;
  final bool showParticles;
  final bool showProgress;
  final IconData? customIcon;
  final Color? customColor;

  const PremiumToast({
    super.key,
    required this.type,
    this.feature = ToastFeature.general,
    required this.title,
    this.message,
    this.action,
    this.autoDismissDuration = const Duration(seconds: 4),
    required this.onDismiss,
    this.showParticles = false,
    this.showProgress = true,
    this.customIcon,
    this.customColor,
  });

  @override
  State<PremiumToast> createState() => _PremiumToastState();
}

class _PremiumToastState extends State<PremiumToast>
    with TickerProviderStateMixin, ToastAnimationMixin {
  late ToastThemeData _themeData;
  bool _isHovered = false;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    
    // Get theme based on feature or type
    _themeData = widget.feature != ToastFeature.general
        ? ToastTheme.getThemeForFeature(widget.feature, type: widget.type)
        : ToastTheme.getThemeForType(widget.type);

    // Override with custom color if provided
    if (widget.customColor != null) {
      _themeData = ToastThemeData(
        primaryColor: widget.customColor!,
        secondaryColor: widget.customColor!.withOpacity(0.8),
        gradient: LinearGradient(
          colors: [widget.customColor!, widget.customColor!.withOpacity(0.8)],
        ),
        icon: widget.customIcon ?? _themeData.icon,
        iconColor: widget.customColor!,
        glowShadow: [
          BoxShadow(
            color: widget.customColor!.withOpacity(0.4),
            blurRadius: 20,
          ),
        ],
      );
    }

    // Initialize animations
    initToastAnimations(
      autoDismissDuration: widget.autoDismissDuration,
      onDismiss: widget.onDismiss,
    );

    // Haptic feedback on show
    HapticFeedback.lightImpact();
  }

  @override
  void dispose() {
    disposeToastAnimations();
    super.dispose();
  }

  void _handleDismiss() {
    HapticFeedback.selectionClick();
    dismissToast(onDismiss: widget.onDismiss);
  }

  void _pauseAutoDismiss() {
    if (!_isPaused) {
      _isPaused = true;
      progressController.stop();
    }
  }

  void _resumeAutoDismiss() {
    if (_isPaused) {
      _isPaused = false;
      progressController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AnimatedBuilder(
      animation: Listenable.merge([
        entryController,
        shimmerController,
        pulseController,
        progressController,
      ]),
      builder: (context, child) {
        return SlideTransition(
          position: slideAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: ScaleTransition(
              scale: scaleAnimation,
              child: ToastDismissible(
                onDismiss: _handleDismiss,
                child: MouseRegion(
                  onEnter: (_) {
                    setState(() => _isHovered = true);
                    _pauseAutoDismiss();
                  },
                  onExit: (_) {
                    setState(() => _isHovered = false);
                    _resumeAutoDismiss();
                  },
                  child: GestureDetector(
                    onTapDown: (_) => _pauseAutoDismiss(),
                    onTapUp: (_) => _resumeAutoDismiss(),
                    onTapCancel: _resumeAutoDismiss,
                    child: _buildToastContainer(isDark),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildToastContainer(bool isDark) {
    return Container(
      constraints: const BoxConstraints(
        maxWidth: ToastTheme.maxWidth,
        minWidth: 280,
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Particle effects (if enabled)
          if (widget.showParticles)
            Positioned.fill(
              child: ParticleSystem(
                effectType: _getParticleEffect(),
                primaryColor: _themeData.primaryColor,
                secondaryColor: _themeData.secondaryColor,
                isPlaying: true,
                particleCount: 15,
              ),
            ),
          
          // Main toast body with glassmorphism
          ClipRRect(
            borderRadius: BorderRadius.circular(ToastTheme.borderRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: ToastTheme.getGlassBackground(context),
                  borderRadius: BorderRadius.circular(ToastTheme.borderRadius),
                  border: Border.all(
                    color: _isHovered
                        ? _themeData.primaryColor.withOpacity(0.5)
                        : ToastTheme.getBorderColor(context),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _themeData.primaryColor.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Content
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        ToastTheme.horizontalPadding,
                        ToastTheme.verticalPadding,
                        ToastTheme.horizontalPadding,
                        ToastTheme.verticalPadding,
                      ),
                      child: Row(
                        children: [
                          // Icon with glow
                          _buildIconSection(),
                          const SizedBox(width: 12),
                          
                          // Text content
                          Expanded(child: _buildTextSection()),
                          
                          // Action button or close
                          if (widget.action != null)
                            _buildActionButton()
                          else
                            _buildCloseButton(),
                        ],
                      ),
                    ),
                    
                    // Progress bar
                    if (widget.showProgress)
                      _buildProgressBar(),
                  ],
                ),
              ),
            ),
          ),
          
          // Shimmer border overlay
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: ShimmerBorderPainter(
                  progress: shimmerAnimation.value,
                  primaryColor: _themeData.primaryColor,
                  secondaryColor: _themeData.secondaryColor,
                  borderRadius: ToastTheme.borderRadius,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconSection() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow effect
        CustomPaint(
          size: const Size(ToastTheme.iconContainerSize, ToastTheme.iconContainerSize),
          painter: IconGlowPainter(
            pulseProgress: pulseAnimation.value,
            glowColor: _themeData.primaryColor,
            baseRadius: ToastTheme.iconContainerSize / 2 - 4,
          ),
        ),
        
        // Icon container
        Container(
          width: ToastTheme.iconContainerSize,
          height: ToastTheme.iconContainerSize,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _themeData.primaryColor.withOpacity(0.2),
                _themeData.secondaryColor.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _themeData.primaryColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Center(
            child: BouncingIcon(
              icon: widget.customIcon ?? _themeData.icon,
              color: _themeData.iconColor,
              size: ToastTheme.iconSize,
              animate: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: ToastTheme.getTextPrimary(context),
            height: 1.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (widget.message != null) ...[
          const SizedBox(height: 2),
          Text(
            widget.message!,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: ToastTheme.getTextSecondary(context),
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildActionButton() {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: TextButton(
        onPressed: () {
          HapticFeedback.selectionClick();
          widget.action!.onPressed();
          _handleDismiss();
        },
        style: TextButton.styleFrom(
          foregroundColor: widget.action!.color ?? _themeData.primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: (widget.action!.color ?? _themeData.primaryColor)
              .withOpacity(0.1),
        ),
        child: Text(
          widget.action!.label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildCloseButton() {
    return GestureDetector(
      onTap: _handleDismiss,
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.close_rounded,
          size: 18,
          color: ToastTheme.getTextSecondary(context),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return SizedBox(
      height: ToastTheme.progressHeight,
      child: CustomPaint(
        size: Size(double.infinity, ToastTheme.progressHeight),
        painter: ProgressBarPainter(
          progress: progressAnimation.value,
          primaryColor: _themeData.primaryColor,
          secondaryColor: _themeData.secondaryColor,
          height: ToastTheme.progressHeight,
        ),
      ),
    );
  }

  ParticleEffectType _getParticleEffect() {
    if (widget.type == ToastType.achievement) {
      return ParticleEffectType.celebration;
    }
    
    switch (widget.feature) {
      case ToastFeature.water:
        return ParticleEffectType.bubbles;
      case ToastFeature.focus:
        return ParticleEffectType.rings;
      case ToastFeature.finance:
        return ParticleEffectType.coins;
      case ToastFeature.habit:
        return ParticleEffectType.fire;
      default:
        return ParticleEffectType.sparkles;
    }
  }
}

/// Quick toast builder for common scenarios
class QuickToast {
  /// Show a success toast
  static PremiumToast success({
    required String title,
    String? message,
    ToastFeature feature = ToastFeature.general,
    ToastAction? action,
    required VoidCallback onDismiss,
  }) {
    return PremiumToast(
      type: ToastType.success,
      feature: feature,
      title: title,
      message: message,
      action: action,
      onDismiss: onDismiss,
    );
  }

  /// Show an error toast
  static PremiumToast error({
    required String title,
    String? message,
    ToastFeature feature = ToastFeature.general,
    ToastAction? action,
    required VoidCallback onDismiss,
  }) {
    return PremiumToast(
      type: ToastType.error,
      feature: feature,
      title: title,
      message: message,
      action: action,
      onDismiss: onDismiss,
      autoDismissDuration: const Duration(seconds: 5),
    );
  }

  /// Show a warning toast
  static PremiumToast warning({
    required String title,
    String? message,
    ToastFeature feature = ToastFeature.general,
    ToastAction? action,
    required VoidCallback onDismiss,
  }) {
    return PremiumToast(
      type: ToastType.warning,
      feature: feature,
      title: title,
      message: message,
      action: action,
      onDismiss: onDismiss,
    );
  }

  /// Show an info toast
  static PremiumToast info({
    required String title,
    String? message,
    ToastFeature feature = ToastFeature.general,
    ToastAction? action,
    required VoidCallback onDismiss,
  }) {
    return PremiumToast(
      type: ToastType.info,
      feature: feature,
      title: title,
      message: message,
      action: action,
      onDismiss: onDismiss,
    );
  }

  /// Show an achievement toast with particles
  static PremiumToast achievement({
    required String title,
    String? message,
    ToastFeature feature = ToastFeature.general,
    required VoidCallback onDismiss,
  }) {
    return PremiumToast(
      type: ToastType.achievement,
      feature: feature,
      title: title,
      message: message,
      onDismiss: onDismiss,
      showParticles: true,
      autoDismissDuration: const Duration(seconds: 5),
    );
  }

  /// Show a reminder toast
  static PremiumToast reminder({
    required String title,
    String? message,
    ToastFeature feature = ToastFeature.general,
    ToastAction? action,
    required VoidCallback onDismiss,
  }) {
    return PremiumToast(
      type: ToastType.reminder,
      feature: feature,
      title: title,
      message: message,
      action: action,
      onDismiss: onDismiss,
      autoDismissDuration: const Duration(seconds: 6),
    );
  }
}
