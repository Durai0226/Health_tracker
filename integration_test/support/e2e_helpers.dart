import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shared driving helpers for the device suites.
///
/// `settle()` and `reachHome()` were byte-identical in two integration suites;
/// a third copy was one too many.

/// Pumps a fixed number of frames rather than waiting for quiescence.
///
/// NOT `pumpAndSettle`: this app runs continuous animations (the nav orb, the
/// loading skeletons, ad views) that never reach a settled state, so
/// `pumpAndSettle` times out rather than returning.
Future<void> settle(
  WidgetTester t, [
  Duration d = const Duration(milliseconds: 250),
  int frames = 12,
]) async {
  for (var i = 0; i < frames; i++) {
    await t.pump(d);
  }
}

/// Gets past first-run onboarding to the app shell, if it is shown.
///
/// Returns immediately when already at the shell. Advances only via benign
/// buttons — it deliberately never taps anything that would raise a native
/// permission dialog, which a widget test cannot dismiss.
///
/// Pass `--dart-define=E2E_TEST=true` and this is near-instant: `main.dart:321`
/// routes straight to `/home`, and `:106` skips notification/ad init, which
/// also keeps that work out of any frame timings measured afterwards.
Future<void> reachHome(WidgetTester t) async {
  for (var i = 0; i < 14; i++) {
    await t.pump(const Duration(milliseconds: 300));
  }
  const advances = [
    'Skip for now',
    'Continue',
    'Get Started',
    'Get started',
    'Next',
    'Done',
    'Finish',
    "Let's go",
    'Start tracking',
  ];
  for (var i = 0; i < 24; i++) {
    if (find.text('Today').evaluate().isNotEmpty &&
        find.text('Health').evaluate().isNotEmpty) {
      return; // shell reached
    }
    for (final label in advances) {
      final f = find.text(label);
      if (f.evaluate().isNotEmpty) {
        await t.tap(f.last, warnIfMissed: false);
        break;
      }
    }
    for (var j = 0; j < 6; j++) {
      await t.pump(const Duration(milliseconds: 300));
    }
  }
}

/// Drives a real scroll, long enough for percentiles to mean something.
///
/// `FrameTimingSummarizer` will happily compute a "90th percentile" from four
/// frames; that number is the worst frame wearing a statistic's clothes. Each
/// cycle here is a full fling down and back up.
Future<void> scrollCycles(
  WidgetTester t,
  Finder scrollable, {
  int cycles = 5,
}) async {
  if (scrollable.evaluate().isEmpty) return;
  for (var c = 0; c < cycles; c++) {
    await t.fling(scrollable, const Offset(0, -320), 1400);
    await settle(t, const Duration(milliseconds: 100), 12);
    await t.fling(scrollable, const Offset(0, 320), 1400);
    await settle(t, const Duration(milliseconds: 100), 12);
  }
}
