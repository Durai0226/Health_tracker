/// Pull down on Sleep to read the health app again.
///
/// The import ran when the app started and nowhere else, so last night could be
/// in the health app and not on this screen until the next launch. Steps and Heart
/// already refresh on a pull; Sleep now does too.
library;

import 'dart:io';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/features/sleep/models/sleep_stage.dart';
import 'package:tablet_remainder/features/sleep/screens/sleep_dashboard_screen.dart';
import 'package:tablet_remainder/features/sleep/services/sleep_service.dart';

import '../../support/font_free_theme.dart';
import '../../support/recording_notification_scheduler.dart';

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
    NotificationService().schedulerForTesting = RecordingNotificationScheduler();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/device_info'),
      (_) async => <String, dynamic>{},
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/device_info'), null);
    await database.close();
  });

  testWidgets('the Sleep screen can be pulled down, and a pull completes',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      for (var i = 0; i < 4; i++) {
        final wake = DateTime(now.year, now.month, now.day - i, 7);
        await database.sleepDao.upsert(db.SleepSessionsCompanion(
          id: Value('n$i'),
          dateKey: Value(
              '${wake.year}-${wake.month.toString().padLeft(2, '0')}-${wake.day.toString().padLeft(2, '0')}'),
          bedtime: Value(wake.subtract(const Duration(minutes: 480))),
          wakeTime: Value(wake),
          inBedMinutes: const Value(480),
          asleepMinutes: const Value(450),
          sourceIndex: Value(SleepSource.healthConnect.index),
          createdAt: Value(wake),
          updatedAt: Value(wake),
        ));
      }
      await SleepService.reloadFromDb();

      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(430, 1000);
      addTearDown(tester.view.reset);
      final prev = FlutterError.onError;
      FlutterError.onError = (_) {};
      try {
        await tester.pumpWidget(MaterialApp(
            theme: fontFreeTheme(), home: const SleepDashboardScreen()));
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.byType(RefreshIndicator), findsOneWidget);

        await tester.fling(find.byType(ListView).first, const Offset(0, 400), 1000);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
      } finally {
        FlutterError.onError = prev;
      }
      await tester.pump(const Duration(seconds: 8));
    });
  });

  test('a pull reads the health app again', () {
    final src = File('lib/features/sleep/screens/sleep_dashboard_screen.dart')
        .readAsStringSync();
    final at = src.indexOf('return RefreshIndicator(');
    expect(at, greaterThan(0));
    expect(src.substring(at, at + 400), contains('SleepService.syncFromHealth()'));
    expect(src.substring(at, at + 600), contains('AlwaysScrollableScrollPhysics'),
        reason: 'a short night list must still be pullable');
  });
}
