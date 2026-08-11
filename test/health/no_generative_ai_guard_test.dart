import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The standing proof that the generative AI stays removed.
///
/// It was deleted because it irritated users: an "Ask AI" chat and a set of
/// "Fill with AI" buttons that, on any build where no engine could connect, were
/// running hand-written regex and template strings. Every deterministic feature
/// was kept — statistics, streaks, vitals classification, the coach tips, the
/// typed quick-fill and the offline drug monographs. What went was the generative
/// tier, its provider plumbing, and all the AI branding.
///
/// This test fails if any of that starts creeping back, because the failure mode
/// is gradual: one SDK dependency, one "Ask AI" label, one sparkle at a time.
void main() {
  final libFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
      .toList();

  String read(File f) => f.readAsStringSync();

  group('no generative AI dependency', () {
    test('pubspec declares no LLM SDK', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final pkg in [
        'firebase_ai',
        'firebase_vertexai',
        'google_generative_ai',
        'flutter_gemma',
        'langchain',
        'dart_openai',
        'anthropic',
        'ollama',
      ]) {
        expect(pubspec.contains('$pkg:'), isFalse,
            reason: 'pubspec.yaml pulls in $pkg');
      }
    });

    test('no source file imports an LLM SDK', () {
      for (final f in libFiles) {
        final s = read(f);
        for (final pkg in [
          'package:firebase_ai/',
          'package:google_generative_ai/',
          'package:flutter_gemma/',
          'package:langchain/',
        ]) {
          expect(s.contains(pkg), isFalse, reason: '${f.path} imports $pkg');
        }
      }
    });

    test('no provider endpoint or model id is hardcoded', () {
      for (final f in libFiles) {
        final s = read(f).toLowerCase();
        for (final needle in [
          'api.groq.com',
          'generativelanguage.googleapis.com',
          'api.openai.com',
          'integrate.api.nvidia.com',
          ':11434', // Ollama
          'gemini-',
          'gpt-4',
          'llama-3',
          'chat/completions',
        ]) {
          expect(s.contains(needle), isFalse,
              reason: '${f.path} references $needle');
        }
      }
    });
  });

  group('no AI surfaces or branding', () {
    test('the deleted files stay deleted', () {
      for (final path in [
        'lib/core/ai',
        'lib/core/services/llm_service.dart',
        'lib/core/ai/ai_assistant.dart',
        'lib/core/widgets/app/ai_widgets.dart',
        'lib/core/widgets/app/ai_insight_kit.dart',
        'lib/features/insights/screens/assistant_screen.dart',
        'lib/features/insights/screens/insights_hub_screen.dart',
        'lib/features/insights/services/assistant_service.dart',
        'lib/features/settings/screens/ai_engine_screen.dart',
        'lib/core/database/daos/ai_dao.dart',
      ]) {
        expect(FileSystemEntity.typeSync(path), FileSystemEntityType.notFound,
            reason: '$path is back');
      }
    });

    test('no user-facing string advertises AI', () {
      // Matches a standalone "AI" inside a quoted Dart string.
      final aiInString = RegExp(r"""['"][^'"]*\bAI\b[^'"]*['"]""");
      final offenders = <String>[];
      for (final f in libFiles) {
        for (final line in read(f).split('\n')) {
          final code = line.trim();
          if (code.startsWith('//') || code.startsWith('///')) continue;
          if (aiInString.hasMatch(code)) offenders.add('${f.path}: $code');
        }
      }
      expect(offenders, isEmpty,
          reason: 'these claim AI to the user:\n${offenders.join('\n')}');
    });

    test('the sparkle hallmark is gone', () {
      for (final f in libFiles) {
        final s = read(f);
        for (final sym in ['AiSeal', 'kAiSparkle', 'EngineBadge', 'AiLabels']) {
          expect(s.contains(sym), isFalse, reason: '${f.path} uses $sym');
        }
      }
    });

    test('nothing is named after AI any more', () {
      for (final f in libFiles) {
        final name = f.uri.pathSegments.last;
        expect(name.startsWith('ai_') || name.contains('_ai_'), isFalse,
            reason: '${f.path} is still AI-named');
      }
      expect(Directory('lib/core/health').existsSync(), isTrue,
          reason: 'the analyzers should live in lib/core/health/');
    });
  });

  group('the deterministic features survived', () {
    test('every analyzer is present in lib/core/health/', () {
      for (final n in [
        'vitals_analyzer',
        'insight',
        'insight_engine',
        'vitals_pattern_detector',
        'adherence_analyzer',
        'streak_engine',
        'hydration_pacer',
        'focus_insights',
        'refill_predictor',
        'adaptive_timing',
        'med_safety_checker',
        'nudge_scheduler',
        'safety_guard',
        'drug_info_catalog',
        'coach_text',
        'health_types',
      ]) {
        expect(File('lib/core/health/$n.dart').existsSync(), isTrue,
            reason: 'lib/core/health/$n.dart is missing — a feature just broke');
      }
    });

    test('the kept UI surfaces are still wired', () {
      expect(File('lib/core/widgets/app/tip_card.dart').existsSync(), isTrue);
      expect(File('lib/core/widgets/app/insight_kit.dart').existsSync(), isTrue);
      final barrel =
          File('lib/core/widgets/app/app_widgets.dart').readAsStringSync();
      expect(barrel, contains("export 'tip_card.dart';"));
      expect(barrel, contains("export 'insight_kit.dart';"));
    });

    test('the offline drug monographs are still bundled', () {
      expect(File('assets/health/drug_info.json').existsSync(), isTrue);
      expect(File('pubspec.yaml').readAsStringSync(),
          contains('assets/health/'));
    });

    test('App Check survives — it gates Firestore, not just the old AI', () {
      // Deleting this would silently break cloud sync on an enforced project.
      expect(File('lib/core/services/app_check_service.dart').existsSync(),
          isTrue);
      expect(File('lib/main.dart').readAsStringSync(),
          contains('AppCheckService.activate()'));
    });
  });
}
