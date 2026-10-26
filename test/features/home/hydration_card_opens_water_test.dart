import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/home/screens/app_shell.dart';
import 'package:tablet_remainder/features/home/screens/home_dashboard.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_medication_dashboard.dart';
import 'package:tablet_remainder/features/water/screens/aqua_water_dashboard.dart';

/// Today's Hydration card and its "Set goal" button called `onNavigate(1,
/// healthTab: 1)`, which the shell translated into "switch to the Health tab" —
/// a list of trackers, one tap short of the water screen the card was about.
void main() {
  late AppDatabase db;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
  });

  tearDown(() async => db.close());

  Future<void> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final prev = FlutterError.onError;
    FlutterError.onError = (_) {}; // layout is the responsive suite's job
    try {
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme, home: const AppShell()));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 300));
    } finally {
      FlutterError.onError = prev;
    }
  }

  void navigate(WidgetTester tester, int index, {int? healthTab}) {
    tester
        .widget<HomeDashboard>(find.byType(HomeDashboard))
        .onNavigate(index, healthTab: healthTab);
  }

  testWidgets('the hydration destination opens the water screen',
      (tester) async {
    await pumpShell(tester);
    expect(find.byType(AquaWaterDashboard), findsNothing);

    navigate(tester, 1, healthTab: 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(AquaWaterDashboard), findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('the medicine destination still switches to the Meds tab, '
      'without pushing anything', (tester) async {
    await pumpShell(tester);

    navigate(tester, 1, healthTab: 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(AquaWaterDashboard), findsNothing);
    expect(find.byType(NunitoMedicationDashboard), findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
  });
}
