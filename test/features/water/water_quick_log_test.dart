import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/water_action_queue.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';

/// Logging a drink straight from the reminder, without opening the app.
///
/// Every competing hydration app has this; ours had no notification action at
/// all, so the reminder that was supposed to make you drink instead made you
/// open the app, find the tab and tap a tile. The action fires in a background
/// isolate where Drift does not exist, so it can only queue the intent — these
/// tests pin the queue and the drain that turns it into a real log.
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

  group('WaterActionQueue', () {
    test('drain returns what was enqueued, and empties on ack', () async {
      final t = DateTime(2026, 8, 21, 9, 30);
      await WaterActionQueue.enqueue(amountMl: 250, at: t);
      await WaterActionQueue.enqueue(amountMl: 500, at: t);

      final first = await WaterActionQueue.drain();
      expect(first.map((p) => p.amountMl).toList(), [250, 500]);
      expect(first.first.at, t);

      // Draining deliberately no longer clears — the caller acks what it
      // actually managed to write, so a failed write leaves the drink queued
      // rather than losing it. The ack is what stops a resume re-logging it.
      await WaterActionQueue.ack(first);
      expect(await WaterActionQueue.drain(), isEmpty,
          reason: 'an acked drink must never be logged twice');
    });

    test('one malformed entry does not strand the rest', () async {
      await WaterActionQueue.enqueue(amountMl: 250, at: DateTime(2026, 8, 21));
      // Corrupt the stored list the way a partial write or version skew would.
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('pending_water_actions')!;
      await prefs.setStringList(
          'pending_water_actions', ['not json', ...list, '{"amountMl":0}']);

      final drained = await WaterActionQueue.drain();
      expect(drained.length, 1,
          reason: 'the good entry survives; junk and non-positive are dropped');
      expect(drained.single.amountMl, 250);
    });
  });

  group('drainPendingWaterActions', () {
    test('writes a real log at the time the button was tapped', () async {
      // Pinned to the afternoon. With a real clock this subtracts 4 hours from
      // whenever the suite happens to run, so between midnight and 04:00 the
      // "tap" lands on YESTERDAY and getTodayData() is empty — the same
      // 00:01 failure `test/support/focus_harness.dart` records.
      final now = DateTime(2026, 6, 10, 13, 30);
      final tapped = now.subtract(const Duration(hours: 4));
      await withClock(Clock.fixed(now), () async {
        await WaterActionQueue.enqueue(amountMl: 250, at: tapped);
      });

      final applied = await withClock(
          Clock.fixed(now), () => WaterService.drainPendingWaterActions());

      expect(applied.length, 1);
      final today = withClock(Clock.fixed(now), WaterService.getTodayData);
      expect(today.logs.length, 1);
      expect(today.logs.single.amountMl, 250);
      expect(today.logs.single.time, tapped,
          reason: 'stamping it at resume would put a 9am drink on the timeline '
              'at 6pm and skew the pacing maths all day');
      expect(today.totalIntakeMl, 250);
    });

    test('the returned records can undo exactly what was applied', () async {
      // Pinned for the same reason as above.
      final now = DateTime(2026, 6, 10, 13, 30);
      await withClock(Clock.fixed(now), () async {
        await WaterActionQueue.enqueue(
            amountMl: 250, at: now.subtract(const Duration(hours: 1)));
        await WaterActionQueue.enqueue(
            amountMl: 250, at: now.subtract(const Duration(hours: 2)));

        final applied = await WaterService.drainPendingWaterActions();
        expect(WaterService.getTodayData().logs.length, 2);

        for (final a in applied) {
          // The day it was filed under, not today — see
          // `quick_add_day_and_undo_test.dart`.
          await WaterService.removeWaterLogForDate(a.at, a.id);
        }
        expect(WaterService.getTodayData().logs, isEmpty);
        expect(WaterService.getTodayData().totalIntakeMl, 0);
      });
    });

    test('an empty queue is a no-op', () async {
      expect(await WaterService.drainPendingWaterActions(), isEmpty);
      expect(WaterService.getTodayData().logs, isEmpty);
    });
  });
}
