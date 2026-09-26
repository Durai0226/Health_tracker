/// TQ-20 — the settings screens changed in this pass had no toggle-persistence
/// test at all.
///
/// `NotificationSettingsScreen` is instant-apply: there is no Save button, so
/// the ONLY evidence a toggle worked is that the preference comes back changed
/// after the screen is rebuilt. Nothing tested that. Two failure modes were
/// live in this file's history and both are invisible on screen at the moment
/// they happen:
///
///  * the debounced write never lands (a cancelled timer, an early return, a
///    swallowed exception) — the switch moves, the "Saved" check fades in, and
///    the old value is still on disk when the user comes back;
///  * the write lands but is built from a FRESH `UserSettings` instead of
///    `copyWith`, so every field the notifications screen does not list is
///    reset to its default. The comment in `_persist` names the casualty:
///    the user's dark/light choice, wiped by flipping an unrelated switch.
///
/// So each test here flips a switch, lets the 400 ms debounce fire, reads the
/// preference back, AND rebuilds the screen from scratch to prove the value the
/// user sees on their return is the one they chose.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart'
    show AppSwitch, SegmentedToggle, SettingsTile;
import 'package:tablet_remainder/features/settings/screens/notification_settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
  });

  tearDown(() async => db.close());

  /// Mounts the screen and waits out `_loadSettings`' 100 ms warm-up.
  ///
  /// The view is made tall enough for the whole list first. A `ListView` only
  /// builds what is visible, so on a phone-sized view the Snooze and Alarm
  /// sections are not in the tree at all and a finder for them silently
  /// matches nothing — which reads as "the control is missing", not "scroll
  /// down". Setting `tester.view.physicalSize` is what actually resizes the
  /// layout; a MediaQuery override alone would not.
  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      home: NotificationSettingsScreen(),
    ));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
  }

  /// Unmounts the screen, which is also what cancels its pending timers.
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();
  }

  /// The live value of the [AppSwitch] in the row titled [title].
  bool switchValue(WidgetTester tester, String title) {
    final row = find.ancestor(
      of: find.text(title),
      matching: find.byType(SettingsTile),
    );
    expect(row, findsOneWidget, reason: 'no settings row titled "$title"');
    return tester
        .widget<AppSwitch>(
            find.descendant(of: row, matching: find.byType(AppSwitch)))
        .value;
  }

  /// The `SegmentedToggle` under the heading [label].
  Finder picker(WidgetTester tester, String label) => find.descendant(
        of: find
            .ancestor(of: find.text(label), matching: find.byType(Column))
            .first,
        matching: find.byType(SegmentedToggle),
      );

  /// The label of the segment the picker under [label] currently shows as
  /// selected. Read from `SegmentedToggle.index`, which is the only thing that
  /// renders the selection — comparing the STORE to itself after a reopen
  /// would pass even if `_loadSettings` never applied the saved value.
  String selectedSegment(WidgetTester tester, String label) {
    final w = tester.widget<SegmentedToggle>(picker(tester, label));
    return w.items[w.index].label;
  }

  /// Taps the row (the whole row toggles) and lets the 400 ms debounce fire
  /// and its async write complete.
  Future<void> toggle(WidgetTester tester, String title) async {
    await tester.tap(find.text(title));
    await tester.pump();
    // The write is behind a Timer, not a frame — pumpAndSettle alone never
    // reaches it, which is exactly how a lost write would go unnoticed.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  testWidgets('a toggle is written through, and survives a rebuild',
      (tester) async {
    await open(tester);
    expect(switchValue(tester, 'Sound'), isTrue, reason: 'default');
    expect(CleanStorageService.getUserSettings().soundEnabled, isTrue);

    await toggle(tester, 'Sound');

    expect(CleanStorageService.getUserSettings().soundEnabled, isFalse,
        reason: 'the switch moved but nothing was persisted');
    expect(switchValue(tester, 'Sound'), isFalse);

    // Leave and come back — the only thing the user can actually observe.
    await close(tester);
    await open(tester);
    expect(switchValue(tester, 'Sound'), isFalse,
        reason: 'the screen reverted to the default on reopen');
  });

  testWidgets('every switch on the screen persists independently',
      (tester) async {
    // One row at a time, because `_persist` writes ALL of them on every change:
    // a copyWith that drops a field would show up here as a neighbour snapping
    // back to its default.
    const rows = {
      'Sound': true,
      'Vibration': true,
      'Lock screen': true,
      'Keep on screen': true,
      'Full-screen alerts': true,
    };

    await open(tester);
    for (final title in rows.keys) {
      await toggle(tester, title);
    }

    final saved = CleanStorageService.getUserSettings();
    expect(saved.soundEnabled, isFalse);
    expect(saved.vibrationEnabled, isFalse);
    expect(saved.showOnLockScreen, isFalse);
    expect(saved.persistentNotification, isFalse);
    expect(saved.fullScreenNotification, isFalse);

    await close(tester);
    await open(tester);
    for (final title in rows.keys) {
      expect(switchValue(tester, title), isFalse,
          reason: '"$title" came back at its default');
    }
  });

  testWidgets('flipping one switch back on does not drag the others with it',
      (tester) async {
    await open(tester);
    await toggle(tester, 'Sound');
    await toggle(tester, 'Vibration');
    expect(CleanStorageService.getUserSettings().soundEnabled, isFalse);
    expect(CleanStorageService.getUserSettings().vibrationEnabled, isFalse);

    await toggle(tester, 'Sound'); // back on

    final saved = CleanStorageService.getUserSettings();
    expect(saved.soundEnabled, isTrue);
    expect(saved.vibrationEnabled, isFalse,
        reason: 'a rebuilt-from-defaults write would turn vibration back on');
  });

  testWidgets('a setting this screen does not own is not reset by a toggle',
      (tester) async {
    // The regression `_persist`'s comment describes: building a fresh
    // `UserSettings` here instead of `copyWith` silently wiped the user's
    // dark/light choice every time they touched a notification switch.
    await CleanStorageService.saveUserSettings(
      CleanStorageService.getUserSettings()
          .copyWith(darkModeEnabled: true, maxSnoozeCount: 7),
    );
    expect(CleanStorageService.getUserSettings().darkModeEnabled, isTrue,
        reason: 'sanity: the preference we are protecting is actually set');

    await open(tester);
    await toggle(tester, 'Vibration');

    final saved = CleanStorageService.getUserSettings();
    expect(saved.vibrationEnabled, isFalse, reason: 'the toggle still works');
    expect(saved.darkModeEnabled, isTrue,
        reason: 'the theme choice was wiped by an unrelated switch');
    expect(saved.maxSnoozeCount, 7,
        reason: 'the snooze cap was reset by an unrelated switch');
  });

  testWidgets('the snooze duration picker persists and survives a rebuild',
      (tester) async {
    await open(tester);
    expect(CleanStorageService.getUserSettings().snoozeIntervalMinutes, 5,
        reason: 'default');

    // Snooze options are 1, 5, 10, 15, 30 — pick 15.
    const heading = 'Snooze duration (minutes)';
    expect(picker(tester, heading), findsOneWidget);
    expect(selectedSegment(tester, heading), '5', reason: 'default');
    await tester.tap(
        find.descendant(of: picker(tester, heading), matching: find.text('15')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(CleanStorageService.getUserSettings().snoozeIntervalMinutes, 15);

    await close(tester);
    await open(tester);
    expect(CleanStorageService.getUserSettings().snoozeIntervalMinutes, 15,
        reason: 'reopening the screen must not overwrite the saved duration');
    // The half the store cannot answer: the reopened screen must SHOW 15.
    // Without this, a `_loadSettings` that never read the saved duration back
    // would leave the picker on its default and this test would still pass.
    expect(selectedSegment(tester, heading), '15',
        reason: 'the reopened picker fell back to its default');
  });

  testWidgets('a save that throws says so instead of pretending nothing happened',
      (tester) async {
    // The failure this screen could not report. `getUserSettings()` casts
    // every stored value, so one preference of the wrong type — which a
    // restore writes straight through from the backup file — makes every
    // save on this screen throw. The catch logged it and stopped there: the
    // switch stayed where the user put it, "Saved" never appeared, and
    // nothing said the change had been lost.
    await open(tester);
    await CleanStorageService.setAppPreference('snoozeInterval', 'restored');

    await toggle(tester, 'Sound');

    expect(find.text("Couldn't save that change. Try again."), findsOneWidget,
        reason: 'a failed write was indistinguishable from a successful one');
    expect(find.text('Saved'), findsOneWidget,
        reason: 'sanity: the "Saved" affordance is always in the tree, faded');
    expect(
        tester
            .widget<AnimatedOpacity>(find.ancestor(
                of: find.text('Saved'), matching: find.byType(AnimatedOpacity)))
            .opacity,
        0,
        reason: 'a failed save must not also flash the success check');

    // Let the toast time out so no timer outlives the test.
    await tester.pump(const Duration(seconds: 8));
    await close(tester);
  });
}
