/// The Trends tab must not rebuild its bundle while it is off screen.
///
/// Trends is a permanent `IndexedStack` child of the app shell, and it listens
/// to `MedicineCleanStorageService.revision` so the charts don't keep showing
/// whatever was true at launch. Those two facts together meant that recording a
/// dose on Today re-ran `TrendsDataService.build` — four service `init()`s,
/// four async series, nine aggregations — for a screen nobody was looking at,
/// on the critical path of the tap that triggered it.
///
/// An `IndexedStack` child cannot see this from `build` or
/// `didChangeDependencies`: hidden children are still built and still laid out.
/// Only paint is withheld.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/insights/screens/trends_dashboard_screen.dart';
import 'package:tablet_remainder/features/insights/services/trends_data_service.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    MedicineCleanStorageService.revision.value = 0;
  });

  tearDown(() async => db.close());

  /// The shell's arrangement, reduced to the part that matters: Trends is a
  /// live `IndexedStack` child that starts hidden behind another tab.
  Future<void Function(int)> pumpShell(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var index = 0;
    final controller = ScrollController();
    addTearDown(controller.dispose);
    late StateSetter setOuter;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: StatefulBuilder(builder: (context, setState) {
        setOuter = setState;
        // The `PrimaryScrollController` wrapper is the shell's, not decoration:
        // the screen finds its `IndexedStack` `Visibility` by walking ancestors,
        // so anything the shell puts in between has to be in between here too.
        return IndexedStack(
          index: index,
          children: [
            const SizedBox.expand(),
            PrimaryScrollController(
              controller: controller,
              child: const TrendsDashboardScreen(isRoot: true),
            ),
          ],
        );
      }),
    ));
    // Let the first load finish. Not pumpAndSettle: the skeleton repeats.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return (int i) => setOuter(() => index = i);
  }

  testWidgets('a data change behind another tab does not rebuild the bundle',
      (tester) async {
    final select = await pumpShell(tester);
    final before = TrendsDataService.debugBuilds;
    expect(before, greaterThan(0),
        reason: 'the tab must have loaded once, or there is nothing to defer');

    // Exactly what recording a dose on any other tab does.
    MedicineCleanStorageService.revision.value++;
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(TrendsDataService.debugBuilds, before,
        reason: 'the hidden tab re-ran the whole bundle off screen');

    // Bringing it to the front is what makes the deferred work due.
    select(1);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(TrendsDataService.debugBuilds, before + 1,
        reason: 'the deferred reload must land when the tab is shown, or the '
            'user reads stale charts');
  });

  testWidgets('a data change on the VISIBLE tab still reloads at once',
      (tester) async {
    // The counterweight: deferring must not turn into never refreshing. The
    // listener exists so the charts follow the data, and on the tab the user is
    // looking at, "follow the data" means now.
    final select = await pumpShell(tester);
    select(1);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final before = TrendsDataService.debugBuilds;
    MedicineCleanStorageService.revision.value++;
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(TrendsDataService.debugBuilds, before + 1);
  });
}
