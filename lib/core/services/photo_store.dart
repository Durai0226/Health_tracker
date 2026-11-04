import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// The photos a person attaches — to a medicine, to a diary entry — and where they
/// live.
///
/// A photo is kept as a COPY inside the app's own private storage, in one folder,
/// never as a path into the gallery: a path into the gallery stops working the day the
/// picture is moved or deleted, and the app could not tell why. Everything that
/// touches the folder goes through here, so the rule about what may be deleted is in
/// one place: only a file inside it.
///
/// What a photo is not: part of a backup. A backup is a JSON file and carries only the
/// NAME of the file a photo was kept as, which on another phone names nothing.
/// Whatever shows a photo must therefore cope with one that is not there ([resolve]).
///
/// A photo is saved as a path, but only its file NAME is trusted: the folder it is in
/// can move without the file moving with its path (an iPhone's app container gets a new
/// location when it is restored to a new phone), so every lookup here — [resolve],
/// [delete], [sweep] — takes the last part of the path and looks for that in the store.
///
/// Every file operation here is the synchronous one, on purpose. A kept photo is a few
/// hundred kilobytes (it is picked at most 1600 px on a side), a copy of it takes
/// about a millisecond, and the alternative — an `await` per step of real I/O — makes
/// each caller's form wait on a clock a widget test cannot turn. Nothing here reads or
/// writes more than one photo at a time, apart from [sweep] and [clearAll], which touch
/// what a person has attached to their medicines and entries: a handful.
class PhotoStore {
  PhotoStore._();

  static const String folderName = 'photos';

  static Future<Directory> Function() _baseDirectory = getApplicationDocumentsDirectory;

  /// The store's folder, once known: [resolve] is synchronous (it runs in `build`) and
  /// cannot ask the platform where the app's files are.
  static Directory? _known;

  /// Where the app keeps its files. Replaced in tests, which have no platform.
  @visibleForTesting
  static Future<Directory> Function() get baseDirectory => _baseDirectory;

  @visibleForTesting
  static set baseDirectory(Future<Directory> Function() where) {
    _baseDirectory = where;
    _known = null;
  }

  /// Asks the person for a picture. Replaced in tests, which have no camera.
  @visibleForTesting
  static Future<XFile?> Function(ImageSource source) picker = (source) =>
      ImagePicker().pickImage(
        source: source,
        // A pill, or a page of a diary: it does not need the sensor's full size, and
        // the copy is kept for as long as the entry is.
        imageQuality: 80,
        maxWidth: 1600,
        maxHeight: 1600,
      );

  /// The clock for [sweep]'s age check. Replaced in tests.
  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  /// The store's folder, made or not.
  static Future<Directory> _location() async {
    final base = await _baseDirectory();
    return _known = Directory(p.join(base.path, folderName));
  }

  static Future<Directory> _folder() async {
    final dir = await _location();
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Find out where the store is, so that [resolve] can find a photo whose saved path
  /// has gone stale. Called once at start-up; until it has finished a path is taken as
  /// it stands. Never throws.
  static Future<void> warmUp() async {
    try {
      await _location();
    } catch (e) {
      debugPrint('Locating the photo store failed: $e');
    }
  }

  /// Ask for a picture from [source] and keep a copy. Null when the person backed out:
  /// there is nothing to do. Throws [PhotoPickFailed] when the picture could not be had
  /// or kept — camera or photo access turned off, no camera, a full phone — which the
  /// person has to be told, or nothing at all seems to have happened.
  static Future<String?> pickAndKeep(ImageSource source) async {
    try {
      final picked = await picker(source);
      if (picked == null) return null;
      return await keep(File(picked.path));
    } catch (e) {
      debugPrint('Picking a photo failed: $e');
      throw PhotoPickFailed(e);
    }
  }

  /// Copy [source] into the store and return where the copy is.
  static Future<String> keep(File source) async {
    final dir = await _folder();
    final ext = p.extension(source.path).toLowerCase();
    final name = '${const Uuid().v4()}${ext.isEmpty ? '.jpg' : ext}';
    return source.copySync(p.join(dir.path, name)).path;
  }

  /// Where the kept photo that [path] was saved as is now, or null when it is not on
  /// this phone. Once the store's place is known ([warmUp]) this looks only inside it,
  /// by the file's name, so a path that has gone stale still finds its photo.
  static String? resolve(String? path) {
    if (path == null) return null;
    final here = _known;
    if (here == null) return File(path).existsSync() ? path : null;
    final moved = p.join(here.path, p.basename(path));
    return File(moved).existsSync() ? moved : null;
  }

  /// Whether [path] is a kept photo that is still there.
  static bool exists(String? path) => resolve(path) != null;

  /// The name a photo is carried under in a backup: no folder, which means nothing on
  /// another phone.
  static String? fileNameOf(String? path) =>
      path == null || path.isEmpty ? null : p.basename(path);

  /// The kept photo called [fileName] (as [fileNameOf] gives it, and a backup carries
  /// it) if it is on this phone, else null. Anything with a folder in it is read as its
  /// last part alone: what a backup file says is not to be trusted to name a place.
  static Future<String?> locate(String? fileName) async {
    if (fileName == null) return null;
    try {
      final file = File(p.join((await _location()).path, p.basename(fileName)));
      return file.existsSync() ? file.path : null;
    } catch (e) {
      debugPrint('Looking for a kept photo failed: $e');
      return null;
    }
  }

  /// Delete the kept photo that [path] was saved as. Only ever a file in the store, by
  /// its name: whoever asks, a path read out of a database or a backup file is not to
  /// be trusted to name a file this app owns.
  static Future<void> delete(String? path) async {
    if (path == null) return;
    try {
      final file = File(p.join((await _location()).path, p.basename(path)));
      if (file.existsSync()) file.deleteSync();
    } catch (e) {
      debugPrint('Deleting a photo failed: $e');
    }
  }

  /// Delete every photo the store holds. For "Delete all data".
  static Future<void> clearAll() async {
    try {
      final base = await baseDirectory();
      final dir = Directory(p.join(base.path, folderName));
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } catch (e) {
      debugPrint('Clearing the photo store failed: $e');
    }
  }

  /// Delete the photos nothing refers to any more: those whose path is not in
  /// [referenced] — and that are older than [grace], so a photo that has just been
  /// picked, and not yet saved on whatever it is for, is not swept from under the person.
  ///
  /// A photo is orphaned by deleting what it was on, by replacing it, and by leaving a
  /// form without saving; each of those could delete as it goes, and this is the one
  /// that cannot be missed. Returns how many were deleted.
  static Future<int> sweep(Set<String> referenced,
      {Duration grace = const Duration(days: 1)}) async {
    var deleted = 0;
    try {
      final dir = await _folder();
      final cutoff = now().subtract(grace);
      // By name, not by path: a path saved before the app's folder moved is the same
      // photo, and must not read as one nothing refers to.
      final wanted = {for (final path in referenced) p.basename(path)};
      for (final entity in dir.listSync()) {
        if (entity is! File) continue;
        if (wanted.contains(p.basename(entity.path))) continue;
        if (entity.statSync().modified.isAfter(cutoff)) continue;
        entity.deleteSync();
        deleted++;
      }
    } catch (e) {
      debugPrint('Sweeping the photo store failed: $e');
    }
    return deleted;
  }
}

/// A picture could not be had or kept (see [PhotoStore.pickAndKeep]). Different from the
/// person backing out, which is not an error.
class PhotoPickFailed implements Exception {
  const PhotoPickFailed(this.cause);

  final Object cause;

  /// What to tell the person. Short, and says what they can do about it.
  static const String message =
      "Couldn't add that photo. If camera or photo access is turned off, you can allow it in Settings.";

  @override
  String toString() => 'PhotoPickFailed: $cause';
}

/// The photos picked while one form is open, and what becomes of them.
///
/// A form that lets the person attach a picture has the same three problems each time:
/// a picture picked and then replaced is useless; one picked and then abandoned (the
/// form closed without saving) is useless; and the one a saved change replaces or
/// removes must be deleted — but only once the change is saved, not when it is made.
/// One of these per form keeps all three in one place.
class PhotoSession {
  /// [original] is the photo the thing being edited had when the form opened.
  PhotoSession({this.original});

  final String? original;
  final Set<String> _picked = {};
  bool _committed = false;

  /// Ask for a picture from [source] and keep a copy. Null when the person backed out;
  /// throws [PhotoPickFailed] when nothing could be kept.
  Future<String?> pick(ImageSource source) async {
    final kept = await PhotoStore.pickAndKeep(source);
    if (kept != null) _picked.add(kept);
    return kept;
  }

  /// [previous] is no longer wanted. If it was picked in this session it is deleted
  /// now: nothing else holds it. The one the thing had before the form opened is not —
  /// that waits for [commit], in case the change is never saved.
  Future<void> replaced(String? previous) async {
    if (previous != null && _picked.remove(previous)) {
      await PhotoStore.delete(previous);
    }
  }

  /// The change was saved, with [finalPath] on the thing: delete the photo it had
  /// before if it no longer has it, and any picked and then dropped.
  Future<void> commit(String? finalPath) async {
    _committed = true;
    final before = original;
    if (before != null && before != finalPath) await PhotoStore.delete(before);
    final dropped = _picked.where((path) => path != finalPath).toList();
    _picked.removeAll(dropped);
    for (final path in dropped) {
      await PhotoStore.delete(path);
    }
  }

  /// The form is closing. Unless a change was saved, every picture picked in it goes.
  void close() {
    if (_committed) return;
    for (final path in _picked) {
      PhotoStore.delete(path);
    }
  }
}

