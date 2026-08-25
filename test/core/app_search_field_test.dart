/// One search field, and the drift it retires.
///
/// Three screens had three different ideas of what a search box is. The worst
/// of them — the Condition Library — had no way to clear a query at all and
/// offered a newline key where a search key belongs. These tests pin the
/// behaviour of the shared widget and, at the end, guard against a fourth
/// screen hand-rolling a fresh one.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';

import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late TextEditingController controller;
  late List<String> emitted;

  setUp(() {
    controller = TextEditingController();
    emitted = <String>[];
  });

  tearDown(() => controller.dispose());

  Future<void> pump(WidgetTester tester,
      {Duration? debounce, VoidCallback? onCleared}) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: AppSearchField(
            controller: controller,
            hint: 'Search conditions',
            debounce: debounce,
            onCleared: onCleared,
            onChanged: emitted.add,
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  group('the clear control', () {
    testWidgets('is absent while the field is empty', (tester) async {
      await pump(tester);
      expect(find.byTooltip('Clear search'), findsNothing);
    });

    testWidgets('appears once there is text, and empties the field',
        (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), 'hyper');
      await tester.pump();

      expect(find.byTooltip('Clear search'), findsOneWidget);

      await tester.tap(find.byTooltip('Clear search'));
      await tester.pump();

      expect(controller.text, isEmpty);
      expect(emitted.last, '',
          reason: 'the screen must be told the query is gone, or the filtered '
              'list stays filtered against a now-empty box');
      expect(find.byTooltip('Clear search'), findsNothing);
    });

    testWidgets('carries a name, not just a glyph', (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), 'x');
      await tester.pump();

      // Two of the three original call sites shipped an icon-only IconButton
      // with no tooltip and no semantic label, which announces as "button".
      final button = tester.widget<IconButton>(find.byType(IconButton));
      expect(button.tooltip, 'Clear search');
    });

    testWidgets('appears for a programmatic edit too', (tester) async {
      await pump(tester);
      // No keystroke here: a parent assigning the text, or an IME committing an
      // autocorrection, must still surface the control. Without the controller
      // listener this renders an un-clearable field.
      controller.text = 'restored query';
      await tester.pump();
      expect(find.byTooltip('Clear search'), findsOneWidget);
    });

    testWidgets('fires onCleared as well as onChanged', (tester) async {
      var cleared = 0;
      await pump(tester, onCleared: () => cleared++);
      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pump();
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pump();
      expect(cleared, 1);
    });
  });

  group('the keyboard', () {
    testWidgets('offers a search action, not a newline', (tester) async {
      await pump(tester);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.textInputAction, TextInputAction.search);
    });
  });

  group('debounce', () {
    testWidgets('is off by default — every keystroke is emitted',
        (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), 'a');
      await tester.enterText(find.byType(TextField), 'ab');
      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pump();
      // Adding latency to the two screens that filter an in-memory list would
      // be a behaviour change smuggled in under a refactor.
      expect(emitted, ['a', 'ab', 'abc']);
    });

    testWidgets('when set, emits once on the trailing edge', (tester) async {
      await pump(tester, debounce: const Duration(milliseconds: 200));
      await tester.enterText(find.byType(TextField), 'a');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.enterText(find.byType(TextField), 'ab');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.enterText(find.byType(TextField), 'abc');

      expect(emitted, isEmpty, reason: 'nothing should have fired yet');

      await tester.pump(const Duration(milliseconds: 250));
      expect(emitted, ['abc']);
    });

    testWidgets('clearing beats an in-flight debounce', (tester) async {
      await pump(tester, debounce: const Duration(milliseconds: 200));
      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.byTooltip('Clear search'));
      await tester.pump();
      expect(emitted, [''],
          reason: 'an emptied box must take effect at once');

      // And the cancelled timer must not fire 'abc' afterwards, re-filtering a
      // list the user just cleared.
      await tester.pump(const Duration(milliseconds: 400));
      expect(emitted, ['']);
    });
  });

  // -------------------------------------------------------------------- guard

  test('no screen hand-rolls a search box any more', () {
    // Source-grep in the repo's established idiom (see
    // no_generative_ai_guard_test.dart). The drift this widget retires happened
    // precisely because each new screen copied a text field and configured
    // search onto it, and nothing made the divergence visible.
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('app_search_field.dart')) continue;
      final src = f.readAsStringSync();
      if (src.contains('prefixIcon: Symbols.search_rounded')) {
        offenders.add(f.path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'use AppSearchField — it carries the clear control, its '
            'accessible name, and the search keyboard action. Found: '
            '$offenders');
  });
}
