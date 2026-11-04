/// The scaffolding the automatic imports from the health store share: the switch,
/// where a read starts, whether a run begins, and one run at a time.
///
/// Blood pressure and sugar, and drinks, each carried their own copy of this and
/// the copies drifted. Here it is proved once, on its own.
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/health/health_import_control.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 9, 30, 12);

  late HealthImportControl control;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    control = HealthImportControl(
      name: 'Test import',
      enabledKey: 'test_enabled',
      lastRunKey: 'test_last_run_ms',
      firstLookback: const Duration(days: 30),
      overlap: const Duration(days: 3),
      minInterval: const Duration(minutes: 15),
    );
  });

  group('the switch', () {
    test('is off until it is turned on', () async {
      expect(await control.isEnabled(), isFalse);
    });

    test('turned on, it stays on', () async {
      await control.setEnabled(true);

      expect(await control.isEnabled(), isTrue);
      expect((await SharedPreferences.getInstance()).getBool('test_enabled'), isTrue);
    });

    test('turned off, it forgets when it last ran, so a fresh start reads the first window',
        () async {
      await control.setEnabled(true);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('test_last_run_ms', now.millisecondsSinceEpoch);

      await control.setEnabled(false);

      expect(await control.isEnabled(), isFalse);
      expect(prefs.containsKey('test_last_run_ms'), isFalse);
    });

    test('turned ON, it leaves when it last ran alone', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('test_last_run_ms', 5);

      await control.setEnabled(true);

      expect(prefs.getInt('test_last_run_ms'), 5);
    });

    test('two imports on different keys do not share a switch', () async {
      final other = HealthImportControl(
        name: 'Other',
        enabledKey: 'other_enabled',
        lastRunKey: 'other_last',
        firstLookback: const Duration(days: 1),
        overlap: const Duration(days: 1),
      );
      await control.setEnabled(true);

      expect(await other.isEnabled(), isFalse);
    });
  });

  group('where a read starts', () {
    test('the first time: the first lookback back', () {
      expect(control.windowStart(lastRunMs: null, now: now),
          now.subtract(const Duration(days: 30)));
    });

    test('after that: the overlap before the last run, not before now', () {
      final last = now.subtract(const Duration(hours: 5));

      expect(control.windowStart(lastRunMs: last.millisecondsSinceEpoch, now: now),
          last.subtract(const Duration(days: 3)));
    });
  });

  group('whether a run begins', () {
    late List<String> calls;

    Future<String?> attempt({
      bool force = false,
      DateTime? at,
      bool allowed = true,
      Object? permissionThrows,
      Object? runThrows,
    }) {
      calls = [];
      return control.runIfEnabled<String>(
        force: force,
        now: at ?? now,
        hasPermission: () async {
          calls.add('permission');
          if (permissionThrows != null) throw permissionThrows;
          return allowed;
        },
        run: (when) async {
          calls.add('run@${when.toIso8601String()}');
          if (runThrows != null) throw runThrows;
          return 'ran';
        },
      );
    }

    Future<void> ranAt(DateTime at) async => (await SharedPreferences.getInstance())
        .setInt('test_last_run_ms', at.millisecondsSinceEpoch);

    test('off: nothing is asked, nothing runs', () async {
      expect(await attempt(), isNull);
      expect(calls, isEmpty);
    });

    test('on and never run: it runs, at the time it was given', () async {
      await control.setEnabled(true);

      expect(await attempt(), 'ran');
      expect(calls, ['permission', 'run@${now.toIso8601String()}']);
    });

    test('too soon after the last run: it does not, and does not even ask', () async {
      await control.setEnabled(true);
      await ranAt(now.subtract(const Duration(minutes: 14)));

      expect(await attempt(), isNull);
      expect(calls, isEmpty);
    });

    test('exactly the interval after: it runs', () async {
      await control.setEnabled(true);
      await ranAt(now.subtract(const Duration(minutes: 15)));

      expect(await attempt(), 'ran');
    });

    test('long after: it runs', () async {
      await control.setEnabled(true);
      await ranAt(now.subtract(const Duration(days: 2)));

      expect(await attempt(), 'ran');
    });

    test('force skips the wait — the switch has just been turned on', () async {
      await control.setEnabled(true);
      await ranAt(now.subtract(const Duration(minutes: 1)));

      expect(await attempt(force: true), 'ran');
    });

    test('but force does not skip the switch', () async {
      expect(await attempt(force: true), isNull);
      expect(calls, isEmpty);
    });

    test('nor the permission', () async {
      await control.setEnabled(true);

      expect(await attempt(force: true, allowed: false), isNull);
      expect(calls, ['permission']);
    });

    test('the health store no longer allows it: it does not run', () async {
      await control.setEnabled(true);

      expect(await attempt(allowed: false), isNull);
      expect(calls, ['permission']);
    });

    test('a run that throws is not thrown on: the app is opening', () async {
      await control.setEnabled(true);

      expect(await attempt(runThrows: StateError('store busy')), isNull);
    });

    test('nor is a permission check that does', () async {
      await control.setEnabled(true);

      expect(await attempt(permissionThrows: StateError('plugin missing')), isNull);
      expect(calls, ['permission']);
    });

    test('with no time given, the clock says what time it is', () async {
      await control.setEnabled(true);
      calls = [];
      final fixed = DateTime(2031, 1, 2, 3, 4);

      await withClock(Clock.fixed(fixed), () => control.runIfEnabled<String>(
            force: false,
            now: null,
            hasPermission: () async => true,
            run: (when) async {
              calls.add('run@${when.toIso8601String()}');
              return 'ran';
            },
          ));

      expect(calls, ['run@${fixed.toIso8601String()}']);
    });
  });

  group('the switch turned off in the middle of a run', () {
    test('a run that has just begun still wants it', () {
      final stillWanted = control.watchSwitch();

      expect(stillWanted(), isTrue);
    });

    test('turning it off ends it: the run that was mid-read finds out', () async {
      final stillWanted = control.watchSwitch();

      await control.setEnabled(false);

      expect(stillWanted(), isFalse);
    });

    test('and it is already so the moment off is asked for, before it is written', () {
      // The run asks as soon as its read returns — which can be before the
      // preference write has finished.
      final stillWanted = control.watchSwitch();

      final turning = control.setEnabled(false);

      expect(stillWanted(), isFalse);
      return turning;
    });

    test('and stays ended when it is turned on again: that run was not asked for', () async {
      final stillWanted = control.watchSwitch();

      await control.setEnabled(false);
      await control.setEnabled(true);

      expect(stillWanted(), isFalse);
    });

    test('a run that begins after it was turned off wants it as much as any', () async {
      await control.setEnabled(false);

      final stillWanted = control.watchSwitch();

      expect(stillWanted(), isTrue);
    });

    test('turning it ON ends nothing', () async {
      final stillWanted = control.watchSwitch();

      await control.setEnabled(true);

      expect(stillWanted(), isTrue);
    });

    test('a run called with the switch never turned on is not ended by that', () {
      // `run` is also called directly — by the first read after the person says
      // yes, and by tests — and "off" there is the absence of a choice.
      final stillWanted = control.watchSwitch();

      expect(stillWanted(), isTrue);
    });

    test('another import\'s switch is not this one\'s', () async {
      final other = HealthImportControl(
        name: 'Other',
        enabledKey: 'o',
        lastRunKey: 'ol',
        firstLookback: const Duration(days: 1),
        overlap: const Duration(days: 1),
      );
      final stillWanted = control.watchSwitch();

      await other.setEnabled(false);

      expect(stillWanted(), isTrue);
    });

    test('a wipe ends every import\'s runs, which never go through the switch', () {
      final other = HealthImportControl(
        name: 'Other',
        enabledKey: 'o',
        lastRunKey: 'ol',
        firstLookback: const Duration(days: 1),
        overlap: const Duration(days: 1),
      );
      final mine = control.watchSwitch();
      final theirs = other.watchSwitch();

      HealthImportControl.cancelAllRuns();

      expect(mine(), isFalse);
      expect(theirs(), isFalse);
    });

    test('a caller who asks for a run of its own is not handed the one that is stopping',
        () async {
      // Off while a read is out, then on again — "on" runs a read of its own. Handed
      // the stopped run's answer, the screen would say "nothing found" to a question
      // nobody asked.
      final gate = Completer<String>();
      final stopping = control.singleFlight(() => gate.future);
      await control.setEnabled(false);
      await control.setEnabled(true);

      var started = 0;
      final fresh = control.singleFlight(() async {
        started++;
        return 'fresh';
      });
      await Future<void>.delayed(Duration.zero);
      expect(started, 0, reason: 'it waits for the one that is stopping to be over');

      gate.complete('stopped');

      expect(await stopping, 'stopped');
      expect(await fresh, 'fresh');
      expect(started, 1);
    });

    test('and several who ask meanwhile share that one fresh run', () async {
      final gate = Completer<String>();
      final stopping = control.singleFlight(() => gate.future);
      await control.setEnabled(false);
      await control.setEnabled(true);

      var started = 0;
      Future<String> ask() => control.singleFlight(() async {
            started++;
            await Future<void>.delayed(const Duration(milliseconds: 1));
            return 'fresh#$started';
          });
      final a = ask();
      final b = ask();
      gate.complete('stopped');

      expect(await stopping, 'stopped');
      expect(await a, 'fresh#1');
      expect(await b, 'fresh#1');
      expect(started, 1);
    });

    test('a stopping run that failed does not fail the caller who waited for it', () async {
      final gate = Completer<String>();
      final stopping = control.singleFlight(() => gate.future);
      await control.setEnabled(false);
      await control.setEnabled(true);

      final fresh = control.singleFlight(() async => 'fresh');
      gate.completeError(StateError('store down'));

      await expectLater(stopping, throwsStateError);
      expect(await fresh, 'fresh');
    });

    test('with nothing stopped, a caller mid-run still gets that run', () async {
      // The ordinary case is unchanged: only a run that has been told to stop is
      // not handed on.
      final gate = Completer<String>();
      final first = control.singleFlight(() => gate.future);
      await control.setEnabled(true);
      final second = control.singleFlight(() async => 'second');
      gate.complete('first');

      expect(await first, 'first');
      expect(await second, 'first');
    });
  });

  group('"Delete all data"', () {
    // Process-wide state: it must never be left on for the next test.
    tearDown(HealthImportControl.wipeEnded);

    test('stops the runs in flight, and is told apart from a switch turned off', () {
      final stillWanted = control.watchSwitch();
      final wiped = control.watchWipe();

      HealthImportControl.wipeBegan();

      expect(stillWanted(), isFalse);
      expect(wiped(), isTrue);
    });

    test('a switch turned off is not a wipe', () async {
      final wiped = control.watchWipe();

      await control.setEnabled(false);

      expect(wiped(), isFalse);
    });

    test('a run that begins after it is not one it wiped', () {
      HealthImportControl.wipeBegan();

      final wiped = control.watchWipe();

      expect(wiped(), isFalse);
    });

    test('it reaches every import', () {
      final other = HealthImportControl(
        name: 'Other',
        enabledKey: 'o',
        lastRunKey: 'ol',
        firstLookback: const Duration(days: 1),
        overlap: const Duration(days: 1),
      );
      final mine = control.watchWipe();
      final theirs = other.watchWipe();

      HealthImportControl.wipeBegan();

      expect(mine(), isTrue);
      expect(theirs(), isTrue);
    });

    test('while it lasts no run begins — and after it, they do', () async {
      await control.setEnabled(true);
      var ran = 0;
      Future<String?> attempt() => control.runIfEnabled<String>(
            force: true,
            now: now,
            hasPermission: () async => true,
            run: (_) async {
              ran++;
              return 'ran';
            },
          );

      HealthImportControl.wipeBegan();
      expect(await attempt(), isNull);
      expect(ran, 0);

      HealthImportControl.wipeEnded();
      expect(await attempt(), 'ran');
      expect(ran, 1);
    });

    test('two that overlap: runs wait for BOTH to end', () async {
      // The settings wipe and an account deletion can be under way together; the first
      // to finish must not let a run begin while the other is still deleting.
      await control.setEnabled(true);
      Future<String?> attempt() => control.runIfEnabled<String>(
            force: true,
            now: now,
            hasPermission: () async => true,
            run: (_) async => 'ran',
          );

      HealthImportControl.wipeBegan();
      HealthImportControl.wipeBegan();
      HealthImportControl.wipeEnded();
      expect(await attempt(), isNull, reason: 'one is still going');

      HealthImportControl.wipeEnded();
      expect(await attempt(), 'ran');
    });

    test('ending it twice, or without a beginning, does no harm', () {
      HealthImportControl.wipeEnded();
      HealthImportControl.wipeEnded();

      expect(control.watchWipe()(), isFalse);
    });
  });

  group('one run at a time', () {
    test('a caller that arrives mid-run gets that run, not a second one', () async {
      var started = 0;
      final gate = Completer<String>();

      final first = control.singleFlight(() {
        started++;
        return gate.future;
      });
      final second = control.singleFlight(() {
        started++;
        return Future.value('second');
      });
      gate.complete('first');

      expect(await first, 'first');
      expect(await second, 'first');
      expect(started, 1);
    });

    test('once it is done, the next call is a run of its own', () async {
      var started = 0;
      Future<int> run() => control.singleFlight(() async => ++started);

      expect(await run(), 1);
      expect(await run(), 2);
    });

    test('a run that fails is over: the next call is not handed the failure', () async {
      Future<String> failing() => control.singleFlight<String>(() async => throw StateError('x'));

      await expectLater(failing(), throwsStateError);
      expect(await control.singleFlight(() async => 'fine'), 'fine');
    });

    test('everyone waiting on a failing run gets the failure', () async {
      final gate = Completer<String>();
      final first = control.singleFlight(() => gate.future);
      final second = control.singleFlight(() async => 'unused');
      gate.completeError(StateError('store down'));

      await expectLater(first, throwsStateError);
      await expectLater(second, throwsStateError);
    });

    test('two imports do not wait for each other', () async {
      final other = HealthImportControl(
        name: 'Other',
        enabledKey: 'o',
        lastRunKey: 'ol',
        firstLookback: const Duration(days: 1),
        overlap: const Duration(days: 1),
      );
      final gate = Completer<String>();
      final mine = control.singleFlight(() => gate.future);

      expect(await other.singleFlight(() async => 'theirs'), 'theirs');
      gate.complete('mine');
      expect(await mine, 'mine');
    });
  });
}
