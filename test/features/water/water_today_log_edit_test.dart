/// A drink on Today's Log can be changed from Today's Log.
///
/// The rows were read-only: to change a drink you could already see, the header's
/// "Edit" took you to the history screen, found the same drink again and opened
/// it there.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/features/water/models/beverage_type.dart';
import 'package:tablet_remainder/features/water/models/enhanced_water_log.dart';
import 'package:tablet_remainder/features/water/screens/aqua_water_dashboard.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';
import 'package:tablet_remainder/features/water/widgets/aqua_timeline_list.dart';

import '../../support/font_free_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  BeverageType catalogue(String id) =>
      BeverageType.defaultBeverages.firstWhere((b) => b.id == id);

  EnhancedWaterLog log(String id, String beverage, int ml, DateTime at) {
    final b = catalogue(beverage);
    return EnhancedWaterLog(
      id: id,
      time: at,
      amountMl: ml,
      effectiveHydrationMl: b.getEffectiveHydration(ml),
      beverageId: b.id,
      beverageName: b.name,
      beverageEmoji: b.emoji,
      hydrationPercent: b.hydrationPercent,
      caffeineAmount: b.getCaffeineAmount(ml),
      isAlcoholic: b.isAlcoholic,
    );
  }

  void quietOverflow() {
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      if (!'${d.exception}'.contains('overflowed')) prev?.call(d);
    };
    addTearDown(() => FlutterError.onError = prev);
  }

  group('the list', () {
    final nine = DateTime(2026, 9, 26, 9, 5);
    final noon = DateTime(2026, 9, 26, 12, 40);

    Future<void> pumpList(WidgetTester tester, AquaTimelineList list) async {
      quietOverflow();
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(430, 1400);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: fontFreeTheme(),
        home: Scaffold(body: SingleChildScrollView(child: list)),
      ));
      await tester.pump();
    }

    testWidgets('a tap on a row hands back that drink', (tester) async {
      final tapped = <String>[];
      await pumpList(
        tester,
        AquaTimelineList(
          logs: [log('a', 'coffee', 200, nine), log('b', 'tea', 250, noon)],
          onEdit: (l) => tapped.add(l.id),
        ),
      );

      await tester.tap(find.textContaining('Tea'));
      await tester.tap(find.textContaining('Coffee'));

      expect(tapped, ['b', 'a'], reason: 'each row opens its own drink');
    });

    testWidgets('without an editor the rows stay as they were', (tester) async {
      await pumpList(
        tester,
        AquaTimelineList(logs: [log('a', 'coffee', 200, nine)]),
      );

      await tester.tap(find.textContaining('Coffee'));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('+200 ml'), findsOneWidget);
    });

    testWidgets('a swipe to delete still works beside a tap to edit', (tester) async {
      final deleted = <String>[];
      final edited = <String>[];
      await pumpList(
        tester,
        AquaTimelineList(
          logs: [log('a', 'coffee', 200, nine)],
          onDelete: (l) => deleted.add(l.id),
          onEdit: (l) => edited.add(l.id),
        ),
      );

      await tester.drag(find.textContaining('Coffee'), const Offset(-120, 0));
      await tester.pump();
      expect(deleted, ['a']);
      expect(edited, isEmpty, reason: 'a swipe is not a tap');

      await tester.tap(find.textContaining('Coffee'));
      expect(edited, ['a']);
    });
  });

  group('on the dashboard', () {
    late db.AppDatabase database;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      database = db.AppDatabase.forTesting(NativeDatabase.memory());
      db.AppDatabase.setInstanceForTesting(database);
      WaterService.clearInMemory();
      await WaterService.resetForTesting();
      await WaterService.init();
    });

    tearDown(() async => database.close());

    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('tapping a drink opens it, and saving changes the row', (tester) async {
      quietOverflow();
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(430, 3200);
      addTearDown(tester.view.reset);

      await tester.runAsync(() => WaterService.addWaterLog(
          amountMl: 400, beverage: catalogue('coffee')));
      await tester.pumpWidget(
          MaterialApp(theme: fontFreeTheme(), home: const AquaWaterDashboard()));
      await settle(tester);

      expect(find.text('+400 ml'), findsOneWidget, reason: "the premise: today's drink is listed");

      await tester.ensureVisible(find.text('+400 ml'));
      await tester.pump();
      await tester.tap(find.text('+400 ml'));
      await settle(tester);

      expect(find.text('Edit Entry'), findsOneWidget);
      // The amount field is the numeric one; the note is free text.
      final numeric = tester.widgetList<TextField>(find.byType(TextField)).firstWhere(
          (f) => f.keyboardType == TextInputType.number && f.controller != null);
      expect(numeric.controller!.text, '400');
      numeric.controller!.text = '300';
      await tester.pump();

      await tester.ensureVisible(find.text('Update Entry'));
      await tester.pump();
      await tester.tap(find.text('Update Entry'));
      await settle(tester);

      expect(find.text('Edit Entry'), findsNothing, reason: 'the sheet closed');
      expect(find.text('+300 ml'), findsOneWidget,
          reason: 'the dashboard read the day again');
      expect(find.text('+400 ml'), findsNothing);
      expect(WaterService.getTodayData().totalIntakeMl, 300);
      await tester.pump(const Duration(seconds: 8));
    });
  });
}
