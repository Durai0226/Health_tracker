/// The chart table twin — the accessible equivalent every chart in this app now
/// carries.
///
/// It is not a nice-to-have. Two of the six chart accents were MEASURED at
/// below 3:1 against the card surface (water 2.36, steps 2.22), and a contrast
/// shortfall obligates either a visible label on every point or a table view.
/// So these tests are the gate on that obligation being met, plus the two
/// honesty rules the table itself has to hold: a gap is never a zero, and a
/// spoken summary never states a direction the card hasn't earned.
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import 'package:tablet_remainder/features/insights/services/trends_data_service.dart';
import 'package:tablet_remainder/features/insights/widgets/trend_chart_card.dart';
import 'package:tablet_remainder/features/insights/widgets/trend_table_view.dart';

/// Mon 4 Aug 2025 .. Sun 10 Aug 2025, with Wed and Sat as gap days.
TrendSeries _week({bool withSecond = false}) {
  const values = <double?>[1200, 1800, null, 2400, 2900, null, 2100];
  const second = <double?>[80, 84, null, 78, 90, null, 82];
  return TrendSeries([
    for (var i = 0; i < 7; i++)
      TrendPoint(
        DateTime(2025, 8, 4 + i),
        values[i],
        withSecond ? second[i] : null,
      ),
  ]);
}

TrendSeries get _empty => TrendSeries([
      for (var i = 0; i < 7; i++) TrendPoint(DateTime(2025, 8, 4 + i), null),
    ]);

TrendSeries get _oneDay => TrendSeries([
      for (var i = 0; i < 7; i++)
        TrendPoint(DateTime(2025, 8, 4 + i), i == 3 ? 2400 : null),
    ]);

String _ml(double v) => '${v.round()} ml';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    ));
    await tester.pump(const Duration(seconds: 2));
  }

  Iterable<String> texts(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => (t.data ?? '').trim())
      .where((s) => s.isNotEmpty);

  // ---------------------------------------------------------------- summary

  group('trendSeriesSummary', () {
    test('an empty week says so, and does not invent an average', () {
      final s = trendSeriesSummary(
        title: 'Water',
        series: _empty,
        rangeDays: 7,
        formatValue: _ml,
      );
      expect(s, 'Water chart. Nothing logged in the last 7 days.');
      expect(s.toLowerCase(), isNot(contains('average')));
    });

    test('names the count, the average, and both extremes with their dates',
        () {
      final s = trendSeriesSummary(
        title: 'Water',
        series: _week(),
        rangeDays: 7,
        formatValue: _ml,
      );
      expect(s, contains('5 of 7 days logged'));
      expect(s, contains('Average 2080 ml'));
      expect(s, contains('Lowest 1200 ml on Mon, Aug 4'));
      expect(s, contains('highest 2900 ml on Fri, Aug 8'));
    });

    test('never doubles the unit', () {
      // `formatValue` already renders "2080 ml". Appending the column heading
      // on top of it produced "Average 2080 ml Water" in the first draft —
      // caught here rather than by a person listening to it.
      final s = trendSeriesSummary(
        title: 'Water',
        series: _week(),
        rangeDays: 7,
        formatValue: _ml,
        valueLabel: 'Water',
      );
      expect(s, isNot(contains('ml Water')));
    });

    test('one logged day does not stutter its low and its high', () {
      final s = trendSeriesSummary(
        title: 'Water',
        series: _oneDay,
        rangeDays: 7,
        formatValue: _ml,
      );
      expect(s, contains('1 of 7 days logged'));
      expect(s, contains('Average 2400 ml'));
      // Lowest == highest == the only row. Saying both reads as a fault.
      expect(s.toLowerCase(), isNot(contains('lowest')));
    });

    test('a two-series card reports both averages and no extremes', () {
      final s = trendSeriesSummary(
        title: 'Blood pressure',
        series: _week(withSecond: true),
        rangeDays: 7,
        formatValue: (v) => v.round().toString(),
        valueLabel: 'Sys',
        secondaryLabel: 'Dia',
      );
      expect(s, contains('Average Sys 2080'));
      expect(s, contains('Average Dia 83')); // 80+84+78+90+82 = 414 / 5
      // "Lowest 1200, highest 2900" would be systolic-only and read as if it
      // described the pair.
      expect(s.toLowerCase(), isNot(contains('lowest')));
    });

    test('states no direction, however clearly the series trends', () {
      // Strictly rising: direction is +1, and the summary must still not say so.
      // Whether up is good is the caller's knowledge, not this function's.
      final rising = TrendSeries([
        for (var i = 0; i < 7; i++)
          TrendPoint(DateTime(2025, 8, 4 + i), 1000 + i * 400),
      ]);
      expect(rising.direction, 1);
      final s = trendSeriesSummary(
        title: 'Steps',
        series: rising,
        rangeDays: 7,
        formatValue: (v) => '${v.round()} steps',
      ).toLowerCase();
      for (final banned in ['up', 'down', 'improv', 'better', 'worse', 'trend']) {
        expect(s, isNot(contains(banned)), reason: 'summary claimed a direction');
      }
    });
  });

  // ------------------------------------------------------------------ table

  group('TrendTableView', () {
    testWidgets('a gap day reads "Not logged" and never zero', (tester) async {
      await pump(
        tester,
        TrendTableView(
            series: _week(), valueLabel: 'Water', formatValue: _ml),
      );

      final all = texts(tester).toList();
      // Two gap days in the fixture.
      expect(all.where((t) => t == kNotLogged).length, 2);
      // The lethal failure this whole widget exists to avoid: a rendered 0 on a
      // day with no entry, which reads as "drank nothing".
      expect(all, isNot(contains('0 ml')));
      expect(all, isNot(contains('0')));
    });

    testWidgets('rows run newest-first', (tester) async {
      await pump(
        tester,
        TrendTableView(
            series: _week(), valueLabel: 'Water', formatValue: _ml),
      );
      final all = texts(tester).toList();
      expect(all.indexOf('Sun, Aug 10'), lessThan(all.indexOf('Mon, Aug 4')));
    });

    testWidgets('a second series adds a third column, headings and all',
        (tester) async {
      await pump(
        tester,
        TrendTableView(
          series: _week(withSecond: true),
          valueLabel: 'Sys',
          secondaryLabel: 'Dia',
          formatValue: (v) => v.round().toString(),
        ),
      );
      final all = texts(tester).toList();
      expect(all, containsAll(<String>['Day', 'Sys', 'Dia']));
      expect(all, contains('2900'));
      expect(all, contains('90'));
      // Both columns of a gap day are unlogged, so the label appears twice per
      // gap row.
      expect(all.where((t) => t == kNotLogged).length, 4);
    });
  });

  // ------------------------------------------------------- card integration

  group('cards carry the twin', () {
    // The accent is an AccentSwatch resolved off the theme, the way every real
    // call site gets it — a raw palette Color is a different type.
    Widget card(TrendSeries series, {List<String>? labels}) => Builder(
          builder: (context) => TrendChartCard(
            accent: AppColorsExt.of(context).water,
            icon: Symbols.water_drop_rounded,
            title: 'Water',
            headline: '2.1 L avg',
            series: series,
            kind: TrendChartKind.bar,
            rangeDays: 7,
            featureName: 'water',
            formatValue: _ml,
            seriesLabels: labels,
          ),
        );

    testWidgets('a card with data offers the table, and it opens',
        (tester) async {
      await pump(tester, card(_week()));

      final button = find.text('View as table');
      expect(button, findsOneWidget,
          reason: 'the contrast obligation is met by this control existing');

      await tester.tap(button);
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(TrendTableView), findsOneWidget);
      final all = texts(tester).toList();
      expect(all, contains('2900 ml'));
      expect(all.where((t) => t == kNotLogged).length, 2);
    });

    testWidgets('a card with no data offers no table', (tester) async {
      await pump(tester, card(_empty));
      expect(find.text('View as table'), findsNothing,
          reason: 'an empty table is a dead end, and the in-card empty state '
              'already says the useful thing');
    });

    testWidgets('the two-series card labels its table columns from seriesLabels',
        (tester) async {
      await pump(
          tester, card(_week(withSecond: true), labels: const ['Sys', 'Dia']));
      await tester.tap(find.text('View as table'));
      await tester.pump(const Duration(seconds: 1));

      final view = tester.widget<TrendTableView>(find.byType(TrendTableView));
      expect(view.valueLabel, 'Sys');
      expect(view.secondaryLabel, 'Dia');
    });

    // The screen-level responsive harness renders Trends against an EMPTY test
    // database, so `hasData` is false there and it has never laid out a single
    // one of these buttons. The same is true of the build-cost budget. This is
    // that blind spot closed at the widget level: real data, the harness's own
    // floor device and its own top text scale.
    testWidgets('no card overflows with the control on it, down to 320 @ 2.0x',
        (tester) async {
      const devices = <Size>[
        Size(320, 568),
        Size(360, 640),
        Size(375, 667),
        Size(428, 926),
      ];
      const scales = <double>[1.0, 1.3, 2.0];

      final overflows = <String>[];
      for (final size in devices) {
        for (final scale in scales) {
          tester.view.devicePixelRatio = 1.0;
          tester.view.physicalSize = size;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final prev = FlutterError.onError;
          FlutterError.onError = (d) {
            final e = d.exception;
            if (e is FlutterError &&
                e.toString().contains('overflowed')) {
              overflows.add('${size.width.toInt()} @${scale}x: '
                  '${e.toString().split('\n').first}');
            } else {
              prev?.call(d);
            }
          };
          try {
            await tester.pumpWidget(MediaQuery(
              data: MediaQueryData(
                  size: size, textScaler: TextScaler.linear(scale)),
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: Builder(
                      builder: (context) {
                        final ext = AppColorsExt.of(context);
                        return Column(children: [
                          card(_week()),
                          card(_week(withSecond: true),
                              labels: const ['Sys', 'Dia']),
                          TrendRingCard(
                            accent: ext.steps,
                            icon: Symbols.directions_walk_rounded,
                            title: 'Steps',
                            ringProgress: 0.8,
                            centerValue: '80%',
                            headline: 'avg 8,200 · goal 10,000',
                            series: _week(),
                            rangeDays: 7,
                            featureName: 'steps',
                            formatValue: (v) => '${v.round()} steps',
                          ),
                          TrendTimeInRangeCard(
                            accent: ext.medicine,
                            icon: Symbols.glucose_rounded,
                            title: 'Glucose',
                            // 13/74/13 puts two segments just over the
                            // `pct >= 12` in-segment-label gate, which is a
                            // proxy for width and knows nothing about text
                            // scale — so this is the fixture that stresses it.
                            tir: const GlucoseTir(low: 13, inRange: 74, high: 13),
                            series: _week(),
                            rangeDays: 7,
                            featureName: 'glucose',
                            formatValue: (v) => '${v.round()} mg/dL',
                          ),
                        ]);
                      },
                    ),
                  ),
                ),
              ),
            ));
            await tester.pump(const Duration(milliseconds: 400));
          } finally {
            FlutterError.onError = prev;
          }
        }
      }
      expect(overflows, isEmpty, reason: overflows.join('\n'));
    });

    // The in-segment percentage on the time-in-range bar is drawn inside a
    // Container with `alignment: center`, which does NOT report overflow — it
    // just paints and clips. So this is measured directly rather than trusted
    // to the error capture above.
    testWidgets('an in-segment label is dropped rather than clipped',
        (tester) async {
      // 13/74/13 at 320pt gives the outer segments ~37pt: the label needs 34pt
      // at 1.0x, exactly 37pt at 1.3x, and more than the slot at 2.0x.
      Widget tirCard() => Builder(
            builder: (context) => TrendTimeInRangeCard(
              accent: AppColorsExt.of(context).medicine,
              icon: Symbols.glucose_rounded,
              title: 'Glucose',
              tir: const GlucoseTir(low: 13, inRange: 74, high: 13),
              series: _week(),
              rangeDays: 7,
              featureName: 'glucose',
              formatValue: (v) => '${v.round()} mg/dL',
            ),
          );

      for (final scale in <double>[1.0, 1.3, 2.0]) {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(320, 900);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(MediaQuery(
          data: MediaQueryData(
              size: const Size(320, 900),
              textScaler: TextScaler.linear(scale)),
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
                body: SingleChildScrollView(child: tirCard())),
          ),
        ));
        await tester.pump(const Duration(milliseconds: 400));

        // Every '13%' still on screen must sit in a slot wide enough for it.
        // The breakdown rows underneath also render '13%', but those are
        // unconstrained body text; only the ones inside an 18pt-tall pill are
        // segment labels.
        for (final e in find.text('13%').evaluate()) {
          final text = e.renderObject! as RenderBox;
          RenderBox? pill;
          var node = e.renderObject!.parent;
          while (node != null) {
            if (node is RenderBox &&
                node.hasSize &&
                (node.size.height - 18).abs() < 0.6) {
              pill = node;
              break;
            }
            node = node.parent;
          }
          if (pill == null) continue; // a breakdown row, not a segment
          expect(text.size.width, lessThan(pill.size.width),
              reason: 'the segment label was clipped to its pill at ${scale}x '
                  '— drop it instead, the breakdown below already says 13%');
        }
      }
    });

    testWidgets('the chart box speaks a summary instead of nothing',
        (tester) async {
      final handle = tester.ensureSemantics();

      await pump(tester, card(_week()));

      // Read the semantics tree directly. `tester.getSemantics` walks the
      // ELEMENT tree via a debug-only visitor that throws on this app's
      // viewports — see focus_a11y_test.dart for the full account.
      // ignore: deprecated_member_use
      final root = tester.binding.pipelineOwner.semanticsOwner?.rootSemanticsNode;
      expect(root, isNotNull);

      final labels = <String>[];
      void walk(SemanticsNode n) {
        final l = n.label.trim();
        if (l.isNotEmpty) labels.add(l);
        n.visitChildren((c) {
          walk(c);
          return true;
        });
      }

      walk(root!);

      expect(
        labels.any((l) => l.contains('Water chart, last 7 days')),
        isTrue,
        reason: 'the chart is a CustomPaint — without this it is a silent box. '
            'Found: $labels',
      );
      expect(labels.any((l) => l.contains('5 of 7 days logged')), isTrue);

      // Not addTearDown: the framework verifies handle disposal inside the test
      // body's own teardown, which runs BEFORE registered tearDowns.
      handle.dispose();
    });
  });
}
