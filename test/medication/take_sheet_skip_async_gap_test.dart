import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_take_medication_sheet.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

/// The take-medication sheet's skip path crosses an async gap: it awaits the
/// "Why are you skipping?" sheet and then calls setState. If the take sheet's
/// own route goes away while that reason sheet is still up, the continuation
/// resumes on a defunct State and setState throws. The test removes that route
/// directly — no in-app flow does so today, which is exactly why the gap went
/// unnoticed — but the sheet sits on the root navigator under four different
/// entry points (home dashboard, log-something sheet, medication dashboard,
/// medicine detail), so its lifetime is not this method's to assume.
///
/// _takeMedication guards the same shape of gap with `if (!mounted) return;`
/// (after _confirmPrnLimits); _skipMedication did not, and nothing pinned it.
///
/// NOTE on pumping (same trap as prn_caregiver_friction_test): once a flow has
/// set _isLoading the primary button shows an indeterminate spinner that never
/// settles, so pumpAndSettle() hangs until the sheet actually pops. Bounded
/// pump()s only, until the sheet is gone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
  });

  tearDown(() async => db.close());

  final scheduledTime = DateTime(2026, 1, 5, 8);

  Future<EnhancedMedicine> seedMedicine() async {
    final med = EnhancedMedicine(
      id: 'med1',
      name: 'Metformin',
      strength: '500mg',
      dosageForm: DosageForm.tablet,
      dosageAmount: 1,
      createdAt: DateTime(2026),
      schedule: MedicineSchedule.onceDaily(hour: 8, minute: 0),
    );
    await MedicineCleanStorageService.addMedicine(med, stampActiveProfile: false);
    return med;
  }

  /// Opens the sheet the way the real app does — a real modal route — and
  /// hands back that route so a test can remove it mid-flow.
  Future<Route<dynamic>> openSheet(
      WidgetTester tester, EnhancedMedicine med, _RouteRecorder recorder) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      navigatorObservers: [recorder],
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showModalBottomSheet<Map<String, dynamic>>(
              context: context,
              isScrollControlled: true,
              builder: (_) => NunitoTakeMedicationSheet(
                  medicine: med, scheduledTime: scheduledTime),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return recorder.live.last;
  }

  Future<void> tapAndPumpBounded(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('positive: skipping while mounted records the reason and pops',
      (tester) async {
    final med = await seedMedicine();
    final recorder = _RouteRecorder();
    await openSheet(tester, med, recorder);

    await tapAndPumpBounded(tester, find.text('Skip'));
    expect(find.text('Why are you skipping?'), findsOneWidget);

    await tapAndPumpBounded(tester, find.text('Forgot to take'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(NunitoTakeMedicationSheet), findsNothing,
        reason: 'the sheet pops itself once the skip is logged');
    final logs = await MedicineCleanStorageService.getLogsForMedicine(med.id);
    expect(logs.where((l) => l.isSkipped).length, 1);
    expect(logs.firstWhere((l) => l.isSkipped).skipReason,
        SkipReason.forgotToTake);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'negative: the sheet disposed mid-await must not setState on the reason',
      (tester) async {
    final med = await seedMedicine();
    final recorder = _RouteRecorder();
    final sheetRoute = await openSheet(tester, med, recorder);

    await tapAndPumpBounded(tester, find.text('Skip'));
    expect(find.text('Why are you skipping?'), findsOneWidget);

    // Tear the take sheet down while the reason sheet is still up and its
    // future still pending — the reason sheet survives, the State does not.
    sheetRoute.navigator!.removeRoute(sheetRoute);
    await tester.pump();
    // By type, not by button copy: a `findsNothing` on a label would go
    // vacuously true the day that label is reworded, and this assertion is the
    // only thing standing between the test and testing nothing.
    expect(find.byType(NunitoTakeMedicationSheet), findsNothing,
        reason: 'the take sheet must really be disposed for this to test anything');
    expect(find.text('Why are you skipping?'), findsOneWidget,
        reason: 'the reason sheet outlives it, so the await still resolves');

    await tapAndPumpBounded(tester, find.text('Forgot to take'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull,
        reason: 'resuming past the await on a defunct State must not setState');
  });
}

/// Keeps the live route stack so a test can grab the sheet's own route.
class _RouteRecorder extends NavigatorObserver {
  final List<Route<dynamic>> live = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      live.add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      live.remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      live.remove(route);
}
