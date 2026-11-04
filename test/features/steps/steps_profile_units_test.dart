/// The steps profile's weight, in the unit the person counts in.
///
/// Stored kilograms are what every calorie figure is computed from, so the tests
/// end on the STORED value: a weight typed in pounds must arrive as kilograms, and
/// one stored in kilograms must come back to the box as the pounds it is.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/utils/units.dart';
import 'package:tablet_remainder/features/steps/models/health_profile.dart';
import 'package:tablet_remainder/features/steps/screens/steps_goal_settings_screen.dart';
import 'package:tablet_remainder/features/steps/services/step_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late db.AppDatabase database;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    await StepService.resetForTesting();
  });

  tearDown(() async {
    Units.resetForTesting();
    await database.close();
  });

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

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save'));
    await tester.pump(const Duration(milliseconds: 350));
  }

  Finder weightBox() => find.byType(TextFormField).first;
  String weightText(WidgetTester tester) =>
      tester.widget<TextFormField>(weightBox()).controller!.text;

  group('in kilograms', () {
    testWidgets('the label and the stored value are as they always were',
        (tester) async {
      await pump(tester);
      expect(find.text('Weight (kg)'), findsOneWidget);

      await tester.enterText(weightBox(), '70');
      await save(tester);

      expect(StepService.getProfile().weightKg, 70.0);
    });

    testWidgets('a comma is a decimal point', (tester) async {
      await pump(tester);

      await tester.enterText(weightBox(), '70,5');
      await save(tester);

      expect(StepService.getProfile().weightKg, 70.5);
    });
  });

  group('in pounds', () {
    setUp(() => Units.setWeight(WeightUnit.lb));

    testWidgets('the label names the unit', (tester) async {
      await pump(tester);

      expect(find.text('Weight (lb)'), findsOneWidget);
      expect(find.text('Weight (kg)'), findsNothing);
    });

    testWidgets('a weight typed in pounds is stored as kilograms', (tester) async {
      await pump(tester);

      await tester.enterText(weightBox(), '154');
      await save(tester);

      expect(StepService.getProfile().weightKg, closeTo(69.85, 0.01),
          reason: 'not 154 kg, which every calorie figure would believe');
    });

    testWidgets('a stored weight comes back as the pounds it is', (tester) async {
      await StepService.saveProfile(const HealthProfile(weightKg: 70));

      await pump(tester);

      expect(weightText(tester), '154.3');
    });

    testWidgets('and saving it again without a change does not move it',
        (tester) async {
      await StepService.saveProfile(const HealthProfile(weightKg: 70));
      await pump(tester);

      await save(tester);

      expect(StepService.getProfile().weightKg, 70.0,
          reason: 'the box shows 154.3 lb, which reads back as 69.99 kg — a save '
              'that changed nothing must not walk the weight');
    });

    testWidgets('a comma is a decimal point', (tester) async {
      await pump(tester);

      await tester.enterText(weightBox(), '154,3');
      await save(tester);

      expect(StepService.getProfile().weightKg, closeTo(69.99, 0.01));
    });

    testWidgets('a weight out of range is refused in pounds, not kilograms',
        (tester) async {
      await pump(tester);

      await tester.enterText(weightBox(), '10');
      await save(tester);

      expect(find.textContaining('Enter a weight between 44.1 and 881.8 lb'),
          findsOneWidget);
      expect(find.textContaining('kg'), findsNothing);
      expect(StepService.getProfile().weightKg, isNull);
    });

    testWidgets('text that is not a number is refused in pounds', (tester) async {
      await pump(tester);

      await tester.enterText(weightBox(), 'heavy');
      await save(tester);

      expect(find.textContaining('lb.'), findsOneWidget);
      expect(StepService.getProfile().weightKg, isNull);
    });

    testWidgets('emptied, it is removed', (tester) async {
      await StepService.saveProfile(const HealthProfile(weightKg: 70));
      await pump(tester);

      await tester.enterText(weightBox(), '');
      await save(tester);

      expect(StepService.getProfile().weightKg, isNull);
    });
  });
}
