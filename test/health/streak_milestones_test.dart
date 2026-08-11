import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/streak_milestones.dart';

void main() {
  group('highestMilestoneReached', () {
    test('positive: returns the highest crossed threshold', () {
      expect(highestMilestoneReached(7), 7);
      expect(highestMilestoneReached(29), 14);
      expect(highestMilestoneReached(365), 365);
      expect(highestMilestoneReached(1000), 365);
    });

    test('negative: below the first threshold returns null', () {
      expect(highestMilestoneReached(0), isNull);
      expect(highestMilestoneReached(6), isNull);
    });
  });

  group('milestoneLabel', () {
    test('positive: every real threshold has a distinct label', () {
      final labels = streakMilestoneDays.map(milestoneLabel).toSet();
      expect(labels.length, streakMilestoneDays.length);
    });
  });

  group('isNewMilestone', () {
    test('positive: first time reaching 7 days with no prior celebration', () {
      expect(isNewMilestone(7, null), isTrue);
    });

    test('positive: advancing from 7 to 30 is a new milestone', () {
      expect(isNewMilestone(30, 7), isTrue);
    });

    test('negative: still within an already-celebrated tier is not new', () {
      expect(isNewMilestone(10, 7), isFalse);
    });

    test('negative: below the first threshold is never new', () {
      expect(isNewMilestone(3, null), isFalse);
    });
  });
}
