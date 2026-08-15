import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tablet_remainder/main.dart' as app;

import 'support/e2e_helpers.dart';

/// Real frame timings — the half a headless harness structurally cannot give.
///
/// `test/performance/screen_build_cost_test.dart` measures wall clock on the
/// host VM in debug mode and says so itself: relative signal, not a device
/// frame budget. It cannot see **raster** time at all, which is where blurred
/// shadows, `saveLayer`, and overdraw actually cost you.
/// `watchPerformance` reports both, with percentiles, from the real engine.
///
/// ## Run it
///
/// ```
/// flutter drive --driver=test_driver/integration_test.dart \
///   --target=integration_test/perf_e2e_test.dart \
///   -d <android-device-id> --profile --no-dds \
///   --dart-define=E2E_TEST=true
/// ```
///
/// Four parts of that are not optional — all four verified the hard way:
///
///  * **`flutter drive`, not `flutter test`.** `flutter test` rejects
///    `--profile` outright, and it discards `binding.reportData`, so the
///    numbers reach neither a real frame budget nor a file.
///  * **`--no-dds`.** `watchPerformance` connects to the VM Service to read the
///    timeline; DDS holds that port and the connection is refused, so
///    `reportData` stays null and every scenario silently reports nothing.
///
///  * **A PHYSICAL Android device for RASTER numbers.** An emulator renders
///    through swiftshader (software), so its rasterizer figures describe the
///    host CPU, not a GPU. Build times are still meaningful on an emulator;
///    raster times are not.
///  * **`--profile`.** Debug builds are 2-10x pessimistic; the numbers are not
///    a frame budget and `watchPerformance` itself warns when it sees debug.
///  * **`--dart-define=E2E_TEST=true`.** Skips onboarding (`main.dart:321`)
///    and notification/ad init (`:106`), so that work does not land inside a
///    measurement window.
///
/// For a machine-readable artifact instead of stdout, use `flutter drive` with
/// a `test_driver/` runner — `binding.reportData` is populated under plain
/// `flutter test` but then discarded, which is why every scenario below also
/// PRINTS.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Wraps a scenario in a frame-timing window.
  ///
  /// `watchPerformance` sleeps before the action and polls until the engine
  /// flushes its FrameTimings, so every call costs several seconds of wall
  /// time. Wrap whole scenarios, never single taps.
  Future<void> measure(String key, Future<void> Function() action) async {
    await binding.watchPerformance(action, reportKey: key);
    final m = binding.reportData?[key];
    if (m is Map) {
      // ignore: avoid_print
      print('PERFDEV|${jsonEncode({'key': key, ...m})}');
    }
  }

  testWidgets('nav slots: Today / Meds / Health / Trends', (t) async {
    app.main();
    await reachHome(t);
    await settle(t);

    await measure('home.scroll', () async {
      await scrollCycles(t, find.byType(Scrollable).first);
    });

    for (final tab in const ['Meds', 'Health', 'Trends']) {
      final finder = find.text(tab);
      if (finder.evaluate().isEmpty) continue;
      await measure('${tab.toLowerCase()}.open_scroll', () async {
        await t.tap(finder.last);
        await settle(t);
        await scrollCycles(t, find.byType(Scrollable).first, cycles: 3);
      });
    }
  });

  testWidgets('the switchers whose effects were stripped', (t) async {
    app.main();
    await reachHome(t);
    await settle(t);

    // Trends carries the Week/Month/Year SegmentedToggle — the widget that
    // used to animate a blurred shadow in and out over 260ms, on the screen
    // that used to blank itself to skeletons on every range change. This is
    // the scenario that should have improved most.
    final trends = find.text('Trends');
    if (trends.evaluate().isNotEmpty) {
      await t.tap(trends.last);
      await settle(t);

      await measure('trends.range_switching', () async {
        for (final label in const ['14 days', '30 days', '7 days']) {
          final seg = find.text(label);
          if (seg.evaluate().isEmpty) continue;
          await t.tap(seg.first);
          await settle(t);
        }
      });
    }
  });

  testWidgets('focus screen — the largest tree in the app', (t) async {
    app.main();
    await reachHome(t);
    await settle(t);

    final focus = find.text('Focus');
    if (focus.evaluate().isEmpty) {
      markTestSkipped('Focus not reachable from Today in this build');
      return;
    }
    await measure('focus.open_scroll', () async {
      await t.tap(focus.last, warnIfMissed: false);
      await settle(t);
      await scrollCycles(t, find.byType(Scrollable).last, cycles: 4);
    });
  });

  testWidgets('report', (t) async {
    // reportData lives on the binding and survives across tests in this
    // isolate, so this prints the whole run — and leaves reportData intact for
    // `flutter drive` to serialise if you use that path.
    final data = binding.reportData ?? const <String, dynamic>{};
    if (data.isEmpty) {
      // ignore: avoid_print
      print('\nNo frame timings captured. Did you pass -d <device> --profile?');
      return;
    }

    num g(Map m, String k) => (m[k] as num?) ?? -1;

    // ignore: avoid_print
    print('\n===== DEVICE FRAME TIMING =====');
    // ignore: avoid_print
    print('16.7ms is the 60Hz budget; 8.3ms at 120Hz. Build AND raster must '
        'each fit, on the same frame.');
    // ignore: avoid_print
    print('${'scenario'.padRight(26)}${'build p90'.padLeft(11)}'
        '${'raster p90'.padLeft(12)}${'worst'.padLeft(9)}${'frames'.padLeft(8)}');
    for (final e in data.entries) {
      final m = e.value;
      if (m is! Map) continue;
      // ignore: avoid_print
      print('${e.key.padRight(26)}'
          '${g(m, '90th_percentile_frame_build_time_millis').toStringAsFixed(1).padLeft(11)}'
          '${g(m, '90th_percentile_frame_rasterizer_time_millis').toStringAsFixed(1).padLeft(12)}'
          '${g(m, 'worst_frame_build_time_millis').toStringAsFixed(1).padLeft(9)}'
          '${g(m, 'frame_count').toString().padLeft(8)}');
    }
    // ignore: avoid_print
    print('===============================\n');
  });
}
