/// The settings row's geometry, measured off a rendered row.
///
/// **Zero committed test files referenced `SettingsTile` or `SettingsSection`
/// before this one.** The shared widget behind every settings row in the app had
/// no widget-level layout test at any level, so the screen-level omission — the
/// responsive sweep only checked `AppHeader` for wrapping — compounded instead of
/// being caught beneath it.
///
/// This is the gate that would have caught the reported defect directly: the row
/// gave its text `Expanded(flex: 3)` and its trailing `Flexible(flex: 2)`, a
/// tight 60% against a loose 40%, so the leftover beside a 60pt switch was never
/// handed back to a title wrapping in 162.6pt.
///
/// Every number here is measured off the tree, never asserted against the
/// constant it came from — which is the mistake worth not repeating from the
/// divider work.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/design/app_design.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  /// Pumps one row inside the layout every settings screen actually uses: a
  /// gutter-padded ListView holding a SettingsSection.
  Future<void> pumpRow(
    WidgetTester tester, {
    required double width,
    required Widget row,
    double scale = 1.0,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(
            size: Size(width, 900), textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            children: [SettingsSection(children: [row])],
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  /// The width the title's paragraph was actually laid out in.
  double titleColumn(WidgetTester tester, String title) =>
      tester.renderObject<RenderBox>(find.text(title)).constraints.maxWidth;

  // ------------------------------------------------------- the flex fix

  group('the trailing takes what it needs, and the title takes the rest', () {
    testWidgets('a switch row leaves the title far more than 60% of the flex',
        (tester) async {
      // Before: 0.6 x (W - 122). After: (W - 122) - 60.
      final expected = <double, double>{320: 134, 360: 174, 393: 207, 430: 244};
      for (final entry in expected.entries) {
        await pumpRow(
          tester,
          width: entry.key,
          row: SettingsTile(
            icon: Symbols.notifications_rounded,
            title: 'Sound',
            switchValue: true,
            onSwitchChanged: (_) {},
          ),
        );
        expect(titleColumn(tester, 'Sound'), entry.value,
            reason: 'at ${entry.key}pt the old split gave '
                '${(0.6 * (entry.key - 122)).toStringAsFixed(1)}pt');
      }
    });

    testWidgets('a chevron row gets more still, because a chevron is 22pt',
        (tester) async {
      // The row type where the old fixed 40% was most wasteful: it reserved
      // 108.4pt at 393 for a 22pt glyph.
      await pumpRow(
        tester,
        width: 393,
        row: SettingsTile(
          icon: Symbols.notifications_rounded,
          title: 'Sound',
          onTap: () {},
        ),
      );
      expect(titleColumn(tester, 'Sound'), 245.0);
    });

    testWidgets('an intrinsically wide trailing cannot starve the title',
        (tester) async {
      // The inverse failure, and the one `AppListTile` actually shipped: with
      // the trailing unconstrained, a long `trailing: Text(...)` took its full
      // intrinsic width first and collapsed the title column to 0.0pt.
      await pumpRow(
        tester,
        width: 360,
        row: const SettingsTile(
          icon: Symbols.sync_rounded,
          title: 'Sync',
          trailing: Text('Every 15 minutes, on Wi-Fi only'),
        ),
      );
      expect(tester.takeException(), isNull);
      // 145.2pt at 360, against **0.0pt** from the widget this replaces — and a
      // `RenderFlex overflowed by 188 pixels` with it. The meaningful bar is
      // that the title keeps more of the row than the trailing does, whatever
      // the cap is tuned to.
      final col = titleColumn(tester, 'Sync');
      // Against the trailing's ALLOTMENT, not against `getSize` on its text —
      // inside a `FittedBox(scaleDown)` the child is laid out unconstrained and
      // then scaled, so its paragraph reports 434pt while it paints inside 88.8.
      // Measuring the wrong number there cost me a red test.
      final content =
          tester.getSize(find.byType(SettingsTile)).width -
              AppRowMetrics.horizontalPadding * 2;
      final cap = content * AppRowMetrics.trailingShare;
      expect(col, greaterThan(cap),
          reason: 'title column $col against a trailing capped at $cap');
      expect(col, greaterThan(140.0), reason: 'title column was $col');
    });

    testWidgets('a switch is never squeezed narrower than it can render',
        (tester) async {
      // The cap has a floor for exactly this: a Material-sized switch box does
      // not shrink to fit a constraint, it overflows.
      await pumpRow(
        tester,
        width: 320,
        row: SettingsTile(
          icon: Symbols.notifications_rounded,
          title: 'A deliberately long row title that wants every pixel',
          switchValue: false,
          onSwitchChanged: (_) {},
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(AppSwitch)), AppSwitch.size);
    });
  });

  // ---------------------------------------------------------- clamping

  group('the row clamps its own text', () {
    testWidgets('a title takes at most two lines, a status exactly one',
        (tester) async {
      await pumpRow(
        tester,
        width: 320,
        scale: 2.0,
        row: SettingsTile(
          icon: Symbols.notifications_rounded,
          title: 'Persistent notifications that keep going',
          subtitle: 'A daily nudge to measure and log a reading',
          onTap: () {},
        ),
      );
      final title = tester.widget<Text>(
          find.text('Persistent notifications that keep going'));
      final sub = tester
          .widget<Text>(find.text('A daily nudge to measure and log a reading'));
      expect(title.maxLines, 2);
      expect(title.overflow, TextOverflow.ellipsis);
      expect(sub.maxLines, 1,
          reason: "Android: \"The subtext should be only one line.\"");
      expect(sub.overflow, TextOverflow.ellipsis);
    });

    testWidgets('a row grows with the text rather than clipping it',
        (tester) async {
      // minHeight, never a fixed height.
      final heights = <double, double>{};
      for (final scale in [1.0, 2.0]) {
        await pumpRow(
          tester,
          width: 320,
          scale: scale,
          row: SettingsTile(
            icon: Symbols.notifications_rounded,
            title: 'Sound',
            subtitle: 'Off',
            onTap: () {},
          ),
        );
        heights[scale] = tester.getSize(find.byType(SettingsTile)).height;
      }
      expect(heights[1.0]!, greaterThanOrEqualTo(AppRowMetrics.minHeight));
      expect(heights[2.0]!, greaterThan(heights[1.0]!));
    });
  });

  // -------------------------------------------------------- one geometry

  group('one geometry for both row widgets', () {
    testWidgets('the two rows start their text at the same x', (tester) async {
      // This is what the divider inset has to match, and what it did not:
      // SettingsSection hardcoded 58 while AppListGroup derived 62.
      await pumpRow(
        tester,
        width: 393,
        row: const SettingsTile(
            icon: Symbols.notifications_rounded, title: 'Alpha'),
      );
      final a = tester.getTopLeft(find.text('Alpha')).dx;

      await pumpRow(
        tester,
        width: 393,
        row: const AppListTile(
            icon: Symbols.notifications_rounded, title: 'Alpha'),
      );
      final b = tester.getTopLeft(find.text('Alpha')).dx;

      expect(a, b, reason: 'the two row widgets disagreed by 4pt');
    });

    testWidgets('a divider between two rows starts where their text does',
        (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(393, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            children: const [
              SettingsSection(children: [
                SettingsTile(icon: Symbols.mic_rounded, title: 'Alpha'),
                SettingsTile(icon: Symbols.mic_rounded, title: 'Beta'),
              ]),
            ],
          ),
        ),
      ));
      await tester.pump();

      final divider = tester.widget<Divider>(find.byType(Divider));
      // Measured against the rendered text, not against the constant.
      final cardLeft = tester.getTopLeft(find.byType(SettingsSection)).dx;
      final textLeft = tester.getTopLeft(find.text('Alpha')).dx;
      expect(divider.indent, textLeft - cardLeft,
          reason: 'the rule must begin under the text it aligns to');
    });
  });

  // ------------------------------------------------------ row anatomy

  group('a row is one affordance', () {
    testWidgets('a row with no tap advertises no chevron', (tester) async {
      await pumpRow(
        tester,
        width: 393,
        row: const AppListTile(
            icon: Symbols.shield_rounded, title: 'What we read'),
      );
      expect(find.byIcon(Symbols.chevron_right_rounded), findsNothing,
          reason: '14 rows advertised a tap they did not answer, twelve of them '
              'on the health disclosure screen');
    });

    testWidgets('a switch row toggles when the ROW is tapped', (tester) async {
      var value = false;
      await pumpRow(
        tester,
        width: 393,
        row: AppListTile(
          icon: Symbols.sync_rounded,
          title: 'Cloud sync',
          switchValue: value,
          onSwitchChanged: (v) => value = v,
        ),
      );
      // Tap the TITLE, not the switch.
      await tester.tap(find.text('Cloud sync'));
      await tester.pump();
      expect(value, isTrue,
          reason: '28 rendered switch rows ignored a row tap while 23 honoured '
              'it, so the documented house rule was the minority behaviour');
    });

    testWidgets('a switch row is one semantics node, not two', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpRow(
        tester,
        width: 393,
        row: AppListTile(
          icon: Symbols.sync_rounded,
          title: 'Cloud sync',
          subtitle: 'On',
          switchValue: true,
          onSwitchChanged: (_) {},
        ),
      );
      // Merged, so the switch is announced WITH what it governs rather than as
      // a bare "switch, on".
      expect(find.byType(MergeSemantics), findsWidgets);
      handle.dispose();
    });
  });
}
