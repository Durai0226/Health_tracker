/// The Connected-devices screen after the rebuild.
///
/// The headline is [shows a seeded device, never "Nothing connected yet"]. On
/// the old screen that assertion failed: a real source row in the DAO, ten
/// seconds of pumped time, zero switches, and the empty state on screen —
/// because one `setState` sat behind four sequential awaits and only one of them
/// was time-bounded.
///
/// `qa_seed.dart:598` plants a Galaxy Watch5 with the comment "so Connected
/// devices is measured with a row rather than its empty state". It never was.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/health_data_service.dart';
import 'package:tablet_remainder/core/services/health_sync_queue.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import 'package:tablet_remainder/features/biometrics/models/biometric_metric.dart';
import 'package:tablet_remainder/features/biometrics/models/health_source.dart';
import 'package:tablet_remainder/features/biometrics/screens/connected_devices_screen.dart';
import 'package:tablet_remainder/features/biometrics/screens/health_source_detail_screen.dart';
import 'package:tablet_remainder/features/biometrics/services/connected_devices_controller.dart';

HealthSource _watch({bool enabled = true, int priority = 0}) {
  final t = DateTime(2026, 8, 24, 9);
  return HealthSource(
    id: 'src_watch',
    sourceId: 'com.samsung.health',
    sourceName: 'Galaxy Watch5',
    platformIndex: 0,
    metrics: {
      BiometricMetricKey.hr: SourceMetricStat(lastSeenAt: t, points: 900),
      BiometricMetricKey.hrv: SourceMetricStat(lastSeenAt: t, points: 30),
    },
    firstSeenAt: t.subtract(const Duration(days: 30)),
    lastSeenAt: t,
    createdAt: t,
    updatedAt: t,
    enabled: enabled,
    priority: priority,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;
  var _pumpSeq = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    await HealthSyncQueue.clearForTesting();
  });

  tearDown(() async => db.close());

  /// Pumps the screen with an injected controller, so a test can decide what the
  /// platform says without a device.
  Future<ConnectedDevicesController> pump(
    WidgetTester tester, {
    List<HealthSource> sources = const [],
    HealthAvailability availability = HealthAvailability.available,
    bool backgroundAvailable = false,
    bool backgroundEnabled = false,
    Duration probeDelay = Duration.zero,
    double height = 844,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(390, height);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final c = ConnectedDevicesController(
      readSources: () async => sources,
      probeAvailability: () async {
        if (probeDelay > Duration.zero) await Future<void>.delayed(probeDelay);
        return availability;
      },
      probeBackgroundAvailable: () async => backgroundAvailable,
      readBackgroundEnabled: () async => backgroundEnabled,
      writeSourceEnabled: (_, _) async {},
      writeSourcePriority: (_, _) async {},
      runSync: () async => 0,
      reloadAggregation: () async {},
      setBackground: (_) async {},
    );
    addTearDown(c.dispose);

    _pumpSeq++;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      // A distinct key per pump. Without one, a second `pumpWidget` in the same
      // test reuses the existing State — same widget type, same position — so
      // `initState` never runs again and the newly injected controller is
      // silently ignored. Two different scenarios then measure identically,
      // which is exactly how the first version of the measurement below
      // reported populated == empty.
      home: ConnectedDevicesScreen(
          key: ValueKey('cd-$_pumpSeq'), controller: c),
    ));
    return c;
  }

  Iterable<String> texts(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => (t.data ?? '').trim())
      .where((s) => s.isNotEmpty);

  // -------------------------------------------------------------- the bug

  group('the false empty state', () {
    testWidgets('shows a seeded device, never "Nothing connected yet"',
        (tester) async {
      await pump(tester, sources: [_watch()]);
      await tester.pumpAndSettle();

      expect(find.text('Galaxy Watch5'), findsOneWidget);
      expect(find.byType(AppSwitch), findsWidgets);
      expect(find.text('Nothing connected yet'), findsNothing,
          reason: 'THE regression. The old screen rendered exactly this with a '
              'real row in the DAO.');
    });

    testWidgets('a hanging probe cannot hide the list', (tester) async {
      // The precise old failure: the platform never answers, the timeout throws
      // into a bare catch, and the one setState never runs.
      await pump(
        tester,
        sources: [_watch()],
        probeDelay: const Duration(seconds: 30),
      );
      // Deliberately NOT pumpAndSettle: the probe is still outstanding, which
      // is the whole point. A handful of frames is all the rows should need.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(find.text('Galaxy Watch5'), findsOneWidget);
      expect(find.text('Nothing connected yet'), findsNothing);

      // Let the 30s probe expire so no timer outlives the test.
      await tester.pump(const Duration(seconds: 31));
    });

    testWidgets('an empty registry still says so', (tester) async {
      await pump(tester, sources: const []);
      await tester.pumpAndSettle();
      expect(find.text('Nothing connected yet'), findsOneWidget,
          reason: 'the empty state is still correct when it is TRUE');
    });

    testWidgets('frame one is a skeleton, not a spinner and not the empty state',
        (tester) async {
      await pump(tester, sources: [_watch()]);
      await tester.pump(const Duration(milliseconds: 1));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Nothing connected yet'), findsNothing,
          reason: 'announcing "nothing connected" before the read completes is '
              'the accessibility face of the same bug');
    });
  });

  // ----------------------------------------------------------- the two nodes

  group('a row has two actions and keeps them separate', () {
    testWidgets('the switch is named, and is not the nav node',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, sources: [_watch()]);
      await tester.pumpAndSettle();

      // ignore: deprecated_member_use
      final root =
          tester.binding.pipelineOwner.semanticsOwner?.rootSemanticsNode;
      final nodes = <SemanticsNode>[];
      void walk(SemanticsNode n) {
        nodes.add(n);
        n.visitChildren((c) {
          walk(c);
          return true;
        });
      }

      walk(root!);

      // A bare Switch announces as "switch, on" with no name. The previous
      // version shipped exactly that.
      final switchNode = nodes.where((n) =>
          n.hasFlag(SemanticsFlag.hasToggledState) ||
          n.label.startsWith('Use Galaxy Watch5'));
      expect(switchNode, isNotEmpty, reason: 'the switch must have a name');
      expect(
        nodes.any((n) => n.label.contains('Use Galaxy Watch5 for health data')),
        isTrue,
        reason: 'found labels: ${nodes.map((n) => n.label).where((l) => l.isNotEmpty).toList()}',
      );

      // …and the navigating half is its own node, merged into one clean run.
      final navNode = nodes.where((n) =>
          n.label.contains('Galaxy Watch5') &&
          n.label.contains('Last seen') &&
          !n.label.startsWith('Use '));
      expect(navNode, hasLength(1),
          reason: 'the name, what it feeds and last-seen should read as ONE '
              'run, not three separate swipes');
      expect(navNode.single.hasFlag(SemanticsFlag.hasToggledState), isFalse);

      // The assertion that actually discriminates, arrived at by dumping the
      // tree rather than reasoning about it.
      //
      // Two nodes existing is not enough — they must be SIBLINGS. The first
      // version of this row produced them NESTED, with the switch as the parent
      // and the device run as its child, which reads as "the switch contains
      // the device". Every flag check above passed on that tree; only parentage
      // told them apart. Removing `container: true` from the switch's Semantics
      // reproduces it, and this is the assertion that goes red.
      //
      // Checked and worth recording: wrapping the whole row in `MergeSemantics`
      // does NOT collapse these two, because the inner `MergeSemantics` and the
      // switch's `container: true` are both explicit boundaries that a merge
      // will not cross. So the structure is robust against that particular
      // "tidy-up", and this test does not claim to catch it.
      final toggle = nodes.singleWhere(
          (n) => n.label == 'Use Galaxy Watch5 for health data');

      List<int> descendantsOf(SemanticsNode n) {
        final ids = <int>[];
        void walkKids(SemanticsNode x) {
          x.visitChildren((c) {
            ids.add(c.id);
            walkKids(c);
            return true;
          });
        }

        walkKids(n);
        return ids;
      }

      expect(descendantsOf(toggle), isNot(contains(navNode.single.id)),
          reason: 'the switch must not contain the device');
      expect(descendantsOf(navNode.single), isNot(contains(toggle.id)),
          reason: 'and the device must not contain the switch — merging the '
              'whole row does exactly this, and the detail screen stops being '
              'independently reachable');

      // Reading order: the device, then the control that governs it.
      //
      // The NEAREST common ancestor — every node up the chain contains both, so
      // `singleWhere` over "contains both" matches several.
      final ancestors = nodes
          .where((n) =>
              descendantsOf(n).contains(navNode.single.id) &&
              descendantsOf(n).contains(toggle.id))
          .toList()
        ..sort((a, b) =>
            descendantsOf(a).length.compareTo(descendantsOf(b).length));
      final parent = ancestors.first;
      expect(parent.childrenCount, 2,
          reason: 'the row should hold exactly these two nodes');
      final order = <int>[];
      parent.visitChildren((c) {
        order.add(c.id);
        return true;
      });
      expect(order, [navNode.single.id, toggle.id]);

      handle.dispose();
    });

    testWidgets('tapping the row opens the detail screen', (tester) async {
      await pump(tester, sources: [_watch()]);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Galaxy Watch5'));
      await tester.pumpAndSettle();

      expect(find.byType(HealthSourceDetailScreen), findsOneWidget);
      expect(find.text('Prefer this device'), findsOneWidget,
          reason: 'the pin lives here — the reason this is a screen, not a '
              'sheet: it needs room for its two caveats');
    });
  });

  // ------------------------------------------------------- banner over data

  group('the banner slot', () {
    testWidgets('a self-disable notice sits ABOVE a populated list',
        (tester) async {
      await HealthSyncQueue.recordSelfDisable(
          SyncDisableReason.permissionRevoked);

      await pump(
        tester,
        sources: [_watch()],
        backgroundAvailable: true,
      );
      await tester.pumpAndSettle();

      // Both at once. This combination is why AsyncSection could not be a
      // strict loading|empty|error|data switch.
      expect(find.text('Background sync turned itself off'), findsOneWidget);
      expect(find.text('Galaxy Watch5'), findsOneWidget);
      expect(find.text('Turn it back on'), findsOneWidget);
    });

    testWidgets('a probe failure does not claim the permission was revoked',
        (tester) async {
      await HealthSyncQueue.recordSelfDisable(SyncDisableReason.checkFailed);
      await pump(tester, sources: [_watch()], backgroundAvailable: true);
      await tester.pumpAndSettle();

      final all = texts(tester).join(' ');
      expect(all, contains("couldn't confirm"));
      expect(all, isNot(contains('lost permission')),
          reason: 'the probe merely failed — asserting a revocation would be a '
              'claim the user cannot check');
    });

    testWidgets('no notice, no banner', (tester) async {
      await pump(tester, sources: [_watch()]);
      await tester.pumpAndSettle();
      expect(find.text('Background sync turned itself off'), findsNothing);
    });
  });

  // ----------------------------------------------------------------- copy

  group('copy claims only what the data supports', () {
    testWidgets('does not promise that everything shows up automatically',
        (tester) async {
      await pump(tester, sources: [_watch()]);
      await tester.pumpAndSettle();

      final all = texts(tester).join(' ');
      // Only the WINNING source of a BIOMETRIC type is ever registered, so a
      // second watch that never wins a day never appears — and steps and sleep
      // never register at all.
      expect(all, isNot(contains('shows up here automatically')));
      expect(all, contains('has actually used their data'));
    });

    testWidgets('background sync does not claim to keep sleep current',
        (tester) async {
      await pump(
        tester,
        sources: [_watch()],
        backgroundAvailable: true,
        backgroundEnabled: true,
        // Tall on purpose: the background section is below the fold at 844, and
        // a ListView never builds its off-screen children, so `find` genuinely
        // cannot see them. (scrollUntilVisible throws on this app's scrollables.)
        height: 1600,
      );
      await tester.pumpAndSettle();

      final all = texts(tester).join(' ');
      // The worker reads steps only, and writes a snapshot the app merges on
      // next open.
      expect(all, isNot(contains('steps and sleep stay current')));
      expect(all, contains('step count'));
      // initialDelay is fifteen minutes, so "never run" right after enabling is
      // expected rather than a fault.
      expect(all, contains('Waiting for the first check'));
    });
  });

  // -------------------------------------------------------- responsive gap

  testWidgets('no overflow in the states the shared harness cannot reach',
      (tester) async {
    // `responsive_overflow_test.dart` mounts this screen against an empty
    // database and no prefs, so it renders exactly one of the four states —
    // and never the two that carry the most layout risk: a populated row and
    // the self-disable banner with two buttons in it. The banner overflowed by
    // 66px at a plain 390pt width when it was first written, and nothing in the
    // shared harness could have seen it.
    const devices = <Size>[
      Size(320, 568),
      Size(360, 640),
      Size(390, 844),
      Size(428, 926),
    ];
    const scales = <double>[1.0, 1.3, 2.0];

    await HealthSyncQueue.recordSelfDisable(SyncDisableReason.permissionRevoked);

    final overflows = <String>[];
    for (final size in devices) {
      for (final scale in scales) {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final c = ConnectedDevicesController(
          readSources: () async => [_watch(priority: 1)],
          probeAvailability: () async => HealthAvailability.available,
          probeBackgroundAvailable: () async => true,
          readBackgroundEnabled: () async => true,
          writeSourceEnabled: (_, _) async {},
          writeSourcePriority: (_, _) async {},
          runSync: () async => 0,
          reloadAggregation: () async {},
          setBackground: (_) async {},
        );

        final prev = FlutterError.onError;
        FlutterError.onError = (d) {
          if (d.exception.toString().contains('overflowed')) {
            overflows.add('${size.width.toInt()} @${scale}x: '
                '${d.exception.toString().split('\n').first}');
          } else {
            prev?.call(d);
          }
        };
        try {
          _pumpSeq++;
          await tester.pumpWidget(MediaQuery(
            data: MediaQueryData(
                size: size, textScaler: TextScaler.linear(scale)),
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: ConnectedDevicesScreen(
                  key: ValueKey('resp-$_pumpSeq'), controller: c),
            ),
          ));
          await tester.pump(const Duration(milliseconds: 400));
        } finally {
          FlutterError.onError = prev;
        }
        c.dispose();
      }
    }
    expect(overflows, isEmpty, reason: overflows.join('\n'));
  });

  // ------------------------------------------------- what the harness misses

  testWidgets('MEASUREMENT: the populated screen, for the build budget',
      (tester) async {
    await pump(tester, sources: [_watch()]);
    await tester.pumpAndSettle();
    final populated = tester.allWidgets.length;

    await pump(tester, sources: const []);
    await tester.pumpAndSettle();
    final empty = tester.allWidgets.length;

    // Not an assertion about a specific number — those belong in
    // screen_build_cost_test.dart. This exists so the gap between the two is
    // recorded somewhere, because the shared harness stops measuring as soon as
    // the widget count is stable for three frames, and the skeleton is stable
    // immediately. That is why a budget of 380 stood next to sibling screens at
    // 660-670 while qa_seed.dart:598 planted a device specifically to be
    // measured here.
    // ignore: avoid_print
    print('BUILD-COST> connected_devices populated=$populated empty=$empty');
    expect(populated, greaterThan(empty),
        reason: 'a rendered device row must cost more than no row at all');
  });
}
