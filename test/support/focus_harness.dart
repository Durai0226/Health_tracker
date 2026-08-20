import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_session_alarm.dart';
import 'package:tablet_remainder/features/focus/services/relaxation_service.dart';
import 'package:tablet_remainder/features/focus/services/stats_service.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';

import 'fake_audio_engine.dart';

/// One `setUp` for every Focus test, because six process-wide singletons and a
/// platform audio player have to be returned to a fresh-install state between
/// tests that share an isolate.
///
/// Everything here is load-bearing. In particular:
///
///  * **`GoogleFonts.config.allowRuntimeFetching = false`** is not cosmetic. Left
///    on, a borderline text measurement depends on whether font resolution
///    happened to finish between pumps, and the identical responsive sweep
///    reported 18 overflowing screens on one run and 4 on the next.
///  * **Never `pumpAndSettle` a Focus screen.** Several run looping pulse and
///    shimmer animations that never settle, so it times out rather than
///    returning. Use [pumpFocus].
///  * **`tick` notifiers are reset, never disposed.** Disposing a singleton's
///    `ValueNotifier` poisons every later test in the isolate.
class FocusHarness {
  FocusHarness._(this.db, this.audio, this.alarm, this.now);

  final AppDatabase db;
  final FakeAudioEngine audio;

  /// The substituted notification scheduler.
  ///
  /// Installed for EVERY Focus test, not only the ones asserting on it: without
  /// it, starting a session reaches `NotificationService` and the real
  /// `flutter_local_notifications` platform instance, which is unregistered
  /// headlessly. That surfaces as noise at best and a `LateInitializationError`
  /// at worst, in tests that are about something else entirely.
  final RecordingFocusSessionAlarm alarm;

  /// The pinned wall clock. Production code reads `clock.now()`, so anything
  /// time-of-day dependent (dose windows, "today" rollover, streak boundaries) is
  /// deterministic instead of depending on when the suite happens to run.
  final DateTime now;

  Future<void> tearDown() async {
    await db.close();
  }
}

/// Bring up a clean Focus world.
///
/// [at] defaults to **today at 13:00**: today's real date is kept because storage
/// resolves "today" through its own calendar reads, while the time is fixed at
/// midday so that scenarios like "two doses already due and one still to come"
/// are expressible. Deriving positions from the real time is what made an earlier
/// suite fail at 00:01, with only one distinct past minute available.
Future<FocusHarness> focusSetUp({DateTime? at}) async {
  GoogleFonts.config.allowRuntimeFetching = false;

  SharedPreferences.setMockInitialValues({});
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  AppDatabase.setInstanceForTesting(db);

  CleanStorageService.resetForTesting();
  ActiveProfileService().resetForTesting();

  final engine = FakeAudioEngine();
  AudioService().engineForTesting = engine;
  AudioService().resetForTesting();

  final alarm = RecordingFocusSessionAlarm();
  FocusService().alarmForTesting = alarm;
  FocusService().resetForTesting();
  RelaxationService().resetForTesting();
  CoinsService().resetForTesting();
  TagService().resetForTesting();
  StatsService().resetForTesting();

  final real = DateTime.now();
  final pinned = at ?? DateTime(real.year, real.month, real.day, 13, 0);
  return FocusHarness._(db, engine, alarm, pinned);
}

/// `testWidgets` inside a pinned clock zone.
///
/// Use this instead of `testWidgets` for anything touching Focus, so a test that
/// passes at 14:00 also passes at 00:01.
void focusTest(
  String description,
  Future<void> Function(WidgetTester tester, FocusHarness h) body, {
  DateTime? at,
}) {
  testWidgets(description, (tester) async {
    final real = DateTime.now();
    final pinned = at ?? DateTime(real.year, real.month, real.day, 13, 0);
    await withClock(Clock.fixed(pinned), () async {
      final h = await focusSetUp(at: pinned);
      try {
        await body(tester, h);
      } finally {
        await h.tearDown();
      }
    });
  });
}

/// Pump a Focus surface without hanging.
///
/// Two pumps rather than `pumpAndSettle`, then a long pump to drain the
/// `.timeout(6s)` guards some screens wrap their init in.
Future<void> pumpFocus(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 350));
}

/// Drain the `.timeout(6s)` init guards so teardown does not trip the
/// pending-timer assertion.
Future<void> drainFocusTimers(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 7));
}

/// Every non-empty string currently rendered.
List<String> visibleText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? '')
    .where((s) => s.trim().isNotEmpty)
    .toList();
