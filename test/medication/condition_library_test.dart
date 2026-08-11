import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/medication/data/condition_library_data.dart';
import 'package:tablet_remainder/features/medication/screens/conditions/condition_library_screen.dart';
import 'package:tablet_remainder/features/medication/screens/conditions/condition_detail_screen.dart';

/// Tier 1: condition-resource library. Dataset integrity + the search filter's
/// positive/negative behavior, plus a UI smoke test for both screens.
void main() {
  group('conditionLibrary dataset integrity', () {
    test('every entry has a unique, non-empty id', () {
      final ids = conditionLibrary.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'duplicate id found');
      expect(ids.every((id) => id.trim().isNotEmpty), isTrue);
    });

    test('every entry has non-empty overview, symptoms, tips, and red flags', () {
      for (final c in conditionLibrary) {
        expect(c.overview.trim(), isNotEmpty, reason: '${c.id} overview');
        expect(c.commonSymptoms, isNotEmpty, reason: '${c.id} commonSymptoms');
        expect(c.selfCareTips, isNotEmpty, reason: '${c.id} selfCareTips');
        expect(c.whenToSeekHelp, isNotEmpty, reason: '${c.id} whenToSeekHelp');
      }
    });

    test('covers more than one category (not a single-topic list)', () {
      expect(conditionLibrary.map((c) => c.category).toSet().length, greaterThan(1));
    });
  });

  group('ConditionInfo.matches', () {
    test('positive: an empty query matches everything', () {
      final c = conditionLibrary.first;
      expect(c.matches(''), isTrue);
    });

    test('positive: matches by name substring (already lowercased)', () {
      final c = conditionLibrary.firstWhere((c) => c.id == 'hypertension');
      expect(c.matches('blood pressure'), isTrue);
    });

    test('positive: matches by alias', () {
      final c = conditionLibrary.firstWhere((c) => c.id == 'asthma');
      expect(c.matches('wheezing'), isTrue);
    });

    test('negative: an unrelated query does not match', () {
      final c = conditionLibrary.firstWhere((c) => c.id == 'asthma');
      expect(c.matches('kidney'), isFalse);
    });
  });

  group('ConditionLibraryScreen', () {
    testWidgets('lists conditions and filters by search (positive + negative)',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ConditionLibraryScreen(),
      ));
      await tester.pumpAndSettle();

      // Positive: at least one known condition is visible unfiltered.
      expect(find.textContaining('High blood pressure'), findsOneWidget);

      // Positive filter: a matching search narrows the list to that entry.
      await tester.enterText(find.byType(TextFormField), 'asthma');
      await tester.pumpAndSettle();
      expect(find.textContaining('Asthma'), findsOneWidget);
      expect(find.textContaining('High blood pressure'), findsNothing);

      // Negative filter: a query matching nothing shows the empty state.
      await tester.enterText(find.byType(TextFormField), 'zzzznotarealcondition');
      await tester.pumpAndSettle();
      expect(find.textContaining('No conditions match'), findsOneWidget);
    });
  });

  group('ConditionDetailScreen', () {
    testWidgets('renders overview, symptoms, tips, and red flags', (tester) async {
      final condition = conditionLibrary.firstWhere((c) => c.id == 'asthma');
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: ConditionDetailScreen(condition: condition),
      ));
      await tester.pumpAndSettle();

      expect(find.text(condition.name), findsOneWidget);
      expect(find.text(condition.overview), findsOneWidget);
      for (final s in condition.commonSymptoms) {
        expect(find.text(s), findsOneWidget);
      }

      // "When to seek help" is further down the list — scroll it into the
      // built extent before asserting (a plain find would otherwise fail on
      // content that's off the initial viewport, not because it's missing).
      for (final t in condition.whenToSeekHelp) {
        await tester.scrollUntilVisible(find.text(t), 300,
            scrollable: find.byType(Scrollable));
        expect(find.text(t), findsOneWidget);
      }
    });
  });
}
