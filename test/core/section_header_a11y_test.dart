/// `SectionHeader` is a real heading.
///
/// 88 call sites across 34 files use this widget, so putting `header: true`
/// inside it rather than at each call site is the difference between every
/// section in the app being reachable by VoiceOver's rotor / TalkBack's
/// heading navigation and almost none of them being reachable. A screen reader
/// user's alternative is swiping through every row of every list.
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';

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

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ));
    await tester.pump();
  }

  testWidgets('a section title is announced as a heading', (tester) async {
    final handle = tester.ensureSemantics();

    await pump(
      tester,
      const SectionHeader(title: 'Your medicines', icon: Symbols.pill_rounded),
    );

    final headings = nodes(tester)
        .where((n) => n.hasFlag(SemanticsFlag.isHeader))
        .map((n) => n.label)
        .toList();

    expect(headings, contains('Your medicines'),
        reason: 'without this the rotor has nothing to jump to. '
            'Headers found: $headings');

    handle.dispose();
  });

  testWidgets('the section action stays a separate, operable node',
      (tester) async {
    final handle = tester.ensureSemantics();

    var tapped = 0;
    await pump(
      tester,
      SectionHeader(
        title: 'Reminders',
        actionLabel: 'See all',
        onAction: () => tapped++,
      ),
    );

    final all = nodes(tester);
    final heading = all.firstWhere((n) => n.hasFlag(SemanticsFlag.isHeader));
    expect(heading.label, 'Reminders');

    final button = all
        .where((n) =>
            n.label == 'See all' && n.hasFlag(SemanticsFlag.isButton))
        .toList();
    expect(button, hasLength(1),
        reason: 'the action must remain its own button node');
    expect(button.single.hasFlag(SemanticsFlag.isHeader), isFalse);

    // The two assertions that actually discriminate, arrived at by dumping the
    // real tree both ways rather than by reasoning about it.
    //
    // Wrapping the whole header in MergeSemantics — the tempting "clean it up"
    // move — leaves BOTH nodes present and BOTH flagged as before. What it
    // changes is that the button becomes a CHILD of the heading, and the
    // heading absorbs the button's tap action. A landmark you can activate is
    // not a landmark: a screen reader user who lands on "Reminders" and double
    // taps navigates away.
    expect(heading.getSemanticsData().actions, 0,
        reason: 'the heading absorbed an action — the Row is merged, so the '
            'section title is now tappable');

    final descendants = <int>[];
    void collect(SemanticsNode n) {
      n.visitChildren((c) {
        descendants.add(c.id);
        collect(c);
        return true;
      });
    }

    collect(heading);
    expect(descendants, isNot(contains(button.single.id)),
        reason: 'the action must be a SIBLING of the heading, not nested '
            'inside it');

    await tester.tap(find.text('See all'));
    expect(tapped, 1);

    handle.dispose();
  });
}
