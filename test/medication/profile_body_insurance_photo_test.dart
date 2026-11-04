/// A family profile's weight, height, insurance and photo.
///
/// The profile kept all four and the form had a control for none of them: it carried
/// the stored values forward untouched, which for a new profile means "never". The
/// photo is the part that can lose something: it lives in the photo store, so it must
/// be kept on save, let go on replace/remove, thrown away when the form is closed
/// unsaved — and the start-up sweep must know a profile refers to it, or it deletes
/// the picture a day after it was chosen.
library;

import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/photo_store.dart';
import 'package:tablet_remainder/core/services/photo_sweep.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import 'package:tablet_remainder/core/widgets/photo_thumb.dart';
import 'package:tablet_remainder/features/medication/models/dependent_profile.dart';
import 'package:tablet_remainder/features/medication/screens/dependents/add_edit_dependent_screen.dart';
import 'package:tablet_remainder/features/medication/screens/dependents/dependent_list_screen.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

import '../support/font_free_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory base;
  late Directory gallery;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    ActiveProfileService().resetForTesting();
    base = Directory.systemTemp.createTempSync('profile_base_');
    gallery = Directory.systemTemp.createTempSync('profile_gallery_');
    PhotoStore.baseDirectory = () async => base;
  });

  tearDown(() async {
    PhotoStore.picker = (s) async => null;
    await db.close();
    for (final d in [base, gallery]) {
      if (d.existsSync()) d.deleteSync(recursive: true);
    }
  });

  File photoIn(String name) =>
      File(p.join(gallery.path, name))..writeAsBytesSync([1, 2, 3]);

  Future<DependentProfile> addMe({
    double? weight,
    double? height,
    String? insurance,
    String? avatar,
    String? doctor,
  }) async {
    final me = DependentProfile(
      id: 'self',
      name: 'Priya',
      relationship: RelationshipType.self,
      weight: weight,
      height: height,
      insuranceInfo: insurance,
      avatarPath: avatar,
      primaryDoctorId: doctor,
    );
    await MedicineCleanStorageService.addDependent(me);
    return me;
  }

  Future<DependentProfile?> stored() => MedicineCleanStorageService.profileFor(null);

  Future<void> open(WidgetTester tester, DependentProfile? edit) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(430, 3600);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: fontFreeTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<bool>(
                builder: (_) => AddEditDependentScreen(editDependent: edit))),
            child: const Text('host page'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('host page'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Finder field(String label) => find.descendant(
      of: find.widgetWithText(AppTextField, label), matching: find.byType(TextField));

  String textIn(WidgetTester tester, String label) =>
      tester.widget<TextField>(field(label)).controller!.text;

  Future<void> save(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(AppButton, 'Save'));
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pickPhoto(WidgetTester tester, String how) async {
    await tester.tap(find.bySemanticsLabel(RegExp(r'(Add a|Change or remove the) profile photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(how));
    await tester.pumpAndSettle();
  }

  Directory inStore() => Directory(p.join(base.path, PhotoStore.folderName));

  group('weight and height', () {
    testWidgets('are kept, and shown again as they were typed', (tester) async {
      final me = await addMe();
      await open(tester, me);
      await tester.enterText(field('Weight (kg)'), '68.5');
      await tester.enterText(field('Height (cm)'), '172');
      await save(tester);

      final saved = await stored();
      expect(saved?.weight, 68.5);
      expect(saved?.height, 172);

      await open(tester, saved);
      expect(textIn(tester, 'Weight (kg)'), '68.5');
      expect(textIn(tester, 'Height (cm)'), '172',
          reason: 'a whole number reads without a ".0"');
    });

    testWidgets('a comma is a decimal point', (tester) async {
      final me = await addMe();
      await open(tester, me);
      await tester.enterText(field('Weight (kg)'), '68,5');
      await save(tester);

      expect((await stored())?.weight, 68.5);
    });

    testWidgets('emptied, they are removed — not saved as zero', (tester) async {
      final me = await addMe(weight: 70, height: 170);
      await open(tester, me);
      await tester.enterText(field('Weight (kg)'), '');
      await tester.enterText(field('Height (cm)'), '');
      await save(tester);

      final saved = await stored();
      expect(saved?.weight, isNull);
      expect(saved?.height, isNull);
    });

    testWidgets('left alone, they survive saving something else', (tester) async {
      final me = await addMe(weight: 70, height: 170);
      await open(tester, me);
      await tester.enterText(field('Allergies'), 'Penicillin');
      await save(tester);

      final saved = await stored();
      expect(saved?.weight, 70);
      expect(saved?.height, 170);
    });

    for (final bad in ['abc', '1', '600', '-5', 'NaN']) {
      testWidgets('weight "$bad" is refused and nothing is saved', (tester) async {
        final me = await addMe(weight: 70);
        await open(tester, me);
        await tester.enterText(field('Weight (kg)'), bad);
        await save(tester);

        expect(find.textContaining('Enter 2 to 500 kg'), findsOneWidget);
        expect((await stored())?.weight, 70);
      });
    }

    for (final bad in ['abc', '10', '300', '0']) {
      testWidgets('height "$bad" is refused and nothing is saved', (tester) async {
        final me = await addMe(height: 170);
        await open(tester, me);
        await tester.enterText(field('Height (cm)'), bad);
        await save(tester);

        expect(find.textContaining('Enter 30 to 260 cm'), findsOneWidget);
        expect((await stored())?.height, 170);
      });
    }

    testWidgets('the limits themselves are allowed', (tester) async {
      final me = await addMe();
      await open(tester, me);
      await tester.enterText(field('Weight (kg)'), '2');
      await tester.enterText(field('Height (cm)'), '260');
      await save(tester);

      final saved = await stored();
      expect(saved?.weight, 2);
      expect(saved?.height, 260);
    });
  });

  group('insurance', () {
    testWidgets('is trimmed, kept and shown again', (tester) async {
      final me = await addMe();
      await open(tester, me);
      await tester.enterText(field('Insurance'), '  Acme Health 12345  ');
      await save(tester);

      final saved = await stored();
      expect(saved?.insuranceInfo, 'Acme Health 12345');
      await open(tester, saved);
      expect(textIn(tester, 'Insurance'), 'Acme Health 12345');
    });

    testWidgets('emptied, it is removed', (tester) async {
      final me = await addMe(insurance: 'Acme');
      await open(tester, me);
      await tester.enterText(field('Insurance'), '   ');
      await save(tester);

      expect((await stored())?.insuranceInfo, isNull);
    });

    testWidgets('a wall of text is refused', (tester) async {
      final me = await addMe(insurance: 'Acme');
      await open(tester, me);
      await tester.enterText(field('Insurance'), 'x' * 201);
      await save(tester);

      expect(find.textContaining('under 200 characters'), findsOneWidget);
      expect((await stored())?.insuranceInfo, 'Acme');
    });

    testWidgets('the most that is allowed is allowed', (tester) async {
      final me = await addMe();
      await open(tester, me);
      await tester.enterText(field('Insurance'), 'x' * 200);
      await save(tester);

      expect((await stored())?.insuranceInfo, hasLength(200));
    });

    testWidgets('saving something else leaves the preferred doctor alone',
        (tester) async {
      final me = await addMe(doctor: 'd1', insurance: 'Acme');
      await open(tester, me);
      await tester.enterText(field('Allergies'), 'Penicillin');
      await save(tester);

      final saved = await stored();
      expect(saved?.primaryDoctorId, 'd1',
          reason: 'the form has no control for it, so it must be carried');
      expect(saved?.insuranceInfo, 'Acme');
    });
  });

  group('the photo', () {
    testWidgets('is kept inside the store and saved on the profile', (tester) async {
      final me = await addMe();
      final shot = photoIn('IMG_1.jpg');
      PhotoStore.picker = (s) async => XFile(shot.path);
      await open(tester, me);

      await pickPhoto(tester, 'Take a photo');
      await save(tester);

      final path = (await stored())!.avatarPath!;
      expect(p.isWithin(base.path, path), isTrue,
          reason: 'a copy in the store, not the gallery\'s own file');
      expect(File(path).existsSync(), isTrue);
      expect(shot.existsSync(), isTrue);
    });

    testWidgets('asks the camera for the camera and the gallery for the gallery',
        (tester) async {
      final me = await addMe();
      final sources = <ImageSource>[];
      PhotoStore.picker = (s) async {
        sources.add(s);
        return null;
      };
      await open(tester, me);

      await pickPhoto(tester, 'Take a photo');
      await pickPhoto(tester, 'Choose from gallery');

      expect(sources, [ImageSource.camera, ImageSource.gallery]);
    });

    testWidgets('is shown in the avatar once chosen', (tester) async {
      final me = await addMe();
      PhotoStore.picker = (s) async => XFile(photoIn('IMG_1.jpg').path);
      await open(tester, me);
      expect(find.byType(PhotoThumb), findsNothing);

      await pickPhoto(tester, 'Choose from gallery');

      expect(find.byType(PhotoThumb), findsOneWidget);
    });

    testWidgets('a replaced photo\'s file is deleted once the change is saved',
        (tester) async {
      final old = await PhotoStore.keep(photoIn('old.jpg'));
      final me = await addMe(avatar: old);
      PhotoStore.picker = (s) async => XFile(photoIn('new.jpg').path);
      await open(tester, me);

      await pickPhoto(tester, 'Choose from gallery');
      expect(File(old).existsSync(), isTrue, reason: 'not before it is saved');
      await save(tester);

      expect(File(old).existsSync(), isFalse);
      final now = (await stored())!.avatarPath!;
      expect(now, isNot(old));
      expect(File(now).existsSync(), isTrue);
    });

    testWidgets('a removed photo is gone from the profile and from the disk',
        (tester) async {
      final old = await PhotoStore.keep(photoIn('old.jpg'));
      final me = await addMe(avatar: old);
      await open(tester, me);

      await pickPhoto(tester, 'Remove photo');
      await save(tester);

      expect((await stored())!.avatarPath, isNull);
      expect(File(old).existsSync(), isFalse);
    });

    testWidgets('one picked and then replaced in the same session is not kept',
        (tester) async {
      final me = await addMe();
      var n = 0;
      PhotoStore.picker = (s) async => XFile(photoIn('shot${++n}.jpg').path);
      await open(tester, me);

      await pickPhoto(tester, 'Take a photo');
      final first = inStore().listSync().map((e) => e.path).toList();
      await pickPhoto(tester, 'Take a photo');

      expect(first, hasLength(1), reason: 'premise');
      expect(File(first.single).existsSync(), isFalse,
          reason: 'replaced before anything was saved — nothing else holds it');
      expect(inStore().listSync(), hasLength(1));
    });

    testWidgets('closing the form without saving deletes what was picked in it',
        (tester) async {
      final me = await addMe();
      PhotoStore.picker = (s) async => XFile(photoIn('shot.jpg').path);
      await open(tester, me);
      await pickPhoto(tester, 'Take a photo');
      expect(inStore().listSync(), hasLength(1), reason: 'premise');

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      expect(inStore().listSync(), isEmpty);
      expect((await stored())!.avatarPath, isNull);
    });

    testWidgets('and one that was already on the profile is not touched by that',
        (tester) async {
      final old = await PhotoStore.keep(photoIn('old.jpg'));
      final me = await addMe(avatar: old);
      await open(tester, me);

      await pickPhoto(tester, 'Remove photo');
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      expect(File(old).existsSync(), isTrue,
          reason: 'removed in the form, but the form was never saved');
      expect((await stored())!.avatarPath, old);
    });

    testWidgets('a camera that cannot be used says so, and changes nothing',
        (tester) async {
      final me = await addMe();
      PhotoStore.picker = (s) async => throw StateError('camera_access_denied');
      await open(tester, me);

      await pickPhoto(tester, 'Take a photo');

      expect(find.text(PhotoPickFailed.message), findsOneWidget);
      await save(tester);
      expect((await stored())!.avatarPath, isNull);
    });

    testWidgets('backing out of the camera changes nothing', (tester) async {
      final me = await addMe();
      PhotoStore.picker = (s) async => null;
      await open(tester, me);

      await pickPhoto(tester, 'Take a photo');

      expect(find.byType(PhotoThumb), findsNothing);
      expect(inStore().existsSync() ? inStore().listSync() : const [], isEmpty);
    });

    testWidgets('leaving the form while the camera is still open keeps nothing',
        (tester) async {
      final me = await addMe();
      final camera = Completer<XFile?>();
      PhotoStore.picker = (s) => camera.future;
      await open(tester, me);
      await tester.tap(find.bySemanticsLabel(RegExp(r'(Add a|Change or remove the) profile photo')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take a photo'));
      await tester.pump();

      // The person goes back instead of finishing with the camera.
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(AddEditDependentScreen), findsNothing,
          reason: 'premise: the form is gone');

      camera.complete(XFile(photoIn('late.jpg').path));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(inStore().existsSync() ? inStore().listSync() : const [], isEmpty,
          reason: 'a picture nothing is going to keep');
      expect((await stored())!.avatarPath, isNull);
    });

    testWidgets('a photo the phone no longer has shows the icon, not a broken box',
        (tester) async {
      final me = await addMe(avatar: '/gone/for/good.jpg');
      await open(tester, me);

      expect(find.byType(PhotoThumb), findsNothing);
      expect(find.byType(Image), findsNothing);
    });
  });

  group('the sweep', () {
    testWidgets('keeps a profile\'s photo, and still removes one nothing refers to',
        (tester) async {
      final kept = await PhotoStore.keep(photoIn('face.jpg'));
      final stray = await PhotoStore.keep(photoIn('stray.jpg'));
      await addMe(avatar: kept);
      // Old enough to be collected: a sweep spares anything made in the last day.
      final old = DateTime.now().subtract(const Duration(days: 3));
      File(kept).setLastModifiedSync(old);
      File(stray).setLastModifiedSync(old);

      final n = await tester.runAsync(() => PhotoSweep.run(database: db));

      expect(n, 1);
      expect(File(kept).existsSync(), isTrue,
          reason: 'a profile refers to it — without this the sweep deletes the '
              'picture the day after it is chosen');
      expect(File(stray).existsSync(), isFalse);
    });

    testWidgets('keeps the photo of a profile that is not the active one',
        (tester) async {
      final kept = await PhotoStore.keep(photoIn('gran.jpg'));
      await addMe();
      await MedicineCleanStorageService.addDependent(DependentProfile(
          id: 'gran',
          name: 'Gran',
          relationship: RelationshipType.grandparent,
          avatarPath: kept));
      File(kept).setLastModifiedSync(DateTime.now().subtract(const Duration(days: 3)));

      await tester.runAsync(() => PhotoSweep.run(database: db));

      expect(File(kept).existsSync(), isTrue);
    });
  });

  group('the list', () {
    testWidgets('shows a profile\'s photo, and the relationship icon for one without',
        (tester) async {
      final face = await PhotoStore.keep(photoIn('face.jpg'));
      await addMe(avatar: face);
      await MedicineCleanStorageService.addDependent(DependentProfile(
          id: 'kid', name: 'Kiran', relationship: RelationshipType.child));
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(430, 1600);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
          theme: fontFreeTheme(), home: const DependentListScreen()));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(PhotoThumb), findsOneWidget,
          reason: 'one profile has a photo, the other does not');
    });

    testWidgets('a photo the phone no longer has is the icon, not a broken thumbnail',
        (tester) async {
      await addMe(avatar: '/gone/for/good.jpg');
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(430, 1600);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
          theme: fontFreeTheme(), home: const DependentListScreen()));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(PhotoThumb), findsNothing);
    });
  });
}
