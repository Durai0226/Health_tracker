/// INS-14 — the best-focus-hour insight formats an hour to a string and then
/// parses it back, and the two halves have to stay agreed.
///
/// The finding was "hardcoded AM/PM — use `DateFormats.meridiem`". That is
/// REFUTED, and this file is the evidence:
///
///  * `InsightEngine.focus` writes `metric: FocusInsights.hourLabel(hour)` and
///    `InsightActions.hourFromMetric` recovers the hour with
///    `upper.contains('PM')`. Producer and parser are one coupled pair, and
///    only one of them was ever going to be localized.
///  * The app configures no locales at all, so `DateFormat('a')` resolves to
///    `en_US` and emits the same two tokens the hand-rolled code does. Swapping
///    it in changes nothing today and breaks the parser the first day it does.
///
/// The existing coverage (`test/reminders/insight_action_wiring_test.dart`)
/// asserts the parser against HAND-TYPED strings — `hourFromMetric('2 PM')` —
/// so it never runs the producer and cannot see the two drift apart. That is
/// the gap this closes: the round trip below goes through the real
/// `hourLabel`, for every hour of the day.
///
/// The third test is the one that makes the refusal safe rather than
/// permanent. The moment this app gains a locale, the hand-rolled meridiem
/// becomes a live bug — and the fix is NOT `DateFormats.meridiem`, it is
/// carrying the hour on `Insight` as an int and deleting the string round trip
/// (`lib/core/health/insight.dart`, `insight_engine.dart`). This fails then,
/// and says so.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/focus_insights.dart';
import 'package:tablet_remainder/features/insights/services/insight_actions.dart';

void main() {
  group('INS-14 the hour survives the round trip', () {
    test('every hour of the day comes back as itself', () {
      final broken = <String>[];
      for (var h = 0; h < 24; h++) {
        final label = FocusInsights.hourLabel(h);
        final back = InsightActions.hourFromMetric(label);
        if (back != h) broken.add('$h -> "$label" -> $back');
      }
      expect(broken, isEmpty,
          reason: 'the engine formats the hour and the action parses it back; '
              'these did not survive:\n${broken.join('\n')}');
    });

    test('the label carries the exact tokens the parser matches', () {
      // Named explicitly because the coupling is invisible from either side.
      // `hourFromMetric` upper-cases and then looks for the bare substrings
      // 'AM' and 'PM'; a localized 'a.m.' or '午後' matches neither, and the
      // action silently schedules the reminder twelve hours early.
      expect(FocusInsights.hourLabel(9), '9 AM');
      expect(FocusInsights.hourLabel(14), '2 PM');
      expect(FocusInsights.hourLabel(0), '12 AM');
      expect(FocusInsights.hourLabel(12), '12 PM');
    });

    test('and the app still has no locale that could change them', () {
      // The premise the refusal rests on. `DateFormat('a')` is only equivalent
      // to the hand-rolled meridiem while the app is en_US-only: no
      // `flutter_localizations`, no `supportedLocales`, no
      // `localizationsDelegates`, no `initializeDateFormatting`, no
      // `Intl.defaultLocale`.
      //
      // When one of these arrives, delete this test and fix the round trip
      // properly — carry the hour as an int on `Insight` instead of
      // re-deriving it from display text.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec.contains('flutter_localizations'), isFalse,
          reason: 'the app gained localization support — see above');

      final offenders = <String>[];
      final markers = [
        'supportedLocales',
        'localizationsDelegates',
        'initializeDateFormatting',
        'Intl.defaultLocale',
      ];
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final src = f.readAsStringSync();
        for (final marker in markers) {
          // Comment LINES only — a doc comment that merely names the marker
          // (this file's own rationale gets quoted around) must not trip it.
          final live = src
              .split('\n')
              .where((l) => !l.trimLeft().startsWith('//'))
              .join('\n');
          if (live.contains(marker)) offenders.add('${f.path}: $marker');
        }
      }
      expect(offenders, isEmpty,
          reason: 'the app now configures a locale, so every hand-rolled '
              'AM/PM is a real defect and the hourLabel round trip has to '
              'go:\n${offenders.join('\n')}');
    });
  });
}
