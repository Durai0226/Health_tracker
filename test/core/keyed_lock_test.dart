/// One turn at a time per key.
///
/// A queue write reads the list, adds to it and writes it back across awaits; two
/// of them overlapping each read the list before the other had stored its change,
/// and the later store replaced the earlier.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/services/keyed_lock.dart';

void main() {
  /// A body that logs when it starts and ends, and takes [ms] in between.
  Future<String> job(List<String> log, String name, int ms) async {
    log.add('start $name');
    await Future<void>.delayed(Duration(milliseconds: ms));
    log.add('end $name');
    return name;
  }

  test('calls for one key run one after another, in the order asked', () async {
    final log = <String>[];
    final results = await Future.wait([
      KeyedLock.run('q', () => job(log, 'a', 30)),
      KeyedLock.run('q', () => job(log, 'b', 1)),
      KeyedLock.run('q', () => job(log, 'c', 10)),
    ]);

    expect(results, ['a', 'b', 'c']);
    expect(log, [
      'start a', 'end a',
      'start b', 'end b',
      'start c', 'end c',
    ], reason: 'a later call never starts while an earlier one is still running');
  });

  test('different keys do not wait for each other', () async {
    final log = <String>[];
    final slow = KeyedLock.run('one', () => job(log, 'slow', 40));
    final quick = KeyedLock.run('two', () => job(log, 'quick', 1));
    await Future.wait([slow, quick]);

    expect(log.indexOf('end quick'), lessThan(log.indexOf('end slow')),
        reason: 'a long write to one queue must not hold up another');
  });

  test('a body that throws still hands the turn on, and its caller hears it', () async {
    final log = <String>[];
    final failing = KeyedLock.run<void>('q', () async {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      throw StateError('boom');
    });
    final after = KeyedLock.run('q', () => job(log, 'after', 1));

    await expectLater(failing, throwsA(isA<StateError>()));
    expect(await after, 'after', reason: 'one failed write must not wedge the queue');
  });

  test('returns what the body returns', () async {
    expect(await KeyedLock.run('q', () async => 42), 42);
    expect(await KeyedLock.run('q', () async => 'x'), 'x');
  });

  test('a call made after the others finished runs straight away', () async {
    await KeyedLock.run('q', () async => null);
    final log = <String>[];
    await KeyedLock.run('q', () => job(log, 'late', 1));
    expect(log, ['start late', 'end late']);
  });

  test('forgets a key once nothing is waiting on it', () async {
    final before = KeyedLock.activeKeys;
    await Future.wait([
      KeyedLock.run('tidy-1', () async => 1),
      KeyedLock.run('tidy-1', () async => 2),
      KeyedLock.run('tidy-2', () async => 3),
    ]);
    // The cleanup runs on the next microtask after the last body finishes.
    await Future<void>.delayed(Duration.zero);
    expect(KeyedLock.activeKeys, before,
        reason: 'the map must not grow with every key ever used');
  });
}
