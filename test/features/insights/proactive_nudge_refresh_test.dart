import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/health/insight.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/insights/screens/proactive_nudge.dart';

/// Pulling to refresh on Today re-checks the health nudge. It used to be worked
/// out once when the tab opened and never again, so it could keep describing a
/// problem the person had since fixed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
  });

  tearDown(() async => db.close());

  Insight insight(String id, String title,
          {InsightSeverity severity = InsightSeverity.attention}) =>
      Insight(
        id: id,
        feature: InsightFeature.water,
        severity: severity,
        title: title,
        detail: 'detail',
        why: 'why',
      );

  /// A nudge whose insights come from [source], rebuilt at [tick].
  Widget host(List<Insight> Function() source, int tick) => MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProactiveNudge(
              refreshTick: tick,
              loadInsights: () async => source(),
            ),
          ),
        ),
      );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  List<String> shows() {
    final v = CleanStorageService.getAppPreference('nudge_shows', const <String>[]);
    return v is List ? v.map((e) => e.toString()).toList() : const [];
  }

  testWidgets('the nudge appears on open, as before', (tester) async {
    var current = [insight('a', 'Drink more')];
    await tester.pumpWidget(host(() => current, 0));
    await settle(tester);
    expect(find.text('Drink more'), findsOneWidget);
    expect(shows(), hasLength(1));
  });

  testWidgets('refreshing takes it down once what it described no longer holds',
      (tester) async {
    var current = [insight('a', 'Drink more')];
    await tester.pumpWidget(host(() => current, 0));
    await settle(tester);
    expect(find.text('Drink more'), findsOneWidget);

    current = const []; // the person fixed it
    await tester.pumpWidget(host(() => current, 1));
    await settle(tester);
    expect(find.text('Drink more'), findsNothing);
  });

  testWidgets('refreshing swaps it for a different top insight, without '
      'spending another show', (tester) async {
    var current = [insight('a', 'Drink more')];
    await tester.pumpWidget(host(() => current, 0));
    await settle(tester);

    current = [insight('b', 'Sleep is slipping')];
    await tester.pumpWidget(host(() => current, 1));
    await settle(tester);

    expect(find.text('Drink more'), findsNothing);
    expect(find.text('Sleep is slipping'), findsOneWidget);
    expect(shows(), hasLength(1),
        reason: 'a refresh must not use up the weekly allowance');
  });

  testWidgets('a dismissed nudge is not brought back by a refresh',
      (tester) async {
    var current = [insight('a', 'Drink more')];
    await tester.pumpWidget(host(() => current, 0));
    await settle(tester);

    await tester.tap(find.text('Dismiss'));
    await settle(tester);
    expect(find.text('Drink more'), findsNothing);

    await tester.pumpWidget(host(() => current, 1));
    await settle(tester);
    expect(find.text('Drink more'), findsNothing);
  });

  testWidgets('with no nudge up, a refresh still respects the show limits',
      (tester) async {
    // One was shown moments ago (the 20-hour gap), then taken down.
    var current = [insight('a', 'Drink more')];
    await tester.pumpWidget(host(() => current, 0));
    await settle(tester);
    current = const [];
    await tester.pumpWidget(host(() => current, 1));
    await settle(tester);

    current = [insight('b', 'Sleep is slipping')];
    await tester.pumpWidget(host(() => current, 2));
    await settle(tester);
    expect(find.text('Sleep is slipping'), findsNothing,
        reason: 'a pull to refresh is not a way round the nudge limits');
  });

  test('Today passes its pull-to-refresh to the nudge', () {
    // Pinned by source, as the sibling nudge test does: mounting the whole Today
    // dashboard to observe one argument would couple this to every card on it.
    final src = File('lib/features/home/screens/home_dashboard.dart')
        .readAsStringSync()
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');

    final refresh = src.substring(src.indexOf('Future<void> _refreshAll()'));
    expect(refresh.substring(0, refresh.indexOf('\n  }\n')),
        contains('_nudgeTick++'),
        reason: 'a pull to refresh has to bump the tick');

    final from = src.indexOf('ProactiveNudge(');
    expect(from, greaterThan(-1));
    final call = src.substring(from, src.indexOf(');', from));
    expect(call, contains('refreshTick: _nudgeTick'),
        reason: 'the tick has to reach the widget that re-checks');
  });
}
