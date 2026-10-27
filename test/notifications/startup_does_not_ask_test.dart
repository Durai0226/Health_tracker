/// "Skip for now" on the welcome screen meant: ask me later. It used to mean:
/// ask me at every start.
///
/// After the first launch every cold start went on to request the notification
/// permission, then the exact-alarm one (which opens a system settings page on
/// Android 12 and later) and then the full-screen one — until each was granted.
/// A person who had declined once, or skipped, was asked again every time they
/// opened the app. "Returning users already decided" was the comment above it;
/// someone who skipped had not.
///
/// The OS dialogs now belong to the places a person asks for them — the welcome
/// pane, the permission banner, the setup checklist. Start-up only looks.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';

import '../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    NotificationService().schedulerForTesting = RecordingNotificationScheduler();
    NotificationService.permissionRequestsForTesting = 0;
  });

  tearDown(() async => db.close());

  test('the start-up pass looks and does not ask', () async {
    await NotificationService().startupPermissionPass();
    expect(NotificationService.permissionRequestsForTesting, 0);
  });

  test('not for a returning user either', () async {
    await CleanStorageService.setFirstLaunchComplete();
    expect(CleanStorageService.isFirstLaunch, isFalse);
    await NotificationService().backgroundSetupForTesting();
    expect(NotificationService.permissionRequestsForTesting, 0,
        reason: 'a person who skipped has not decided');
  });

  test('and not however many times the app is started', () async {
    await CleanStorageService.setFirstLaunchComplete();
    for (var i = 0; i < 3; i++) {
      await NotificationService().backgroundSetupForTesting();
    }
    expect(NotificationService.permissionRequestsForTesting, 0);
  });

  test('nor on the very first launch', () async {
    expect(CleanStorageService.isFirstLaunch, isTrue);
    await NotificationService().backgroundSetupForTesting();
    expect(NotificationService.permissionRequestsForTesting, 0);
  });

  test('asking is a separate, explicit act: the welcome pane, banner and checklist',
      () async {
    await NotificationService().requestPermissionsIfNeeded();
    expect(NotificationService.permissionRequestsForTesting, 1);
  });
}
