/// The Adherence screen's tiles have to account for the total above them.
///
/// The headline reads "N of M scheduled doses taken", and M is
/// `taken + skipped + missed` plus anything still inside the reconciliation
/// grace window. The tiles showed Taken and Missed only — `_AdherenceSummary`
/// had parsed `skipped` all along and nothing rendered it.
///
/// On the device that meant "17 of 36 scheduled doses taken" above tiles
/// reading 17 and 16: three doses the user had deliberately skipped,
/// unaccounted for on the one screen whose job is explaining that percentage.
/// The doctor-facing PDF has always listed them.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  /// The screen's source with comments stripped — this file explains the fix
  /// at length, and a guard its own prose satisfies is not a guard.
  late String src;

  setUpAll(() {
    src = File(
            'lib/features/medication/screens/analytics/nunito_adherence_report_screen.dart')
        .readAsStringSync()
        .replaceAll(RegExp(r'^\s*//.*$', multiLine: true), '')
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  });

  test('the summary still carries a skipped count', () {
    expect(src, contains('final int skipped'),
        reason: 'premise: if the field went away this test is measuring '
            'nothing');
  });

  test('skipped is rendered, not just parsed', () {
    expect(src, contains("label: 'Skipped'"),
        reason: 'the headline counts skipped doses in its denominator, so the '
            'tiles beneath it cannot leave them out — the numbers stop adding '
            'up and there is nothing on screen to explain the gap');
    expect(src, contains(r"value: '${_summary.skipped}'"),
        reason: 'and it has to show the real count, not a placeholder');
  });

  test('the tile is conditional, so a clean record stays three tiles', () {
    expect(src, contains('if (_summary.skipped > 0)'),
        reason: 'a permanent "0 Skipped" is noise for the ordinary user; the '
            'tile exists to close a gap that only appears when there is one');
  });

  test('the other two tiles are still there', () {
    for (final label in const ['Day streak', 'Taken', 'Missed']) {
      expect(src, contains("label: '$label'"),
          reason: 'adding Skipped must not have displaced $label');
    }
  });
}
