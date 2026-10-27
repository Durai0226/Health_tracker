/// A reminder Smart Add made repeat — "every 3 days" — says so in the form, and
/// can be moved further apart without being thrown away.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/design/app_colors_ext.dart';
import 'package:tablet_remainder/features/reminders/widgets/reminder_rule_editor.dart';

import '../support/font_free_theme.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    String rule, {
    required ValueChanged<String> onChanged,
    VoidCallback? onUseStandard,
  }) async {
    final ext = AppColorsExt.light;
    await tester.pumpWidget(MaterialApp(
      theme: fontFreeTheme(),
      home: Scaffold(
        body: ReminderRuleEditor(
          rule: rule,
          accent: ext.reminders,
          onChanged: onChanged,
          onUseStandard: onUseStandard ?? () {},
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('says what the repeat is, in words', (tester) async {
    await pump(tester, 'RRULE:FREQ=DAILY;INTERVAL=3', onChanged: (_) {});
    expect(find.text('Every 3 days'), findsOneWidget);
    expect(find.text('Does not repeat'), findsNothing,
        reason: 'the form used to say this beside a reminder that repeats');
  });

  testWidgets('"every other" is said the way people say it', (tester) async {
    await pump(tester, 'RRULE:FREQ=WEEKLY;INTERVAL=2', onChanged: (_) {});
    expect(find.text('Every other week'), findsOneWidget);
  });

  testWidgets('Less often moves it one further apart, keeping the rest',
      (tester) async {
    String? got;
    await pump(tester, 'RRULE:FREQ=DAILY;INTERVAL=3;COUNT=8',
        onChanged: (r) => got = r);
    await tester.tap(find.byTooltip('Less often'));
    expect(got, contains('INTERVAL=4'));
    expect(got, contains('COUNT=8'));
  });

  testWidgets('More often moves it one closer', (tester) async {
    String? got;
    await pump(tester, 'RRULE:FREQ=DAILY;INTERVAL=3', onChanged: (r) => got = r);
    await tester.tap(find.byTooltip('More often'));
    expect(got, contains('INTERVAL=2'));
  });

  testWidgets('it cannot be made closer than every one', (tester) async {
    await pump(tester, 'RRULE:FREQ=DAILY', onChanged: (_) {});
    final minus = tester.widget<IconButton>(
        find.ancestor(of: find.byTooltip('More often'), matching: find.byType(IconButton)).first);
    expect(minus.onPressed, isNull);
    expect(find.text('Every day'), findsOneWidget);
  });

  testWidgets('or further than a year of days', (tester) async {
    await pump(tester, 'RRULE:FREQ=DAILY;INTERVAL=365', onChanged: (_) {});
    final plus = tester.widget<IconButton>(
        find.ancestor(of: find.byTooltip('Less often'), matching: find.byType(IconButton)).first);
    expect(plus.onPressed, isNull);
  });

  testWidgets('a rule with a weekday says so, and keeps it', (tester) async {
    String? got;
    await pump(tester, 'RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=TU',
        onChanged: (r) => got = r);
    expect(find.text('Every other week'), findsOneWidget);
    // The weekday is spelled out beneath, from the rule itself.
    expect(find.textContaining('Tuesday'), findsOneWidget);

    await tester.tap(find.byTooltip('Less often'));
    expect(got, contains('BYDAY=TU'));
    expect(got, contains('INTERVAL=3'));
  });

  testWidgets('a plain rule has no second line repeating the first',
      (tester) async {
    await pump(tester, 'RRULE:FREQ=DAILY;INTERVAL=3', onChanged: (_) {});
    expect(find.textContaining('3 days'), findsOneWidget);
  });

  testWidgets('"Use a standard repeat instead" lets go of the rule', (tester) async {
    var used = false;
    await pump(tester, 'RRULE:FREQ=DAILY;INTERVAL=3',
        onChanged: (_) {}, onUseStandard: () => used = true);
    await tester.tap(find.text('Use a standard repeat instead'));
    expect(used, isTrue);
  });

  testWidgets('a rule it cannot read still shows, and offers only the way out',
      (tester) async {
    await pump(tester, 'RRULE:FREQ=HOURLY;INTERVAL=2', onChanged: (_) {});
    expect(find.text('Repeats on its own schedule'), findsOneWidget);
    expect(find.byTooltip('Less often'), findsNothing,
        reason: 'a stepper for something it cannot step would be a lie');
    expect(find.text('Use a standard repeat instead'), findsOneWidget);
  });
}
