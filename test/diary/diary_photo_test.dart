/// A photo on a diary entry: attached, shown, replaced, removed, and cleaned up.
///
/// "Diary: No mood, tags, photos or search" — mood, tags and search came first. A photo
/// is kept as a copy in the app's own storage, is not part of a backup (a JSON file),
/// and goes when the entry, or all data, does.
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
import 'package:tablet_remainder/core/services/photo_sweep.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/photo_thumb.dart';
import 'package:tablet_remainder/features/diary/models/diary_entry.dart';
import 'package:tablet_remainder/features/diary/screens/diary_entry_screen.dart';
import 'package:tablet_remainder/features/diary/screens/diary_screen.dart';
import 'package:tablet_remainder/features/diary/services/diary_storage_service.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

import '../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;
  late Directory base;
  late Directory gallery;
  var clock = DateTime(2026, 11, 2, 12);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    NotificationService().schedulerForTesting = RecordingNotificationScheduler();
    base = Directory.systemTemp.createTempSync('diary_photo_base_');
    gallery = Directory.systemTemp.createTempSync('diary_photo_gallery_');
    clock = DateTime(2026, 11, 2, 12);
    PhotoStore.baseDirectory = () async => base;
    PhotoStore.now = () => clock;
  });

  tearDown(() async {
    PhotoStore.picker = (s) async => null;
    await db.close();
    for (final d in [base, gallery]) {
      if (d.existsSync()) d.deleteSync(recursive: true);
    }
  });

  File shot(String name) => File(p.join(gallery.path, name))..writeAsBytesSync([1, 2, 3]);

  Directory store() => Directory(p.join(base.path, PhotoStore.folderName));

  DiaryEntry entry({String id = 'e1', String? photo}) => DiaryEntry(
        id: id,
        body: 'Walked home in the rain.',
        entryAt: DateTime(2026, 11, 1, 18),
        createdAt: DateTime(2026, 11, 1, 18),
        photoPath: photo,
      );

  Future<void> ioDone(WidgetTester tester) => tester.pumpAndSettle();

  Future<String> keptFile(WidgetTester tester, String name) =>
      PhotoStore.keep(shot(name));

  Future<void> openEditor(WidgetTester tester, {DiaryEntry? existing}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(430, 1200);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute<void>(builder: (_) => DiaryEntryScreen(existing: existing))),
              child: const Text('open editor'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open editor'));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String how) async {
    await tester.tap(find.byWidgetPredicate((w) =>
        w is Semantics &&
        (w.properties.label == 'Add a photo' ||
            w.properties.label == 'Change or remove the photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(how));
    await tester.pumpAndSettle();
    await ioDone(tester);
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byIcon(Symbols.check_rounded).first);
    await tester.pump();
    await ioDone(tester);
  }

  Future<DiaryEntry> stored() async =>
      (await DiaryStorageService.getAll(scopeToActiveProfile: false)).single;

  group('the editor', () {
    testWidgets('offers a photo, and keeps the one picked, with the entry', (tester) async {
      PhotoStore.picker = (s) async => XFile(shot('IMG.jpg').path);
      await openEditor(tester, existing: entry());
      expect(find.text('Add a photo'), findsOneWidget);
      await DiaryStorageService.save(entry());

      await choose(tester, 'Choose from gallery');
      expect(find.text('Change or remove the photo'), findsOneWidget);
      await save(tester);

      final saved = await stored();
      expect(saved.photoPath, isNotNull);
      expect(p.isWithin(store().path, saved.photoPath!), isTrue);
      expect(File(saved.photoPath!).existsSync(), isTrue);
    });

    testWidgets('a photo alone is a change worth confirming before it is thrown away',
        (tester) async {
      PhotoStore.picker = (s) async => XFile(shot('IMG.jpg').path);
      await DiaryStorageService.save(entry());
      await openEditor(tester, existing: entry());

      await choose(tester, 'Take a photo');
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Discard this entry?'), findsOneWidget);
    });

    testWidgets('discarding deletes the picture picked in the editor', (tester) async {
      PhotoStore.picker = (s) async => XFile(shot('IMG.jpg').path);
      await DiaryStorageService.save(entry());
      await openEditor(tester, existing: entry());
      await choose(tester, 'Take a photo');
      expect(store().listSync(), hasLength(1), reason: 'premise');

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      await ioDone(tester);

      expect(store().listSync(), isEmpty);
      expect((await stored()).photoPath, isNull);
    });

    testWidgets('a camera that cannot be used says so, and changes nothing', (tester) async {
      PhotoStore.picker = (s) async => throw StateError('camera_access_denied');
      await DiaryStorageService.save(entry());
      await openEditor(tester, existing: entry());

      await choose(tester, 'Take a photo');

      expect(find.text(PhotoPickFailed.message), findsOneWidget,
          reason: 'or the person would think nothing was tapped');
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Discard this entry?'), findsNothing,
          reason: 'nothing was changed, so there is nothing to discard');
      expect((await stored()).photoPath, isNull);
    });

    testWidgets('leaving the editor while the camera is still open keeps nothing', (tester) async {
      final camera = Completer<XFile?>();
      PhotoStore.picker = (s) => camera.future;
      await DiaryStorageService.save(entry());
      await openEditor(tester, existing: entry());
      await tester.tap(find.byWidgetPredicate((w) =>
          w is Semantics && w.properties.label == 'Add a photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take a photo'));
      await tester.pumpAndSettle();

      // Back, with nothing changed: no question, and the camera is still open.
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(DiaryEntryScreen), findsNothing, reason: 'premise: it is gone');

      camera.complete(XFile(shot('late.jpg').path));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(!store().existsSync() || store().listSync().isEmpty, isTrue,
          reason: 'the editor that asked for it had closed, so nothing will refer to it');
      expect((await stored()).photoPath, isNull);
    });

    testWidgets('a replaced photo\'s file is deleted once the entry is saved', (tester) async {
      final old = await keptFile(tester, 'old.jpg');
      await DiaryStorageService.save(entry(photo: old));
      PhotoStore.picker = (s) async => XFile(shot('new.jpg').path);
      await openEditor(tester, existing: entry(photo: old));

      await choose(tester, 'Choose from gallery');
      expect(File(old).existsSync(), isTrue, reason: 'not before it is saved');
      await save(tester);

      expect(File(old).existsSync(), isFalse);
      final now = (await stored()).photoPath!;
      expect(now, isNot(old));
      expect(File(now).existsSync(), isTrue);
    });

    testWidgets('a removed photo is gone from the entry and the disk', (tester) async {
      final old = await keptFile(tester, 'old.jpg');
      await DiaryStorageService.save(entry(photo: old));
      await openEditor(tester, existing: entry(photo: old));

      await choose(tester, 'Remove photo');
      await save(tester);

      expect((await stored()).photoPath, isNull);
      expect(File(old).existsSync(), isFalse);
    });

    testWidgets('editing the words of an entry with a photo keeps the photo', (tester) async {
      final old = await keptFile(tester, 'old.jpg');
      await DiaryStorageService.save(entry(photo: old));
      await openEditor(tester, existing: entry(photo: old));

      await tester.enterText(find.byType(TextFormField).last, 'Changed my mind.');
      await tester.pump();
      await save(tester);

      final saved = await stored();
      expect((saved.body, saved.photoPath), ('Changed my mind.', old));
      expect(File(old).existsSync(), isTrue);
    });

    testWidgets('a photo that is not on this phone shows as a plain square, and saves as it was',
        (tester) async {
      await DiaryStorageService.save(entry(photo: '/gone/from/this/phone.jpg'));
      await openEditor(tester, existing: entry(photo: '/gone/from/this/phone.jpg'));

      expect(find.byType(PhotoThumb), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('the list', () {
    testWidgets('shows a thumbnail on an entry that has a photo, and none on one that has not',
        (tester) async {
      final photo = await keptFile(tester, 'p.jpg');
      await DiaryStorageService.save(entry(id: 'with', photo: photo));
      await DiaryStorageService.save(entry(id: 'without'));
        tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(430, 1200);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: const DiaryScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(PhotoThumb), findsOneWidget);
    });
  });

  group('the entry\'s photo and the rest of the app', () {
    test('deleting the entry leaves its photo, so that Undo can bring it back', () async {
      final photo = await PhotoStore.keep(shot('p.jpg'));
      final e = entry(photo: photo);
      await DiaryStorageService.save(e);

      await DiaryStorageService.delete('e1');
      expect(File(photo).existsSync(), isTrue, reason: 'Undo is still on offer');

      // What the Diary's Undo does: saves the entry it deleted, as it was.
      await DiaryStorageService.save(e);
      expect((await stored()).photoPath, photo);
      expect(PhotoStore.exists((await stored()).photoPath), isTrue);
    });

    test('and once the entry stays deleted the next start-up sweep removes the photo',
        () async {
      final photo = await PhotoStore.keep(shot('p.jpg'));
      File(photo).setLastModifiedSync(clock.subtract(const Duration(days: 3)));
      await DiaryStorageService.save(entry(photo: photo));
      await DiaryStorageService.delete('e1');

      expect(await PhotoSweep.run(database: db), 1);

      expect(File(photo).existsSync(), isFalse);
    });

    test('deleting an entry that has none is quiet', () async {
      await DiaryStorageService.save(entry());
      await DiaryStorageService.delete('e1');
      expect(await DiaryStorageService.getAll(scopeToActiveProfile: false), isEmpty);
    });

    test('a backup carries the name of a photo, not its path or its picture', () async {
      final photo = await PhotoStore.keep(shot('p.jpg'));
      await DiaryStorageService.save(entry(photo: photo));

      final out = await DiaryStorageService.exportJson();

      expect(out.single.containsKey('photoPath'), isFalse);
      expect(out.single['photoFile'], p.basename(photo));
      expect(out.single.toString(), isNot(contains(base.path)),
          reason: 'a folder means nothing on another phone, or here after a wipe');
    });

    test('a restore over an entry that is here keeps the photo that is here, whatever the file names',
        () async {
      final mine = await PhotoStore.keep(shot('mine.jpg'));
      final other = await PhotoStore.keep(shot('other.jpg'));
      await DiaryStorageService.save(entry(photo: mine));
      final backup = await DiaryStorageService.exportJson();
      backup.single['photoFile'] = p.basename(other);

      await DiaryStorageService.importJson(backup);

      expect((await stored()).photoPath, mine);
    });

    test('an entry with no photo says so as null', () async {
      await DiaryStorageService.save(entry());
      expect((await DiaryStorageService.exportJson()).single['photoFile'], isNull);
    });

    test('an overwrite restore on this phone gives the photos back', () async {
      final photo = await PhotoStore.keep(shot('p.jpg'));
      await DiaryStorageService.save(entry(photo: photo));
      final backup = await DiaryStorageService.exportJson();
      // An overwrite restore (and the rollback of a failed one) empties the rows first.
      await db.delete(db.diaryEntries).go();
      expect(await DiaryStorageService.getAll(scopeToActiveProfile: false), isEmpty,
          reason: 'premise');

      await DiaryStorageService.importJson(backup);

      expect((await stored()).photoPath, photo,
          reason: 'the file is still here, and the backup says which it was');
    });

    test('the same restore on a phone without the file leaves the entry with no photo',
        () async {
      final photo = await PhotoStore.keep(shot('p.jpg'));
      await DiaryStorageService.save(entry(photo: photo));
      final backup = await DiaryStorageService.exportJson();
      await db.delete(db.diaryEntries).go();
      File(photo).deleteSync();

      await DiaryStorageService.importJson(backup);

      expect((await stored()).photoPath, isNull);
    });

    test('a backup cannot name a place: only the last part of what it says is used',
        () async {
      final secret = File(p.join(base.path, 'secret.jpg'))..writeAsBytesSync([1]);
      await PhotoStore.keep(shot('seed.jpg')); // makes the folder
      await DiaryStorageService.importJson([
        {
          'id': 'x',
          'body': 'Crafted.',
          'entryAt': DateTime(2026, 10, 1).toIso8601String(),
          'photoFile': '../secret.jpg',
        }
      ]);

      expect((await stored()).photoPath, isNull, reason: 'it is not in the store');
      expect(secret.existsSync(), isTrue);
    });

    test('a restore over an entry that is here leaves it its photo', () async {
      final photo = await PhotoStore.keep(shot('p.jpg'));
      await DiaryStorageService.save(entry(photo: photo));
      final backup = await DiaryStorageService.exportJson();

      await DiaryStorageService.importJson(backup);

      expect((await stored()).photoPath, photo,
          reason: 'the file has no photo to bring, and must not take this one away');
    });

    test('a restored entry that was not here has no photo, and shows nothing wrong', () async {
      await DiaryStorageService.importJson([
        {
          'id': 'fresh',
          'body': 'From another phone.',
          'entryAt': DateTime(2026, 10, 1).toIso8601String(),
        }
      ]);
      expect((await stored()).photoPath, isNull);
    });

    test('"Delete all data" clears the photos too', () async {
      final a = await PhotoStore.keep(shot('a.jpg'));
      await DiaryStorageService.save(entry(photo: a));

      await CleanStorageService.clearAllPersistentData();

      expect(File(a).existsSync(), isFalse);
      expect(store().existsSync(), isFalse);
    });

    test('the medicine\'s and the entry\'s photos are both swept by a wipe', () async {
      final forMedicine = await PhotoStore.keep(shot('m.jpg'));
      await MedicineCleanStorageService.saveMedicine(EnhancedMedicine(
        id: 'm1',
        name: 'Metformin',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        schedule: MedicineSchedule(
            frequencyType: FrequencyType.onceDaily,
            times: [ScheduledTime(hour: 8, minute: 0)]),
        imagePath: forMedicine,
      ));
      await CleanStorageService.clearAllPersistentData();
      expect(File(forMedicine).existsSync(), isFalse);
    });
  });

  group('sweeping what nothing refers to', () {
    Future<String> aged(String name, {Duration age = const Duration(days: 3)}) async {
      final path = await PhotoStore.keep(shot(name));
      File(path).setLastModifiedSync(clock.subtract(age));
      return path;
    }

    Future<void> medicineWith(String path, {bool deleted = false}) async {
      await MedicineCleanStorageService.saveMedicine(EnhancedMedicine(
        id: 'm1',
        name: 'Metformin',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        schedule: MedicineSchedule(
            frequencyType: FrequencyType.onceDaily,
            times: [ScheduledTime(hour: 8, minute: 0)]),
        imagePath: path,
      ));
      if (deleted) await MedicineCleanStorageService.deleteMedicine('m1');
    }

    test('keeps a photo a medicine or an entry refers to, and removes one nothing does', () async {
      final onMedicine = await aged('a.jpg');
      final onEntry = await aged('b.jpg');
      final orphan = await aged('c.jpg');
      await medicineWith(onMedicine);
      await DiaryStorageService.save(entry(photo: onEntry));

      final n = await PhotoSweep.run(database: db);

      expect(n, 1);
      expect(File(onMedicine).existsSync(), isTrue);
      expect(File(onEntry).existsSync(), isTrue);
      expect(File(orphan).existsSync(), isFalse);
    });

    test('a photo only just picked is not swept, saved or not', () async {
      final fresh = await aged('fresh.jpg', age: const Duration(hours: 1));
      expect(await PhotoSweep.run(database: db), 0);
      expect(File(fresh).existsSync(), isTrue);
    });

    test('a deleted medicine no longer holds its photo', () async {
      final photo = await aged('a.jpg');
      await medicineWith(photo, deleted: true);
      await PhotoSweep.run(database: db);
      expect(File(photo).existsSync(), isFalse);
    });

    test('never deletes anything when it could not read what is in use', () async {
      final photo = await aged('a.jpg');
      // Opened, used and closed: a read after that throws, as one from a database that
      // has gone away would.
      final broken = AppDatabase.forTesting(NativeDatabase.memory());
      await broken.customSelect('SELECT 1').get();
      await broken.close();

      expect(await PhotoSweep.run(database: broken), 0);

      expect(File(photo).existsSync(), isTrue,
          reason: 'a failed read taken as "nothing refers to anything" would be '
              'permission to delete every photo the person has');
    });
  });
}
