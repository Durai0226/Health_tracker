import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/services/background_alarm_service.dart'
    show ReminderKind;
import 'package:tablet_remainder/core/services/reminder_budget.dart';

/// Nothing enforced a pending-notification ceiling before this.
///
/// iOS keeps only the soonest-firing **64** pending requests and silently
/// discards the rest — no error, no log. The medication fallback path arms up to
/// 24 requests per medicine, so three medicines already overflow, and what gets
/// dropped is whatever is furthest out. Samsung's AlarmManager throws past
/// roughly 500 alarms per app, and window nudges alone are `3 × 24 × N`.
///
/// `getPendingNotificationCount()` existed the whole time and was only ever read
/// into a debug log.
void main() {
  group('the ceiling is the real platform limit', () {
    test('iOS is the hard 64-request system cap', () {
      expect(ReminderBudget.ceilingFor(isIOS: true), 64);
    });

    test('Android is the Samsung AlarmManager ceiling', () {
      expect(ReminderBudget.ceilingFor(isIOS: false), 500);
    });

    test('a reserve is held back so a later writer still fits', () {
      // Reminders are armed by several services at different moments (app start,
      // a settings save, a medicine edit). Filling the ceiling exactly means
      // whichever runs last loses.
      expect(ReminderBudget.usable(64), lessThan(64));
      expect(ReminderBudget.usable(64), 64 - ReminderBudget.reserve);
    });

    test('a ceiling smaller than the reserve yields zero, not a negative', () {
      expect(ReminderBudget.usable(3), 0);
    });
  });

  group('who yields when demand exceeds the ceiling', () {
    test('a dose is never pruned, even past the usable ceiling', () {
      // Demand deliberately ABOVE usable(64) — a demand that fits anyway proves
      // nothing about priority, it only proves there was room.
      final over = ReminderBudget.usable(64) + 20;
      final granted = ReminderBudget.allocate(
        ceiling: 64,
        demand: {ReminderKind.dose: over, ReminderKind.gentle: 100},
      );
      expect(granted[ReminderKind.dose], over,
          reason: 'doses are granted in full and the overflow reported, never '
              'silently trimmed to fit');
      expect(granted[ReminderKind.gentle], 0);
    });

    test('nudges yield first, and completely', () {
      final granted = ReminderBudget.allocate(
        ceiling: 64,
        demand: {
          ReminderKind.dose: 40,
          ReminderKind.alarm: 16,
          ReminderKind.gentle: 100,
        },
      );
      // usable(64) == 56; dose takes 40, alarm takes the remaining 16, nudges 0.
      expect(granted[ReminderKind.alarm], 16);
      expect(granted[ReminderKind.gentle], 0);
    });

    test('user-set alarms yield only after every nudge already has', () {
      final granted = ReminderBudget.allocate(
        ceiling: 64,
        demand: {
          ReminderKind.dose: 50,
          ReminderKind.alarm: 20,
          ReminderKind.gentle: 20,
        },
      );
      expect(granted[ReminderKind.dose], 50);
      expect(granted[ReminderKind.alarm], 6, reason: 'usable(64) - 50');
      expect(granted[ReminderKind.gentle], 0);
    });

    test('everything fits when demand is under the ceiling', () {
      final granted = ReminderBudget.allocate(
        ceiling: 500,
        demand: {
          ReminderKind.dose: 20,
          ReminderKind.alarm: 10,
          ReminderKind.gentle: 30,
        },
      );
      expect(granted, {
        ReminderKind.dose: 20,
        ReminderKind.alarm: 10,
        ReminderKind.gentle: 30,
      });
    });

    test('doses alone over the ceiling are still armed, and reported', () {
      // Refusing to arm a dose is never the better option. The honest failure is
      // to arm it and say the platform may drop some.
      const demand = {ReminderKind.dose: 200};
      expect(ReminderBudget.allocate(ceiling: 64, demand: demand)[
              ReminderKind.dose],
          200);
      expect(ReminderBudget.overCommitted(ceiling: 64, demand: demand), isTrue);
      expect(
        ReminderBudget.overCommitted(
            ceiling: 64, demand: {ReminderKind.dose: 10}),
        isFalse,
      );
    });

    test('an absent kind is zero, not an error', () {
      final granted = ReminderBudget.allocate(ceiling: 64, demand: const {});
      expect(granted.values.every((v) => v == 0), isTrue);
    });
  });

  group('headroom is what the fan-outs truncate against', () {
    test('shrinks as other families take slots', () {
      expect(
        ReminderBudget.headroomFor(ReminderKind.gentle,
            pending: 0, ceiling: 64),
        ReminderBudget.usable(64),
      );
      expect(
        ReminderBudget.headroomFor(ReminderKind.gentle,
            pending: 50, ceiling: 64),
        ReminderBudget.usable(64) - 50,
      );
    });

    test('never goes negative', () {
      // 100 water reminders against a 64-request cap is the real case: without
      // this the loop would run with a negative bound or overflow the cap.
      expect(
        ReminderBudget.headroomFor(ReminderKind.gentle,
            pending: 500, ceiling: 64),
        0,
      );
    });

    test('a full budget arms nothing rather than evicting a dose', () {
      // On iOS the OS keeps the SOONEST 64, so an over-subscribed queue does not
      // drop the newcomer — it drops whatever is furthest out, which is usually
      // a dose. Yielding here is what protects them.
      expect(
        ReminderBudget.headroomFor(ReminderKind.gentle,
            pending: ReminderBudget.usable(64), ceiling: 64),
        0,
      );
    });
  });
}
