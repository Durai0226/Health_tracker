/// A reload that cannot pile up.
///
/// The blood-pressure and blood-sugar screens reload on every change to the store.
/// An import saves its readings one at a time, so a few hundred changes started a
/// few hundred overlapping reloads, each reading the whole table and rebuilding the
/// list. The rule here is the whole fix: one load at a time, and anything asked
/// for meanwhile is ONE more load afterwards.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/utils/coalesced_load.dart';

void main() {
  /// A load the test finishes by hand, so what is "in flight" is under its control.
  late List<Completer<void>> gates;
  late int started;
  late int running;
  late int mostAtOnce;

  Future<void> slowLoad() async {
    started++;
    running++;
    if (running > mostAtOnce) mostAtOnce = running;
    final gate = Completer<void>();
    gates.add(gate);
    await gate.future;
    running--;
  }

  setUp(() {
    gates = [];
    started = 0;
    running = 0;
    mostAtOnce = 0;
  });

  Future<void> finishOne() async {
    gates.removeAt(0).complete();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  test('one ask is one load', () async {
    final load = CoalescedLoad(slowLoad);

    final done = load();
    expect(started, 1, reason: 'it starts at once, not on a timer');
    await finishOne();
    await done;

    expect(started, 1);
  });

  test('a burst while one is running is ONE more, however long the burst', () async {
    final load = CoalescedLoad(slowLoad);
    final done = load();

    for (var i = 0; i < 300; i++) {
      unawaited(load());
    }
    expect(started, 1, reason: 'none of the 300 started a load of its own');

    await finishOne();
    expect(started, 2, reason: 'one more, which reads everything that changed');
    await finishOne();
    await done;

    expect(started, 2);
    expect(mostAtOnce, 1);
  });

  test('a change during that second load earns a third, and no more', () async {
    final load = CoalescedLoad(slowLoad);
    final done = load();
    unawaited(load());
    await finishOne();
    expect(started, 2);

    unawaited(load());
    unawaited(load());
    await finishOne();
    expect(started, 3);
    await finishOne();
    await done;

    expect(started, 3);
    expect(mostAtOnce, 1);
  });

  test('a call that arrives mid-load completes only after a load that began after it', () async {
    final load = CoalescedLoad(slowLoad);
    final first = load();
    var secondDone = false;
    final second = load().then((_) => secondDone = true);

    await finishOne();
    expect(secondDone, isFalse, reason: 'the load that was running began BEFORE the call');
    expect(started, 2);
    await finishOne();
    await second;
    await first;

    expect(secondDone, isTrue);
  });

  test('when it is quiet again, the next ask starts a load straight away', () async {
    final load = CoalescedLoad(slowLoad);
    final done = load();
    await finishOne();
    await done;

    final again = load();
    expect(started, 2);
    await finishOne();
    await again;
  });

  test('a waiting load is not run for something that has gone', () async {
    var alive = true;
    final load = CoalescedLoad(slowLoad, canContinue: () => alive);
    final done = load();
    unawaited(load());

    alive = false;
    await finishOne();
    await done;

    expect(started, 1);
  });

  group('settled', () {
    test('is at once when nothing is running', () async {
      final load = CoalescedLoad(slowLoad);

      await load.settled;

      expect(started, 0);
    });

    test('waits for the load under way, and the one behind it, without adding one', () async {
      final load = CoalescedLoad(slowLoad);
      final first = load();
      unawaited(load());
      var settled = false;
      final waiting = load.settled.then((_) => settled = true);

      await finishOne();
      expect(settled, isFalse, reason: 'the load behind it has not finished');
      await finishOne();
      await waiting;
      await first;

      expect(settled, isTrue);
      expect(started, 2, reason: 'asking whether it is settled is not a reason to load');
    });
  });

  test('a load that throws lets the next ask start afresh', () async {
    var calls = 0;
    final load = CoalescedLoad(() async {
      calls++;
      if (calls == 1) throw StateError('database is locked');
    });

    await expectLater(load(), throwsStateError);
    await load();

    expect(calls, 2);
  });

  group('a load that throws', () {
    test('does not drop the one that was asked for meanwhile', () async {
      // The burst this class exists for: changes arrive while a load runs, and the
      // load fails. What arrived is still owed.
      var calls = 0;
      final firstGate = Completer<void>();
      final load = CoalescedLoad(() async {
        calls++;
        if (calls == 1) {
          await firstGate.future;
          throw StateError('database busy');
        }
      });

      final done = load();
      unawaited(load());
      firstGate.complete();

      await done; // the second pass succeeded, so there is nothing to hear
      expect(calls, 2, reason: 'the pass behind it ran');
    });

    test('is heard of when it was the last pass', () async {
      final load = CoalescedLoad(() async => throw StateError('database busy'));

      await expectLater(load(), throwsStateError);
    });

    test('and the next ask starts fresh, not behind a pass that is over', () async {
      var calls = 0;
      final load = CoalescedLoad(() async {
        calls++;
        if (calls == 1) throw StateError('once');
      });

      await expectLater(load(), throwsStateError);
      await load();

      expect(calls, 2);
    });

    test('a failed pass behind a good one is heard of: it is the last', () async {
      var calls = 0;
      final gate = Completer<void>();
      final load = CoalescedLoad(() async {
        calls++;
        if (calls == 1) await gate.future;
        if (calls == 2) throw StateError('the second failed');
      });

      final done = load();
      unawaited(load());
      gate.complete();

      await expectLater(done, throwsStateError);
      expect(calls, 2);
    });
  });

  group('a load that throws before it awaits anything', () {
    // A plain callback, not an async one: it throws synchronously, and used to leave
    // an already-finished future standing in for "a load is running" for good.
    test('is an error for its caller, and the next ask runs a load', () async {
      var calls = 0;
      final load = CoalescedLoad(() {
        calls++;
        if (calls == 1) throw StateError('threw at once');
        return Future<void>.value();
      });

      await expectLater(load(), throwsStateError);
      await load();

      expect(calls, 2, reason: 'not frozen behind the one that failed');
    });

    test('and one asked for while it ran is not stranded either', () async {
      var calls = 0;
      late CoalescedLoad load;
      load = CoalescedLoad(() {
        calls++;
        if (calls == 1) {
          unawaited(load());
          throw StateError('threw at once');
        }
        return Future<void>.value();
      });

      await load();

      expect(calls, 2);
    });
  });
}
