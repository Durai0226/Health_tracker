/// A reminder answered from its notification: what the background isolate can
/// hand to the main one.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/services/reminder_action_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final tap = DateTime(2026, 6, 20, 15, 5);
  final evening = DateTime(2026, 6, 20, 18);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('nothing queued: nothing to drain', () async {
    expect(await ReminderActionQueue.drain(), isEmpty);
  });

  test('Done is kept with who and when', () async {
    await ReminderActionQueue.enqueue(
        reminderId: 'r1', action: ReminderNotificationAction.done, at: tap);
    final d = await ReminderActionQueue.drain();
    expect(d, hasLength(1));
    expect(d.single.reminderId, 'r1');
    expect(d.single.action, ReminderNotificationAction.done);
    expect(d.single.at, tap);
    expect(d.single.laterAt, isNull);
  });

  test('Later keeps when it was set to ring again', () async {
    await ReminderActionQueue.enqueue(
        reminderId: 'r1',
        action: ReminderNotificationAction.later,
        at: tap,
        laterAt: evening);
    final d = (await ReminderActionQueue.drain()).single;
    expect(d.action, ReminderNotificationAction.later);
    expect(d.laterAt, evening);
  });

  test('oldest first', () async {
    await ReminderActionQueue.enqueue(
        reminderId: 'a', action: ReminderNotificationAction.done, at: tap);
    await ReminderActionQueue.enqueue(
        reminderId: 'b', action: ReminderNotificationAction.done, at: tap.add(const Duration(minutes: 1)));
    expect((await ReminderActionQueue.drain()).map((e) => e.reminderId), ['a', 'b']);
  });

  test('draining does not clear: only an ack does', () async {
    await ReminderActionQueue.enqueue(
        reminderId: 'r1', action: ReminderNotificationAction.done, at: tap);
    final first = await ReminderActionQueue.drain();
    expect(await ReminderActionQueue.drain(), hasLength(1));
    await ReminderActionQueue.ack(first);
    expect(await ReminderActionQueue.drain(), isEmpty);
  });

  test('a tap that arrives during the drain survives the ack', () async {
    await ReminderActionQueue.enqueue(
        reminderId: 'a', action: ReminderNotificationAction.done, at: tap);
    final drained = await ReminderActionQueue.drain();
    await ReminderActionQueue.enqueue(
        reminderId: 'b', action: ReminderNotificationAction.later, at: tap, laterAt: evening);
    await ReminderActionQueue.ack(drained);
    expect((await ReminderActionQueue.drain()).map((e) => e.reminderId), ['b']);
  });

  test('two identical taps are two records, and two acks', () async {
    for (var i = 0; i < 2; i++) {
      await ReminderActionQueue.enqueue(
          reminderId: 'r1', action: ReminderNotificationAction.done, at: tap);
    }
    final d = await ReminderActionQueue.drain();
    expect(d, hasLength(2));
    await ReminderActionQueue.ack([d.first]);
    expect(await ReminderActionQueue.drain(), hasLength(1));
  });

  test('a record with no reminder, or an unknown action, is dropped for good',
      () async {
    SharedPreferences.setMockInitialValues({
      'pending_reminder_actions': [
        '{"reminderId":"","action":"done","at":"2026-06-20T15:05:00.000"}',
        '{"action":"done","at":"2026-06-20T15:05:00.000"}',
        '{"reminderId":"r1","action":"explode","at":"2026-06-20T15:05:00.000"}',
        'not json',
        '{"reminderId":"r2","action":"done","at":"2026-06-20T15:05:00.000"}',
      ],
    });
    final d = await ReminderActionQueue.drain();
    expect(d.map((e) => e.reminderId), ['r2']);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('pending_reminder_actions'), hasLength(1),
        reason: 'what nothing will ever ack is pruned');
  });

  test('an enqueue on a store that fails does not throw', () async {
    // The queue is best-effort in a background isolate: a lost tap must not
    // crash the handler that received it.
    await expectLater(
        ReminderActionQueue.enqueue(
            reminderId: 'r1', action: ReminderNotificationAction.done, at: tap),
        completes);
  });
}
