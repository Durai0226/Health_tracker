import '../models/relaxation_music.dart';

/// What to do with a relaxation session found unfinished when the app starts.
enum RelaxationRecovery {
  /// It was paused: bring it back paused, with the time it had left.
  paused,

  /// Its end is still ahead: carry on, and play the track again.
  resume,

  /// Its end has passed while the app was not running: drop it.
  ///
  /// Not credited. The track died with the app, so nobody can say how long it
  /// was listened to, and a session recorded as completed would be minutes that
  /// may not have happened — and, with "Save mindful minutes" on, written to a
  /// health record.
  expired,
}

/// A running or paused relaxation session as it is kept between launches, so that
/// the app being closed under it (the system reclaiming memory, a crash, an update)
/// does not silently end it.
///
/// Pure Dart. [fromJson] answers null for anything it cannot trust — a stored
/// value that is not this shape, a number out of range, a track or category that no
/// longer exists — and the caller drops it; recovery must never throw at start-up.
class RelaxationSnapshot {
  const RelaxationSnapshot({
    required this.startedAt,
    required this.endTime,
    required this.minutes,
    required this.music,
    required this.category,
    this.pausedRemainingSeconds,
  });

  final DateTime startedAt;

  /// When it ends, on the wall clock. For a paused session it is what the end was
  /// when it was paused and is not used: [pausedRemainingSeconds] is.
  final DateTime endTime;
  final int minutes;
  final RelaxationMusicType music;
  final RelaxationCategory category;

  /// Seconds left, when the session is paused; null while it runs.
  final int? pausedRemainingSeconds;

  /// A session is a few minutes to a few hours; anything outside is not one.
  static const int maxMinutes = 240;

  bool get paused => pausedRemainingSeconds != null;

  Map<String, dynamic> toJson() => {
        'startedAt': startedAt.millisecondsSinceEpoch,
        'endTime': endTime.millisecondsSinceEpoch,
        'minutes': minutes,
        'music': music.index,
        'category': category.index,
        'pausedRemaining': pausedRemainingSeconds,
      };

  static int? _int(Object? v) => v is int ? v : (v is num && v == v.truncate() ? v.toInt() : null);

  static RelaxationSnapshot? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final started = _int(raw['startedAt']);
    final end = _int(raw['endTime']);
    final minutes = _int(raw['minutes']);
    final music = _int(raw['music']);
    final category = _int(raw['category']);
    if (started == null || end == null || minutes == null) return null;
    if (music == null || category == null) return null;
    if (minutes < 1 || minutes > maxMinutes) return null;
    if (music < 0 || music >= RelaxationMusicType.values.length) return null;
    if (category < 0 || category >= RelaxationCategory.values.length) return null;
    if (end <= started) return null;

    int? paused;
    if (raw['pausedRemaining'] != null) {
      paused = _int(raw['pausedRemaining']);
      if (paused == null || paused < 0 || paused > minutes * 60) return null;
    }

    return RelaxationSnapshot(
      startedAt: DateTime.fromMillisecondsSinceEpoch(started),
      endTime: DateTime.fromMillisecondsSinceEpoch(end),
      minutes: minutes,
      music: RelaxationMusicType.values[music],
      category: RelaxationCategory.values[category],
      pausedRemainingSeconds: paused,
    );
  }

  RelaxationRecovery recoveryAt(DateTime now) {
    if (paused) return RelaxationRecovery.paused;
    return endTime.isAfter(now)
        ? RelaxationRecovery.resume
        : RelaxationRecovery.expired;
  }

  /// Whole seconds left at [now], rounded up as the countdown rounds, never below
  /// zero. For a paused session, what it had left when it was paused.
  int remainingSecondsAt(DateTime now) {
    if (paused) return pausedRemainingSeconds!;
    final ms = endTime.difference(now).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }
}
