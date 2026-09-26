import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/focus/models/ambient_sound.dart';
import 'package:tablet_remainder/features/focus/screens/focus_screen.dart';
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_session_alarm.dart';
import 'package:tablet_remainder/features/focus/services/stats_service.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';

import '../../support/fake_audio_engine.dart';

/// The ambient volume slider has to move when you drag it.
///
/// `AmbientSoundSelector` is a StatelessWidget and takes the volume as a VALUE,
/// and the sheet that hosts it had no listener of any kind — a modal sheet is
/// its own route, so the Focus screen's own `ListenableBuilder` does not rebuild
/// it. `Slider.value` was therefore pinned to whatever `_focusService
/// .soundVolume` happened to be when the sheet opened: the audio volume
/// followed the drag, and the control reporting it sat still and snapped back
/// on release.
///
/// The sibling sheet on the same screen (`_showSessionSetupSheet`) already
/// carries the inner `ListenableBuilder` for exactly this reason.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  final focus = FocusService();

  final t0 = DateTime(2026, 3, 14, 13, 0);

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.loadAppPreferences();
    AudioService().engineForTesting = FakeAudioEngine();
    focus.alarmForTesting = RecordingFocusSessionAlarm();
    focus.resetForTesting();
    CoinsService().resetForTesting();
    TagService().resetForTesting();
    StatsService().resetForTesting();
    await focus.init();
  });

  tearDown(() async {
    focus.resetForTesting();
    StatsService().resetForTesting();
    await db.close();
  });

  /// Open the Focus screen on a running session — the one state that puts the
  /// ambient sound card inline instead of two taps deep — and then open the
  /// sound picker from it.
  Future<void> openSoundPicker(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(375, 1400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: FocusScreen()));
    // Never pumpAndSettle a Focus screen: it runs looping pulse animations.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 350));

    await tester.ensureVisible(find.text('White Noise'));
    await tester.pump();
    await tester.tap(find.text('White Noise'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets('the slider follows the volume while the sheet is open',
      (tester) async {
    await withClock(Clock.fixed(t0), () async {
      // A sound has to be chosen for the selector to render a volume row at all.
      focus.setSound(AmbientSoundType.whiteNoise);
      focus.setDuration(25);
      await focus.startSession();

      await openSoundPicker(tester);

      // try/finally, because the session installs a periodic timer and
      // `_verifyInvariants` runs BEFORE any tearDown: a failing assertion would
      // otherwise be reported as "A Timer is still pending" instead of as
      // itself.
      try {
        expect(find.byType(Slider), findsOneWidget,
            reason: 'sanity: the sheet with the volume row really is open');
        expect(tester.widget<Slider>(find.byType(Slider)).value, 0.5,
            reason: 'sanity: the default volume');

        // Exactly what one frame of a drag does.
        focus.setSoundVolume(0.9, persist: false);
        await tester.pump();

        expect(tester.widget<Slider>(find.byType(Slider)).value, 0.9,
            reason: 'BEFORE THE FIX the sheet body was built once, so the '
                'thumb was frozen at the volume the sheet opened with while '
                'the audio it controls moved underneath it');
      } finally {
        focus.resetForTesting();
        await tester.pump();
      }
    });
  });

  testWidgets('a real drag moves the thumb', (tester) async {
    // The assertion above drives the service directly, which proves the sheet
    // rebuilds but not that the slider is wired to anything. This drags the
    // actual control.
    await withClock(Clock.fixed(t0), () async {
      focus.setSound(AmbientSoundType.whiteNoise);
      focus.setDuration(25);
      await focus.startSession();

      await openSoundPicker(tester);

      try {
        final slider = find.byType(Slider);
        await tester.drag(slider, const Offset(-200, 0));
        await tester.pump();

        expect(focus.soundVolume, lessThan(0.5),
            reason: 'sanity: dragging left really did lower the volume');
        expect(tester.widget<Slider>(slider).value, focus.soundVolume,
            reason: 'the control must report the value it just set');
      } finally {
        focus.resetForTesting();
        await tester.pump();
      }
    });
  });
}
