import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/features/diary/models/diary_entry.dart';
import 'package:tablet_remainder/features/diary/services/diary_storage_service.dart';

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

  DiaryEntry entry(String id, {String? title, String body = 'hello', String? dependentId}) =>
      DiaryEntry(
        id: id,
        dependentId: dependentId,
        title: title,
        body: body,
        entryAt: DateTime(2026, 1, 1, 20),
        createdAt: DateTime(2026, 1, 1, 20),
      );

  group('DiaryEntry model', () {
    test('displayTitle prefers the title when set', () {
      expect(entry('a', title: 'My title').displayTitle, 'My title');
    });

    test('displayTitle falls back to the first non-empty body line', () {
      final e = entry('a', body: '\n\n  First real line  \nsecond');
      expect(e.displayTitle, 'First real line');
    });

    test('displayTitle falls back to a placeholder for an all-blank body', () {
      final e = entry('a', body: '   \n   ');
      expect(e.displayTitle, 'Untitled entry');
    });

    test('toJson/fromJson round-trips every field', () {
      final e = DiaryEntry(
        id: 'd1',
        dependentId: 'dep1',
        title: 'Trip notes',
        body: 'Line one\nLine two',
        entryAt: DateTime(2026, 3, 1, 9),
        createdAt: DateTime(2026, 3, 1, 9),
      );
      final back = DiaryEntry.fromJson(e.toJson());
      expect(back.id, e.id);
      expect(back.dependentId, e.dependentId);
      expect(back.title, e.title);
      expect(back.body, e.body);
      expect(back.entryAt, e.entryAt);
    });

    test('copyWith clearTitle/clearDependentId actually clear (not a no-op)', () {
      final e = entry('a', title: 'x', dependentId: 'dep1');
      final cleared = e.copyWith(clearTitle: true, clearDependentId: true);
      expect(cleared.title, isNull);
      expect(cleared.dependentId, isNull);
    });
  });

  group('DiaryStorageService', () {
    test('positive: a saved entry round-trips through storage', () async {
      await DiaryStorageService.save(entry('d1'), stampActiveProfile: false);
      final all = await DiaryStorageService.getAll(scopeToActiveProfile: false);
      expect(all.map((e) => e.id), contains('d1'));
    });

    test('editing an entry (same id) updates rather than duplicates', () async {
      await DiaryStorageService.save(entry('d1', body: 'first'),
          stampActiveProfile: false);
      await DiaryStorageService.save(entry('d1', body: 'second'),
          stampActiveProfile: false);
      final all = await DiaryStorageService.getAll(scopeToActiveProfile: false);
      expect(all.where((e) => e.id == 'd1'), hasLength(1));
      expect(all.first.body, 'second');
    });

    test('delete removes the entry', () async {
      await DiaryStorageService.save(entry('d1'), stampActiveProfile: false);
      await DiaryStorageService.delete('d1');
      final all = await DiaryStorageService.getAll(scopeToActiveProfile: false);
      expect(all.map((e) => e.id), isNot(contains('d1')));
    });

    test('negative: active-profile scoping hides another profile\'s entries', () async {
      await DiaryStorageService.save(entry('self', dependentId: null),
          stampActiveProfile: false);
      await DiaryStorageService.save(entry('dep', dependentId: 'dep1'),
          stampActiveProfile: false);

      final selfView = await DiaryStorageService.getAll();
      expect(selfView.map((e) => e.id), contains('self'));
      expect(selfView.map((e) => e.id), isNot(contains('dep')));
    });

    test('exportJson / importJson round-trip, and skip malformed entries', () async {
      await DiaryStorageService.save(entry('d1'), stampActiveProfile: false);
      final exported = await DiaryStorageService.exportJson();
      expect(exported.any((e) => e['id'] == 'd1'), isTrue);

      await DiaryStorageService.importJson([
        entry('restored').toJson(),
        {'id': 'bad'}, // missing required fields — must be skipped, not thrown
      ]);
      final all = await DiaryStorageService.getAll(scopeToActiveProfile: false);
      expect(all.map((e) => e.id), containsAll(['d1', 'restored']));
      expect(all.map((e) => e.id), isNot(contains('bad')));
    });
  });
}
