/// SS-17 — the manual sleep sheet accepted a night that never happened.
///
/// Two silent acceptances, both of which move a health figure the user cannot
/// reconcile afterwards:
///
/// * **bed == wake.** `_bedDateTime()` wraps a bedtime at/after the wake time
///   to the previous evening, so setting both pickers to the same moment did
///   not produce a zero-length night — it produced a 24-hour one, and the old
///   `_durationMinutes > 0` guard on Save happily let 1440 through.
/// * **A wake time in the future.** `_pickDate` bounds the DATE to today but
///   `_pickTime` bounds nothing, so "today at 23:00" could be logged at 09:00
///   as sleep that has not happened yet.
///
/// Either one is then averaged into `sleepDebtMinutes` and the regularity
/// index.
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/sleep/models/sleep_schedule.dart';
import 'package:tablet_remainder/features/sleep/widgets/sleep_manual_log_sheet.dart';

/// 2026-03-10 at 09:30 — a plain weekday morning, no DST boundary near it.
final _now = DateTime(2026, 3, 10, 9, 30);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('SleepManualLogSheet.validate', () {
    test('a normal night passes', () {
      expect(
        SleepManualLogSheet.validate(
          bedtime: DateTime(2026, 3, 9, 22, 30),
          wakeTime: DateTime(2026, 3, 10, 7, 0),
          now: _now,
        ),
        isNull,
      );
    });

    test('the 24-hour night bed == wake resolves to is rejected', () {
      // Exactly what `_bedDateTime()` produces when both pickers read 07:00.
      final msg = SleepManualLogSheet.validate(
        bedtime: DateTime(2026, 3, 9, 7, 0),
        wakeTime: DateTime(2026, 3, 10, 7, 0),
        now: _now,
      );
      expect(msg, isNotNull);
      expect(msg, contains('24-hour night'));
    });

    test('a wake time later today is rejected', () {
      final msg = SleepManualLogSheet.validate(
        bedtime: DateTime(2026, 3, 10, 22, 0),
        wakeTime: DateTime(2026, 3, 10, 23, 0),
        now: _now,
      );
      expect(msg, isNotNull);
      expect(msg, contains('has not happened yet'));
    });

    test('a wake time one minute ago is fine — the bound is "now", not "today"',
        () {
      expect(
        SleepManualLogSheet.validate(
          bedtime: _now.subtract(const Duration(hours: 8)),
          wakeTime: _now.subtract(const Duration(minutes: 1)),
          now: _now,
        ),
        isNull,
      );
    });

    test('a zero-length or negative span is rejected', () {
      expect(
        SleepManualLogSheet.validate(
          bedtime: DateTime(2026, 3, 10, 7, 0),
          wakeTime: DateTime(2026, 3, 10, 7, 0),
          now: _now,
        ),
        isNotNull,
      );
      expect(
        SleepManualLogSheet.validate(
          bedtime: DateTime(2026, 3, 10, 8, 0),
          wakeTime: DateTime(2026, 3, 10, 7, 0),
          now: _now,
        ),
        isNotNull,
      );
    });

    test('a long-but-real night is still accepted', () {
      // 19:00 → 14:00, 19 hours. Unusual, not impossible (illness), and the
      // bound has to sit above it or the guard becomes a different bug.
      expect(
        SleepManualLogSheet.validate(
          bedtime: DateTime(2026, 3, 9, 19, 0),
          wakeTime: DateTime(2026, 3, 10, 9, 0),
          now: _now,
        ),
        isNull,
      );
    });
  });

  group('the sheet itself', () {
    /// Opens the sheet with [schedule] and hands back the result future.
    Future<SleepManualLogResult?> open(
      WidgetTester tester,
      SleepSchedule schedule,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(430, 1600);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SleepManualLogResult? result;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await SleepManualLogSheet.show(context,
                      schedule: schedule);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('bed == wake shows the reason and refuses to save',
        (tester) async {
      await withClock(Clock.fixed(_now), () async {
        await open(
          tester,
          const SleepSchedule(
              bedtimeHour: 7, bedtimeMinute: 0, wakeHour: 7, wakeMinute: 0),
        );

        expect(find.textContaining('24-hour night'), findsOneWidget,
            reason: 'the sheet has to say why, not just sit there');

        await tester.tap(find.text('Save sleep'));
        await tester.pumpAndSettle();

        // Save is disabled, so the sheet is still up and nothing was returned.
        expect(find.text('Save sleep'), findsOneWidget);
        expect(find.textContaining('24-hour night'), findsOneWidget);
      });
    });

    testWidgets(
        'before the usual wake time the sheet opens on LAST night, not on a '
        'wake that has not happened', (tester) async {
      await withClock(Clock.fixed(_now), () async {
        await open(
          tester,
          // It is 09:30 and the usual wake is 23:00: "today's" wake is hours
          // away. The sheet used to open on it anyway, showing "has not happened
          // yet" with Save disabled — for the person logging a night in the
          // small hours, which is exactly when someone does.
          const SleepSchedule(
              bedtimeHour: 15, bedtimeMinute: 0, wakeHour: 23, wakeMinute: 0),
        );

        expect(find.text('Yesterday'), findsOneWidget);
        expect(find.textContaining('has not happened yet'), findsNothing);

        await tester.tap(find.text('Save sleep'));
        await tester.pumpAndSettle();
        expect(find.text('Save sleep'), findsNothing,
            reason: 'it saved, so the sheet closed');
      });
    });

    testWidgets('after the usual wake time it opens on today, as it always did',
        (tester) async {
      await withClock(Clock.fixed(_now), () async {
        await open(
          tester,
          const SleepSchedule(
              bedtimeHour: 22, bedtimeMinute: 30, wakeHour: 7, wakeMinute: 0),
        );

        expect(find.text('Today'), findsOneWidget);
        expect(find.text('Yesterday'), findsNothing);
      });
    });

    testWidgets(
        'a wake time later today, chosen by hand, shows the reason and refuses '
        'to save', (tester) async {
      await withClock(Clock.fixed(_now), () async {
        await open(
          tester,
          const SleepSchedule(
              bedtimeHour: 15, bedtimeMinute: 0, wakeHour: 23, wakeMinute: 0),
        );

        // It opened on yesterday; the person moves it to today, where 23:00 is
        // still ahead of the clock.
        await tester.tap(find.text('Yesterday'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('10').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Set date'));
        await tester.pumpAndSettle();

        expect(find.textContaining('has not happened yet'), findsOneWidget);

        await tester.tap(find.text('Save sleep'));
        await tester.pumpAndSettle();
        expect(find.text('Save sleep'), findsOneWidget);
      });
    });

    testWidgets('a real night saves, with no complaint', (tester) async {
      await withClock(Clock.fixed(_now), () async {
        await open(
          tester,
          const SleepSchedule(
              bedtimeHour: 22, bedtimeMinute: 30, wakeHour: 7, wakeMinute: 0),
        );

        expect(find.textContaining('24-hour night'), findsNothing);
        expect(find.textContaining('has not happened yet'), findsNothing);
        expect(find.text('8h 30m'), findsOneWidget);

        await tester.tap(find.text('Save sleep'));
        await tester.pumpAndSettle();

        // The sheet closed — the only way out of it is a successful save.
        expect(find.text('Save sleep'), findsNothing);
      });
    });
  });
}
