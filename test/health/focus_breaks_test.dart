/// How long someone has focused without a break, and when that is worth asking
/// about.
///
/// A break is a gap of ten minutes between one round ending and the next one
/// beginning — a Pomodoro's five-minute rests are not that — and the question is
/// only asked once the run since the last one reaches ninety minutes.
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/focus_breaks.dart';

void main() {
  final t0 = DateTime(2026, 3, 14, 9);

  /// A round starting [startMin] minutes after [t0] and [length] minutes long.
  FocusSpan span(int startMin, int length, {int? minutes}) => FocusSpan(
        start: t0.add(Duration(minutes: startMin)),
        end: t0.add(Duration(minutes: startMin + length)),
        minutes: minutes ?? length,
      );

  DateTime at(int minutes) => t0.add(Duration(minutes: minutes));

  group('the run so far', () {
    test('nothing focused, nothing to count', () {
      final s = FocusBreaks.stretch(const [], now: at(30));
      expect(s.minutes, 0);
      expect(s.since, isNull);
    });

    test('one round that has just ended is the run', () {
      final s = FocusBreaks.stretch([span(0, 25)], now: at(27));
      expect(s.minutes, 25);
      expect(s.since, at(0));
    });

    test('ten minutes since the last round ended: that was the break', () {
      expect(FocusBreaks.stretch([span(0, 25)], now: at(35)).minutes, 0);
      expect(FocusBreaks.stretch([span(0, 25)], now: at(34)).minutes, 25,
          reason: 'nine minutes is not');
    });

    test('rounds with Pomodoro-sized rests between them are one run', () {
      final s = FocusBreaks.stretch(
        [span(0, 25), span(30, 25), span(60, 25)],
        now: at(87),
      );
      expect(s.minutes, 75);
      expect(s.since, at(0));
    });

    test('a gap of ten minutes between two rounds ends the run; nine does not', () {
      // Round one 0–25, round two 35–60: a gap of exactly ten.
      final broken = FocusBreaks.stretch([span(0, 25), span(35, 25)], now: at(62));
      expect(broken.minutes, 25, reason: 'only the newer round');
      expect(broken.since, at(35));

      // Round two 34–59: a gap of nine.
      final joined = FocusBreaks.stretch([span(0, 25), span(34, 25)], now: at(61));
      expect(joined.minutes, 50);
      expect(joined.since, at(0));
    });

    test('a break further back does not hide the run after it', () {
      final s = FocusBreaks.stretch(
        [span(0, 25), span(60, 30), span(95, 30)],
        now: at(127),
      );
      expect(s.minutes, 60, reason: 'the two after the 35-minute gap');
      expect(s.since, at(60));
    });

    test('the order the rounds are given in does not matter', () {
      final rounds = [
        span(0, 25), span(30, 25), span(60, 25), span(90, 25), span(120, 25),
      ];
      final expected = FocusBreaks.stretch(rounds, now: at(147));
      expect(expected.minutes, 125);
      for (var seed = 0; seed < 5; seed++) {
        final shuffled = [...rounds]..shuffle(Random(seed));
        final s = FocusBreaks.stretch(shuffled, now: at(147));
        expect(s.minutes, expected.minutes);
        expect(s.since, expected.since);
      }
    });

    test('rounds that overlap — a clock that moved — are one run, not a gap', () {
      final s = FocusBreaks.stretch([span(0, 25), span(20, 25)], now: at(47));
      expect(s.minutes, 50);
      expect(s.since, at(0));
    });

    test('minutes focused, not the time between start and end: a pause is not focus',
        () {
      // An hour on the clock, twenty-five minutes of it focus.
      final s = FocusBreaks.stretch([span(0, 60, minutes: 25)], now: at(62));
      expect(s.minutes, 25);
    });

    test('a round with no focus in it is ignored — and does not bridge a break', () {
      // 0–25, then 43–68: eighteen minutes apart. A zero-minute round at 34–34
      // would sit nine minutes from each, and must not join them.
      final s = FocusBreaks.stretch(
        [span(0, 25), span(34, 0, minutes: 0), span(43, 25)],
        now: at(70),
      );
      expect(s.minutes, 25);
      expect(s.since, at(43));
    });

    test('a round that has not started yet is ignored', () {
      final s = FocusBreaks.stretch([span(0, 25), span(60, 25)], now: at(30));
      expect(s.minutes, 25);
      expect(s.since, at(0), reason: 'the round that has happened, not the one booked');
    });

    test('only the last twelve hours are looked at', () {
      // Thirty rounds of 25 minutes with five-minute rests, the newest ending a
      // minute ago: 900 minutes of run, of which only the rounds that ended
      // inside the last 720 minutes are counted — 24 of them.
      final now = at(2000);
      final rounds = [
        for (var i = 0; i < 30; i++)
          FocusSpan(
            start: now.subtract(Duration(minutes: 1 + 30 * i + 25)),
            end: now.subtract(Duration(minutes: 1 + 30 * i)),
            minutes: 25,
          ),
      ];
      expect(FocusBreaks.stretch(rounds, now: now).minutes, 24 * 25);
    });
  });

  group('when to ask', () {
    FocusStretch run(int minutes, {DateTime? since}) =>
        FocusStretch(minutes, since ?? at(0));

    test('at ninety minutes, not before', () {
      expect(FocusBreaks.shouldOffer(run(89)), isFalse);
      expect(FocusBreaks.shouldOffer(run(90)), isTrue);
      expect(FocusBreaks.shouldOffer(run(300)), isTrue);
    });

    test('no run, no question', () {
      expect(FocusBreaks.shouldOffer(FocusStretch.none), isFalse);
    });

    test('after "start anyway", the same run is not asked about again straight away',
        () {
      final declined = run(95);
      expect(FocusBreaks.shouldOffer(run(100), declined: declined), isFalse);
      expect(FocusBreaks.shouldOffer(run(154), declined: declined), isFalse);
    });

    test('but is, once it has grown by an hour', () {
      final declined = run(95);
      expect(FocusBreaks.shouldOffer(run(155), declined: declined), isTrue);
      expect(FocusBreaks.shouldOffer(run(200), declined: declined), isTrue);
    });

    test('a different run — there was a real break between — is asked about afresh',
        () {
      final declined = run(95, since: at(0));
      expect(FocusBreaks.shouldOffer(run(95, since: at(600)), declined: declined),
          isTrue);
    });

    test('the run below the bar is not asked about, declined or not', () {
      expect(FocusBreaks.shouldOffer(run(60), declined: run(95)), isFalse);
    });
  });

  group('what it says', () {
    test('lengths read as a person would say them', () {
      expect(FocusBreaks.duration(45), '45 min');
      expect(FocusBreaks.duration(59), '59 min');
      expect(FocusBreaks.duration(60), '1 h');
      expect(FocusBreaks.duration(90), '1 h 30 min');
      expect(FocusBreaks.duration(120), '2 h');
      expect(FocusBreaks.duration(125), '2 h 5 min');
    });

    test('the question states what was counted, and offers rather than insists', () {
      final m = FocusBreaks.offerMessage(100);
      expect(m, contains('1 h 40 min'));
      expect(m, contains('without a break of 10 minutes or more'));
      expect(m, isNot(contains('must')));
      expect(m, isNot(contains('need to')));
    });
  });
}
