import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/app_strings.dart';
import 'support/e2e.dart';

/// Real frame timings — the half a headless harness structurally cannot give.
///
/// `test/performance/screen_build_cost_test.dart` measures wall clock on the
/// host VM in debug mode and says so itself: relative signal, not a device
/// frame budget. It cannot see **raster** time at all, which is where blurred
/// shadows, `saveLayer` and overdraw actually cost you. `watchPerformance`
/// reports both, with percentiles, from the real engine.
///
/// ## Run it
///
/// ```
/// flutter drive --driver=test_driver/integration_test.dart \
///   --target=integration_test/z01_perf_e2e_test.dart \
///   -d emulator-5554 --profile \
///   --dart-define=E2E_TEST=true --dart-define=E2E_SEED=true
/// ```
///
/// Three parts of that are not optional:
///
///  * **`flutter drive`, not `flutter test`.** `flutter test` rejects
///    `--profile` and discards `binding.reportData`; only the driver path
///    persists it (to `build/integration_response_data.json`).
///  * **`--profile`.** Debug builds are 2-10x pessimistic and are not a frame
///    budget. NOTE: `--profile` is *unsupported on the iOS simulator*
///    (`flutter_tools/lib/src/ios/simulators.dart` — `supportsRuntimeMode`
///    admits debug only), which is why this runs on Android.
///  * **`--dart-define=E2E_SEED=true`.** An empty database makes every screen
///    look both fast and small. Timings taken against it describe the empty
///    state, not the app.
///
/// ## What these numbers are, and are not
///
/// An emulator's GPU is the host's. These are real engine frame timings from
/// the real Android compositor, which is far better than a headless
/// approximation and still **not a phone**. They are reported, not scored —
/// `test/support/perf_rating.dart` deliberately scores only counts, booleans
/// and within-run ratios, because the build-cost harness observed an ~8x
/// wall-clock swing between two runs of an identical screen. Admitting a
/// timing threshold would trade reproducibility for a number nobody can
/// reproduce.
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

  /// Drives a real scroll, long enough for percentiles to mean something.
  ///
  /// `FrameTimingSummarizer` will happily compute a "90th percentile" from four
  /// frames; that number is the worst frame wearing a statistic's clothes.
  Future<void> scrollCycles(WidgetTester t, Finder scrollable,
      {int cycles = 5}) async {
    expect(scrollable, findsWidgets,
        reason: 'nothing scrollable here — a scroll measurement over zero '
            'frames would report a fictional p90');
    for (var c = 0; c < cycles; c++) {
      await t.fling(scrollable, const Offset(0, -320), 1400);
      await settle(t, const Duration(milliseconds: 100), 12);
      await t.fling(scrollable, const Offset(0, 320), 1400);
      await settle(t, const Duration(milliseconds: 100), 12);
    }
  }

  testWidgets('scroll and tab-open across all four destinations', (t) async {
    await E2E.launch(t);

    await measure('home.scroll', () async {
      await scrollCycles(t, find.byType(Scrollable).first);
    });

    // Was `if (finder.evaluate().isEmpty) continue;` — a missing tab silently
    // produced no measurement and a green run. goTab asserts arrival.
    for (final tab in const [NavTab.meds, NavTab.health, NavTab.trends]) {
      await measure('${tab.label.toLowerCase()}.open_scroll', () async {
        await E2E.goTab(t, tab);
        await scrollCycles(t, find.byType(Scrollable).first, cycles: 3);
      });
    }

    E2E.assertClean('nav scroll sweep');
  });

  testWidgets('Trends range switching', (t) async {
    await E2E.launch(t);
    await E2E.goTab(t, NavTab.trends);

    // Trends carries the range SegmentedToggle — the widget that used to
    // animate a blurred shadow in and out over 260ms, on the screen that used
    // to blank itself to skeletons on every range change.
    await measure('trends.range_switching', () async {
      for (final label in const [kTrends14, kTrends30, kTrends7]) {
        final seg = find.text(label);
        expect(seg, findsWidgets, reason: 'range option "$label" is missing');
        await t.tap(seg.first);
        await settle(t);
      }
    });

    E2E.assertClean('Trends range switching');
  });

  testWidgets('report', (t) async {
    // e2e-measure-only: prints the run's frame timings. reportData lives on the
    // binding and survives across tests in this isolate, so this covers the
    // whole run, and `flutter drive` still serialises it afterwards.
    final data = binding.reportData ?? const <String, dynamic>{};

    // Was: print "no frame timings captured" and RETURN — a pass. An empty
    // report means the run measured nothing, which is a failure of the
    // measurement, not an absence of findings.
    expect(
      data,
      isNotEmpty,
      reason: 'No frame timings were captured. Either the scenarios above did '
          'not run, or this was invoked without a device. A perf harness that '
          'passes having measured nothing is worse than no harness.',
    );

    num g(Map m, String k) => (m[k] as num?) ?? -1;

    // ignore: avoid_print
    print('\n===== DEVICE FRAME TIMING (Android emulator, profile) =====');
    // ignore: avoid_print
    print('16.7ms is the 60Hz budget; 8.3ms at 120Hz. Build AND raster must '
        'each fit, on the same frame.');
    // ignore: avoid_print
    print('Reported, NOT scored — an emulator GPU is the host GPU. See the '
        'header of this file.');
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
    print('==========================================================\n');
  });
}
