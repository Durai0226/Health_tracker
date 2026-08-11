import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/features/medication/models/weight_reading.dart';
import 'package:tablet_remainder/features/medication/models/mood_entry.dart';
import 'package:tablet_remainder/features/medication/services/vitals_storage_service.dart';

/// Tier 1: weight + mood tracking. Mirrors the BP/glucose coverage in
/// vitals_health_sync_test.dart (that file owns the Health-Connect-sync
/// specific cases) — this file covers plain CRUD, active-profile scoping,
/// model round-trips, and backup export/import for the two new trackers.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
  });

  tearDown(() async => db.close());

  WeightReading weight(String id, {double kg = 70, String? dependentId}) =>
      WeightReading(
        id: id,
        dependentId: dependentId,
        valueKg: kg,
        takenAt: DateTime(2026, 1, 1, 8),
        createdAt: DateTime(2026, 1, 1, 8),
      );

  MoodEntry mood(String id, {int index = 0, String? dependentId}) => MoodEntry(
        id: id,
        dependentId: dependentId,
        moodIndex: index,
        takenAt: DateTime(2026, 1, 1, 20),
        createdAt: DateTime(2026, 1, 1, 20),
      );

  group('WeightReading model', () {
    test('valueLb converts from the canonical kg', () {
      final r = weight('w', kg: 100);
      expect(r.valueLb, closeTo(220.46, 0.01));
    });

    test('toJson/fromJson round-trips every field', () {
      final r = WeightReading(
        id: 'w1',
        dependentId: 'dep1',
        valueKg: 68.5,
        takenAt: DateTime(2026, 2, 1, 7, 30),
        tags: const ['fasted'],
        note: 'after workout',
        createdAt: DateTime(2026, 2, 1, 7, 30),
      );
      final back = WeightReading.fromJson(r.toJson());
      expect(back.id, r.id);
      expect(back.dependentId, r.dependentId);
      expect(back.valueKg, r.valueKg);
      expect(back.takenAt, r.takenAt);
      expect(back.tags, r.tags);
      expect(back.note, r.note);
    });

    test('copyWith clearDependentId actually clears (not a no-op)', () {
      final r = weight('w', dependentId: 'dep1');
      final cleared = r.copyWith(clearDependentId: true);
      expect(cleared.dependentId, isNull);
    });
  });

  group('MoodEntry model', () {
    test('label matches moodRatingLabels at the same index', () {
      expect(mood('m', index: 0).label, 'Great');
      expect(mood('m', index: 4).label, 'Terrible');
    });

    test('toJson/fromJson round-trips every field', () {
      final e = MoodEntry(
        id: 'm1',
        dependentId: 'dep1',
        moodIndex: 3,
        takenAt: DateTime(2026, 2, 1, 20),
        tags: const ['stressed'],
        note: 'long day',
        createdAt: DateTime(2026, 2, 1, 20),
      );
      final back = MoodEntry.fromJson(e.toJson());
      expect(back.id, e.id);
      expect(back.moodIndex, e.moodIndex);
      expect(back.note, e.note);
      expect(back.tags, e.tags);
    });

    test('fromJson clamps an out-of-range moodIndex instead of throwing', () {
      final back = MoodEntry.fromJson({
        'id': 'm2',
        'moodIndex': 99,
        'takenAt': DateTime(2026, 1, 1).toIso8601String(),
      });
      expect(back.moodIndex, 4);
    });
  });

  group('VitalsStorageService.saveWeight / getAllWeight', () {
    test('a saved reading round-trips through storage', () async {
      await VitalsStorageService.saveWeight(weight('w1'), stampActiveProfile: false);
      final all = await VitalsStorageService.getAllWeight(scopeToActiveProfile: false);
      expect(all.map((r) => r.id), contains('w1'));
      expect(all.first.valueKg, 70);
    });

    test('editing a reading (same id) updates rather than duplicates', () async {
      await VitalsStorageService.saveWeight(weight('w1', kg: 70),
          stampActiveProfile: false);
      await VitalsStorageService.saveWeight(weight('w1', kg: 72),
          stampActiveProfile: false);
      final all = await VitalsStorageService.getAllWeight(scopeToActiveProfile: false);
      expect(all.where((r) => r.id == 'w1'), hasLength(1));
      expect(all.first.valueKg, 72);
    });

    test('deleteWeight removes the reading', () async {
      await VitalsStorageService.saveWeight(weight('w1'), stampActiveProfile: false);
      await VitalsStorageService.deleteWeight('w1');
      final all = await VitalsStorageService.getAllWeight(scopeToActiveProfile: false);
      expect(all.map((r) => r.id), isNot(contains('w1')));
    });

    test('active-profile scoping hides another profile\'s readings', () async {
      await VitalsStorageService.saveWeight(weight('self', dependentId: null),
          stampActiveProfile: false);
      await VitalsStorageService.saveWeight(weight('dep', dependentId: 'dep1'),
          stampActiveProfile: false);

      // Default active profile is self (null).
      final selfView = await VitalsStorageService.getAllWeight();
      expect(selfView.map((r) => r.id), contains('self'));
      expect(selfView.map((r) => r.id), isNot(contains('dep')));

      await ActiveProfileService().setActiveDependent('dep1');
      final depView = await VitalsStorageService.getAllWeight();
      expect(depView.map((r) => r.id), contains('dep'));
      expect(depView.map((r) => r.id), isNot(contains('self')));
    });
  });

  group('VitalsStorageService.saveMood / getAllMood', () {
    test('a saved entry round-trips through storage', () async {
      await VitalsStorageService.saveMood(mood('m1'), stampActiveProfile: false);
      final all = await VitalsStorageService.getAllMood(scopeToActiveProfile: false);
      expect(all.map((r) => r.id), contains('m1'));
      expect(all.first.moodIndex, 0);
    });

    test('deleteMood removes the entry', () async {
      await VitalsStorageService.saveMood(mood('m1'), stampActiveProfile: false);
      await VitalsStorageService.deleteMood('m1');
      final all = await VitalsStorageService.getAllMood(scopeToActiveProfile: false);
      expect(all.map((r) => r.id), isNot(contains('m1')));
    });

    test('active-profile scoping hides another profile\'s entries', () async {
      await VitalsStorageService.saveMood(mood('self', dependentId: null),
          stampActiveProfile: false);
      await VitalsStorageService.saveMood(mood('dep', dependentId: 'dep1'),
          stampActiveProfile: false);

      final selfView = await VitalsStorageService.getAllMood();
      expect(selfView.map((r) => r.id), contains('self'));
      expect(selfView.map((r) => r.id), isNot(contains('dep')));
    });
  });

  group('backup export/import', () {
    test('exportJson includes weight and mood sections', () async {
      await VitalsStorageService.saveWeight(weight('w1'), stampActiveProfile: false);
      await VitalsStorageService.saveMood(mood('m1'), stampActiveProfile: false);
      final json = await VitalsStorageService.exportJson();
      expect(json['weight'], isA<List>());
      expect(json['mood'], isA<List>());
      expect((json['weight'] as List).any((e) => e['id'] == 'w1'), isTrue);
      expect((json['mood'] as List).any((e) => e['id'] == 'm1'), isTrue);
    });

    test('importJson restores weight and mood without disturbing existing data',
        () async {
      await VitalsStorageService.saveWeight(weight('existing'),
          stampActiveProfile: false);
      await VitalsStorageService.importJson({
        'weight': [weight('restored-w').toJson()],
        'mood': [mood('restored-m').toJson()],
      });
      final weights =
          await VitalsStorageService.getAllWeight(scopeToActiveProfile: false);
      final moods = await VitalsStorageService.getAllMood(scopeToActiveProfile: false);
      expect(weights.map((r) => r.id), containsAll(['existing', 'restored-w']));
      expect(moods.map((r) => r.id), contains('restored-m'));
    });

    test('a malformed entry in the backup is skipped, not thrown', () async {
      await VitalsStorageService.importJson({
        'weight': [
          {'id': 'bad'} // missing required fields
        ],
      });
      final weights =
          await VitalsStorageService.getAllWeight(scopeToActiveProfile: false);
      expect(weights.map((r) => r.id), isNot(contains('bad')));
    });
  });
}
