/// The accent has to survive a sheet.
///
/// `showModalBottomSheet` and `showDialog` mount their content on a NEW route —
/// a child of the Navigator, not of the caller — so inherited widgets from the
/// calling subtree do not reach them. Flutter bridges that gap with
/// `InheritedTheme.capture` (`bottom_sheet.dart:1320`, `dialog.dart:1640`),
/// which captures `InheritedTheme` subclasses and nothing else.
///
/// `AccentScope` was a plain `InheritedWidget`, so every sheet and dialog in
/// the app silently lost the accent and `featureOf` fell back to
/// `FeatureAccent.brand`. The visible form: the period "Days before" sheet drew
/// five teal radio rows directly under its own pink header, because the header
/// icon was passed `accent:` by hand and the rows were not.
///
/// Call sites had been working around this one at a time. This is the fix at
/// the source, so the next sheet nobody remembers to thread an accent through
/// is still the right colour.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tablet_remainder/core/design/app_design.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_bottom_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  /// Mount a button under [feature] that opens [open] when tapped, and return
  /// whatever accent the opened route resolved.
  Future<FeatureAccent?> accentInsideRoute(
    WidgetTester tester, {
    required FeatureAccent feature,
    required Future<void> Function(BuildContext context, void Function(FeatureAccent) report) open,
  }) async {
    FeatureAccent? seen;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: AccentScope(
        feature: feature,
        child: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => open(context, (f) => seen = f),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return seen;
  }

  testWidgets('a bottom sheet keeps the accent of the screen that opened it',
      (tester) async {
    final seen = await accentInsideRoute(
      tester,
      feature: FeatureAccent.period,
      open: (context, report) => AppBottomSheet.show<void>(
        context,
        title: 'Days before',
        // Deliberately NO accent: — the point is that the sheet inherits it.
        builder: (sheetContext) {
          report(AccentScope.featureOf(sheetContext));
          return const SizedBox(height: 40);
        },
      ),
    );

    expect(seen, isNotNull,
        reason: 'premise: the sheet actually built. Without this the '
            'assertion below cannot fail for the right reason.');
    expect(seen, FeatureAccent.period,
        reason: 'the sheet resolved its accent from nothing, so every row in '
            'it that does not pass `accent:` by hand renders brand teal under '
            'a header the caller coloured correctly');
  });

  testWidgets('a raw showModalBottomSheet keeps it too — it is the capture, '
      'not a wrapper AppBottomSheet adds', (tester) async {
    final seen = await accentInsideRoute(
      tester,
      feature: FeatureAccent.water,
      open: (context, report) => showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) {
          report(AccentScope.featureOf(sheetContext));
          return const SizedBox(height: 40);
        },
      ),
    );
    expect(seen, FeatureAccent.water,
        reason: 'if only AppBottomSheet worked, every hand-rolled sheet in the '
            'app would still be wrong');
  });

  testWidgets('a dialog keeps it as well', (tester) async {
    final seen = await accentInsideRoute(
      tester,
      feature: FeatureAccent.sleep,
      open: (context, report) => showDialog<void>(
        context: context,
        builder: (dialogContext) {
          report(AccentScope.featureOf(dialogContext));
          return const SizedBox(height: 40);
        },
      ),
    );
    expect(seen, FeatureAccent.sleep);
  });

  testWidgets('with no scope at all it still reports brand', (tester) async {
    // The control. If `featureOf` returned something other than brand for an
    // unscoped tree, every assertion above would pass for the wrong reason.
    FeatureAccent? seen;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              builder: (c) {
                seen = AccentScope.featureOf(c);
                return const SizedBox(height: 40);
              },
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(seen, FeatureAccent.brand,
        reason: 'the fallback must still be brand — that is the behaviour the '
            'tests above detect the ABSENCE of');
  });
}
