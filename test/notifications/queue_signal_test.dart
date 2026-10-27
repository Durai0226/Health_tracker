/// A button tapped on a notification while the app is open takes effect now — and
/// is not lost to a stale copy of the preferences.
///
/// The buttons run in a background isolate with no database, so what they ask for
/// is parked in a queue the main isolate drains. Two things made that unreliable:
/// each isolate keeps its own copy of SharedPreferences, read once, so the drain
/// could be looking at a copy older than the write; and nothing told an open app
/// that anything had arrived, so a Done tapped over the open Reminders list waited
/// for the next time the app was backgrounded and returned to.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:tablet_remainder/core/services/dose_action_queue.dart';
import 'package:tablet_remainder/core/services/intent_queue.dart';
import 'package:tablet_remainder/core/services/queue_signal.dart';
import 'package:tablet_remainder/core/services/reminder_action_queue.dart';
import 'package:tablet_remainder/core/services/water_action_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the signal', () {
    test('with no listener it is a quiet no-op', () {
      QueueSignal.notify();
    });

    test('a listener hears it', () async {
      var heard = 0;
      final stop = QueueSignal.listen(() => heard++);
      QueueSignal.notify();
      QueueSignal.notify();
      await pumpEventQueue();
      expect(heard, 2);
      stop();
    });

    test('and stops hearing once it stops', () async {
      var heard = 0;
      final stop = QueueSignal.listen(() => heard++);
      stop();
      QueueSignal.notify();
      await pumpEventQueue();
      expect(heard, 0);
    });

    test('a newer listener takes over; stopping the older does not unplug it',
        () async {
      var older = 0, newer = 0;
      final stopOlder = QueueSignal.listen(() => older++);
      final stopNewer = QueueSignal.listen(() => newer++);
      stopOlder();
      QueueSignal.notify();
      await pumpEventQueue();
      expect(newer, 1, reason: 'a rebuilt shell must not be silenced by the old one going');
      expect(older, 0);
      stopNewer();
    });
  });

  group('every queue tells the app when something arrives', () {
    Future<int> heardDuring(Future<void> Function() enqueue) async {
      var heard = 0;
      final stop = QueueSignal.listen(() => heard++);
      await enqueue();
      await pumpEventQueue();
      stop();
      return heard;
    }

    test('a reminder answer', () async {
      expect(
          await heardDuring(() => ReminderActionQueue.enqueue(
              reminderId: 'r-1',
              action: ReminderNotificationAction.done,
              at: DateTime(2026, 6, 20, 9))),
          1);
    });

    test('any answer on the shared queue', () async {
      expect(
          await heardDuring(() => const IntentQueue('probe').enqueue({'x': 1},
              at: DateTime(2026, 6, 20, 9))),
          1);
    });

    test('a dose', () async {
      expect(
          await heardDuring(() => DoseActionQueue.enqueue(
              medicineId: 'm', scheduledTime: DateTime(2026, 6, 20, 8), action: 'take')),
          1);
    });

    test('a drink', () async {
      expect(
          await heardDuring(() => WaterActionQueue.enqueue(
              amountMl: 250, at: DateTime(2026, 6, 20, 9))),
          1);
    });
  });

  group('and each reads what the other isolate wrote', () {
    // The isolates share the native store, not Dart memory. Here, the "other
    // isolate" writes to the store BEHIND the instance this one already holds —
    // which its cached copy cannot see until it reloads. (Resetting the mock
    // instead would hand out a brand-new instance and prove nothing.)
    Future<void> otherIsolateWrites(Map<String, Object> values) async {
      final store = SharedPreferencesStorePlatform.instance;
      for (final e in values.entries) {
        final v = e.value;
        await store.setValue(
            v is List ? 'StringList' : 'String', 'flutter.${e.key}', v);
      }
    }

    test('freshPrefs sees it; a plain getInstance does not', () async {
      final held = await SharedPreferences.getInstance();
      expect(held.getString('k'), isNull);
      await otherIsolateWrites({'k': 'v'});

      expect(held.getString('k'), isNull, reason: 'the premise: the held copy is stale');
      final fresh = await QueueSignal.freshPrefs();
      expect(fresh.getString('k'), 'v');
    });

    test('a drain finds a reminder answer the other isolate queued', () async {
      await SharedPreferences.getInstance(); // this isolate has loaded, empty
      await otherIsolateWrites({
        'pending_reminder_actions': [
          '{"reminderId":"r-1","action":"done","at":"2026-06-20T09:00:00.000"}'
        ],
      });
      final pending = await ReminderActionQueue.drain();
      expect(pending, hasLength(1),
          reason: 'a Done tapped while the app sat alive in the background');
      expect(pending.single.reminderId, 'r-1');
    });

    test('a drain finds a dose', () async {
      await SharedPreferences.getInstance();
      await otherIsolateWrites({
        'pending_dose_actions': [
          '{"medicineId":"m","scheduledTime":"2026-06-20T08:00:00.000","action":"take"}'
        ],
      });
      expect(await DoseActionQueue.drain(), hasLength(1));
    });

    test('a drain finds a drink', () async {
      await SharedPreferences.getInstance();
      await otherIsolateWrites({
        'pending_water_actions': ['{"amountMl":250,"at":"2026-06-20T09:00:00.000"}'],
      });
      expect(await WaterActionQueue.drain(), hasLength(1));
    });

    test('an enqueue from a stale copy does not wipe what the other isolate queued',
        () async {
      await SharedPreferences.getInstance(); // empty here
      await otherIsolateWrites({
        'pending_reminder_actions': [
          '{"reminderId":"r-1","action":"done","at":"2026-06-20T09:00:00.000"}'
        ],
      });

      await ReminderActionQueue.enqueue(
          reminderId: 'r-2',
          action: ReminderNotificationAction.later,
          at: DateTime(2026, 6, 20, 9, 5),
          laterAt: DateTime(2026, 6, 20, 18));

      final pending = await ReminderActionQueue.drain();
      expect(pending.map((p) => p.reminderId), ['r-1', 'r-2'],
          reason: 'a read-modify-write from a stale copy would have kept only r-2');
    });
  });

  group('wired in', () {
    test('the app shell listens for it, and stops', () {
      final src = File('lib/features/home/screens/app_shell.dart').readAsStringSync();
      expect(src, contains('QueueSignal.listen(_onQueueArrived)'));
      expect(src, contains('_stopListeningForQueues?.call()'));
      final handler = src.substring(src.indexOf('void _onQueueArrived()'));
      final body = handler.substring(0, handler.indexOf('\n  }'));
      for (final drain in [
        '_drainQueuedDoseActions()',
        '_drainQueuedWaterActions()',
        '_drainQueuedAnswers()',
      ]) {
        expect(body, contains(drain));
      }
    });

    test('the queues reload before they read, and signal after they write', () {
      for (final path in [
        'lib/core/services/intent_queue.dart',
        'lib/core/services/dose_action_queue.dart',
        'lib/core/services/water_action_queue.dart',
      ]) {
        final src = File(path).readAsStringSync();
        expect(src, isNot(contains('SharedPreferences.getInstance()')),
            reason: '$path must go through QueueSignal.freshPrefs()');
        expect(src, contains('QueueSignal.freshPrefs()'), reason: path);
        expect(src, contains('QueueSignal.notify()'), reason: path);
      }
    });
  });
}
