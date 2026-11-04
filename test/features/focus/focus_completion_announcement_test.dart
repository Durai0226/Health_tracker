/// A finished round is announced — by a screen that is there, or by a notification.
///
/// `FocusService` decides by whether anyone listens to `justCompleted`: someone, and
/// the screen celebrates; no one, and a notification says it. So a listener that is
/// not a celebration must not be on `justCompleted` — the Trends tab, which stays
/// mounted once it has been shown, was, and a round that finished with the Focus
/// screen closed was announced to nobody. Trends listens to `sessionsRevision`.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_session_alarm.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';

import '../../support/fake_audio_engine.dart';
import '../../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late RecordingNotificationScheduler scheduler;
  final focus = FocusService();
  final at = DateTime(2026, 3, 14, 9, 30);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.loadAppPreferences();
    AudioService().engineForTesting = FakeAudioEngine();
    scheduler = RecordingNotificationScheduler();
    NotificationService().schedulerForTesting = scheduler;
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

  Future<void> waitUntil(bool Function() condition) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!condition() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(condition(), isTrue, reason: 'never became true');
  }

  /// Finish one real one-minute round, watched on screen: the last three foreground
  /// seconds hand the announcement to the app (the armed system notification is
  /// withdrawn), and then the round ends.
  Future<void> finishARound() async {
    await withClock(Clock.fixed(at), () async {
      focus.setDuration(1);
      await focus.startSession();
    });
    await withClock(Clock.fixed(at.add(const Duration(minutes: 1))), () async {
      focus.applyTick(2);
      focus.applyTick(0);
    });
    await waitUntil(() => !focus.isRunning);
  }

  bool announcedByNotification() =>
      scheduler.shown.any((n) => (n.title ?? '').contains('Focus Session Complete'));

  /// The announcement follows the round being over, a little later: wait for it.
  Future<void> waitForAnnouncement() => waitUntil(announcedByNotification);

  /// And for "nothing was announced", give it the time it would have taken.
  Future<void> letItSettle() => Future<void>.delayed(const Duration(milliseconds: 300));

  test('with nobody listening, a notification says it', () async {
    await finishARound();
    await waitForAnnouncement();

    expect(focus.justCompleted.value, isNull);
  });

  test('with a screen listening to justCompleted, the screen is given it instead', () async {
    void listener() {}
    focus.justCompleted.addListener(listener);
    addTearDown(() => focus.justCompleted.removeListener(listener));

    await finishARound();
    await letItSettle();

    expect(focus.justCompleted.value, isNotNull);
    expect(announcedByNotification(), isFalse, reason: 'a banner over the screen that has it');
  });

  test('a listener on the history of rounds is not a screen: a notification still says it',
      () async {
    // What the Trends tab is, mounted and watching for a change to chart.
    var changes = 0;
    void trends() => changes++;
    focus.sessionsRevision.addListener(trends);
    addTearDown(() => focus.sessionsRevision.removeListener(trends));

    await finishARound();
    await waitForAnnouncement();

    expect(focus.justCompleted.hasConsumer, isFalse);
    expect(changes, greaterThan(0), reason: 'and it was told there is a new round to chart');
  });

  test('re-reading the rounds from the database tells it too', () async {
    final before = focus.sessionsRevision.value;

    await focus.reloadSessionsFromDb();

    expect(focus.sessionsRevision.value, greaterThan(before));
  });
}
