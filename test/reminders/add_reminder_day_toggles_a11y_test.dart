/// The Add Reminder form's day-of-week toggles, and its two icon-only ✕s, are
/// reachable and namable.
///
/// They are the control that decides which days a reminder fires on, and they
/// were a bare 40x40 `GestureDetector` — four points under the 44pt floor, with
/// no `Semantics` anywhere in the file. A screen reader reached seven
/// unlabelled buttons and could not tell which days were already on; two of the
/// visible letters ('T', 'S') name two different days each, so even reading the
/// letter out would not have disambiguated them.
///
/// Measured against the RENDERED geometry and the LIVE semantics tree, not the
/// source: a `Semantics` wrapper that fails to reach the node carrying the tap
/// action, or a hit box that is 44pt in the widget tree and 40pt on screen,
/// passes a grep and fails here.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';
import 'package:tablet_remainder/features/reminders/screens/add_reminder_screen.dart';

/// Apple HIG 2.5.5 — the same floor `test/responsive/touch_target_audit_test`
/// gates the rest of the app against.
const double _appleMin = 44.0;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUp(() => SharedPreferences.setMockInitialValues({}));

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
      (n) =>
          (n.getSemanticsData().actions & SemanticsAction.tap.index) != 0);

  /// The custom-repeat form, on a mainstream phone.
  ///
  /// `initialRepeat: custom` is what makes the day row render at all — the
  /// dropdown defaults to "Does not repeat" and the toggles are behind an
  /// `if (_repeatType == RepeatType.custom)`. A test that pumped the default
  /// screen would assert on seven widgets that were never built.
  Future<void> pumpForm(WidgetTester tester, {List<int>? days}) async {
    // Layout follows the view, not MediaQuery: a width-dependent row measured
    // against a MediaQuery that the render tree never saw cannot fail.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    // The Date/Time rows above the day picker overflow by 52pt at 390 — a
    // pre-existing finding that `test/responsive/responsive_overflow_test`
    // owns and prices. Left unsuppressed it fails every test in this file for
    // a defect none of them is about; `touch_target_audit_test` silences it
    // the same way and for the same reason.
    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: AddReminderScreen(
        initialTitle: 'Stretch',
        initialRepeat: RepeatType.custom,
        initialCustomDays: days ?? const [1, 3],
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    FlutterError.onError = prev;
  }

  /// The seven day toggles in week order, each identified by the letter it
  /// paints and resolved to the NEAREST `GestureDetector` above that letter —
  /// which is the widget whose render box is the actual hit area.
  ///
  /// `find.ancestor` returns every matching ancestor, and the form sits inside
  /// a second `GestureDetector` of its own, so matching by type alone finds
  /// fourteen and measures the wrong seven.
  List<Element> dayToggles(WidgetTester tester) {
    final letters = find.byWidgetPredicate((w) =>
        w is Text &&
        w.data != null &&
        w.data!.length == 1 &&
        const {'M', 'T', 'W', 'F', 'S'}.contains(w.data));
    final out = [
      for (final letter in letters.evaluate())
        find
            .ancestor(
              of: find.byElementPredicate((e) => e == letter),
              matching: find.byType(GestureDetector),
            )
            .evaluate()
            .first,
    ];
    // Asserted here rather than in one test, so no caller can measure four
    // toggles and report a clean result. Seven is the whole week; anything
    // else means the row did not render or the letters match something else on
    // the screen.
    expect(out, hasLength(7),
        reason: 'expected seven day toggles, found ${out.length}');
    return out;
  }

  testWidgets('every day toggle clears the 44pt minimum', (tester) async {
    await pumpForm(tester);

    final found = dayToggles(tester);
    final undersized = <String>[];
    for (final e in found) {
      final box = e.renderObject! as RenderBox;
      final s = box.size;
      if (s.width < _appleMin || s.height < _appleMin) {
        undersized.add('${s.width.toStringAsFixed(0)}x'
            '${s.height.toStringAsFixed(0)}');
      }
    }
    expect(undersized, isEmpty,
        reason: 'day toggles below 44pt: $undersized');
  });

  testWidgets('all seven still fit one row inside the gutters',
      (tester) async {
    // The fix must not be "make them 44 and let the week wrap onto two lines":
    // a day picker split across rows reads as two groups.
    await pumpForm(tester);

    final tops = dayToggles(tester)
        .map((e) => (e.renderObject! as RenderBox)
            .localToGlobal(Offset.zero)
            .dy)
        .toSet();
    expect(tops, hasLength(1),
        reason: 'the seven toggles sit on ${tops.length} rows: $tops');
  });

  testWidgets('each one announces the day it actually toggles', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpForm(tester);

    final labels = tappable(tester).map((n) => n.label).toSet();
    for (final day in const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ]) {
      expect(labels, contains(day),
          reason: 'no activatable node announces "$day". A day picker whose '
              'buttons are called "T" names Tuesday and Thursday the same. '
              'Tappable labels: $labels');
    }

    handle.dispose();
  });

  testWidgets('and says whether that day is already on', (tester) async {
    // A name with no state is half an announcement: seven identical "button"s
    // leave a screen-reader user unable to read back the schedule they just
    // set.
    final handle = tester.ensureSemantics();
    await pumpForm(tester, days: const [1, 3]);

    final selected = <String>{};
    final unselected = <String>{};
    for (final n in tappable(tester)) {
      if (n.label.isEmpty) continue;
      (n.hasFlag(SemanticsFlag.isSelected) ? selected : unselected)
          .add(n.label);
    }

    expect(selected, containsAll(<String>['Monday', 'Wednesday']),
        reason: 'selected days did not announce as selected: $selected');
    expect(unselected, containsAll(<String>['Tuesday', 'Sunday']),
        reason: 'unselected days announced as selected: $selected');

    handle.dispose();
  });

  testWidgets('tapping one still toggles it, through the bigger hit box',
      (tester) async {
    // The 2pt ring added around the circle is padding with nothing painted in
    // it. Without `HitTestBehavior.opaque` it swallows nothing and the target
    // is 40pt again — which the geometry assertion above cannot see.
    final handle = tester.ensureSemantics();
    await pumpForm(tester, days: const [1]);

    // The extreme corner of the hit box, not its centre: the centre was always
    // inside the old 40pt circle.
    final tuesday = dayToggles(tester)[1].renderObject! as RenderBox;
    final origin = tuesday.localToGlobal(Offset.zero);
    await tester.tapAt(origin + const Offset(1, 1));
    await tester.pump();

    final nowSelected = {
      for (final n in tappable(tester))
        if (n.hasFlag(SemanticsFlag.isSelected)) n.label,
    };
    expect(nowSelected, contains('Tuesday'),
        reason: 'a tap 1pt inside the target did not reach the toggle — '
            'selected: $nowSelected');

    handle.dispose();
  });

  /// The edit form with a photo attached, which is the only way the remove-✕
  /// renders (`_selectedImagePath` is seeded from `reminder.imagePath` and is
  /// otherwise only set by the gallery picker, a platform channel no widget
  /// test can drive).
  ///
  /// A real file on disk, because `Image.file` on a missing path raises
  /// through `FlutterError.onError` — which this file restores after the pump.
  Future<void> pumpFormWithPhoto(WidgetTester tester) async {
    // Every file call here is the *Sync* variant: `testWidgets` runs inside a
    // fake-async zone, so an `await`ed real disk read never completes and the
    // test hangs instead of failing.
    final dir = Directory.systemTemp.createTempSync('reminder_photo');
    addTearDown(() => dir.deleteSync(recursive: true));
    final png = File('${dir.path}/shot.png')
      ..writeAsBytesSync(base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8'
          'BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='));

    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: AddReminderScreen(
        reminder: Reminder(
          id: 'r1',
          title: 'Stretch',
          body: '',
          scheduledTime: DateTime(2026, 9, 26, 18),
          imagePath: png.path,
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    FlutterError.onError = prev;
  }

  testWidgets('the remove-photo button is named AND still activatable',
      (tester) async {
    // Both halves in one test on purpose. Naming an icon-only control by
    // wrapping it in `Semantics(…, excludeSemantics: true)` DROPS the
    // InkWell's own node, tap action included: the result reads out as
    // "Remove photo, button" and does nothing when a screen reader activates
    // it. `design_tokens_guard_test`'s rule for this — a source scan for a
    // label near an icon-only InkWell — passes on exactly that. So the
    // assertion here is the action, not the annotation.
    final handle = tester.ensureSemantics();
    await pumpFormWithPhoto(tester);

    expect(find.byType(Image), findsOneWidget,
        reason: 'the photo (and therefore the remove ✕) did not render');

    final named = tappable(tester).where((n) => n.label == 'Remove photo');
    expect(named, hasLength(1),
        reason: 'no ACTIVATABLE node announces "Remove photo" — a label on a '
            'node with no tap action is a caption. Tappable labels: '
            '${tappable(tester).map((n) => n.label).toSet()}');

    // Drive it the way a screen reader does — through the semantics action,
    // not a synthetic touch — since that is the path `excludeSemantics` breaks.
    // ignore: deprecated_member_use
    tester.binding.pipelineOwner.semanticsOwner!
        .performAction(named.single.id, SemanticsAction.tap);
    await tester.pump();

    expect(find.byType(Image), findsNothing,
        reason: 'activating "Remove photo" did not remove the photo');

    handle.dispose();
  });

  testWidgets('the header close button is named', (tester) async {
    // Icon-only, and the control that discards a half-filled form.
    final handle = tester.ensureSemantics();
    await pumpForm(tester);

    // `IconButton(tooltip:)` puts the name in the node's `tooltip`, not its
    // label — that is what a screen reader reads out for a control whose only
    // child is an icon, and it is the remedy `design_tokens_guard_test`'s
    // 'IconButton without tooltip' rule names.
    expect(tappable(tester).map((n) => n.tooltip), contains('Close'));

    handle.dispose();
  });
}
