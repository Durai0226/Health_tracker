import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/ai/rag_service.dart';

/// The FTS query builder is where abstention starts: a question with no content
/// word can't match anything, so it must yield a null query (→ abstain).
void main() {
  group('RagService.tokenize', () {
    test('drops stopwords and short tokens, lowercases', () {
      final t = RagService.tokenize('What is the Follicular phase?');
      expect(t, contains('follicular'));
      expect(t, contains('phase'));
      expect(t, isNot(contains('what')));
      expect(t, isNot(contains('is')));
      expect(t, isNot(contains('the')));
    });

    test('a question with only stopwords yields no tokens', () {
      expect(RagService.tokenize('what is it about?'), isEmpty);
    });
  });

  group('RagService.buildFtsQuery', () {
    test('builds a prefix-OR expression over content tokens', () {
      final q = RagService.buildFtsQuery('follicular phase');
      expect(q, isNotNull);
      expect(q, contains('follicular*'));
      expect(q, contains('phase*'));
      expect(q, contains(' OR '));
    });

    test('returns null when there is no usable content token → abstain', () {
      expect(RagService.buildFtsQuery('what is it?'), isNull);
      expect(RagService.buildFtsQuery('   '), isNull);
    });

    test('dedups repeated tokens', () {
      final q = RagService.buildFtsQuery('sleep sleep sleep');
      expect(q, 'sleep*');
    });
  });
}
