/// Re-arming every reminder is one pass at a time.
///
/// A pass cancels and re-schedules every reminder in every family. It runs at start,
/// on an exact-alarm grant, after a restore and now when the person changes how alerts
/// look, so two can easily overlap — a switch flipped while the start-up pass is
/// still going, or two switches a few seconds apart — and interleave their cancels
/// and schedules. A call that arrives mid-pass asks for ONE more behind it.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/services/reminder_reschedule_service.dart';

void main() {
  late List<Completer<void>> gates;
  late int started;
  late int mostAtOnce;
  late int running;

  setUp(() {
    gates = [];
    started = 0;
    mostAtOnce = 0;
    running = 0;
    ReminderRescheduleService.passForTesting = () async {
      started++;
      running++;
      if (running > mostAtOnce) mostAtOnce = running;
      final gate = Completer<void>();
      gates.add(gate);
      await gate.future;
      running--;
    };
  });

  tearDown(() => ReminderRescheduleService.passForTesting = null);

  Future<void> finishOne() async {
    gates.removeAt(0).complete();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  test('one call is one pass', () async {
    final done = ReminderRescheduleService.rescheduleAllReminders();
    expect(started, 1);
    await finishOne();
    await done;

    expect(started, 1);
  });

  test('calls during a pass are ONE more pass, never two running at once', () async {
    final first = ReminderRescheduleService.rescheduleAllReminders();
    for (var i = 0; i < 5; i++) {
      unawaited(ReminderRescheduleService.rescheduleAllReminders());
    }
    expect(started, 1, reason: 'none of them started a pass of its own');

    await finishOne();
    expect(started, 2);
    await finishOne();
    await first;

    expect(started, 2);
    expect(mostAtOnce, 1);
  });

  test('a caller that arrives mid-pass hears back only when a pass that began after it is done',
      () async {
    final first = ReminderRescheduleService.rescheduleAllReminders();
    var secondDone = false;
    final second =
        ReminderRescheduleService.rescheduleAllReminders().then((_) => secondDone = true);

    await finishOne();
    expect(secondDone, isFalse,
        reason: 'the pass that was running began before this call — its change may not be in it');
    await finishOne();
    await second;
    await first;

    expect(secondDone, isTrue);
  });

  test('once it is quiet, the next call is a pass at once', () async {
    final first = ReminderRescheduleService.rescheduleAllReminders();
    await finishOne();
    await first;

    final again = ReminderRescheduleService.rescheduleAllReminders();
    expect(started, 2);
    await finishOne();
    await again;
  });

  test('a pass that throws does not leave the next call waiting on it', () async {
    var calls = 0;
    ReminderRescheduleService.passForTesting = () async {
      calls++;
      if (calls == 1) throw StateError('the database is locked');
    };

    await expectLater(ReminderRescheduleService.rescheduleAllReminders(), throwsStateError);
    await ReminderRescheduleService.rescheduleAllReminders();

    expect(calls, 2);
  });

  group('what a pass does', () {
    // `passForTesting` stands in for the whole pass; these stand in for its parts.
    late int reconciled;
    late int armed;
    late List<Completer<void>> held;

    setUp(() {
      ReminderRescheduleService.passForTesting = null;
      reconciled = 0;
      armed = 0;
      held = [];
      ReminderRescheduleService.reconcileForTesting = () async => reconciled++;
      ReminderRescheduleService.familiesForTesting = [
        ReminderFamily('one', () async {
          armed++;
          if (held.isNotEmpty) await held.removeAt(0).future;
          return 1;
        }),
      ];
    });

    tearDown(() {
      ReminderRescheduleService.reconcileForTesting = null;
      ReminderRescheduleService.familiesForTesting = null;
    });

    test('rescheduleAllReminders closes out past-due doses, then arms everything', () async {
      await ReminderRescheduleService.rescheduleAllReminders();

      expect(reconciled, 1);
      expect(armed, 1);
    });

    test('rearmReminders only arms: a switch is not a reason to mark doses missed', () async {
      await ReminderRescheduleService.rearmReminders();

      expect(armed, 1);
      expect(reconciled, 0, reason: 'it would move the adherence numbers under the switch');
    });

    test('and one pass reconciles once for however many asked for it', () async {
      final gate = Completer<void>();
      held.add(gate);
      final first = ReminderRescheduleService.rearmReminders();
      await Future<void>.delayed(Duration.zero);
      unawaited(ReminderRescheduleService.rescheduleAllReminders());
      unawaited(ReminderRescheduleService.rescheduleAllReminders());
      gate.complete();
      await first;
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(reconciled, 1, reason: 'the pass behind the first: someone waiting asked for it');
      expect(armed, 2, reason: 'the first, and ONE more behind it');
    });

    test('a re-arm that arrives behind a full pass is a pass of its own, without it', () async {
      final gate = Completer<void>();
      held.add(gate);
      final full = ReminderRescheduleService.rescheduleAllReminders();
      await Future<void>.delayed(Duration.zero);
      expect(reconciled, 1);
      unawaited(ReminderRescheduleService.rearmReminders());
      gate.complete();
      await full;
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(armed, 2);
      expect(reconciled, 1, reason: 'the one behind it was only asked to re-arm');
    });

    test('a reconciliation that fails does not stop anything being armed', () async {
      ReminderRescheduleService.reconcileForTesting = () async => throw StateError('db busy');

      await ReminderRescheduleService.rescheduleAllReminders();

      expect(armed, 1);
    });
  });
}
