import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Privacy mechanism #1, enforced as a test: the deterministic on-device AI
/// path (RAG retrieval, memory, the rule engine, the KB seeder, the safety
/// guard, and the AI DAO) must NEVER import a networking library. The ONLY
/// networked AI tier is the consent-gated cloud engine, which is deliberately
/// excluded from this list. If this test fails, a network dependency leaked
/// into the private answer path.
void main() {
  const answerPathFiles = <String>[
    'lib/core/ai/rag_service.dart',
    'lib/core/ai/memory_service.dart',
    'lib/core/ai/knowledge_base.dart',
    'lib/core/ai/rule_based_engine.dart',
    'lib/core/ai/safety_guard.dart',
    'lib/core/database/daos/ai_dao.dart',
    'lib/core/database/tables/knowledge_tables.dart',
    'lib/core/database/tables/memory_tables.dart',
  ];

  // Import fragments that mean "this can talk to the network".
  final banned = RegExp(
    r'''import\s+['"](?:package:(?:http|dio|http2|grpc|web_socket_channel|firebase_[^'"]+|cloud_firestore)[^'"]*|dart:io)['"]''',
  );

  test('deterministic AI answer path imports no networking library', () {
    final offenders = <String>[];
    for (final path in answerPathFiles) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: 'missing $path');
      final src = file.readAsStringSync();
      for (final line in src.split('\n')) {
        if (banned.hasMatch(line)) offenders.add('$path → ${line.trim()}');
      }
    }
    expect(offenders, isEmpty,
        reason: 'Network import leaked into the private AI path:\n'
            '${offenders.join('\n')}');
  });
}
