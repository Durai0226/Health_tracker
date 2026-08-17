import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/services/health_sync_queue.dart';

/// The hand-off between the background isolate and the app.
///
/// Pure SharedPreferences by design — the worker must never touch Drift — so
/// this is fully testable headlessly, unlike the worker itself.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await HealthSyncQueue.clearForTesting();
  });

  test('a snapshot round-trips', () async {
    await HealthSyncQueue.writeSnapshot({'todayKey': '2026-03-10', 'steps': 8421});

    final snap = await HealthSyncQueue.readSnapshot();
    expect(snap, isNotNull);
    expect(snap!['steps'], 8421);
    expect(snap['todayKey'], '2026-03-10');
    expect(snap['v'], HealthSyncQueue.snapshotVersion);
  });

  test('no snapshot reads as null rather than throwing', () async {
    expect(await HealthSyncQueue.readSnapshot(), isNull);
  });

  test('a snapshot from a different version is discarded', () async {
    // A blob written by an older build must not be misread into the wrong
    // fields — that is what the version stamp is for.
    SharedPreferences.setMockInitialValues({
      'flutter.health_bg_snapshot': '{"v":0,"steps":1}',
    });
    expect(await HealthSyncQueue.readSnapshot(), isNull);
  });

  test('corrupt JSON is tolerated', () async {
    SharedPreferences.setMockInitialValues({
      'flutter.health_bg_snapshot': 'not json at all',
    });
    expect(await HealthSyncQueue.readSnapshot(), isNull);
  });

  test('a JSON non-object is tolerated', () async {
    SharedPreferences.setMockInitialValues({
      'flutter.health_bg_snapshot': '[1,2,3]',
    });
    expect(await HealthSyncQueue.readSnapshot(), isNull);
  });

  group('the dirty flag', () {
    test('is read-and-clear, so two drains cannot both act on one run',
        () async {
      await HealthSyncQueue.setDirty(true);
      expect(await HealthSyncQueue.takeDirty(), isTrue);
      expect(await HealthSyncQueue.takeDirty(), isFalse);
    });

    test('defaults to false', () async {
      expect(await HealthSyncQueue.takeDirty(), isFalse);
    });
  });

  group('the enabled flag', () {
    test('defaults to false — background sync is opt-in', () async {
      expect(await HealthSyncQueue.isEnabled(), isFalse);
    });

    test('disabling drops the snapshot with it', () async {
      await HealthSyncQueue.setEnabled(true);
      await HealthSyncQueue.writeSnapshot({'steps': 10});
      expect(await HealthSyncQueue.readSnapshot(), isNotNull);

      await HealthSyncQueue.setEnabled(false);
      expect(await HealthSyncQueue.isEnabled(), isFalse);
      expect(await HealthSyncQueue.readSnapshot(), isNull,
          reason: 'stale health data must not outlive the feature being off');
    });
  });

  test('a successful write clears the previous error breadcrumb', () async {
    await HealthSyncQueue.recordError('SecurityException: no permission');
    expect(await HealthSyncQueue.lastError(), isNotNull);

    await HealthSyncQueue.writeSnapshot({'steps': 1});
    expect(await HealthSyncQueue.lastError(), isNull);
    expect(await HealthSyncQueue.lastRunAt(), isNotNull);
  });

  test('a pathological error message is truncated', () async {
    await HealthSyncQueue.recordError('x' * 5000);
    expect(await HealthSyncQueue.lastError(), hasLength(300));
  });
}
