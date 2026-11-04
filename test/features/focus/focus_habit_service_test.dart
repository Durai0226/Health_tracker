/// "Your usual round around now", as the focus service decides it: from the rounds
/// already finished, the time of day, and what is set up now.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/health/focus_habit.dart';
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/features/focus/models/ambient_sound.dart';
import 'package:tablet_remainder/features/focus/models/focus_plant.dart';
import 'package:tablet_remainder/features/focus/models/focus_session.dart';
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_session_alarm.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';

import '../../support/fake_audio_engine.dart';
import '../../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  final focus = FocusService();
  final t0 = DateTime(2026, 3, 14, 9, 30);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.loadAppPreferences();
    AudioService().engineForTesting = FakeAudioEngine();
    NotificationService().schedulerForTesting = RecordingNotificationScheduler();
    focus.alarmForTesting = RecordingFocusSessionAlarm();
    focus.resetForTesting();
    CoinsService().resetForTesting();
    TagService().resetForTesting();
    await focus.init();
  });

  tearDown(() async {
    focus.resetForTesting();
    await db.close();
  });

  var counter = 0;

  /// A finished round [daysAgo] days before [t0], started at [hour]:00.
  Map<String, dynamic> round(
    int daysAgo, {
    FocusActivityType activity = FocusActivityType.study,
    int minutes = 45,
    int hour = 9,
    int minute = 0,
    AmbientSoundType? sound = AmbientSoundType.rain,
  }) {
    counter++;
    final start = DateTime(2026, 3, 14 - daysAgo, hour, minute);
    return FocusSession(
      id: 'habit-$counter',
      startedAt: start,
      completedAt: start.add(Duration(minutes: minutes)),
      targetMinutes: minutes,
      actualMinutes: minutes,
      wasCompleted: true,
      activityType: activity,
      plantType: PlantType.seedling,
      soundUsed: sound,
    ).toJson();
  }

  /// Five mornings of studying for 45 minutes with rain.
  Future<void> aRoutine({int days = 5}) =>
      focus.importSessionsJson([for (var d = 1; d <= days; d++) round(d)]);

  FocusHabit? habitAt(DateTime at) =>
      withClock(Clock.fixed(at), () => focus.habitSuggestion);

  FocusHabit? habit() => habitAt(t0);

  group('the history of rounds says when it changes', () {
    // For a screen that only wants to know — Trends, which stays mounted — and which
    // must NOT listen to `justCompleted`: whether anyone listens to that decides if a
    // finished round is celebrated on screen or announced by notification.
    test('restored rounds do', () async {
      final before = focus.sessionsRevision.value;

      await aRoutine();

      expect(focus.sessionsRevision.value, greaterThan(before));
    });

    test('a round abandoned does', () async {
      await withClock(Clock.fixed(t0), focus.startSession);
      final before = focus.sessionsRevision.value;

      await withClock(Clock.fixed(t0), focus.abandonSession);

      expect(focus.sessionsRevision.value, greaterThan(before));
    });

    test('and nothing about it makes `justCompleted` look listened to', () async {
      await aRoutine();

      expect(focus.justCompleted.hasConsumer, isFalse);
    });
  });

  group('when it is offered', () {
    test('a routine at this hour, when the setup is something else', () async {
      await aRoutine();

      final h = habit()!;

      expect(h.activity, FocusActivityType.study.index);
      expect(h.minutes, 45);
      expect(h.sound, AmbientSoundType.rain.index);
      expect(h.times, 5);
    });

    test('nothing, with no routine', () async {
      await aRoutine(days: 3);
      expect(habit(), isNull);
    });

    test('not at another hour of the day', () async {
      await aRoutine();
      expect(habitAt(DateTime(2026, 3, 14, 15, 30)), isNull);
    });

    test('"around now" is judged at THIS minute, not at the start of the hour', () async {
      // Routine at 08:30. At 09:05 that is 35 minutes ago, so it is offered; at 09:35
      // it is 65 minutes ago, so it is not. Both are in the 09:00 hour: a result kept
      // for the hour would have answered the second with the first.
      await focus.importSessionsJson(
          [for (var d = 1; d <= 5; d++) round(d, hour: 8, minute: 30)]);

      expect(habitAt(DateTime(2026, 3, 14, 9, 5)), isNotNull);
      expect(habitAt(DateTime(2026, 3, 14, 9, 35)), isNull);
      expect(habitAt(DateTime(2026, 3, 14, 9, 5)), isNotNull, reason: 'and back');
    });

    test('not while a round is running', () async {
      await aRoutine();
      await withClock(Clock.fixed(t0), focus.startSession);

      expect(habit(), isNull);
      await withClock(Clock.fixed(t0), focus.abandonSession);
    });
  });

  group('when the setup already is that', () {
    setUp(() async {
      await aRoutine();
      withClock(Clock.fixed(t0), () {
        focus.setActivity(FocusActivityType.study);
        focus.setDuration(45);
        focus.setSound(AmbientSoundType.rain);
      });
    });

    test('there is nothing to offer', () {
      expect(habit(), isNull);
    });

    test('but a different activity brings it back', () {
      withClock(Clock.fixed(t0), () => focus.setActivity(FocusActivityType.work));
      expect(habit(), isNotNull);
    });

    test('so does a different length', () {
      withClock(Clock.fixed(t0), () => focus.setDuration(25));
      expect(habit(), isNotNull);
    });

    test('so does a different sound', () {
      withClock(Clock.fixed(t0), () => focus.setSound(AmbientSoundType.cafe));
      expect(habit(), isNotNull);
    });

    test('a Pomodoro is compared on its work round, not the single-round length', () {
      withClock(Clock.fixed(t0), () {
        focus.setMode(FocusMode.pomodoro);
        focus.setPomodoroConfig(workMinutes: 25);
      });
      expect(habit(), isNotNull);

      withClock(Clock.fixed(t0), () => focus.setPomodoroConfig(workMinutes: 45));
      expect(habit(), isNull);
    });

    test('a count-up session has no length to compare', () {
      withClock(Clock.fixed(t0), () {
        focus.setMode(FocusMode.flow);
        focus.setDuration(10);
      });
      expect(habit(), isNull);
    });
  });

  group('what counts as a round', () {
    test('an abandoned one does not', () async {
      Map<String, dynamic> abandoned(int d) {
        counter++;
        final start = DateTime(2026, 3, 14 - d, 9);
        return FocusSession(
          id: 'habit-$counter',
          startedAt: start,
          completedAt: start.add(const Duration(minutes: 20)),
          targetMinutes: 45,
          actualMinutes: 20,
          wasAbandoned: true,
          activityType: FocusActivityType.study,
          plantType: PlantType.seedling,
        ).toJson();
      }

      await focus.importSessionsJson([round(1), round(2), round(3), abandoned(4), abandoned(5)]);

      expect(habit(), isNull, reason: 'three finished, two given up on');
    });
  });

  group('a routine with no usual sound', () {
    test('a round recorded as "no sound" is no sound, not a sound called none', () async {
      await focus.importSessionsJson([
        for (var d = 1; d <= 5; d++) round(d, sound: AmbientSoundType.none),
      ]);

      expect(habit()!.sound, isNull);
    });

    test('does not mind which sound is set', () async {
      await focus.importSessionsJson([
        for (var d = 1; d <= 5; d++) round(d, sound: null),
      ]);
      withClock(Clock.fixed(t0), () {
        focus.setActivity(FocusActivityType.study);
        focus.setDuration(45);
        focus.setSound(AmbientSoundType.cafe);
      });

      expect(habit(), isNull);
    });
  });

  group('turning it off', () {
    test('is on to begin with', () {
      expect(focus.habitOffers, isTrue);
    });

    test('nothing is offered, and it is remembered', () async {
      await aRoutine();

      await focus.setHabitOffers(false);

      expect(habit(), isNull);
      focus.resetForTesting();
      await focus.init();
      expect(focus.habitOffers, isFalse);
    });

    test('and back on, it is offered', () async {
      await aRoutine();
      await focus.setHabitOffers(false);

      await focus.setHabitOffers(true);

      expect(habit(), isNotNull);
    });

    test('the wipe turns it back on', () async {
      await focus.setHabitOffers(false);

      focus.resetAfterWipe();

      expect(focus.habitOffers, isTrue);
    });
  });

  group('Not now', () {
    test('puts it away for the rest of the day', () async {
      await aRoutine();
      expect(habit(), isNotNull, reason: 'seen first, so it has been remembered');

      await withClock(Clock.fixed(t0), focus.dismissHabitSuggestion);

      expect(habit(), isNull);
      expect(habitAt(DateTime(2026, 3, 14, 10, 15)), isNull, reason: 'still today');
    });

    test('and it is back tomorrow', () async {
      await aRoutine();
      await withClock(Clock.fixed(t0), focus.dismissHabitSuggestion);

      expect(habitAt(DateTime(2026, 3, 15, 9, 30)), isNotNull);
    });

    test('and is remembered across a restart', () async {
      await aRoutine();
      await withClock(Clock.fixed(t0), focus.dismissHabitSuggestion);

      focus.resetForTesting();
      await focus.init();

      expect(habit(), isNull);
    });
  });

  group('what was remembered does not outlive what it depended on', () {
    test('another hour of the day is not answered with this hour\'s', () async {
      await aRoutine();
      expect(habitAt(DateTime(2026, 3, 14, 15, 30)), isNull, reason: 'the premise');

      expect(habitAt(t0), isNotNull);
    });

    test('nor another day, once the rounds have aged out', () async {
      await aRoutine();
      expect(habit(), isNotNull, reason: 'the premise');

      expect(habitAt(DateTime(2026, 5, 24, 9, 30)), isNull, reason: 'seventy days on');
    });

    test('a round that finishes changes the answer', () async {
      await aRoutine(days: 3);
      expect(habit(), isNull, reason: 'the premise: three is not a routine');

      await focus.importSessionsJson([round(4)]);

      expect(habit(), isNotNull);
    });
  });

  group('Use this', () {
    Future<AppliedSuggestion<FocusHabit>?> apply() =>
        withClock(Clock.fixed(t0), focus.applyHabitSuggestion);

    setUp(() async {
      await aRoutine();
    });

    test('sets the activity, the length and the sound, and puts it away', () async {
      final applied = await apply();

      expect(applied, isNotNull);
      // And says which it applied — read again at the tap, not at the moment the card
      // was drawn.
      expect(applied!.suggestion.activity, FocusActivityType.study.index);
      expect(applied.suggestion.minutes, 45);
      expect(applied.suggestion.sound, AmbientSoundType.rain.index);
      expect(focus.selectedActivity, FocusActivityType.study);
      expect(focus.selectedMinutes, 45);
      expect(focus.selectedSound, AmbientSoundType.rain);
      expect(habit(), isNull);
    });

    test('changing the setup again afterwards does not bring it straight back', () async {
      await apply();

      withClock(Clock.fixed(t0), () => focus.setDuration(25));

      expect(habit(), isNull, reason: 'they have seen it and chosen');
    });

    test('Undo puts every one of them back, and the offer returns', () async {
      withClock(Clock.fixed(t0), () {
        focus.setActivity(FocusActivityType.coding);
        focus.setDuration(50);
        focus.setSound(AmbientSoundType.forest);
      });
      final undo = (await apply())!.undo;
      expect(habit(), isNull, reason: 'the premise: put away');

      await withClock(Clock.fixed(t0), undo);

      expect(focus.selectedActivity, FocusActivityType.coding);
      expect(focus.selectedMinutes, 50);
      expect(focus.selectedSound, AmbientSoundType.forest);
      expect(habit(), isNotNull);
    });

    test('is not choosing a sound: it counts nothing toward Sound Explorer', () async {
      expect(focus.usedSoundsForTesting, isEmpty, reason: 'the premise');

      await apply();

      expect(focus.selectedSound, AmbientSoundType.rain);
      expect(focus.usedSoundsForTesting, isEmpty,
          reason: 'accepting an offer is not playing the sound');
    });

    test('and nor is its Undo', () async {
      withClock(Clock.fixed(t0), () => focus.setSound(AmbientSoundType.forest));
      final tried = {...focus.usedSoundsForTesting};
      final undo = (await apply())!.undo;

      await withClock(Clock.fixed(t0), undo);

      expect(focus.selectedSound, AmbientSoundType.forest);
      expect(focus.usedSoundsForTesting, tried);
    });

    test('choosing a sound still does count, as it always did', () {
      withClock(Clock.fixed(t0), () => focus.setSound(AmbientSoundType.cafe));

      expect(focus.usedSoundsForTesting, {AmbientSoundType.cafe});
    });

    test('in a Pomodoro it is the work round that changes', () async {
      withClock(Clock.fixed(t0), () {
        focus.setMode(FocusMode.pomodoro);
        focus.setPomodoroConfig(workMinutes: 25);
        focus.setDuration(15);
      });

      await apply();

      expect(focus.workMinutes, 45);
      expect(focus.selectedMinutes, 15, reason: 'the single-round length is left alone');
    });

    test('in Flow no length is touched', () async {
      withClock(Clock.fixed(t0), () {
        focus.setMode(FocusMode.flow);
        focus.setDuration(15);
        focus.setPomodoroConfig(workMinutes: 25);
      });

      await apply();

      expect(focus.selectedActivity, FocusActivityType.study);
      expect(focus.selectedMinutes, 15);
      expect(focus.workMinutes, 25);
    });

    test('leaves the sound alone when there is no usual one', () async {
      await focus.importSessionsJson([
        for (var d = 6; d <= 12; d++) round(d, sound: null),
      ]);
      // Twelve rounds now, five with rain: under half.
      withClock(Clock.fixed(t0), () => focus.setSound(AmbientSoundType.forest));

      await apply();

      expect(focus.selectedSound, AmbientSoundType.forest);
    });

    test('nothing to apply, nothing changes', () async {
      await focus.setHabitOffers(false);
      final before = (focus.selectedActivity, focus.selectedMinutes, focus.selectedSound);

      expect(await apply(), isNull);

      expect((focus.selectedActivity, focus.selectedMinutes, focus.selectedSound), before);
    });

    test('a suggestion that has gone still tells the screen, so the card that offered it goes',
        () async {
      // The screen does not rebuild an idle Focus page by itself: without this the
      // card stays, and every tap repeats "out of date".
      await focus.setHabitOffers(false);
      var notified = 0;
      void listener() => notified++;
      focus.addListener(listener);
      addTearDown(() => focus.removeListener(listener));

      expect(await apply(), isNull);

      expect(notified, greaterThan(0));
    });

    test('while a round runs it does nothing', () async {
      await withClock(Clock.fixed(t0), focus.startSession);
      final before = focus.selectedActivity;

      expect(await apply(), isNull);

      expect(focus.selectedActivity, before);
      await withClock(Clock.fixed(t0), focus.abandonSession);
    });
  });
}
