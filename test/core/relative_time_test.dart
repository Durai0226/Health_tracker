import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dart:io';
import 'package:tablet_remainder/core/utils/relative_time.dart';

/// Five hand-rolled copies of this existed before, with two different
/// vocabularies ("3 days ago" vs "3d ago") and none of them testable. Two of the
/// behaviours below were wrong in every one of them.
void main() {
  final now = DateTime(2026, 6, 10, 15, 0);
  String at(Duration ago) => RelativeTime.since(now.subtract(ago), now: now);

  group('the ordinary ladder', () {
    test('under a minute', () {
      expect(at(Duration.zero), 'just now');
      expect(at(const Duration(seconds: 59)), 'just now');
    });

    test('minutes', () {
      expect(at(const Duration(minutes: 1)), '1 min ago');
      expect(at(const Duration(minutes: 59)), '59 min ago');
    });

    test('hours, singular and plural', () {
      expect(at(const Duration(minutes: 60)), '1 hour ago');
      expect(at(const Duration(hours: 4)), '4 hours ago');
      expect(at(const Duration(hours: 23, minutes: 59)), '23 hours ago');
    });

    test('yesterday is named, not counted', () {
      expect(at(const Duration(hours: 24)), 'yesterday');
      expect(at(const Duration(hours: 47)), 'yesterday');
    });

    test('days up to a week', () {
      expect(at(const Duration(days: 2)), '2 days ago');
      expect(at(const Duration(days: 6)), '6 days ago');
    });
  });

  group('the tail is bounded', () {
    test('past a week it becomes a date', () {
      // "Last seen 412 days ago" is not information.
      expect(at(const Duration(days: 7)), isNot(contains('ago')));
      expect(at(const Duration(days: 412)), isNot(contains('ago')));
      // Bare, so it composes after any lead-in the caller writes. A baked-in
      // "on " is a preposition the caller cannot remove, and it reads wrong
      // after the mid-dot the vitals screens use.
      expect(at(const Duration(days: 7)), isNot(startsWith('on ')));
    });

    test('an old date carries its year', () {
      // DateFormats.dayLabel is year-aware; 412 days back crosses a year.
      final old = RelativeTime.since(DateTime(2024, 3, 14), now: now);
      expect(old, contains('2024'));
    });

    test('a date inside this year omits the year', () {
      final recent = RelativeTime.since(DateTime(2026, 3, 14), now: now);
      expect(recent, isNot(contains('2026')));
    });
  });

  group('clock skew', () {
    test('a future timestamp is "just now", not a negative duration', () {
      // A wearable syncing with a skewed clock genuinely produces this. The old
      // implementations rendered it as "0 min ago" by accident.
      expect(RelativeTime.since(now.add(const Duration(hours: 3)), now: now),
          'just now');
      expect(RelativeTime.since(now.add(const Duration(days: 90)), now: now),
          'just now');
    });
  });

  group('composition and null-handling', () {
    test('lastSeen prefixes the bare phrase', () {
      expect(RelativeTime.lastSeen(now.subtract(const Duration(hours: 4)),
              now: now),
          'Last seen 4 hours ago');
    });

    test('sinceOrNull returns null so the caller renders nothing', () {
      // "We have no timestamp" and "the timestamp is old" are different facts
      // and must not share a rendering.
      expect(RelativeTime.sinceOrNull(null, now: now), isNull);
      expect(RelativeTime.sinceOrNull(now, now: now), 'just now');
    });
  });

  group('it reads the injectable clock', () {
    test('omitting now uses clock.now(), not DateTime.now()', () {
      withClock(Clock.fixed(now), () {
        expect(RelativeTime.since(now.subtract(const Duration(hours: 2))),
            '2 hours ago');
      });
    });
  });

  // -------------------------------------------------------------------- guard

  test('no screen hand-rolls a relative time any more', () {
    // Five copies, two vocabularies ("3d ago" vs "3 days ago"), none of them
    // clamping a future timestamp. Source-grep in the repo's established idiom
    // so a sixth cannot appear quietly.
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('relative_time.dart')) continue;
      final src = f
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      if (src.contains('_timeAgo(') || src.contains('String _lastSeen(')) {
        offenders.add(f.path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'use RelativeTime — it bounds the tail and clamps clock skew. '
            'Found: $offenders');
  });
}
