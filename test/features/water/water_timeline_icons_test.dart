import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/water/models/beverage_type.dart';
import 'package:tablet_remainder/features/water/models/enhanced_water_log.dart';
import 'package:tablet_remainder/features/water/widgets/aqua_timeline_list.dart';

/// W4 — Today's Log drew every drink as a drop of water.
///
/// Both timeline widgets resolved their glyph through a local ten-id map that
/// fell back to `'water'`. The catalogue defines beer, wine, spirits, cocktail,
/// espresso, three teas, orange juice, lemonade, coconut water, sports drink,
/// diet soda and sparkling water — none of which were in that map — while
/// `AquaTheme.iconFor` has a case for every one of them. So the map could only
/// lose information, and a beer and an espresso were both shown as water.
void main() {
  EnhancedWaterLog logFor(BeverageType b, {required int amountMl}) =>
      EnhancedWaterLog(
        id: 'log-${b.id}',
        time: DateTime(2026, 9, 26, 19, 30),
        amountMl: amountMl,
        effectiveHydrationMl: b.getEffectiveHydration(amountMl),
        beverageId: b.id,
        beverageName: b.name,
        beverageEmoji: b.emoji,
        hydrationPercent: b.hydrationPercent,
        caffeineAmount: b.getCaffeineAmount(amountMl),
        isAlcoholic: b.isAlcoholic,
      );

  BeverageType catalogue(String id) =>
      BeverageType.defaultBeverages.firstWhere((b) => b.id == id);

  Future<void> pumpTimeline(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ));
    await tester.pump();
  }

  /// Every icon rendered inside the list, so a test can say "the drop is not
  /// among them" as well as "the right glyph is".
  Set<IconData> iconsIn(WidgetTester tester) => tester
      .widgetList<Icon>(find.byType(Icon))
      .map((i) => i.icon)
      .whereType<IconData>()
      .toSet();

  testWidgets('a beer in the timeline is drawn as a beer', (tester) async {
    await pumpTimeline(
      tester,
      AquaTimelineList(logs: [logFor(catalogue('beer'), amountMl: 330)]),
    );

    expect(iconsIn(tester), contains(Symbols.sports_bar_rounded));
    expect(iconsIn(tester), isNot(contains(Symbols.water_drop_rounded)),
        reason: 'the log misrepresents what was drunk if a beer reads as '
            'water — the tile fill is the water container for every drink by '
            'design, so the glyph is the only thing that identifies it');
  });

  testWidgets('wine and espresso get their own glyphs too', (tester) async {
    await pumpTimeline(
      tester,
      AquaTimelineList(logs: [
        logFor(catalogue('wine'), amountMl: 150),
        logFor(catalogue('espresso'), amountMl: 30),
      ]),
    );

    final icons = iconsIn(tester);
    expect(icons, contains(Symbols.local_bar_rounded));
    expect(icons, contains(Symbols.coffee_rounded));
    expect(icons, isNot(contains(Symbols.water_drop_rounded)));
  });

  testWidgets('the compact entry resolves the same way', (tester) async {
    await pumpTimeline(
      tester,
      AquaCompactLogEntry(log: logFor(catalogue('beer'), amountMl: 330)),
    );

    expect(iconsIn(tester), contains(Symbols.sports_bar_rounded));
    expect(iconsIn(tester), isNot(contains(Symbols.water_drop_rounded)));
  });

  testWidgets('water itself still shows the drop', (tester) async {
    await pumpTimeline(
      tester,
      AquaTimelineList(logs: [logFor(catalogue('water'), amountMl: 250)]),
    );

    expect(iconsIn(tester), contains(Symbols.water_drop_rounded),
        reason: 'the default must survive the map being deleted');
  });
}
