/// `AppHeader`'s title is a real heading.
///
/// Every screen in the app puts its name in this one widget, so the title was
/// the single most important string to be navigable — and it was a plain
/// `Text`. A screen-reader user landing on a pushed screen had no heading to
/// jump to and had to swipe from the back button into the body to find out
/// where they were. `SectionHeader` had been doing this correctly for section
/// titles all along (see `section_header_a11y_test.dart`); the screen title
/// simply never got the same treatment.
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_header.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  /// Every node in the live semantics tree, read from the owner rather than by
  /// walking elements — `tester.getSemantics` routes through a debug-only
  /// element visitor that throws on this app's viewports.
  List<SemanticsNode> nodes(WidgetTester tester) {
    // ignore: deprecated_member_use
    final root = tester.binding.pipelineOwner.semanticsOwner?.rootSemanticsNode;
    expect(root, isNotNull, reason: 'ensureSemantics() must be held open');
    final out = <SemanticsNode>[];
    void walk(SemanticsNode n) {
      out.add(n);
      n.visitChildren((c) {
        walk(c);
        return true;
      });
    }

    walk(root!);
    return out;
  }

  Future<void> pump(WidgetTester tester, WidgetBuilder header) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(builder: (context) => Column(children: [header(context)])),
      ),
    ));
    await tester.pump();
  }

  testWidgets('a screen title is announced as a heading', (tester) async {
    final handle = tester.ensureSemantics();

    await pump(tester, (_) => const AppHeader(title: 'Blood pressure'));

    final headings = nodes(tester)
        .where((n) => n.hasFlag(SemanticsFlag.isHeader))
        .map((n) => n.label)
        .toList();

    expect(headings, contains('Blood pressure'),
        reason: 'the rotor has nothing to jump to on a screen whose title is '
            'ordinary text. Headers found: $headings');

    handle.dispose();
  });

  testWidgets('both layouts carry it, and the back button stays separate',
      (tester) async {
    final handle = tester.ensureSemantics();

    for (final layout in HeaderLayout.values) {
      await pump(
        tester,
        (context) => AppHeader(
          title: 'Today',
          layout: layout,
          leading: AppHeader.backButton(context),
        ),
      );

      final all = nodes(tester);
      final headings =
          all.where((n) => n.hasFlag(SemanticsFlag.isHeader)).toList();
      expect(headings, hasLength(1), reason: 'layout: $layout');
      expect(headings.single.label, 'Today', reason: 'layout: $layout');

      // A landmark you can activate is not a landmark: if the title merged with
      // the back button beside it, a reader who lands on "Today" and double
      // taps navigates away instead of staying put.
      expect(headings.single.getSemanticsData().actions, 0,
          reason: 'the title absorbed a tap action — layout: $layout');
      final tappable = all
          .where((n) =>
              (n.getSemanticsData().actions & SemanticsAction.tap.index) != 0)
          .toList();
      expect(tappable, hasLength(1),
          reason: 'the back button must stay its own node — layout: $layout');
      expect(tappable.single.hasFlag(SemanticsFlag.isHeader), isFalse,
          reason: 'layout: $layout');
    }

    handle.dispose();
  });
}
