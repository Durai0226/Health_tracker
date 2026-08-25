import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/bedtime_guidance.dart';

/// `SleepService.averageActualSchedule` already answers "when do you usually go
/// to bed". That is useless as a *target*, because it averages the good nights
/// together with the 2am ones the user is trying to stop having.
///
/// Oura's Bedtime Guidance takes the other approach: look at the nights that
/// actually scored well and point at what those had in common. This is that,
/// as arithmetic over the user's own logged nights.
void main() {
  BedtimeNight n(int hour, int minute, int score) =>
      BedtimeNight(bedMinutes: hour * 60 + minute, score: score);

  group('it learns from the good nights, not the average', () {
    test('early nights that score well pull the target earlier', () {
      final nights = [
        // Five good nights around 22:30.
        n(22, 30, 88), n(22, 20, 90), n(22, 40, 86), n(22, 30, 89), n(22, 25, 91),
        // Five poor ones around 00:30.
        n(0, 30, 62), n(0, 40, 58), n(0, 20, 64), n(0, 35, 60), n(0, 25, 61),
      ];
      final s = BedtimeGuidance.fromBestNights(nights)!;
      expect(s.isEarlier, isTrue);
      expect(s.bedMinutes, closeTo(22 * 60 + 29, 3));
      // The plain average would sit near 23:30 — between the two clusters, and
      // a night the user has never actually had.
      expect(s.shiftMinutes.abs(), greaterThan(20));
      expect(s.sampleCount, 5);
      expect(s.averageScoreOfBest, greaterThan(85));
    });

    test('bedtimes either side of midnight cluster instead of averaging to noon',
        () {
      // 23:40 and 00:10 are half an hour apart, not twelve hours.
      final nights = [
        n(23, 40, 90), n(0, 10, 88), n(23, 50, 92), n(0, 0, 89), n(23, 45, 91),
        n(3, 0, 55), n(3, 30, 52), n(2, 40, 58), n(3, 10, 54), n(2, 50, 56),
      ];
      final s = BedtimeGuidance.fromBestNights(nights)!;
      // Must land near midnight, not near midday.
      expect(s.bedMinutes > 23 * 60 || s.bedMinutes < 60, isTrue,
          reason: 'got ${s.bedMinutes} minutes-since-midnight');
    });

    test('the shift takes the short way round the clock', () {
      final nights = [
        n(23, 30, 92), n(23, 20, 90), n(23, 40, 91), n(23, 35, 89), n(23, 25, 93),
        n(0, 40, 60), n(0, 50, 58), n(1, 0, 55), n(0, 45, 59), n(0, 55, 57),
      ];
      final s = BedtimeGuidance.fromBestNights(nights)!;
      expect(s.shiftMinutes.abs(), lessThan(120),
          reason: 'a wrap bug shows up as a ~1400 minute "shift"');
      expect(s.isEarlier, isTrue);
    });
  });

  group('it declines rather than inventing advice', () {
    test('too few nights says nothing', () {
      final few = [n(22, 30, 90), n(0, 30, 60), n(22, 40, 88)];
      expect(BedtimeGuidance.fromBestNights(few), isNull,
          reason: 'a suggestion from three nights is a coincidence with a '
              'confident voice');
    });

    test('a trivial shift says nothing', () {
      // "Go to bed seven minutes earlier" is noise dressed as insight.
      final nights = [
        for (var i = 0; i < 10; i++) n(22, 30 + (i % 3), 80 + (i % 2) * 12),
      ];
      expect(BedtimeGuidance.fromBestNights(nights), isNull);
    });

    test('best nights that are not actually better say nothing', () {
      // If every night scores the same, the "best" ones are just whichever
      // happened to sort first.
      final flat = [
        n(22, 0, 80), n(23, 0, 80), n(0, 0, 80), n(1, 0, 80),
        n(22, 30, 80), n(23, 30, 80), n(0, 30, 80), n(1, 30, 80),
      ];
      expect(BedtimeGuidance.fromBestNights(flat), isNull);
    });

    test('an implausibly large shift is refused', () {
      // Six hours earlier is not guidance, it is a data problem.
      final nights = [
        n(18, 0, 95), n(18, 10, 94), n(17, 50, 96), n(18, 5, 93), n(17, 55, 97),
        n(2, 0, 50), n(2, 30, 48), n(3, 0, 45), n(2, 15, 49), n(2, 45, 47),
      ];
      expect(BedtimeGuidance.fromBestNights(nights), isNull);
    });

    test('an empty history does not throw', () {
      expect(BedtimeGuidance.fromBestNights(const []), isNull);
    });
  });
}
