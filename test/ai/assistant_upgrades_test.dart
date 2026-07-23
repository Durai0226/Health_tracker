import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/ai/ai_assistant.dart';
import 'package:tablet_remainder/core/ai/ai_types.dart';
import 'package:tablet_remainder/core/ai/llm_engine.dart';
import 'package:tablet_remainder/core/ai/memory_service.dart';
import 'package:tablet_remainder/core/ai/on_device_llm_engine.dart';
import 'package:tablet_remainder/core/ai/rag_service.dart';
import 'package:tablet_remainder/core/ai/safety_guard.dart';
import 'package:tablet_remainder/core/database/app_database.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/insights/services/assistant_service.dart';

/// A fake generative engine that records the system prompt it receives, so we
/// can assert what does (and doesn't) reach an LLM tier.
class _FakeEngine implements LlmEngine {
  _FakeEngine(this._id, this.captured);
  final String _id;
  final List<String> captured;
  @override
  String get id => _id;
  @override
  bool get isAvailable => true;
  @override
  Future<String?> completeText({
    required String system,
    required String user,
    double temperature = 0.3,
    int maxTokens = 512,
  }) async {
    captured.add(system);
    return 'A grounded answer.';
  }

  @override
  Future<Map<String, dynamic>?> completeJson({
    required String system,
    required String user,
    int maxTokens = 512,
  }) async =>
      null;
}

void main() {
  group('SafetyGuard — crisis vs medical emergency', () {
    test('self-harm routes to a CRISIS card with a helpline, not the generic card',
        () {
      final r =
          SafetyGuard.emergencyResponse('i want to kill myself', locale: 'en_us');
      expect(r, isNotNull);
      expect(r, contains('988')); // US crisis line
      expect(r!.toLowerCase(), contains('you matter'));
      expect(r, isNot(contains('medical emergency')));
    });

    test('chest pain stays a medical-emergency card (not the crisis card)', () {
      final r = SafetyGuard.emergencyResponse('i have crushing chest pain');
      expect(r, isNotNull);
      expect(r, contains('medical emergency'));
      expect(r, isNot(contains('988')));
    });

    test('a benign question is not flagged', () {
      expect(SafetyGuard.emergencyResponse('what is the follicular phase?'),
          isNull);
    });
  });

  group('AssistantService — RAG fallthrough + stemming (in-memory DB)', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      AppDatabase.setInstanceForTesting(db);
      CleanStorageService.resetForTesting();
      // Reset the shared AiAssistant slot to the inert on-device engine.
      AiAssistant().onDeviceEngine = OnDeviceLlmEngine();
      await AiAssistant().setPreference(AiEnginePreference.auto);
      await const MemoryService().setEnabled(true);

      final dao = db.aiDao;
      final now = DateTime.now();
      Future<void> add(String id, String topic, String title, String body) async {
        await dao.insertChunk(KnowledgeChunksCompanion.insert(
            id: id, topic: topic, title: title, body: body, createdAt: now));
        await dao.insertFts(id, title, body, topic);
      }

      await add('hydration_daily', 'hydration', 'How much water to drink',
          'A common guideline is roughly 2 to 3 litres of fluids a day for adults.');
      await add('hydration_overhydration', 'hydration', 'Can you drink too much?',
          'Drinking far more water than you need over a short time can dilute your body\'s salts.');
      await add('sleep_duration', 'sleep', 'How much sleep adults need',
          'Most adults do best with about 7 to 9 hours of sleep per night.');
      await add('steps_benefits', 'activity', 'Benefits of walking',
          'Regular walking supports heart health, mood, sleep and energy.');
    });

    tearDown(() async {
      await db.close();
    });

    test('a general question is answered from the KB, not empty own-data', () async {
      final r = await AssistantService.answer('how much water should I drink?');
      expect(r.sources, isNotEmpty,
          reason: 'general question should surface a KB citation');
      expect(r.topic, 'hydration');
    });

    test('title-boost ranking prefers the on-point chunk', () async {
      final hits =
          await const RagService().retrieve('how much water should I drink');
      expect(hits, isNotEmpty);
      expect(hits.first.title.toLowerCase(), contains('how much water'));
    });

    test('synonym expansion: "workout" retrieves an activity chunk', () async {
      final hits = await const RagService().retrieve('any good workout tips?');
      expect(hits, isNotEmpty);
      expect(hits.first.topic, 'activity');
    });

    test('porter stemming: "sleeping" still retrieves the sleep chunk', () async {
      final r =
          await AssistantService.answer('how many hours of sleeping do adults need?');
      expect(r.sources, isNotEmpty);
      expect(r.sources.first.title, contains('sleep'));
    });

    test('multi-turn: "why?" after a hydration answer stays on hydration', () async {
      final first = await AssistantService.answer('how much water should I drink?');
      expect(first.topic, 'hydration');
      final follow =
          await AssistantService.answer('why?', contextTopic: first.topic);
      expect(follow.sources, isNotEmpty);
      expect(follow.topic, 'hydration');
    });

    test('an out-of-scope question abstains (no citation)', () async {
      final r = await AssistantService.answer('who won the world cup final?');
      expect(r.sources, isEmpty);
    });
  });

  group('AiAssistant.groundedAnswer — memory never egresses to cloud', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      AppDatabase.setInstanceForTesting(db);
      CleanStorageService.resetForTesting();
      await const MemoryService().setEnabled(true);
      await const MemoryService().remember("I'm trying to conceive");
      final dao = db.aiDao;
      await dao.insertChunk(KnowledgeChunksCompanion.insert(
          id: 'sleep_duration',
          topic: 'sleep',
          title: 'How much sleep adults need',
          body: 'Most adults do best with about 7 to 9 hours of sleep per night.',
          createdAt: DateTime.now()));
      await dao.insertFts('sleep_duration', 'How much sleep adults need',
          'Most adults do best with about 7 to 9 hours of sleep per night.', 'sleep');
    });

    tearDown(() async {
      AiAssistant().onDeviceEngine = OnDeviceLlmEngine();
      await AiAssistant().setPreference(AiEnginePreference.auto);
      await db.close();
    });

    test('a CLOUD-id engine never receives the memory context', () async {
      final captured = <String>[];
      AiAssistant().onDeviceEngine = _FakeEngine('cloud', captured);
      await AiAssistant().setPreference(AiEnginePreference.onDevice);

      final g = await AiAssistant().groundedAnswer('how much sleep do adults need');
      expect(g, isNotNull);
      expect(captured, isNotEmpty);
      expect(captured.first, isNot(contains('trying to conceive')),
          reason: 'device-only memory must not be put in a cloud prompt');
    });

    test('an on-device engine DOES get the memory context (for grounding)', () async {
      final captured = <String>[];
      AiAssistant().onDeviceEngine = _FakeEngine('on_device', captured);
      await AiAssistant().setPreference(AiEnginePreference.onDevice);

      final g = await AiAssistant().groundedAnswer('how much sleep do adults need');
      expect(g, isNotNull);
      expect(captured, isNotEmpty);
      expect(captured.first, contains('trying to conceive'));
    });
  });
}
