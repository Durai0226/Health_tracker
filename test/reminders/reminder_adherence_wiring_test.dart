/// `ReminderAdherence` reaches a screen.
///
/// The engine was 136 lines, fully tested, and completely unreachable — its only
/// reference in `lib/` was its own private constructor. The occurrence log it
/// reads was built to make this question answerable and nothing had ever asked.
///
/// `reminder_adherence_test.dart` covers the arithmetic. This covers the path:
/// database -> `ReminderService.adherence()` -> the summary a card renders.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart'
    show AppDatabase, ReminderOccurrencesCompanion;
import 'package:tablet_remainder/core/database/daos/reminders_dao.dart';
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';
import 'package:tablet_remainder/features/reminders/services/reminder_service.dart';
import 'package:drift/drift.dart' show Value;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  final today = DateTime(2026, 6, 20, 12);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
  });
  tearDown(() async => db.close());

  Future<void> record(DateTime at, ReminderOutcome outcome) =>
      db.remindersDao.recordOccurrence(ReminderOccurrencesCompanion.insert(
        id: RemindersDao.occurrenceId('r-1', at),
        reminderId: 'r-1',
        scheduledFor: at,
        outcome: Value(outcome.name),
      ));

  DateTime day(int d, [int hour = 9]) => DateTime(2026, 6, d, hour);

  test('with an empty log it reports nothing at all', () async {
    await withClock(Clock.fixed(today), () async {
      expect(await ReminderService.instance.adherence(), isNull,
          reason: 'a card must render nothing rather than 0%');
    });
  });

  test('a perfect fortnight reaches the summary as 100%', () async {
    await withClock(Clock.fixed(today), () async {
      for (var d = 6; d <= 19; d++) {
        await record(day(d), ReminderOutcome.done);
      }
      final a = await ReminderService.instance.adherence();
      expect(a, isNotNull, reason: 'the engine is not reaching the service');
      expect(a!.proportionOfDaysCovered, 1.0);
      expect(a.daysCounted, 14, reason: 'the card states this as its denominator');
      expect(a.isAdherent, isTrue);
      expect(a.streak.current, greaterThan(0));
    });
  });

  test('days with nothing resolved stay out of the denominator', () async {
    await withClock(Clock.fixed(today), () async {
      await record(day(17), ReminderOutcome.done);
      await record(day(18), ReminderOutcome.pending);
      await record(day(19), ReminderOutcome.done);
      final a = await ReminderService.instance.adherence();
      // Two days known, not three. A pending day is unknown, not a failure —
      // scoring it would measure app-opening.
      expect(a!.daysCounted, 2);
      expect(a.proportionOfDaysCovered, 1.0);
    });
  });

  test('the two rates disagree exactly where the doc says they will',
      () async {
    await withClock(Clock.fixed(today), () async {
      // Three of four done, every day: 75% of occurrences, 0% of days covered.
      // That gap is the thing a single figure hides, and the card only shows
      // the second line when it is real.
      for (var d = 16; d <= 19; d++) {
        for (var i = 0; i < 3; i++) {
          await record(day(d, 8 + i), ReminderOutcome.done);
        }
        await record(day(d, 20), ReminderOutcome.missed);
      }
      final a = await ReminderService.instance.adherence();
      expect(a!.proportionOfDaysCovered, 0.0);
      expect(a.proportionOfOccurrencesDone, 0.75);
      expect(a.ratesDisagree, isTrue);
      expect(a.isAdherent, isFalse);
    });
  });

  test('a deliberate skip is not held against you', () async {
    await withClock(Clock.fixed(today), () async {
      await record(day(18), ReminderOutcome.done);
      await record(day(19), ReminderOutcome.skipped);
      final a = await ReminderService.instance.adherence();
      // The skipped day drops out entirely rather than scoring zero: an
      // adherence figure that punishes honesty teaches people to stop being
      // honest.
      expect(a!.daysCounted, 1);
      expect(a.proportionOfDaysCovered, 1.0);
    });
  });
}
