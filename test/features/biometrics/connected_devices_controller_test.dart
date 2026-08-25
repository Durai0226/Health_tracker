/// The Connected-devices controller, and the bug it exists to kill.
///
/// The screen this replaces resolved four sequential awaits into ONE setState,
/// with only one of them time-bounded. So a hung platform probe threw away the
/// database rows too — and those rows arrive in about a millisecond. Measured on
/// the old screen: a real source row in the DAO, ten seconds of pumped time,
/// zero switches rendered, "Nothing connected yet" on screen.
///
/// The headline test here is [emits rows before it has probed anything]. If
/// somebody ever "simplifies" `load()` into one `Future.wait`, that is the test
/// that stops them.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/services/health_data_service.dart';
import 'package:tablet_remainder/core/services/health_sync_queue.dart';
import 'package:tablet_remainder/features/biometrics/models/health_source.dart';
import 'package:tablet_remainder/features/biometrics/services/connected_devices_controller.dart';

HealthSource _source(String id, {bool enabled = true, int priority = 0}) {
  final t = DateTime(2026, 8, 24, 9);
  return HealthSource(
    id: id,
    sourceId: 'com.example.$id',
    sourceName: id,
    platformIndex: 0,
    firstSeenAt: t,
    lastSeenAt: t,
    createdAt: t,
    updatedAt: t,
    enabled: enabled,
    priority: priority,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await HealthSyncQueue.clearForTesting();
  });

  /// Records every distinct state the controller publishes.
  List<ConnectedDevicesState> record(ConnectedDevicesController c) {
    final seen = <ConnectedDevicesState>[];
    c.addListener(() => seen.add(c.value));
    return seen;
  }

  group('load ordering', () {
    test('emits rows before it has probed anything', () async {
      final probeGate = Completer<HealthAvailability>();
      final c = ConnectedDevicesController(
        readSources: () async => [_source('watch')],
        probeAvailability: () => probeGate.future,
        probeBackgroundAvailable: () async => false,
        readBackgroundEnabled: () async => false,
      );
      final seen = record(c);

      final loading = c.load();
      await Future<void>.delayed(Duration.zero);

      // The probe has NOT answered, and the row is already on screen.
      expect(probeGate.isCompleted, isFalse);
      expect(seen, isNotEmpty,
          reason: 'the rows resolved; nothing should be waiting on the '
              'platform to show them');
      expect(seen.first.phase, DevicesPhase.rowsOnly);
      expect(seen.first.sources, hasLength(1));
      expect(seen.first.availability, isNull);

      probeGate.complete(HealthAvailability.available);
      await loading;

      expect(seen.length, greaterThanOrEqualTo(2),
          reason: 'a second emit must follow the probe');
      expect(seen.last.phase, DevicesPhase.complete);
      expect(seen.last.availability, HealthAvailability.available);
      expect(seen.last.sources, hasLength(1));
      c.dispose();
    });

    test('a probe that never answers cannot hide the rows', () async {
      // The exact failure the old screen had. The probe hangs past its own
      // timeout; the rows must survive it.
      final c = ConnectedDevicesController(
        readSources: () async => [_source('watch'), _source('ring')],
        probeAvailability: () => Completer<HealthAvailability>().future,
        probeBackgroundAvailable: () async => false,
        readBackgroundEnabled: () async => false,
        probeTimeout: const Duration(milliseconds: 30),
      );

      await c.load();

      expect(c.value.sources, hasLength(2),
          reason: 'THE regression. The old screen rendered "Nothing connected '
              'yet" here.');
      expect(c.value.isEmpty, isFalse);
      expect(c.value.probeFailed, isTrue);
      expect(c.value.error, isNull,
          reason: 'a dead probe is not an error state — the rows are fine');
      c.dispose();
    });

    test('a probe failure is distinct from "not determined"', () async {
      final c = ConnectedDevicesController(
        readSources: () async => const [],
        probeAvailability: () async => throw StateError('platform channel'),
        probeBackgroundAvailable: () async => false,
        readBackgroundEnabled: () async => false,
      );
      await c.load();

      // The old code collapsed a broken probe INTO notDetermined, so "we asked
      // and it broke" was indistinguishable from "we never asked".
      expect(c.value.probeFailed, isTrue);
      expect(c.value.availability, isNull);
      c.dispose();
    });
  });

  group('empty is a conclusion, not a default', () {
    test('sources is null until a read completes', () {
      final c = ConnectedDevicesController(
        readSources: () async => const [],
        probeAvailability: () async => HealthAvailability.available,
        probeBackgroundAvailable: () async => false,
        readBackgroundEnabled: () async => false,
      );
      expect(c.value.sources, isNull);
      expect(c.value.isEmpty, isFalse,
          reason: 'nothing has been read yet, so "empty" is not yet true');
      c.dispose();
    });

    test('isEmpty only after a read found nothing', () async {
      final c = ConnectedDevicesController(
        readSources: () async => const [],
        probeAvailability: () async => HealthAvailability.available,
        probeBackgroundAvailable: () async => false,
        readBackgroundEnabled: () async => false,
      );
      await c.load();
      expect(c.value.isEmpty, isTrue);
      c.dispose();
    });

    test('a DB failure IS an error state, unlike a probe failure', () async {
      var probed = false;
      final c = ConnectedDevicesController(
        readSources: () async => throw StateError('drift is down'),
        probeAvailability: () async {
          probed = true;
          return HealthAvailability.available;
        },
        probeBackgroundAvailable: () async => false,
        readBackgroundEnabled: () async => false,
      );
      await c.load();

      expect(c.value.error, isNotNull);
      expect(c.value.phase, DevicesPhase.complete);
      expect(probed, isFalse,
          reason: 'with nothing to show, probing the platform is wasted work');
      c.dispose();
    });
  });

  group('toggling a source', () {
    test('re-aggregates AND reloads the in-memory view', () async {
      // reloadFromDb's own docstring names this screen as a caller, and it had
      // zero call sites. Without it Heart and Workouts keep serving an
      // aggregation computed while the source was still on.
      var synced = 0, reloaded = 0;
      final c = ConnectedDevicesController(
        readSources: () async => [_source('watch')],
        probeAvailability: () async => HealthAvailability.available,
        probeBackgroundAvailable: () async => false,
        readBackgroundEnabled: () async => false,
        writeSourceEnabled: (_, _) async {},
        runSync: () async {
          synced++;
          return 0;
        },
        reloadAggregation: () async => reloaded++,
      );
      await c.load();
      final ok = await c.setEnabled(c.value.sources!.single, false);

      expect(ok, isTrue);
      expect(synced, 1);
      expect(reloaded, 1, reason: 'the missing call');
      expect(c.value.sources!.single.enabled, isFalse);
      c.dispose();
    });

    test('a failed write puts the switch back', () async {
      final c = ConnectedDevicesController(
        readSources: () async => [_source('watch')],
        probeAvailability: () async => HealthAvailability.available,
        probeBackgroundAvailable: () async => false,
        readBackgroundEnabled: () async => false,
        writeSourceEnabled: (_, _) async => throw StateError('write failed'),
        runSync: () async => 0,
        reloadAggregation: () async {},
      );
      await c.load();
      final ok = await c.setEnabled(c.value.sources!.single, false);

      expect(ok, isFalse);
      expect(c.value.sources!.single.enabled, isTrue,
          reason: 'the optimistic flip must be undone');
      c.dispose();
    });

    test('only the row being written is pending', () async {
      final gate = Completer<void>();
      final c = ConnectedDevicesController(
        readSources: () async => [_source('watch'), _source('ring')],
        probeAvailability: () async => HealthAvailability.available,
        probeBackgroundAvailable: () async => false,
        readBackgroundEnabled: () async => false,
        writeSourceEnabled: (_, _) => gate.future,
        runSync: () async => 0,
        reloadAggregation: () async {},
      );
      await c.load();
      final f = c.setEnabled(c.value.sources!.first, false);
      await Future<void>.delayed(Duration.zero);

      expect(c.value.pendingIds, {'watch'},
          reason: 'nothing should grey out en masse');
      gate.complete();
      await f;
      expect(c.value.pendingIds, isEmpty);
      c.dispose();
    });
  });

  group('the pin is a radio, not a checkbox', () {
    test('pinning one source clears every other pin', () async {
      final writes = <String, int>{};
      final c = ConnectedDevicesController(
        readSources: () async => [
          _source('watch', priority: 1),
          _source('phone'),
          _source('ring'),
        ],
        probeAvailability: () async => HealthAvailability.available,
        probeBackgroundAvailable: () async => false,
        readBackgroundEnabled: () async => false,
        writeSourcePriority: (id, p) async => writes[id] = p,
        runSync: () async => 0,
        reloadAggregation: () async {},
      );
      await c.load();
      final ring = c.value.sources!.firstWhere((s) => s.id == 'ring');
      await c.setPinned(ring, true);

      // Two pinned sources would tie at the top tier of HealthSourceRegistry.wins
      // and silently fall through to raw sample count — a control that appears
      // to work and does not.
      expect(c.value.sources!.where((s) => s.priority == 1).map((s) => s.id),
          ['ring']);
      expect(writes, {'watch': 0, 'ring': 1},
          reason: "only rows whose priority actually changes are written; "
              "'phone' was already 0");
      c.dispose();
    });

    test('unpinning clears the pin entirely', () async {
      final c = ConnectedDevicesController(
        readSources: () async => [_source('watch', priority: 1)],
        probeAvailability: () async => HealthAvailability.available,
        probeBackgroundAvailable: () async => false,
        readBackgroundEnabled: () async => false,
        writeSourcePriority: (_, _) async {},
        runSync: () async => 0,
        reloadAggregation: () async {},
      );
      await c.load();
      await c.setPinned(c.value.sources!.single, false);
      expect(c.value.sources!.single.priority, 0);
      c.dispose();
    });
  });

  group('the self-disable notice', () {
    test('surfaces the recorded reason and its time', () async {
      await HealthSyncQueue.recordSelfDisable(
          SyncDisableReason.permissionRevoked);

      final c = ConnectedDevicesController(
        readSources: () async => const [],
        probeAvailability: () async => HealthAvailability.available,
        probeBackgroundAvailable: () async => true,
        readBackgroundEnabled: HealthSyncQueue.isEnabled,
      );
      await c.load();

      expect(c.value.selfDisabled, isNotNull);
      expect(c.value.selfDisabled!.reason, SyncDisableReason.permissionRevoked);
      expect(c.value.backgroundEnabled, isFalse,
          reason: 'recordSelfDisable must also switch it off');
      c.dispose();
    });

    test('a hand toggle leaves no notice behind', () async {
      // The user turning it off knows why it is off. Only the WORKER explains
      // itself.
      await HealthSyncQueue.setEnabled(true);
      await HealthSyncQueue.setEnabled(false);
      expect(await HealthSyncQueue.selfDisable(), isNull);
    });

    test('re-enabling clears the notice', () async {
      await HealthSyncQueue.recordSelfDisable(SyncDisableReason.checkFailed);
      expect(await HealthSyncQueue.selfDisable(), isNotNull);
      await HealthSyncQueue.setEnabled(true);
      expect(await HealthSyncQueue.selfDisable(), isNull);
    });

    test('an unknown reason name is dropped, not guessed', () async {
      // Stored by NAME so an enum reorder cannot reinterpret history — and an
      // unrecognised name must read as "no notice" rather than as slot zero.
      SharedPreferences.setMockInitialValues({
        'flutter.health_bg_disabled_reason': 'somethingFromAFutureBuild',
        'flutter.health_bg_disabled_at_ms': 1,
      });
      expect(await HealthSyncQueue.selfDisable(), isNull);
    });
  });
}
