/// The medicine's own page warns about an allergy on your profile, as it does
/// for a person you look after.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/medication/models/dependent_profile.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_medication_detail_screen.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

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

  EnhancedMedicine aspirin({String? dependentId}) => EnhancedMedicine(
        id: 'm1',
        name: 'Aspirin',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        createdAt: DateTime(2026, 1, 1),
        dependentId: dependentId,
        schedule: MedicineSchedule.onceDaily(hour: 8, minute: 0),
      );

  Future<void> open(WidgetTester tester, EnhancedMedicine med) async {
    await MedicineCleanStorageService.addMedicine(med, stampActiveProfile: false);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(430, 2800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: NunitoMedicationDetailScreen(medicine: med),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> profile(String id, RelationshipType who, List<String>? allergies) =>
      MedicineCleanStorageService.addDependent(DependentProfile(
        id: id,
        name: who == RelationshipType.self ? 'Me' : 'Kid',
        relationship: who,
        allergies: allergies,
      ));

  testWidgets('your own medicine, an allergy on your profile', (tester) async {
    await profile('self', RelationshipType.self, ['Aspirin']);
    await open(tester, aspirin());
    expect(find.text('Warnings & Side Effects'), findsOneWidget);
    expect(find.textContaining('recorded allergy "Aspirin"'), findsOneWidget);
  });

  testWidgets('no allergy on your profile: no warning', (tester) async {
    await profile('self', RelationshipType.self, null);
    await open(tester, aspirin());
    expect(find.textContaining('recorded allergy'), findsNothing);
  });

  testWidgets("a dependent's medicine reads the dependent's allergies, not yours",
      (tester) async {
    await profile('kid', RelationshipType.child, null);
    await profile('self', RelationshipType.self, ['Aspirin']);
    await open(tester, aspirin(dependentId: 'kid'));
    expect(find.textContaining('recorded allergy'), findsNothing);
  });

  testWidgets("and the dependent's own allergy still warns", (tester) async {
    await profile('self', RelationshipType.self, null);
    await profile('kid', RelationshipType.child, ['Aspirin']);
    await open(tester, aspirin(dependentId: 'kid'));
    expect(find.textContaining('recorded allergy "Aspirin"'), findsOneWidget);
  });
}
