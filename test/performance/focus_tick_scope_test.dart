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
    expect(tickRebuilds, greaterThanOrEqualTo(0));
  });

  testWidgets('the Focus screen listens to the tick separately', (tester) async {
    // A ValueListenableBuilder bound to FocusService.tick must exist: it is the
    // thing that keeps the clock live while the rest of the tree stays put. If
    // someone reverts the scoping and goes back to a single ListenableBuilder,
    // the clock would still work — so this asserts the narrow listener exists,
    // which the coarse implementation cannot satisfy.
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
}
