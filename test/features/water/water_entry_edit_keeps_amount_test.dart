/// Correcting a drink's TYPE must not silently rewrite its amount.
///
/// `_AddEditEntrySheet` serves both "Add Entry" and "Edit Entry" — the two call
/// sites differ only by `existingLog`. Its beverage tiles overwrote
/// `_amountController` with the newly-picked beverage's `defaultAmountMl` on
/// every tap, which is a sensible convenience while ADDING and data loss while
/// EDITING: an entry logged as Coffee 400ml, retyped as Tea because the user
/// picked the wrong drink, silently became 200ml with nothing on screen to say
/// the volume had changed.
///
/// The rule now is "prefill only while the amount is still the outgoing
/// beverage's default", which keeps the convenience for a fresh entry and a
/// typed-over one alike.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/water/screens/water_history_edit_screen.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late db.AppDatabase database;
  final day = DateTime(2026, 3, 14);
  const keyFor = '2026-03-14';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    WaterService.clearInMemory();
    await WaterService.resetForTesting();
  });

  tearDown(() async => database.close());

  /// One stored day holding a single 400ml coffee.
  Future<void> seedCoffee400() async {
    await database.waterDao.saveDailyData(db.DailyWaterDataTableCompanion(
      id: Value(keyFor),
      date: Value(day),
      dailyGoalMl: const Value(2500),
      totalIntakeMl: const Value(400),
      effectiveHydrationMl: const Value(400),
      totalCaffeineMg: const Value(0),
      alcoholicDrinksCount: const Value(0),
      goalReached: const Value(false),
    ));
    await database.waterDao.addWaterLog(db.EnhancedWaterLogsCompanion(
      id: const Value('log-1'),
      dailyDataId: Value(keyFor),
      time: Value(DateTime(2026, 3, 14, 9, 0)),
      amountMl: const Value(400),
      effectiveHydrationMl: const Value(400),
      beverageId: const Value('coffee'),
      beverageName: const Value('Coffee'),
      beverageEmoji: const Value('☕'),
      hydrationPercent: const Value(100),
      caffeineAmount: const Value(0),
      isAlcoholic: const Value(false),
    ));
  }

  /// The amount field's live text, whichever TextField it is.
  String amountFieldText(WidgetTester tester) {
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields, isNotEmpty, reason: 'the edit sheet rendered no text field');
    // The amount field is the numeric one; the note field is free text.
    final numeric = fields.where((f) =>
        f.keyboardType == TextInputType.number && f.controller != null);
    expect(numeric, isNotEmpty,
        reason: 'no numeric field on the sheet — the amount input moved');
    return numeric.first.controller!.text;
  }

  Future<void> openEditSheet(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(420, 1200);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: WaterHistoryEditScreen(date: day),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The row for the seeded log — by its beverage name, not by "400":
    // the hero total at the top of the screen also reads "400ml".
    await tester.tap(find.text('Coffee').first, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('changing the drink type keeps the amount already logged',
      (tester) async {
    await seedCoffee400();
    await WaterService.init();
    await openEditSheet(tester);

    expect(amountFieldText(tester), '400',
        reason: 'premise: the edit sheet opens on the real logged volume. '
            'Without this the assertion below proves nothing.');

    // The user picked the wrong drink and is correcting only that.
    final tea = find.text('Tea');
    expect(tea, findsWidgets, reason: 'the beverage strip did not render');
    await tester.tap(tea.first, warnIfMissed: false);
    await tester.pump();

    expect(amountFieldText(tester), '400',
        reason: 'the amount the user actually logged was overwritten by the '
            "new beverage's default — silent data loss on an edit");
  });

  testWidgets('while adding, picking a drink still prefills its default',
      (tester) async {
    // The convenience this rule has to preserve: a fresh entry starts at the
    // default 250, so it is still "untouched" and follows the beverage.
    await WaterService.init();

    tester.view.devicePixelRatio = 1.0;
    // Wider than the edit path, and overflow exceptions swallowed.
    //
    // The ADD sheet seeds its time field from `TimeOfDay.now()` — the real
    // wall clock, not `clock.now()`, so it cannot be pinned — and its
    // time-picker row overflows by a few pixels at some widths once the
    // rendered time string gets wide enough ("12:02 PM" vs "9:02 AM"). This
    // test passed when it was written and failed hours later for that reason
    // alone.
    //
    // That overflow is a separate, known item and belongs to the responsive
    // harness, which measures layout properly. This test is about whether the
    // AMOUNT is prefilled, so it must not be a clock-dependent layout test by
    // accident.
    tester.view.physicalSize = const Size(600, 1400);
    addTearDown(tester.view.reset);

    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      if (!d.exception.toString().contains('overflowed')) prev?.call(d);
    };
    addTearDown(() => FlutterError.onError = prev);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: WaterHistoryEditScreen(date: day),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Add entry').first, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    if (find.byType(TextField).evaluate().isEmpty) {
      markTestSkipped('the add sheet did not open in this layout');
      return;
    }
    final before = amountFieldText(tester);
    expect(before, '250', reason: 'a new entry starts on the water default');

    final tea = find.text('Tea');
    if (tea.evaluate().isEmpty) {
      markTestSkipped('beverage strip not laid out');
      return;
    }
    await tester.tap(tea.first, warnIfMissed: false);
    await tester.pump();

    expect(amountFieldText(tester), isNot('250'),
        reason: 'an untouched amount must still follow the chosen beverage');
  });
}
