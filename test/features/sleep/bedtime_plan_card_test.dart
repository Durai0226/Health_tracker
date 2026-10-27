/// "Aim for 10:40 PM", with its working, and the offer to have the reminder follow.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/bedtime_plan.dart';
import 'package:tablet_remainder/features/sleep/widgets/bedtime_plan_card.dart';

import '../../support/font_free_theme.dart';

void main() {
  const wake7 = 7 * 60;

  BedtimePlan plan({int catchUp = 0, int target = 465, int awake = 15}) => BedtimePlan(
        bedMinuteOfDay: (wake7 - (target + catchUp + awake)) % 1440,
        wakeMinuteOfDay: wake7,
        needMinutes: target,
        catchUpMinutes: catchUp,
        awakeMinutes: awake,
        awakeIsYours: false,
      );

  Future<void> pump(
    WidgetTester tester,
    BedtimePlan p, {
    int lead = 30,
    bool reminder = false,
    bool follow = false,
    int? fixed,
    VoidCallback? onFollow,
    double width = 430,
    double scale = 1,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, 1600);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: fontFreeTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: BedtimePlanCard(
            plan: p,
            windDownLeadMinutes: lead,
            reminderEnabled: reminder,
            followPlan: follow,
            fixedReminderMinuteOfDay: fixed,
            onFollowPlan: onFollow,
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  group('the plan', () {
    testWidgets('the time, and what it is made of', (tester) async {
      await pump(tester, plan());
      expect(find.text("TONIGHT'S BEDTIME"), findsOneWidget);
      expect(find.text('Aim for 11:00 PM'), findsOneWidget);
      expect(find.text('8 h in bed: your 7 h 45 m of sleep and about 15 m awake in bed.'),
          findsOneWidget);
    });

    testWidgets('with a catch-up, it is named', (tester) async {
      await pump(tester, plan(catchUp: 20));
      expect(find.text('Aim for 10:40 PM'), findsOneWidget);
      expect(
          find.text('8 h 20 m in bed: your 7 h 45 m of sleep, 20 m of catch-up and '
              'about 15 m awake in bed.'),
          findsOneWidget);
    });

    test('the working as a sentence, whatever it holds', () {
      expect(BedtimePlanCard.detail(plan(target: 480, awake: 30)),
          '8 h 30 m in bed: your 8 h of sleep and about 30 m awake in bed.');
      expect(BedtimePlanCard.detail(plan(catchUp: 45, target: 420, awake: 10)),
          '7 h 55 m in bed: your 7 h of sleep, 45 m of catch-up and about 10 m awake in bed.');
    });
  });

  group('the reminder', () {
    testWidgets('nothing about it while it is off, not even an offer', (tester) async {
      await pump(tester, plan(catchUp: 20),
          reminder: false, fixed: 22 * 60 + 30, onFollow: () {});
      expect(find.textContaining('wind-down reminder'), findsNothing);
      expect(find.textContaining('Move it to'), findsNothing);
    });

    testWidgets('where it rings, when it does not follow', (tester) async {
      await pump(tester, plan(catchUp: 20),
          reminder: true, fixed: 22 * 60 + 30, onFollow: () {});
      expect(find.text('Your wind-down reminder is at 10:30 PM.'), findsOneWidget);
    });

    testWidgets('and offers to move it, saying where', (tester) async {
      var taken = 0;
      await pump(tester, plan(catchUp: 20),
          reminder: true, fixed: 22 * 60 + 30, onFollow: () => taken++);
      // The plan is 10:40 PM and the lead 30 minutes: 10:10 PM.
      expect(find.text('Move it to 10:10 PM and keep it there'), findsOneWidget);
      await tester.tap(find.text('Move it to 10:10 PM and keep it there'));
      expect(taken, 1);
    });

    testWidgets('not when it is already about there', (tester) async {
      // Plan 11:00 PM, lead 30: 10:30 PM; the reminder is at 10:33.
      await pump(tester, plan(),
          reminder: true, fixed: 22 * 60 + 33, onFollow: () {});
      expect(find.textContaining('Move it to'), findsNothing);
    });

    testWidgets('five minutes is worth moving for; four is not', (tester) async {
      await pump(tester, plan(), reminder: true, fixed: 22 * 60 + 35, onFollow: () {});
      expect(find.textContaining('Move it to'), findsOneWidget);
      await pump(tester, plan(), reminder: true, fixed: 22 * 60 + 34, onFollow: () {});
      expect(find.textContaining('Move it to'), findsNothing);
    });

    testWidgets('across midnight the distance is the short way round', (tester) async {
      // Plan 00:10 AM (wake 7:00, need 7 h 45 m, catch-up 0, awake 5), lead 0:
      // a reminder at 23:50 is 20 minutes away, not 23 hours.
      const p = BedtimePlan(
        bedMinuteOfDay: 10,
        wakeMinuteOfDay: wake7,
        needMinutes: 410,
        catchUpMinutes: 0,
        awakeMinutes: 10,
        awakeIsYours: true,
      );
      await pump(tester, p, lead: 0, reminder: true, fixed: 23 * 60 + 50, onFollow: () {});
      expect(find.text('Move it to 12:10 AM and keep it there'), findsOneWidget);
    });

    testWidgets('across midnight, four minutes apart is not worth moving for',
        (tester) async {
      // The plan's wind-down is 12:02 AM; the reminder is at 11:58 PM.
      const p = BedtimePlan(
        bedMinuteOfDay: 2,
        wakeMinuteOfDay: wake7,
        needMinutes: 410,
        catchUpMinutes: 0,
        awakeMinutes: 10,
        awakeIsYours: true,
      );
      await pump(tester, p, lead: 0, reminder: true, fixed: 23 * 60 + 58, onFollow: () {});
      expect(find.textContaining('Move it to'), findsNothing);
    });

    testWidgets('no offer without something to do with it', (tester) async {
      await pump(tester, plan(catchUp: 20), reminder: true, fixed: 22 * 60 + 30);
      expect(find.textContaining('Move it to'), findsNothing);
    });

    testWidgets('following: it says so, and offers nothing', (tester) async {
      await pump(tester, plan(catchUp: 20),
          reminder: true, follow: true, fixed: 22 * 60 + 30, onFollow: () {});
      expect(find.text('Your wind-down reminder follows this plan: 10:10 PM tonight.'),
          findsOneWidget);
      expect(find.textContaining('Move it to'), findsNothing);
    });

    testWidgets('the offer is a real target', (tester) async {
      await pump(tester, plan(catchUp: 20),
          reminder: true, fixed: 22 * 60 + 30, onFollow: () {});
      final size = tester.getSize(find.ancestor(
          of: find.text('Move it to 10:10 PM and keep it there'),
          matching: find.byType(TextButton)));
      expect(size.height, greaterThanOrEqualTo(44));
    });
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('fits at 320pt and ${scale}x text, the longest it gets', (tester) async {
      final reports = <String>[];
      final prev = FlutterError.onError;
      FlutterError.onError = (d) => reports.add(d.toString());
      try {
        await pump(tester, plan(catchUp: 45, target: 480, awake: 45),
            reminder: true,
            fixed: 22 * 60 + 30,
            onFollow: () {},
            width: 320,
            scale: scale);
      } finally {
        FlutterError.onError = prev;
      }
      expect(find.textContaining('Aim for'), findsOneWidget);
      expect(reports.where((r) => r.contains('bedtime_plan_card.dart')), isEmpty,
          reason: reports.join('\n').split('\n').take(6).join('\n'));
    });
  }
}
