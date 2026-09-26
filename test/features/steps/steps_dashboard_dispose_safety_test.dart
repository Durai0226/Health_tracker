/// The Steps dashboard must not touch its `BuildContext` after it is gone.
///
/// An audit reported that opening and closing this screen threw *"Looking up a
/// deactivated widget's ancestor is unsafe"* — the class of defect that lets a
/// closed screen reach for `ScaffoldMessenger`, `MediaQuery` or `Navigator`
/// through an element the framework has already torn down, and which the
/// screen-build-cost harness cannot see because it swallows
/// `FlutterError.onError`.
///
/// This test installs its own collector and asserts nothing of that kind fires
/// while the screen is opened, closed and pumped again — including the
/// post-frame goal-celebration callback and the milestone/availability probes,
/// which all land after the screen may be gone. Layout overflow is deliberately
/// ignored: it is a different defect, covered by the responsive suite.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/steps/screens/steps_dashboard_screen.dart';
import 'package:tablet_remainder/features/steps/services/step_service.dart';

/// Errors that mean "this widget used a context it no longer owns".
bool _isUseAfterDispose(Object e) {
  final s = e.toString();
  return s.contains('deactivated widget') ||
      s.contains('after being disposed') ||
      s.contains('was used after being disposed') ||
      s.contains('setState() called after dispose()') ||
      s.contains('_dependents.isEmpty');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late db.AppDatabase database;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    await StepService.resetForTesting();
  });

  tearDown(() async => database.close());

  testWidgets('opening and closing it touches no dead context',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final caught = <String>[];
    final other = <String>[];
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      final s = d.exception.toString();
      if (_isUseAfterDispose(d.exception)) {
        caught.add(s.split('\n').first);
      } else if (s.contains('overflowed by')) {
        // Layout overflow is a different defect, covered by the responsive
        // suite. Everything ELSE is collected — a collector that silently
        // drops non-matching errors would let a build exception in this very
        // screen pass as a clean run, which is how the harness this test
        // exists to replace stayed blind for months.
      } else {
        other.add(s.split('\n').first);
      }
    };

    try {
      // A pinned clock is how the audit reproduced it; it also keeps the
      // week/day-dependent parts of the screen deterministic.
      await withClock(Clock.fixed(DateTime(2026, 3, 12, 13)), () async {
        for (var i = 0; i < 3; i++) {
          await tester.pumpWidget(MaterialApp(
            theme: AppTheme.lightTheme,
            home: const StepsDashboardScreen(),
          ));
          // Let init(), the availability probe and the milestone sync land, and
          // let the post-frame celebration callback run at least once.
          for (var f = 0; f < 6; f++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          // Close it while those callbacks are still in flight.
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(milliseconds: 16));
          await tester.pump(const Duration(seconds: 8));
        }
      });
    } finally {
      FlutterError.onError = prev;
    }

    // The screen must actually have RENDERED. Without this the test passes just
    // as happily when the widget throws on build and puts up an ErrorWidget —
    // no context is touched after dispose if nothing was ever built.
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const StepsDashboardScreen(),
    ));
    for (var f = 0; f < 6; f++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.byType(ErrorWidget), findsNothing,
        reason: 'the screen must build, or this test proves nothing');
    expect(find.byType(StepsDashboardScreen), findsOneWidget);

    // Drain the screen's own availability-probe timeout, or the binding fails
    // the test on a pending timer rather than on anything we are measuring.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 8));

    expect(caught, isEmpty, reason: caught.join(' | '));
    expect(other, isEmpty,
        reason: 'framework errors other than overflow: ${other.join(' | ')}');
  });
}
