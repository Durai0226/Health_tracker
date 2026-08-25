import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/insight.dart';
import 'package:tablet_remainder/core/health/insight_engine.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import 'package:tablet_remainder/features/insights/services/insight_actions.dart';
import 'package:tablet_remainder/features/reminders/screens/add_reminder_screen.dart';

/// `InsightCard` renders its action button only when `onAction` is non-null.
/// Nothing ever passed one — so `focus_besthour`'s `actionLabel: 'Remind me
/// then'` was dead from the day it was written: a call to action the user could
/// never see, on the one insight designed to create a reminder.
///
/// This file used to assert that `weekly_recap_screen.dart` **literally
/// contained** the string `'onAction: _actionFor(context, i)'`. Two problems
/// with that: it broke the moment the screen was rebuilt, and a comment
/// containing the right text would have satisfied it. It now asserts the three
/// things the grep was standing in for — the parser works, the handler set is
/// complete, and tapping the button actually does something.
void main() {
  group('hourFromMetric — parses what the engine formatted', () {
    // This has never been tested, despite parsing formatted output back into an
    // int the engine already had. Every case here is a real hourLabel output.
    test('morning and afternoon hours', () {
      expect(InsightActions.hourFromMetric('9 AM'), 9);
      expect(InsightActions.hourFromMetric('2 PM'), 14);
      expect(InsightActions.hourFromMetric('11 AM'), 11);
    });

    test('the two midnight/noon edge cases', () {
      // 12 AM is hour 0, not 12. 12 PM is hour 12, not 24.
      expect(InsightActions.hourFromMetric('12 AM'), 0);
      expect(InsightActions.hourFromMetric('12 PM'), 12);
    });

    test('degrades to null rather than guessing', () {
      // A silent no-op is the intended failure: better than scheduling a
      // reminder at an hour we invented.
      expect(InsightActions.hourFromMetric(null), isNull);
      expect(InsightActions.hourFromMetric('no digits here'), isNull);
      expect(InsightActions.hourFromMetric(''), isNull);
    });

    test('an out-of-range hour is refused', () {
      expect(InsightActions.hourFromMetric('99 AM'), isNull);
    });
  });

  group('every insight declaring an action has a handler', () {
    test('the declared ids are all in InsightActions.handled', () {
      // The guard against a second insight shipping dead the same way. It reads
      // the engine source (the good half of the old test) but asserts against a
      // real Dart Set, so it does not care which screen renders the card and a
      // comment cannot fool it.
      final engine =
          File('lib/core/health/insight_engine.dart').readAsStringSync();
      final declared = RegExp(r"id: '([a-z_]+)'[\s\S]{0,600}?actionLabel: '")
          .allMatches(engine)
          .map((m) => m.group(1)!)
          .toSet();

      expect(declared, isNotEmpty,
          reason: 'the regex should still find focus_besthour — if this fails '
              'the engine format changed and this guard is now vacuous');
      expect(declared, everyElement(isIn(InsightActions.handled)),
          reason: 'an insight declares an actionLabel with no handler, so its '
              'button will render and do nothing. Either handle it in '
              'InsightActions or drop the label.');
    });

    test('handled contains no id no engine produces', () {
      // The reverse direction: a stale entry in `handled` would make the guard
      // above pass while the real coverage rotted.
      final engine =
          File('lib/core/health/insight_engine.dart').readAsStringSync();
      for (final id in InsightActions.handled) {
        expect(engine, contains("id: '$id'"), reason: id);
      }
    });
  });

  group('the action actually does something', () {
    testWidgets('tapping focus_besthour pushes the add-reminder screen',
        (tester) async {
      // This is what the render-site grep was proxying for, asserted directly.
      const insight = Insight(
        id: 'focus_besthour',
        feature: InsightFeature.focus,
        severity: InsightSeverity.info,
        title: 'Your best focus hour',
        detail: 'You focus most around 2 PM.',
        metric: '2 PM',
        why: 'Hour of day with the most accumulated focus minutes.',
        actionLabel: 'Remind me then',
      );

      final pushed = <Route<dynamic>>[];
      await tester.pumpWidget(MaterialApp(
        navigatorObservers: [_RecordingObserver(pushed)],
        home: Builder(
          builder: (context) => Scaffold(
            body: InsightCard(
              insight: insight,
              onAction: InsightActions.of(context, insight),
            ),
          ),
        ),
      ));

      expect(find.text('Remind me then'), findsOneWidget,
          reason: 'onAction was null, so InsightCard rendered no button');

      await tester.tap(find.text('Remind me then'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.byType(AddReminderScreen),
        findsOneWidget,
        reason: 'the button rendered but pushed nothing',
      );
      expect(pushed, isNotEmpty);
    });

    testWidgets('an insight with no actionLabel renders no button',
        (tester) async {
      const insight = Insight(
        id: 'focus_streak',
        feature: InsightFeature.focus,
        severity: InsightSeverity.good,
        title: 'On a roll',
        detail: 'Three days running.',
        why: 'Consecutive days with a completed session.',
      );

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: InsightCard(
              insight: insight,
              onAction: InsightActions.of(context, insight),
            ),
          ),
        ),
      ));

      expect(InsightActions.of(tester.element(find.byType(InsightCard)), insight),
          isNull);
    });
  });

  group('the engine keeps feeding a parseable hour', () {
    test('focus_besthour still carries an hour in its metric', () {
      // `hourFromMetric` parses `FocusInsights.hourLabel`. If that format ever
      // renders an hour without a digit, the action silently no-ops.
      final insight = InsightEngine.focus(
        sessionCount: 20,
        completionRate: 0.8,
        bestFocusHour: 14,
        streakDays: 1,
        suggestedMinutes: 25,
      );
      expect(insight?.id, 'focus_besthour');
      expect(insight?.metric, isNotNull);
      expect(RegExp(r'\d').hasMatch(insight!.metric!), isTrue,
          reason: 'hourLabel must keep a parseable hour');
      // And end to end: the engine's own output round-trips through the parser.
      expect(InsightActions.hourFromMetric(insight.metric), 14);
    });
  });
}

class _RecordingObserver extends NavigatorObserver {
  _RecordingObserver(this.pushed);
  final List<Route<dynamic>> pushed;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
    super.didPush(route, previousRoute);
  }
}
