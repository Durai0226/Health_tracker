import 'package:flutter/foundation.dart';

import '../../focus/models/breathing_exercise.dart';
import '../../focus/models/relaxation_music.dart';

/// The wind-down reminder, and the tap that opens the routine it offers.
class WindDownLink {
  const WindDownLink._();

  /// The payload on the reminder.
  static const String payload = 'winddown';

  /// Whether a tapped notification's payload is the wind-down reminder's.
  static bool isPayload(String? p) => p == payload;

  /// Set by a tapped reminder (warm or cold start); the app shell opens the routine,
  /// once the app lock allows, and clears it.
  static final ValueNotifier<bool> pendingOpen = ValueNotifier<bool>(false);
}

/// What "wind down" is: a short 4-7-8 breath, a low steady sound for a set time, and
/// then nothing.
///
/// Fixed rather than configurable. It is one tap at the end of a day, and every
/// choice put in front of someone who is trying to stop thinking is a reason not to
/// start; the Relaxation screen is where the sound and the length are chosen.
class WindDownRoutine {
  const WindDownRoutine._();

  /// The breathing pattern: 4 in, 7 held, 8 out.
  static const BreathingPattern pattern = BreathingPattern.sleepBreathing;

  /// The sound. The one Full Reset track that has audio behind it (see
  /// `AudioService.hasRelaxationAudio`); the screen offers the sound only while it does.
  static const RelaxationMusicType track = RelaxationMusicType.deepSleepDelta;

  /// How long the sound plays before it stops by itself.
  static const int soundMinutes = 20;

  /// How long the breathing takes, in whole minutes, never less than one.
  static int get breathingMinutes {
    final seconds = pattern.totalCycleDuration * pattern.recommendedCycles;
    return (seconds / 60).round().clamp(1, 60);
  }
}
