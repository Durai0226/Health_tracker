/// Chart dates go through [DateFormats], not through hand-rolled tables.
///
/// `trend_chart_card.dart` carried its own `_months` and `_weekdays` const
/// lists and indexed them by `month - 1` / `weekday - 1`, so every chart
/// tooltip in the app read "Mon, 14 Mar" in English whatever the device was set
/// to — while the reading lists, alarm rows and history headers a tap away were
/// already going through `DateFormats`.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import 'package:tablet_remainder/core/utils/date_formats.dart';
import 'package:tablet_remainder/features/insights/services/trends_data_service.dart';
import 'package:tablet_remainder/features/insights/widgets/trend_chart_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  /// Seven days from Sat 14 March 2026.
  final days = [for (var i = 0; i < 7; i++) DateTime(2026, 3, 14 + i)];

  Future<void> pumpCard(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: TrendChartCard(
          accent: AppColorsExt.light.water,
          icon: Symbols.water_drop_rounded,
          title: 'Water',
          headline: '2.1 L avg',
          series: TrendSeries(
              [for (final d in days) TrendPoint(d, 2100 + d.day.toDouble())]),
          kind: TrendChartKind.bar,
          rangeDays: 7,
          featureName: 'water',
          formatValue: (v) => '${v.round()} ml',
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('the tooltip date is formatted, not assembled from const tables',
      (tester) async {
    await pumpCard(tester);

    final chart = tester.widget<BarChart>(find.byType(BarChart));
    final group = chart.data.barGroups.first;
    final item = chart.data.barTouchData.touchTooltipData
        .getTooltipItem(group, 0, group.barRods.first, 0);
    expect(item, isNotNull,
        reason: 'no tooltip means this test is asserting on nothing');

    final dateLine = item!.children!.first.toPlainText().trim();

    // 14 March 2026 is a Saturday. The hand-rolled version produced
    // "Sat, 14 Mar" from its own English tables; this is the app's own format,
    // which follows the locale like every other date on screen.
    expect(dateLine, 'Sat, Mar 14');
    expect(dateLine, DateFormats.weekdayDayMonthShort.format(days.first));
  });
}
