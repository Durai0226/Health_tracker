/// The last of the confirmed findings — small, visible, each one a number or a
/// word that disagreed with another on the same screen.
///
/// Grouped in one file because they share no code, only a shape: a value
/// derived one way and displayed next to the same value derived another.
library;

import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/utils/calendar_day.dart';
import 'package:tablet_remainder/features/medication/models/dependent_profile.dart';

void main() {
  /// Infant age in CALENDAR months.
  ///
  /// `age` is already calendar-correct — it decrements the year when the
  /// birthday has not passed — but the under-one branch fell back to
  /// `difference().inDays ~/ 30`. Twelve 30-day "months" is 360 days, so a
  /// child five days short of their first birthday was listed as "12 months".
  group('infant age', () {
    DependentProfile child(DateTime dob) => DependentProfile(
          id: 'd1',
          name: 'Baby',
          relationship: RelationshipType.child,
          dateOfBirth: dob,
        );

    String ageAt(DateTime dob, DateTime now) =>
        withClock(Clock.fixed(now), () => child(dob).displayAge);

    test('never reports twelve months for a child under one', () {
      // Born 2025-04-01; on 2026-03-27 they are 11 months and most of a
      // month old — 360 elapsed days, which the old arithmetic called 12.
      expect(ageAt(DateTime(2025, 4, 1), DateTime(2026, 3, 27)), '11 months');
    });

    test('counts the month only once the day comes round', () {
      final dob = DateTime(2025, 4, 15);
      expect(ageAt(dob, DateTime(2025, 5, 14)), '0 months',
          reason: 'one day short of a month');
      expect(ageAt(dob, DateTime(2025, 5, 15)), '1 month',
          reason: 'and singular, not "1 months"');
      expect(ageAt(dob, DateTime(2025, 6, 15)), '2 months');
    });

    test('a newborn is zero months, not negative', () {
      final dob = DateTime(2026, 3, 14);
      expect(ageAt(dob, DateTime(2026, 3, 14)), '0 months');
      expect(ageAt(dob, DateTime(2026, 3, 20)), '0 months');
    });

    test('past the first birthday it switches to years', () {
      expect(ageAt(DateTime(2025, 4, 1), DateTime(2026, 4, 1)), '1 years');
    });
  });

  /// Three date labels that answered a calendar question with elapsed time.
  ///
  /// A civil day containing a spring-forward transition is 23 hours and one
  /// containing a fall-back is 25, so `difference().inDays` truncates and
  /// `add(Duration(days: 1))` lands on the wrong date.
  ///
  /// **These first assertions do not, on their own, catch the bug.** This
  /// suite runs in whatever zone the machine is in, and in a zone without DST
  /// the old arithmetic gives the same answers. They state what the helpers
  /// mean; `dst_date_arithmetic_probe.dart` re-executes the shared helpers
  /// under TZ=America/New_York, and the source guard below is what holds the
  /// three CALL SITES to using them.
  group('calendar-day labelling', () {
    // 2026 US transitions: spring forward Mar 8, fall back Nov 1.
    test('the day after spring-forward is one day, not zero', () {
      // `DateTime(2026,3,9).difference(DateTime(2026,3,8)).inDays` is 0 in a
      // DST zone — the shared helper is not fooled.
      expect(calendarDaysBetween(DateTime(2026, 3, 8), DateTime(2026, 3, 9)), 1,
          reason: 'the vitals Date & time field labelled the 8th "Today" on '
              'the 9th, and Steps history drew two consecutive "Today" rows');
      expect(calendarDaysBetween(DateTime(2026, 3, 7), DateTime(2026, 3, 9)), 2);
    });

    test('the day after a fall-back transition is still one day', () {
      expect(calendarDaysBetween(DateTime(2026, 11, 1), DateTime(2026, 11, 2)), 1);
    });

    test('tomorrow is the next date, even across fall-back', () {
      // `DateTime(2026,11,1).add(Duration(days:1))` is 2026-11-01 23:00 in a
      // DST zone, so the Reminders agenda's "Tomorrow" bucket matched TODAY
      // and tomorrow's reminders were filed under "Upcoming".
      final tomorrow = dayOffset(DateTime(2026, 11, 1), 1);
      expect(tomorrow.day, 2);
      expect(tomorrow.month, 11);
      expect(tomorrow, isNot(DateTime(2026, 11, 1)));
    });

    test('and across spring-forward', () {
      final tomorrow = dayOffset(DateTime(2026, 3, 8), 1);
      expect(tomorrow.day, 9);
    });
  });

  /// The three screens actually use the helpers.
  ///
  /// The assertions above pass in a zone without DST no matter which
  /// arithmetic the screens use, so this is the half that fails when one of
  /// them goes back to `difference().inDays` or `add(Duration(days: n))` for a
  /// calendar question. Comments are stripped first — this repo documents what
  /// it replaced right where it replaced it, and a guard its own prose
  /// satisfies is not a guard (the e2e string registry was found passing for
  /// exactly that reason).
  group('the screens use calendar arithmetic, not elapsed', () {
    const files = <String, String>{
      'vitals Date & time field': 'lib/core/widgets/app/app_date_time_field.dart',
      'Steps history': 'lib/features/steps/screens/steps_history_screen.dart',
      'Reminders agenda': 'lib/features/reminders/screens/reminders_screen.dart',
    };

    files.forEach((what, path) {
      test('$what', () {
        final src = File(path)
            .readAsStringSync()
            .replaceAll(RegExp(r'^\s*//.*$', multiLine: true), '')
            .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');

        expect(src, isNot(contains('.inDays')),
            reason: '$path truncates an elapsed span to answer a question '
                'about dates. Use calendarDaysBetween.');
        expect(src, isNot(matches(RegExp(r'\.add\(\s*(const\s+)?Duration\(days:'))),
            reason: '$path steps a date with an absolute Duration. Use '
                'dayOffset — a civil day is not always 24 hours.');

        // ...and it really does reach for the shared helper.
        expect(
            src.contains('calendarDaysBetween') || src.contains('dayOffset'),
            isTrue,
            reason: '$path no longer references either helper, so the two '
                'assertions above may be passing because the date logic left '
                'rather than because it is correct');
      });
    });
  });

  /// Four numbers or words that contradicted something printed beside them.
  ///
  /// Each is a value derived one way and displayed next to the same value
  /// derived another. Asserted on the source, because all four live inside
  /// build methods behind screens that load their own data — and what changed
  /// in every case was which expression feeds the label.
  group('a value and its label agree', () {
    String code(String path) => File(path)
        .readAsStringSync()
        .replaceAll(RegExp(r'^\s*//.*$', multiLine: true), '')
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');

    test('the Trends Sleep headline is not capped below its own ring', () {
      // The ring centre prints `b.sleep.average!` while the headline read the
      // CLAMPED `goalProgress` — so 8-hour nights against a 7h target showed
      // "8.0 h" over "100% of goal".
      final src = code('lib/features/insights/screens/trends_dashboard_screen.dart');
      expect(src, contains("b.sleep.goalPercent!.round()"),
          reason: 'the Sleep headline must read the uncapped percentage, the '
              'one its own doc calls "for the ring\'s CENTRE label"');
    });

    test('the water history ring prints the real percentage', () {
      // `_buildProgressCard` clamps at both places it FILLS a ring; what it
      // must not do is clamp the number it PRINTS. 5000ml against a 2000ml
      // goal drew "150%" beside "5000ml / of 2000ml goal".
      final src = code('lib/features/water/screens/water_history_edit_screen.dart');
      expect(src, isNot(contains('.clamp(0.0, 1.5)')),
          reason: 'the value handed to _buildProgressCard is the label as '
              'well as the fill, so clamping it makes the ring lie');
    });

    test('the weight delta is the difference of what is shown', () {
      // `_display` rounds each reading to one decimal; the delta was taken at
      // full precision and rounded separately, so 70.44 and 70.36 rendered as
      // "70.4", "70.4" and "+0.1 vs last".
      final src = code('lib/features/medication/screens/vitals/weight_screen.dart');
      expect(src, contains('double.parse(_display(latest.valueKg))'),
          reason: 'the delta has to be computed from the displayed values, or '
              'the card contradicts its own arithmetic');
    });

    test('Focus never calls a Flow session a single one', () {
      // `_setupSummary` branched only on pomodoro, so flow fell into the else
      // and the collapsed row read "Single session" beside a Flow button. The
      // leave dialog separately labelled count-UP time "Time remaining".
      final src = code('lib/features/focus/screens/focus_screen.dart');
      // Specific to the SETUP SUMMARY. `FocusMode.flow =>` also appears in
      // the start-button label at line ~680, so a bare `contains` passed with
      // the summary's own arm deleted — checked, and it did.
      expect(src, contains("FocusMode.flow => 'Flow',"),
          reason: 'the setup summary must name every mode, not fall through '
              'to "Single session"');
      expect(src, contains("FocusMode.single => 'Single session',"),
          reason: 'and the single-session arm has to be the one that says so, '
              'rather than an else catching everything that is not pomodoro');
      expect(src, contains("_focusService.isCountUp ? 'Time focused'"),
          reason: 'formattedTime counts UP in Flow — its own comment says '
              '"time SPENT, not time left. Same formatting, opposite meaning"');
    });
  });
}
