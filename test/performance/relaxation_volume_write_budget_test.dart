@Tags(['performance'])
library;

/// Dragging the relaxation volume slider must not write to disk per frame.
///
/// `RelaxationService.setVolume` called `_saveData()`, which is six sequential
/// `setAppPreference` calls — each its own Drift write, its own transaction, its
/// own WAL fsync — and two of the six values are the stats blob and the last
/// hundred sessions re-encoded as JSON. The slider is wired to
/// `Slider.onChanged`, so all of that ran once per drag frame, on the UI
/// isolate, while audio was playing.
///
/// `FocusService.setSoundVolume` had the identical defect and the identical fix:
/// `persist: false` for the drag, one single-key write on release.
///
/// Measured as WRITES, not elapsed time: wall-clock on a shared machine swings
/// far more than the thing being measured, and a write count is the same number
/// on every machine.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/focus/services/relaxation_service.dart';

import '../support/counting_executor.dart';
import '../support/fake_audio_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CountingExecutor counter;
  late AppDatabase db;
  final service = RelaxationService();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    counter = CountingExecutor(NativeDatabase.memory());
    db = AppDatabase.forTesting(counter);
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    AudioService().engineForTesting = FakeAudioEngine();
    service.resetForTesting();
  });

  tearDown(() async => db.close());

  /// Writes against `app_preferences` while [body] runs.
  ///
  /// `setVolume` fires its write unawaited, so the queue has to be drained
  /// before counting — otherwise the measurement is of how fast the loop ran,
  /// not of what it wrote, and the assertion below would pass with the defect
  /// restored.
  Future<int> prefWritesDuring(void Function() body) async {
    counter.reset();
    body();
    await pumpEventQueue();
    return counter.writeTally['app_preferences'] ?? 0;
  }

  test('a thirty-frame drag writes nothing', () async {
    final writes = await prefWritesDuring(() {
      for (var frame = 0; frame < 30; frame++) {
        service.setVolume(frame / 30, persist: false);
      }
    });

    expect(writes, 0,
        reason: 'half a second of dragging used to be 180 Drift writes plus '
            'thirty re-encodes of the stats blob and the session history');
    expect(service.volume, closeTo(29 / 30, 0.001),
        reason: 'the value still has to follow the thumb — a slider that '
            'writes nothing AND changes nothing is not a fix');
  });

  test('releasing the thumb writes exactly one key, once', () async {
    final writes = await prefWritesDuring(() => service.setVolume(0.42));

    expect(writes, 1,
        reason: 'one key (`relaxationVolume`), not the whole six-key blob');
    expect(service.volume, 0.42);
  });

  test('the value that lands on disk is the one released, not the last frame',
      () async {
    // The half a commit-only write could quietly break: if the drag frames were
    // silently dropped, release would persist a stale value.
    for (var frame = 0; frame < 5; frame++) {
      service.setVolume(frame / 10, persist: false);
    }
    service.setVolume(0.8);
    await pumpEventQueue();

    expect(CleanStorageService.getAppPreference('relaxationVolume'), 0.8);
  });
}
