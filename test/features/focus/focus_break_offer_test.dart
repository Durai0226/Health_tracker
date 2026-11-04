/// "Break first?", as the focus service decides it: from the rounds already done,
/// the clock, and whether it has been asked and answered before.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
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
  final t0 = DateTime(2026, 3, 14, 9);

  DateTime at(int minutes) => t0.add(Duration(minutes: minutes));

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

  /// A finished round: [minutes] long, starting [startMin] after [t0].
  Map<String, dynamic> round(int startMin, int minutes, {bool endedAt = true}) {
    counter++;
    return FocusSession(
      id: 'round-$counter',
      startedAt: at(startMin),
      completedAt: endedAt ? at(startMin + minutes) : null,
      targetMinutes: minutes,
      actualMinutes: minutes,
      wasCompleted: endedAt,
      wasAbandoned: !endedAt,
      activityType: FocusActivityType.work,
      plantType: PlantType.seedling,
    ).toJson();
  }

  /// Four 25-minute rounds with five-minute rests: a 100-minute run, the last
  /// ending at minute 115.
  Future<void> aLongRun() =>
      focus.importSessionsJson([round(0, 25), round(30, 25), round(60, 25), round(90, 25)]);

  ({int focusedMinutes, int breakMinutes})? offerAt(int minute) =>
      withClock(Clock.fixed(at(minute)), () => focus.breakOffer);

  group('when it is offered', () {
    test('never, with nothing done', () {
      expect(offerAt(10), isNull);
    });

    test('not for a run under ninety minutes', () async {
      await focus.importSessionsJson([round(0, 25), round(30, 25), round(60, 25)]);
      expect(offerAt(87), isNull, reason: '75 minutes');
    });

    test('for a run of ninety or more: how long, and the break to take', () async {
      await aLongRun();

      final offer = offerAt(117)!;

      expect(offer.focusedMinutes, 100);
      expect(offer.breakMinutes, FocusService.suggestedBreakMinutes(100));
      expect(offer.breakMinutes, 20);
    });

    test('ten minutes after the last round the break has happened, so it is not', () async {
      await aLongRun();

      expect(offerAt(124), isNotNull, reason: 'nine minutes');
      expect(offerAt(125), isNull, reason: 'ten');
    });

    test('a round abandoned with no end time still counts, for the minutes it ran',
        () async {
      await focus.importSessionsJson([
        round(0, 50, endedAt: false),
        round(55, 50, endedAt: false),
      ]);

      expect(offerAt(107)!.focusedMinutes, 100);
    });

    test('not while a round is running', () async {
      await aLongRun();
      await withClock(Clock.fixed(at(117)), focus.startSession);

      expect(withClock(Clock.fixed(at(118)), () => focus.breakOffer), isNull);
      await withClock(Clock.fixed(at(119)), focus.abandonSession);
    });
  });

  group('"Start anyway"', () {
    test('is not asked about again straight away', () async {
      await aLongRun();
      withClock(Clock.fixed(at(117)), focus.declineBreakOffer);

      expect(offerAt(118), isNull);
    });

    test('but is, once the run has grown by an hour', () async {
      await aLongRun();
      withClock(Clock.fixed(at(117)), focus.declineBreakOffer);
      // Two more rounds: 155 minutes in all, 55 more than the 100 it was declined at.
      await focus.importSessionsJson([round(120, 25), round(150, 30)]);
      expect(offerAt(183), isNull, reason: 'not yet an hour more');

      // Ten minutes more makes 165: past the 160.
      await focus.importSessionsJson([round(185, 10)]);
      expect(offerAt(197)!.focusedMinutes, 165);
    });

    test('a different run is asked about afresh', () async {
      await aLongRun();
      withClock(Clock.fixed(at(117)), focus.declineBreakOffer);
      // An hour's break, then another long run.
      await focus.importSessionsJson([
        round(180, 25), round(210, 25), round(240, 25), round(270, 25),
      ]);

      expect(offerAt(297)!.focusedMinutes, 100);
    });
  });

  group('turning it off', () {
    test('is on to begin with', () {
      expect(focus.breakOffers, isTrue);
    });

    test('nothing is offered, and it is remembered', () async {
      await aLongRun();

      await focus.setBreakOffers(false);

      expect(offerAt(117), isNull);
      expect(CleanStorageService.getAppPreference('focusBreakOffers'), false);
      focus.resetForTesting();
      await focus.init();
      expect(focus.breakOffers, isFalse);
    });

    test('and back on, it is offered again — a decline made before does not linger',
        () async {
      await aLongRun();
      withClock(Clock.fixed(at(117)), focus.declineBreakOffer);
      await focus.setBreakOffers(false);

      await focus.setBreakOffers(true);

      expect(offerAt(118), isNotNull);
    });

    test('the wipe turns it back on, with nothing declined', () async {
      await aLongRun();
      await focus.setBreakOffers(false);

      focus.resetAfterWipe();

      expect(focus.breakOffers, isTrue);
    });
  });
}
