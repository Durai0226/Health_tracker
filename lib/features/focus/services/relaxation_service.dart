import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../../core/services/haptic_service.dart';
import 'package:clock/clock.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../../core/services/clean_storage_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/utils/enum_json.dart';
import '../models/relaxation_music.dart';

/// A [ValueNotifier] that will admit whether anybody is listening.
///
/// The same type, for the same reason, as `FocusService`'s [CompletionNotifier]:
/// `ChangeNotifier.hasListeners` is `@protected`, so a plain `ValueNotifier`
/// FIELD cannot be asked whether publishing to it would reach anyone — and
/// publishing a completion nobody is listening to drops it on the floor.
class RelaxationCompletionNotifier extends ValueNotifier<RelaxationSession?> {
  RelaxationCompletionNotifier() : super(null);

  /// Whether a screen is currently able to present a completion.
  bool get hasConsumer => hasListeners;
}

class RelaxationService extends ChangeNotifier with WidgetsBindingObserver {
  static final RelaxationService _instance = RelaxationService._internal();
  factory RelaxationService() => _instance;
  RelaxationService._internal();

  final AudioService _audioService = AudioService();

  // Session State
  bool _isRunning = false;
  bool _isPaused = false;
  int _remainingSeconds = 0;
  int _selectedMinutes = 15;
  DateTime? _startTime;

  /// Absolute wall-clock end of the session.
  ///
  /// The countdown used to be purely tick-accumulated (`_remainingSeconds--` once
  /// a second) with no wall-clock anchor and no lifecycle observer — the only one
  /// of the three timers in this feature without either. When Android suspended
  /// the isolate's timers in the background the countdown simply stalled while the
  /// audio kept playing (iOS has the `audio` background mode), so a 15-minute
  /// session overshot by however long the app spent backgrounded, and completion
  /// only fired once the user came back.
  DateTime? _endTime;

  /// When the current pause began, or null if the session is running.
  ///
  /// Load-bearing, not bookkeeping: the countdown is derived from the absolute
  /// [_endTime], so a pause that does not record its own start has no way to push
  /// that end forward and every paused second is charged to the user.
  DateTime? _pauseStartTime;
  Timer? _timer;

  /// Whether the app is currently on screen.
  ///
  /// Decides WHERE a completion is announced, together with [justCompleted].
  /// `_completeSession` fired an OS notification unconditionally — and it can
  /// only ever run in the foreground, because the ticker is cancelled when the
  /// app is backgrounded and an elapsed session therefore completes on the way
  /// back in. So every completion banner this feature has ever shown landed on
  /// top of the screen that was already showing the same news.
  bool _isForeground = true;

  /// The session that just finished, for a listening screen to celebrate.
  ///
  /// Foreground AND listening is the real question, not foreground alone:
  /// `RelaxationScreen` is a pushed route, so "in the app but not on this
  /// screen" is an ordinary state, and someone there has to be told something.
  /// `FocusService.justCompleted` makes exactly this distinction.
  final RelaxationCompletionNotifier justCompleted =
      RelaxationCompletionNotifier();

  /// A completion or abandon is already in flight. Same guard, and the same
  /// reason, as `FocusService._finishing`: `_isRunning` is only cleared in
  /// `_resetSession()`, which runs after the audio stop, the notification and the
  /// storage write — and `_syncTimer()` fires on every lifecycle resume, so an
  /// elapsed session could be recorded twice with two sets of credited minutes.
  bool _finishing = false;

  // Current Session Config
  RelaxationMusicType? _selectedMusic;
  RelaxationCategory _selectedCategory = RelaxationCategory.deepFocus;
  double _volume = 0.7;
  
  // Stats & Data
  RelaxationStats _stats = const RelaxationStats();
  List<RelaxationSession> _sessions = [];

  // Getters
  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;
  int get remainingSeconds => _remainingSeconds;
  int get selectedMinutes => _selectedMinutes;
  RelaxationMusicType? get selectedMusic => _selectedMusic;
  RelaxationCategory get selectedCategory => _selectedCategory;
  double get volume => _volume;
  RelaxationStats get stats => _stats;
  List<RelaxationSession> get sessions => List.unmodifiable(_sessions);
  
  double get progress => _isRunning && _selectedMinutes > 0
      ? 1 - (_remainingSeconds / (_selectedMinutes * 60))
      : 0.0;

  String get formattedTime {
    final mins = _remainingSeconds ~/ 60;
    final secs = _remainingSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
  
  int get todayMinutes {
    final today = clock.now();
    return _sessions
        .where((s) => _isSameDay(s.startedAt, today) && s.wasCompleted)
        .fold(0, (sum, s) => sum + s.actualMinutes);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _isForeground = true;
        _syncTimer();
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _isForeground = false;
        if (_isRunning && !_isPaused) {
          _timer?.cancel();
          _timer = null;
        }
      case AppLifecycleState.inactive:
        break;
    }
  }

  /// Recompute the countdown from the wall clock on the way back in.
  void _syncTimer() {
    if (!_isRunning || _isPaused || _endTime == null) return;
    final remaining = _endTime!.difference(clock.now()).inSeconds;
    if (remaining <= 0) {
      _remainingSeconds = 0;
      _completeSession();
      return;
    }
    _remainingSeconds = remaining;
    _startTimer();
    notifyListeners();
  }

  bool _didInit = false;

  Future<void> init() async {
    // Guarded, and it has to be.
    //
    // `RelaxationScreen.initState` calls this, and `RelaxationService` is a
    // process-wide singleton, so every mount used to register ANOTHER lifecycle
    // observer on the same object — with no `removeObserver` anywhere to undo it.
    // Open the relaxation screen three times and `didChangeAppLifecycleState`
    // fires three times per transition, so one resume ran `_syncTimer()` three
    // times and a session that had elapsed completed three times over: three sets
    // of side effects for one session.
    //
    // `FocusService` already had exactly this guard (`_didInit`, plus a
    // `removeObserver` in `resetForTesting`) for exactly this reason; this service
    // was written from the same shape and missed it.
    if (_didInit) return;
    _didInit = true;
    WidgetsBinding.instance.addObserver(this);
    await _audioService.init();
    await _loadData();
    debugPrint('✓ RelaxationService initialized');
  }

  /// Read persisted relaxation state — one section at a time, so a bad value
  /// costs one field instead of the feature.
  ///
  /// This was a single `try` around all three sections, with both enums read as
  /// raw ordinals (`RelaxationCategory.values[...]`). One out-of-range index — a
  /// build downgraded after recording data, an enum whose values were renamed —
  /// threw a `RangeError` on the FIRST line and the stats and the whole session
  /// history were never reached: the user opens Relaxation and every minute they
  /// ever logged is gone, while the data still sits on disk. [EnumJson] keeps the
  /// ordinals survivable, and the split `try`s keep one bad section from taking
  /// the others with it.
  Future<void> _loadData() async {
    final prefs = CleanStorageService.getAppPreferences();

    try {
      _selectedMinutes = prefs['relaxationSelectedMinutes'] ?? 15;
      _selectedCategory = EnumJson.at(RelaxationCategory.values,
          prefs['relaxationSelectedCategory'], RelaxationCategory.deepFocus);
      _volume = (prefs['relaxationVolume'] ?? 0.7).toDouble();
      // atOrNull, not at: no track selected is a real state, and substituting the
      // first one would put a track the user never picked under the play button.
      _selectedMusic = EnumJson.atOrNull(
          RelaxationMusicType.values, prefs['relaxationSelectedMusic']);
    } catch (e) {
      debugPrint('Error loading relaxation settings: $e');
    }

    try {
      final statsJson = prefs['relaxationStats'];
      if (statsJson != null && statsJson is Map) {
        _stats = RelaxationStats.fromJson(Map<String, dynamic>.from(statsJson));
      }
    } catch (e) {
      debugPrint('Error loading relaxation stats: $e');
    }

    try {
      final sessionsJson = prefs['relaxationSessions'];
      if (sessionsJson != null && sessionsJson is List) {
        // Row by row: one unreadable record (a null `startedAt`, a truncated
        // write) must not delete the rest of the history.
        final loaded = <RelaxationSession>[];
        for (final s in sessionsJson) {
          try {
            loaded.add(
                RelaxationSession.fromJson(Map<String, dynamic>.from(s as Map)));
          } catch (e) {
            debugPrint('Skipping unreadable relaxation session: $e');
          }
        }
        _sessions = loaded;
      }
    } catch (e) {
      debugPrint('Error loading relaxation sessions: $e');
    }

    notifyListeners();
  }

  Future<void> _saveData() async {
    try {
      await CleanStorageService.setAppPreference('relaxationSelectedMinutes', _selectedMinutes);
      await CleanStorageService.setAppPreference('relaxationSelectedCategory', _selectedCategory.index);
      await CleanStorageService.setAppPreference('relaxationVolume', _volume);
      await CleanStorageService.setAppPreference('relaxationSelectedMusic', _selectedMusic?.index);
      await CleanStorageService.setAppPreference('relaxationStats', _stats.toJson());
      await CleanStorageService.setAppPreference('relaxationSessions', _sessions.take(100).map((s) => s.toJson()).toList());
    } catch (e) {
      debugPrint('Error saving relaxation data: $e');
    }
  }

  void setDuration(int minutes) {
    if (!_isRunning) {
      _selectedMinutes = minutes;
      _saveData();
      notifyListeners();
    }
  }

  void setCategory(RelaxationCategory category) {
    if (!_isRunning) {
      _selectedCategory = category;
      // Reset music selection when category changes
      _selectedMusic = null;
      _saveData();
      notifyListeners();
    }
  }

  void setMusic(RelaxationMusicType music) {
    _selectedMusic = music;
    _selectedCategory = music.category;
    _saveData();
    notifyListeners();
  }

  /// Persist ONE preference.
  ///
  /// [_saveData] writes six keys, and two of those values are the whole stats
  /// blob and the last hundred sessions re-encoded as JSON.
  /// `FocusService._savePreference` exists for the identical reason — see
  /// [setVolume] for the drag that made it necessary here too.
  Future<void> _savePreference(String key, Object? value) async {
    try {
      await CleanStorageService.setAppPreference(key, value);
    } catch (e) {
      debugPrint('Error saving $key: $e');
    }
  }

  /// [persist] is false for the drag itself.
  ///
  /// The slider is wired to `Slider.onChanged`, which fires every frame, and
  /// this called `_saveData()` — six Drift writes plus a re-encode of the stats
  /// blob and of the last hundred sessions, PER FRAME, on the UI isolate, while
  /// audio was playing. The audio volume still follows the thumb; the write now
  /// happens once, when it is released.
  void setVolume(double vol, {bool persist = true}) {
    _volume = vol.clamp(0.0, 1.0);
    _audioService.setVolume(_volume);
    if (persist) _savePreference('relaxationVolume', _volume);
    notifyListeners();
  }

  Future<void> startSession() async {
    if (_isRunning || _selectedMusic == null) return;

    // Retire the previous celebration. Cleared HERE rather than in the listener
    // keeps consuming [justCompleted] a pure read, so a screen never has to
    // write back into the service to acknowledge something.
    justCompleted.value = null;
    
    _isRunning = true;
    _isPaused = false;
    _remainingSeconds = _selectedMinutes * 60;
    _startTime = clock.now();
    _endTime = _startTime!.add(Duration(minutes: _selectedMinutes));
    
    // Provide haptic feedback for session start
    HapticService().focusStart();
    
    // Start timer and update UI IMMEDIATELY for smooth experience
    _startTimer();
    notifyListeners();
    
    debugPrint('✓ Relaxation session started: $_selectedMinutes minutes with ${_selectedMusic?.name}');
    
    // Load and play audio in background (non-blocking)
    _playRelaxationMusic();
  }

  Future<void> _playRelaxationMusic() async {
    if (_selectedMusic == null) return;
    
    try {
      final musicKey = _selectedMusic!.assetKey;
      debugPrint('Playing relaxation music with key: $musicKey');
      await _audioService.playRelaxationMusic(musicKey, volume: _volume);
    } catch (e) {
      debugPrint('Error playing relaxation music: $e');
    }
  }

  /// Fires once a second while a session runs — and nothing else.
  ///
  /// Same defect `FocusService.tick` was introduced to fix. The countdown
  /// arrived via `notifyListeners()`, and `RelaxationScreen.build` wraps the
  /// ENTIRE 1078-line screen in one `ListenableBuilder` on this service — so a
  /// running relaxation session rebuilt all of it 60 times a minute, including
  /// a `shrinkWrap: true` ListView that eagerly builds every track.
  ///
  /// Only the clock changes per second. It listens here; everything else keeps
  /// listening to the ChangeNotifier, which now fires only on real state
  /// transitions (start, pause, resume, complete).
  final ValueNotifier<int> tick = ValueNotifier<int>(0);

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) => applyTick());
  }

  /// One second of countdown. Extracted so a test drives the real path — the
  /// property that matters (a tick does NOT fire notifyListeners) is only
  /// meaningful when asserted against this, not against the notifier alone.
  /// Puts the service into a running state without touching audio or storage,
  /// so a test can drive [applyTick] down the real countdown path.
  ///
  /// Needed because `applyTick` correctly no-ops when nothing is running —
  /// which meant a test that only called it measured nothing and passed with
  /// the bug restored.
  @visibleForTesting
  void primeForTest({int seconds = 60}) {
    _isRunning = true;
    _isPaused = false;
    _remainingSeconds = seconds;
  }

  @visibleForTesting
  void applyTick() {
    // A tick with no session running must do nothing. Without this guard the
    // `_remainingSeconds <= 0` branch below ran `_completeSession()` against a
    // null session and threw — a stray timer callback after a session ended
    // would have crashed the isolate.
    if (!_isRunning) return;
    if (_isPaused) return;

    // Derived from the absolute end time rather than decremented, so a tick that
    // never fired (backgrounded, suspended, throttled) cannot cost the user time.
    // `primeForTest` leaves `_endTime` null, so fall back to decrementing there.
    if (_endTime != null) {
      final ms = _endTime!.difference(clock.now()).inMilliseconds;
      final remaining = (ms / 1000).ceil();
      if (remaining <= 0) {
        _remainingSeconds = 0;
        tick.value = 0;
        _completeSession();
        return;
      }
      if (_remainingSeconds != remaining) {
        _remainingSeconds = remaining;
        // Deliberately NOT notifyListeners(): see [tick].
        tick.value = remaining;
      }
      return;
    }

    if (_remainingSeconds > 0) {
      _remainingSeconds--;
      tick.value = _remainingSeconds;
    } else {
      _completeSession();
    }
  }

  void pauseSession() {
    if (_isRunning && !_isPaused) {
      _isPaused = true;
      // Stop the clock, not only the audio.
      //
      // [applyTick] derives the remaining time from the original [_endTime], so a
      // pause that leaves it alone silently spends the paused minutes: pausing a
      // 15-minute session at 5 minutes for 7 minutes came back with 3 minutes
      // left instead of 10, and a pause outlasting the session completed it
      // instantly and credited a full 15 minutes nobody listened to.
      _pauseStartTime = clock.now();
      _timer?.cancel();
      _timer = null;
      _audioService.pause();
      HapticService().focusPause();
      notifyListeners();
    }
  }

  void resumeSession() {
    if (_isRunning && _isPaused) {
      _isPaused = false;
      // Push the end time forward by however long the pause lasted, the way
      // `FocusService.resumeSession` does.
      final pausedAt = _pauseStartTime;
      if (pausedAt != null && _endTime != null) {
        _endTime = _endTime!.add(clock.now().difference(pausedAt));
      }
      _pauseStartTime = null;
      _audioService.resume();
      // The ticker was cancelled by the pause, so resuming has to restart it or
      // the countdown never moves again.
      _startTimer();
      HapticService().focusStart();
      notifyListeners();
    }
  }

  Future<void> abandonSession() async {
    if (!_isRunning || _finishing) return;
    _finishing = true;
    // try/finally, because `_finishing` latches BEFORE the awaits below.
    // A throw from any of them (the DAO write, the tag persist, the coin
    // award) would otherwise leave the flag set for the life of the
    // process, and every later Done AND Give Up would return silently —
    // the same dead-button failure the paused-recovery fix was about.
    // Clearing on the error path can in principle let a half-finished
    // payout be retried; a session the user cannot end at all is worse.
    try {
      _timer?.cancel();
      await _audioService.stop();
      HapticService().focusComplete();

      // Elapsed, floored to whole minutes.
      //
      // `_selectedMinutes - (_remainingSeconds ~/ 60)` truncates the remainder,
      // which rounds the subtraction UP: stopping 30 seconds into a 15-minute track
      // logged a full minute of relaxation, and 90 seconds logged two. Compute the
      // elapsed side directly and floor it, as `FocusService.abandonSession` does.
      final elapsedSeconds = _selectedMinutes * 60 - _remainingSeconds;
      final elapsedMinutes = (elapsedSeconds ~/ 60).clamp(0, _selectedMinutes);

      // Create abandoned session
      final session = RelaxationSession(
        id: _generateId(),
        startedAt: _startTime!,
        completedAt: clock.now(),
        targetMinutes: _selectedMinutes,
        actualMinutes: elapsedMinutes,
        wasCompleted: false,
        wasAbandoned: true,
        musicType: _selectedMusic!,
        category: _selectedCategory,
      );
      _sessions.insert(0, session);
    
      // Update stats
      _stats = _stats.copyWith(
        totalSessions: _stats.totalSessions + 1,
        abandonedSessions: _stats.abandonedSessions + 1,
      );
    
      _resetSession();
      await _saveData();
    
      debugPrint('✓ Relaxation session abandoned');
    } finally {
      _finishing = false;
    }
}

  Future<void> _completeSession() async {
    if (_finishing) return;
    _finishing = true;
    // try/finally, because `_finishing` latches BEFORE the awaits below.
    // A throw from any of them (the DAO write, the tag persist, the coin
    // award) would otherwise leave the flag set for the life of the
    // process, and every later Done AND Give Up would return silently —
    // the same dead-button failure the paused-recovery fix was about.
    // Clearing on the error path can in principle let a half-finished
    // payout be retried; a session the user cannot end at all is worse.
    try {      _timer?.cancel();
      await _audioService.stop();
      HapticService().focusComplete();
    
      // Create completed session
      final session = RelaxationSession(
        id: _generateId(),
        startedAt: _startTime!,
        completedAt: clock.now(),
        targetMinutes: _selectedMinutes,
        actualMinutes: _selectedMinutes,
        wasCompleted: true,
        wasAbandoned: false,
        musicType: _selectedMusic!,
        category: _selectedCategory,
      );
      _sessions.insert(0, session);
    
      // Update category minutes
      final categoryMinutes = Map<RelaxationCategory, int>.from(_stats.minutesByCategory);
      categoryMinutes[_selectedCategory] = (categoryMinutes[_selectedCategory] ?? 0) + _selectedMinutes;
    
      // Update track usage
      final trackUsage = Map<RelaxationMusicType, int>.from(_stats.usageByTrack);
      trackUsage[_selectedMusic!] = (trackUsage[_selectedMusic!] ?? 0) + 1;
    
      // Update stats
      _stats = _stats.copyWith(
        totalMinutes: _stats.totalMinutes + _selectedMinutes,
        totalSessions: _stats.totalSessions + 1,
        completedSessions: _stats.completedSessions + 1,
        minutesByCategory: categoryMinutes,
        usageByTrack: trackUsage,
      );
    
      // WHERE the completion is announced.
      //
      // This banner used to fire unconditionally, and `_completeSession` can
      // only run while the app is on screen — the ticker is cancelled when we
      // are backgrounded, so a session that elapsed while away completes inside
      // `_syncTimer()` on the way back in. Every one of these notifications
      // therefore dropped a system banner over the screen the user was already
      // looking at. Publish it to a listening screen instead, and keep the
      // notification for the case where nobody can present it — which is a real
      // case, not a theoretical one: `RelaxationScreen` is a pushed route.
      //
      // `showFocusNotification`, not `showImmediateNotification`: the latter routes
      // through `_notificationDetails`, which ignores its channelId and hardcodes
      // `alarm_channel` — so the end of a relaxation session rang on the alarm
      // audio stream, through Do Not Disturb, with Snooze/Dismiss buttons.
      if (_isForeground && justCompleted.hasConsumer) {
        justCompleted.value = session;
      } else {
        await NotificationService().showFocusNotification(
          title: 'Relaxation Complete! ${_selectedCategory.emoji}',
          body: 'You completed $_selectedMinutes minutes of ${_selectedCategory.name}. Feel refreshed!',
        );
      }
    
      _resetSession();
      await _saveData();
    
      debugPrint('✓ Relaxation session completed');
    } finally {
      _finishing = false;
    }
}

  void _resetSession() {
    _isRunning = false;
    _isPaused = false;
    _finishing = false;
    _remainingSeconds = 0;
    _startTime = null;
    _endTime = null;
    _pauseStartTime = null;
    notifyListeners();
  }

  String _generateId() {
    return '${clock.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
  }

  bool get isAudioPlaying => _audioService.isPlaying;

  Future<void> toggleAudio() async {
    await _audioService.toggle();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioService.stop();
    super.dispose();
  }
  /// Fresh-install state between tests. See FocusService.resetForTesting.
  ///
  /// `tick` is reset, never disposed — disposing a singleton's notifier
  /// poisons every later test in the isolate.
  @visibleForTesting
  void resetForTesting() {
    _timer?.cancel();
    _timer = null;
    // Mirror FocusService: deregister the lifecycle observer and clear the guard,
    // or every test in the isolate inherits the previous test's observer and one
    // resume drives N sessions to completion.
    if (_didInit) {
      WidgetsBinding.instance.removeObserver(this);
      _didInit = false;
    }
    _isRunning = false;
    _isPaused = false;
    _finishing = false;
    _remainingSeconds = 0;
    _selectedMinutes = 15;
    _selectedCategory = RelaxationCategory.deepFocus;
    _selectedMusic = null;
    _volume = 0.7;
    _startTime = null;
    _endTime = null;
    _pauseStartTime = null;
    _stats = const RelaxationStats();
    _sessions = [];
    _isForeground = true;
    // Reset, never disposed — same reason as `tick`.
    justCompleted.value = null;
    tick.value = 0;
  }

}
