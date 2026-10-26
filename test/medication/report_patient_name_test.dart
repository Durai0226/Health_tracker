import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/features/medication/models/dependent_profile.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

/// A printed vitals report for a family member did not say whose it was: the
/// adherence report passed the active profile's name, the blood-pressure and
/// blood-sugar reports did not, so two exports for two people were
/// indistinguishable except by reading the rows — an easy way to hand a doctor
/// the wrong person's chart.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    await ActiveProfileService().init();
  });

  tearDown(() async {
    ActiveProfileService().resetForTesting();
    await db.close();
  });

  group('activePatientName', () {
    test('the account holder has no "Patient:" line', () async {
      expect(await MedicineCleanStorageService.activePatientName(), isNull);
    });

    test('a family member is named', () async {
      await MedicineCleanStorageService.addDependent(DependentProfile(
        id: 'dep1',
        name: 'Ada',
        relationship: RelationshipType.child,
      ));
      await ActiveProfileService().setActiveDependent('dep1');
      expect(await MedicineCleanStorageService.activePatientName(), 'Ada');
    });

    test('a profile that no longer exists yields no name rather than a crash',
        () async {
      await ActiveProfileService().setActiveDependent('ghost');
      expect(await MedicineCleanStorageService.activePatientName(), isNull);
    });
  });

  group('every printed report passes it', () {
    // `Printing.sharePdf` is a platform channel, so the export cannot be driven
    // headlessly; the call sites are pinned by source, bounded to the builder
    // call so a stray mention elsewhere cannot satisfy them.
    String callOf(String file, String builder) {
      final src = File(file)
          .readAsStringSync()
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      final from = src.indexOf('$builder(');
      expect(from, greaterThan(-1), reason: '$builder call not found');
      return src.substring(from, src.indexOf(');', from));
    }

    for (final c in const [
      (
        'lib/features/medication/screens/vitals/blood_pressure_report_screen.dart',
        'buildBpPdf'
      ),
      (
        'lib/features/medication/screens/vitals/blood_sugar_report_screen.dart',
        'buildGlucosePdf'
      ),
      (
        'lib/features/medication/screens/nunito_medication_list_screen.dart',
        'buildPdf'
      ),
    ]) {
      test('${c.$2} is given the active profile name', () {
        expect(callOf(c.$1, c.$2),
            contains('patientName: await MedicineCleanStorageService.activePatientName()'));
      });
    }
  });
}
