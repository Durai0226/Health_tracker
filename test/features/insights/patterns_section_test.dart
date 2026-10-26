import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/health/insight.dart';
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/insights/services/pattern_insights.dart';
import 'package:tablet_remainder/features/insights/widgets/patterns_section.dart';

Insight ins(String id, InsightSeverity s, {double rank = 0, String? title}) =>
    Insight(
      id: id,
      feature: InsightFeature.crossCutting,
      severity: s,
      title: title ?? id,
      detail: 'detail of $id',
      why: 'why of $id',
      rank: rank,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
  });

  tearDown(() async => db.close());

  final data = [
    ins('correlation_bp_adherence', InsightSeverity.attention, rank: 60, title: 'BP follows your doses'),
    ins('steps_trend', InsightSeverity.info, rank: 40, title: 'Steps are up'),
    ins('water_trend', InsightSeverity.good, rank: 20, title: 'Water is up'),
    ins('water_behind', InsightSeverity.attention, rank: 90, title: 'Behind on water'),
  ];

  Future<void> pump(WidgetTester tester, Widget w) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 3000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: SingleChildScrollView(child: w)),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('groups the patterns and leaves today-only insights out',
      (tester) async {
    await pump(tester,
        PatternsSection(reloadKey: Object(), load: () async => data));

    expect(find.text('Patterns'), findsOneWidget);
    expect(find.text('NEEDS ATTENTION'), findsOneWidget);
    expect(find.text('PATTERNS'), findsOneWidget);
    expect(find.text('WINS'), findsOneWidget);
    expect(find.text('BP follows your doses'), findsOneWidget);
    expect(find.text('Steps are up'), findsOneWidget);
    expect(find.text('Water is up'), findsOneWidget);
    expect(find.text('Behind on water'), findsNothing,
        reason: 'a today-scoped nudge is not a cross-day pattern');
  });

  testWidgets('with nothing to say it renders nothing at all', (tester) async {
    await pump(tester, PatternsSection(reloadKey: Object(), load: () async => []));
    expect(find.text('Patterns'), findsNothing);
    expect(find.text('Not useful'), findsNothing);
  });

  testWidgets('only today-scoped insights also render nothing', (tester) async {
    await pump(
        tester,
        PatternsSection(
            reloadKey: Object(),
            load: () async =>
                [ins('water_behind', InsightSeverity.attention, rank: 90)]));
    expect(find.text('Patterns'), findsNothing);
  });

  testWidgets('"Not useful" hides it and keeps it hidden', (tester) async {
    final key = Object();
    await pump(tester, PatternsSection(reloadKey: key, load: () async => data));

    await tester.tap(find.text('Not useful').first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('BP follows your doses'), findsNothing);
    expect(HiddenPatterns.current(), contains('correlation_bp_adherence'));

    // A fresh mount (a new visit) does not bring it back.
    await tester.pumpWidget(const SizedBox.shrink());
    await pump(tester, PatternsSection(reloadKey: Object(), load: () async => data));
    expect(find.text('BP follows your doses'), findsNothing);
    expect(find.text('Steps are up'), findsOneWidget);
  });

  testWidgets('a failing source shows nothing rather than breaking the page',
      (tester) async {
    await pump(tester,
        PatternsSection(reloadKey: Object(), load: () async => throw StateError('x')));
    expect(find.text('Patterns'), findsNothing);
  });

  testWidgets('it reloads when the data behind the page was rebuilt, and not '
      'otherwise', (tester) async {
    var loads = 0;
    Future<List<Insight>> load() async {
      loads++;
      return data;
    }

    final k1 = Object();
    await pump(tester, PatternsSection(reloadKey: k1, load: load));
    expect(loads, 1);

    // Same key: a parent rebuild must not refetch.
    await pump(tester, PatternsSection(reloadKey: k1, load: load));
    expect(loads, 1);

    await pump(tester, PatternsSection(reloadKey: Object(), load: load));
    expect(loads, 2);
  });

  testWidgets('it tells its parent whether it has anything', (tester) async {
    final seen = <bool>[];
    await pump(
        tester,
        PatternsSection(
            reloadKey: Object(), load: () async => data, onResolved: seen.add));
    expect(seen, [true]);

    final seen2 = <bool>[];
    await pump(
        tester,
        PatternsSection(
            reloadKey: Object(), load: () async => [], onResolved: seen2.add));
    expect(seen2, [false]);
  });

  group('HiddenPatterns', () {
    final t0 = DateTime(2026, 3, 1);

    test('hides for 30 days, then lets it come back', () async {
      await HiddenPatterns.hide('steps_trend', now: t0);
      expect(HiddenPatterns.current(now: t0), contains('steps_trend'));
      expect(HiddenPatterns.current(now: t0.add(const Duration(days: 29))),
          contains('steps_trend'));
      expect(HiddenPatterns.current(now: t0.add(const Duration(days: 31))),
          isNot(contains('steps_trend')));
    });

    test('hiding again restarts the clock, and ids stay separate', () async {
      await HiddenPatterns.hide('steps_trend', now: t0);
      await HiddenPatterns.hide('water_trend', now: t0);
      await HiddenPatterns.hide('steps_trend', now: t0.add(const Duration(days: 20)));
      final later = t0.add(const Duration(days: 40));
      expect(HiddenPatterns.current(now: later), {'steps_trend'});
    });
  });
}
