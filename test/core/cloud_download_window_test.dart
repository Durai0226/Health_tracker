import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/cloud_sync_service.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';

/// `downloadDataFromCloud` restored the user's THIRTY OLDEST days of water.
///
/// The read was `collection('water_intake').limit(30).get()` under a comment
/// promising "the last 30 days worth". Firestore with no `orderBy` sorts by
/// document id ascending, and these ids are `YYYY-MM-DD` — so for anyone with
/// more than a month of history the restore returned the beginning of their
/// history and stopped. The user sees a full-looking sync that contains none of
/// the days they actually care about, and no error anywhere.
///
/// Nothing about the resulting data reveals the bug (thirty days is thirty days
/// either way), so this asserts on *which* days landed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;
  late FakeFirebaseFirestore fs;
  final service = CloudSyncService();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    WaterService.clearInMemory();
    await WaterService.resetForTesting();
    await WaterService.init();

    fs = FakeFirebaseFirestore();
    service.firestoreForTesting = fs;
  });

  tearDown(() async {
    service.firestoreForTesting = null;
    await database.close();
  });

  /// 45 consecutive days ending 2026-02-14, written oldest-first so document
  /// creation order cannot be what makes the test pass.
  Future<List<String>> seedDays() async {
    final last = DateTime(2026, 2, 14);
    final keys = <String>[];
    for (var i = 44; i >= 0; i--) {
      final day = last.subtract(Duration(days: i));
      final key = WaterService.dateKeyFor(day);
      keys.add(key);
      await fs
          .collection('users')
          .doc('u1')
          .collection('water_intake')
          .doc(key)
          .set({
        'id': key,
        'date': day.toIso8601String(),
        'dailyGoalMl': 2500,
        'totalIntakeMl': 500,
        'effectiveHydrationMl': 500,
        'logs': const <Map<String, dynamic>>[],
      });
    }
    return keys;
  }

  test('restores the most recent 30 days, not the oldest 30', () async {
    final keys = await seedDays();

    await service.downloadDataFromCloud('u1');

    final restored = (await database.waterDao.getAllDailyData())
        .map((r) => r.id)
        .toSet();

    expect(restored.length, 30);
    expect(restored, keys.sublist(keys.length - 30).toSet(),
        reason: 'the newest 30 keys, in full');
    expect(restored, contains('2026-02-14'), reason: 'the most recent day');
    expect(restored, isNot(contains('2026-01-01')),
        reason: 'the oldest seeded day is outside a 30-day window');
  });

  test('a shorter history is restored whole', () async {
    for (final d in [DateTime(2026, 2, 12), DateTime(2026, 2, 13)]) {
      final key = WaterService.dateKeyFor(d);
      await fs
          .collection('users')
          .doc('u1')
          .collection('water_intake')
          .doc(key)
          .set({
        'id': key,
        'date': d.toIso8601String(),
        'dailyGoalMl': 2500,
        'totalIntakeMl': 250,
        'effectiveHydrationMl': 250,
        'logs': const <Map<String, dynamic>>[],
      });
    }

    await service.downloadDataFromCloud('u1');

    final restored = (await database.waterDao.getAllDailyData())
        .map((r) => r.id)
        .toSet();
    expect(restored, {'2026-02-12', '2026-02-13'});
  });
}
