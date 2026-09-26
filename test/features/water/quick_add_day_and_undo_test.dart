import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/water_action_queue.dart';
import 'package:tablet_remainder/features/water/models/beverage_type.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';

/// Drinks logged from outside the app — a reminder's "Log 250 ml" button or the
/// home-screen widget's "+250" — used to end up on the wrong day, be lost when
/// a write failed, and be un-undoable.
///
///  * The iOS widget stamps its taps with `ISO8601DateFormatter()`, which is
///    always UTC. The day a drink is filed under is read off `.year/.month/.day`,
///    so someone in Asia/Kolkata tapping +250 at 02:00 had it counted against
///    YESTERDAY's goal and shown on the timeline at 20:30 — with today's dial
///    still at 0. Every tap between midnight and 05:30 IST.
///  * The queue was cleared BEFORE the caller wrote the logs, so any throw
///    while applying them lost the drinks silently: no log, no queue entry, no
///    message.
///  * The confirmation toast's Undo deleted from TODAY, but the drink was filed
///    at the tap time — very often yesterday. The log row went, yesterday's
///    totals stayed, and history disagreed with its own logs.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    WaterService.clearInMemory();
    await WaterService.resetForTesting();
    await WaterService.init();
  });

  tearDown(() async => database.close());

  BeverageType water() =>
      BeverageType.defaultBeverages.firstWhere((b) => b.id == 'water');

  group('a UTC-stamped tap is filed under the local day', () {
    test('drain hands back a LOCAL time, whatever the producer sent', () async {
      final tappedLocal = DateTime(2026, 8, 29, 2, 0);
      // Exactly what the iOS extension writes: the same instant, in Zulu.
      await WaterActionQueue.enqueue(
          amountMl: 250, at: tappedLocal.toUtc());

      final drained = await WaterActionQueue.drain();
      expect(drained.single.at.isUtc, isFalse,
          reason: 'a UTC timestamp read as-is puts the drink on the wrong '
              'calendar day for every user east or west of Greenwich');
      expect(drained.single.at, tappedLocal);
    });

    test('two taps either side of local midnight stay on their own days',
        () async {
      // 00:30 crosses into the previous UTC day for any positive offset; 23:30
      // crosses into the next one for any negative offset. So in any zone but
      // UTC itself, reading these as UTC moves at least one of them off Aug 29.
      //
      // In UTC the property is UNOBSERVABLE — `toUtc()` is the identity, so
      // nothing moves and this test would pass with the fix reverted. Say so
      // and skip, rather than leave a green test that cannot fail: the
      // zone-independent half of the guarantee is asserted by the `isUtc` check
      // in the test above, which catches the same bug in every zone.
      if (DateTime.now().timeZoneOffset == Duration.zero) {
        markTestSkipped('reinterpreting UTC as local is a no-op in UTC — run '
            'under TZ=Asia/Kolkata (or any non-zero offset) for this one');
        return;
      }
      final early = DateTime(2026, 8, 29, 0, 30);
      final late = DateTime(2026, 8, 29, 23, 30);
      await WaterActionQueue.enqueue(amountMl: 250, at: early.toUtc());
      await WaterActionQueue.enqueue(amountMl: 300, at: late.toUtc());

      await withClock(Clock.fixed(DateTime(2026, 8, 30, 8, 0)), () async {
        await WaterService.drainPendingWaterActions();
      });

      expect(WaterService.getDataForDate(early)?.totalIntakeMl, 550);
      expect(WaterService.getDataForDate(DateTime(2026, 8, 28))?.totalIntakeMl,
          anyOf(isNull, 0));
      expect(WaterService.getDataForDate(DateTime(2026, 8, 30))?.totalIntakeMl,
          anyOf(isNull, 0));
    });
  });

  group('nothing is forgotten before it is written', () {
    test('drain does not clear; only an ack does', () async {
      final t = DateTime(2026, 8, 29, 9, 0);
      await WaterActionQueue.enqueue(amountMl: 250, at: t);
      await WaterActionQueue.enqueue(amountMl: 500, at: t);

      final first = await WaterActionQueue.drain();
      expect(first.map((p) => p.amountMl).toList(), [250, 500]);

      final again = await WaterActionQueue.drain();
      expect(again.map((p) => p.amountMl).toList(), [250, 500],
          reason: 'if applying them throws, the drinks must still be queued '
              'for the next resume rather than silently gone');

      await WaterActionQueue.ack([first.first]);
      final left = await WaterActionQueue.drain();
      expect(left.single.amountMl, 500,
          reason: 'only the entry that landed is forgotten');
    });

    test('a successful drain leaves the queue empty — no re-log on the next '
        'resume', () async {
      final now = DateTime(2026, 8, 29, 13, 0);
      await WaterActionQueue.enqueue(amountMl: 250, at: now);

      await withClock(Clock.fixed(now), () async {
        expect((await WaterService.drainPendingWaterActions()).length, 1);
        expect(await WaterService.drainPendingWaterActions(), isEmpty);
        expect(WaterService.getTodayData().totalIntakeMl, 250);
      });
    });

    test('one malformed entry is pruned and does not strand the rest',
        () async {
      await WaterActionQueue.enqueue(amountMl: 250, at: DateTime(2026, 8, 29));
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('pending_water_actions')!;
      await prefs.setStringList(
          'pending_water_actions', ['not json', ...list, '{"amountMl":0}']);

      final drained = await WaterActionQueue.drain();
      expect(drained.length, 1);
      expect(drained.single.amountMl, 250);
      expect(prefs.getStringList('pending_water_actions')!.length, 1,
          reason: 'junk must be dropped at once — nothing will ever ack it');
    });
  });

  group('the drain reports what it actually applied', () {
    test('the real volumes come back, not count x 250', () async {
      final now = DateTime(2026, 8, 29, 13, 0);
      await WaterActionQueue.enqueue(amountMl: 500, at: now);
      await WaterActionQueue.enqueue(amountMl: 330, at: now);

      final applied = await withClock(
          Clock.fixed(now), () => WaterService.drainPendingWaterActions());

      expect(applied.map((a) => a.amountMl).toList(), [500, 330]);
      expect(applied.fold<int>(0, (s, a) => s + a.amountMl), 830,
          reason: 'the toast said "2 × 250 ml" no matter what was tapped');
    });

    test('each applied action carries the day it was filed under', () async {
      final tapped = DateTime(2026, 8, 28, 23, 30);
      await WaterActionQueue.enqueue(amountMl: 250, at: tapped);

      final applied = await withClock(Clock.fixed(DateTime(2026, 8, 29, 8, 0)),
          () => WaterService.drainPendingWaterActions());

      expect(applied.single.at, tapped,
          reason: 'Undo has to delete from the day the drink landed on, and '
              'that is the tap time, not the resume');
    });
  });

  group('undoing a quick-add', () {
    test('removing it from the day it was filed under clears that day',
        () async {
      final tapped = DateTime(2026, 8, 28, 23, 30);
      await WaterActionQueue.enqueue(amountMl: 250, at: tapped);
      final applied = await withClock(Clock.fixed(DateTime(2026, 8, 29, 8, 0)),
          () => WaterService.drainPendingWaterActions());

      await WaterService.removeWaterLogForDate(
          applied.single.at, applied.single.id);

      final day = WaterService.getDataForDate(tapped);
      expect(day!.logs, isEmpty);
      expect(day.totalIntakeMl, 0);
    });

    test('an Undo aimed at the wrong day never desyncs a day from its logs',
        () async {
      final yesterday = DateTime(2026, 8, 28, 23, 30);
      final today = DateTime(2026, 8, 29, 9, 0);

      final oldDay = await WaterService.addWaterLogForDate(
        date: yesterday,
        amountMl: 250,
        beverage: water(),
        time: yesterday,
      );
      final oldId = oldDay.logs.single.id;
      // Today has a row too, which is the state a resumed app is actually in.
      await WaterService.addWaterLogForDate(
        date: today,
        amountMl: 200,
        beverage: water(),
        time: today,
      );

      // The old Undo: today's date, yesterday's log id.
      await WaterService.removeWaterLogForDate(today, oldId);

      expect(WaterService.getDataForDate(today)!.totalIntakeMl, 200,
          reason: "today's own log must be untouched");

      // Re-read yesterday from storage: the row and its logs have to agree.
      WaterService.clearInMemory();
      final reloaded = await WaterService.loadDataForDate(yesterday);
      expect(reloaded!.totalIntakeMl, 250);
      expect(reloaded.logs.length, 1,
          reason: 'the log row was deleted while the day kept its total, so '
              'history and the weekly stats counted a drink that was gone');
      expect(reloaded.logs.single.id, oldId);
    });
  });

  group('two overlapping drains cannot double-log', () {
    // The queue is now read-then-ack rather than read-and-clear, which is what
    // stopped a failed write losing drinks — but it also means the entries stay
    // visible until they are acked. AppShell drains on cold start AND on
    // resume, and a resume can land while the first drain is still awaiting its
    // DB writes, so without a guard both passes applied the same taps.
    test('negative: a second drain while the first is in flight applies nothing',
        () async {
      await WaterActionQueue.enqueue(amountMl: 250, at: clock.now());
      await WaterActionQueue.enqueue(amountMl: 500, at: clock.now());

      // Both started before either can finish.
      final a = WaterService.drainPendingWaterActions();
      final b = WaterService.drainPendingWaterActions();
      final applied = [...await a, ...await b];

      expect(applied, hasLength(2),
          reason: 'each queued tap is applied exactly once');
      expect(WaterService.getTodayData().totalIntakeMl, 750,
          reason: 'a re-entrant drain used to log every drink twice');
      expect(WaterService.getTodayData().logs, hasLength(2));
    });

    test('positive: a later drain still works once the first has finished',
        () async {
      await WaterActionQueue.enqueue(amountMl: 250, at: clock.now());
      expect(await WaterService.drainPendingWaterActions(), hasLength(1));

      await WaterActionQueue.enqueue(amountMl: 300, at: clock.now());
      expect(await WaterService.drainPendingWaterActions(), hasLength(1),
          reason: 'the guard is per-drain, not permanent');
      expect(WaterService.getTodayData().totalIntakeMl, 550);
    });
  });

  group('Undo finds the drink whatever day it was filed under', () {
    test('positive: a drink added for a PAST day is removed by removeWaterLog',
        () async {
      final yesterday = clock.now().subtract(const Duration(days: 1));
      final day = await WaterService.addWaterLogForDate(
        date: yesterday,
        amountMl: 400,
        beverage:
            BeverageType.defaultBeverages.firstWhere((b) => b.id == 'water'),
      );
      final id = day.logs.single.id;

      // `removeWaterLog` takes no date — it used to assume today, look for the
      // id among today's logs, not find it, and (now that a mismatched day is
      // refused rather than silently desynced) do nothing at all.
      await WaterService.removeWaterLog(id);

      final after = WaterService.getDataForDate(yesterday);
      expect(after?.logs ?? const [], isEmpty,
          reason: 'Undo must remove the drink from the day it belongs to');
      expect(after?.totalIntakeMl ?? 0, 0);
    });

    test('negative: an unknown id changes nothing', () async {
      await WaterService.addWaterLog(
          amountMl: 250,
          beverage: BeverageType.defaultBeverages
              .firstWhere((b) => b.id == 'water'));
      await WaterService.removeWaterLog('not-a-log');
      expect(WaterService.getTodayData().totalIntakeMl, 250);
    });
  });
}
