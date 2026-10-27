/// Taps that arrive together are all kept.
///
/// Every queue is written by reading the stored list, adding to it and storing it
/// back, with an await between each step (the preferences are reloaded first, so
/// another isolate's writes are seen). Two writes overlapping both read the same
/// list, and the second store replaced the first: two buttons tapped within a few
/// milliseconds of each other kept one answer.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:tablet_remainder/core/services/dose_action_queue.dart';
import 'package:tablet_remainder/core/services/intent_queue.dart';
import 'package:tablet_remainder/core/services/water_action_queue.dart';

/// A store whose next write waits until the test lets it through — the slow
/// write a real platform can have, which is what makes an overlapping write able
/// to land first.
class _SlowStore extends InMemorySharedPreferencesStore {
  _SlowStore.withData(super.data) : super.withData();

  Completer<void>? hold;

  Future<void> _wait() async {
    final gate = hold;
    if (gate == null) return;
    hold = null; // only the first write waits
    await gate.future;
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    await _wait();
    return super.setValue(valueType, key, value);
  }

  @override
  Future<bool> remove(String key) async {
    await _wait();
    return super.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Start [slowOp] against a store whose first write is held, start [other]
  /// beside it, then let the held write through. What each does to the stored
  /// list is the question; the order they finish in is not.
  Future<void> overlap(
    Map<String, Object> stored,
    Future<void> Function() slowOp,
    Future<void> Function() other,
  ) async {
    final store = _SlowStore.withData(stored);
    SharedPreferencesStorePlatform.instance = store;
    SharedPreferences.resetStatic();
    final gate = Completer<void>();
    store.hold = gate;

    final first = slowOp();
    final second = other();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    gate.complete();
    await Future.wait([first, second]);
  }

  final at = DateTime(2026, 6, 20, 9);

  group('the intent queue', () {
    const queue = IntentQueue('concurrency_queue');

    Future<void> tap(int n) => queue.enqueue({'n': n}, at: at);

    test('twenty taps in the same instant are twenty records, in order', () async {
      await Future.wait([for (var i = 0; i < 20; i++) tap(i)]);

      final pending = await queue.drain();
      expect(pending.map((p) => p.data['n']), [for (var i = 0; i < 20; i++) i]);
    });

    test('a tap that lands while an earlier one is being acked survives', () async {
      await tap(0);
      await tap(1);
      final pending = await queue.drain();
      expect(pending, hasLength(2));

      await Future.wait([
        queue.ack(pending),
        tap(2),
      ]);

      final left = await queue.drain();
      expect(left.map((p) => p.data['n']), [2],
          reason: 'the two applied are forgotten, and the new one is not');
    });

    test('a drain that prunes a bad record does not take a new tap with it', () async {
      SharedPreferences.setMockInitialValues({
        'concurrency_queue': ['not json', '{"n":0,"at":"${at.toIso8601String()}"}'],
      });

      final results = await Future.wait([queue.drain(), tap(1).then((_) => null)]);
      expect((results.first! as List).length, 1);

      final left = await queue.drain();
      expect(left.map((p) => p.data['n']), [0, 1]);
    });

    test('an ack that finds nothing to remove leaves the others alone', () async {
      await tap(0);
      final pending = await queue.drain();
      await queue.ack(pending);
      await Future.wait([queue.ack(pending), tap(1)]);
      expect((await queue.drain()).map((p) => p.data['n']), [1]);
    });
  });

  group('the dose queue', () {
    test('taps from two reminders at once are both kept', () async {
      await Future.wait([
        for (var i = 0; i < 10; i++)
          DoseActionQueue.enqueue(
              medicineId: 'm$i',
              scheduledTime: at.add(Duration(minutes: i)),
              action: DoseActionQueue.actionTake),
      ]);

      final pending = await DoseActionQueue.drain();
      expect(pending.map((p) => p.medicineId), [for (var i = 0; i < 10; i++) 'm$i']);
    });

    test('and a drain beside a tap loses neither', () async {
      await DoseActionQueue.enqueue(
          medicineId: 'first', scheduledTime: at, action: DoseActionQueue.actionTake);

      final results = await Future.wait([
        DoseActionQueue.drain(),
        DoseActionQueue.enqueue(
                medicineId: 'second',
                scheduledTime: at,
                action: DoseActionQueue.actionSkip)
            .then((_) => <PendingDoseAction>[]),
      ]);

      final drainedFirst = results.first.map((p) => p.medicineId).toList();
      final drainedAfter =
          (await DoseActionQueue.drain()).map((p) => p.medicineId).toList();
      expect([...drainedFirst, ...drainedAfter], ['first', 'second'],
          reason: 'each tap is handed over exactly once, whichever drain gets it');
    });
  });

  group('the water queue', () {
    test('drinks logged together are all kept', () async {
      await Future.wait([
        for (var i = 1; i <= 10; i++)
          WaterActionQueue.enqueue(amountMl: 100 * i, at: at),
      ]);

      final pending = await WaterActionQueue.drain();
      expect(pending.map((p) => p.amountMl), [for (var i = 1; i <= 10; i++) 100 * i]);
    });

    test('a drink that arrives while the last is being acked is not lost', () async {
      await WaterActionQueue.enqueue(amountMl: 250, at: at);
      final pending = await WaterActionQueue.drain();

      await Future.wait([
        WaterActionQueue.ack(pending),
        WaterActionQueue.enqueue(amountMl: 330, at: at),
      ]);

      expect((await WaterActionQueue.drain()).map((p) => p.amountMl), [330]);
    });
  });

  group('when the store is slow to write', () {
    const queue = IntentQueue('concurrency_queue');
    String record(int n) => '{"n":$n,"at":"${at.toIso8601String()}"}';

    test('a tap made while a drain is still storing is not overwritten by it', () async {
      await overlap(
        {'flutter.concurrency_queue': ['not json', record(0)]},
        () async => await queue.drain(),
        () => queue.enqueue({'n': 1}, at: at),
      );

      expect((await queue.drain()).map((p) => p.data['n']), [0, 1],
          reason: 'the drain pruned a bad record while a tap came in: both stay');
    });

    test('nor by an ack', () async {
      final pending = <PendingIntent>[
        PendingIntent(data: {'n': 0}, at: at, raw: record(0)),
      ];
      await overlap(
        {'flutter.concurrency_queue': [record(0)]},
        () => queue.ack(pending),
        () => queue.enqueue({'n': 1}, at: at),
      );

      expect((await queue.drain()).map((p) => p.data['n']), [1]);
    });

    test('the dose queue\'s drain does not wipe a tap that arrives while it clears',
        () async {
      final first = '{"medicineId":"first","scheduledTime":"${at.toIso8601String()}","action":"take"}';
      late List<PendingDoseAction> drained;
      await overlap(
        {'flutter.pending_dose_actions': [first]},
        () async => drained = await DoseActionQueue.drain(),
        () => DoseActionQueue.enqueue(
            medicineId: 'second', scheduledTime: at, action: DoseActionQueue.actionTake),
      );

      final later = await DoseActionQueue.drain();
      expect([...drained, ...later].map((p) => p.medicineId), ['first', 'second'],
          reason: 'each is handed over once; the second must not vanish');
    });

    test('the water queue\'s drain pruning a bad record does not overwrite a new drink',
        () async {
      final good = '{"amountMl":250,"at":"${at.toIso8601String()}"}';
      late List<PendingWaterAction> drained;
      await overlap(
        {'flutter.pending_water_actions': ['not json', good]},
        () async => drained = await WaterActionQueue.drain(),
        () => WaterActionQueue.enqueue(amountMl: 330, at: at),
      );

      final later = await WaterActionQueue.drain();
      expect({...drained.map((p) => p.amountMl), ...later.map((p) => p.amountMl)},
          {250, 330});
      expect(later.map((p) => p.amountMl), contains(330),
          reason: 'the drink that arrived during the prune is still queued');
    });

    test('the water queue\'s ack does not wipe a drink that arrives with it', () async {
      final raw = '{"amountMl":250,"at":"${at.toIso8601String()}"}';
      await overlap(
        {'flutter.pending_water_actions': [raw]},
        () => WaterActionQueue.ack(
            [PendingWaterAction(amountMl: 250, at: at, raw: raw)]),
        () => WaterActionQueue.enqueue(amountMl: 330, at: at),
      );

      expect((await WaterActionQueue.drain()).map((p) => p.amountMl), [330]);
    });
  });
}
