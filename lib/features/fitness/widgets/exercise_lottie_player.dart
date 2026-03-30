import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../theme/fitness_theme.dart';

/// Lottie animation player for exercise demonstrations
class ExerciseLottiePlayer extends StatefulWidget {
  final String? assetPath;
  final String? networkUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool autoPlay;
  final bool loop;
  final bool showControls;
  final Color? backgroundColor;
  final Widget? placeholder;
  final Widget? errorWidget;

  const ExerciseLottiePlayer({
    super.key,
    this.assetPath,
    this.networkUrl,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.autoPlay = true,
    this.loop = true,
    this.showControls = false,
    this.backgroundColor,
    this.placeholder,
    this.errorWidget,
  });
  
  /// Check if valid lottie source is available
  bool get hasValidSource => assetPath != null || networkUrl != null;

  @override
  State<ExerciseLottiePlayer> createState() => _ExerciseLottiePlayerState();
}

class _ExerciseLottiePlayerState extends State<ExerciseLottiePlayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isPlaying = true;
  bool _hasError = false;
  bool _isLoading = true;
  int _retryCount = 0;
  static const int _maxRetries = 2;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _isPlaying = widget.autoPlay;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_isPlaying) {
        _controller.stop();
      } else {
        _controller.repeat();
      }
      _isPlaying = !_isPlaying;
    });
  }

  void _onLoaded(LottieComposition composition) {
    if (!mounted) return;
    setState(() => _isLoading = false);
    _controller.duration = composition.duration;
    if (widget.autoPlay) {
      if (widget.loop) {
        _controller.repeat();
      } else {
        _controller.forward();
      }
    }
  }

  void _retry() {
    if (_retryCount < _maxRetries) {
      setState(() {
        _hasError = false;
        _isLoading = true;
        _retryCount++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? FitnessTheme.surface,
        borderRadius: FitnessTheme.borderRadiusMd,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Lottie animation
          ClipRRect(
            borderRadius: FitnessTheme.borderRadiusMd,
            child: _buildLottie(),
          ),
          // Play/Pause controls
          if (widget.showControls && !_hasError)
            Positioned(
              bottom: FitnessTheme.spacingSm,
              right: FitnessTheme.spacingSm,
              child: GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: FitnessTheme.background.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: FitnessTheme.textPrimary,
                    size: 20,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLottie() {
    if (_hasError || !widget.hasValidSource) {
      return widget.errorWidget ?? _buildErrorWidget();
    }

    if (widget.assetPath != null) {
      return Lottie.asset(
        widget.assetPath!,
        controller: _controller,
        onLoaded: _onLoaded,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _hasError = true);
          });
          return widget.errorWidget ?? _buildErrorWidget();
        },
        frameBuilder: (context, child, composition) {
          if (composition == null) {
            return widget.placeholder ?? _buildPlaceholder();
          }
          return child;
        },
      );
    }

    if (widget.networkUrl != null) {
      return Lottie.network(
        widget.networkUrl!,
        controller: _controller,
        onLoaded: _onLoaded,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _hasError = true);
          });
          return widget.errorWidget ?? _buildErrorWidget();
        },
        frameBuilder: (context, child, composition) {
          if (composition == null) {
            return widget.placeholder ?? _buildPlaceholder();
          }
          return child;
        },
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: FitnessTheme.surface,
        borderRadius: FitnessTheme.borderRadiusMd,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(
                FitnessTheme.primary.withOpacity(0.7),
              ),
            ),
          ),
          const SizedBox(height: FitnessTheme.spacingMd),
          Text(
            'Loading animation...',
            style: FitnessTheme.caption.copyWith(
              color: FitnessTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FitnessTheme.surface,
            FitnessTheme.surface.withOpacity(0.8),
          ],
        ),
        borderRadius: FitnessTheme.borderRadiusMd,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated exercise icon
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.9, end: 1.1),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeInOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: FitnessTheme.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.fitness_center,
                    size: 48,
                    color: FitnessTheme.primary.withOpacity(0.7),
                  ),
                ),
              );
            },
            onEnd: () {
              // Restart animation
              if (mounted) setState(() {});
            },
          ),
          const SizedBox(height: FitnessTheme.spacingMd),
          Text(
            'Exercise Demo',
            style: FitnessTheme.titleSm.copyWith(
              color: FitnessTheme.textSecondary,
            ),
          ),
          const SizedBox(height: FitnessTheme.spacingXs),
          Text(
            'Follow the instructions below',
            style: FitnessTheme.caption.copyWith(
              color: FitnessTheme.textMuted,
            ),
          ),
          // Retry button if retries available
          if (_retryCount < _maxRetries && widget.hasValidSource) ...[
            const SizedBox(height: FitnessTheme.spacingMd),
            GestureDetector(
              onTap: _retry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: FitnessTheme.spacingMd,
                  vertical: FitnessTheme.spacingSm,
                ),
                decoration: BoxDecoration(
                  color: FitnessTheme.primary.withOpacity(0.2),
                  borderRadius: FitnessTheme.borderRadiusSm,
                  border: Border.all(
                    color: FitnessTheme.primary.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.refresh,
                      size: 16,
                      color: FitnessTheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Retry',
                      style: FitnessTheme.caption.copyWith(
                        color: FitnessTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact exercise thumbnail with Lottie
class ExerciseThumbnail extends StatelessWidget {
  final String? assetPath;
  final String? networkUrl;
  final double size;
  final Color? backgroundColor;

  const ExerciseThumbnail({
    super.key,
    this.assetPath,
    this.networkUrl,
    this.size = 56,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? FitnessTheme.surface,
        borderRadius: FitnessTheme.borderRadiusSm,
      ),
      child: ClipRRect(
        borderRadius: FitnessTheme.borderRadiusSm,
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (assetPath != null) {
      return Lottie.asset(
        assetPath!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildFallback(),
      );
    }

    if (networkUrl != null) {
      return Lottie.network(
        networkUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildFallback(),
      );
    }

    return _buildFallback();
  }

  Widget _buildFallback() {
    return Container(
      color: FitnessTheme.surface,
      child: Icon(
        Icons.fitness_center,
        size: size * 0.5,
        color: FitnessTheme.textMuted,
      ),
    );
  }
}

/// Full screen exercise player for active workout
class FullScreenExercisePlayer extends StatefulWidget {
  final String? assetPath;
  final String? networkUrl;
  final String exerciseName;
  final int? reps;
  final int? seconds;
  final VoidCallback? onComplete;

  const FullScreenExercisePlayer({
    super.key,
    this.assetPath,
    this.networkUrl,
    required this.exerciseName,
    this.reps,
    this.seconds,
    this.onComplete,
  });

  @override
  State<FullScreenExercisePlayer> createState() => _FullScreenExercisePlayerState();
}

class _FullScreenExercisePlayerState extends State<FullScreenExercisePlayer> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: FitnessTheme.background,
      child: Column(
        children: [
          // Exercise animation - takes most of the screen
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(FitnessTheme.spacingLg),
              child: ExerciseLottiePlayer(
                assetPath: widget.assetPath,
                networkUrl: widget.networkUrl,
                fit: BoxFit.contain,
                autoPlay: true,
                loop: true,
              ),
            ),
          ),
          // Exercise info
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: FitnessTheme.spacingLg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.exerciseName,
                    style: FitnessTheme.headingMd,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: FitnessTheme.spacingSm),
                  if (widget.reps != null)
                    Text(
                      '${widget.reps} reps',
                      style: FitnessTheme.titleLg.copyWith(
                        color: FitnessTheme.primary,
                      ),
                    )
                  else if (widget.seconds != null)
                    Text(
                      '${widget.seconds} seconds',
                      style: FitnessTheme.titleLg.copyWith(
                        color: FitnessTheme.primary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
