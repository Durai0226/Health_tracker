import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// INS-04 — the daily briefing was cached for the LIFE of the screen.
///
/// `_briefingFuture ??= …` with no validity key: the sentence bakes in
/// `clock.now().hour`, so "Good morning" survived into the evening for anyone
/// who left Home open, and the only thing that cleared it was pull-to-refresh.
/// Returning to the Home tab bumped `refreshTick`, but `didUpdateWidget` only
/// called `setState` — the `??=` then re-served the same stale sentence.
///
/// Not a widget test: HomeDashboard mounts Firebase-backed services and a
/// dozen listenables, and the defect is in the caching rule rather than in the
/// rendering. The rule is asserted here against the source; the bounds below
/// are anchored to declarations, not to line offsets, so the window cannot
/// drift.
void main() {
  final src =
      File('lib/features/home/screens/home_dashboard.dart').readAsStringSync();

  String between(String from, String to) {
    final a = src.indexOf(from);
    expect(a, greaterThan(-1), reason: 'anchor "$from" not found — re-anchor');
    final b = src.indexOf(to, a);
    expect(b, greaterThan(a), reason: 'anchor "$to" not found after "$from"');
    return src.substring(a, b);
  }

  test('the cache is keyed, not merely lifetimed', () {
    final fn = between('Future<String?> _briefingSentence()', 'CoachText()');

    expect(fn.contains('??='), isFalse,
        reason: 'a bare ??= is the defect: it can never notice that the hour '
            'or the data moved');
    expect(fn, contains('_briefingRevision'));
    expect(fn, contains('_briefingHour'));
    expect(fn, contains('clock.now().hour'),
        reason: 'the hour is what goes stale, so it has to be part of the key');
    expect(fn, contains('MedicineCleanStorageService.revision.value'),
        reason: 'a dose taken must invalidate the sentence that counts doses');
  });

  test('returning to Home clears it, because water and focus do not bump the '
      'medicine revision', () {
    final fn = between('void didUpdateWidget(', 'Future<void> _refreshAll()');
    expect(fn, contains('refreshTick != widget.refreshTick'));
    expect(fn, contains('_briefingFuture = null'),
        reason: 'the briefing counts water, focus minutes and reminders — none '
            'of which bump the medicine revision — so the tab return is the '
            'only signal those may have changed');
  });

  test('the scanner is reading the real file', () {
    expect(src.length, greaterThan(20000),
        reason: 'home_dashboard.dart is a large file; a tiny read means the '
            'path moved and this guard is asserting nothing');
    expect(src, contains('_briefingFuture'));
  });
}
