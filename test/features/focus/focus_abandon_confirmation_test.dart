/// The Give Up confirmation: what it costs to say yes, and what it takes to
/// say no.
///
/// DS-13 asked whether this dialog could become a `ConfirmationBottomSheet`.
/// It cannot yet, and this file is the reason written as assertions rather than
/// as a note: `showDialog(barrierDismissible: false)` is load-bearing here, and
/// `AppBottomSheet.show` — which `ConfirmationBottomSheet` is built on — always
/// calls `showModalBottomSheet` with its defaults, i.e. dismissible by a
/// barrier tap and by a downward drag. Three of the four `barrierDismissible:
/// false` sites left in `lib/` are in this feature, so the conversion would
/// have quietly handed a second, unlabelled way out of a question the author
/// made unskippable.
///
/// The first test is the one that fails the day someone swaps the dialog for a
/// sheet without carrying that across. The other two are the ordinary contract
/// any confirmation owes: no means nothing happened, yes means it did.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/focus/screens/focus_screen.dart';
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_session_alarm.dart';
import 'package:tablet_remainder/features/focus/services/stats_service.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';

import '../../support/fake_audio_engine.dart';

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
    // Abandoning disarms the completion notification and stops the audio before
    // it writes anything; both are platform channels, and both are seamed here
    // so the confirm path can run to completion headlessly.
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

  /// A running countdown session with the Focus screen on top of it.
  ///
  /// Countdown, not flow: flow mode renders **Done** instead of **Give up** and
  /// takes an entirely different path (`_finishFlowSession`), so the control
  /// under test would not be on screen at all.
  Future<void> pumpRunningSession(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(375, 1400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    focus.setDuration(25);
    await focus.startSession();

    await tester.pumpWidget(const MaterialApp(home: FocusScreen()));
    // Never pumpAndSettle a Focus screen: it runs looping pulse animations.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 350));
  }

  /// Open the confirmation from the running session's own control.
  ///
  /// Driven through the button rather than by calling the private method, so
  /// the wiring is part of what is asserted.
  Future<void> openAbandonDialog(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Give up'));
    await tester.pump();
    await tester.tap(find.text('Give up'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Give up?'), findsOneWidget,
        reason: 'the control must still open the confirmation');
  }

  /// Let the abandon payout finish.
  ///
  /// `abandonSession` awaits the disarm, the audio stop and three writes before
  /// `_resetSession` clears `isRunning`, and the dialog button does not await
  /// it — so a single pump lands mid-payout and reads the pre-abandon state.
  /// Pumping past the toast's 4s SnackBar as well, or its timer outlives the
  /// test and is reported instead of whatever actually failed.
  Future<void> settleAbandon(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(seconds: 5));
  }

  testWidgets('a tap outside the confirmation neither closes it nor abandons',
      (tester) async {
    await withClock(Clock.fixed(t0), () async {
      await pumpRunningSession(tester);
      // try/finally: a running session installs a periodic timer, and
      // `_verifyInvariants` runs BEFORE any tearDown — so a failing assertion
      // would otherwise surface as "A Timer is still pending" instead of as
      // itself.
      try {
        await openAbandonDialog(tester);

        // The barrier, well clear of a centred AlertDialog on a 375x1400 view.
        await tester.tapAt(const Offset(10, 10));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.text('Give up?'), findsOneWidget,
            reason: 'barrierDismissible: false — an accidental tap outside '
                'must not answer the question. A ConfirmationBottomSheet '
                'CANNOT hold this line today: AppBottomSheet.show passes no '
                'isDismissible/enableDrag through to showModalBottomSheet.');
        expect(focus.isRunning, isTrue,
            reason: 'and nothing may have been abandoned behind it');
      } finally {
        focus.resetForTesting();
        await tester.pump();
      }
    });
  });

  testWidgets('Keep going abandons nothing', (tester) async {
    await withClock(Clock.fixed(t0), () async {
      await pumpRunningSession(tester);
      try {
        await openAbandonDialog(tester);

        await tester.tap(find.text('Keep going'));
        await settleAbandon(tester);

        expect(find.text('Give up?'), findsNothing);
        expect(focus.isRunning, isTrue,
            reason: 'the cancel button is the LEFT one — if the two handlers '
                'are ever transposed, this is what catches it');
        expect(find.text('Give up'), findsOneWidget,
            reason: 'and the session controls are still the running ones');
      } finally {
        focus.resetForTesting();
        await tester.pump();
      }
    });
  });

  testWidgets('Give up ends the session', (tester) async {
    await withClock(Clock.fixed(t0), () async {
      await pumpRunningSession(tester);
      try {
        await openAbandonDialog(tester);

        // `.last`: 'Give up' is both the control underneath and the confirm
        // button in the dialog above it, and the dialog's route is the later
        // of the two in the tree. The title is 'Give up?', which `find.text`
        // matches whole, so it cannot be picked up here.
        await tester.tap(find.text('Give up').last);
        await settleAbandon(tester);

        expect(find.text('Give up?'), findsNothing);
        expect(focus.isRunning, isFalse,
            reason: 'confirming must actually end the session — a destructive '
                'yes that becomes a no-op is the silent half of this failure');
        expect(find.text('Start Focus'), findsOneWidget,
            reason: 'and the surface must return to its resting state — the '
                'idle primary action for single mode');
      } finally {
        focus.resetForTesting();
        await tester.pump();
      }
    });
  });
}
