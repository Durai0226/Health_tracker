/// Water reaches the cloud for the last week of days, not only today.
///
/// The sync reconciled today's document and nothing else, so a drink logged after
/// the day's last sync — an evening glass, with the app opened only in the morning
/// — was never uploaded: by the next sync it belonged to yesterday. The first
/// upload to a new account also carried today alone, leaving the rest of the
/// person's water history on the phone only.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/cloud_sync_service.dart';
import 'package:tablet_remainder/core/services/health_cloud_sync_service.dart';
import 'package:tablet_remainder/features/water/models/enhanced_water_log.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;
  late FakeFirebaseFirestore fs;

  // Tuesday 10 March 2026, 21:00 — the evening the drinks below were logged.
  final now = DateTime(2026, 3, 10, 21);
  DateTime daysAgo(int n, [int hour = 20]) =>
      DateTime(now.year, now.month, now.day - n, hour);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    fs = FakeFirebaseFirestore();
    CloudSyncService().firestoreForTesting = fs;
    HealthCloudSyncService.instance.firestoreForTesting = fs;
    WaterService.clearInMemory();
    await WaterService.resetForTesting();
    await WaterService.init();
  });

  tearDown(() async {
    CloudSyncService().firestoreForTesting = null;
    HealthCloudSyncService.instance.firestoreForTesting = null;
    await database.close();
  });

  Future<void> drink(int daysBack, int ml, {String? id}) =>
      WaterService.addWaterLogForDate(
        date: daysAgo(daysBack),
        amountMl: ml,
        beverage: WaterService.getBeverage('water')!,
        id: id,
        syncToHealth: false,
      );

  /// Under the same fixed clock as the sync: a tombstone older than the warm
  /// window is pruned against the CLOCK, and the real one is months past March.
  Future<void> remove(int daysBack, String id) => withClock(Clock.fixed(now),
      () => WaterService.removeWaterLogForDate(daysAgo(daysBack), id));

  Future<void> sync() => withClock(
      Clock.fixed(now), () => CloudSyncService().syncUserData('u1'));

  Future<Map<String, dynamic>?> cloudDay(int daysBack) async {
    final doc = await fs
        .collection('users')
        .doc('u1')
        .collection('water_intake')
        .doc(WaterService.dateKeyFor(daysAgo(daysBack)))
        .get();
    return doc.data();
  }

  group('a sync', () {
    test('uploads a drink from an earlier day this week', () async {
      await drink(2, 300);

      await sync();

      final day = await cloudDay(2);
      expect(day, isNotNull,
          reason: 'only today was reconciled, so this day never left the phone');
      expect((day!['logs'] as List), hasLength(1));
    });

    test('uploads every day in the window, and today', () async {
      for (final back in [0, 1, 3, 6]) {
        await drink(back, 200 + back);
      }

      await sync();

      for (final back in [0, 1, 3, 6]) {
        expect(await cloudDay(back), isNotNull, reason: '$back days ago');
      }
    });

    test('leaves a day outside the window alone', () async {
      await drink(7, 250);

      await sync();

      expect(await cloudDay(7), isNull,
          reason: 'a routine sync reconciles a week, not all of history');
    });

    test('a day with nothing in it writes nothing', () async {
      await sync();

      final all = await fs.collection('users').doc('u1').collection('water_intake').get();
      expect(all.docs, isEmpty);
    });

    test('brings down a drink a peer logged earlier this week', () async {
      final peer = EnhancedWaterLog(
        id: 'peer-drink',
        time: daysAgo(3, 9),
        amountMl: 400,
        effectiveHydrationMl: 400,
        beverageId: 'water',
        beverageName: 'Water',
        beverageEmoji: '💧',
      );
      await fs
          .collection('users')
          .doc('u1')
          .collection('water_intake')
          .doc(WaterService.dateKeyFor(daysAgo(3)))
          .set(DailyWaterData(
            id: WaterService.dateKeyFor(daysAgo(3)),
            date: daysAgo(3),
            dailyGoalMl: 2500,
            totalIntakeMl: 400,
            effectiveHydrationMl: 400,
            logs: [peer],
          ).toJson());

      await sync();

      final local = await WaterService.loadDataForDate(daysAgo(3));
      expect(local!.logs.map((l) => l.id), ['peer-drink']);
    });

    test('merges, not overwrites, an earlier day both sides have drinks on',
        () async {
      await drink(2, 250, id: 'mine');
      await fs
          .collection('users')
          .doc('u1')
          .collection('water_intake')
          .doc(WaterService.dateKeyFor(daysAgo(2)))
          .set(DailyWaterData(
            id: WaterService.dateKeyFor(daysAgo(2)),
            date: daysAgo(2),
            dailyGoalMl: 2500,
            totalIntakeMl: 500,
            effectiveHydrationMl: 500,
            logs: [
              EnhancedWaterLog(
                id: 'theirs',
                time: daysAgo(2, 8),
                amountMl: 500,
                effectiveHydrationMl: 500,
                beverageId: 'water',
                beverageName: 'Water',
                beverageEmoji: '💧',
              ),
            ],
          ).toJson());

      await sync();

      final day = await cloudDay(2);
      expect({for (final l in day!['logs'] as List) (l as Map)['id']},
          {'mine', 'theirs'},
          reason: 'both survive, locally and in the cloud');
    });

    test('a drink deleted on an earlier day is deleted in the cloud too',
        () async {
      await drink(2, 250, id: 'doomed');
      await drink(2, 300, id: 'kept');
      await sync();
      expect((await cloudDay(2))!['logs'], hasLength(2));

      await remove(2, 'doomed');
      await sync();

      final day = await cloudDay(2);
      expect({for (final l in day!['logs'] as List) (l as Map)['id']}, {'kept'});
      expect(day['deletedLogIds'], ['doomed'],
          reason: 'the tombstone travels, or the next download returns it');
    });

    test('a day emptied by deletes, with nothing in the cloud, uploads nothing',
        () async {
      await drink(2, 250, id: 'only');
      await remove(2, 'only');

      await sync();

      expect(await cloudDay(2), isNull,
          reason: 'there is no drink to restore, so no document to create');
    });

    test('a delete the cloud has not heard of reaches it even when the counts '
        'happen to agree', () async {
      // The cloud holds one 250 ml drink. Here it is deleted and another 250 ml
      // is logged, so the merged day and the cloud's both read "one drink,
      // 250 ml" — only the tombstone says they are different drinks.
      await drink(2, 250, id: 'old');
      await sync();
      await remove(2, 'old');
      await drink(2, 250, id: 'new');

      await sync();

      final day = await cloudDay(2);
      expect({for (final l in day!['logs'] as List) (l as Map)['id']}, {'new'});
      expect(day['deletedLogIds'], ['old']);
    });

    test('one day the cloud refuses to read does not stop the others', () async {
      // Everything is readable and writable except one day's water document.
      final refusing = FakeFirebaseFirestore(securityRules: '''
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{u} { allow read, write: if true; }
    match /users/{u}/{col}/{doc} { allow read, write: if col != 'water_intake'; }
    match /users/{u}/water_intake/{day} {
      allow read: if day != '${WaterService.dateKeyFor(daysAgo(1))}';
      allow write: if true;
    }
  }
}
''');
      CloudSyncService().firestoreForTesting = refusing;
      HealthCloudSyncService.instance.firestoreForTesting = refusing;
      await drink(0, 250);
      await drink(1, 250);
      await drink(2, 250);

      await sync();

      Future<bool> uploaded(int back) async => (await refusing
              .collection('users')
              .doc('u1')
              .collection('water_intake')
              .doc(WaterService.dateKeyFor(daysAgo(back)))
              .get())
          .exists;
      expect(await uploaded(2), isTrue, reason: 'the day after the refused one');
      expect(await uploaded(0), isTrue, reason: 'and the one before it');
    });
  });

  group('the first upload', () {
    test('carries every stored day, however old', () async {
      await drink(0, 250);
      await drink(5, 250);
      await drink(40, 250);
      await drink(400, 250);

      await withClock(
          Clock.fixed(now), () => CloudSyncService().uploadDataToCloud('u1'));

      for (final back in [0, 5, 40, 400]) {
        expect(await cloudDay(back), isNotNull, reason: '$back days ago');
      }
    });

    test('carries the deletions with each day', () async {
      await drink(3, 250, id: 'doomed');
      await drink(3, 300, id: 'kept');
      await remove(3, 'doomed');

      await withClock(
          Clock.fixed(now), () => CloudSyncService().uploadDataToCloud('u1'));

      final day = await cloudDay(3);
      expect({for (final l in day!['logs'] as List) (l as Map)['id']}, {'kept'});
      expect(day['deletedLogIds'], ['doomed'],
          reason: 'without it the next download hands the drink back');
    });

    test('carries the deletions even after a restart, when the day was loaded '
        'before anything read them', () async {
      await drink(3, 250, id: 'doomed');
      await drink(3, 300, id: 'kept');
      await remove(3, 'doomed');
      // The next launch, inside the warm cache window: the day is cached by
      // `init`, which deliberately does not read the tombstone row.
      await withClock(Clock.fixed(now), () async {
        await WaterService.resetForTesting();
        await WaterService.init();
      });
      expect(WaterService.getDataForDate(daysAgo(3))!.deletedLogIds, isEmpty,
          reason: 'premise: the cached day knows nothing of the deletion yet');

      await withClock(
          Clock.fixed(now), () => CloudSyncService().uploadDataToCloud('u1'));

      expect((await cloudDay(3))!['deletedLogIds'], ['doomed']);
    });

    test('skips a day with no drinks', () async {
      await drink(3, 250, id: 'only');
      await remove(3, 'only');

      await withClock(
          Clock.fixed(now), () => CloudSyncService().uploadDataToCloud('u1'));

      expect(await cloudDay(3), isNull,
          reason: 'an emptied day has nothing to restore');
    });
  });

  group('the sync window', () {
    test('is a week', () {
      expect(CloudSyncService.waterSyncDays, 7);
    });
  });
}
