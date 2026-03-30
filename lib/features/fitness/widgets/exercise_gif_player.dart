import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/fitness_theme.dart';

/// GIF player for exercise demonstrations
/// Displays animated GIFs from ExerciseDB with loading/error states
class ExerciseGifPlayer extends StatefulWidget {
  final String? gifUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final bool showControls;

  const ExerciseGifPlayer({
    super.key,
    this.gifUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.backgroundColor,
    this.borderRadius,
    this.showControls = false,
  });

  @override
  State<ExerciseGifPlayer> createState() => _ExerciseGifPlayerState();
}

class _ExerciseGifPlayerState extends State<ExerciseGifPlayer> {
  bool _isPaused = false;

  bool get hasValidSource => widget.gifUrl != null && widget.gifUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? FitnessTheme.borderRadiusMd;

    if (!hasValidSource) {
      return _buildPlaceholder(radius);
    }

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? FitnessTheme.surface,
        borderRadius: radius,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // GIF Image
            GestureDetector(
              onTap: widget.showControls ? _togglePause : null,
              child: _isPaused
                  ? _buildPausedFrame()
                  : CachedNetworkImage(
                      imageUrl: widget.gifUrl!,
                      fit: widget.fit,
                      placeholder: (context, url) => _buildLoadingState(),
                      errorWidget: (context, url, error) => _buildErrorState(),
                    ),
            ),

            // Play/Pause overlay
            if (widget.showControls && _isPaused)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _togglePause,
                  child: Container(
                    color: Colors.black38,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: FitnessTheme.primary.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Controls hint
            if (widget.showControls && !_isPaused)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app, color: Colors.white70, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Tap to pause',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });
  }

  Widget _buildPausedFrame() {
    // Show first frame when paused (static image)
    return CachedNetworkImage(
      imageUrl: widget.gifUrl!,
      fit: widget.fit,
      placeholder: (context, url) => _buildLoadingState(),
      errorWidget: (context, url, error) => _buildErrorState(),
      // Use memory cache to show static frame
      memCacheWidth: 1,
    );
  }

  Widget _buildLoadingState() {
    return Container(
      color: widget.backgroundColor ?? FitnessTheme.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(
                  FitnessTheme.primary.withOpacity(0.7),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Loading demo...',
              style: FitnessTheme.caption.copyWith(
                color: FitnessTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      color: widget.backgroundColor ?? FitnessTheme.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FitnessTheme.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 32,
                color: FitnessTheme.error.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Demo unavailable',
              style: FitnessTheme.caption.copyWith(
                color: FitnessTheme.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Follow instructions below',
              style: FitnessTheme.caption.copyWith(
                color: FitnessTheme.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BorderRadius radius) {
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
        borderRadius: radius,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
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
        ],
      ),
    );
  }
}

/// Compact GIF player for list items
class ExerciseGifThumbnail extends StatelessWidget {
  final String? gifUrl;
  final double size;
  final BorderRadius? borderRadius;

  const ExerciseGifThumbnail({
    super.key,
    this.gifUrl,
    this.size = 60,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(12);

    if (gifUrl == null || gifUrl!.isEmpty) {
      return _buildPlaceholder(radius);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        color: FitnessTheme.surface,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: CachedNetworkImage(
          imageUrl: gifUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: FitnessTheme.surface,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(
                    FitnessTheme.primary.withOpacity(0.5),
                  ),
                ),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: FitnessTheme.surface,
            child: Icon(
              Icons.fitness_center,
              size: size * 0.4,
              color: FitnessTheme.primary.withOpacity(0.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BorderRadius radius) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        color: FitnessTheme.surface,
      ),
      child: Icon(
        Icons.fitness_center,
        size: size * 0.4,
        color: FitnessTheme.primary.withOpacity(0.5),
      ),
    );
  }
}
