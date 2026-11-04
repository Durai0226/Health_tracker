/// A medicine's prescriber, pharmacy, cost and photo, from the form to the database.
///
/// `EnhancedMedicine` had all four and the form had control for none of them (it carried
/// the old values forward, which for a new medicine means nothing); the cost had no
/// column at all. The pharmacy is what the refill errand calls.
library;

import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/core/services/photo_store.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart' show AppButton, AppCard;
import 'package:tablet_remainder/core/widgets/photo_thumb.dart';
import 'package:tablet_remainder/features/medication/models/doctor_pharmacy.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_log.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_add_medication_flow.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_medication_detail_screen.dart';
import 'package:tablet_remainder/features/medication/services/drug_name_catalog.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  tz_data.initializeTimeZones();

  late AppDatabase db;
  late Directory base;
  late Directory gallery;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tz.setLocalLocation(tz.UTC);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    NotificationService().schedulerForTesting = RecordingNotificationScheduler();
    base = Directory.systemTemp.createTempSync('supply_base_');
    gallery = Directory.systemTemp.createTempSync('supply_gallery_');
    PhotoStore.baseDirectory = () async => base;
  });

  tearDown(() async {
    PhotoStore.picker = (s) async => null;
    await db.close();
    for (final d in [base, gallery]) {
      if (d.existsSync()) d.deleteSync(recursive: true);
    }
  });

  EnhancedMedicine metformin({
    String? doctorId,
    String? pharmacyId,
    double? cost,
    String? imagePath,
  }) =>
      EnhancedMedicine(
        id: 'm1',
        name: 'Metformin',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        schedule: MedicineSchedule(
            frequencyType: FrequencyType.onceDaily,
            times: [ScheduledTime(hour: 8, minute: 0)],
            startDate: DateTime(2026, 1, 1)),
        doctorId: doctorId,
        pharmacyId: pharmacyId,
        costPerUnit: cost,
        imagePath: imagePath,
      );

  Future<void> seed({EnhancedMedicine? medicine}) async {
    await MedicineCleanStorageService.addDoctor(
        Doctor(id: 'd1', name: 'Rao', specialty: 'Cardiology'));
    await MedicineCleanStorageService.addPharmacy(
        Pharmacy(id: 'p1', name: 'Corner Chemist', phone: '0123456'));
    await MedicineCleanStorageService.saveMedicine(medicine ?? metformin());
  }

  /// Opens the wizard on the last step, editing [metformin] as it is stored.
  Future<void> openEdit(WidgetTester tester) async {
    await tester.runAsync(DrugNameCatalog.ensureLoaded);
    final edit = (await MedicineCleanStorageService.getMedicine('m1'))!;
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 1800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<bool>(
              builder: (_) =>
                  NunitoAddMedicationFlow(editMedicine: edit, debugInitialStep: 4),
            )),
            child: const Text('host page'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('host page'));
    await tester.pumpAndSettle();
  }

  Future<void> settle(WidgetTester tester, [int n = 20]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> save(WidgetTester tester) async {
    final b = find.widgetWithText(AppButton, 'Save changes');
    await tester.ensureVisible(b);
    await tester.pump();
    await tester.tap(b);
    await settle(tester);
  }

  Future<EnhancedMedicine> stored() async =>
      (await MedicineCleanStorageService.getMedicine('m1'))!;

  Finder costField() => find.byType(TextField).last;

  Future<void> tapRow(WidgetTester tester, String label) async {
    final f = find.text(label).first;
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  /// The words on one of the step's rows: its label and what it says for it.
  List<String> rowTexts(String label) {
    final card = find.ancestor(of: find.text(label).first, matching: find.byType(AppCard)).first;
    return [
      for (final t in find
          .descendant(of: card, matching: find.byType(Text))
          .evaluate()
          .map((e) => e.widget as Text))
        if (t.data != null) t.data!
    ];
  }

  Future<String> keepIn(WidgetTester tester, File f) => PhotoStore.keep(f);

  /// Let what the form has just asked for settle.
  Future<void> copyDone(WidgetTester tester) => tester.pumpAndSettle();

  File photoIn(String name) => File(p.join(gallery.path, name))..writeAsBytesSync([1, 2, 3]);

  group('cost per unit', () {
    testWidgets('is saved, and comes back in the field', (tester) async {
      await seed();
      await openEdit(tester);
      await tester.ensureVisible(costField());
      await tester.enterText(costField(), '2.5');
      await tester.pump();

      await save(tester);

      expect((await stored()).costPerUnit, 2.5);
      await openEdit(tester);
      expect(find.widgetWithText(TextField, '2.5'), findsOneWidget);
    });

    testWidgets('a comma is a decimal point, as it is in the dose', (tester) async {
      await seed();
      await openEdit(tester);
      await tester.ensureVisible(costField());
      await tester.enterText(costField(), '2,5');
      await tester.pump();
      await save(tester);
      expect((await stored()).costPerUnit, 2.5);
    });

    testWidgets('a whole number reads without a ".0"', (tester) async {
      await seed(medicine: metformin(cost: 3));
      await openEdit(tester);
      expect(find.widgetWithText(TextField, '3'), findsOneWidget);
    });

    testWidgets('clearing it saves nothing, not zero', (tester) async {
      await seed(medicine: metformin(cost: 4));
      await openEdit(tester);
      await tester.ensureVisible(costField());
      await tester.enterText(costField(), '');
      await tester.pump();
      await save(tester);
      expect((await stored()).costPerUnit, isNull);
    });

    testWidgets('something that is not a number is said so, and nothing is saved', (tester) async {
      await seed(medicine: metformin(cost: 4));
      await openEdit(tester);
      await tester.ensureVisible(costField());
      await tester.enterText(costField(), 'a lot');
      await tester.pump();

      expect(find.text('Cost per unit should be a number, like 2.50'), findsOneWidget);
      await save(tester);

      expect((await stored()).costPerUnit, 4, reason: 'the medicine is as it was');
      expect(find.text('Save changes'), findsWidgets, reason: 'still on the form');
    });

    testWidgets('a negative or absurd amount is refused', (tester) async {
      await seed();
      await openEdit(tester);
      await tester.ensureVisible(costField());
      for (final bad in ['-1', '99999999', 'NaN', '1e999']) {
        await tester.enterText(costField(), bad);
        await tester.pump();
        expect(find.text('Cost per unit should be a number, like 2.50'), findsOneWidget,
            reason: bad);
      }
      await tester.enterText(costField(), '0');
      await tester.pump();
      expect(find.text('Cost per unit should be a number, like 2.50'), findsNothing,
          reason: 'free is a price');
    });
  });

  group('prescriber and pharmacy', () {
    testWidgets('are not set until chosen', (tester) async {
      await seed();
      await openEdit(tester);
      expect(rowTexts('Prescriber'), contains('Not set'));
      expect(rowTexts('Pharmacy'), contains('Not set'));
    });

    testWidgets('a doctor is chosen from the list and saved', (tester) async {
      await seed();
      await openEdit(tester);

      await tapRow(tester, 'Prescriber');
      expect(find.text('Select doctor'), findsOneWidget);
      await tester.tap(find.text('Dr. Rao'));
      await tester.pumpAndSettle();
      expect(find.text('Rao'), findsOneWidget, reason: 'the row names them');

      await save(tester);
      expect((await stored()).doctorId, 'd1');
    });

    testWidgets('a pharmacy is chosen from the list and saved', (tester) async {
      await seed();
      await openEdit(tester);

      await tapRow(tester, 'Pharmacy');
      expect(find.text('Select pharmacy'), findsOneWidget);
      await tester.tap(find.text('Corner Chemist'));
      await tester.pumpAndSettle();

      await save(tester);
      expect((await stored()).pharmacyId, 'p1');
    });

    testWidgets('an existing link is shown by name, and can be cleared', (tester) async {
      await seed(medicine: metformin(doctorId: 'd1', pharmacyId: 'p1'));
      await openEdit(tester);
      expect(find.text('Rao'), findsOneWidget);
      expect(find.text('Corner Chemist'), findsOneWidget);

      await tester.ensureVisible(find.byTooltip('Clear Prescriber'));
      await tester.tap(find.byTooltip('Clear Prescriber'));
      await tester.pumpAndSettle();
      await save(tester);

      final m = await stored();
      expect(m.doctorId, isNull);
      expect(m.pharmacyId, 'p1', reason: 'the other is left alone');
    });

    testWidgets('a link to something deleted shows as not set and is not saved back',
        (tester) async {
      await seed();
      // Stored pointing at records that are not there (an older delete, or a backup
      // restored without them).
      await MedicineCleanStorageService.saveMedicine(
          metformin(doctorId: 'ghost-doc', pharmacyId: 'ghost-pharm'));
      await openEdit(tester);
      expect(rowTexts('Prescriber'), contains('Not set'));
      expect(rowTexts('Pharmacy'), contains('Not set'));

      await save(tester);
      final m = await stored();
      expect((m.doctorId, m.pharmacyId), (null, null));
    });

    testWidgets('a medicine edited with neither touched keeps what it had', (tester) async {
      await seed(medicine: metformin(doctorId: 'd1', pharmacyId: 'p1', cost: 2));
      await openEdit(tester);
      await save(tester);
      final m = await stored();
      expect((m.doctorId, m.pharmacyId, m.costPerUnit), ('d1', 'p1', 2));
    });
  });

  group('the photo', () {
    Future<void> choose(WidgetTester tester, String how) async {
      await tapRow(tester, 'Photo');
      await tester.tap(find.text(how));
      await tester.pumpAndSettle();
      await copyDone(tester);
    }

    testWidgets('is taken, kept inside the store, shown and saved', (tester) async {
      await seed();
      final shot = photoIn('IMG_1.jpg');
      PhotoStore.picker = (s) async => XFile(shot.path);
      await openEdit(tester);

      await choose(tester, 'Take a photo');
      expect(find.text('Tap to change or remove'), findsOneWidget);
      await save(tester);

      final path = (await stored()).imagePath!;
      expect(p.isWithin(base.path, path), isTrue, reason: 'a copy, not the gallery\'s own file');
      expect(File(path).existsSync(), isTrue);
      expect(shot.existsSync(), isTrue);
    });

    testWidgets('asks the camera for the camera and the gallery for the gallery', (tester) async {
      await seed();
      final sources = <ImageSource>[];
      PhotoStore.picker = (s) async {
        sources.add(s);
        return null;
      };
      await openEdit(tester);
      await choose(tester, 'Take a photo');
      await choose(tester, 'Choose from gallery');
      expect(sources, [ImageSource.camera, ImageSource.gallery]);
    });

    testWidgets('backing out of the camera changes nothing', (tester) async {
      await seed();
      PhotoStore.picker = (s) async => null;
      await openEdit(tester);
      await choose(tester, 'Take a photo');
      expect(find.text('Add one to know it at a glance'), findsOneWidget);
    });

    testWidgets('a replaced photo\'s file is deleted once the change is saved', (tester) async {
      final old = await keepIn(tester, photoIn('old.jpg'));
      await seed(medicine: metformin(imagePath: old));
      PhotoStore.picker = (s) async => XFile(photoIn('new.jpg').path);
      await openEdit(tester);

      await choose(tester, 'Choose from gallery');
      expect(File(old).existsSync(), isTrue, reason: 'not before the change is saved');
      await save(tester);
      await copyDone(tester); // the old file's deletion is real I/O too

      expect(File(old).existsSync(), isFalse);
      final now = (await stored()).imagePath!;
      expect(now, isNot(old));
      expect(File(now).existsSync(), isTrue);
    });

    testWidgets('a removed photo is gone from the medicine and from the disk', (tester) async {
      final old = await keepIn(tester, photoIn('old.jpg'));
      await seed(medicine: metformin(imagePath: old));
      await openEdit(tester);

      await tapRow(tester, 'Photo');
      await tester.tap(find.text('Remove photo'));
      await tester.pumpAndSettle();
      await save(tester);
      await copyDone(tester);

      expect((await stored()).imagePath, isNull);
      expect(File(old).existsSync(), isFalse);
    });

    testWidgets('one picked and then replaced in the same session is not kept', (tester) async {
      await seed();
      var n = 0;
      final firstPath = <String>[];
      PhotoStore.picker = (s) async {
        n++;
        return XFile(photoIn('shot$n.jpg').path);
      };
      await openEdit(tester);

      await choose(tester, 'Take a photo');
      final inStore = Directory(p.join(base.path, PhotoStore.folderName));
      firstPath.addAll(inStore.listSync().map((e) => e.path));
      await choose(tester, 'Take a photo');

      expect(firstPath, hasLength(1), reason: 'premise');
      expect(File(firstPath.single).existsSync(), isFalse,
          reason: 'the first was replaced before anything was saved');
      expect(inStore.listSync(), hasLength(1));
    });

    testWidgets('closing the form without saving deletes the photo picked in it',
        (tester) async {
      await seed();
      PhotoStore.picker = (s) async => XFile(photoIn('shot.jpg').path);
      await openEdit(tester);
      await choose(tester, 'Take a photo');
      final inStore = Directory(p.join(base.path, PhotoStore.folderName));
      expect(inStore.listSync(), hasLength(1), reason: 'premise');

      // Leave the form: it asks, and the answer is to discard.
      await tester.tap(find.byIcon(Symbols.close_rounded).first);
      await tester.pumpAndSettle();
      expect(find.text('Discard'), findsOneWidget, reason: 'a picked photo is work to lose');
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      await copyDone(tester); // the picked photo's deletion is real I/O

      expect(inStore.listSync(), isEmpty,
          reason: 'a picture nothing is going to keep');
      expect((await stored()).imagePath, isNull);
    });

    testWidgets('a camera that cannot be used says so, and changes nothing', (tester) async {
      await seed();
      PhotoStore.picker = (s) async => throw StateError('camera_access_denied');
      await openEdit(tester);

      await choose(tester, 'Take a photo');

      expect(find.text(PhotoPickFailed.message), findsOneWidget,
          reason: 'or the person would think nothing was tapped');
      expect(find.text('Tap to change or remove'), findsNothing);
      await save(tester);
      expect((await stored()).imagePath, isNull);
    });

    testWidgets('leaving the form while the camera is still open keeps nothing', (tester) async {
      await seed();
      final camera = Completer<XFile?>();
      PhotoStore.picker = (s) => camera.future;
      await openEdit(tester);
      await tapRow(tester, 'Photo');
      await tester.tap(find.text('Take a photo'));
      await tester.pumpAndSettle();

      // The person goes back instead of finishing with the camera.
      await tester.tap(find.byIcon(Symbols.close_rounded).first);
      await tester.pumpAndSettle();
      if (find.text('Discard').evaluate().isNotEmpty) {
        await tester.tap(find.text('Discard'));
        await tester.pumpAndSettle();
      }
      expect(find.byType(NunitoAddMedicationFlow), findsNothing, reason: 'premise: it is gone');

      camera.complete(XFile(photoIn('late.jpg').path));
      await settle(tester);

      final inStore = Directory(p.join(base.path, PhotoStore.folderName));
      expect(!inStore.existsSync() || inStore.listSync().isEmpty, isTrue,
          reason: 'the form that asked for it had closed, so nothing will ever refer to it');
      expect((await stored()).imagePath, isNull);
    });

    testWidgets('a photo that is no longer on the phone shows as such, and the form still works',
        (tester) async {
      await seed(medicine: metformin(imagePath: '/gone/from/this/phone.jpg'));
      await openEdit(tester);

      expect(find.byType(PhotoThumb), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
      await save(tester);
      expect((await stored()).imagePath, '/gone/from/this/phone.jpg',
          reason: 'saving the form is not what decides a photo is gone');
    });
  });

  group('on the medicine\'s own screen', () {
    Future<void> openDetail(WidgetTester tester) async {
      final med = (await MedicineCleanStorageService.getMedicine('m1'))!;
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(430, 2800);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: NunitoMedicationDetailScreen(medicine: med),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the prescriber, pharmacy, cost and photo that were set', (tester) async {
      final photo = await keepIn(tester, photoIn('pill.jpg'));
      await seed(medicine: metformin(doctorId: 'd1', pharmacyId: 'p1', cost: 2.5, imagePath: photo));
      await openDetail(tester);

      expect(find.text('Prescriber'), findsOneWidget);
      expect(find.text('Dr. Rao'), findsOneWidget);
      expect(find.text('Pharmacy'), findsOneWidget);
      expect(find.text('Corner Chemist'), findsOneWidget);
      expect(find.text('Cost per unit'), findsOneWidget);
      expect(find.text('2.50'), findsOneWidget);
      expect(find.byType(PhotoThumb), findsOneWidget);
    });

    testWidgets('shows none of them when none were set', (tester) async {
      await seed();
      await openDetail(tester);

      expect(find.text('Prescriber'), findsNothing);
      expect(find.text('Cost per unit'), findsNothing);
      expect(find.byType(PhotoThumb), findsNothing);
    });

    testWidgets('still loads its history when the prescriber cannot be looked up', (tester) async {
      await seed(medicine: metformin(doctorId: 'd1', pharmacyId: 'p1'));
      for (var i = 0; i < 6; i++) {
        final slot = DateTime(2026, 3, 1 + i, 8);
        await MedicineCleanStorageService.addLog(MedicineLog(
          id: MedicineCleanStorageService.doseLogId('m1', slot),
          medicineId: 'm1',
          scheduledTime: slot,
          status: MedicineStatus.taken,
          actionTime: slot,
        ));
      }
      await db.customStatement('ALTER TABLE doctors RENAME TO doctors_x');

      await openDetail(tester);

      expect(find.text('Prescriber'), findsNothing);
      expect(find.text('Show all 6 doses'), findsOneWidget,
          reason: 'what is loaded after the two names was not lost with them');
    });

    testWidgets('leaves out a doctor or pharmacy that has since been deleted', (tester) async {
      await seed(medicine: metformin(doctorId: 'ghost', pharmacyId: 'ghost'));
      await openDetail(tester);

      expect(find.text('Prescriber'), findsNothing);
      expect(find.text('Pharmacy'), findsNothing);
    });

    testWidgets('a photo that is not on this phone is a plain square, not an error', (tester) async {
      await seed(medicine: metformin(imagePath: '/gone/from/this/phone.jpg'));
      await openDetail(tester);

      expect(find.byType(PhotoThumb), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
