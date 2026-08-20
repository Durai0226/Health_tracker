import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/widgets/toast/premium_toast.dart';
import 'package:tablet_remainder/core/widgets/toast/toast_theme.dart';

/// A toast must BUILD, and it must stop looping when asked to.
///
/// ## Why this file exists
///
/// The reduce-motion fix for toasts shipped broken and every existing test passed.
/// The first version read `MediaQuery.maybeDisableAnimationsOf(context)` inside
/// `State.initState`, where `StatefulElement.dependOnInheritedElement` asserts:
/// in debug it threw *"dependOnInheritedWidgetOfExactType&lt;MediaQuery&gt;() ... was
/// called before State.initState() completed"* and returned null, so **every toast
/// in the app became a red error widget**.
///
/// The bug shipped and **the whole 1299-test suite passed with it in place**. Two
/// mechanisms let it through, and being precise about them matters:
///
///  * Every Focus harness sets `FlutterError.onError = (_) {}` to silence overflow
///    noise. Flutter reports a build-time throw through that same channel, so the
///    exception was absorbed.
///  * The `silent-completion` gate asked `ToastOverlay.hasActiveToasts`, which
///    counts entries in a list. An error widget is still an entry, so the gate was
///    measuring that a toast had been *inserted*, not that it had *rendered*.
///
/// One honest correction to the first telling of this: `focus_first_run_test.dart`
/// is **not** blind to the defect class — reinstating the bug does turn its
/// completion test red. But it did not catch the shipped instance, and
/// `focus_a11y_test.dart` still passes 35/35 with the bug present, because its
/// toast surface was replaced by a bare `ParticleSystem` (for good reasons — see
/// the comment there about auto-dismiss making both directions vacuous). "A test
/// that would fail if you broke it differently" is not the same as coverage.
///
/// So the assertions here are deliberately blunt: pump the real widget with **no
/// error suppression at all** and demand `tester.takeException()` is null. It is
/// the cheapest possible check, and it is the one nothing in the repo was making.
void main() {
  Widget host({required bool reduceMotion, Duration? dismiss}) => MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: Scaffold(
          body: PremiumToast(
            type: ToastType.achievement,
            feature: ToastFeature.focus,
            title: 'Session Complete!',
            message: 'You focused for 25 minutes',
            showParticles: true,
            autoDismissDuration: dismiss ?? const Duration(minutes: 5),
            onDismiss: () {},
          ),
        ),
      );

  for (final reduceMotion in const [false, true]) {
    testWidgets('a toast builds without throwing (reduceMotion: $reduceMotion)',
        (tester) async {
      // NO FlutterError.onError override. That is the whole point.
      await tester.pumpWidget(host(reduceMotion: reduceMotion));
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull,
          reason: 'building a toast must not throw. This is exactly what the '
              'initState MediaQuery read did, invisibly, because every other '
              'harness suppresses FlutterError.onError.');
      expect(find.text('Session Complete!'), findsOneWidget,
          reason: 'and it must actually render its content — an error widget is '
              'still a mounted OverlayEntry, which is why hasActiveToasts could '
              'not see the difference');
    });
  }

  testWidgets('the perpetual loops stop when the user asks for stillness',
      (tester) async {
    // A five-minute auto-dismiss on purpose. At the shipped default of 4 seconds
    // (`ToastTheme.defaultAutoDismiss`) the toast removes itself inside any
    // sensible pump window, and then BOTH directions of this assertion pass for
    // the same wrong reason: nothing is animating because nothing is there. The
    // finite progress controller is the one ticker expected to survive.
    await tester.pumpWidget(host(reduceMotion: true));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    final withReduction = tester.binding.transientCallbackCount;

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));

    await tester.pumpWidget(host(reduceMotion: false));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    final withMotion = tester.binding.transientCallbackCount;

    expect(withMotion, greaterThan(withReduction),
        reason: 'the shimmer, the pulse and the confetti must add tickers when '
            'motion is allowed ($withMotion) and not when it is suppressed '
            '($withReduction). Equal counts mean the preference changed nothing, '
            'or that the motion was deleted rather than made optional.');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
