/// Where a photo is kept, and what may be deleted.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:tablet_remainder/core/services/photo_store.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/photo_thumb.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory base;
  late Directory elsewhere;
  var clock = DateTime(2026, 11, 2, 12);

  setUp(() {
    base = Directory.systemTemp.createTempSync('photo_store_base_');
    elsewhere = Directory.systemTemp.createTempSync('photo_store_else_');
    clock = DateTime(2026, 11, 2, 12);
    PhotoStore.baseDirectory = () async => base;
    PhotoStore.now = () => clock;
  });

  tearDown(() {
    PhotoStore.picker = (source) async => null;
    for (final d in [base, elsewhere]) {
      if (d.existsSync()) d.deleteSync(recursive: true);
    }
  });

  File source(String name, {List<int> bytes = const [1, 2, 3]}) =>
      File(p.join(elsewhere.path, name))..writeAsBytesSync(bytes);

  Directory store() => Directory(p.join(base.path, PhotoStore.folderName));

  group('keeping', () {
    test('copies the picture into the store, and the original is left where it was',
        () async {
      final src = source('IMG_1.JPG', bytes: [9, 8, 7]);

      final path = await PhotoStore.keep(src);

      expect(p.isWithin(store().path, path), isTrue);
      expect(File(path).readAsBytesSync(), [9, 8, 7]);
      expect(src.existsSync(), isTrue, reason: 'the gallery\'s own file is not ours');
      expect(p.extension(path), '.jpg', reason: 'the extension, lower-cased');
    });

    test('a picture with no extension is kept as .jpg', () async {
      expect(p.extension(await PhotoStore.keep(source('noext'))), '.jpg');
    });

    test('two pictures never share a name', () async {
      final a = await PhotoStore.keep(source('a.jpg'));
      final b = await PhotoStore.keep(source('a.jpg'));
      expect(a, isNot(b));
    });

    test('pickAndKeep keeps what the picker returns', () async {
      final src = source('shot.png');
      PhotoStore.picker = (s) async => XFile(src.path);
      final path = await PhotoStore.pickAndKeep(ImageSource.camera);
      expect(path, isNotNull);
      expect(PhotoStore.exists(path), isTrue);
    });

    test('and does nothing when the person backs out', () async {
      PhotoStore.picker = (s) async => null;
      expect(await PhotoStore.pickAndKeep(ImageSource.gallery), isNull);
      expect(store().existsSync(), isFalse, reason: 'not even a folder made for nothing');
    });

    test('and says so when the camera or the gallery cannot be used', () async {
      PhotoStore.picker = (s) async => throw StateError('camera_access_denied');
      await expectLater(PhotoStore.pickAndKeep(ImageSource.camera),
          throwsA(isA<PhotoPickFailed>()),
          reason: 'not the same as backing out: the person has to be told');
    });

    test('and says so when the picture cannot be copied', () async {
      PhotoStore.picker = (s) async => XFile(p.join(elsewhere.path, 'vanished.jpg'));
      await expectLater(PhotoStore.pickAndKeep(ImageSource.gallery),
          throwsA(isA<PhotoPickFailed>()));
      expect(store().existsSync() ? store().listSync() : const [], isEmpty);
    });
  });

  group('deleting', () {
    test('removes a kept photo', () async {
      final path = await PhotoStore.keep(source('a.jpg'));
      await PhotoStore.delete(path);
      expect(File(path).existsSync(), isFalse);
    });

    test('never removes a file outside the store, whoever names it', () async {
      final outside = source('precious.jpg');
      await PhotoStore.keep(source('seed.jpg')); // makes the folder
      await PhotoStore.delete(outside.path);
      expect(outside.existsSync(), isTrue,
          reason: 'a path read out of a database or a backup is not to be trusted');
    });

    test('nor one reached by climbing out of it', () async {
      final outside = File(p.join(base.path, 'secret.txt'))..writeAsStringSync('x');
      await PhotoStore.keep(source('seed.jpg'));
      await PhotoStore.delete(p.join(store().path, '..', 'secret.txt'));
      expect(outside.existsSync(), isTrue);
    });

    test('is quiet about a path that is empty, null or already gone', () async {
      await PhotoStore.delete(null);
      await PhotoStore.delete('');
      final path = await PhotoStore.keep(source('a.jpg'));
      await PhotoStore.delete(path);
      await PhotoStore.delete(path);
    });
  });

  group('a path saved before the app\'s folder moved', () {
    // What an iPhone restored to a new phone holds: the old container's path to a file
    // that is now in the new one.
    String stale(String path) =>
        p.join('/old/container/Documents', PhotoStore.folderName, p.basename(path));

    test('still finds its photo, by its name', () async {
      final path = await PhotoStore.keep(source('a.jpg'));

      expect(PhotoStore.resolve(stale(path)), path);
      expect(PhotoStore.exists(stale(path)), isTrue);
    });

    test('is not mistaken for a photo that is not there', () async {
      await PhotoStore.keep(source('a.jpg'));
      expect(PhotoStore.resolve(stale('/else/b.jpg')), isNull);
    });

    test('is found once the store has been located, and taken as it stands until then',
        () async {
      store().createSync(recursive: true);
      final file = File(p.join(store().path, 'a.jpg'))..writeAsBytesSync([1]);
      expect(PhotoStore.resolve(stale(file.path)), isNull, reason: 'the store is not known yet');
      expect(PhotoStore.resolve(file.path), file.path, reason: 'a path as it stands');

      await PhotoStore.warmUp();

      expect(PhotoStore.resolve(stale(file.path)), file.path);
    });

    test('is not read as the place of a file outside the store, once the store is known',
        () async {
      await PhotoStore.keep(source('seed.jpg'));
      final outside = source('outside.jpg');
      expect(PhotoStore.resolve(outside.path), isNull);
    });

    test('is deleted by its name', () async {
      final path = await PhotoStore.keep(source('a.jpg'));
      await PhotoStore.delete(stale(path));
      expect(File(path).existsSync(), isFalse);
    });

    test('is a reference to its photo, for the sweep', () async {
      final old = clock.subtract(const Duration(days: 3));
      final a = File(await PhotoStore.keep(source('a.jpg')))..setLastModifiedSync(old);
      final b = File(await PhotoStore.keep(source('b.jpg')))..setLastModifiedSync(old);

      final n = await PhotoStore.sweep({stale(a.path)});

      expect(n, 1);
      expect(a.existsSync(), isTrue, reason: 'the photo it names is the one that is kept');
      expect(b.existsSync(), isFalse);
    });
  });

  group('a photo as a backup names it', () {
    test('is its file name, and only that', () {
      expect(PhotoStore.fileNameOf('/data/app/photos/ab12.jpg'), 'ab12.jpg');
      expect(PhotoStore.fileNameOf(null), isNull);
      expect(PhotoStore.fileNameOf(''), isNull);
    });

    test('is found in the store by that name', () async {
      final path = await PhotoStore.keep(source('a.jpg'));
      expect(await PhotoStore.locate(p.basename(path)), path);
    });

    test('is not found for a photo that is not on this phone', () async {
      await PhotoStore.keep(source('seed.jpg'));
      expect(await PhotoStore.locate('missing.jpg'), isNull);
      expect(await PhotoStore.locate(null), isNull);
      expect(await PhotoStore.locate(''), isNull);
    });

    test('cannot name a place: a folder in it is ignored', () async {
      File(p.join(base.path, 'secret.jpg')).writeAsBytesSync([1]);
      await PhotoStore.keep(source('seed.jpg'));
      expect(await PhotoStore.locate('../secret.jpg'), isNull);
      expect(await PhotoStore.locate('..'), isNull);
      expect(await PhotoStore.locate('.'), isNull);
    });
  });

  group('what exists', () {
    test('is a file that is there', () async {
      final path = await PhotoStore.keep(source('a.jpg'));
      expect(PhotoStore.exists(path), isTrue);
      await PhotoStore.delete(path);
      expect(PhotoStore.exists(path), isFalse);
      expect(PhotoStore.exists(null), isFalse);
      expect(PhotoStore.exists(''), isFalse);
      expect(PhotoStore.exists('/not/a/real/place.jpg'), isFalse,
          reason: 'what a backup restored on another phone points at');
    });
  });

  group('sweeping', () {
    Future<String> keptAt(String name, DateTime modified) async {
      final path = await PhotoStore.keep(source(name));
      File(path).setLastModifiedSync(modified);
      return path;
    }

    test('removes the old photos nothing refers to, and only those', () async {
      final old = clock.subtract(const Duration(days: 3));
      final kept = await keptAt('kept.jpg', old);
      final orphan = await keptAt('orphan.jpg', old);

      final n = await PhotoStore.sweep({kept});

      expect(n, 1);
      expect(File(kept).existsSync(), isTrue);
      expect(File(orphan).existsSync(), isFalse);
    });

    test('leaves a photo that has only just been picked, saved or not', () async {
      final fresh = await keptAt('fresh.jpg', clock.subtract(const Duration(hours: 2)));
      expect(await PhotoStore.sweep(const {}), 0);
      expect(File(fresh).existsSync(), isTrue,
          reason: 'it may be on a form the person has not saved yet');
    });

    test('the age limit is the caller\'s to choose', () async {
      final f = await keptAt('f.jpg', clock.subtract(const Duration(hours: 2)));
      expect(await PhotoStore.sweep(const {}, grace: const Duration(hours: 1)), 1);
      expect(File(f).existsSync(), isFalse);
    });

    test('does nothing to a store that has never been made', () async {
      expect(await PhotoStore.sweep(const {}), 0);
    });

    test('ignores anything in the folder that is not a file, however old', () async {
      await keptAt('a.jpg', clock.subtract(const Duration(days: 3)));
      Directory(p.join(store().path, 'sub')).createSync();
      // A month on, so the folder just made is older than the age limit too: only
      // being a folder keeps it.
      clock = DateTime.now().add(const Duration(days: 30));

      expect(await PhotoStore.sweep(const {}), 1, reason: 'the picture, and not the folder');
      expect(Directory(p.join(store().path, 'sub')).existsSync(), isTrue);
    });
  });

  test('clearAll empties the store, folder and all', () async {
    await PhotoStore.keep(source('a.jpg'));
    await PhotoStore.keep(source('b.jpg'));
    await PhotoStore.clearAll();
    expect(store().existsSync(), isFalse);
    await PhotoStore.clearAll(); // and again, with nothing there
  });

  group('a form\'s photos', () {
    Future<PhotoSession> sessionWith({String? original}) async {
      var n = 0;
      PhotoStore.picker = (s) async => XFile(source('shot${++n}.jpg').path);
      return PhotoSession(original: original);
    }

    test('one picked is kept, and a second picked after it replaces it', () async {
      final session = await sessionWith();
      final a = (await session.pick(ImageSource.camera))!;
      final b = (await session.pick(ImageSource.camera))!;
      await session.replaced(a);

      expect(File(a).existsSync(), isFalse, reason: 'picked here and replaced here: no use');
      expect(File(b).existsSync(), isTrue);
    });

    test('the photo the thing already had is NOT deleted when it is replaced, only when saved',
        () async {
      final original = await PhotoStore.keep(source('original.jpg'));
      final session = await sessionWith(original: original);
      final picked = (await session.pick(ImageSource.gallery))!;

      await session.replaced(original);
      expect(File(original).existsSync(), isTrue, reason: 'the change may never be saved');

      await session.commit(picked);
      expect(File(original).existsSync(), isFalse);
      expect(File(picked).existsSync(), isTrue);
    });

    test('saving with the same photo it started with deletes nothing', () async {
      final original = await PhotoStore.keep(source('original.jpg'));
      final session = await sessionWith(original: original);
      await session.commit(original);
      expect(File(original).existsSync(), isTrue);
    });

    test('saving with the photo removed deletes the one it had', () async {
      final original = await PhotoStore.keep(source('original.jpg'));
      final session = await sessionWith(original: original);
      await session.commit(null);
      expect(File(original).existsSync(), isFalse);
    });

    test('saving drops what was picked and then not used', () async {
      final session = await sessionWith();
      final a = (await session.pick(ImageSource.camera))!;
      final b = (await session.pick(ImageSource.camera))!;
      await session.commit(b);
      expect(File(a).existsSync(), isFalse);
      expect(File(b).existsSync(), isTrue);
    });

    test('closing without saving deletes everything picked, and leaves the original', () async {
      final original = await PhotoStore.keep(source('original.jpg'));
      final session = await sessionWith(original: original);
      final picked = (await session.pick(ImageSource.camera))!;

      session.close();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(File(picked).existsSync(), isFalse);
      expect(File(original).existsSync(), isTrue);
    });

    test('closing after saving does not delete what was saved', () async {
      final session = await sessionWith();
      final picked = (await session.pick(ImageSource.camera))!;
      await session.commit(picked);
      session.close();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(File(picked).existsSync(), isTrue);
    });

    test('a picker that fails is told to the caller, and leaves nothing picked', () async {
      PhotoStore.picker = (s) async => throw StateError('no camera');
      final session = PhotoSession();
      await expectLater(
          session.pick(ImageSource.camera), throwsA(isA<PhotoPickFailed>()));
      session.close(); // nothing to delete, and nothing thrown
      await session.commit(null);
    });

    test('backing out of the picker is nothing picked', () async {
      PhotoStore.picker = (s) async => null;
      final session = PhotoSession();
      expect(await session.pick(ImageSource.camera), isNull);
      session.close();
    });
  });

  group('the thumbnail', () {
    Future<void> pump(WidgetTester tester, String? path,
            {VoidCallback? onTap, double size = 72}) =>
        tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
              body: Center(
                  child: PhotoThumb(path: path, onTap: onTap, label: 'Pill', size: size))),
        ));

    // A real 1x1 PNG, so the image decodes.
    const pngBytes = [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
      0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
      0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44,
      0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0x00, 0x00, 0x03, 0x01, 0x01,
      0x00, 0x18, 0xDD, 0x8D, 0xB0, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44,
      0xAE, 0x42, 0x60, 0x82,
    ];

    testWidgets('shows a photo that is there, and opens it on a tap', (tester) async {
      final png = File(p.join(elsewhere.path, 'p.png'))..writeAsBytesSync(pngBytes);
      var taps = 0;
      await pump(tester, png.path, onTap: () => taps++);

      expect(find.byType(Image), findsOneWidget);
      await tester.tap(find.byType(PhotoThumb));
      expect(taps, 1);
    });

    testWidgets('shows a photo whose saved path has gone stale', (tester) async {
      final kept = await PhotoStore.keep(
          File(p.join(elsewhere.path, 'p.png'))..writeAsBytesSync(pngBytes));
      await pump(tester, '/old/container/Documents/photos/${p.basename(kept)}');

      expect(find.byType(Image), findsOneWidget);
      final shown = tester.widget<Image>(find.byType(Image)).image;
      final file = (shown is ResizeImage ? shown.imageProvider : shown) as FileImage;
      expect(file.file.path, kept, reason: 'the photo as it is kept now, not the stale path');
    });

    testWidgets('a small one that opens something still has a 44-point target', (tester) async {
      final png = File(p.join(elsewhere.path, 'p.png'))..writeAsBytesSync(pngBytes);
      var taps = 0;
      await pump(tester, png.path, size: 40, onTap: () => taps++);

      final area = tester.getSize(find.byType(PhotoThumb));
      expect(area.width, greaterThanOrEqualTo(44));
      expect(area.height, greaterThanOrEqualTo(44));
      // A tap just outside the 40-point picture, inside the 44-point target.
      final c = tester.getCenter(find.byType(PhotoThumb));
      await tester.tapAt(c + const Offset(21, 0));
      expect(taps, 1);
    });

    testWidgets('one that opens nothing is just its size', (tester) async {
      final png = File(p.join(elsewhere.path, 'p.png'))..writeAsBytesSync(pngBytes);
      await pump(tester, png.path, size: 40);
      expect(tester.getSize(find.byType(PhotoThumb)), const Size(40, 40));
    });

    testWidgets('a screen reader can open it: a button with a tap action of its own',
        (tester) async {
      final handle = tester.ensureSemantics();
      final png = File(p.join(elsewhere.path, 'p.png'))..writeAsBytesSync(pngBytes);
      var taps = 0;
      await pump(tester, png.path, onTap: () => taps++);

      expect(tester.getSemantics(find.bySemanticsLabel('Pill')),
          isSemantics(isButton: true, hasTapAction: true));
      tester.semantics.tap(find.semantics.byLabel('Pill'));
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('and says nothing is there to open when the photo is gone', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, '/not/a/real/place.jpg', onTap: () {});
      expect(tester.getSemantics(find.bySemanticsLabel('Pill — not on this phone')),
          isNot(isSemantics(isButton: true)));
      handle.dispose();
    });

    testWidgets('shows "not on this phone", not an error, for a photo that is gone',
        (tester) async {
      var taps = 0;
      await pump(tester, '/not/a/real/place.jpg', onTap: () => taps++);

      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(PhotoThumb));
      expect(taps, 0, reason: 'nothing to open');
    });

    testWidgets('a screen reader hears the difference', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, '/not/a/real/place.jpg');
      expect(find.bySemanticsLabel('Pill — not on this phone'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('no path at all is the same square', (tester) async {
      await pump(tester, null);
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
