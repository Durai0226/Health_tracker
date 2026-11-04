/// Drinks the person makes: made from the drinks strip, listed by use, and
/// edited or deleted the same way a cup is.
///
/// `WaterService.addCustomBeverage` and the table behind it existed, and so did
/// the favourites ranking; no screen reached either. A drink the catalogue did
/// not list was logged as water or as the nearest thing.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart' show AppSwitch;
import 'package:tablet_remainder/features/water/models/beverage_type.dart';
import 'package:tablet_remainder/features/water/models/custom_drink.dart';
import 'package:tablet_remainder/features/water/screens/aqua_water_dashboard.dart';
import 'package:tablet_remainder/features/water/screens/custom_drink_screen.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';
import 'package:tablet_remainder/features/water/theme/aqua_theme.dart';
import 'package:tablet_remainder/features/water/widgets/aqua_beverage_sheet.dart';
import 'package:tablet_remainder/features/water/widgets/aqua_quick_add_grid.dart';
import 'package:tablet_remainder/features/water/widgets/water_hero_gauge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late db.AppDatabase database;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    WaterService.clearInMemory();
    await WaterService.resetForTesting();
    await WaterService.init();
  });

  tearDown(() async {
    await WaterService.resetForTesting();
    await database.close();
  });

  final shake = CustomDrink.build(
      id: 'custom_protein_shake',
      name: 'Protein shake',
      colorHex: '#4CAF50',
      countsAsPercent: 75,
      caffeineMg: 0);

  Future<void> pumpFor(WidgetTester tester, [int n = 6]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> openDashboard(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 2400);
    addTearDown(tester.view.reset);
    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    try {
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme, home: const AquaWaterDashboard()));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 400));
    } finally {
      FlutterError.onError = prev;
    }
  }

  Future<void> showStrip(WidgetTester tester, Finder f) =>
      tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);

  /// By the label the chip announces, without turning semantics on for the test.
  Finder labelled(String label) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == label);
  Finder drinkChip(String name) => labelled('$name, select beverage');
  final newDrink = labelled('Create new drink');

  /// The drink the quick-add block has selected.
  String selected(WidgetTester tester) =>
      tester.widget<AquaQuickAddGrid>(find.byType(AquaQuickAddGrid)).selectedBeverageId;

  group('on the drinks strip', () {
    testWidgets('a drink the person made is there, and says what it is', (tester) async {
      await WaterService.addCustomBeverage(shake);
      await openDashboard(tester);
      await showStrip(tester, find.text('Protein shake'));

      expect(find.text('Protein shake'), findsOneWidget,
          reason: 'an unselected chip is only an icon, which for their own drinks '
              'would make every one of them the same chip');
    });

    testWidgets('a catalogue drink that is not selected shows no name, as before',
        (tester) async {
      await openDashboard(tester);
      final other = BeverageType.defaultBeverages[3];
      expect(find.text(other.name), findsNothing);
    });

    testWidgets('the "+" leads the strip and opens the creator', (tester) async {
      await openDashboard(tester);
      expect(newDrink, findsOneWidget, reason: 'first, not twenty chips along');
      expect(tester.getTopLeft(newDrink).dx,
          lessThan(tester.getTopLeft(drinkChip(BeverageType.defaultBeverages.first.name)).dx));

      await tester.tap(newDrink);
      await pumpFor(tester, 10);

      expect(find.byType(CustomDrinkScreen), findsOneWidget);
      expect(tester.widget<CustomDrinkScreen>(find.byType(CustomDrinkScreen)).existing,
          isNull);
    });

    testWidgets('a drink saved from the creator is selected on return', (tester) async {
      await openDashboard(tester);
      await tester.tap(newDrink);
      await pumpFor(tester, 10);

      await tester.enterText(find.byType(TextField).first, 'Protein shake');
      await tester.tap(find.text('Add Drink'));
      await pumpFor(tester, 12);

      expect(WaterService.getBeverage('custom_protein_shake'), isNotNull);
      expect(find.byType(CustomDrinkScreen), findsNothing, reason: 'it closed');
      expect(selected(tester), 'custom_protein_shake',
          reason: 'they made it to log it, so it is the one ready to log');
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('logging a drink while the screen is open does not move the chips',
        (tester) async {
      await openDashboard(tester);
      final ids = BeverageType.defaultBeverages.map((b) => b.id).toList();
      // Chips that are on screen at the start: the third, and the one before it.
      final third = WaterService.getBeverage(ids[2])!;
      final second = WaterService.getBeverage(ids[1])!;
      final before = tester.getTopLeft(drinkChip(third.name)).dx;
      expect(before, greaterThan(tester.getTopLeft(drinkChip(second.name)).dx),
          reason: 'premise: the catalogue\'s own order');

      for (var i = 0; i < 4; i++) {
        await WaterService.addWaterLog(amountMl: 100, beverage: third);
      }
      await tester.pump(const Duration(milliseconds: 300));
      await pumpFor(tester, 3);

      expect(tester.getTopLeft(drinkChip(third.name)).dx, before,
          reason: 'ranking on every build would put it first, moving the chip under a '
              'thumb that is about to tap it');
    });

    testWidgets('a drink made while it is open is on the strip at once', (tester) async {
      await openDashboard(tester);
      await WaterService.addCustomBeverage(shake);
      await tester.pump(const Duration(milliseconds: 300));
      await pumpFor(tester, 3);

      await showStrip(tester, find.text('Protein shake'));
      expect(find.text('Protein shake'), findsOneWidget);
    });

    testWidgets('the drink logged most is first on the strip', (tester) async {
      final ids = BeverageType.defaultBeverages.map((b) => b.id).toList();
      final late = WaterService.getBeverage(ids[5])!;
      for (var i = 0; i < 3; i++) {
        await WaterService.addWaterLog(amountMl: 100, beverage: late);
      }
      await openDashboard(tester);

      final lateChip = drinkChip(late.name);
      final first = drinkChip(BeverageType.defaultBeverages.first.name);
      expect(lateChip, findsOneWidget);
      expect(first, findsOneWidget);
      expect(tester.getTopLeft(lateChip).dx, lessThan(tester.getTopLeft(first).dx),
          reason: 'it was sixth in the catalogue; three logs put it ahead of the first');
    });
  });

  group('in the full picker', () {
    Future<List<String>> pick(WidgetTester tester, {required bool canCreate}) async {
      final picked = <String>[];
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 2400);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: AquaBeverageSheet(
              selectedBeverageId: 'water',
              onSelect: picked.add,
              canCreate: canCreate,
            ),
          ),
        ),
      ));
      await pumpFor(tester, 2);
      return picked;
    }

    testWidgets('ends with a "New drink" tile that asks to make one', (tester) async {
      final picked = await pick(tester, canCreate: true);

      await tester.tap(find.text('New drink'));

      expect(picked, [AquaBeverageSheet.createNew]);
    });

    testWidgets('a caller that does not offer it does not show it', (tester) async {
      await pick(tester, canCreate: false);
      expect(find.text('New drink'), findsNothing);
    });

    testWidgets('lists their own drinks, and the ones they log most first',
        (tester) async {
      await WaterService.addCustomBeverage(shake);
      final late = WaterService.getBeverage(BeverageType.defaultBeverages[5].id)!;
      for (var i = 0; i < 3; i++) {
        await WaterService.addWaterLog(amountMl: 100, beverage: late);
      }
      await pick(tester, canCreate: false);

      final names = [
        for (final t in tester.widgetList<Text>(find.byType(Text)).map((t) => t.data))
          if (t != null) t
      ];
      expect(names, contains('Protein shake'));
      expect(names.indexOf(late.name), lessThan(names.indexOf('Protein shake')));
      expect(names.indexOf('Protein shake'),
          lessThan(names.indexOf(BeverageType.defaultBeverages.first.name)),
          reason: 'a drink made is ahead of the catalogue drinks nobody has logged');
    });
  });

  group('from the dashboard\'s own picker', () {
    testWidgets('tapping the gauge opens the full picker, and "New drink" opens the creator',
        (tester) async {
      await openDashboard(tester);

      await tester.tap(find.byType(WaterHeroGauge));
      await pumpFor(tester, 8);
      expect(find.text('Select Beverage'), findsOneWidget);

      await tester.tap(find.text('New drink'));
      await pumpFor(tester, 10);

      expect(find.byType(CustomDrinkScreen), findsOneWidget);
    });
  });

  test('a drink the person made has its own glyph, not water\'s drop', () {
    final water = AquaTheme.iconFor('water');
    expect(AquaTheme.iconFor('custom_protein_shake'), isNot(water));
    expect(AquaTheme.iconFor('custom_anything'), AquaTheme.iconFor('custom_other'));
    expect(AquaTheme.iconFor('kombucha'), isNot(water),
        reason: 'one made before ids carried a prefix is theirs too: what makes it '
            'theirs is that the catalogue does not have it');
  });

  test('the catalogue\'s own drinks keep the glyphs they had', () {
    final custom = AquaTheme.iconFor('custom_anything');
    for (final b in BeverageType.defaultBeverages) {
      expect(AquaTheme.iconFor(b.id), isNot(custom), reason: b.id);
    }
    expect(AquaTheme.iconFor('sparkling_water'), AquaTheme.iconFor('water'));
  });

  group('editing and deleting one of their own', () {
    testWidgets('a long press offers Edit and Delete', (tester) async {
      await WaterService.addCustomBeverage(shake);
      await openDashboard(tester);
      await showStrip(tester, find.text('Protein shake'));

      await tester.longPress(find.text('Protein shake'));
      await pumpFor(tester);

      expect(find.text('Edit drink'), findsOneWidget);
      expect(find.text('Delete drink'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('Delete removes it, and Undo brings it back', (tester) async {
      await WaterService.addCustomBeverage(shake);
      await openDashboard(tester);
      await showStrip(tester, find.text('Protein shake'));

      await tester.longPress(find.text('Protein shake'));
      await pumpFor(tester);
      await tester.tap(find.text('Delete drink'));
      await pumpFor(tester, 8);

      expect(WaterService.getBeverage('custom_protein_shake'), isNull);
      expect(find.text('Deleted Protein shake'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await pumpFor(tester, 8);

      expect(WaterService.getBeverage('custom_protein_shake'), isNotNull);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('deleting the drink that is selected falls back to water', (tester) async {
      await WaterService.addCustomBeverage(shake);
      await openDashboard(tester);
      await showStrip(tester, find.text('Protein shake'));
      await tester.tap(find.text('Protein shake'));
      await pumpFor(tester, 3);
      expect(selected(tester), 'custom_protein_shake', reason: 'premise');

      await tester.longPress(find.text('Protein shake'));
      await pumpFor(tester);
      await tester.tap(find.text('Delete drink'));
      await pumpFor(tester, 8);

      expect(selected(tester), 'water',
          reason: 'not left on an id that no longer exists');
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('Undo does not overwrite a drink made since with the same name', (tester) async {
      await WaterService.addCustomBeverage(shake);
      await openDashboard(tester);
      await showStrip(tester, find.text('Protein shake'));
      await tester.longPress(find.text('Protein shake'));
      await pumpFor(tester);
      await tester.tap(find.text('Delete drink'));
      await pumpFor(tester, 8);
      expect(find.text('Undo'), findsOneWidget, reason: 'premise');

      // Meanwhile the person makes a different drink with the same name.
      await WaterService.addCustomBeverage(CustomDrink.build(
          id: 'custom_protein_shake_new',
          name: 'Protein shake',
          colorHex: '#2196F3',
          countsAsPercent: 50));
      await tester.tap(find.text('Undo'));
      await pumpFor(tester, 8);

      expect(WaterService.getCustomBeverages().length, 1,
          reason: 'not two of the same name');
      expect(WaterService.getBeverage('custom_protein_shake_new')!.hydrationPercent, 50,
          reason: 'and the newer one is not overwritten');
      expect(WaterService.getBeverage('custom_protein_shake'), isNull);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('says so when a delete could not be made, and the drink stays',
        (tester) async {
      await WaterService.addCustomBeverage(shake);
      await openDashboard(tester);
      await showStrip(tester, find.text('Protein shake'));
      await tester.longPress(find.text('Protein shake'));
      await pumpFor(tester);
      await database.close();

      await tester.tap(find.text('Delete drink'));
      await pumpFor(tester, 8);

      expect(find.text('Could not delete the drink. Try again.'), findsOneWidget);
      expect(WaterService.getBeverage('custom_protein_shake'), isNotNull);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('Edit opens the creator on that drink, with its name filled in',
        (tester) async {
      await WaterService.addCustomBeverage(shake);
      await openDashboard(tester);
      await showStrip(tester, find.text('Protein shake'));

      await tester.longPress(find.text('Protein shake'));
      await pumpFor(tester);
      await tester.tap(find.text('Edit drink'));
      await pumpFor(tester, 10);

      final screen =
          tester.widget<CustomDrinkScreen>(find.byType(CustomDrinkScreen));
      expect(screen.existing?.id, 'custom_protein_shake');
      expect(find.widgetWithText(TextField, 'Protein shake'), findsOneWidget);
      expect(find.text('Edit Drink'), findsOneWidget);
    });

    testWidgets('a drink made before ids carried a prefix is still theirs to edit',
        (tester) async {
      await WaterService.addCustomBeverage(
          BeverageType(id: 'kombucha', name: 'Kombucha', emoji: '🫙'));
      await openDashboard(tester);
      await showStrip(tester, find.text('Kombucha'));

      await tester.longPress(find.text('Kombucha'));
      await pumpFor(tester);

      expect(find.text('Edit drink'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('a catalogue drink offers neither', (tester) async {
      await openDashboard(tester);
      final name = BeverageType.defaultBeverages.first.name;

      await tester.longPress(drinkChip(name));
      await pumpFor(tester);

      expect(find.text('Edit drink'), findsNothing);
      expect(find.text('Delete drink'), findsNothing);
    });

    testWidgets('a screen reader reaches the same actions on their own drinks only',
        (tester) async {
      await WaterService.addCustomBeverage(shake);
      await openDashboard(tester);

      final withAction = find.byWidgetPredicate((w) =>
          w is Semantics &&
          (w.properties.customSemanticsActions?.keys
                  .any((a) => a.label == 'Edit or delete drink') ??
              false));
      expect(withAction, findsOneWidget,
          reason: 'the one made drink has it; the catalogue ones do not');
    });
  });

  group('the usual-drink tile', () {
    Future<void> seedHabit(String id, int ml, Iterable<int> days) async {
      final now = DateTime.now();
      for (final d in days) {
        final at = DateTime(now.year, now.month, now.day - d, now.hour, now.minute);
        await WaterService.addWaterLogForDate(
            date: at, amountMl: ml, beverage: WaterService.getBeverage(id)!, time: at);
      }
    }

    testWidgets('a drink that was deleted is no longer offered as the usual one',
        (tester) async {
      await WaterService.addCustomBeverage(shake);
      await seedHabit('custom_protein_shake', 200, [1, 2, 3, 4]);
      await openDashboard(tester);
      expect(find.text('Protein shake · 200 ml'), findsOneWidget, reason: 'premise');

      await showStrip(tester, find.text('Protein shake').last);
      await tester.longPress(find.text('Protein shake').last);
      await pumpFor(tester);
      await tester.tap(find.text('Delete drink'));
      await pumpFor(tester, 8);

      expect(find.text('Protein shake · 200 ml'), findsNothing,
          reason: 'tapping it would log a drink that no longer resolves');
      expect(find.text('Your usual'), findsNothing);
      await tester.pump(const Duration(seconds: 8));
    });
  });

  group('the creator', () {
    Future<void> openCreator(WidgetTester tester, {BeverageType? existing}) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 2400);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme, home: CustomDrinkScreen(existing: existing)));
      await pumpFor(tester, 3);
    }

    Future<void> save(WidgetTester tester) async {
      await tester.tap(find.text(
          find.text('Save Changes').evaluate().isNotEmpty ? 'Save Changes' : 'Add Drink'));
      await pumpFor(tester, 8);
    }

    testWidgets('asks for a name rather than saving a nameless drink', (tester) async {
      await openCreator(tester);

      await save(tester);

      expect(find.text('Give the drink a name'), findsOneWidget);
      expect(WaterService.getCustomBeverages(), isEmpty);
    });

    testWidgets('refuses a name that is already a drink, whatever the case', (tester) async {
      await openCreator(tester);
      await tester.enterText(
          find.byType(TextField).first, BeverageType.defaultBeverages.first.name.toUpperCase());

      await save(tester);

      expect(find.textContaining('You already have a drink called'), findsOneWidget);
      expect(WaterService.getCustomBeverages(), isEmpty);
    });

    testWidgets('the message clears as soon as the name is touched', (tester) async {
      await openCreator(tester);
      await save(tester);
      expect(find.text('Give the drink a name'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'P');
      await tester.pump();

      expect(find.text('Give the drink a name'), findsNothing);
    });

    testWidgets('saves what the form says: how much it counts, and its caffeine',
        (tester) async {
      await openCreator(tester);
      await tester.enterText(find.byType(TextField).first, 'Oat latte');
      await tester.tap(find.text('75%'));
      await tester.pump();
      await tester.tap(find.byType(AppSwitch));
      await tester.pump();
      await tester.tap(find.text('Strong'));
      await tester.pump();

      await save(tester);

      final b = WaterService.getBeverage('custom_oat_latte')!;
      expect((b.name, b.hydrationPercent, b.hasCaffeine, b.caffeinePerMl),
          ('Oat latte', 75, true, 80));
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('a drink with the caffeine switch off carries none', (tester) async {
      await openCreator(tester);
      await tester.enterText(find.byType(TextField).first, 'Plain');

      await save(tester);

      final b = WaterService.getBeverage('custom_plain')!;
      expect((b.hasCaffeine, b.caffeinePerMl), (false, 0));
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('editing keeps the id, may keep the same name, and changes the rest',
        (tester) async {
      await WaterService.addCustomBeverage(shake);
      await openCreator(tester, existing: shake);

      await tester.tap(find.text('In full'));
      await tester.pump();
      await save(tester);

      expect(WaterService.getCustomBeverages().length, 1);
      final b = WaterService.getBeverage('custom_protein_shake')!;
      expect((b.name, b.hydrationPercent), ('Protein shake', 100),
          reason: 'its own name is not a clash with itself');
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('an existing strength that is not one of the steps is kept', (tester) async {
      final odd = CustomDrink.build(
          id: 'custom_odd', name: 'Odd', colorHex: '#4CAF50', caffeineMg: 55);
      await WaterService.addCustomBeverage(odd);
      await openCreator(tester, existing: odd);

      expect(find.text('55 mg'), findsOneWidget, reason: 'shown, not snapped to a step');
      await save(tester);

      expect(WaterService.getBeverage('custom_odd')!.caffeinePerMl, 55);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('a name whose id a deleted drink still has logs under gets another id',
        (tester) async {
      await WaterService.addCustomBeverage(shake);
      await WaterService.addWaterLog(
          amountMl: 200, beverage: WaterService.getBeverage('custom_protein_shake')!);
      await WaterService.deleteBeverage('custom_protein_shake');
      await openCreator(tester);

      await tester.enterText(find.byType(TextField).first, 'Protein shake');
      await save(tester);

      expect(WaterService.getBeverage('custom_protein_shake'), isNull,
          reason: 'its logs are the old drink\'s, and must stay so');
      expect(WaterService.getBeverage('custom_protein_shake_2'), isNotNull);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('says so, and stays, when the drink could not be saved', (tester) async {
      await openCreator(tester);
      await tester.enterText(find.byType(TextField).first, 'Doomed');
      await database.close();

      await save(tester);

      expect(find.text('Could not save the drink. Try again.'), findsOneWidget);
      expect(find.byType(CustomDrinkScreen), findsOneWidget, reason: 'nothing was lost');
      expect(WaterService.getCustomBeverages(), isEmpty);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('an older drink opens with its own percentage and colour chosen, and saves them unchanged',
        (tester) async {
      final legacy = BeverageType(
        id: 'kombucha',
        name: 'Kombucha',
        emoji: '🫙',
        hydrationPercent: 80,
        colorHex: '#123456',
        defaultAmountMl: 330,
      );
      await WaterService.addCustomBeverage(legacy);
      await openCreator(tester, existing: legacy);

      expect(find.text('80%'), findsOneWidget, reason: 'its own value is on offer');
      final selectedSwatch = find.byWidgetPredicate((w) =>
          w is Semantics &&
          w.properties.selected == true &&
          (w.properties.label ?? '').startsWith('Color '));
      expect(selectedSwatch, findsOneWidget,
          reason: 'its own colour is a swatch, and the chosen one — the form does not '
              'look as if none were picked');
      await save(tester);

      final b = WaterService.getBeverage('kombucha')!;
      expect((b.hydrationPercent, b.emoji, b.defaultAmountMl), (80, '🫙', 330),
          reason: 'opened and saved, it is the same drink');
      expect(b.colorHex.toLowerCase(), '#123456');
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('the original value stays on offer after another is picked', (tester) async {
      final legacy = BeverageType(
          id: 'kombucha', name: 'Kombucha', emoji: '🫙', hydrationPercent: 80);
      await WaterService.addCustomBeverage(legacy);
      await openCreator(tester, existing: legacy);

      await tester.tap(find.text('50%'));
      await tester.pump();

      expect(find.text('80%'), findsOneWidget, reason: 'so the person can go back to it');
    });

    testWidgets('the colour swatches are told apart by a screen reader', (tester) async {
      await openCreator(tester);
      final labels = [
        for (final w in tester.widgetList<Semantics>(find.byWidgetPredicate(
            (w) => w is Semantics && (w.properties.label ?? '').startsWith('Color '))))
          w.properties.label
      ];
      expect(labels.length, greaterThan(5));
      expect(labels.toSet().length, labels.length, reason: 'twelve "Color"s are one label');
    });

    testWidgets('closing without saving leaves nothing behind', (tester) async {
      await openCreator(tester);
      await tester.enterText(find.byType(TextField).first, 'Never saved');
      await tester.tap(find.byIcon(Symbols.close_rounded).first);
      await pumpFor(tester, 3);

      expect(WaterService.getCustomBeverages(), isEmpty);
    });
  });
}
