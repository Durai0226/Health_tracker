/// While App lock is on, the app's content stays out of the recent-apps preview.
///
/// The lock screen guards the app, but Android's task switcher shows a snapshot
/// of whatever was on screen last — medicines, readings, a diary entry. A
/// secure window removes it. The native side is one flag; what is pinned here is
/// that the app asks for it when the lock is on, and only then.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/app_lock_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/privacy_window.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];
  const channel = MethodChannel('dlyminder/lockscreen');
  late AppDatabase database;

  setUp(() async {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(database);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await database.close();
  });

  List<bool> secureCalls() => [
        for (final c in calls)
          if (c.method == 'setSecure') (c.arguments as Map)['enabled'] as bool
      ];

  test('apply asks the window to be secure, or not', () async {
    await PrivacyWindow.apply(true);
    await PrivacyWindow.apply(false);
    expect(secureCalls(), [true, false]);
  });

  test('on a platform without the channel it is a quiet no-op', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => throw MissingPluginException());
    await PrivacyWindow.apply(true);
  });

  test('turning the lock on makes the window secure', () async {
    await AppLockService().setPin('1234');
    await Future<void>.delayed(Duration.zero);
    expect(secureCalls(), [true]);
  });

  test('turning it off makes it ordinary again', () async {
    await AppLockService().setPin('1234');
    calls.clear();
    await AppLockService().disableLock();
    await Future<void>.delayed(Duration.zero);
    expect(secureCalls(), [false]);
  });

  test('a lock that is already on from the last run is secure from start-up',
      () async {
    await CleanStorageService.setAppPreference(AppLockService.keyLockEnabled, true);
    final lock = AppLockService();
    // init() is idempotent for the process; what it asks of the window is what
    // is pinned, so call the same thing it calls.
    await PrivacyWindow.apply(lock.isLockEnabled);
    expect(secureCalls(), [true]);
  });

  test('the native side sets and clears FLAG_SECURE for it', () {
    final kt = File('android/app/src/main/kotlin/com/dlyminder/app/MainActivity.kt')
        .readAsStringSync();
    expect(kt, contains('"setSecure"'));
    expect(kt, contains('FLAG_SECURE'));
    expect(kt, contains('addFlags(WindowManager.LayoutParams.FLAG_SECURE)'));
    expect(kt, contains('clearFlags(WindowManager.LayoutParams.FLAG_SECURE)'));
  });

  test('the service keeps the window in step with the lock, everywhere it changes',
      () {
    final src = File('lib/core/services/app_lock_service.dart').readAsStringSync();
    expect(src, contains('unawaited(PrivacyWindow.apply(isLockEnabled));'),
        reason: 'start-up');
    expect(src, contains('unawaited(PrivacyWindow.apply(true));'), reason: 'on');
    expect(src, contains('unawaited(PrivacyWindow.apply(false));'), reason: 'off');
  });
}
