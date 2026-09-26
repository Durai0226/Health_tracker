@Tags(['performance'])
library;

/// A running focus timer must not rebuild the whole Focus screen every second.
///
/// The Focus screen is a `SingleChildScrollView` over thirteen configuration
/// sections — mode toggle, duration, pomodoro config, coach card, activity,
/// tags, plants, sound, breathing, relaxation, features grid, quick stats. The
/// build-cost harness measures it at **2322 widgets, the largest tree in the
/// app by roughly 3x**.
///
/// All of it sat inside one `ListenableBuilder` on `FocusService`, and
/// `_startTimer` called `notifyListeners()` once a second. So a 25-minute
/// pomodoro rebuilt 2322 widgets 1500 times. `HomeDashboard` listens to the
/// same service, so it was rebuilding at 1 Hz too.
///
/// `FocusService.tick` now carries the per-second signal on its own
/// `ValueNotifier`, and only the clock and progress ring listen to it.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/relaxation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the per-second tick is not a ChangeNotifier notification', () {
    // Singleton (focus_service.dart:17-19) — never dispose it in a test.
    final service = FocusService();

    var structuralRebuilds = 0;
    void listener() => structuralRebuilds++;
    service.addListener(listener);
    addTearDown(() => service.removeListener(listener));

    var tickRebuilds = 0;
    void onTick() => tickRebuilds++;
    service.tick.addListener(onTick);
    addTearDown(() => service.tick.removeListener(onTick));

    // Drive the REAL per-second code path, not the notifier in isolation —
    // otherwise reinstating notifyListeners() inside applyTick would not fail
    // this test.
    for (var s = 300; s > 295; s--) {
      service.applyTick(s);
    }

    expect(tickRebuilds, 5,
        reason: 'the countdown must be delivered on the tick notifier');
    expect(
      structuralRebuilds,
      0,
      reason: 'The per-second countdown fired the ChangeNotifier, which the '
          'Focus screen listens to around its entire 2322-widget body — and '
          'HomeDashboard listens to as well. A 25-minute session rebuilt both '
          '1500 times. Only the clock and the ring may react to the tick.',
    );
  });

  test('the relaxation countdown is not a ChangeNotifier notification', () {
    // RelaxationScreen.build wraps its ENTIRE 1078-line body in one
    // ListenableBuilder on this service, including a shrinkWrap ListView that
    // builds every track eagerly. A per-second notifyListeners() rebuilt all
    // of it 60 times a minute for the length of the session.
    final service = RelaxationService();
    // Singleton: a session left running by an earlier test in this isolate
    // would give `applyTick` a non-null `_endTime` and send it down the
    // wall-clock branch, so the exact countdown asserted below would depend on
    // test order.
    service.resetForTesting();

    var structuralRebuilds = 0;
    void listener() => structuralRebuilds++;
    service.addListener(listener);
    addTearDown(() => service.removeListener(listener));

    var tickRebuilds = 0;
    void onTick() => tickRebuilds++;
    service.tick.addListener(onTick);
    addTearDown(() => service.tick.removeListener(onTick));

    // A running session is required: applyTick correctly no-ops when nothing
    // is running, so without this the loop body never executes and the test
    // passes with the bug restored (it did exactly that on the first attempt).
    service.primeForTest(seconds: 60);
    for (var i = 0; i < 3; i++) {
      service.applyTick();
    }
    expect(tickRebuilds, 3, reason: 'the countdown must reach the tick notifier');

    expect(
      structuralRebuilds,
      0,
      reason: 'The relaxation countdown fired the ChangeNotifier that the '
          'whole screen listens to. Only the clock may react to a tick.',
    );
    // Counting notifications is not enough: the clock widget renders
    // `tick.value`, so a tick that fires without carrying the new remaining
    // seconds leaves a frozen number on screen while the ChangeNotifier stays
    // (correctly) silent — i.e. the scoping fix would have traded a rebuild
    // storm for a stopped clock. Three ticks from a primed 60 s session must
    // land on 57, and the service's own countdown must agree with what it
    // published.
    expect(service.tick.value, 57,
        reason: 'the tick notifier must carry the countdown, not just signal '
            'that one happened — the clock reads this value directly');
    expect(service.remainingSeconds, service.tick.value,
        reason: 'the published tick and the service\'s own remaining time must '
            'not disagree about how much of the session is left');
  });

  testWidgets('the tick notifier drives a rebuild on its own', (tester) async {
    // Half of the scoping fix is that `tick` is a real ValueListenable a narrow
    // builder can bind to, and that setting it repaints only that builder.
    //
    // This was named "the Focus screen listens to the tick separately" and its
    // comment claimed to assert that a ValueListenableBuilder bound to
    // FocusService.tick EXISTS in the screen. It did no such thing: it built
    // its own ValueListenableBuilder here in the test body and never referred
    // to `focus_screen.dart` at all. Deleting the screen's narrow builder and
    // putting the whole 2322-widget body back under one ListenableBuilder left
    // this green — the test measured Flutter's ValueListenableBuilder, not the
    // app's use of it. The wiring assertion it was supposed to make now lives
    // in the source guard below.
    final service = FocusService();

    var built = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder<int>(
          valueListenable: service.tick,
          builder: (context, value, _) {
            built++;
            return Text('$value');
          },
        ),
      ),
    ));

    expect(built, 1);
    service.tick.value = 42;
    await tester.pump();

    expect(built, 2, reason: 'the tick notifier must drive a rebuild');
    expect(find.text('42'), findsOneWidget);
  });

  test('each screen binds its clock to the tick, not its whole body', () {
    // The two tests above prove a tick does NOT fire notifyListeners(). They
    // prove nothing about either screen actually reading it: delete the narrow
    // builder, put the body back under one ListenableBuilder, and both still
    // pass while the on-screen clock silently stops counting.
    //
    // Mounting FocusScreen or RelaxationScreen here is not an option — between
    // them they need the whole service stack and start real timers — so the
    // wiring is read out of the source, the way
    // test/release/ambient_refresh_wiring_test.dart already does for the shell.
    //
    // Anchored on the `ValueListenableBuilder<int>(` + `valueListenable:` PAIR,
    // not on either half alone. `relaxation_screen.dart` already carries a
    // SECOND ValueListenableBuilder on a different notifier, so the widget name
    // alone does not say the clock is the thing bound; and the bare field name
    // would be satisfied by any plain read of `tick`, `tick.value` included.
    // Matching the pair is what makes deleting the narrow builder fail here.
    const bindings = <String, String>{
      'lib/features/focus/screens/focus_screen.dart': '_focusService.tick',
      'lib/features/focus/screens/relaxation_screen.dart':
          '_relaxationService.tick',
    };

    bindings.forEach((path, field) {
      final src = File(path).readAsStringSync();
      final narrow = RegExp('ValueListenableBuilder<int>\\(\\s*'
          'valueListenable:\\s*${RegExp.escape(field)}\\b');
      expect(
        narrow.hasMatch(src),
        isTrue,
        reason: '$path must drive its clock from `$field` through a '
            'ValueListenableBuilder. Without it the per-second countdown has '
            'no subscriber and the readout freezes, or it comes back through '
            'a ListenableBuilder on the whole service and the rebuild storm '
            'this file exists to prevent is back.',
      );
    });
  });
}
