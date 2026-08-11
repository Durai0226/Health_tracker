import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression cover for the reported *"tab switch has some glitch"* and the
/// Today page becoming unscrollable after skipping a dose.
///
/// `ModalRoute` wraps a route's content in exactly ONE [PrimaryScrollController]
/// (framework: `widgets/routes.dart:1199`). Any vertical `ScrollView` with no
/// explicit controller silently attaches to it — `ScrollView.build` resolves
/// `effectivePrimary = primary ?? controller == null &&
/// PrimaryScrollController.shouldInherit(...)`, which is true on mobile.
///
/// `IndexedStack` keeps every child **alive** at once, so Today, Health and
/// Insights were all attaching to that single controller simultaneously
/// (Meds was fine — it declares its own controller). One controller driving
/// three positions asserts on every `.offset` / `.position` read, and offset
/// corrections land on the wrong tab.
///
/// The first test pins the broken behaviour so the fix can't be "simplified"
/// away; the rest prove the fix and guard the real `AppShell` source, in the
/// style of this repo's existing `test/ai/ai_no_network_guard_test.dart`.
void main() {
  /// Two tabs in a live `IndexedStack`, each an intentionally controller-less
  /// `ListView` — exactly what the real tab screens are.
  ///
  /// When [isolated] is true each child is wrapped in its own
  /// [PrimaryScrollController], which is the shipped fix.
  Widget twoLiveTabs({
    required bool isolated,
    required List<ScrollController> controllers,
  }) {
    Widget list(String label) => ListView(
          children: [
            for (var i = 0; i < 40; i++)
              SizedBox(height: 40, child: Text('$label-$i')),
          ],
        );

    final children = <Widget>[list('a'), list('b')];

    return MaterialApp(
      home: Scaffold(
        body: IndexedStack(
          index: 0,
          children: [
            for (var i = 0; i < children.length; i++)
              if (isolated)
                PrimaryScrollController(
                  controller: controllers[i],
                  child: children[i],
                )
              else
                children[i],
          ],
        ),
      ),
    );
  }

  testWidgets('BUG: live IndexedStack tabs share one PrimaryScrollController',
      (tester) async {
    await tester.pumpWidget(twoLiveTabs(isolated: false, controllers: const []));

    // Read the route's controller from above the stack — a ScrollView that has
    // consumed the primary controller inserts a `PrimaryScrollController.none()`
    // barrier below itself (scroll_view.dart:532), so a context *inside* a tab
    // deliberately can't see it.
    final routeController = PrimaryScrollController.of(
      tester.element(find.byType(IndexedStack)),
    );

    expect(routeController.positions.length, 2,
        reason: 'the defect: one controller driving two live tabs');

    // Which makes the controller unusable — the framework asserts rather than
    // guessing which tab you meant. This is the mechanism behind both symptoms.
    expect(() => routeController.offset, throwsAssertionError);
    expect(() => routeController.position, throwsAssertionError);
  });

  testWidgets('FIX: one controller per tab, each with a single position',
      (tester) async {
    final a = ScrollController();
    final b = ScrollController();
    addTearDown(a.dispose);
    addTearDown(b.dispose);

    await tester.pumpWidget(twoLiveTabs(isolated: true, controllers: [a, b]));

    expect(a.positions.length, 1);
    expect(b.positions.length, 1);
    expect(a.offset, 0.0);
    expect(b.offset, 0.0);

    // And the route's own controller is now driving nothing, so nothing can
    // corrupt it.
    final routeController = PrimaryScrollController.of(
      tester.element(find.byType(IndexedStack)),
    );
    expect(routeController.positions, isEmpty);
  });

  testWidgets('FIX: scrolling one tab does not move the other', (tester) async {
    final a = ScrollController();
    final b = ScrollController();
    addTearDown(a.dispose);
    addTearDown(b.dispose);

    await tester.pumpWidget(twoLiveTabs(isolated: true, controllers: [a, b]));

    a.jumpTo(200);
    await tester.pump();

    expect(a.offset, 200.0);
    expect(b.offset, 0.0,
        reason: 'independent offsets are what stops the tab-switch jump');
  });

  testWidgets('FIX: a tab whose content shrinks corrects its OWN offset',
      (tester) async {
    // This is the skip-a-dose case: Today's content gets shorter, so the offset
    // must be clamped back — but only for Today. With a shared controller the
    // correction was applied against another tab's metrics.
    final a = ScrollController();
    final b = ScrollController();
    addTearDown(a.dispose);
    addTearDown(b.dispose);

    Widget build(int rowsInA) => MaterialApp(
          home: Scaffold(
            body: IndexedStack(
              index: 0,
              children: [
                PrimaryScrollController(
                  controller: a,
                  child: ListView(children: [
                    for (var i = 0; i < rowsInA; i++)
                      SizedBox(height: 40, child: Text('a-$i')),
                  ]),
                ),
                PrimaryScrollController(
                  controller: b,
                  child: ListView(children: [
                    for (var i = 0; i < 40; i++)
                      SizedBox(height: 40, child: Text('b-$i')),
                  ]),
                ),
              ],
            ),
          ),
        );

    await tester.pumpWidget(build(40));
    a.jumpTo(a.position.maxScrollExtent);
    await tester.pump();
    expect(a.offset, greaterThan(0));

    // Content shrinks (a dose resolved and its card disappeared).
    await tester.pumpWidget(build(12));
    await tester.pumpAndSettle();

    expect(a.offset, lessThanOrEqualTo(a.position.maxScrollExtent),
        reason: 'the offset must be clamped into the new, shorter extent');
    expect(b.offset, 0.0, reason: 'the other tab must be untouched');
  });

  test('GUARD: AppShell wraps every IndexedStack child in its own controller',
      () {
    // Source-level, because a unit test of AppShell itself would need Firebase +
    // Drift + every service — while the regression is trivially reintroduced by
    // editing the widget tree.
    final src =
        File('lib/features/home/screens/app_shell.dart').readAsStringSync();

    expect(src, contains('IndexedStack'));
    expect(src, contains('PrimaryScrollController('),
        reason: 'IndexedStack children must each get their own controller');
    expect(src, contains('_tabScrollControllers'),
        reason: 'the shell must own (and dispose) one controller per tab');
    expect(src, contains('c.dispose()'),
        reason: 'undisposed controllers leak one position per tab per rebuild');

    // The wrapper must be INSIDE the stack, per child. One controller around the
    // whole IndexedStack would reintroduce the bug exactly.
    final stackAt = src.indexOf('IndexedStack(');
    final wrapAt = src.indexOf('PrimaryScrollController(', stackAt);
    expect(stackAt, greaterThan(-1));
    expect(wrapAt, greaterThan(stackAt),
        reason: 'PrimaryScrollController must wrap each child, not the stack');
  });
}
