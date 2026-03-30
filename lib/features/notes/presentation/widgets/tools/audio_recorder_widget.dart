import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/livescribe_theme.dart';

/// Audio recording widget with waveform visualization
class AudioRecorderWidget extends StatefulWidget {
  final VoidCallback onStartRecording;
  final Function(String path, int durationMs) onStopRecording;
  final VoidCallback? onCancelRecording;
  final bool isRecording;
  final int recordingDurationMs;

  const AudioRecorderWidget({
    super.key,
    required this.onStartRecording,
    required this.onStopRecording,
    this.onCancelRecording,
    this.isRecording = false,
    this.recordingDurationMs = 0,
  });

  @override
  State<AudioRecorderWidget> createState() => _AudioRecorderWidgetState();
}

class _AudioRecorderWidgetState extends State<AudioRecorderWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  Timer? _durationTimer;
  int _currentDurationMs = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(AudioRecorderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isRecording && !oldWidget.isRecording) {
      _startRecordingUI();
    } else if (!widget.isRecording && oldWidget.isRecording) {
      _stopRecordingUI();
    }
  }

  void _startRecordingUI() {
    _currentDurationMs = 0;
    _pulseController.repeat(reverse: true);
    _durationTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      setState(() {
        _currentDurationMs += 100;
      });
    });
  }

  void _stopRecordingUI() {
    _pulseController.stop();
    _pulseController.reset();
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _durationTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(int ms) {
    final seconds = (ms / 1000).floor();
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.isRecording) {
      return _buildRecordingView(isDark);
    }
    return _buildIdleView(isDark);
  }

  Widget _buildIdleView(bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onStartRecording();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: LivescribeTheme.toolbarDecoration(isDark: isDark),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: LivescribeTheme.error,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mic_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Record Audio',
              style: LivescribeTheme.titleMedium.copyWith(
                color: isDark ? LivescribeTheme.darkTextPrimary : LivescribeTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingView(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: LivescribeTheme.toolbarDecoration(isDark: isDark),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Recording indicator
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: LivescribeTheme.error.withOpacity(0.8 + _pulseController.value * 0.2),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: LivescribeTheme.error.withOpacity(0.3 * _pulseController.value),
                      blurRadius: 12 * _pulseController.value,
                      spreadRadius: 4 * _pulseController.value,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.mic_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              );
            },
          ),
          const SizedBox(width: 12),

          // Waveform visualization
          SizedBox(
            width: 100,
            height: 30,
            child: _WaveformVisualization(
              isRecording: widget.isRecording,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 12),

          // Duration
          Text(
            _formatDuration(_currentDurationMs),
            style: LivescribeTheme.titleMedium.copyWith(
              color: LivescribeTheme.error,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 16),

          // Stop button
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              widget.onStopRecording('', _currentDurationMs);
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.stop_rounded,
                color: isDark ? LivescribeTheme.darkTextPrimary : LivescribeTheme.textPrimary,
                size: 20,
              ),
            ),
          ),

          // Cancel button
          if (widget.onCancelRecording != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onCancelRecording!();
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close_rounded,
                  color: isDark ? LivescribeTheme.darkTextSecondary : LivescribeTheme.textSecondary,
                  size: 18,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WaveformVisualization extends StatefulWidget {
  final bool isRecording;
  final bool isDark;

  const _WaveformVisualization({
    required this.isRecording,
    required this.isDark,
  });

  @override
  State<_WaveformVisualization> createState() => _WaveformVisualizationState();
}

class _WaveformVisualizationState extends State<_WaveformVisualization>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _amplitudes = List.filled(20, 0.2);
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    if (widget.isRecording) {
      _startAnimation();
    }
  }

  @override
  void didUpdateWidget(_WaveformVisualization oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !oldWidget.isRecording) {
      _startAnimation();
    } else if (!widget.isRecording && oldWidget.isRecording) {
      _stopAnimation();
    }
  }

  void _startAnimation() {
    _updateTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      setState(() {
        for (int i = 0; i < _amplitudes.length; i++) {
          // Simulate random audio levels
          _amplitudes[i] = 0.2 + (0.8 * (DateTime.now().millisecondsSinceEpoch % (100 + i * 10)) / (100 + i * 10));
        }
      });
    });
  }

  void _stopAnimation() {
    _updateTimer?.cancel();
    _updateTimer = null;
    setState(() {
      for (int i = 0; i < _amplitudes.length; i++) {
        _amplitudes[i] = 0.2;
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(_amplitudes.length, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 50),
          width: 3,
          height: 30 * _amplitudes[index],
          decoration: BoxDecoration(
            color: LivescribeTheme.error.withOpacity(0.8),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

/// Compact recording button for floating toolbar
class CompactRecordButton extends StatelessWidget {
  final bool isRecording;
  final VoidCallback onTap;
  final int? durationMs;

  const CompactRecordButton({
    super.key,
    required this.isRecording,
    required this.onTap,
    this.durationMs,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: LivescribeTheme.durationFast,
        padding: EdgeInsets.symmetric(
          horizontal: isRecording ? 12 : 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isRecording
              ? LivescribeTheme.error
              : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isRecording ? Icons.stop_rounded : Icons.mic_rounded,
              size: 18,
              color: isRecording
                  ? Colors.white
                  : (isDark ? LivescribeTheme.darkTextPrimary : LivescribeTheme.textPrimary),
            ),
            if (isRecording && durationMs != null) ...[
              const SizedBox(width: 8),
              Text(
                _formatDuration(durationMs!),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDuration(int ms) {
    final seconds = (ms / 1000).floor();
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
