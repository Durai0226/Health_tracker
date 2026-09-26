import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// SS-11 — `availability()` was a platform round trip on every call.
///
/// Ten call sites reach it, several on screen-open paths that wrap it in a
/// six-second timeout (sleep, steps, heart, workouts). The answer changes at
/// most a handful of times in a device's life, so every one of those opens paid
/// for a question already answered.
///
/// A source guard rather than a behavioural test, and the reason is concrete:
/// `HealthDataService` talks to Health Connect / HealthKit through the `health`
/// package, whose platform channels are unregistered in a host VM — the
/// responsive harness allow-lists health screens for the same reason. What CAN
/// be asserted is the caching RULE, and the invalidation that keeps it honest.
void main() {
  final src = File('lib/core/services/health_data_service.dart').readAsStringSync();

  String body(String from, String to) {
    final a = src.indexOf(from);
    expect(a, greaterThan(-1), reason: 'anchor "$from" not found — re-anchor');
    final b = src.indexOf(to, a);
    expect(b, greaterThan(a), reason: 'anchor "$to" not found after "$from"');
    return src.substring(a, b);
  }

  test('the answer is memoised', () {
    final fn = body('Future<HealthAvailability> availability(',
        'Future<HealthAvailability> _readAvailability()');
    expect(fn, contains('_cachedAvailability'));
    expect(fn, contains('if (!forceRefresh && cached != null) return cached'),
        reason: 'without the early return this is a cache nothing reads');
    expect(fn, contains('_cachedAvailability = result'),
        reason: 'and without the store it is a cache nothing fills');
  });

  test('and dropped by everything that can change it', () {
    // These two methods exist to change the answer. If either stops clearing
    // the cache, the in-app "install Health Connect, come back" flow reports
    // the pre-install state forever.
    for (final sig in const [
      'Future<bool> requestPermissions() async {',
      'Future<void> installHealthConnect() async {',
    ]) {
      final i = src.indexOf(sig);
      expect(i, greaterThan(-1), reason: '$sig not found — re-anchor');
      // Bounded to the first 400 chars of the method, which is where an
      // invalidation has to be to be useful (before any early return).
      final head = src.substring(i, i + 400);
      expect(head, contains('invalidateAvailabilityCache()'),
          reason: '$sig must drop the memoised availability, or the answer it '
              'just changed stays stale for the rest of the session');
    }
  });

  test('the scanner is reading the real file', () {
    expect(src.length, greaterThan(15000),
        reason: 'a tiny read means the path moved and the checks above assert '
            'nothing');
    expect(src, contains('enum HealthAvailability'),
        reason: 'sanity: this is the file that defines the type');
  });
}
