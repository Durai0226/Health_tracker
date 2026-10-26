/// The Garden Shop paints accents at the scale the token is defined for.
///
/// Seeded with the 1445 coins the bug report was filed against — every
/// existing harness resets `CoinsService` to zero, so all of them only ever
/// laid out the greyed-out `canAfford == false` grid and none of them has seen
/// this screen in its normal state.
///
/// Three defects, all of them one mistake: an accent used one rung below its
/// documented scale.
///
///  * The hero was `fillBg(...)`, whose doc comment reads "AA-safe background
///    for a FILLED control (primary button)" and which returns the identical
///    expression to `mark()`. At 363x241pt it resolved to #4ADE80 and measured
///    10.69:1 against the page, where every other card on the screen measures
///    1.08:1.
///  * The eight species borders were raw model hexes at 0.3 alpha, measuring
///    1.16:1 to 2.13:1 — an 84% spread encoding no state, which is why one
///    tile read as selected and its neighbour read as plain.
///  * The price chips were the same hexes at 0.1 alpha: 1.05:1 to 1.24:1, i.e.
///    no chip at all on dark.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/design/app_colors_ext.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/focus/models/focus_coins.dart';
import 'package:tablet_remainder/features/focus/screens/plant_real_trees_screen.dart';
import 'package:tablet_remainder/features/focus/services/coins_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.loadAppPreferences();
    CoinsService().resetForTesting();
  });

  tearDown(() async {
    CoinsService().resetForTesting();
    await db.close();
  });

  /// The reported state: 1445 coins, nothing bought yet.
  Future<void> pumpShop(WidgetTester tester) async {
    await CleanStorageService.setAppPreference(
      'focusCoins',
      const FocusCoins(totalCoins: 1445, lifetimeCoins: 1445).toJson(),
    );
    await CoinsService().init();

    tester.view.devicePixelRatio = 1.0;
    // Tall enough that the grid tiles actually lay out, not just the hero.
    tester.view.physicalSize = const Size(411, 2000);
    addTearDown(tester.view.reset);

    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    try {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: const PlantRealTreesScreen(),
      ));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 350));
    } finally {
      FlutterError.onError = prev;
    }
  }

  /// Every solid colour this screen paints as a box decoration.
  List<Color> decorationColors(WidgetTester tester) => [
        for (final c in tester.widgetList<Container>(find.byType(Container)))
          if (c.decoration is BoxDecoration &&
              (c.decoration as BoxDecoration).color != null)
            (c.decoration as BoxDecoration).color!,
      ];

  /// Every border colour this screen paints.
  List<Color> borderColors(WidgetTester tester) => [
        for (final c in tester.widgetList<Container>(find.byType(Container)))
          if (c.decoration is BoxDecoration &&
              (c.decoration as BoxDecoration).border != null)
            ((c.decoration as BoxDecoration).border! as Border).top.color,
      ];

  testWidgets('no surface is filled with a mark-scale accent', (tester) async {
    await pumpShop(tester);
    const ext = AppColorsExt.dark;

    // `fillBg` and `mark` are the same expression, so this one check covers
    // both spellings of the mistake.
    final marks = {
      for (final s in [ext.success, ext.steps, ext.focus, ext.brand])
        ext.fillBg(s),
    };
    final painted = decorationColors(tester).toSet();
    final offenders = painted.intersection(marks);

    expect(offenders, isEmpty,
        reason: 'a card ground is painted in a token defined for a filled '
            'control or a 20pt glyph. At 363x241pt that measured 10.69:1 '
            'against the page, against 1.08:1 for every other card here.');
  });

  testWidgets('the hero uses the accent container pair', (tester) async {
    await pumpShop(tester);
    const ext = AppColorsExt.dark;

    // Anchored to the hero's own label, not to the screen at large: the price
    // chips are filled with the same token, so a screen-wide `contains` stays
    // green when only the hero regresses — it would be measuring the chips.
    final hero = tester
        .widgetList<Container>(find.ancestor(
          of: find.text('Available Coins'),
          matching: find.byType(Container),
        ))
        .where((c) => c.decoration is BoxDecoration)
        .map((c) => (c.decoration as BoxDecoration).color)
        .whereType<Color>();

    expect(hero, isNotEmpty,
        reason: 'premise: the hero card rendered and is an ancestor of its '
            'own label. Without this the assertion below is vacuous.');
    expect(hero, contains(ext.success.container),
        reason: 'the hero is no longer filled with the large-area token.');
  });

  testWidgets('no species colour is used as a boundary', (tester) async {
    await pumpShop(tester);

    final species = {
      for (final t in RealTreeType.values) ...[
        t.color.withOpacity(0.3),
        t.color.withOpacity(0.1),
      ],
    };
    final used = {...borderColors(tester), ...decorationColors(tester)};

    expect(used.intersection(species), isEmpty,
        reason: 'the eight raw model hexes are back on the tiles. As borders '
            'they measured 1.16:1 to 2.13:1 and as chip fills 1.05:1 to '
            '1.24:1 — a spread that made some tiles look selected and the '
            'price chips invisible on dark.');
  });

  testWidgets('the header does not print the same number twice',
      (tester) async {
    await pumpShop(tester);

    // lifetimeCoins == totalCoins + coinsSpentOnTrees is an exact invariant of
    // CoinsService, so before the first purchase it IS the balance.
    expect(find.text('Lifetime Coins'), findsNothing,
        reason: 'with 1445 coins and nothing bought, "Available Coins" and '
            '"Lifetime Coins" both read 1445 — two labels, one number.');
    expect(find.text('Available Coins'), findsOneWidget,
        reason: 'premise: the balance itself is still on the screen');
  });
}
