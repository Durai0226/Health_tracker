/// Ticking a repeating reminder recorded the outcome against the wrong day.
///
/// `Reminder.scheduledTime` is an ANCHOR, not the instant that just came due —
/// for a repeating reminder it is wherever the last roll-forward left it, or the
/// creation time for one that has never been ticked. The reminders list wrote
/// `done` against that anchor, so:
///
///   * the outcome landed on an occurrence that could be days old, and
///   * the occurrence that was genuinely due stayed `pending` until the
///     reconcile sweep wrote it off as MISSED.
///
/// A user who answered a daily reminder every single day therefore accumulated
/// missed occurrences, and the "still pending" follow-up — which is keyed by the
/// occurrence instant — kept firing for something already done. Now that
/// `recordDueReminderOccurrences` derives the pending rows, the two disagreeing
/// instants are visible as duplicate rows in the log.
library;

import 'dart:io';
import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart'
    show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';
import 'package:tablet_remainder/features/reminders/screens/reminders_screen.dart';
import 'package:tablet_remainder/features/reminders/services/reminder_service.dart';

void main() {
  late AppDatabase db;

  /// Now, pinned. The anchor sits three days back, so anchor != due instant.
  final now = DateTime(2026, 6, 20, 12, 0);
  final anchor = DateTime(2026, 6, 17, 9, 0);
  final dueToday = DateTime(2026, 6, 20, 9, 0);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    // The service caches the DB handle and its own category/reminder caches
    // across tests; without this the second test writes through a closed
    // database.
    CleanStorageService.resetForTesting();
    ActiveProfileService().resetForTesting();
    await ReminderService.instance.resetForTesting();
  });
  tearDown(() async {
    await ReminderService.instance.resetForTesting();
    await db.close();
  });

  Reminder daily({DateTime? at, DateTime? endsAt, bool paused = false}) =>
      Reminder(
        id: 'r-1',
        title: 'Water the plants',
        body: 'Just the ferns',
        scheduledTime: at ?? anchor,
        repeatType: RepeatType.daily,
        endsAt: endsAt,
        isPaused: paused,
      );

  group('which occurrence a tick belongs to', () {
    test('the most recent one at or before now, not the stored anchor', () {
      final r = daily();
      expect(resolveReminderOccurrence(r, now: now), dueToday);
      expect(resolveReminderOccurrence(r, now: now), isNot(r.scheduledTime),
          reason: 'the anchor is three days old — that is the whole defect');
    });

    test('an occurrence still to come today resolves to yesterday', () {
      // 08:00 on a daily 09:00 reminder: nothing has come due yet today, so the
      // tick belongs to yesterday's 09:00 — never to a future instant.
      final at = resolveReminderOccurrence(daily(),
          now: DateTime(2026, 6, 20, 8, 0));
      expect(at, DateTime(2026, 6, 19, 9, 0));
    });

    test('a one-off keeps its own instant — the guard must not over-fire', () {
      final oneOff = Reminder(
        id: 'r-2',
        title: 'Renew passport',
        body: '',
        scheduledTime: anchor,
      );
      expect(resolveReminderOccurrence(oneOff, now: now), anchor);
    });

    test('an anchor in the future is itself', () {
      final future = daily(at: DateTime(2026, 6, 21, 9, 0));
      expect(resolveReminderOccurrence(future, now: now),
          DateTime(2026, 6, 21, 9, 0));
    });

    test('a paused reminder does not walk forward', () {
      expect(resolveReminderOccurrence(daily(paused: true), now: now), anchor);
    });

    test('endsAt caps the walk', () {
      // Repeats daily but stopped after the 18th: the last real occurrence is
      // the 18th, not today.
      final ended = daily(endsAt: DateTime(2026, 6, 18, 23, 59));
      expect(resolveReminderOccurrence(ended, now: now),
          DateTime(2026, 6, 18, 9, 0));
    });

    test('a weekly reminder lands on the right week', () {
      final weekly = Reminder(
        id: 'r-3',
        title: 'Bins out',
        body: '',
        scheduledTime: DateTime(2026, 6, 3, 7, 0), // a Wednesday
        repeatType: RepeatType.weekly,
      );
      expect(resolveReminderOccurrence(weekly, now: now),
          DateTime(2026, 6, 17, 7, 0));
    });
  });

  group('the tick lands on the row the derive pass created', () {
    test('today stops being pending, and no duplicate row appears', () async {
      await withClock(Clock.fixed(now), () async {
        await CleanStorageService.saveReminder(daily());
        // The pass that turns "came due" into pending rows.
        await CleanStorageService.recordDueReminderOccurrences();
        final derived =
            await CleanStorageService.getReminderOccurrences('r-1');
        expect(derived.map((o) => o.scheduledFor), contains(dueToday),
            reason: 'the derive pass must have produced today s occurrence');
        final derivedCount = derived.length;

        await CleanStorageService.recordReminderOutcome(
          reminderId: 'r-1',
          scheduledFor: resolveReminderOccurrence(daily()),
          outcome: ReminderOutcome.done,
          source: 'app',
        );

        final after = await CleanStorageService.getReminderOccurrences('r-1');
        expect(after, hasLength(derivedCount),
            reason: 'recording against the anchor ADDS a row instead of '
                'resolving the pending one');
        final today = after.firstWhere((o) => o.scheduledFor == dueToday);
        expect(today.outcome, ReminderOutcome.done.name);
      });
    });
  });

  group('the reminders list itself', () {
    /// Drift's stream-query cancel schedules a zero-duration timer when the
    /// `StreamBuilder` unmounts; left to teardown it fails the test as a
    /// pending timer. Same workaround as
    /// test/responsive/responsive_overflow_test.dart.
    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 10));
    }

    /// Fixed-frame pump, never `pumpAndSettle` — this screen runs animations
    /// that never settle.
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
    }

    testWidgets('ticking the card resolves today, not the anchor',
        (tester) async {
      await withClock(Clock.fixed(now), () async {
        await CleanStorageService.saveReminder(daily());
        await CleanStorageService.recordDueReminderOccurrences();

        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          home: const RemindersScreen(),
        ));
        await settle(tester);
        expect(find.text('Water the plants'), findsOneWidget,
            reason: 'the reminder must be on the list to be ticked');

        // The card's 44px tick hit target, scoped to this card's row.
        // (`find.bySemanticsLabel` is avoided deliberately: semantics lookups
        // are unreliable on this app's scrolling screens.)
        final tick = find.descendant(
          of: find.ancestor(
              of: find.text('Water the plants'),
              matching: find.byType(IntrinsicHeight)),
          matching: find.byWidgetPredicate(
              (w) => w is SizedBox && w.width == 44 && w.height == 44),
        );
        // The card also carries a 44pt More trigger, LAST in the row; the tick
        // is the first of the two.
        expect(tick, findsNWidgets(2));
        await tester.tap(tick.first);
        await settle(tester);

        final rows = await CleanStorageService.getReminderOccurrences('r-1');
        final today = rows.firstWhere((o) => o.scheduledFor == dueToday);
        expect(today.outcome, ReminderOutcome.done.name,
            reason: 'the occurrence the user ticked off is the due one');
        final anchorRow =
            rows.where((o) => o.scheduledFor == anchor).toList();
        expect(anchorRow.map((o) => o.outcome), isNot(contains('done')),
            reason: 'the three-day-old anchor must not be marked done');

        await unmount(tester);
      });
    });

    // NOT a widget test, and the reason is narrow: this file installs no
    // notification scheduler.
    //
    // The toast genuinely does not render here, but not because the harness
    // cannot show one. `NotificationService().init()` never completes headless
    // (it reaches for the device timezone and the plugin), so the `arm()` inside
    // `_toggle` hangs forever and everything after it — `_load()` and the toast
    // — is never reached. `schedulerForTesting` sets `_isInitialized`, which is
    // what makes the whole tail of `_toggle` observable;
    // test/reminders/tick_reports_arm_failure_test.dart does exactly that and
    // asserts the rendered toast, the Undo, and the roll-back.
    //
    // This stays as a source pin because it is cheap and it guards the WIRING
    // (that Undo is handed what the tick itself changed, occurrence included,
    // rather than anything re-derived from the stored anchor), which the widget
    // test cannot see from outside. What the tick and Undo actually do is
    // asserted by behaviour in test/reminders/reminder_completion_test.dart,
    // against the one implementation the screen and the notification's Done
    // button share.
    test('the tick offers an Undo, and Undo reverts what the tick changed', () {
      final src =
          File('lib/features/reminders/screens/reminders_screen.dart')
              .readAsStringSync();
      expect(src, contains("label: 'Undo'"),
          reason: 'a ticked card vanishes from Today with no other feedback');
      expect(src, contains('ReminderCompletion.markDone(r)'),
          reason: 'the tick is the shared one, not a second implementation');
      expect(src, contains('_undoToggle(done)'),
          reason: 'Undo must revert the SAME occurrence the tick recorded, not '
              'the stored anchor: it travels in the DoneUndo the tick returned');
      final undo = src.substring(src.indexOf('Future<void> _undoToggle('));
      final body = undo.substring(0, undo.indexOf('\n  Future<'));
      expect(body, contains('ReminderCompletion.undo(done)'));
    });
  });
}
