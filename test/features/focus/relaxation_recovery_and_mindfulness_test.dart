/// A relaxation session the app was closed under, and relaxation as mindful minutes.
///
/// Nothing was kept of a running session between launches, so the system reclaiming
/// the app, a crash or an update ended it with no trace: the screen came back idle and
/// the minutes already listened to were never recorded. Now a running or paused
/// session is kept, and found again at start-up. One whose end passed while the app was
/// not running is dropped rather than credited — the track died with the app, so
/// nobody can say how long it was listened to.
///
/// And a completed Stress Relief session can be saved as mindful minutes, when the
/// person has asked for that. Deep Focus (work music) and Full Reset (sleep audio)
/// are not mindfulness practice and are never written.
library;


import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/mindfulness_channel.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/features/focus/models/relaxation_music.dart';
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/relaxation_service.dart';
import 'package:tablet_remainder/features/focus/services/relaxation_snapshot.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';

import '../../support/fake_audio_engine.dart';
import '../../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final t0 = DateTime(2026, 3, 14, 13, 0);

  group('the snapshot', () {
    RelaxationSnapshot snap({int? paused, int minutes = 10}) => RelaxationSnapshot(
          startedAt: t0,
          endTime: t0.add(Duration(minutes: minutes)),
          minutes: minutes,
          music: RelaxationMusicType.deepSleepDelta,
          category: RelaxationCategory.nervousSystemReset,
          pausedRemainingSeconds: paused,
        );

    Map<String, dynamic> good() => snap().toJson();

    test('survives a round trip', () {
      final back = RelaxationSnapshot.fromJson(snap(paused: 300).toJson())!;
      expect(back.startedAt, t0);
      expect(back.endTime, t0.add(const Duration(minutes: 10)));
      expect(back.minutes, 10);
      expect(back.music, RelaxationMusicType.deepSleepDelta);
      expect(back.category, RelaxationCategory.nervousSystemReset);
      expect(back.pausedRemainingSeconds, 300);
      expect(back.paused, isTrue);
      expect(RelaxationSnapshot.fromJson(snap().toJson())!.paused, isFalse);
    });

    test('a whole number that came back as a double is still read', () {
      final j = good()..['minutes'] = 10.0;
      expect(RelaxationSnapshot.fromJson(j), isNotNull);
    });

    test('anything it cannot trust is null, never a throw', () {
      Map<String, dynamic> with_(String k, Object? v) => good()..[k] = v;
      expect(RelaxationSnapshot.fromJson(null), isNull);
      expect(RelaxationSnapshot.fromJson('nope'), isNull);
      expect(RelaxationSnapshot.fromJson([1, 2]), isNull);
      for (final k in ['startedAt', 'endTime', 'minutes', 'music', 'category']) {
        expect(RelaxationSnapshot.fromJson(good()..remove(k)), isNull, reason: 'no $k');
        expect(RelaxationSnapshot.fromJson(with_(k, 'x')), isNull, reason: 'bad $k');
      }
      expect(RelaxationSnapshot.fromJson(with_('minutes', 0)), isNull);
      expect(RelaxationSnapshot.fromJson(with_('minutes', 1)), isNotNull);
      expect(RelaxationSnapshot.fromJson(with_('minutes', RelaxationSnapshot.maxMinutes)),
          isNotNull);
      expect(RelaxationSnapshot.fromJson(with_('minutes', RelaxationSnapshot.maxMinutes + 1)),
          isNull);
      expect(RelaxationSnapshot.fromJson(with_('minutes', 10.5)), isNull);
      expect(RelaxationSnapshot.fromJson(with_('music', -1)), isNull);
      expect(RelaxationSnapshot.fromJson(with_('music', RelaxationMusicType.values.length)),
          isNull);
      expect(RelaxationSnapshot.fromJson(with_('music', RelaxationMusicType.values.length - 1)),
          isNotNull);
      expect(RelaxationSnapshot.fromJson(with_('category', -1)), isNull);
      expect(RelaxationSnapshot.fromJson(with_('category', RelaxationCategory.values.length)),
          isNull);
      expect(RelaxationSnapshot.fromJson(with_('endTime', t0.millisecondsSinceEpoch)), isNull,
          reason: 'it cannot end when it began');
      expect(RelaxationSnapshot.fromJson(with_('pausedRemaining', -1)), isNull);
      expect(RelaxationSnapshot.fromJson(with_('pausedRemaining', 601)), isNull);
      expect(RelaxationSnapshot.fromJson(with_('pausedRemaining', 600)), isNotNull);
      expect(RelaxationSnapshot.fromJson(with_('pausedRemaining', 'x')), isNull);
      expect(RelaxationSnapshot.fromJson(with_('pausedRemaining', 0)), isNotNull);
    });

    test('what to do with it', () {
      final running = snap();
      expect(running.recoveryAt(t0.add(const Duration(minutes: 3))),
          RelaxationRecovery.resume);
      expect(running.recoveryAt(t0.add(const Duration(minutes: 10))),
          RelaxationRecovery.expired, reason: 'the end itself is over');
      expect(running.recoveryAt(t0.add(const Duration(minutes: 10, milliseconds: -1))),
          RelaxationRecovery.resume);
      expect(running.recoveryAt(t0.add(const Duration(hours: 5))),
          RelaxationRecovery.expired);
      expect(snap(paused: 120).recoveryAt(t0.add(const Duration(hours: 5))),
          RelaxationRecovery.paused,
          reason: 'a paused session does not run out while the app is closed');
    });

    test('the time left', () {
      final running = snap();
      expect(running.remainingSecondsAt(t0.add(const Duration(minutes: 3))), 420);
      expect(running.remainingSecondsAt(t0.add(const Duration(minutes: 10, milliseconds: -1500))),
          2, reason: 'rounded up, as the countdown rounds');
      expect(running.remainingSecondsAt(t0.add(const Duration(minutes: 11))), 0);
      expect(snap(paused: 123).remainingSecondsAt(t0.add(const Duration(hours: 9))), 123);
    });
  });

  group('the service', () {
    late AppDatabase db;
    late FakeAudioEngine engine;
    late RecordingNotificationScheduler notifications;
    final service = RelaxationService();

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.forTesting(NativeDatabase.memory());
      AppDatabase.setInstanceForTesting(db);
      ActiveProfileService().resetForTesting();
      CleanStorageService.resetForTesting();
      await CleanStorageService.loadAppPreferences();
      engine = FakeAudioEngine();
      AudioService().engineForTesting = engine;
      AudioService().resetForTesting();
      notifications = RecordingNotificationScheduler();
      NotificationService().schedulerForTesting = notifications;
      FocusService().resetForTesting();
      CoinsService().resetForTesting();
      TagService().resetForTesting();
      service.resetForTesting();
    });

    tearDown(() async {
      service.resetForTesting();
      FocusService().resetForTesting();
      await db.close();
    });

    Future<T> at<T>(DateTime t, Future<T> Function() body) =>
        withClock(Clock.fixed(t), body);

    Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 50));

    /// Start a session of [minutes] at [t0], then close the app.
    Future<void> startThenClose({
      int minutes = 10,
      RelaxationMusicType music = RelaxationMusicType.deepSleepDelta,
    }) async {
      await at(t0, () async {
        await service.init();
        service.setMusic(music);
        service.setDuration(minutes);
        await service.startSession();
        await settle();
      });
      service.resetForTesting();
      engine.reset();
    }

    /// Open the app again at [t].
    Future<void> reopenAt(DateTime t) => at(t, () async {
          await service.init();
          await settle();
        });

    Object? stored() => CleanStorageService.getAppPreferences()['relaxationActive'];

    test('a started session is kept', () async {
      await startThenClose(minutes: 10);
      final snap = RelaxationSnapshot.fromJson(stored())!;
      expect(snap.startedAt, t0);
      expect(snap.endTime, t0.add(const Duration(minutes: 10)));
      expect(snap.minutes, 10);
      expect(snap.music, RelaxationMusicType.deepSleepDelta);
      expect(snap.category, RelaxationCategory.nervousSystemReset);
      expect(snap.paused, isFalse);
    });

    test('a running session carries on after a restart, with what is left', () async {
      await startThenClose(minutes: 10);
      await reopenAt(t0.add(const Duration(minutes: 3)));

      expect(service.isRunning, isTrue);
      expect(service.isPaused, isFalse);
      expect(service.remainingSeconds, 420);
      expect(service.selectedMinutes, 10);
      expect(service.selectedMusic, RelaxationMusicType.deepSleepDelta);
      expect(service.selectedCategory, RelaxationCategory.nervousSystemReset);
      expect(engine.loadCalls, greaterThan(0), reason: 'the track plays again');
    });

    test('and finishes through the normal path, credited as started', () async {
      await startThenClose(minutes: 10);
      await reopenAt(t0.add(const Duration(minutes: 3)));

      // Still counting towards the ORIGINAL end: a minute before it, one minute left.
      await at(t0.add(const Duration(minutes: 9)), () async {
        service.applyTick();
        await settle();
      });
      expect(service.isRunning, isTrue);
      expect(service.remainingSeconds, 60);

      await at(t0.add(const Duration(minutes: 10, seconds: 1)), () async {
        service.applyTick();
        await settle();
      });
      expect(service.isRunning, isFalse);
      final s = service.sessions.single;
      expect(s.wasCompleted, isTrue);
      expect(s.startedAt, t0);
      expect(s.actualMinutes, 10);
      expect(stored(), isNull, reason: 'a finished session is not kept');
    });

    test('a paused session comes back paused with the time it had left, however '
        'long the app was closed', () async {
      await at(t0, () async {
        await service.init();
        service.setMusic(RelaxationMusicType.deepSleepDelta);
        service.setDuration(10);
        await service.startSession();
      });
      await at(t0.add(const Duration(minutes: 2)), () async {
        service.pauseSession();
        await settle();
      });
      expect(RelaxationSnapshot.fromJson(stored())!.pausedRemainingSeconds, 480);
      service.resetForTesting();
      engine.reset();

      await reopenAt(t0.add(const Duration(hours: 3)));
      expect(service.isRunning, isTrue);
      expect(service.isPaused, isTrue);
      expect(service.remainingSeconds, 480);

      // Resuming plays the track again (nothing is loaded to resume) and the time
      // left is what it was.
      await at(t0.add(const Duration(hours: 3, minutes: 1)), () async {
        service.resumeSession();
        await settle();
        service.applyTick();
      });
      expect(service.isPaused, isFalse);
      expect(service.remainingSeconds, 480);
      expect(engine.loadCalls, greaterThan(0));
      final snap = RelaxationSnapshot.fromJson(stored())!;
      expect(snap.paused, isFalse);
      expect(snap.endTime, t0.add(const Duration(hours: 3, minutes: 9)));
    });

    test('resuming without a restart still resumes the loaded track', () async {
      await at(t0, () async {
        await service.init();
        service.setMusic(RelaxationMusicType.deepSleepDelta);
        service.setDuration(10);
        await service.startSession();
        await settle();
        service.pauseSession();
        engine.calls.clear();
        engine.loadedSources.clear();
        service.resumeSession();
        await settle();
      });
      expect(engine.loadCalls, 0, reason: 'nothing to reload');
      expect(engine.calls, contains('play'));
    });

    test('one whose end passed while the app was closed is dropped, not credited',
        () async {
      await startThenClose(minutes: 10);
      await reopenAt(t0.add(const Duration(minutes: 11)));

      expect(service.isRunning, isFalse);
      expect(service.sessions, isEmpty);
      expect(service.stats.totalSessions, 0);
      expect(service.stats.totalMinutes, 0);
      expect(stored(), isNull);
      expect(engine.loadCalls, 0);
    });

    test('exactly at its end is over too', () async {
      await startThenClose(minutes: 10);
      await reopenAt(t0.add(const Duration(minutes: 10)));
      expect(service.isRunning, isFalse);
      expect(service.sessions, isEmpty);
    });

    test('something stored that cannot be read is dropped, without a throw', () async {
      await CleanStorageService.setAppPreference('relaxationActive', 'garbage');
      await reopenAt(t0);
      expect(service.isRunning, isFalse);
      expect(stored(), isNull);

      await CleanStorageService.setAppPreference(
          'relaxationActive', {'startedAt': 'x', 'endTime': 1});
      service.resetForTesting();
      await reopenAt(t0);
      expect(service.isRunning, isFalse);
      expect(stored(), isNull);
    });

    test('abandoning clears it', () async {
      await at(t0, () async {
        await service.init();
        service.setMusic(RelaxationMusicType.deepSleepDelta);
        service.setDuration(10);
        await service.startSession();
        await settle();
        expect(stored(), isNotNull);
        await service.abandonSession();
        await settle();
      });
      expect(stored(), isNull);
    });

    test('nothing is kept when nothing runs, and a normal launch is unchanged',
        () async {
      await reopenAt(t0);
      expect(service.isRunning, isFalse);
      expect(stored(), isNull);
      expect(engine.loadCalls, 0);
    });
  });

  group('as mindful minutes', () {
    late AppDatabase db;
    late List<MethodCall> channelCalls;
    const channel = MethodChannel('dlyminder/mindfulness');
    final service = RelaxationService();

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.forTesting(NativeDatabase.memory());
      AppDatabase.setInstanceForTesting(db);
      ActiveProfileService().resetForTesting();
      CleanStorageService.resetForTesting();
      await CleanStorageService.loadAppPreferences();
      AudioService().engineForTesting = FakeAudioEngine();
      AudioService().resetForTesting();
      NotificationService().schedulerForTesting = RecordingNotificationScheduler();
      FocusService().resetForTesting();
      CoinsService().resetForTesting();
      TagService().resetForTesting();
      service.resetForTesting();
      channelCalls = [];
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      MindfulnessChannel.channelForTesting = channel;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        channelCalls.add(call);
        return true;
      });
    });

    tearDown(() async {
      service.resetForTesting();
      FocusService().resetForTesting();
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      await db.close();
    });

    List<MethodCall> writes() =>
        channelCalls.where((c) => c.method == 'writeSession').toList();

    /// Run one [minutes]-long session of [music] to its end, from [t0].
    Future<void> runToEnd(RelaxationMusicType music, {int minutes = 10}) async {
      await withClock(Clock.fixed(t0), () => service.init());
      final before = service.sessions.length; // what a restart brought back
      await withClock(Clock.fixed(t0), () async {
        service.setMusic(music);
        service.setDuration(minutes);
        await service.startSession();
      });
      await withClock(Clock.fixed(t0.add(Duration(minutes: minutes, seconds: 1))), () async {
        service.applyTick();
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      expect(service.sessions, hasLength(before + 1),
          reason: 'the session really finished');
    }

    test('which categories are mindfulness', () {
      expect(mindfulnessKindForRelaxation(RelaxationCategory.stressRelief),
          MindfulnessKind.meditation);
      expect(mindfulnessKindForRelaxation(RelaxationCategory.deepFocus), isNull,
          reason: 'work music is not practice');
      expect(mindfulnessKindForRelaxation(RelaxationCategory.nervousSystemReset), isNull,
          reason: 'sleep audio is played while falling asleep');
    });

    test('a finished Stress Relief session is written, when it was asked for',
        () async {
      await FocusService().setMindfulnessSync(true);
      channelCalls.clear();
      await runToEnd(RelaxationMusicType.healing432Hz);

      final args = Map<String, dynamic>.from(writes().single.arguments as Map);
      expect(args['startMs'], t0.millisecondsSinceEpoch);
      expect(args['endMs'], t0.add(const Duration(minutes: 10, seconds: 1)).millisecondsSinceEpoch);
      expect(args['kind'], MindfulnessKind.meditation.index);
      expect(args['title'], 'Relaxation');
      expect((args['clientId'] as String).startsWith('relaxation_'), isTrue);
    });

    test('with the switch off, nothing is written', () async {
      await runToEnd(RelaxationMusicType.healing432Hz);
      expect(writes(), isEmpty);
    });

    test('Deep Focus and Full Reset are never written', () async {
      await FocusService().setMindfulnessSync(true);
      channelCalls.clear();
      await runToEnd(RelaxationMusicType.lofiHipHop);
      expect(writes(), isEmpty);

      service.resetForTesting();
      await runToEnd(RelaxationMusicType.deepSleepDelta);
      expect(writes(), isEmpty);
    });

    test('an abandoned session is not written', () async {
      await FocusService().setMindfulnessSync(true);
      channelCalls.clear();
      await withClock(Clock.fixed(t0), () async {
        await service.init();
        service.setMusic(RelaxationMusicType.healing432Hz);
        service.setDuration(10);
        await service.startSession();
        await service.abandonSession();
      });
      expect(writes(), isEmpty);
    });
  });
}
