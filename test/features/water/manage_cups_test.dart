/// Cups the person made can be edited and deleted.
///
/// The creator already took an existing cup and the service already deleted one;
/// the cups row only offered "New Cup". So a cup made with a typo in its name or
/// the wrong size stayed that way for good.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/water/models/water_container.dart';
import 'package:tablet_remainder/features/water/screens/aqua_water_dashboard.dart';
import 'package:tablet_remainder/features/water/screens/custom_cup_creator_screen.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';

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

  tearDown(() async => database.close());

  final flask = WaterContainer(
      id: 'flask', name: 'Flask', emoji: '🥛', capacityMl: 777);

  Future<void> open(WidgetTester tester) async {
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

  Future<void> pumpFor(WidgetTester tester, [int n = 6]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Finder chip(String label) => find.text(label).first;

  testWidgets('a cup the person made is on the row', (tester) async {
    await WaterService.addCustomContainer(flask);
    await open(tester);
    await tester.scrollUntilVisible(chip('777ml'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(chip('777ml'), findsOneWidget);
  });

  testWidgets('a long press offers Edit and Delete', (tester) async {
    await WaterService.addCustomContainer(flask);
    await open(tester);
    await tester.scrollUntilVisible(chip('777ml'), 200,
        scrollable: find.byType(Scrollable).first);

    await tester.longPress(chip('777ml'));
    await pumpFor(tester);

    expect(find.text('Edit cup'), findsOneWidget);
    expect(find.text('Delete cup'), findsOneWidget);
    expect(find.text('🥛 Flask'), findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('Delete removes it, and Undo brings it back', (tester) async {
    await WaterService.addCustomContainer(flask);
    await open(tester);
    await tester.scrollUntilVisible(chip('777ml'), 200,
        scrollable: find.byType(Scrollable).first);

    await tester.longPress(chip('777ml'));
    await pumpFor(tester);
    await tester.tap(find.text('Delete cup'));
    await pumpFor(tester, 8);

    expect(WaterService.getAllContainers().any((c) => c.id == 'flask'), isFalse);
    expect(find.text('777ml'), findsNothing);
    expect(find.text('Deleted Flask'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await pumpFor(tester, 8);

    expect(WaterService.getAllContainers().any((c) => c.id == 'flask'), isTrue);
    expect(find.text('777ml'), findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('Edit opens the creator on that cup', (tester) async {
    await WaterService.addCustomContainer(flask);
    await open(tester);
    await tester.scrollUntilVisible(chip('777ml'), 200,
        scrollable: find.byType(Scrollable).first);

    await tester.longPress(chip('777ml'));
    await pumpFor(tester);
    await tester.tap(find.text('Edit cup'));
    await pumpFor(tester, 10);

    final creator = tester.widget<CustomCupCreatorScreen>(
        find.byType(CustomCupCreatorScreen));
    expect(creator.existingContainer?.id, 'flask');
    expect(find.widgetWithText(TextFormField, 'Flask'), findsOneWidget,
        reason: 'the name is filled in');
  });

  testWidgets('a built-in cup is not offered for editing', (tester) async {
    await open(tester);
    final builtIn =
        WaterService.getAllContainers().firstWhere((c) => c.isDefault);
    final label = '${builtIn.capacityMl}ml';
    await tester.scrollUntilVisible(chip(label), 200,
        scrollable: find.byType(Scrollable).first);

    await tester.longPress(chip(label));
    await pumpFor(tester);

    expect(find.text('Edit cup'), findsNothing);
    expect(find.text('Delete cup'), findsNothing);
  });

  testWidgets('a screen reader can reach the same two actions on a made cup only',
      (tester) async {
    await WaterService.addCustomContainer(flask);
    await open(tester);

    final withAction = find.byWidgetPredicate((w) =>
        w is Semantics &&
        (w.properties.customSemanticsActions?.keys
                .any((a) => a.label == 'Edit or delete cup') ??
            false));
    expect(withAction, findsOneWidget,
        reason: 'the one made cup has it; the built-in ones do not');
  });
}
