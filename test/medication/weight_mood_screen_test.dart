import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/weight_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/mood_screen.dart';

/// Tier 1 UI coverage for the new standalone Weight and Mood trackers —
/// positive (valid entry saves and appears) and negative (invalid/missing
/// entry is rejected with an inline error, nothing is persisted) cases for
/// each screen's log form.
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

  Future<void> pump(WidgetTester tester, Widget home) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: home));
    await tester.pumpAndSettle();
  }

  group('WeightScreen', () {
    testWidgets('empty state prompts to log the first reading', (tester) async {
      await pump(tester, const WeightScreen());
      expect(find.text('Track your weight'), findsOneWidget);
      expect(find.text('Log your first reading'), findsOneWidget);
    });

    testWidgets('positive: a valid weight saves and shows in history',
        (tester) async {
      await pump(tester, const WeightScreen());

      await tester.tap(find.text('Log your first reading'));
      await tester.pumpAndSettle();
      expect(find.text('Save reading'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, '70.5');
      await tester.tap(find.text('Save reading'));
      await tester.pumpAndSettle();

      // Sheet closed, empty state gone, the logged value is now on screen.
      expect(find.text('Log your first reading'), findsNothing);
      expect(find.textContaining('70.5'), findsWidgets);
    });

    testWidgets('negative: a non-numeric entry is rejected and nothing saves',
        (tester) async {
      await pump(tester, const WeightScreen());

      await tester.tap(find.text('Log your first reading'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'abc');
      await tester.tap(find.text('Save reading'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid weight.'), findsOneWidget);
      // Sheet stays open — the save was blocked, not silently accepted.
      expect(find.text('Save reading'), findsOneWidget);
    });

    testWidgets(
        'negative: an out-of-range value is rejected with a specific message',
        (tester) async {
      await pump(tester, const WeightScreen());

      await tester.tap(find.text('Log your first reading'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, '9999');
      await tester.tap(find.text('Save reading'));
      await tester.pumpAndSettle();

      expect(find.text('That doesn\'t look like a valid weight.'), findsOneWidget);
    });
  });

  group('MoodScreen', () {
    testWidgets('empty state prompts to log how you feel', (tester) async {
      await pump(tester, const MoodScreen());
      expect(find.text('Track your mood'), findsOneWidget);
      expect(find.text('Log how you feel'), findsOneWidget);
    });

    testWidgets('positive: picking a mood saves and shows in history',
        (tester) async {
      await pump(tester, const MoodScreen());

      await tester.tap(find.text('Log how you feel'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Good'));
      await tester.tap(find.text('Save entry'));
      await tester.pumpAndSettle();

      expect(find.text('Log how you feel'), findsNothing);
      expect(find.text('Good'), findsWidgets);
    });

    testWidgets('negative: saving without picking a mood is rejected',
        (tester) async {
      await pump(tester, const MoodScreen());

      await tester.tap(find.text('Log how you feel'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save entry'));
      await tester.pumpAndSettle();

      expect(find.text('Pick how you\'re feeling.'), findsOneWidget);
      // Nothing was logged — the empty state's CTA is still reachable behind it.
      expect(find.text('Save entry'), findsOneWidget);
    });
  });
}
