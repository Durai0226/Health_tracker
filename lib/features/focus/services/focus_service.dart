import 'dart:async';
import 'dart:convert';
import '../../../core/utils/enum_json.dart';
import 'package:clock/clock.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:drift/drift.dart' show Value;
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/focus_dao.dart';
import '../../../core/health/streak_engine.dart';
import '../../../core/services/clean_storage_service.dart';
import '../../../core/services/mindfulness_channel.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/audio_service.dart';
import '../models/focus_plant.dart';
import '../models/ambient_sound.dart';
import '../models/focus_session.dart';
import '../models/focus_achievement.dart';
import 'coins_service.dart';
import 'focus_reminder_scheduler.dart';
import 'focus_session_alarm.dart';
import 'tag_service.dart';

/// Shortest session the app will run. Below this a "session" is not measurable.
const int kMinSessionMinutes = 1;

/// Longest session the app will run (10 hours). Matches the custom-duration
/// sheet's own validation, which was previously the only place this was enforced.
const int kMaxSessionMinutes = 600;

/// Most minutes one session can earn coins for.
///
/// Two hours: longer than any session the suggestion engine has ever proposed
/// (it clamps at 120) and longer than the ultradian ceiling the research
/// describes, so an honest session never reaches it. See `_completeSession`.
const int kMaxCoinEarningMinutes = 120;

/// A [ValueNotifier] that will admit whether anybody is listening.
///
/// `ChangeNotifier.hasListeners` is `@protected`, so a plain `ValueNotifier`
/// FIELD cannot be asked. That mattered: publishing a completion to a notifier
/// with no listener drops it on the floor, and the fallback that should have
/// caught it was gated on the wrong condition.
class CompletionNotifier extends ValueNotifier<FocusSession?> {
  CompletionNotifier() : super(null);

  /// Whether any screen is currently able to present a completion.
  bool get hasConsumer => hasListeners;
}

class FocusService extends ChangeNotifier with WidgetsBindingObserver {
  static final FocusService _instance = FocusService._internal();
  factory FocusService() => _instance;
  FocusService._internal();

  // Audio Service for ambient sounds
  final AudioService _audioService = AudioService();

  // Session State
  bool _isRunning = false;
  bool _isPaused = false;
  int _remainingSeconds = 0;

  /// Fires once a second while a session runs — and NOTHING else.
  ///
  /// The countdown used to arrive via `notifyListeners()`, which the Focus
  /// screen listens to around its entire body. That body is **2322 widgets**
  /// (the largest tree in the app by a factor of ~3, because it is a
  /// `SingleChildScrollView` over thirteen configuration sections), so a
  /// running timer rebuilt all of it 60 times a minute — and Home listens to
  /// this service too, so it rebuilt at 1 Hz as well.
  ///
  /// Only the clock readout and the progress ring actually change per second.
  /// They listen here; everything else keeps listening to the ChangeNotifier,
  /// which now fires only on real state changes (start, pause, phase change,
  /// completion) — all user-driven and rare.
  final ValueNotifier<int> tick = ValueNotifier<int>(0);

  /// Publishes the session that has just finished, so a screen can celebrate it.
  ///
  /// A service has no `BuildContext` and must not acquire one — so it cannot show
  /// a toast, and reaching for a global navigator key to fake one is how services
  /// end up owning presentation. This is the same shape as [tick]: publish the
  /// fact, and let whichever surface is mounted decide what it looks like.
  ///
  /// Cleared by [startSession] rather than by the listener, so consuming it stays
  /// a read and the service keeps ownership of its own state.
  final CompletionNotifier justCompleted = CompletionNotifier();

  /// Whether a grace day is currently holding the streak together.
  ///
  /// `StreakEngine` forgives one miss per rolling week and has always returned
  /// this, and `_checkAndUpdateStreak` has always thrown it away — so the user got
  /// the forgiveness and was never told about it. The reassurance is the half that
  /// changes behaviour: research on streak anxiety is blunt that a hard reset on
  /// one missed day is what makes people quit.
  bool _streakUsedGrace = false;

  /// Today is not done yet and the streak breaks if the day ends unmet.
  bool _streakAtRisk = false;

  bool get streakUsedGrace => _streakUsedGrace;
  bool get streakAtRisk => _streakAtRisk;

  /// Whether the app is currently on screen.
  ///
  /// Decides WHERE a completion is announced. `_completeSession` used to fire an
  /// OS notification unconditionally, so the one moment in the feature that
  /// should feel good was delivered as a system banner dropped over the screen
  /// the user was already watching.
  bool _isForeground = true;
  int _selectedMinutes = 25;
  DateTime? _startTime;
  DateTime? _endTime;
  DateTime? _pauseStartTime;
  Timer? _timer;

  // Total length (minutes) of the interval that is currently running. For single
  // mode this equals _selectedMinutes; for pomodoro it is the work or break
  // length of the active phase. Drives [progress] so the ring is correct in both
  // work and break phases. 0 when idle.
  int _phaseMinutes = 0;

  // ---- Pomodoro (FOCUS-2) ----
  FocusMode _mode = FocusMode.single;
  int _workMinutes = 25;
  int _shortBreakMinutes = 5;
  int _longBreakMinutes = 15;
  int _roundsBeforeLongBreak = 4;
  int _totalRounds = 4;

  // Pomodoro runtime state.
  bool _isOnBreak = false;
  bool _isLongBreak = false;
  int _currentRound = 0; // completed WORK rounds this session
  
  // Current Session Config
  PlantType _selectedPlant = PlantType.seedling;
  FocusActivityType _selectedActivity = FocusActivityType.work;
  AmbientSoundType _selectedSound = AmbientSoundType.none;
  double _soundVolume = 0.5;
  List<String> _selectedTagIds = [];
  
  // Stats & Data
  FocusStats _stats = const FocusStats();
  List<FocusPlant> _garden = [];
  List<FocusSession> _sessions = [];
  final Map<AchievementType, FocusAchievement> _achievements = {};
  Set<PlantType> _unlockedPlants = {PlantType.seedling, PlantType.sprout};
  Set<AmbientSoundType> _usedSounds = {};

  // Getters
  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;
  int get remainingSeconds => _remainingSeconds;
  int get selectedMinutes => _selectedMinutes;
  PlantType get selectedPlant => _selectedPlant;
  FocusActivityType get selectedActivity => _selectedActivity;
  AmbientSoundType get selectedSound => _selectedSound;
  double get soundVolume => _soundVolume;
  List<String> get selectedTagIds => List.unmodifiable(_selectedTagIds);
  FocusStats get stats => _stats;
  List<FocusPlant> get garden => List.unmodifiable(_garden);
  List<FocusSession> get sessions => List.unmodifiable(_sessions);
  Map<AchievementType, FocusAchievement> get achievements => Map.unmodifiable(_achievements);
  Set<PlantType> get unlockedPlants => Set.unmodifiable(_unlockedPlants);

  // Pomodoro getters (FOCUS-2)
  FocusMode get mode => _mode;
  int get workMinutes => _workMinutes;
  int get shortBreakMinutes => _shortBreakMinutes;
  int get longBreakMinutes => _longBreakMinutes;
  int get roundsBeforeLongBreak => _roundsBeforeLongBreak;
  int get totalRounds => _totalRounds;
  bool get isOnBreak => _isOnBreak;
  bool get isLongBreak => _isLongBreak;
  int get currentRound => _currentRound;

  /// True while a count-UP session is configured.
  ///
  /// Callers use this to render an elapsed treatment instead of a ring. There is
  /// deliberately no fake denominator for flow mode — see [progress].
  bool get isCountUp => _mode == FocusMode.flow;

  /// Fraction of the current interval elapsed, 0..1.
  ///
  /// **Returns 0 in flow mode, on purpose.** A count-up session has no target, so
  /// any ring it filled would be filling against a number the app invented — and
  /// the obvious hack, dividing by [kMaxSessionMinutes], would show a 40-minute
  /// session as 6% done, which is worse than showing nothing. `isCountUp` is the
  /// signal to render elapsed time instead.
  double get progress => _isRunning && !isCountUp && _phaseMinutes > 0
      ? 1 - (_remainingSeconds / (_phaseMinutes * 60))
      : 0.0;

  /// Seconds elapsed in the current interval. The count-up counterpart of
  /// [remainingSeconds], derived from the same absolute [_startTime].
  int get elapsedSeconds {
    final start = _startTime;
    if (!_isRunning || start == null) return 0;
    final e = clock.now().difference(start).inSeconds;
    return e < 0 ? 0 : e;
  }

  String get formattedTime {
    // Flow mode shows time SPENT, not time left. Same formatting, opposite
    // meaning — and `_remainingSeconds` is meaningless when there is no target.
    final total = isCountUp ? elapsedSeconds : _remainingSeconds;
    final mins = total ~/ 60;
    final secs = total % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
  
  int get todayMinutes {
    final today = clock.now();
    return _sessions
        .where((s) => _isSameDay(s.startedAt, today) && s.wasCompleted)
        .fold(0, (sum, s) => sum + s.actualMinutes);
  }
  
  int get weekMinutes {
    final now = clock.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    return _sessions
        .where((s) => s.startedAt.isAfter(weekStart) && s.wasCompleted)
        .fold(0, (sum, s) => sum + s.actualMinutes);
  }

  List<FocusPlant> get todayPlants {
    final today = clock.now();
    return _garden.where((p) => _isSameDay(p.plantedAt, today)).toList();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _didInit = false;

  Future<void> init() async {
    // Guarded. `init()` is called from FocusScreen.initState, so every mount used
    // to register ANOTHER lifecycle observer on this singleton and re-run
    // `_loadData()` — which, mid-session, reloads `focusSelectedMinutes` over the
    // in-flight pomodoro phase length.
    if (_didInit) return;
    _didInit = true;
    WidgetsBinding.instance.addObserver(this);
    // Audio is NOT initialised here. It self-initialises on first playback, so a
    // cold launch does not open a platform audio channel (and touch
    // AudioSession.instance) for the majority of users who never start a session.
    // This matters because init() now runs at app startup, not on screen mount.
    await CoinsService().init();
    await TagService().init();
    await _loadData();
    _initAchievements();
    await _checkAndUpdateStreak();
    // After the history is loaded, before anything renders: pick up a session the
    // process died in the middle of.
    await _recoverActiveSession();
    // Deliberately NOT awaited. This does notification I/O and can hit
    // `checkPermissions()`; a cold start must not block on it, and it is
    // self-retrying if it fails. It has to run here rather than on the settings
    // screen because the installs that need it are the ones whose owner never
    // opens that screen — see FocusReminderScheduler.migrateOffAlarmManager.
    //
    // Must come AFTER _checkAndUpdateStreak(): the streak nudge is only scheduled
    // while the streak is actually at risk, and that fact is computed there.
    FocusReminderScheduler.migrateOffAlarmManager();
    debugPrint('✓ FocusService initialized');
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
        // Stop the 1 Hz ticker while we are not on screen.
        //
        // Only `resumed` used to be handled, so the periodic timer kept firing in
        // the background purely to recompute a countdown nobody could see. The
        // countdown is derived from the absolute `_endTime`, so nothing is lost:
        // `_syncTimer()` recomputes it exactly on the way back. Also persist,
        // because being backgrounded is the moment before the OS may kill us.
        if (_isRunning) {
          _timer?.cancel();
          _timer = null;
          _saveActiveSession();
          // Covers the one case arming-at-start cannot: the ticker pre-empted the
          // notification in the final seconds and the user then left the screen.
          // Idempotent — same id, so re-arming an already-armed phase replaces.
          if (!_isPaused) _armCompletion();
        }
      case AppLifecycleState.inactive:
        break; // transient (a system overlay); keep ticking
    }
  }

  void _syncTimer() {
    if (_isRunning && !_isPaused && _endTime != null) {
      final now = clock.now();
      final remaining = _endTime!.difference(now).inSeconds;
      
      if (remaining <= 0) {
        _remainingSeconds = 0;
        _onIntervalComplete();
      } else {
        _remainingSeconds = remaining;
        // Restart the ticker cancelled when we were backgrounded (see
        // didChangeAppLifecycleState). Without this the clock would freeze on
        // return, showing a stale time until the session silently ended.
        _startTimer();
        notifyListeners();
      }
    }
  }

  // ---- in-flight session durability (4b) -----------------------------------
  //
  // Before this, `_isRunning`, `_startTime`, `_endTime`, `_phaseMinutes` and the
  // pomodoro round counter lived ONLY in memory. A process kill — the OS
  // reclaiming the app, a crash, or the user swiping it away — therefore
  // discarded the session in flight completely: no session row, no plant, no
  // coins, and it was not even recorded as abandoned. The user came back to a
  // Focus screen that had forgotten they were ever focusing.
  // ---- background completion (the armed notification) ----------------------
  //
  // The timer's ticker is cancelled while backgrounded, so `_completeSession()`
  // can only ever run on resume — which meant the app never told you the moment
  // your session ended unless you were already watching it. A one-shot
  // notification scheduled for `_endTime` closes that, and [FocusSessionAlarm]
  // makes the arm/disarm decisions assertable without a device.
  //
  // Lazy, exactly like `AudioService._engine`: as a field initialiser this would
  // reach `NotificationService()` the first time anything referenced
  // `FocusService()`, which in a headless test is before a substitute can be
  // installed.
  FocusSessionAlarm? _alarmOverride;
  FocusSessionAlarm get _alarm =>
      _alarmOverride ??= const NotificationFocusSessionAlarm();

  /// Substitute the alarm in tests. Resets the derived state with it, because
  /// this singleton outlives any one test.
  @visibleForTesting
  set alarmForTesting(FocusSessionAlarm alarm) {
    _alarmOverride = alarm;
    _armedFor = null;
    _completionDelivered = false;
  }

  /// The instant a notification is currently armed for, or null if none is.
  DateTime? _armedFor;

  /// Whether the armed notification had already fired by the time we disarmed.
  ///
  /// Without this the fix creates a NEW defect: once completion can be delivered
  /// in the background, the resume path runs `_completeSession()` and announces a
  /// SECOND time, so a user who was away gets the scheduled banner and then
  /// another one the instant they open the app. Computed at disarm, because that
  /// is the only moment both facts are known.
  bool _completionDelivered = false;

  /// Ask the OS to announce the end of the current phase.
  ///
  /// Armed at the START of every phase, not only when backgrounding: `detached`
  /// is not a reliable place to do I/O, and a force-stop or an OOM kill can skip
  /// `paused` entirely — so waiting for it would mean the sessions most likely to
  /// need this are the ones that never armed. The cost is a pending notification
  /// during a foreground session, which [applyTick] pre-empts.
  ///
  /// Unawaited by its callers on purpose: notification I/O must never sit between
  /// the user pressing Start and the countdown moving. The state below is set
  /// before the first `await`, so callers see it synchronously.
  Future<void> _armCompletion() async {
    final at = _endTime;
    if (at == null || !_isRunning || _isPaused) return;
    _armedFor = at;
    _completionDelivered = false;
    final copy = _completionCopy();
    try {
      await _alarm.arm(
        id: NotificationService.focusSessionEndId,
        at: at,
        title: copy.title,
        body: copy.body,
      );
    } catch (e) {
      debugPrint('Focus completion arm failed: $e');
    }
  }

  /// Withdraw the armed notification, recording whether it already fired.
  Future<void> _disarmCompletion() async {
    final armed = _armedFor;
    _completionDelivered = armed != null && !clock.now().isBefore(armed);
    _armedFor = null;
    try {
      await _alarm.disarm(NotificationService.focusSessionEndId);
    } catch (e) {
      debugPrint('Focus completion disarm failed: $e');
    }
  }

  /// What the armed notification should say about the phase now running.
  ///
  /// Phase-correct, because a break ending and a session ending are different
  /// events and a user who is away has only this text to tell them apart. The
  /// final round says "session"; any earlier one says which round.
  ({String title, String body}) _completionCopy() {
    if (_mode == FocusMode.pomodoro && _isOnBreak) {
      return (title: 'Break over ☕', body: 'Time to focus again.');
    }
    final isFinalRound =
        _mode != FocusMode.pomodoro || _currentRound + 1 >= _totalRounds;
    if (!isFinalRound) {
      return (
        title: 'Round ${_currentRound + 1} of $_totalRounds done',
        // Not naming the break length: `_startBreak` decides whether it is a long
        // break and it has not run yet, so duplicating that rule here is how the
        // two drift apart.
        body: 'Time for a break.',
      );
    }
    return (
      title: 'Focus session complete 🌱',
      body: '$_phaseMinutes minutes done.',
    );
  }

  static const _kActiveSession = 'focusActiveSession';

  Future<void> _saveActiveSession() async {
    if (!_isRunning || _startTime == null || _endTime == null) return;
    try {
      await CleanStorageService.setAppPreference(_kActiveSession, {
        'startedAtMs': _startTime!.millisecondsSinceEpoch,
        'endsAtMs': _endTime!.millisecondsSinceEpoch,
        'phaseMinutes': _phaseMinutes,
        'selectedMinutes': _selectedMinutes,
        'mode': _mode.index,
        'isOnBreak': _isOnBreak,
        'isLongBreak': _isLongBreak,
        'currentRound': _currentRound,
        'isPaused': _isPaused,
        // Remaining is persisted so a session killed WHILE PAUSED resumes with
        // the right amount left — a paused session has no meaningful end time.
        'remainingSeconds': _remainingSeconds,
      });
    } catch (e) {
      debugPrint('Error saving active focus session: $e');
    }
  }

  Future<void> _clearActiveSession() async {
    try {
      await CleanStorageService.setAppPreference(_kActiveSession, null);
    } catch (e) {
      debugPrint('Error clearing active focus session: $e');
    }
  }

  /// Recover a session that was in flight when the process died.
  ///
  /// Two outcomes, and the choice between them is deliberate:
  ///
  ///  * **Its end time has passed** — credit it as completed. We cannot
  ///    distinguish "the OS killed us mid-session" from "the user force-quit to
  ///    dodge the timer", and this is exactly what `_syncTimer` already does when
  ///    the app is merely backgrounded across the end. Being consistent with that
  ///    matters more than catching a cheat: the research on this category is
  ///    unanimous that punitive heuristics generate unfair-loss complaints, and
  ///    Forest deliberately makes failure an explicit "Give Up" press instead.
  ///  * **It is still running** — restore the state and restart the ticker, so the
  ///    countdown picks up exactly where the wall clock says it should be.
  Future<void> _recoverActiveSession() async {
    final raw = CleanStorageService.getAppPreferences()[_kActiveSession];
    if (raw is! Map) return;
    try {
      final data = Map<String, dynamic>.from(raw);
      final startedAt =
          DateTime.fromMillisecondsSinceEpoch(data['startedAtMs'] as int);
      final endsAt =
          DateTime.fromMillisecondsSinceEpoch(data['endsAtMs'] as int);

      _mode = EnumJson.at(FocusMode.values, data['mode'], FocusMode.single);
      _phaseMinutes = (data['phaseMinutes'] as int?) ?? 0;
      _selectedMinutes = ((data['selectedMinutes'] as int?) ?? 25)
          .clamp(kMinSessionMinutes, kMaxSessionMinutes);
      _isOnBreak = data['isOnBreak'] == true;
      _isLongBreak = data['isLongBreak'] == true;
      _currentRound = (data['currentRound'] as int?) ?? 0;
      _startTime = startedAt;
      _endTime = endsAt;
      _isRunning = true;
      _isPaused = data['isPaused'] == true;

      if (_isPaused) {
        _remainingSeconds = (data['remainingSeconds'] as int?) ?? 0;
        notifyListeners();
        debugPrint('✓ Recovered a PAUSED focus session');
        return;
      }

      final remaining = endsAt.difference(clock.now()).inSeconds;
      if (remaining <= 0) {
        _remainingSeconds = 0;
        debugPrint('✓ Recovered a focus session that finished while away');
        _onIntervalComplete();
        return;
      }

      _remainingSeconds = remaining;
      _startTimer();
      notifyListeners();
      debugPrint('✓ Recovered a running focus session: ${remaining}s left');
    } catch (e) {
      debugPrint('Could not recover active session: $e');
      await _clearActiveSession();
    }
  }

  Future<void> _loadData() async {
    try {
      final prefs = CleanStorageService.getAppPreferences();
      
      // Clamped on the way IN as well as in setDuration. The setter's bound is
      // no protection against a value already on disk — 0 makes `progress`
      // divide by zero, and a persisted 100000 makes the ring meaningless.
      _selectedMinutes = ((prefs['focusSelectedMinutes'] as int?) ?? 25)
          .clamp(kMinSessionMinutes, kMaxSessionMinutes);

      // Pomodoro mode + config (FOCUS-2). Defaults keep single-session behavior.
      _mode = EnumJson.at(FocusMode.values, prefs['focusMode'], FocusMode.single);
      _workMinutes = prefs['focusPomoWorkMinutes'] ?? 25;
      _shortBreakMinutes = prefs['focusPomoShortBreakMinutes'] ?? 5;
      _longBreakMinutes = prefs['focusPomoLongBreakMinutes'] ?? 15;
      _roundsBeforeLongBreak = prefs['focusPomoRoundsBeforeLong'] ?? 4;
      _totalRounds = prefs['focusPomoTotalRounds'] ?? 4;

      _selectedPlant = EnumJson.at(
          PlantType.values, prefs['focusSelectedPlant'], PlantType.seedling);
      _selectedActivity = EnumJson.at(FocusActivityType.values,
          prefs['focusSelectedActivityType'], FocusActivityType.work);
      _selectedSound = EnumJson.at(AmbientSoundType.values,
          prefs['focusSelectedSound'], AmbientSoundType.none);
      final dynamic volumeValue = prefs['focusSoundVolume'] ?? 0.5;
      if (volumeValue is String) {
        _soundVolume = double.tryParse(volumeValue) ?? 0.5;
      } else if (volumeValue is num) {
        _soundVolume = volumeValue.toDouble();
      } else {
        _soundVolume = 0.5;
      }

      _breathingPreroll = prefs[_kBreathingPreroll] == true;
      _mindfulnessSync = prefs[_kMindfulnessSync] == true;

      // Load stats
      final statsJson = prefs['focusStats'];
      if (statsJson != null && statsJson is Map) {
        _stats = FocusStats.fromJson(Map<String, dynamic>.from(statsJson));
      }

      // Load previously selected tags for the next session
      final selectedTagsJson = prefs['focusSelectedTagIds'];
      if (selectedTagsJson != null && selectedTagsJson is List) {
        _selectedTagIds = List<String>.from(selectedTagsJson);
      }

      // Load garden
      final gardenJson = prefs['focusGarden'];
      if (gardenJson != null && gardenJson is List) {
        _garden = gardenJson
            .map((p) => FocusPlant.fromJson(Map<String, dynamic>.from(p)))
            .toList();
      }

      // Sessions come from Drift now, migrating off the preference blob on the
      // first launch that finds one. See [_loadSessions].
      await _loadSessions(prefs);

      // Load achievements
      final achievementsJson = prefs['focusAchievements'];
      if (achievementsJson != null && achievementsJson is Map) {
        achievementsJson.forEach((key, value) {
          final achievement = FocusAchievement.fromJson(Map<String, dynamic>.from(value));
          _achievements[achievement.type] = achievement;
        });
      }

      // Load unlocked plants
      final unlockedPlantsJson = prefs['focusUnlockedPlants'];
      if (unlockedPlantsJson != null && unlockedPlantsJson is List) {
        // Skip unknown ordinals rather than throwing: a plant this build does
        // not have must not cost the user their whole unlock set.
        _unlockedPlants = unlockedPlantsJson
            .map((i) => EnumJson.atOrNull(PlantType.values, i))
            .whereType<PlantType>()
            .toSet();
        if (_unlockedPlants.isEmpty) {
          _unlockedPlants = {PlantType.seedling, PlantType.sprout};
        }
      }
      
      // Load used sounds
      final usedSoundsJson = prefs['focusUsedSounds'];
      if (usedSoundsJson != null && usedSoundsJson is List) {
        _usedSounds = usedSoundsJson
            .map((i) => EnumJson.atOrNull(AmbientSoundType.values, i))
            .whereType<AmbientSoundType>()
            .toSet();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading focus data: $e');
    }
  }

  void _initAchievements() {
    for (final type in AchievementType.values) {
      if (!_achievements.containsKey(type)) {
        _achievements[type] = FocusAchievement(type: type);
      }
    }
  }

  // ---- session storage: Drift, not a capped blob ---------------------------

  static const _kSessionsMigrated = 'focusSessionsMigratedToDrift';
  static const _kLegacySessions = 'focusSessions';

  FocusDao get _focusDao => AppDatabase.instance.focusDao;

  /// Load history, moving it off the preference blob the first time.
  ///
  /// The blob was written with `_sessions.take(100)`, so the 101st session
  /// destroyed the oldest on the next save — about fifty days at two sessions a
  /// day, silently shrinking, and eroding the streak history that
  /// `_checkAndUpdateStreak` recomputes from.
  ///
  /// The migration runs HERE and not in `MigrationStrategy`, which only creates
  /// the table. Reading `AppPreferences` from inside a Drift migration means
  /// touching `CleanStorageService` before its cache is loaded, and a failure
  /// there has no UI to report itself — the lesson the v13 `alterTable` step
  /// recorded the hard way.
  ///
  /// Order matters and is the whole safety argument: insert, then set the flag,
  /// then drop the blob. Idempotent by primary key, so a crash at any point
  /// leaves the blob intact and simply retries. Dropping it before the flag was
  /// set would lose the history to a crash in between.
  Future<void> _loadSessions(Map<String, dynamic> prefs) async {
    try {
      final migrated = prefs[_kSessionsMigrated] == true;
      final legacy = prefs[_kLegacySessions];

      if (!migrated && legacy is List && legacy.isNotEmpty) {
        final parsed = <FocusSession>[];
        for (final raw in legacy) {
          try {
            parsed.add(
                FocusSession.fromJson(Map<String, dynamic>.from(raw as Map)));
          } catch (e) {
            // One unreadable record must not cost the user the other hundred.
            debugPrint('Skipping unreadable legacy focus session: $e');
          }
        }
        await _focusDao
            .upsertAll(parsed.map(_toCompanion).toList());
        await CleanStorageService.setAppPreference(_kSessionsMigrated, true);
        await CleanStorageService.removeAppPreference(_kLegacySessions);
        debugPrint('✓ Migrated ${parsed.length} focus sessions to Drift');
      } else if (!migrated) {
        // Nothing to move — record it anyway so this never looks again.
        await CleanStorageService.setAppPreference(_kSessionsMigrated, true);
      }

      final rows = await _focusDao.getAll();
      _sessions = rows.map(_fromRow).toList();
    } catch (e) {
      debugPrint('Error loading focus sessions: $e');
    }
  }

  /// Write one session. Called at each of the four points `_sessions` changes.
  ///
  /// Per-row rather than rewriting the whole history on every save: that is what
  /// the blob did, and it is why a volume slider could re-encode every session
  /// the user had ever run.
  Future<void> _persistSession(FocusSession session) async {
    try {
      await _focusDao.upsert(_toCompanion(session));
    } catch (e) {
      debugPrint('Error saving focus session ${session.id}: $e');
    }
  }

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  FocusSessionsCompanion _toCompanion(FocusSession s) {
    final now = clock.now();
    return FocusSessionsCompanion.insert(
      id: s.id,
      dateKey: _dateKey(s.startedAt),
      startedAt: s.startedAt,
      completedAt: Value(s.completedAt),
      targetMinutes: s.targetMinutes,
      actualMinutes: Value(s.actualMinutes),
      wasCompleted: Value(s.wasCompleted),
      wasAbandoned: Value(s.wasAbandoned),
      activityTypeIndex: Value(s.activityType.index),
      plantTypeIndex: Value(s.plantType.index),
      soundUsedIndex: Value(s.soundUsed?.index),
      note: Value(s.note),
      tagIdsJson: Value(jsonEncode(s.tagIds)),
      distractionsJson:
          Value(jsonEncode(s.distractions.map((d) => d.toJson()).toList())),
      quality: Value(s.quality),
      createdAt: now,
      updatedAt: now,
    );
  }

  FocusSession _fromRow(FocusSessionRow r) {
    List<T> decode<T>(String raw, T Function(dynamic) map) {
      try {
        final v = jsonDecode(raw);
        return v is List ? v.map(map).toList() : <T>[];
      } catch (_) {
        return <T>[];
      }
    }

    return FocusSession(
      id: r.id,
      startedAt: r.startedAt,
      completedAt: r.completedAt,
      targetMinutes: r.targetMinutes,
      actualMinutes: r.actualMinutes,
      wasCompleted: r.wasCompleted,
      wasAbandoned: r.wasAbandoned,
      activityType: EnumJson.at(
          FocusActivityType.values, r.activityTypeIndex, FocusActivityType.work),
      plantType:
          EnumJson.at(PlantType.values, r.plantTypeIndex, PlantType.seedling),
      soundUsed: r.soundUsedIndex == null
          ? null
          : EnumJson.at(AmbientSoundType.values, r.soundUsedIndex,
              AmbientSoundType.none),
      note: r.note,
      tagIds: decode<String>(r.tagIdsJson, (e) => e.toString()),
      quality: r.quality,
      distractions: decode<DistractionTap>(
          r.distractionsJson,
          (e) => DistractionTap.fromJson(Map<String, dynamic>.from(e as Map))),
    );
  }

  /// Persist ONE preference.
  ///
  /// [_saveData] writes eighteen keys, and two of those values are the whole
  /// session history and the whole garden re-encoded as JSON. `setSoundVolume`
  /// called it, and the volume slider is wired to `Slider.onChanged` — so
  /// dragging it ran eighteen awaited Drift writes and a full-history encode
  /// **per frame**, on the UI isolate, while audio was playing. The slider is now
  /// on `onChangeEnd`, and the single-key path below means even that final write
  /// is one row instead of eighteen.
  Future<void> _savePreference(String key, Object? value) async {
    try {
      await CleanStorageService.setAppPreference(key, value);
    } catch (e) {
      debugPrint('Error saving $key: $e');
    }
  }

  /// Persist everything. For history and stats changes — not for a single
  /// setting, which has [_savePreference].
  Future<void> _saveData() async {
    try {
      await CleanStorageService.setAppPreference('focusSelectedMinutes', _selectedMinutes);
      await CleanStorageService.setAppPreference('focusMode', _mode.index);
      await CleanStorageService.setAppPreference('focusPomoWorkMinutes', _workMinutes);
      await CleanStorageService.setAppPreference('focusPomoShortBreakMinutes', _shortBreakMinutes);
      await CleanStorageService.setAppPreference('focusPomoLongBreakMinutes', _longBreakMinutes);
      await CleanStorageService.setAppPreference('focusPomoRoundsBeforeLong', _roundsBeforeLongBreak);
      await CleanStorageService.setAppPreference('focusPomoTotalRounds', _totalRounds);
      await CleanStorageService.setAppPreference('focusSelectedPlant', _selectedPlant.index);
      await CleanStorageService.setAppPreference('focusSelectedActivityType', _selectedActivity.index);
      await CleanStorageService.setAppPreference('focusSelectedSound', _selectedSound.index);
      await CleanStorageService.setAppPreference('focusSoundVolume', _soundVolume);
      await CleanStorageService.setAppPreference(_kBreathingPreroll, _breathingPreroll);
      await CleanStorageService.setAppPreference(_kMindfulnessSync, _mindfulnessSync);
      await CleanStorageService.setAppPreference('focusSelectedTagIds', _selectedTagIds);
      await CleanStorageService.setAppPreference('focusStats', _stats.toJson());
      await CleanStorageService.setAppPreference('focusGarden', _garden.map((p) => p.toJson()).toList());
      await CleanStorageService.setAppPreference('focusAchievements', 
        _achievements.map((k, v) => MapEntry(k.index.toString(), v.toJson())));
      await CleanStorageService.setAppPreference('focusUnlockedPlants', _unlockedPlants.map((p) => p.index).toList());
      await CleanStorageService.setAppPreference('focusUsedSounds', _usedSounds.map((s) => s.index).toList());
    } catch (e) {
      debugPrint('Error saving focus data: $e');
    }
  }

  /// What the user said they were going to do, for the session about to start.
  ///
  /// `FocusSession.note` has existed and round-tripped through `toJson`/`fromJson`
  /// since the model was written, with **zero writers and zero readers** — so the
  /// storage for this was already there, already persisted and already in the
  /// backup, waiting for something to put a value in it.
  ///
  /// Deliberately NOT remembered between sessions. Stating the intention is the
  /// mechanism (an implementation intention — an if-then plan is the
  /// best-supported item in the behaviour-change literature this feature draws
  /// on); pre-filling it with last time's answer turns a decision into a default
  /// and the mechanism stops working.
  String? _pendingIntention;
  String? get pendingIntention => _pendingIntention;

  /// Maximum stored intention length.
  ///
  /// Enforced HERE rather than on the text field, because this is the boundary
  /// that matters: the note is persisted, rides the backup blob and is rendered
  /// in a one-line summary. A field-level cap would leave an import or a restore
  /// free to carry an unbounded string into a `Text` with `maxLines: 1`.
  static const int kMaxIntentionChars = 80;

  void setIntention(String? text) {
    final trimmed = text?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      _pendingIntention = null;
    } else {
      _pendingIntention = trimmed.length > kMaxIntentionChars
          ? trimmed.substring(0, kMaxIntentionChars)
          : trimmed;
    }
    notifyListeners();
  }

  // ---- mindfulness write-back (opt-in) -------------------------------------

  static const _kMindfulnessSync = 'focusMindfulnessSync';

  bool _mindfulnessSync = false;

  /// Whether completed mindfulness practice is written to Health Connect.
  ///
  /// Off by default, and the settings row is hidden entirely when the platform
  /// cannot store it — see [MindfulnessChannel.isAvailable]. Mirrors the existing
  /// opt-in write-back for BP/glucose/weight rather than inventing a second
  /// pattern for the same decision.
  bool get mindfulnessSync => _mindfulnessSync;

  Future<void> setMindfulnessSync(bool value) async {
    // Re-validated against the REAL grant rather than trusted: a user who
    // revokes the permission in the Health Connect app would otherwise leave this
    // switch stuck on, silently writing nothing.
    if (value && !await MindfulnessChannel.instance.hasPermission()) {
      _mindfulnessSync = false;
      await _savePreference(_kMindfulnessSync, false);
      notifyListeners();
      return;
    }
    _mindfulnessSync = value;
    await _savePreference(_kMindfulnessSync, value);
    notifyListeners();
  }

  /// Write a completed session to Health Connect, if it is mindfulness practice.
  ///
  /// Fire-and-forget by contract: never awaited by the completion path. A slow or
  /// hanging health provider must not sit between the user finishing a session and
  /// the session being saved — the same rule the vitals write-back follows.
  ///
  /// [mindfulnessKindFor] returns null for every activity that is concentration
  /// rather than practice, so a work sprint is not written at all.
  Future<void> _writeMindfulness(FocusSession session) async {
    if (!_mindfulnessSync) return;
    final kind = mindfulnessKindFor(session.activityType);
    if (kind == null) return;
    final end = session.completedAt;
    if (end == null) return;
    try {
      await MindfulnessChannel.instance.writeSession(
        start: session.startedAt,
        end: end,
        kind: kind,
        title: session.note,
        // The session id doubles as the Health Connect clientRecordId, so a
        // retry after a crash cannot double-write.
        clientId: session.id,
      );
    } catch (e) {
      debugPrint('Mindfulness write-back failed: $e');
    }
  }

  /// Record a completed breathing exercise as a mindfulness session.
  ///
  /// Breathing is the clearest case in the whole feature: it is guided practice
  /// with a defined start and end, and `MINDFULNESS_SESSION_TYPE_BREATHING`
  /// exists for exactly it.
  Future<void> writeBreathingMindfulness({
    required DateTime start,
    required DateTime end,
  }) async {
    if (!_mindfulnessSync) return;
    try {
      await MindfulnessChannel.instance.writeSession(
        start: start,
        end: end,
        kind: MindfulnessKind.breathing,
        title: 'Breathing exercise',
        clientId: 'breathing_${start.millisecondsSinceEpoch}',
      );
    } catch (e) {
      debugPrint('Breathing mindfulness write-back failed: $e');
    }
  }

  // ---- optional breathing pre-roll ----------------------------------------

  static const _kBreathingPreroll = 'focusBreathingPreroll';

  /// Whether to run a few breaths before the timer starts.
  ///
  /// Off by default. `BreathingWidget` already existed with real patterns and was
  /// already reachable from the More grid; this only offers it at the one moment
  /// it is a ritual rather than an activity.
  ///
  /// Honest about what it is: one sec's evidence is for friction placed before the
  /// DISTRACTION, not before the work, so this is a calm way in and nothing is
  /// claimed for it beyond that. It is not the 57%.
  bool _breathingPreroll = false;
  bool get breathingPreroll => _breathingPreroll;

  void setBreathingPreroll(bool value) {
    _breathingPreroll = value;
    _savePreference(_kBreathingPreroll, value);
    notifyListeners();
  }

  // ---- distraction tally + session review ---------------------------------

  /// Distractions tapped during the session in flight.
  final List<DistractionTap> _pendingDistractions = [];
  List<DistractionTap> get pendingDistractions =>
      List.unmodifiable(_pendingDistractions);

  /// Record that a named distraction pulled at the user, now.
  ///
  /// The "Distractions" screen has always been an honest note-to-self —
  /// `AppAllowList.isAppAllowed` was deleted precisely because it enforced
  /// nothing — and this is the thing that list can DO without a single new
  /// permission. No monitoring, no blocking; the user says so.
  ///
  /// Self-report is weaker data than usage stats and a stronger intervention:
  /// the tap IS the interposed pause that the friction literature credits, and it
  /// is available on a platform where real blocking is a dead end.
  ///
  /// Ignored when nothing is running: a tally has to belong to a session.
  void logDistraction(String appId) {
    if (!_isRunning || _startTime == null) return;
    final elapsed = clock.now().difference(_startTime!).inSeconds;
    _pendingDistractions
        .add(DistractionTap(appId: appId, atSecond: elapsed < 0 ? 0 : elapsed));
    notifyListeners();
  }

  /// Attach a self-reported quality to the most recent session.
  ///
  /// Applied AFTER the fact rather than collected before `_completeSession`
  /// returns, because the review has to be optional and non-blocking — a modal
  /// standing between the user and their finished session would make the one
  /// moment in this feature that should feel good into a form.
  ///
  /// 0 = went well, 1 = mixed, 2 = struggled. Lower is better, matching the mood
  /// index the correlation engine is already written against.
  Future<void> setLastSessionQuality(int quality) async {
    if (_sessions.isEmpty) return;
    final clamped = quality.clamp(0, 2);
    _sessions[0] = _sessions[0].copyWith(quality: clamped);
    notifyListeners();
    await _persistSession(_sessions[0]);
  }

  /// Session length in minutes, clamped to [kMinSessionMinutes]..[kMaxSessionMinutes].
  ///
  /// The bound used to exist only in the custom-duration sheet's text validation,
  /// so any other caller — or a corrupt persisted value — could set 0 (making
  /// `progress` a division by zero) or 100000.
  void setDuration(int minutes) {
    if (!_isRunning) {
      _selectedMinutes =
          minutes.clamp(kMinSessionMinutes, kMaxSessionMinutes);
      _saveData();
      notifyListeners();
    }
  }

  // ---- Pomodoro configuration (FOCUS-2) ----

  void setMode(FocusMode mode) {
    if (!_isRunning && _mode != mode) {
      _mode = mode;
      _saveData();
      notifyListeners();
    }
  }

  /// Update pomodoro parameters. Only takes effect while idle. Values are clamped
  /// to sane ranges; nulls leave the existing value unchanged.
  void setPomodoroConfig({
    int? workMinutes,
    int? shortBreakMinutes,
    int? longBreakMinutes,
    int? roundsBeforeLongBreak,
    int? totalRounds,
  }) {
    if (_isRunning) return;
    if (workMinutes != null) _workMinutes = workMinutes.clamp(1, 180);
    if (shortBreakMinutes != null) _shortBreakMinutes = shortBreakMinutes.clamp(1, 60);
    if (longBreakMinutes != null) _longBreakMinutes = longBreakMinutes.clamp(1, 120);
    if (roundsBeforeLongBreak != null) _roundsBeforeLongBreak = roundsBeforeLongBreak.clamp(1, 12);
    if (totalRounds != null) _totalRounds = totalRounds.clamp(1, 16);
    _saveData();
    notifyListeners();
  }

  void setPlant(PlantType plant) {
    if (!_isRunning && _unlockedPlants.contains(plant)) {
      _selectedPlant = plant;
      _saveData();
      notifyListeners();
    }
  }

  void setActivity(FocusActivityType activity) {
    if (!_isRunning) {
      _selectedActivity = activity;
      _saveData();
      notifyListeners();
    }
  }

  void setSelectedTags(List<String> tagIds) {
    if (!_isRunning) {
      _selectedTagIds = List<String>.from(tagIds);
      _saveData();
      notifyListeners();
    }
  }

  void toggleTag(String tagId) {
    if (_isRunning) return;
    if (_selectedTagIds.contains(tagId)) {
      _selectedTagIds.remove(tagId);
    } else {
      _selectedTagIds.add(tagId);
    }
    _saveData();
    notifyListeners();
  }

  void setSound(AmbientSoundType sound) {
    _selectedSound = sound;
    if (sound != AmbientSoundType.none) {
      _usedSounds.add(sound);
      _checkSoundExplorerAchievement();
      // If session is running, change the sound immediately
      if (_isRunning) {
        _audioService.playSound(sound, volume: _soundVolume);
      }
    } else if (_isRunning) {
      _audioService.stop();
    }
    _saveData();
    notifyListeners();
  }

  /// Set the ambient volume, optionally without persisting.
  ///
  /// `persist: false` is for the drag itself. The slider calls this on every
  /// frame, and this method used to call `_saveData()` — eighteen awaited Drift
  /// writes plus a JSON re-encode of the entire session history and garden, per
  /// frame, on the UI isolate, while audio was playing. The write now happens
  /// once, when the thumb is released.
  void setSoundVolume(double volume, {bool persist = true}) {
    _soundVolume = volume.clamp(0.0, 1.0);
    _audioService.setVolume(_soundVolume);
    if (persist) _savePreference('focusSoundVolume', _soundVolume);
    notifyListeners();
  }

  Future<void> startSession() async {
    if (_isRunning) return;

    // Retire the previous celebration. Clearing it HERE rather than in the
    // listener keeps consuming `justCompleted` a pure read, so a screen never has
    // to write back into the service to acknowledge something.
    justCompleted.value = null;

    _isRunning = true;
    _isPaused = false;
    _isOnBreak = false;
    _isLongBreak = false;
    _currentRound = 0;

    // In pomodoro mode the first interval is a WORK interval of _workMinutes;
    // _selectedMinutes is driven so the existing completion loop (coins/plant)
    // awards for the work length. Single mode uses the chosen duration as-is.
    if (_mode == FocusMode.pomodoro) {
      _selectedMinutes = _workMinutes;
    } else if (_mode == FocusMode.flow) {
      // A flow session has no chosen length, so `_phaseMinutes` becomes the HARD
      // CAP rather than a target. `_endTime` is still set, and still real: it is
      // the moment the session auto-stops.
      //
      // The cap is not defensive tidiness. Without it a count-up the user forgot
      // about would log a fourteen-hour session, which would then poison
      // `suggestedMinutes` (a median), the daily totals, and the coin economy at
      // two coins a minute.
      _selectedMinutes = kMaxSessionMinutes;
    }
    _phaseMinutes = _selectedMinutes;

    _remainingSeconds = _phaseMinutes * 60;
    _startTime = clock.now();
    _endTime = _startTime!.add(Duration(minutes: _phaseMinutes));

    // Start ambient sound if selected
    if (_selectedSound != AmbientSoundType.none) {
      await _audioService.playSound(_selectedSound, volume: _soundVolume);
    }

    _startTimer();
    await _saveActiveSession();
    _armCompletion();
    notifyListeners();
    debugPrint('✓ Focus session started (${_mode.name}): $_phaseMinutes minutes, ends at $_endTime');
  }

  /// Routes an elapsed interval to the correct completion handler. Break
  /// intervals never earn coins/plants; only work intervals do.
  Future<void> _onIntervalComplete() async {
    if (_mode == FocusMode.pomodoro && _isOnBreak) {
      await _completeBreak();
    } else {
      await _completeSession();
    }
  }

  /// Begins a break interval (pomodoro). No coins/plants are awarded here.
  void _startBreak() {
    _isOnBreak = true;
    _isPaused = false;
    // A long break lands after every _roundsBeforeLongBreak completed work rounds.
    _isLongBreak =
        _roundsBeforeLongBreak > 0 && _currentRound % _roundsBeforeLongBreak == 0;
    _phaseMinutes = _isLongBreak ? _longBreakMinutes : _shortBreakMinutes;
    _remainingSeconds = _phaseMinutes * 60;
    _startTime = clock.now();
    _endTime = _startTime!.add(Duration(minutes: _phaseMinutes));
    _startTimer();
    _armCompletion();
    notifyListeners();
    debugPrint('✓ Pomodoro break started (${_isLongBreak ? 'long' : 'short'}): $_phaseMinutes min');
  }

  /// Break finished → back to a work interval (pomodoro).
  Future<void> _completeBreak() async {
    _timer?.cancel();
    await _disarmCompletion();
    await _audioService.stop();
    _isOnBreak = false;
    _isLongBreak = false;

    // Start the work interval FIRST, then announce.
    //
    // Two fixes in one reordering:
    //
    //  * The notification was awaited between clearing `_isOnBreak` and calling
    //    `_startWork()`, so for the duration of a platform round trip the service
    //    sat in a state that is neither a break nor a work interval — `_endTime`
    //    still the break's, `_phaseMinutes` still the break's — and any listener
    //    that rebuilt in that window read an inconsistent phase.
    //  * The banner was UNGATED, so a pomodoro user watching the screen got a
    //    system notification dropped over it at the end of every single break.
    //    That is precisely the interruption `_announceCompletion` exists to avoid;
    //    it was fixed for completion and missed here. On screen the handover is
    //    already visible — the phase pill flips and the ring returns to the focus
    //    tone — so the banner is only useful to someone who is not looking.
    _startWork();

    if (!_isForeground) {
      await NotificationService().showFocusNotification(
        title: 'Break over ☕',
        body: 'Time to focus again — round ${_currentRound + 1} of $_totalRounds.',
      );
    }
  }

  /// Begins the next work interval (pomodoro).
  void _startWork() {
    _isOnBreak = false;
    _isPaused = false;
    _selectedMinutes = _workMinutes;
    _phaseMinutes = _workMinutes;
    _remainingSeconds = _phaseMinutes * 60;
    _startTime = clock.now();
    _endTime = _startTime!.add(Duration(minutes: _phaseMinutes));

    if (_selectedSound != AmbientSoundType.none) {
      _audioService.playSound(_selectedSound, volume: _soundVolume);
    }

    _startTimer();
    _saveActiveSession();
    _armCompletion();
    notifyListeners();
    debugPrint('✓ Pomodoro work started: round ${_currentRound + 1} of $_totalRounds');
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isRunning && !_isPaused && _endTime != null) {
        final now = clock.now();
        // CEIL, not truncate.
        //
        // `Duration.inSeconds` truncates toward zero, so with 0.4s of a 25-minute
        // session left it reported 0 and completed — the session ran up to a
        // second SHORT of its target every time, and the clock jumped from 00:01
        // straight to finished without ever displaying 00:00. Rounding up means
        // the last whole second is counted, so the full duration actually elapses.
        final ms = _endTime!.difference(now).inMilliseconds;
        applyTick((ms / 1000).ceil());
      }
    });
  }

  /// One second of countdown.
  ///
  /// Extracted from the `Timer.periodic` callback so a test can drive the real
  /// path without starting a session (which needs storage and audio). The
  /// important property — that a tick does NOT fire `notifyListeners()` — is
  /// only meaningful if it is asserted against this code rather than against
  /// the notifier in isolation.
  /// Whether the 1 Hz ticker is currently scheduled.
  ///
  /// Exposed so a test can assert the background/foreground contract without
  /// reaching into private state: the ticker must stop when the app leaves the
  /// screen and restart when it returns.
  @visibleForTesting
  bool get debugTimerActive => _timer?.isActive ?? false;

  /// Whether the armed notification had already fired when it was withdrawn.
  ///
  /// Exposed because it is the guard against announcing a completion twice, and
  /// the difference between "the OS told them" and "nobody told them" is not
  /// observable any other way from outside.
  @visibleForTesting
  bool get completionAlreadyAnnouncedForTesting => _completionDelivered;

  /// The instant a notification is currently armed for, or null.
  @visibleForTesting
  DateTime? get armedCompletionForTesting => _armedFor;

  /// Drive one tick using the CURRENT clock, exactly as the periodic timer does.
  ///
  /// `applyTick(int)` takes the remaining seconds as an argument, which makes it
  /// useless for testing the relationship between `_endTime` and the wall clock —
  /// and that relationship is where the defects were (completing early, drifting
  /// while backgrounded). This runs the real derivation instead.
  @visibleForTesting
  void applyTickFromClockForTesting() {
    if (!_isRunning || _isPaused || _endTime == null) return;
    final ms = _endTime!.difference(clock.now()).inMilliseconds;
    applyTick((ms / 1000).ceil());
  }

  @visibleForTesting
  void applyTick(int remaining) {
    // Hand the last three foreground seconds to the in-app celebration.
    //
    // AlarmManager can fire exactly at `_endTime` while this ticker only reaches
    // it up to a second later, so a user watching the screen would get a system
    // banner just BEFORE the toast — the one moment in the feature that should
    // feel good, pre-empted by a notification about it. Three seconds is chosen
    // to be safely wider than that skew; if the app is backgrounded inside the
    // window, `didChangeAppLifecycleState` re-arms.
    if (remaining <= 3 && remaining > 0 && _isForeground && _armedFor != null) {
      _disarmCompletion();
    }
    if (remaining <= 0) {
      _remainingSeconds = 0;
      // Publish 00:00 before the completion side effects run, so the readout has
      // a value to show for the final second instead of skipping it.
      tick.value = 0;
      _onIntervalComplete();
      return;
    }
    // Only update the UI if the second actually changed, to avoid jitter.
    if (_remainingSeconds != remaining) {
      _remainingSeconds = remaining;
      // Deliberately NOT notifyListeners(): see [tick]. This is the only
      // per-second signal, and it must not rebuild the whole screen.
      tick.value = remaining;
    }
  }

  void pauseSession() {
    if (_isRunning && !_isPaused) {
      _isPaused = true;
      _pauseStartTime = clock.now();
      _audioService.pause();
      _timer?.cancel(); // Save resources
      _saveActiveSession();
      // A paused session has no end time to announce. Leaving it armed would
      // announce the ORIGINAL end time while the user is still paused.
      _disarmCompletion();
      notifyListeners();
    }
  }

  void resumeSession() {
    if (_isRunning && _isPaused && _pauseStartTime != null && _endTime != null) {
      _isPaused = false;
      
      // Calculate how long we were paused
      final pauseDuration = clock.now().difference(_pauseStartTime!);
      
      // Push the end time forward by the pause duration
      _endTime = _endTime!.add(pauseDuration);
      _pauseStartTime = null;
      
      _audioService.resume();
      _startTimer(); // Check immediately
      _saveActiveSession();
      // Re-arm against the NEW `_endTime`, which the pause just pushed forward.
      // Re-arming rather than resuming matters: the same id replaces, so a
      // pause/resume cycle cannot leave a notification pointing at the old
      // instant.
      _armCompletion();
      notifyListeners();
    }
  }

  /// The break the Flowtime technique suggests after [focusedMinutes]: the
  /// focused time divided by five, clamped to 5–30.
  ///
  /// Offered at the end of a flow session and never auto-started. Auto-starting
  /// would reintroduce exactly what flow mode exists to avoid — a timer deciding
  /// when the user's attention is finished — and the 2025 scoping review is blunt
  /// that structured breaks cut *subjective* fatigue while RCTs show no objective
  /// advantage over self-regulated ones. So: a suggestion, with a button.
  static int suggestedBreakMinutes(int focusedMinutes) {
    if (focusedMinutes <= 0) return 5;
    return (focusedMinutes / 5).round().clamp(5, 30);
  }

  /// End a flow session and bank it as completed.
  ///
  /// The whole point of the mode: stopping is SUCCESS, not abandonment. Routing
  /// this through `abandonSession` would wither the plant and file the session as
  /// abandoned, which would be the app disagreeing with its own premise — and it
  /// would corrupt `suggestedMinutes`, which counts completed sessions only.
  ///
  /// The loveliest property falls out of that: a flow session's `actualMinutes`
  /// IS a completed length, so it feeds the median that single mode offers back
  /// as "your usual". Flow mode teaches the app the length you naturally stop at.
  /// No competitor can do this, because none of them measure natural stopping
  /// points — only whether you hit a number you picked in advance.
  Future<void> stopFlowSession() async {
    if (!_isRunning || _mode != FocusMode.flow) return;
    final elapsed = elapsedSeconds ~/ 60;
    if (elapsed < kMinSessionMinutes) {
      // Under a minute is not a session. Abandon rather than bank it, so a
      // mis-tap cannot enter a 0-minute "completed" row into the median.
      await abandonSession();
      return;
    }
    // `_completeSession` credits `_selectedMinutes`, which is the CAP in flow
    // mode — so it has to become the real elapsed length before completing.
    _selectedMinutes = elapsed.clamp(kMinSessionMinutes, kMaxSessionMinutes);
    _phaseMinutes = _selectedMinutes;
    _remainingSeconds = 0;
    await _completeSession();
  }

  Future<void> abandonSession() async {
    if (!_isRunning) return;

    _timer?.cancel();
    await _disarmCompletion();
    await _audioService.stop();

    // Abandoning during a pomodoro break just ends the session — a break grows
    // no plant, so nothing withers and no abandoned session is recorded.
    if (_mode == FocusMode.pomodoro && _isOnBreak) {
      _resetSession();
      await _saveData();
      debugPrint('✓ Pomodoro ended during break');
      return;
    }

    // Elapsed, floored to whole minutes.
    //
    // This was `_selectedMinutes - (_remainingSeconds ~/ 60)`, which OVER-credits:
    // the truncation on the remainder rounds the subtraction up, so abandoning a
    // 25-minute session after 30 seconds logged a full minute, and after 90
    // seconds logged two. Compute the elapsed side directly instead, and floor it.
    final elapsedSeconds =
        (_phaseMinutes > 0 ? _phaseMinutes * 60 : _selectedMinutes * 60) -
            _remainingSeconds;
    final elapsedMinutes = (elapsedSeconds ~/ 60).clamp(0, _selectedMinutes);
    
    // Create dead plant
    final deadPlant = FocusPlant(
      id: _generateId(),
      type: _selectedPlant,
      plantedAt: _startTime!,
      durationMinutes: elapsedMinutes,
      isAlive: false,
      growthProgress: progress,
      activity: _selectedActivity.name,
    );
    _garden.add(deadPlant);
    
    // Create abandoned session
    final session = FocusSession(
      id: _generateId(),
      startedAt: _startTime!,
      completedAt: clock.now(),
      targetMinutes: _selectedMinutes,
      actualMinutes: elapsedMinutes,
      wasCompleted: false,
      wasAbandoned: true,
      activityType: _selectedActivity,
      note: _pendingIntention,
      distractions: List<DistractionTap>.from(_pendingDistractions),
      plantType: _selectedPlant,
      soundUsed: _selectedSound,
      tagIds: List<String>.from(_selectedTagIds),
    );
    _sessions.insert(0, session);
    await _persistSession(session);
    // Deliberately NO mindfulness write here. An abandoned session is not a
    // completed practice, and a health record should not carry one.

    // Persist the session → tag mapping (also bumps tag usage counts)
    if (_selectedTagIds.isNotEmpty) {
      await TagService().tagSession(session.id, List<String>.from(_selectedTagIds));
    }

    // Update stats
    _stats = _stats.copyWith(
      totalSessions: _stats.totalSessions + 1,
      abandonedSessions: _stats.abandonedSessions + 1,
      totalPlants: _stats.totalPlants + 1,
      deadPlants: _stats.deadPlants + 1,
    );
    
    _resetSession();
    await _saveData();
    
    debugPrint('✓ Focus session abandoned');
  }

  Future<void> _completeSession() async {
    _timer?.cancel();
    // Before anything else: this both withdraws a pending notification and
    // records whether it already fired, which `_announceCompletion` needs to
    // avoid telling the user twice.
    await _disarmCompletion();
    await _audioService.stop();

    // Track whether this is the first completed session today (for streak bonus)
    final isFirstCompletedToday = !_sessions.any(
      (s) => s.wasCompleted && _isSameDay(s.startedAt, clock.now()),
    );

    // Create healthy plant
    final plant = FocusPlant(
      id: _generateId(),
      type: _selectedPlant,
      plantedAt: _startTime!,
      durationMinutes: _selectedMinutes,
      isAlive: true,
      growthProgress: 1.0,
      activity: _selectedActivity.name,
    );
    _garden.add(plant);
    
    // Create completed session
    final session = FocusSession(
      id: _generateId(),
      startedAt: _startTime!,
      completedAt: clock.now(),
      targetMinutes: _selectedMinutes,
      actualMinutes: _selectedMinutes,
      wasCompleted: true,
      wasAbandoned: false,
      activityType: _selectedActivity,
      note: _pendingIntention,
      distractions: List<DistractionTap>.from(_pendingDistractions),
      plantType: _selectedPlant,
      soundUsed: _selectedSound,
      tagIds: List<String>.from(_selectedTagIds),
    );
    _sessions.insert(0, session);
    await _persistSession(session);
    // Unawaited on purpose — see [_writeMindfulness]. Completed only: an
    // abandoned session is not a practice.
    _writeMindfulness(session);

    // Persist the session → tag mapping (also bumps tag usage counts)
    if (_selectedTagIds.isNotEmpty) {
      await TagService().tagSession(session.id, List<String>.from(_selectedTagIds));
    }

    // Update activity minutes
    final activityMinutes = Map<FocusActivityType, int>.from(_stats.minutesByActivity);
    activityMinutes[_selectedActivity] = (activityMinutes[_selectedActivity] ?? 0) + _selectedMinutes;
    
    // Update plant counts
    final plantCounts = Map<PlantType, int>.from(_stats.plantCounts);
    plantCounts[_selectedPlant] = (plantCounts[_selectedPlant] ?? 0) + 1;
    
    // Update stats
    _stats = _stats.copyWith(
      totalMinutes: _stats.totalMinutes + _selectedMinutes,
      totalSessions: _stats.totalSessions + 1,
      completedSessions: _stats.completedSessions + 1,
      totalPlants: _stats.totalPlants + 1,
      minutesByActivity: activityMinutes,
      plantCounts: plantCounts,
      lastSessionDate: clock.now(),
    );
    
    // Check for new plant unlocks
    await _checkPlantUnlocks();
    
    // Check achievements
    await _checkAchievements();
    
    // Update streak
    await _checkAndUpdateStreak();

    // Award focus coins for the completed session (Forest-style earn loop),
    // capped per session.
    //
    // Flow mode made this necessary: at two coins a minute an uncapped count-up
    // running to the ten-hour ceiling would pay 1,200 coins — twice the most
    // expensive tree — from one forgotten timer. The cap is deliberately well
    // above any real session, so it never touches an honest one; it exists so the
    // economy cannot be broken by walking away from the app.
    final coinsService = CoinsService();
    await coinsService.earnCoins(
      minutes: _selectedMinutes.clamp(0, kMaxCoinEarningMinutes),
      sessionId: session.id,
    );
    // Award a streak bonus once per day on the first completed session
    if (isFirstCompletedToday) {
      await coinsService.addStreakBonus(_stats.currentStreak);
    }

    // Pomodoro: this was a WORK interval. Advance the round counter, then either
    // finish the whole session (total-rounds reached) or auto-start a break.
    if (_mode == FocusMode.pomodoro) {
      _currentRound++;
      await _saveData();
      final finished = _currentRound >= _totalRounds;
      // Captured BEFORE the branch: `_resetSession()` sets `_currentRound` back to
      // 0, so the final round used to log "round 0/4 completed".
      final roundJustFinished = _currentRound;
      await _announceCompletion(session, finished: finished);
      if (finished) {
        _resetSession();
      } else {
        _startBreak();
      }
      debugPrint(
          '✓ Pomodoro work round $roundJustFinished/$_totalRounds completed');
      return;
    }

    await _announceCompletion(session, finished: true);
    _resetSession();
    await _saveData();

    debugPrint('✓ Focus session completed');
  }

  /// Tell the user their work finished — once, through the right channel, and
  /// without lying about what finished.
  ///
  /// Two decisions live here.
  ///
  /// **Where.** A system banner dropped over the screen you are already watching
  /// is not a celebration, it is an interruption. `_completeSession` used to fire
  /// one unconditionally, while the in-app celebration written for exactly this
  /// moment sat unused in `focus_toast.dart`. Foregrounded, publish [justCompleted]
  /// and let the screen present it; backgrounded, the notification is the only way
  /// to reach them and stays.
  ///
  /// **Whether.** In pomodoro mode this method is reached at the end of EVERY work
  /// interval, so a 4-round pomodoro announced "Session Complete!" four times —
  /// and three of those were false. [finished] gates the celebration on the whole
  /// session actually being over. A round handing over to a break is already
  /// visible on screen (the phase pill, the ring recolouring to the break tone),
  /// so only a backgrounded user needs telling, and they get the truth: which
  /// round, not which session.
  Future<void> _announceCompletion(
    FocusSession session, {
    required bool finished,
  }) async {
    if (!finished) {
      if (!_isForeground && !_completionDelivered) {
        await NotificationService().showFocusNotification(
          title: 'Round $_currentRound of $_totalRounds done',
          // Deliberately not naming the break length: whether this is a long
          // break is decided by `_startBreak`, which has not run yet, and
          // duplicating that rule here is how the two drift apart.
          body: 'Time for a break.',
        );
      }
      return;
    }

    // Foreground is NOT sufficient — someone has to be listening.
    //
    // `FocusScreen` is the only consumer of [justCompleted], and it is a PUSHED
    // ROUTE (`app_shell.dart:190-194`), not one of the four live IndexedStack
    // tabs. So the ordinary flow of starting a session and pressing back disposes
    // the only listener: the app is foregrounded, the notifier is set, nobody
    // reads it, and the user is never told their session finished. Before the
    // in-app celebration existed they at least got a notification, so this was a
    // regression introduced by the celebration itself — and it was dismissed once
    // on the mistaken belief that the Focus screen was a live tab.
    if (_isForeground && justCompleted.hasConsumer) {
      justCompleted.value = session;
    } else {
      // Reached whenever nobody is listening — which is the ordinary case, not
      // an edge one: `FocusScreen` is a PUSHED route, so starting a session and
      // pressing back disposes the only consumer of [justCompleted].
      //
      // `_completionDelivered` is the guard that makes the background fix safe.
      // A notification is armed for `_endTime` at the start of every phase, so
      // once the OS has delivered it there is nothing left to announce — and
      // announcing anyway is what a naive version of this fix does: the user who
      // stepped away gets the scheduled banner, then a second one the moment they
      // reopen the app. `_disarmCompletion()` at the top of `_completeSession()`
      // records whether that already happened.
      if (_completionDelivered) return;
      await NotificationService().showFocusNotification(
        title: 'Focus Session Complete! 🌱',
        body: 'Amazing! You focused for $_selectedMinutes minutes and grew a ${_selectedPlant.name}!',
      );
    }
  }

  void _resetSession() {
    // Clearing here covers every exit: completion, abandon, and the pomodoro
    // end-of-rounds path. Fire-and-forget is fine — the in-memory state is
    // already reset, so a failed write can only leave a stale record that
    // recovery discards as finished.
    _clearActiveSession();
    // Cleared here rather than in `_completeSession`, so BOTH exits — completed
    // and abandoned — record the intention and the tally before they go.
    _pendingIntention = null;
    _pendingDistractions.clear();
    // Belt and braces, and the `!= null` is load-bearing rather than defensive.
    //
    // Every exit already disarms, which leaves `_armedFor` null — so this is
    // normally a no-op, and it MUST be: `_disarmCompletion()` recomputes
    // `_completionDelivered`, and `_resetSession()` runs AFTER
    // `_announceCompletion` has read it. Sweeping unconditionally here reset the
    // flag to false on every completion and silently reintroduced the duplicate
    // announcement this whole mechanism exists to prevent.
    //
    // So the condition is also the assertion: if a future exit path forgets to
    // disarm, `_armedFor` is non-null and this catches it.
    if (_armedFor != null) _disarmCompletion();
    _isRunning = false;
    _isPaused = false;
    _remainingSeconds = 0;
    _startTime = null;
    _endTime = null;
    _pauseStartTime = null;
    _phaseMinutes = 0;
    _isOnBreak = false;
    _isLongBreak = false;
    _currentRound = 0;
    notifyListeners();
  }

  Future<void> _checkPlantUnlocks() async {
    for (final plant in PlantType.values) {
      if (!_unlockedPlants.contains(plant) && _stats.totalMinutes >= plant.unlockMinutes) {
        _unlockedPlants.add(plant);
        await NotificationService().showFocusNotification(
          title: 'New Plant Unlocked! ${plant.emoji}',
          body: 'You\'ve unlocked the ${plant.name}! Keep focusing to grow your garden.',
        );
      }
    }
  }

  Future<void> _checkAchievements() async {
    // Time-based achievements
    _updateAchievement(AchievementType.firstSession, 1);
    _updateAchievement(AchievementType.tenMinutes, _stats.totalMinutes);
    _updateAchievement(AchievementType.thirtyMinutes, _stats.totalMinutes);
    _updateAchievement(AchievementType.oneHour, _stats.totalMinutes);
    _updateAchievement(AchievementType.threeHours, _stats.totalMinutes);
    _updateAchievement(AchievementType.fiveHours, _stats.totalMinutes);
    _updateAchievement(AchievementType.tenHours, _stats.totalMinutes);
    _updateAchievement(AchievementType.twentyFiveHours, _stats.totalMinutes);
    _updateAchievement(AchievementType.fiftyHours, _stats.totalMinutes);
    _updateAchievement(AchievementType.hundredHours, _stats.totalMinutes);
    
    // Plant achievements
    _updateAchievement(AchievementType.firstPlant, _stats.alivePlants);
    _updateAchievement(AchievementType.tenPlants, _stats.alivePlants);
    _updateAchievement(AchievementType.fiftyPlants, _stats.alivePlants);
    _updateAchievement(AchievementType.hundredPlants, _stats.alivePlants);
    
    // Plant collector
    _updateAchievement(AchievementType.allPlants, _unlockedPlants.length);
    
    // Time of day achievements
    final hour = clock.now().hour;
    if (hour < 7) {
      _updateAchievement(AchievementType.earlyBird, 1);
    }
    if (hour >= 22) {
      _updateAchievement(AchievementType.nightOwl, 1);
    }
    
    // Weekend warrior
    if (clock.now().weekday >= 6) {
      final weekendSessions = _sessions
          .where((s) => s.startedAt.weekday >= 6 && s.wasCompleted)
          .length;
      _updateAchievement(AchievementType.weekendWarrior, weekendSessions);
    }

    // Perfect week — seven distinct days, each with a completed session.
    //
    // This had NO updater at all: it was rendered in the achievements grid with a
    // 0/7 bar that nothing could ever move. Of the twenty-four types it was the
    // only one a user could see and never earn, which is worse than not shipping
    // it — an achievement that cannot be earned reads as a broken app rather than
    // an absent feature.
    //
    // Deliberately NOT the streak. `StreakEngine` forgives one miss per rolling
    // week, so a 7-day streak can contain a day with no session — and calling
    // that a "perfect week" would quietly contradict the forgiveness the rest of
    // the feature is careful to be honest about. This counts actual days.
    final today = clock.now();
    final weekStart = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 6));
    final daysThisWeek = _completedSessionDays()
        .where((d) => !d.isBefore(weekStart))
        .length;
    _updateAchievement(AchievementType.perfectWeek, daysThisWeek);
  }

  void _updateAchievement(AchievementType type, int progress) {
    final current = _achievements[type];
    if (current != null && !current.isUnlocked) {
      if (progress >= type.requiredValue) {
        _achievements[type] = current.copyWith(
          currentProgress: progress,
          isUnlocked: true,
          unlockedAt: clock.now(),
        );
        _notifyAchievementUnlocked(type);
      } else {
        _achievements[type] = current.copyWith(currentProgress: progress);
      }
    }
  }

  /// The single choke point every unlock passes through.
  ///
  /// The coin award belongs HERE and not at each `_updateAchievement` call site,
  /// for the same reason the notification does: twenty-four types unlock through
  /// one function, and anything hung off the call sites instead would be missing
  /// from whichever one is added next. `CoinsService.addAchievementBonus` had no
  /// caller at all, so achievements fired a notification and paid nothing, while
  /// a method advertising a payout sat unused in the ledger.
  Future<void> _notifyAchievementUnlocked(AchievementType type) async {
    await CoinsService().addAchievementBonus(type.coinReward, type.name);
    await NotificationService().showFocusNotification(
      title: 'Achievement Unlocked! ${type.emoji}',
      body: '${type.name}: ${type.description} · +${type.coinReward} coins',
    );
  }

  void _checkSoundExplorerAchievement() {
    _updateAchievement(AchievementType.soundExplorer, _usedSounds.length);
  }

  /// Days with at least one completed focus session — the input to the shared,
  /// forgiving [StreakEngine].
  Set<DateTime> _completedSessionDays() {
    final days = <DateTime>{};
    for (final s in _sessions) {
      if (!s.wasCompleted) continue;
      days.add(DateTime(s.startedAt.year, s.startedAt.month, s.startedAt.day));
    }
    return days;
  }

  /// Recompute the focus streak from session history via the shared
  /// [StreakEngine] — the same engine, and the same one-grace-day-per-rolling-
  /// week, that medicine, steps and water use. The old logic hard-reset the
  /// streak to 1 on any gap larger than a day and inferred it from
  /// `lastSessionDate` alone, so one missed day wiped a long run. Deriving it
  /// from the actual sessions also makes it idempotent — running this on every
  /// init and every completion can no longer double-count.
  Future<void> _checkAndUpdateStreak() async {
    final result = StreakEngine.compute(
      completedDays: _completedSessionDays(),
      today: clock.now(),
      graceDaysPerWeek: 1,
    );
    final newStreak = result.current;
    _streakUsedGrace = result.usedGrace;
    _streakAtRisk = result.atRisk;

    _stats = _stats.copyWith(
      currentStreak: newStreak,
      // Persisted history is trimmed to the last 100 sessions, so never let a
      // recompute shrink a longest streak the user already earned.
      longestStreak: max(_stats.longestStreak, max(result.longest, newStreak)),
    );

    if (newStreak > 0) {
      _updateAchievement(AchievementType.firstStreak, newStreak);
      _updateAchievement(AchievementType.weekStreak, newStreak);
      _updateAchievement(AchievementType.monthStreak, newStreak);
    }

    await _saveData();
  }

  void incrementBreathingCount() async {
    final prefs = CleanStorageService.getAppPreferences();
    int breathingCount = prefs['focusBreathingCount'] ?? 0;
    breathingCount++;
    await CleanStorageService.setAppPreference('focusBreathingCount', breathingCount);
    _updateAchievement(AchievementType.breathingMaster, breathingCount);
    await _saveData();
  }

  String _generateId() {
    return '${clock.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
  }

  List<FocusPlant> getGardenForDate(DateTime date) {
    return _garden.where((p) => _isSameDay(p.plantedAt, date)).toList();
  }

  Map<DateTime, List<FocusPlant>> getGardenByWeek() {
    final Map<DateTime, List<FocusPlant>> grouped = {};
    for (final plant in _garden) {
      final weekStart = plant.plantedAt.subtract(Duration(days: plant.plantedAt.weekday - 1));
      final key = DateTime(weekStart.year, weekStart.month, weekStart.day);
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(plant);
    }
    return grouped;
  }

  // ============ BACKUP HELPERS ============

  /// Export completed/abandoned focus sessions as JSON for the full app backup.
  /// (Other focus state — stats, garden, coins, achievements — already round-trips
  /// via the `preferences` section of the backup.)
  List<Map<String, dynamic>> exportSessionsJson() {
    return _sessions.map((s) => s.toJson()).toList();
  }

  /// Restore focus sessions from a backup. Non-destructive: sessions are merged
  /// by id (existing sessions are kept, new ones added) so restoring can't wipe
  /// the running session history. Malformed entries are skipped. After merging,
  /// the in-memory service and its persisted copy are refreshed so the UI updates.
  Future<void> importSessionsJson(List<dynamic> data) async {
    if (data.isEmpty) return;
    final existingIds = _sessions.map((s) => s.id).toSet();
    for (final raw in data) {
      try {
        final session = FocusSession.fromJson(Map<String, dynamic>.from(raw as Map));
        if (existingIds.add(session.id)) {
          _sessions.add(session);
        }
      } catch (e) {
        debugPrint('Import focus session failed: $e');
      }
    }
    // Keep newest-first ordering used throughout the service.
    _sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    // Persist the WHOLE merged set, not `_saveData()`.
    //
    // This is the defect that made the cap worse than the cap: import merged a
    // backup into memory (which could reach 300) and then `_saveData()` wrote
    // `.take(100)` — so restoring a 300-session backup kept 100, and the user was
    // told the restore succeeded.
    await _focusDao.upsertAll(_sessions.map(_toCompanion).toList());
    await _saveData();
    notifyListeners();
  }

  /// Check if audio is currently playing
  bool get isAudioPlaying => _audioService.isPlaying;

  /// Toggle audio playback
  Future<void> toggleAudio() async {
    await _audioService.toggle();
    notifyListeners();
  }

  /// Return the singleton to a fresh-install state between tests.
  ///
  /// Needed because this is a process-wide singleton with ~25 mutable fields, a
  /// Timer, a ValueNotifier and a registered lifecycle observer, and
  /// `flutter test` shares one isolate across a file. Without it, tests leak into
  /// each other — the old suite actually depended on that, setting a duration in
  /// one test and reading it in the next.
  ///
  /// `tick` is RESET, never disposed: disposing a singleton's notifier poisons
  /// every later test in the isolate.
  @visibleForTesting
  void resetForTesting() {
    _timer?.cancel();
    _timer = null;
    if (_didInit) {
      WidgetsBinding.instance.removeObserver(this);
      _didInit = false;
    }
    _isRunning = false;
    _isPaused = false;
    _remainingSeconds = 0;
    _startTime = null;
    _endTime = null;
    _pauseStartTime = null;
    _phaseMinutes = 0;
    _breathingPreroll = false;
    _mindfulnessSync = false;
    _mode = FocusMode.single;
    _workMinutes = 25;
    _shortBreakMinutes = 5;
    _longBreakMinutes = 15;
    _roundsBeforeLongBreak = 4;
    _totalRounds = 4;
    _isOnBreak = false;
    _isLongBreak = false;
    _currentRound = 0;
    _selectedMinutes = 25;
    _selectedPlant = PlantType.seedling;
    _selectedActivity = FocusActivityType.work;
    _selectedSound = AmbientSoundType.none;
    _soundVolume = 0.5;
    _selectedTagIds = [];
    // Reset, never dispose: this is a process-wide singleton, and disposing its
    // notifiers poisons every later test in the isolate.
    justCompleted.value = null;
    _pendingIntention = null;
    _pendingDistractions.clear();
    _armedFor = null;
    _completionDelivered = false;
    _isForeground = true;
    _streakUsedGrace = false;
    _streakAtRisk = false;
    // History too. Without this, sessions/garden/stats accumulate across tests in
    // one file and every `sessions.single` assertion becomes order-dependent —
    // which is not a hypothetical: it broke the abandon test the first time.
    _sessions = [];
    _garden = [];
    _achievements.clear();
    _unlockedPlants = {PlantType.seedling, PlantType.sprout};
    _usedSounds = {};
    _stats = const FocusStats();
    tick.value = 0;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _audioService.stop();
    tick.dispose();
    super.dispose();
  }
}
