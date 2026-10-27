/// Smart Add understands "30 min before" and "until done".
///
/// A heads-up fires earlier than the thing itself and says what it is early for;
/// "until done" asks for the follow-up tier. Neither phrase may leak into the
/// title, and neither may disturb how the rest of the sentence is read.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/coach_text.dart';
import 'package:tablet_remainder/core/health/health_types.dart';

void main() {
  const coach = CoachText();

  // Saturday 14 March 2026, 10:00.
  final now = DateTime(2026, 3, 14, 10, 0);

  ParsedReminder parse(String text) =>
      withClock(Clock.fixed(now), () => coach.parseReminder(text));

  group('a heads-up', () {
    test('"30 min before" fires half an hour earlier and keeps the event', () {
      final p = parse('Dentist tomorrow 3pm 30 min before');
      expect(p.eventTime, DateTime(2026, 3, 15, 15, 0));
      expect(p.time, DateTime(2026, 3, 15, 14, 30));
      expect(p.leadMinutes, 30);
      expect(p.title, 'Dentist');
    });

    test('"an hour before"', () {
      final p = parse('remind me an hour before the train tomorrow at 9am');
      expect(p.leadMinutes, 60);
      expect(p.time, DateTime(2026, 3, 15, 8, 0));
      expect(p.eventTime, DateTime(2026, 3, 15, 9, 0));
      expect(p.title, 'The train');
    });

    test('"half an hour before"', () {
      expect(parse('call mum tomorrow 6pm half an hour before').leadMinutes, 30);
      expect(parse('call mum tomorrow 6pm half hour before').leadMinutes, 30);
    });

    test('hours and minutes in digits, and the other ways of saying before', () {
      expect(parse('flight tomorrow 9am 2 hours before').leadMinutes, 120);
      expect(parse('flight tomorrow 9am 45 mins ahead').leadMinutes, 45);
      expect(parse('flight tomorrow 9am 1 hr early').leadMinutes, 60);
    });

    test('the phrase does not leak into the title', () {
      final p = parse('Pick up the parcel tomorrow at 4pm 20 minutes before');
      expect(p.title, 'Pick up the parcel');
    });

    test('a lead of more than a day is not a heads-up', () {
      final p = parse('exam tomorrow 9am 48 hours before');
      expect(p.leadMinutes, isNull);
      expect(p.eventTime, isNull);
    });

    test('a heads-up that would already have gone is sent a minute from now',
        () {
      // 10:00 now; the event is at 10:20 today, with a 30 minute lead.
      final p = parse('standup today at 10:20am 30 min before');
      expect(p.eventTime, DateTime(2026, 3, 14, 10, 20));
      expect(p.time, DateTime(2026, 3, 14, 10, 1),
          reason: 'not in the past, where it would silently never fire');
    });

    test('a repeating reminder shifts its anchor and keeps its repeat', () {
      final p = parse('take the bins out every day at 7pm 15 min before');
      expect(p.repeat, 'daily');
      expect(p.leadMinutes, 15);
      expect(p.time!.hour, 18);
      expect(p.time!.minute, 45);
      expect(p.eventTime!.hour, 19);
    });

    test('a repeat is never pulled forward to "now": its anchor is its own', () {
      // 10:00 now; a daily 10:20 with a 30 minute lead has an anchor of 09:50
      // today. Moving it to 10:01 would move every future occurrence with it.
      final p = parse('take the pill every day at 10:20am 30 min before');
      expect(p.time!.hour, 9);
      expect(p.time!.minute, 50);
    });

    test('without a heads-up nothing about the time changes', () {
      final p = parse('Dentist tomorrow 3pm');
      expect(p.time, DateTime(2026, 3, 15, 15, 0));
      expect(p.leadMinutes, isNull);
      expect(p.eventTime, isNull);
    });

    test('"in 30 minutes" is still a time, not a heads-up', () {
      final p = parse('check the oven in 30 minutes');
      expect(p.leadMinutes, isNull);
      expect(p.time, DateTime(2026, 3, 14, 10, 30));
    });
  });

  group('until done', () {
    test('is read from the common ways of saying it', () {
      for (final phrase in [
        'pay rent tomorrow 9am until done',
        "pay rent tomorrow 9am until it's done",
        'pay rent tomorrow 9am until I do it',
        'pay rent tomorrow 9am until finished',
        'pay rent tomorrow 9am keep reminding me',
        'pay rent tomorrow 9am nag me',
        "pay rent tomorrow 9am don't let me forget",
      ]) {
        expect(parse(phrase).untilDone, isTrue, reason: phrase);
      }
    });

    test('the phrase does not leak into the title', () {
      expect(parse('pay rent tomorrow 9am until done').title, 'Pay rent');
      expect(parse('pay rent tomorrow 9am keep reminding me').title, 'Pay rent');
      expect(parse("don't let me forget the passport tomorrow 8am").title,
          'The passport');
    });

    test('an ordinary sentence is not until-done', () {
      expect(parse('pay rent tomorrow 9am').untilDone, isFalse);
      expect(parse('finish the report tomorrow 9am').untilDone, isFalse,
          reason: '"finish" alone is the task, not a request to nag');
    });

    test('an until DATE is still an end date, and not until-done', () {
      final p = parse('take antibiotics every day at 8am until 20 March');
      expect(p.untilDone, isFalse);
      expect(p.endsAt, isNotNull);
    });

    test('and the two can be said together', () {
      final p = parse('take insulin every day at 8am until done');
      expect(p.untilDone, isTrue);
      expect(p.repeat, 'daily');
    });
  });

  test('a heads-up and until done together', () {
    final p = parse('send the form tomorrow 5pm 1 hour before until done');
    expect(p.leadMinutes, 60);
    expect(p.untilDone, isTrue);
    expect(p.time, DateTime(2026, 3, 15, 16, 0));
    expect(p.title, 'Send the form');
  });
}
