/// "Rain from 6 pm — 4–6 pm looks dry for a walk." Only for someone behind.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/dry_window.dart';
import 'package:tablet_remainder/core/health/walk_weather_tip.dart';

void main() {
  int at(int h, [int m = 0]) => h * 60 + m;

  group('behind pace', () {
    // An even spread of 8,000 steps over 07:00–21:00 is 571 an hour; the tip
    // wants someone under 80% of that.
    test('clearly short of where an even day would have them', () {
      // 14:00 is half the day: 4,000 expected; 80% of that is 3,200.
      expect(WalkWeatherTips.behindPace(steps: 2500, goal: 8000, nowMinute: at(14)), isTrue);
    });

    test('a little short is not behind', () {
      expect(WalkWeatherTips.behindPace(steps: 3300, goal: 8000, nowMinute: at(14)), isFalse);
    });

    test('exactly 80% of an even pace is not behind', () {
      expect(WalkWeatherTips.behindPace(steps: 3200, goal: 8000, nowMinute: at(14)), isFalse,
          reason: 'under it, not at it');
      expect(WalkWeatherTips.behindPace(steps: 3199, goal: 8000, nowMinute: at(14)), isTrue);
    });

    test('ahead is not behind', () {
      expect(WalkWeatherTips.behindPace(steps: 6000, goal: 8000, nowMinute: at(14)), isFalse);
    });

    test('the goal met is never behind', () {
      expect(WalkWeatherTips.behindPace(steps: 8000, goal: 8000, nowMinute: at(20)), isFalse);
      expect(WalkWeatherTips.behindPace(steps: 9000, goal: 8000, nowMinute: at(20)), isFalse);
    });

    test('no goal, no tip', () {
      expect(WalkWeatherTips.behindPace(steps: 0, goal: 0, nowMinute: at(14)), isFalse);
    });

    test('the day has not started', () {
      expect(WalkWeatherTips.behindPace(steps: 0, goal: 8000, nowMinute: at(6)), isFalse);
      expect(WalkWeatherTips.behindPace(steps: 0, goal: 8000, nowMinute: at(7)), isFalse,
          reason: 'nothing is owed at the first minute');
    });

    test('late in the day, nothing is expected to be left to do', () {
      // After 21:00 the whole goal is "expected": 2,000 of 8,000 is behind.
      expect(WalkWeatherTips.behindPace(steps: 2000, goal: 8000, nowMinute: at(22)), isTrue);
    });
  });

  group('words', () {
    test('hours', () {
      expect(WalkWeatherTips.hourLabel(0), '12 am');
      expect(WalkWeatherTips.hourLabel(9), '9 am');
      expect(WalkWeatherTips.hourLabel(12), '12 pm');
      expect(WalkWeatherTips.hourLabel(18), '6 pm');
      expect(WalkWeatherTips.hourLabel(24), '12 am');
    });

    test('a range inside one half of the day says it once', () {
      expect(WalkWeatherTips.rangeLabel(16, 18), '4–6 pm');
      expect(WalkWeatherTips.rangeLabel(8, 10), '8–10 am');
      expect(WalkWeatherTips.rangeLabel(12, 14), '12–2 pm');
    });

    test('across noon it says both', () {
      expect(WalkWeatherTips.rangeLabel(11, 13), '11 am–1 pm');
    });

    test('rain coming', () {
      const w = DryWindow(fromHour: 16, toHour: 18, rainHour: 18, rainingNow: false);
      expect(WalkWeatherTips.say(w), 'Rain from 6 pm — 4–6 pm looks dry for a walk.');
    });

    test('rain now', () {
      const w = DryWindow(fromHour: 15, toHour: 17, rainHour: 15, rainingNow: true);
      expect(WalkWeatherTips.say(w), 'Rain until 3 pm — 3–5 pm looks dry for a walk.');
    });

    test('a forecast is never a promise', () {
      const w = DryWindow(fromHour: 16, toHour: 18, rainHour: 18, rainingNow: false);
      final line = WalkWeatherTips.say(w);
      expect(line, contains('looks dry'));
      expect(line, isNot(contains('will')));
    });
  });
}
