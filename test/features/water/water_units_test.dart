/// Counting in ounces and pounds.
///
/// A unit is only how an amount is shown and how typed text is read: everything
/// stored stays millilitres and kilograms. So each test here ends on a STORED value
/// being the metric one, and on text being in the unit chosen.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/health/bottle_mode.dart';
import 'package:tablet_remainder/core/health/coach_text.dart';
import 'package:tablet_remainder/core/health/insight_engine.dart';
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/utils/units.dart';
import 'package:tablet_remainder/core/design/app_design.dart' show AppColorsExt;
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart' show AppButton, AppTextField;
import 'package:tablet_remainder/features/water/models/hydration_profile.dart';
import 'package:tablet_remainder/features/water/screens/aqua_water_dashboard.dart';
import 'package:tablet_remainder/features/water/screens/custom_cup_creator_screen.dart';
import 'package:tablet_remainder/features/water/screens/hydration_profile_screen.dart';
import 'package:tablet_remainder/features/water/screens/water_history_edit_screen.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';
import 'package:tablet_remainder/features/water/widgets/aqua_quick_add_grid.dart';
import 'package:tablet_remainder/features/water/widgets/bottle_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late db.AppDatabase database;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    WaterService.clearInMemory();
    await WaterService.resetForTesting();
  });

  tearDown(() async {
    Units.resetForTesting();
    await database.close();
  });

  Future<void> tall(WidgetTester tester, [double h = 4400]) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(400, h);
    addTearDown(tester.view.reset);
  }

  // ------------------------------------------------------------------ the words

  group('the sentences', () {
    const coach = CoachText();

    String tip({required int intake, required int goal, bool restricted = false,
            int hour = 15}) =>
        coach.hydrationTip(
            intakeMl: intake,
            goalMl: goal,
            streakDays: 0,
            hour: hour,
            isRestricted: restricted);

    test('millilitres read exactly as they always have', () {
      expect(tip(intake: 2500, goal: 2500), contains('Goal reached — 2500ml today!'));
      expect(tip(intake: 1800, goal: 1500, restricted: true),
          contains('You are 300ml over your 1500ml daily limit'));
    });

    test('ounces replace every amount, including the limit wording', () async {
      await Units.setVolume(VolumeUnit.flOz);

      final reached = tip(intake: 2500, goal: 2500);
      expect(reached, contains('84.5 fl oz today'));
      expect(reached, isNot(contains('ml')));

      final over = tip(intake: 1800, goal: 1500, restricted: true);
      expect(over, contains('10.1 fl oz over your 50.7 fl oz daily limit'));
      expect(over, isNot(contains('ml')));
    });

    test('the pace line carries the deficit and the suggested sip in ounces',
        () async {
      await Units.setVolume(VolumeUnit.flOz);

      final line = tip(intake: 200, goal: 2500, hour: 17);

      expect(line, contains('fl oz'));
      expect(line, isNot(contains('ml')));
    });

    test('a water insight names its amounts in the chosen unit', () async {
      final ml = InsightEngine.water(
          intakeMl: 600, goalMl: 2500, behind: true, deficitMl: 900)!;
      expect(ml.detail, contains('900ml'));
      expect(ml.metric, '900ml behind');

      await Units.setVolume(VolumeUnit.flOz);
      final oz = InsightEngine.water(
          intakeMl: 600, goalMl: 2500, behind: true, deficitMl: 900)!;
      expect(oz.detail, contains('30.4 fl oz'));
      expect(oz.metric, '30.4 fl oz behind');
    });
  });

  group('the bottle rule', () {
    test('accepts a whole number of ounces as well as every 50 ml', () {
      for (final oz in [7, 12, 16, 20, 24, 32, 64]) {
        final ml = (oz * Units.mlPerFlOz).round();
        expect(BottleMode.isValid(ml), isTrue, reason: '$oz oz = $ml ml');
      }
    });

    test('still refuses what is neither', () {
      expect(BottleMode.isValid(474), isFalse, reason: '16.03 oz');
      expect(BottleMode.isValid(725), isFalse);
      expect(BottleMode.isValid(177), isFalse, reason: 'six ounces is under the minimum');
      expect(BottleMode.isValid(2100), isFalse);
    });
  });

  // ------------------------------------------------------- the hydration profile

  group('the hydration profile', () {
    Future<void> open(WidgetTester tester, {HydrationProfile? profile}) async {
      await WaterService.init();
      if (profile != null) await WaterService.saveProfile(profile);
      await tall(tester);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const HydrationProfileScreen(),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    Finder field(String label) =>
        find.ancestor(of: find.text(label), matching: find.byType(TextField));

    Future<void> tapUnit(WidgetTester tester, String label) async {
      await tester.tap(find.text(label));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    final base = HydrationProfile(id: 'profile', createdAt: DateTime(2026, 9, 26));

    testWidgets('has a Units section, on millilitres and kilograms to begin with',
        (tester) async {
      await open(tester, profile: base);

      expect(find.text('Units'), findsOneWidget);
      expect(Units.volume, VolumeUnit.ml);
      expect(Units.weight, WeightUnit.kg);
    });

    testWidgets('choosing fl oz is kept, and the goal card shows ounces',
        (tester) async {
      await open(tester, profile: base);

      await tapUnit(tester, 'fl oz');

      expect(Units.volume, VolumeUnit.flOz);
      expect(find.textContaining('fl oz'), findsWidgets);
    });

    testWidgets('a daily limit typed in ounces is stored in millilitres',
        (tester) async {
      await open(tester, profile: base.copyWith(fluidCeilingMl: 1500));
      await tapUnit(tester, 'fl oz');

      expect(tester.widget<TextField>(field('Daily limit (fl oz)')).controller!.text,
          '50.7',
          reason: 'the same 1500 ml, in the unit now chosen');

      await tester.enterText(field('Daily limit (fl oz)'), '50');
      await tester.tap(find.text('Save Profile'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(WaterService.getProfile().fluidCeilingMl, (50 * Units.mlPerFlOz).round());
    });

    testWidgets('a weight typed in pounds is stored in kilograms', (tester) async {
      await open(tester, profile: base);
      await tapUnit(tester, 'lb');

      await tester.enterText(field('Weight (lb)'), '154.3');
      await tester.tap(find.text('Save Profile'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(WaterService.getProfile().weightKg, closeTo(69.99, 0.01));
    });

    testWidgets('switching weight units converts what is in the box, and back',
        (tester) async {
      await open(tester, profile: base.copyWith(weightKg: 82));
      expect(tester.widget<TextField>(field('Weight (kg)')).controller!.text, '82.0');

      await tapUnit(tester, 'lb');
      expect(tester.widget<TextField>(field('Weight (lb)')).controller!.text, '180.8');

      await tapUnit(tester, 'kg');
      expect(tester.widget<TextField>(field('Weight (kg)')).controller!.text, '82.0',
          reason: 'exactly what it was, not 82.0095 from the rounded pounds');
    });

    testWidgets('saving with the weight box untouched leaves the stored weight exactly',
        (tester) async {
      await open(tester, profile: base.copyWith(weightKg: 70));
      await tapUnit(tester, 'lb'); // the box reads 154.3, which is 69.99 kg

      await tester.tap(find.text('Save Profile'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(WaterService.getProfile().weightKg, 70.0,
          reason: 'a save that changed nothing must not walk the weight');
    });

    testWidgets('a weight out of range is refused in the unit it was typed in',
        (tester) async {
      await open(tester, profile: base);
      await tapUnit(tester, 'lb');

      await tester.enterText(field('Weight (lb)'), '10');
      await tester.tap(find.text('Save Profile'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('lb'), findsWidgets);
      expect(WaterService.getProfile().weightKg, isNull, reason: 'nothing saved');
    });

    testWidgets('a custom goal steps in whole ounces', (tester) async {
      await open(
          tester, profile: base.copyWith(useCustomGoal: true, customGoalMl: 2500));
      await tapUnit(tester, 'fl oz');

      await tester.tap(find.byTooltip('Increase goal by 8 fl oz'));
      await tester.pump();
      await tester.tap(find.text('Save Profile'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // 2500 ml is 84.5 oz, so 85 oz + 8 = 93 oz.
      expect(WaterService.getProfile().customGoalMl, (93 * Units.mlPerFlOz).round());
    });
  });

  // ------------------------------------------------------------- an entry's sheet

  group('the entry sheet', () {
    final day = DateTime(2026, 9, 26);

    Future<void> open(WidgetTester tester) async {
      await WaterService.init();
      await tall(tester, 2400);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: WaterEntrySheet(date: day, onSaved: () async {}),
          ),
        ),
      ));
      await tester.pump();
    }

    Finder amount(String label) => find.descendant(
        of: find.widgetWithText(AppTextField, label), matching: find.byType(TextField));

    Future<int> saved(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(AppButton, 'Add Entry'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final logs = (await WaterService.loadDataForDate(day))!.logs;
      return logs.single.amountMl;
    }

    testWidgets('millilitres, as before: typed, stored, labelled', (tester) async {
      await open(tester);
      expect(find.text('Amount (ml)'), findsOneWidget);

      await tester.enterText(amount('Amount (ml)'), '300');
      expect(await saved(tester), 300);
    });

    testWidgets('ounces: labelled, typed, stored as millilitres', (tester) async {
      await Units.setVolume(VolumeUnit.flOz);
      await open(tester);
      expect(find.text('Amount (fl oz)'), findsOneWidget);
      expect(tester.widget<TextField>(amount('Amount (fl oz)')).controller!.text, '8.5',
          reason: '250 ml, the default a new entry starts from, in ounces');

      await tester.enterText(amount('Amount (fl oz)'), '12');
      expect(await saved(tester), 355);
    });

    testWidgets('the one-tap amounts are round ounces', (tester) async {
      await Units.setVolume(VolumeUnit.flOz);
      await open(tester);

      expect(find.text('16 fl oz'), findsOneWidget);

      await tester.tap(find.text('16 fl oz'));
      await tester.pump();
      expect(tester.widget<TextField>(amount('Amount (fl oz)')).controller!.text, '16');
      expect(await saved(tester), 473);
    });

    testWidgets('changing only the drink still follows its default, in ounces too',
        (tester) async {
      await Units.setVolume(VolumeUnit.flOz);
      await open(tester);
      final coffee = WaterService.getBeverage('coffee')!;

      await tester.tap(find.text(coffee.name));
      await tester.pump();

      expect(tester.widget<TextField>(amount('Amount (fl oz)')).controller!.text,
          Units.volumeInput(coffee.defaultAmountMl),
          reason: 'an untouched amount follows the drink');
    });

    testWidgets('a typed amount is not overwritten when the drink changes',
        (tester) async {
      await Units.setVolume(VolumeUnit.flOz);
      await open(tester);
      await tester.enterText(amount('Amount (fl oz)'), '12');

      await tester.tap(find.text(WaterService.getBeverage('coffee')!.name));
      await tester.pump();

      expect(tester.widget<TextField>(amount('Amount (fl oz)')).controller!.text, '12');
    });

    testWidgets('a decimal ounce is accepted, with a comma too', (tester) async {
      await Units.setVolume(VolumeUnit.flOz);
      await open(tester);

      await tester.enterText(amount('Amount (fl oz)'), '8,5');
      expect(await saved(tester), 251);
    });
  });

  // ----------------------------------------------------------- quick add / amounts

  group('quick add', () {
    Future<int?> chooseCustom(WidgetTester tester,
        {Future<void> Function()? beforeConfirm}) async {
      int? got;
      await tall(tester, 1200);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => AquaCustomAmountDialog(
                    beverageId: 'water', onConfirm: (ml) => got = ml),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await beforeConfirm?.call();
      await tester.tap(find.textContaining('Add '));
      await tester.pumpAndSettle();
      return got;
    }

    testWidgets('millilitres: 250 to begin with, steps of 50', (tester) async {
      final got = await chooseCustom(tester, beforeConfirm: () async {
        await tester.tap(find.byTooltip('Increase by 50 ml'));
        await tester.pump();
      });
      expect(got, 300);
    });

    testWidgets('ounces: a glass to begin with, steps of one whole ounce',
        (tester) async {
      await Units.setVolume(VolumeUnit.flOz);
      final got = await chooseCustom(tester, beforeConfirm: () async {
        expect(find.text('8'), findsOneWidget);
        await tester.tap(find.byTooltip('Increase by 1 fl oz'));
        await tester.pump();
        expect(find.text('9'), findsOneWidget);
      });
      expect(got, (9 * Units.mlPerFlOz).round());
    });

    testWidgets('ounces: the preset chips are round ounce sizes', (tester) async {
      await Units.setVolume(VolumeUnit.flOz);
      int? got;
      await tall(tester, 1200);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
            body: AquaCustomAmountDialog(
                beverageId: 'water', onConfirm: (ml) => got = ml)),
      ));
      await tester.pump();

      expect(find.text('12 fl oz'), findsOneWidget);
      await tester.tap(find.text('12 fl oz'));
      await tester.pump();
      await tester.tap(find.textContaining('Add '));
      await tester.pump();

      expect(got, 355);
    });
  });

  // ------------------------------------------------------------------- the bottle

  group('the bottle sheet', () {
    Future<int?> run(WidgetTester tester, {int? initial, List<String> taps = const []}) async {
      int? result;
      await tall(tester, 1400);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async => result = await BottleSizeSheet.show(context,
                  accent: AppColorsExt.of(context).water, initialMl: initial),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      for (final t in taps) {
        await tester.tap(find.byTooltip(t));
        await tester.pump();
      }
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('millilitres: steps of 50 from what it was', (tester) async {
      expect(await run(tester, initial: 500, taps: ['Larger bottle']), 550);
    });

    testWidgets('ounces: opened and saved with no press, the bottle is as it was',
        (tester) async {
      await Units.setVolume(VolumeUnit.flOz);

      expect(await run(tester, initial: 500), 500,
          reason: 'showing 16.9 fl oz must not quietly make it 17');
    });

    testWidgets('ounces: a press moves to the next whole ounce', (tester) async {
      await Units.setVolume(VolumeUnit.flOz);

      final ml = await run(tester, initial: 500, taps: ['Larger bottle']);

      // 500 ml is 16.9 oz; one press up is 18 oz.
      expect(ml, (18 * Units.mlPerFlOz).round());
      expect(BottleMode.isValid(ml!), isTrue,
          reason: 'what the sheet saves must be a size the bottle rule accepts');
    });

    testWidgets('ounces: a dozen presses never leave a whole ounce', (tester) async {
      await Units.setVolume(VolumeUnit.flOz);

      final ml = await run(tester,
          initial: 500, taps: List.filled(12, 'Larger bottle'));

      expect(ml, (29 * Units.mlPerFlOz).round());
      expect(BottleMode.isValid(ml!), isTrue);
    });

    testWidgets('ounces: stops at the largest size, which is a valid one',
        (tester) async {
      await Units.setVolume(VolumeUnit.flOz);

      final ml = await run(tester,
          initial: 1900, taps: List.filled(10, 'Larger bottle'));

      expect(ml, lessThanOrEqualTo(BottleMode.maxBottleMl));
      expect(BottleMode.isValid(ml!), isTrue);
    });
  });

  // ---------------------------------------------------------------- a cup's size

  group('a cup', () {
    testWidgets('typed in ounces is stored as millilitres', (tester) async {
      await Units.setVolume(VolumeUnit.flOz);
      await WaterService.init();
      await tall(tester, 3000);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const CustomCupCreatorScreen(),
      ));
      await tester.pump();

      Finder box(String label) => find.descendant(
          of: find.widgetWithText(AppTextField, label),
          matching: find.byType(TextField));
      await tester.enterText(box('Cup name'), 'Zed cup');
      await tester.enterText(box('Capacity (fl oz)'), '12');
      await tester.tap(find.text('Create Cup'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final mug = WaterService.getAllContainers().firstWhere((c) => c.name == 'Zed cup');
      expect(mug.capacityMl, 355);
    });

    testWidgets('its preset sizes are round ounces', (tester) async {
      await Units.setVolume(VolumeUnit.flOz);
      await WaterService.init();
      await tall(tester, 3000);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const CustomCupCreatorScreen(),
      ));
      await tester.pump();

      expect(find.text('16 fl oz'), findsWidgets);
      expect(find.text('250ml'), findsNothing);
    });
  });

  // ---------------------------------------------- a screen already open underneath

  testWidgets('the water dashboard re-reads its amounts when the unit changes',
      (tester) async {
    await WaterService.init();
    await tall(tester, 1800);
    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    try {
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme, home: const AquaWaterDashboard()));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('ml'), findsWidgets, reason: 'the quick-add tiles say ml');

      await Units.setVolume(VolumeUnit.flOz);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('fl oz'), findsWidgets);
      expect(find.text('ml'), findsNothing);
    } finally {
      FlutterError.onError = prev;
    }
  });
}
