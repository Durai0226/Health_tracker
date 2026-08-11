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
import 'package:tablet_remainder/features/medication/screens/nunito_add_medication_flow.dart';

/// Tier 2: administration-route field. Model round-trip + the UI's
/// conditional visibility (only offered for the two DosageForms that are
/// genuinely ambiguous — injection and drops).
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

  EnhancedMedicine baseMedicine({AdministrationRoute? route}) => EnhancedMedicine(
        id: 'm1',
        name: 'Insulin',
        dosageForm: DosageForm.injection,
        route: route,
        dosageAmount: 1,
        createdAt: DateTime(2026, 1, 1),
        schedule: MedicineSchedule(
          frequencyType: FrequencyType.onceDaily,
          times: [ScheduledTime(hour: 8, minute: 0)],
        ),
      );

  group('EnhancedMedicine.route model', () {
    test('toJson/fromJson round-trips a set route', () {
      final m = baseMedicine(route: AdministrationRoute.subcutaneousInjection);
      final back = EnhancedMedicine.fromJson(m.toJson());
      expect(back.route, AdministrationRoute.subcutaneousInjection);
    });

    test('toJson/fromJson round-trips an unset (null) route', () {
      final m = baseMedicine();
      final back = EnhancedMedicine.fromJson(m.toJson());
      expect(back.route, isNull);
    });

    test('copyWith clearRoute actually clears (not a no-op)', () {
      final m = baseMedicine(route: AdministrationRoute.intravenousInjection);
      final cleared = m.copyWith(clearRoute: true);
      expect(cleared.route, isNull);
    });

    test('copyWith without clearRoute preserves the existing route', () {
      final m = baseMedicine(route: AdministrationRoute.otic);
      final unchanged = m.copyWith(name: 'Renamed');
      expect(unchanged.route, AdministrationRoute.otic);
    });
  });

  group('NunitoAddMedicationFlow route picker visibility', () {
    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
          MaterialApp(theme: AppTheme.lightTheme, home: const NunitoAddMedicationFlow()));
      await tester.pumpAndSettle();
    }

    // The Type/Route chips can sit below the fold on the default test
    // viewport inside a SingleChildScrollView — scroll to a finder before
    // tapping it, rather than tapping blind.
    Future<void> scrollToAndTap(WidgetTester tester, Finder finder) async {
      await tester.scrollUntilVisible(finder, 200,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    testWidgets('positive: selecting Injection reveals route options',
        (tester) async {
      await pump(tester);
      await scrollToAndTap(tester, find.text('Injection'));

      expect(find.text('Route (optional)'), findsOneWidget);
      await tester.scrollUntilVisible(
          find.text('Subcutaneous injection'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Subcutaneous injection'), findsOneWidget);
      expect(find.text('Intramuscular injection'), findsOneWidget);
      expect(find.text('Intravenous injection'), findsOneWidget);
    });

    testWidgets('positive: selecting Drops reveals a different route set',
        (tester) async {
      await pump(tester);
      await scrollToAndTap(tester, find.text('Drops'));

      expect(find.text('Route (optional)'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Eye'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Eye'), findsOneWidget);
      expect(find.text('Ear'), findsOneWidget);
      expect(find.text('Nasal'), findsOneWidget);
    });

    testWidgets(
        'negative: the default Tablet form shows no route picker at all',
        (tester) async {
      await pump(tester);
      expect(find.text('Route (optional)'), findsNothing);
    });

    testWidgets(
        'negative: switching from Injection back to Tablet hides and clears the route',
        (tester) async {
      await pump(tester);
      await scrollToAndTap(tester, find.text('Injection'));
      await scrollToAndTap(tester, find.text('Subcutaneous injection'));

      await scrollToAndTap(tester, find.text('Tablet'));

      expect(find.text('Route (optional)'), findsNothing);
    });
  });
}
