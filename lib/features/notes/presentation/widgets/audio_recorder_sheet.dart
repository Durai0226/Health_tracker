import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';

class AudioRecorderSheet extends StatefulWidget {
  const AudioRecorderSheet({super.key});

  @override
  State<AudioRecorderSheet> createState() => _AudioRecorderSheetState();
}

class _AudioRecorderSheetState extends State<AudioRecorderSheet> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  Timer? _timer;
  int _seconds = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/${const Uuid().v4()}.m4a';
        
        await _audioRecorder.start(const RecordConfig(), path: path);
        
        setState(() {
          _isRecording = true;
          _isRecording = true;
          _seconds = 0;
          _seconds = 0;
        });

        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _seconds++;
          });
        });
      }
    } catch (e) {
      debugPrint('Error starting record: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      _timer?.cancel();
      
      setState(() {
        _isRecording = false;
        _isRecording = false;
      });

      if (path != null && mounted) {
        Navigator.pop(context, File(path));
      }
    } catch (e) {
      debugPrint('Error stopping record: $e');
    }
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Record Audio",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            _formatDuration(_seconds),
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: _isRecording ? _stopRecording : _startRecording,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _isRecording ? Colors.red : AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_isRecording ? Colors.red : AppColors.primary).withValues(alpha: 0.3),
                    blurRadius: 15,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _isRecording ? "Tap to Stop" : "Tap to Record",
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
