/// The Sleep history list: nights past the last five weeks, and a night you can
/// open.
library;

import 'dart:io';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/sleep/models/sleep_stage.dart';
import 'package:tablet_remainder/features/sleep/screens/sleep_history_screen.dart';
import 'package:tablet_remainder/features/sleep/services/sleep_service.dart';

import '../../support/font_free_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;
  final now = DateTime(2026, 6, 20, 12);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    await SleepService.resetForTesting();
  });

  tearDown(() async => database.close());

  String key(int daysAgo) {
    final d = DateTime(now.year, now.month, now.day - daysAgo);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> night(int daysAgo, {SleepSource source = SleepSource.healthConnect, String? note}) async {
    final wake = DateTime(now.year, now.month, now.day - daysAgo, 7);
    await database.sleepDao.upsert(db.SleepSessionsCompanion(
      id: Value('n$daysAgo'),
      dateKey: Value(key(daysAgo)),
      bedtime: Value(wake.subtract(const Duration(minutes: 480))),
      wakeTime: Value(wake),
      inBedMinutes: const Value(480),
      asleepMinutes: const Value(450),
      deepMinutes: const Value(80),
      remMinutes: const Value(95),
      lightMinutes: const Value(275),
      sourceIndex: Value(source.index),
      qualityIndex: Value(source == SleepSource.manual ? 3 : null),
      note: Value(note),
      createdAt: Value(wake),
      updatedAt: Value(wake),
    ));
  }

  Future<void> open(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(430, 4000);
    addTearDown(tester.view.reset);
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      if (!'${d.exception}'.contains('overflowed')) prev?.call(d);
    };
    addTearDown(() => FlutterError.onError = prev);
    await tester.pumpWidget(
        MaterialApp(theme: fontFreeTheme(), home: const SleepHistoryScreen()));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Scroll to it, let the scroll land, then tap: `ensureVisible` moves the
  /// list but the new position only exists after a frame.
  Future<void> tapVisible(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
  }

  Future<void> load(List<int> daysAgo, {Set<int> manual = const {}}) async {
    for (final d in daysAgo) {
      await night(d, source: manual.contains(d) ? SleepSource.manual : SleepSource.healthConnect);
    }
    await SleepService.reloadFromDb();
  }

  testWidgets('a night a health app recorded opens in full, read-only', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await load([1, 2, 3]);
      await open(tester);

      await tester.tap(find.text('Yesterday'));
      await settle(tester);

      expect(find.text('Source'), findsOneWidget);
      expect(find.text('Health Connect'), findsOneWidget);
      expect(find.text('Deep'), findsOneWidget);
      expect(find.textContaining('came from your health app'), findsOneWidget);
      expect(find.text('Save changes'), findsNothing,
          reason: 'a device\'s night is the device\'s to correct');

      await tester.tap(find.text('Close'));
      await settle(tester);
      expect(find.textContaining('came from your health app'), findsNothing);
    });
  });

  testWidgets('a night you logged opens the form on what you logged', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await load([1, 2, 3], manual: {2});
      await open(tester);

      await tester.tap(find.text('Thu, Jun 18'));
      await settle(tester);

      expect(find.text('Edit night'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
      expect(find.text('Save sleep'), findsNothing);
      expect(find.text('8h 00m'), findsOneWidget, reason: 'its time in bed, as logged');
      expect(find.text('Note (optional)'), findsOneWidget);
    });
  });

  testWidgets('saving a change updates the night and offers Undo', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await load([1, 2], manual: {2});
      await open(tester);

      await tester.tap(find.text('Thu, Jun 18'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).last, 'woke twice');
      await tester.pump();
      await tapVisible(tester, find.text('Save changes'));
      await settle(tester);

      expect(find.text('Night updated'), findsOneWidget);
      expect(SleepService.getAllSessions().firstWhere((s) => s.id == 'n2').note, 'woke twice');

      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(SleepService.getAllSessions().firstWhere((s) => s.id == 'n2').note, isNull,
          reason: 'back as it was');
    });
  });

  group('earlier nights', () {
    testWidgets('five weeks are shown, and a button reads further back',
        (tester) async {
      await withClock(Clock.fixed(now), () async {
        await load([for (var i = 0; i < 70; i++) i]);
        await open(tester);

        expect(find.text('Show earlier nights'), findsOneWidget);
        final before = find.byType(Dismissible).evaluate().length;
        expect(before, lessThan(70), reason: 'the premise: not every night is on screen');

        await tapVisible(tester, find.text('Show earlier nights'));
        await settle(tester);

        expect(find.byType(Dismissible).evaluate().length, greaterThan(before));
      });
    });

    testWidgets('and when there are no more, it says so, not a vanished button',
        (tester) async {
      await withClock(Clock.fixed(now), () async {
        await load([for (var i = 0; i < 50; i++) i]);
        await open(tester);
        await tapVisible(tester, find.text('Show earlier nights'));
        await settle(tester);

        expect(find.text('Show earlier nights'), findsNothing);
        expect(find.text('That is every night on record.'), findsOneWidget);
        expect(find.byType(Dismissible).evaluate().length, 50);
      });
    });

    testWidgets('with nothing older, no button and no claim', (tester) async {
      await withClock(Clock.fixed(now), () async {
        await load([for (var i = 0; i < 10; i++) i]);
        await open(tester);
        expect(find.text('Show earlier nights'), findsNothing);
        expect(find.text('That is every night on record.'), findsNothing,
            reason: 'nothing was read further back, so nothing is claimed');
      });
    });

    testWidgets('an older night opens just like a recent one', (tester) async {
      await withClock(Clock.fixed(now), () async {
        await load([for (var i = 0; i < 70; i++) i], manual: {55});
        await open(tester);
        await tapVisible(tester, find.text('Show earlier nights'));
        await settle(tester);

        await tapVisible(tester, find.text('Sun, Apr 26'));
        await settle(tester);
        expect(find.text('Edit night'), findsOneWidget);
      });
    });
  });

  test('a refused edit is said, not swallowed', () {
    // The refusals themselves (a date that already has a night, a night from a
    // health app) are pinned in sleep_history_service_test; this is the line that
    // shows them. Driving the date picker through a sheet is not worth what it
    // would add.
    final src = File('lib/features/sleep/screens/sleep_history_screen.dart')
        .readAsStringSync();
    final at = src.indexOf('final edit = r.edit;');
    expect(at, greaterThan(0));
    expect(src.substring(at, at + 300), contains('context.toastError(r.problem'));
  });
}
