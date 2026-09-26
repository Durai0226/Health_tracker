/// SS-15 — the sleep feature's two icon-only controls announce, and are big
/// enough to hit.
///
/// The quality stars in the manual-log sheet were five bare `GestureDetector`s
/// with no `Semantics` anywhere in the file: a screen reader reached five
/// unlabelled taps and could not read back the rating at all. Worse, the two
/// arms of the filled/empty ternary were the SAME constant, so a filled star
/// differed from an empty one by colour alone.
///
/// The schedule screen's −/+ steppers were `AppIconButton(size: 36)` with no
/// `tooltip:` — eight points under the 44pt floor, and `AppIconButton` only
/// wraps itself in a `Tooltip` when one is passed, so they reached the
/// semantics tree nameless. The design guard's `\bIconButton\(` regex
/// deliberately does not match `AppIconButton(`, so nothing caught either.
///
/// Measured against the LIVE semantics tree and the RENDERED geometry, not the
/// source: a `Semantics` wrapper that never reaches the node carrying the tap
/// action, or a 44pt box in the widget tree that lays out at 36, passes a grep
/// and fails here. Same instrument as
/// `test/reminders/add_reminder_day_toggles_a11y_test.dart`.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/sleep/models/sleep_schedule.dart';
import 'package:tablet_remainder/features/sleep/screens/sleep_schedule_settings_screen.dart';
import 'package:tablet_remainder/features/sleep/widgets/sleep_manual_log_sheet.dart';

/// Apple HIG 2.5.5 — the floor `test/responsive/touch_target_audit_test` holds
/// the rest of the app to.
const double _appleMin = 44.0;

/// A plain weekday morning, no DST boundary near it, so the sheet's default
/// night validates and the form renders rather than sitting on an error.
final _now = DateTime(2026, 3, 10, 9, 30);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late db.AppDatabase database;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
  });

  tearDown(() async => database.close());

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

  /// The nodes a screen reader can actually activate. A label parked on a node
  /// with no tap action is a caption, and the control beside it still
  /// announces as nothing.
  Iterable<SemanticsNode> tappable(WidgetTester tester) => nodes(tester).where(
      (n) => (n.getSemanticsData().actions & SemanticsAction.tap.index) != 0);

  List<String> tappableLabels(WidgetTester tester) =>
      [for (final n in tappable(tester)) n.label];

  // ───────────────────────────── the stars ─────────────────────────────

  group('the manual-log quality stars', () {
    Future<void> openSheet(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(430, 1600);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => SleepManualLogSheet.show(
                  context,
                  schedule: const SleepSchedule(),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    /// The five star icons, in order. Resolved through the rendered tree so a
    /// count that is not five fails loudly rather than measuring three.
    List<Element> starBoxes(WidgetTester tester) {
      final found = find
          .ancestor(
            of: find.byIcon(Symbols.star_rounded),
            matching: find.byType(GestureDetector),
          )
          .evaluate()
          .toList();
      expect(found, hasLength(5),
          reason: 'expected five stars, found ${found.length}');
      return found;
    }

    testWidgets('each star says which rating it sets', (tester) async {
      final handle = tester.ensureSemantics();
      await withClock(Clock.fixed(_now), () async {
        await openSheet(tester);

        final labels = tappableLabels(tester);
        for (var i = 1; i <= 5; i++) {
          expect(labels, contains('Rate $i of 5'),
              reason: 'star $i announces as "". A five-star rating where every '
                  'star is nameless cannot be read back. Tappable labels: '
                  '$labels');
        }
      });
      handle.dispose();
    });

    testWidgets('and the current rating is readable from their state',
        (tester) async {
      // The sheet opens at 4 of 5. Without a selected flag a screen-reader
      // user hears five identical buttons and cannot tell what is set.
      final handle = tester.ensureSemantics();
      await withClock(Clock.fixed(_now), () async {
        await openSheet(tester);

        Set<String> selected() => {
              for (final n in tappable(tester))
                if (n.hasFlag(SemanticsFlag.isSelected) && n.label.isNotEmpty)
                  n.label,
            };

        expect(
            selected(),
            <String>{
              'Rate 1 of 5',
              'Rate 2 of 5',
              'Rate 3 of 5',
              'Rate 4 of 5',
            },
            reason: 'four stars are lit at the default rating of 4');

        // And it moves when the rating does.
        await tester.tap(find.bySemanticsLabel('Rate 2 of 5'));
        await tester.pump();
        expect(selected(), <String>{'Rate 1 of 5', 'Rate 2 of 5'});
      });
      handle.dispose();
    });

    testWidgets('each star clears the 44pt minimum', (tester) async {
      await withClock(Clock.fixed(_now), () async {
        await openSheet(tester);

        final undersized = <String>[];
        for (final e in starBoxes(tester)) {
          final s = (e.renderObject! as RenderBox).size;
          if (s.width < _appleMin || s.height < _appleMin) {
            undersized.add('${s.width.toStringAsFixed(0)}x'
                '${s.height.toStringAsFixed(0)}');
          }
        }
        expect(undersized, isEmpty, reason: 'stars below 44pt: $undersized');
      });
    });

    testWidgets('a lit star differs from an unlit one by more than colour',
        (tester) async {
      // The filled/empty ternary named the same constant on both arms, so the
      // ONLY difference was `ext.mark(accent)` vs `ext.outlineStrong`.
      await withClock(Clock.fixed(_now), () async {
        await openSheet(tester);

        final fills = tester
            .widgetList<Icon>(find.byIcon(Symbols.star_rounded))
            .map((i) => i.fill)
            .toList();
        expect(fills, hasLength(5));
        expect(fills.sublist(0, 4), everyElement(1.0),
            reason: 'the four lit stars must be FILLED, not just tinted: '
                '$fills');
        expect(fills[4], 0.0,
            reason: 'the unlit star must be an outline: $fills');
      });
    });
  });

  // ──────────────────────────── the steppers ────────────────────────────

  group('the schedule screen steppers', () {
    Future<void> pumpScreen(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(430, 1600);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(
        home: SleepScheduleSettingsScreen(),
      ));
      await tester.pump(const Duration(milliseconds: 300));
    }

    /// The −/+ buttons, resolved to the `SizedBox` inside `AppIconButton` that
    /// actually sets the hit area.
    List<Element> stepperBoxes(WidgetTester tester) {
      final found = <Element>[];
      for (final icon in const [Symbols.remove_rounded, Symbols.add_rounded]) {
        found.addAll(find
            .ancestor(
              of: find.byIcon(icon),
              matching: find.byType(InkWell),
            )
            .evaluate());
      }
      expect(found, hasLength(4),
          reason: 'expected two rows of −/+, found ${found.length}');
      return found;
    }

    testWidgets('each one says which setting it moves, and which way',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester);

      // `AppIconButton` puts the text on the node as a TOOLTIP, which is what
      // TalkBack and VoiceOver read for an icon-only control — the same route
      // `AppStepper` uses. Asserted on the node that carries the tap action:
      // a name on a node with no action is a caption.
      final named = {
        for (final n in tappable(tester))
          if (n.tooltip.isNotEmpty) n.tooltip,
      };
      for (final expected in const [
        'Decrease sleep target',
        'Increase sleep target',
        'Decrease wind-down',
        'Increase wind-down',
      ]) {
        expect(named, contains(expected),
            reason: 'a −/+ button announces as "". Named tappables: $named');
      }

      handle.dispose();
    });

    testWidgets('each one clears the 44pt minimum', (tester) async {
      await pumpScreen(tester);

      final undersized = <String>[];
      for (final e in stepperBoxes(tester)) {
        final s = (e.renderObject! as RenderBox).size;
        if (s.width < _appleMin || s.height < _appleMin) {
          undersized.add('${s.width.toStringAsFixed(0)}x'
              '${s.height.toStringAsFixed(0)}');
        }
      }
      expect(undersized, isEmpty,
          reason: 'steppers below 44pt: $undersized');
    });
  });
}
