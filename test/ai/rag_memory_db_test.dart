import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/ai/memory_service.dart';
import 'package:tablet_remainder/core/ai/rag_service.dart';
import 'package:tablet_remainder/core/database/app_database.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';

/// End-to-end over an in-memory Drift DB (incl. the FTS5 index): retrieval
/// grounds/abstains correctly, and memory dedups + supersedes + forgets.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting(); // re-bind to this in-memory DB
    await const MemoryService().setEnabled(true); // deterministic default

    final dao = db.aiDao;
    final now = DateTime.now();
    Future<void> add(String id, String topic, String title, String body) async {
      await dao.insertChunk(KnowledgeChunksCompanion.insert(
          id: id, topic: topic, title: title, body: body, createdAt: now));
      await dao.insertFts(id, title, body, topic);
    }

    await add('cycle_follicular', 'cycle', 'Follicular phase',
        'The follicular phase starts on the first day of your period and lasts until ovulation.');
    await add('sleep_duration', 'sleep', 'How much sleep adults need',
        'Most adults do best with about 7 to 9 hours of sleep per night.');
    await add('hydration_daily', 'hydration', 'How much water to drink',
        'A common guideline is roughly 2 to 3 litres of fluids a day for adults.');
  });

  tearDown(() async {
    await db.close();
  });

  group('RagService.retrieve', () {
    test('relevant question returns the matching topic chunk', () async {
      final hits =
          await const RagService().retrieve('what is the follicular phase?');
      expect(hits, isNotEmpty);
      expect(hits.first.topic, 'cycle');
      expect(hits.first.title, 'Follicular phase');
    });

    test('a different topic retrieves its own chunk', () async {
      final hits = await const RagService().retrieve('how many hours of sleep?');
      expect(hits, isNotEmpty);
      expect(hits.first.topic, 'sleep');
    });

    test('irrelevant question abstains (empty)', () async {
      final hits = await const RagService().retrieve('who won the world cup?');
      expect(hits, isEmpty);
    });

    test('no content tokens abstains', () async {
      expect(await const RagService().retrieve('what is it?'), isEmpty);
    });
  });

  group('MemoryService', () {
    test('remember stores, and dedups case-insensitively', () async {
      const m = MemoryService();
      final a = await m.remember("I'm trying to conceive");
      expect(a, isNotNull);
      final b = await m.remember("i'm trying to conceive");
      expect(b!.id, a!.id); // same row — not a duplicate
      expect((await m.active()).length, 1);
    });

    test('a new goal supersedes the prior goal', () async {
      const m = MemoryService();
      await m.remember('5000 steps', kind: MemoryService.kKindGoal);
      await m.remember('8000 steps', kind: MemoryService.kKindGoal);
      final goals = (await m.active())
          .where((x) => x.kind == MemoryService.kKindGoal)
          .toList();
      expect(goals.length, 1);
      expect(goals.first.content, '8000 steps');
    });

    test('forgetByText removes the matching note', () async {
      const m = MemoryService();
      await m.remember('I take vitamin D');
      expect(await m.forgetByText('vitamin d'), ForgetResult.removed);
      expect(await m.active(), isEmpty);
    });

    test('forgetByText is ambiguity-safe (multiple matches → ask, no delete)',
        () async {
      const m = MemoryService();
      await m.remember('8000 steps', kind: MemoryService.kKindGoal);
      await m.remember('I count my steps every morning');
      // "steps" matches both → must NOT silently delete either.
      expect(await m.forgetByText('steps'), ForgetResult.ambiguous);
      expect((await m.active()).length, 2);
    });

    test('forgetByText returns notFound when nothing matches', () async {
      const m = MemoryService();
      await m.remember('I prefer evening reminders');
      expect(await m.forgetByText('blood pressure'), ForgetResult.notFound);
    });

    test('disabled → no writes and no reads', () async {
      const m = MemoryService();
      await m.setEnabled(false);
      expect(await m.remember('should not save'), isNull);
      expect(await m.active(), isEmpty);
      await m.setEnabled(true);
    });

    test('contextBlock recaps active memories', () async {
      const m = MemoryService();
      await m.remember('I prefer evening reminders',
          kind: MemoryService.kKindPreference);
      final block = await m.contextBlock();
      expect(block, isNotNull);
      expect(block, contains('evening reminders'));
    });
  });
}
