import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';

/// Health data must not leave the device without explicit consent.
///
/// Background: `AuthService.init()` silently creates an ANONYMOUS Firebase
/// account on first launch. `main.dart` used to trigger `CloudSyncService`
/// gated only on `currentUser?.id != null` — which an anonymous account
/// satisfies — so medicines, water and 60 days of steps/sleep were uploaded
/// for every user, including people who chose "Continue as guest", while
/// onboarding promised "Private · on-device · no account".
///
/// These tests pin the consent flag itself. The gate in `main.dart` is
/// `auth.isAuthenticated && CleanStorageService.cloudSyncEnabled`, and the
/// upload branch of Google sign-in carries the same `cloudSyncEnabled` check.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  // CleanStorageService is a static singleton that persists app preferences
  // through Drift, so the DB must outlive individual tests. Closing it in
  // tearDown made every later write fail silently ("Can't re-open a database
  // after closing it") — the assertions would then have been reading a stale
  // in-memory value and passing for the wrong reason.
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    await CleanStorageService.init();
  });

  tearDownAll(() async => db.close());

  // Start every test from the shipped default rather than the previous test's
  // leftovers.
  setUp(() async => CleanStorageService.setCloudSyncEnabled(false));

  test('cloud sync is OFF for a brand-new install', () {
    // Read the raw preference with the same default the getter ships with:
    // an absent key must mean "off", not "unset therefore on".
    expect(
      CleanStorageService.getAppPreference('cloudSyncEnabled', false),
      isFalse,
    );
    expect(
      CleanStorageService.cloudSyncEnabled,
      isFalse,
      reason: 'A fresh install must not upload health data. Default-on would '
          'contradict the on-device promise shown during onboarding.',
    );
  });

  test('consent persists once granted', () async {
    await CleanStorageService.setCloudSyncEnabled(true);
    expect(CleanStorageService.cloudSyncEnabled, isTrue);
  });

  test('consent can be withdrawn', () async {
    await CleanStorageService.setCloudSyncEnabled(true);
    await CleanStorageService.setCloudSyncEnabled(false);
    expect(
      CleanStorageService.cloudSyncEnabled,
      isFalse,
      reason: 'Turning sync off must actually stop future uploads.',
    );
  });

  test('an unrelated preference write does not silently enable sync', () async {
    await CleanStorageService.setAppPreference('someOtherFlag', true);
    expect(CleanStorageService.cloudSyncEnabled, isFalse);
  });
}
