/// The milestones shelf must not re-evaluate itself on every rebuild.
///
/// `MilestonesScreen` was a `StatelessWidget` calling `MilestonesService.sync()`
/// inline in `build`, so every rebuild the route saw — a theme change, a parent
/// `setState` — handed the `FutureBuilder` a brand-new future and started the
/// whole evaluation again: the full catalog, `StepService.getBestDay()`,
/// `getStreakResult()`, every sleep session, the regularity index, and a
/// persisted write whenever something is freshly earned.
///
/// What this is NOT: a spinner flash. `FutureBuilder.didUpdateWidget` swaps the
/// future with `_snapshot.inState(ConnectionState.none)`, which KEEPS the old
/// data — so `snap.hasData` stays true and the shelf never falls back to the
/// `CircularProgressIndicator`. An earlier version of this file asserted that it
/// did, and passed with the defect fully restored. The observable that actually
/// distinguishes the two is the identity of the future itself.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/milestones/milestones_screen.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
  });

  tearDown(() async => db.close());

  testWidgets('the evaluation is not restarted by a rebuild', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late StateSetter rebuild;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: StatefulBuilder(
        builder: (context, setState) {
          rebuild = setState;
          return MilestonesScreen(
              feature: 'steps', accentOf: (ext) => ext.steps);
        },
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The shelf has resolved. On an empty database nothing is earned, and
    // "0 of N reached" is still the loaded state — without this the identity
    // check below would be comparing two futures nobody ever awaited.
    //
    // Not `textContaining('reached')`: one of the tile titles is "First goal
    // reached", so that finder matches two widgets.
    final header = find.byWidgetPredicate(
        (w) => w is Text && RegExp(r'^\d+ of \d+ reached$').hasMatch(w.data ?? ''),
        description: 'the "N of M reached" header, i.e. the loaded state');
    expect(header, findsOneWidget,
        reason: 'the shelf never loaded, so this test is checking nothing');

    Future<Object?> currentFuture() => tester
        .widgetList(find.byWidgetPredicate((w) => w is FutureBuilder))
        .map((w) => (w as FutureBuilder).future)
        .first as Future<Object?>;

    final first = currentFuture();

    // Exactly what a theme change or a parent setState does to this route.
    rebuild(() {});
    await tester.pump();

    expect(identical(currentFuture(), first), isTrue,
        reason: 'a new future per build is the whole defect: MilestonesService'
            '.sync() walks the catalog, reads Steps and Sleep, and can write '
            'the earned map, once for every rebuild the route happens to see');
    expect(header, findsOneWidget,
        reason: 'the loaded list must survive the rebuild');
  });

  testWidgets('the feature filter still applies', (tester) async {
    // The conversion moved `feature` behind `widget.`; a filter silently
    // reading null would show both shelves and nothing else would notice.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 2000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: MilestonesScreen(feature: 'sleep', accentOf: (ext) => ext.sleep),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    // Five sleep milestones in the catalog, and no steps ones.
    expect(find.text('0 of 5 reached'), findsOneWidget);
    expect(find.text('First night logged'), findsOneWidget);
    expect(find.text('10,000 steps'), findsNothing);
  });
}
