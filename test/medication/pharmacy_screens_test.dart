/// Pharmacies: added, linked, called and deleted.
///
/// The table, its storage methods and the refill errand that calls a medicine's
/// pharmacy all existed; nothing could add a pharmacy, so the refill's "call the
/// pharmacy" was unreachable.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/contact_launcher.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/medication/models/doctor_pharmacy.dart';
import 'package:tablet_remainder/features/medication/screens/pharmacies/nunito_add_edit_pharmacy_screen.dart';
import 'package:tablet_remainder/features/medication/screens/pharmacies/nunito_pharmacy_list_screen.dart';
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
  });

  tearDown(() async => db.close());

  const size = Size(390, 844);

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(size: size),
      child: MaterialApp(theme: AppTheme.lightTheme, home: home),
    ));
    await tester.pumpAndSettle();
  }

  /// The form's fields in the order they are laid out: name, phone, address, hours,
  /// notes. By position, since the labels are drawn outside the field.
  Finder field(int i) => find.byType(TextFormField).at(i);

  Pharmacy corner() => Pharmacy(
        id: 'p1',
        name: 'Corner Chemist',
        phone: '0123456',
        address: '4 High Street',
        hours: '9 am – 9 pm',
        hasDelivery: true,
        notes: 'Ask for Priya',
      );

  group('the list', () {
    testWidgets('says there are none, and offers to add one', (tester) async {
      await pump(tester, const NunitoPharmacyListScreen());
      expect(find.text('No pharmacies added'), findsOneWidget);
      expect(find.text('Add pharmacy'), findsOneWidget);
    });

    testWidgets('shows a pharmacy with its hours, address and delivery', (tester) async {
      await MedicineCleanStorageService.addPharmacy(corner());
      await pump(tester, const NunitoPharmacyListScreen());

      expect(find.text('Corner Chemist'), findsOneWidget);
      expect(find.text('9 am – 9 pm · 4 High Street'), findsOneWidget);
      expect(find.text('Delivers'), findsOneWidget);
      expect(find.byTooltip('Call'), findsOneWidget);
    });

    testWidgets('has no Call button for a pharmacy with no number', (tester) async {
      await MedicineCleanStorageService.addPharmacy(Pharmacy(id: 'p2', name: 'No phone'));
      await pump(tester, const NunitoPharmacyListScreen());
      expect(find.byTooltip('Call'), findsNothing);
    });

    testWidgets('Call opens the dialer on the digits of the number, not the text typed',
        (tester) async {
      Uri? opened;
      ContactLauncher.launcherOverride = (uri) async {
        opened = uri;
        return true;
      };
      addTearDown(() => ContactLauncher.launcherOverride = null);
      await MedicineCleanStorageService.addPharmacy(
          Pharmacy(id: 'p3', name: 'Night Chemist', phone: '+91 (98765) 43-210 #2'));
      await pump(tester, const NunitoPharmacyListScreen());

      await tester.tap(find.byTooltip('Call'));
      await tester.pump();

      expect(opened.toString(), 'tel:+9198765432102',
          reason: 'a space or a # in a typed number is not part of a URI');
    });

    testWidgets('and says so when there is no dialer to open', (tester) async {
      ContactLauncher.launcherOverride = (uri) async => false;
      addTearDown(() => ContactLauncher.launcherOverride = null);
      await MedicineCleanStorageService.addPharmacy(corner());
      await pump(tester, const NunitoPharmacyListScreen());

      await tester.tap(find.byTooltip('Call'));
      await tester.pump();

      expect(find.text('No phone app is available on this device.'), findsOneWidget);
    });

    testWidgets('a delete that fails says so, and the pharmacy stays listed', (tester) async {
      await MedicineCleanStorageService.addPharmacy(corner());
      await pump(tester, const NunitoPharmacyListScreen());
      await db.customStatement('DROP TABLE pharmacies');

      await tester.drag(find.text('Corner Chemist'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't delete the pharmacy. Please try again."), findsOneWidget);
      expect(find.text('Corner Chemist'), findsOneWidget);
    });

    testWidgets('adds one: the name is required, and what is typed is kept', (tester) async {
      await pump(tester, const NunitoPharmacyListScreen());
      await tester.tap(find.text('Add pharmacy').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Name is required'), findsOneWidget);
      expect(await MedicineCleanStorageService.getAllPharmacies(), isEmpty);

      await tester.enterText(field(0), '  Corner Chemist ');
      await tester.enterText(field(1), '0123456');
      await tester.enterText(field(3), 'Open 24 hours');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = (await MedicineCleanStorageService.getAllPharmacies()).single;
      expect((saved.name, saved.phone, saved.hours, saved.hasDelivery),
          ('Corner Chemist', '0123456', 'Open 24 hours', false));
      expect(saved.address, isNull, reason: 'a blank field is nothing, not an empty string');
      expect(find.text('Corner Chemist'), findsOneWidget, reason: 'back on the list, with it');
    });

    testWidgets('opens one to edit, and a change is saved over it, not beside it',
        (tester) async {
      await MedicineCleanStorageService.addPharmacy(corner());
      await pump(tester, const NunitoPharmacyListScreen());

      await tester.tap(find.text('Corner Chemist'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'Corner Chemist'), findsOneWidget);
      expect(find.text('Edit pharmacy'), findsOneWidget);

      await tester.enterText(field(0), 'High St Chemist');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final all = await MedicineCleanStorageService.getAllPharmacies();
      expect(all.map((p) => p.name), ['High St Chemist']);
      expect(all.single.notes, 'Ask for Priya', reason: 'what was not touched is kept');
    });

    testWidgets('the delivery switch is saved', (tester) async {
      await pump(tester, const NunitoAddEditPharmacyScreen());
      await tester.enterText(field(0), 'Night Pharmacy');
      await tester.tap(find.text('Delivers'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect((await MedicineCleanStorageService.getAllPharmacies()).single.hasDelivery, isTrue);
    });

    testWidgets('a swipe asks, and only Delete deletes', (tester) async {
      await MedicineCleanStorageService.addPharmacy(corner());
      await pump(tester, const NunitoPharmacyListScreen());

      await tester.drag(find.text('Corner Chemist'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('Delete pharmacy?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await MedicineCleanStorageService.getAllPharmacies(), hasLength(1));

      await tester.drag(find.text('Corner Chemist'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(await MedicineCleanStorageService.getAllPharmacies(), isEmpty);
      expect(find.text('No pharmacies added'), findsOneWidget);
    });
  });

  group('picking one for a medicine', () {
    testWidgets('a tap returns the pharmacy instead of opening it', (tester) async {
      await MedicineCleanStorageService.addPharmacy(corner());
      Pharmacy? picked;
      await pump(
          tester,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => picked = await Navigator.push<Pharmacy>(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const NunitoPharmacyListScreen(isSelectionMode: true))),
                child: const Text('pick'),
              ),
            ),
          ));
      await tester.tap(find.text('pick'));
      await tester.pumpAndSettle();
      expect(find.text('Select pharmacy'), findsOneWidget);

      await tester.tap(find.text('Corner Chemist'));
      await tester.pumpAndSettle();

      expect(picked?.id, 'p1');
    });

    testWidgets('adding one while picking returns the new one', (tester) async {
      Pharmacy? picked;
      await pump(
          tester,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => picked = await Navigator.push<Pharmacy>(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const NunitoPharmacyListScreen(isSelectionMode: true))),
                child: const Text('pick'),
              ),
            ),
          ));
      await tester.tap(find.text('pick'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add pharmacy').first);
      await tester.pumpAndSettle();
      await tester.enterText(field(0), 'New One');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(picked?.name, 'New One', reason: 'the one just made is the one they came for');
    });
  });
}
