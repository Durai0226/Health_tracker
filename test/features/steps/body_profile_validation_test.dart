/// SS-13 — the steps body profile accepted nonsense.
///
/// `_save()` did `weightKg: double.tryParse(text), heightCm: int.tryParse(text)`
/// with no range check, no formatter and no validator, so `-5`, `0`, `3` and
/// `5000` all persisted. Those two numbers are not cosmetic: height becomes
/// every distance the app reports (`HealthProfile.strideMeters`) and weight
/// becomes every active-calorie figure (`deriveActiveCalories`), so a typo
/// comes back to the user as a confident health number rather than as an
/// error.
///
/// The fix is a message, not a clamp — silently turning a typed `5` into `20`
/// would show a value the user never entered and never say why.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/steps/models/health_profile.dart';
import 'package:tablet_remainder/features/steps/screens/steps_goal_settings_screen.dart';
import 'package:tablet_remainder/features/steps/services/step_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('HealthProfile.validateWeightText', () {
    test('accepts a plausible weight', () {
      expect(HealthProfile.validateWeightText('70'), isNull);
      expect(HealthProfile.validateWeightText('62.5'), isNull);
    });

    test('empty means "not set", which is allowed', () {
      expect(HealthProfile.validateWeightText(''), isNull);
      expect(HealthProfile.validateWeightText('   '), isNull);
    });

    test('rejects zero and negatives', () {
      expect(HealthProfile.validateWeightText('0'), isNotNull);
      expect(HealthProfile.validateWeightText('-5'), isNotNull);
    });

    test('rejects an absurd weight', () {
      expect(HealthProfile.validateWeightText('5000'), isNotNull);
    });

    test('rejects text that is not a number', () {
      expect(HealthProfile.validateWeightText('heavy'), isNotNull);
    });

    /// `double.tryParse` returns a real value for both of these, so a plain
    /// null check would have let them through — and `steps * NaN * 0.0005`
    /// renders as "NaN kcal" rather than failing anywhere a log would show it.
    test('rejects NaN and Infinity, which double.tryParse accepts', () {
      expect(double.tryParse('NaN')?.isNaN, isTrue,
          reason: 'guard premise: tryParse really does accept this');
      expect(HealthProfile.validateWeightText('NaN'), isNotNull);
      expect(HealthProfile.validateWeightText('Infinity'), isNotNull);
    });

    test('the message names the bounds rather than just saying "invalid"', () {
      final msg = HealthProfile.validateWeightText('5000')!;
      expect(msg, contains('${HealthProfile.minWeightKg.toInt()}'));
      expect(msg, contains('${HealthProfile.maxWeightKg.toInt()}'));
    });
  });

  group('HealthProfile.validateHeightText', () {
    test('accepts a plausible height', () {
      expect(HealthProfile.validateHeightText('172'), isNull);
    });

    test('empty means "not set", which is allowed', () {
      expect(HealthProfile.validateHeightText(''), isNull);
    });

    test('rejects the 3 cm height that would give a 1.2 cm stride', () {
      expect(HealthProfile.validateHeightText('3'), isNotNull);
      // The number the old code would have produced, for the record.
      expect(const HealthProfile(heightCm: 3).strideMeters,
          closeTo(0.01245, 0.00001));
    });

    test('rejects zero, negatives and absurd heights', () {
      expect(HealthProfile.validateHeightText('0'), isNotNull);
      expect(HealthProfile.validateHeightText('-170'), isNotNull);
      expect(HealthProfile.validateHeightText('900'), isNotNull);
    });

    test('rejects text that is not a whole number', () {
      expect(HealthProfile.validateHeightText('tall'), isNotNull);
    });
  });

  group('Goal & profile screen', () {
    late db.AppDatabase database;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      database = db.AppDatabase.forTesting(NativeDatabase.memory());
      db.AppDatabase.setInstanceForTesting(database);
      CleanStorageService.resetForTesting();
      await CleanStorageService.init();
      await StepService.resetForTesting();
    });

    tearDown(() async => database.close());

    Future<void> pump(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(430, 1600);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const StepsGoalSettingsScreen(),
      ));
      await tester.pump(const Duration(milliseconds: 350));
    }

    Finder weightField() => find.ancestor(
          of: find.text('Weight (kg)'),
          matching: find.byType(Column),
        );

    testWidgets('a negative weight is refused and never reaches the profile',
        (tester) async {
      await pump(tester);

      await tester.enterText(find.byType(TextFormField).first, '-5');
      await tester.tap(find.text('Save'));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.textContaining('Weight must be between'), findsOneWidget,
          reason: 'the user has to be told why the save did not happen');
      expect(StepService.getProfile().weightKg, isNot(-5.0));
      expect(StepService.getProfile().weightKg, isNull);
      // Still on the editor — a refused save must not pop.
      expect(find.text('Goal & profile'), findsOneWidget);
      expect(weightField(), findsWidgets);
    });

    testWidgets('an absurd height is refused and never reaches the profile',
        (tester) async {
      await pump(tester);

      await tester.enterText(find.byType(TextFormField).at(1), '3');
      await tester.tap(find.text('Save'));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.textContaining('Height must be between'), findsOneWidget);
      expect(StepService.getProfile().heightCm, isNull);
    });

    testWidgets('a sound profile still saves', (tester) async {
      await pump(tester);

      await tester.enterText(find.byType(TextFormField).first, '70');
      await tester.enterText(find.byType(TextFormField).at(1), '172');
      await tester.tap(find.text('Save'));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.textContaining('must be between'), findsNothing);
      expect(StepService.getProfile().weightKg, 70.0);
      expect(StepService.getProfile().heightCm, 172);
    });

    testWidgets('editing the field clears the message instead of arguing',
        (tester) async {
      await pump(tester);

      await tester.enterText(find.byType(TextFormField).first, '-5');
      await tester.tap(find.text('Save'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.textContaining('Weight must be between'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, '7');
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.textContaining('Weight must be between'), findsNothing,
          reason: 'typing "70" passes through "7"; the message must not '
              'flash back while the user is still typing');
    });
  });
}
