/// `AppListGroup` and the divider geometry it fixes.
///
/// Four call sites across three screens hand-rolled this card-of-rows, each with
/// its own copy of a `_withDividers` helper. They agreed on the numbers because
/// they were copies of each other, not because the numbers were right: the
/// separator was indented 52 while the tile's text starts at 62, and stopped 8
/// from the right while the tile pads 12.
///
/// The interesting assertion here is not "the indent is 62" — that is just
/// restating the constant. It is that the indent MATCHES WHERE THE TILE'S TEXT
/// ACTUALLY IS, measured off a rendered tile. That version fails if someone
/// changes the tile's padding and leaves every divider in the app behind.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';

import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ));
    await tester.pump();
  }

  List<Widget> tiles(int n) => [
        for (var i = 0; i < n; i++)
          AppListTile(
            icon: Symbols.pill_rounded,
            title: 'Row $i',
            subtitle: 'Subtitle $i',
            onTap: () {},
          ),
      ];

  group('separatedBy', () {
    test('puts a separator between items and nowhere else', () {
      final sep = Container(key: const Key('sep'));
      final out = separatedBy(
        [const Text('a'), const Text('b'), const Text('c')],
        sep,
      );
      expect(out.length, 5);
      expect(out.where((w) => w == sep).length, 2);
      // The failure mode: a stray rule under the last row, forever.
      expect(out.last, isNot(sep));
      expect(out.first, isNot(sep));
    });

    test('leaves a single item and an empty list alone', () {
      final sep = Container();
      expect(separatedBy([const Text('a')], sep), hasLength(1));
      expect(separatedBy(<Widget>[], sep), isEmpty);
    });
  });

  group('AppListGroup', () {
    testWidgets('draws n-1 separators', (tester) async {
      await pump(tester, AppListGroup(children: tiles(3)));
      expect(find.byType(Divider), findsNWidgets(2));
    });

    testWidgets('a single row gets no separator', (tester) async {
      await pump(tester, AppListGroup(children: tiles(1)));
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('separated: false draws none', (tester) async {
      await pump(
          tester, AppListGroup(separated: false, children: tiles(3)));
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('the separator starts where the tile text starts',
        (tester) async {
      await pump(tester, AppListGroup(children: tiles(2)));

      // Measured, not asserted against the constant. The tile's title Text and
      // the Divider are both laid out for real; their left edges must line up.
      final title = tester.getTopLeft(find.text('Row 0'));
      final divider = find.byType(Divider);
      final dividerBox = tester.renderObject<RenderBox>(divider);
      final dividerLeft =
          dividerBox.localToGlobal(Offset.zero).dx;

      // The Divider widget's own box spans the full width; the painted rule is
      // inset by `indent`. Read the indent off the widget and add it.
      final indent = tester.widget<Divider>(divider).indent!;
      expect(dividerLeft + indent, closeTo(title.dx, 0.5),
          reason: 'the rule and the text it separates must share a left edge. '
              'The old hand-rolled value of 52 sat 10pt to the left of the '
              'text at 62, which is what made these lists read as crooked.');
    });

    testWidgets('the separator ends where the tile content ends',
        (tester) async {
      await pump(tester, AppListGroup(children: tiles(2)));
      final divider = tester.widget<Divider>(find.byType(Divider));
      // The old value was 8 against a tile that pads 12, so the rule overshot
      // the content at the right-hand end by 4pt.
      expect(divider.endIndent, AppRowMetrics.horizontalPadding);
    });
  });

  group('metrics are derived, not copied', () {
    test('textInset is the sum of the tile parts', () {
      expect(AppRowMetrics.iconBox, 36);
      expect(AppRowMetrics.textInset, 62);
      expect(
        AppRowMetrics.textInset,
        AppRowMetrics.horizontalPadding +
            AppRowMetrics.iconBox +
            AppRowMetrics.iconGap,
      );
    });

    test('no screen hand-rolls a divider list any more', () {
      // Source-grep in the repo's established idiom. `indent: 52` was the
      // fingerprint of every copy.
      final offenders = <String>[];
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        // The definition site names both fingerprints in prose, explaining what
        // it replaced. Asserting over its own documentation is how a guard
        // fails on the fix rather than on the bug.
        if (f.path.endsWith('list_group.dart')) continue;
        final src = f
            .readAsLinesSync()
            .where((l) => !l.trimLeft().startsWith('//'))
            .join('\n');
        if (src.contains('_withDividers') || src.contains('indent: 52')) {
          offenders.add(f.path);
        }
      }
      expect(offenders, isEmpty,
          reason: 'use AppListGroup — its separator geometry is derived from '
              'AppListTile instead of guessed. Found: $offenders');
    });
  });
}
