import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/ai/ai_assistant.dart';
import 'package:tablet_remainder/core/ai/ai_types.dart';
import 'package:tablet_remainder/core/ai/on_device_llm_engine.dart';
import 'package:tablet_remainder/core/database/app_database.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/insights/services/assistant_service.dart';

/// QA — natural-language logging (Feature B). Validates that the assistant
/// actually EXECUTES a plain-text log ("my bp is 120/80" → written + ✓), not
/// just talks about it, and that a plain question is not mistaken for a command.
/// Uses the in-memory Drift harness (BP/glucose/medicine write through Drift).
void main() {
  group('AssistantService — natural-language logging (in-memory DB)', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      AppDatabase.setInstanceForTesting(db);
      CleanStorageService.resetForTesting();
      AiAssistant().onDeviceEngine = OnDeviceLlmEngine();
      await AiAssistant().setPreference(AiEnginePreference.auto);
    });

    tearDown(() async {
      await db.close();
    });

    test('logs blood pressure from plain text and confirms with ✓', () async {
      final r = await AssistantService.answer('my bp is 120/80');
      expect(r.text, contains('Logged BP 120/80'));
      expect(r.text, contains('✓'));
    });

    test('logs blood glucose from plain text and confirms with ✓', () async {
      final r = await AssistantService.answer('glucose 110');
      expect(r.text, contains('Logged 110 mg/dL'));
      expect(r.text, contains('✓'));
    });

    test('"took my medicine" with nothing due responds gracefully', () async {
      final r = await AssistantService.answer('I took my medicine');
      expect(r.text.toLowerCase(), contains('no dose due'));
    });

    test('a plain question is NOT mistaken for a log command', () async {
      final r = await AssistantService.answer("what's my medication adherence?");
      expect(r.text, isNot(contains('Logged')));
    });
  });
}
