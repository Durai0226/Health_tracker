/// A stored volume must not take the selected track down with it.
///
/// Found by opening Relaxation on a device, where logcat carried
/// `Error loading relaxation settings: NoSuchMethodError: Class 'String' has
/// no instance method 'toDouble'`.
///
/// `CleanStorageService.setAppPreference` has typed paths for `bool`, `int`
/// and `Map`/`List`, and sends everything else through `value?.toString()`. A
/// `double` has no typed path, so the volume persists as the STRING "0.7";
/// `loadAppPreferences` then only `jsonDecode`s values starting with `{` or
/// `[`, so it comes back a String. `(…).toDouble()` threw on it — and being
/// the third of four assignments under one `try`, the throw skipped
/// `_selectedMusic`, so the track the user picked was dropped on every launch.
///
/// It only ever failed after a restart: the write-through cache holds the real
/// double for the rest of the session, which is why no in-session test saw it.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/focus/models/relaxation_music.dart';
import 'package:tablet_remainder/features/focus/services/relaxation_service.dart';

import '../../support/fake_audio_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.loadAppPreferences();
    AudioService().engineForTesting = FakeAudioEngine();
    RelaxationService().resetForTesting();
  });

  tearDown(() async {
    RelaxationService().resetForTesting();
    await db.close();
  });

  /// Cold-start the service against preferences shaped the way the database
  /// actually hands them back after a restart — the volume as a String.
  Future<void> bootAfterRestart({required Object storedVolume}) async {
    await CleanStorageService.setAppPreference(
        'relaxationVolume', storedVolume);
    // An ordinal, which is what `EnumJson.atOrNull` reads and what
    // `setAppPreference` round-trips through its typed `int` path.
    await CleanStorageService.setAppPreference(
        'relaxationSelectedMusic', RelaxationMusicType.values.length - 1);
    await RelaxationService().init();
  }

  test('a volume stored as a String is still read as a number', () async {
    await bootAfterRestart(storedVolume: '0.35');
    expect(RelaxationService().volume, closeTo(0.35, 1e-9),
        reason: 'the value on disk is the string "0.35"; reading it as 0.7 '
            'silently resets the volume every launch');
  });

  test('and the selected track survives alongside it', () async {
    await bootAfterRestart(storedVolume: '0.35');
    expect(RelaxationService().selectedMusic, RelaxationMusicType.values.last,
        reason: 'this is the real damage: the volume threw partway through '
            'the block and the track assignment below it never ran, so the '
            "user's chosen music was dropped on every cold start");
  });

  test('a real double still works', () async {
    await bootAfterRestart(storedVolume: 0.42);
    expect(RelaxationService().volume, closeTo(0.42, 1e-9),
        reason: 'the in-session path must keep working');
  });

  test('an unparseable value falls back instead of throwing', () async {
    await bootAfterRestart(storedVolume: 'loud');
    expect(RelaxationService().volume, closeTo(0.7, 1e-9));
    expect(RelaxationService().selectedMusic, RelaxationMusicType.values.last,
        reason: 'a bad value costs its own field, not the ones after it');
  });
}
