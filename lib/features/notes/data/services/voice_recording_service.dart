import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceRecordingService {
  static final VoiceRecordingService _instance = VoiceRecordingService._internal();
  factory VoiceRecordingService() => _instance;
  VoiceRecordingService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  
  final ValueNotifier<RecordingState> stateNotifier = ValueNotifier(RecordingState.idle);
  final ValueNotifier<Duration> durationNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> playbackPositionNotifier = ValueNotifier(Duration.zero);
  
  Timer? _durationTimer;
  String? _currentRecordingPath;
  String? _currentPlayingPath;

  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<String?> getVoiceNotesDirectory() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final voiceDir = Directory('${dir.path}/voice_notes');
      if (!await voiceDir.exists()) {
        await voiceDir.create(recursive: true);
      }
      return voiceDir.path;
    } catch (e) {
      debugPrint('Error getting voice notes directory: $e');
      return null;
    }
  }

  Future<bool> startRecording() async {
    try {
      final hasPermission = await requestPermission();
      if (!hasPermission) {
        debugPrint('Microphone permission denied');
        return false;
      }

      final voiceDir = await getVoiceNotesDirectory();
      if (voiceDir == null) return false;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '$voiceDir/voice_$timestamp.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentRecordingPath!,
      );

      stateNotifier.value = RecordingState.recording;
      durationNotifier.value = Duration.zero;
      
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        durationNotifier.value += const Duration(seconds: 1);
      });

      return true;
    } catch (e) {
      debugPrint('Error starting recording: $e');
      return false;
    }
  }

  Future<String?> stopRecording() async {
    try {
      _durationTimer?.cancel();
      _durationTimer = null;

      final path = await _recorder.stop();
      stateNotifier.value = RecordingState.idle;
      
      return path ?? _currentRecordingPath;
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      stateNotifier.value = RecordingState.idle;
      return null;
    }
  }

  Future<void> cancelRecording() async {
    try {
      _durationTimer?.cancel();
      _durationTimer = null;
      
      await _recorder.stop();
      
      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
      
      _currentRecordingPath = null;
      stateNotifier.value = RecordingState.idle;
      durationNotifier.value = Duration.zero;
    } catch (e) {
      debugPrint('Error canceling recording: $e');
    }
  }

  Future<void> playRecording(String path) async {
    try {
      if (_currentPlayingPath == path && stateNotifier.value == RecordingState.playing) {
        await pausePlayback();
        return;
      }

      _currentPlayingPath = path;
      await _player.setFilePath(path);
      
      _player.positionStream.listen((position) {
        playbackPositionNotifier.value = position;
      });
      
      _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          stateNotifier.value = RecordingState.idle;
          playbackPositionNotifier.value = Duration.zero;
        }
      });

      await _player.play();
      stateNotifier.value = RecordingState.playing;
    } catch (e) {
      debugPrint('Error playing recording: $e');
    }
  }

  Future<void> pausePlayback() async {
    try {
      await _player.pause();
      stateNotifier.value = RecordingState.paused;
    } catch (e) {
      debugPrint('Error pausing playback: $e');
    }
  }

  Future<void> resumePlayback() async {
    try {
      await _player.play();
      stateNotifier.value = RecordingState.playing;
    } catch (e) {
      debugPrint('Error resuming playback: $e');
    }
  }

  Future<void> stopPlayback() async {
    try {
      await _player.stop();
      stateNotifier.value = RecordingState.idle;
      playbackPositionNotifier.value = Duration.zero;
    } catch (e) {
      debugPrint('Error stopping playback: $e');
    }
  }

  Future<void> seekTo(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      debugPrint('Error seeking: $e');
    }
  }

  Duration? get totalDuration => _player.duration;

  Future<int?> getRecordingDuration(String path) async {
    try {
      await _player.setFilePath(path);
      return _player.duration?.inSeconds;
    } catch (e) {
      debugPrint('Error getting recording duration: $e');
      return null;
    }
  }

  Future<void> deleteRecording(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting recording: $e');
    }
  }

  void dispose() {
    _durationTimer?.cancel();
    _recorder.dispose();
    _player.dispose();
  }
}

enum RecordingState {
  idle,
  recording,
  playing,
  paused,
}
