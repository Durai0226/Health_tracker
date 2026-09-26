/// SS-18 — one thousands formatter for the steps feature, not seven.
///
/// Six byte-identical copies of the same StringBuffer loop had accumulated
/// (`_fmt` in the dashboard, the goal settings screen, the history screen, the
/// activity ring and the service; `_formatUnsigned` in the manual-entry
/// sheet), plus a seventh shape — `_short` in the weekly chart — for the same
/// numbers in a narrower space.
///
/// Three layers, because the first two alone would be vacuous: the truth table
/// proves the helper, the source guard proves nobody re-grows a private copy,
/// and the rendered assertion proves the SHIPPED call sites actually route
/// through it. A helper with a perfect unit test that no screen calls formats
/// nothing.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/steps/utils/step_format.dart';
import 'package:tablet_remainder/features/steps/widgets/step_activity_ring.dart';
import 'package:tablet_remainder/features/steps/widgets/step_weekly_chart.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('formatThousands', () {
    test('groups from the right, three at a time', () {
      expect(formatThousands(0), '0');
      expect(formatThousands(7), '7');
      expect(formatThousands(999), '999');
      expect(formatThousands(1000), '1,000');
      expect(formatThousands(4321), '4,321');
      expect(formatThousands(12345), '12,345');
      expect(formatThousands(999999), '999,999');
      expect(formatThousands(1234567), '1,234,567');
    });

    test('keeps the sign outside the grouping', () {
      // A manual entry can be a trim, so negatives reach this.
      expect(formatThousands(-1), '-1');
      expect(formatThousands(-1500), '-1,500');
      expect(formatThousands(-1000000), '-1,000,000');
    });
  });

  group('formatCompactSteps', () {
    test('stays exact below a thousand', () {
      expect(formatCompactSteps(0), '0');
      expect(formatCompactSteps(999), '999');
      // Matches what the weekly chart's `_short` did: short numbers, negatives
      // included, are already short enough.
      expect(formatCompactSteps(-250), '-250');
    });

    test('one decimal below 10k, none above', () {
      expect(formatCompactSteps(1000), '1.0k');
      expect(formatCompactSteps(4321), '4.3k');
      expect(formatCompactSteps(9999), '10.0k');
      expect(formatCompactSteps(10000), '10k');
      expect(formatCompactSteps(12500), '13k');
    });
  });

  test('no steps file has re-grown a private copy of the loop', () {
    // The duplication this finding is about is a source property, so it needs
    // a source assertion. Anything matching the grouping arithmetic outside
    // step_format.dart is a seventh copy in the making.
    final offenders = <String>[];
    for (final e in Directory('lib/features/steps')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      if (e.path.endsWith('utils/step_format.dart')) continue;
      if (e.readAsStringSync().contains('% 3 == 0')) offenders.add(e.path);
    }
    expect(offenders, isEmpty,
        reason: 'thousands grouping is implemented outside step_format.dart '
            'in: $offenders');
  });

  /// The rendered half. Pumped at a generous size so the ring's FittedBox has
  /// no reason to shrink the text out of existence.
  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(500, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: Center(child: child)),
    ));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('the activity ring paints a grouped count, not 12345',
      (tester) async {
    await pump(
      tester,
      const StepActivityRing(progress: 0.5, steps: 12345, goalSteps: 24000),
    );

    expect(find.text('12,345'), findsOneWidget,
        reason: 'the hero number is the most-read figure in the feature');
    expect(find.text('12345'), findsNothing);
    expect(find.text('of 24,000 steps'), findsOneWidget,
        reason: 'the goal beside it must be grouped the same way — a card '
            'showing "12,345 of 24000" reads as a bug');
  });

  testWidgets('the weekly chart badge uses the compact form', (tester) async {
    await pump(
      tester,
      const StepWeeklyChart(
        data: [
          StepDayBar(label: 'M', steps: 6000),
          StepDayBar(label: 'T', steps: 9000, reached: true),
        ],
        goalSteps: 8500,
      ),
    );

    // Compact, not grouped: this badge shares a row with the card title and
    // lost that fight at 1.3x text scale, which is why it is short.
    expect(find.text('Goal 8.5k'), findsOneWidget);
  });
}
