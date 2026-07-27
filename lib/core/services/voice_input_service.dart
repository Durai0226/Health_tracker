import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Thin wrapper around the OS speech recognizer for the AI-chat mic.
///
/// Speech runs through the platform recognizer (Android `SpeechRecognizer` /
/// iOS Speech), so it needs no network of our own and adds no key. It degrades
/// gracefully: if the device has no recognizer or the mic permission is denied,
/// [start] returns false and the caller simply keeps the plain text field.
class VoiceInputService {
  VoiceInputService._();
  static final VoiceInputService instance = VoiceInputService._();

  final SpeechToText _speech = SpeechToText();

  // `initialize` only registers its status/error listeners on the first
  // successful call, so we route them through these fields — updated on every
  // [start] — instead of the (stale) closures from the first init.
  void Function(String status)? _onStatus;
  void Function(String error)? _onError;

  bool get isListening => _speech.isListening;

  Future<bool> _ensureInitialized() async {
    if (_speech.isAvailable) return true;
    try {
      return await _speech.initialize(
        onStatus: (s) => _onStatus?.call(s),
        onError: (e) => _onError?.call(e.errorMsg),
      );
    } catch (e) {
      debugPrint('⚠️ VoiceInputService init failed: $e');
      return false;
    }
  }

  /// Begins listening. [onText] streams the transcript (partial, then final);
  /// [onDone] fires when recognition ends (final result, pause timeout, or
  /// error). Returns false if speech is unavailable so the UI can fall back.
  Future<bool> start({
    required void Function(String text, bool isFinal) onText,
    required VoidCallback onDone,
    void Function(String error)? onError,
  }) async {
    _onStatus = (s) {
      if (s == SpeechToText.doneStatus || s == SpeechToText.notListeningStatus) {
        onDone();
      }
    };
    _onError = (e) {
      onError?.call(e);
      onDone();
    };

    final ok = await _ensureInitialized();
    if (!ok) return false;

    try {
      await _speech.listen(
        onResult: (SpeechRecognitionResult r) =>
            onText(r.recognizedWords, r.finalResult),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
        ),
      );
      return true;
    } catch (e) {
      debugPrint('⚠️ VoiceInputService listen failed: $e');
      return false;
    }
  }

  Future<void> stop() async {
    if (_speech.isListening) await _speech.stop();
  }

  Future<void> cancel() async {
    if (_speech.isListening) await _speech.cancel();
  }
}
