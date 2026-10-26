import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/features/focus/models/focus_plant.dart';
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/relaxation_service.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';

import '../../support/fake_audio_engine.dart';
import '../../support/recording_notification_scheduler.dart';

/// "Delete all data" removed the Focus rows and preferences and left the
/// singletons holding their own copies — which they wrote straight back on the
/// next save. The first focus session after a wipe brought the garden, stats and
/// coins back; and Relaxation, which keeps `relaxation*` keys, was never reached
/// at all.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.loadAppPreferences();
    AudioService().engineForTesting = FakeAudioEngine();
    NotificationService().schedulerForTesting = RecordingNotificationScheduler();
    FocusService().resetForTesting();
    CoinsService().resetForTesting();
    TagService().resetForTesting();
    RelaxationService().resetForTesting();
  });

  tearDown(() async {
    FocusService().resetForTesting();
    RelaxationService().resetForTesting();
    await db.close();
  });

  Future<void> seedFocus() async {
    await CleanStorageService.setAppPreference('focusGarden', [
      FocusPlant(
        id: 'p1',
        type: PlantType.values.first,
        plantedAt: DateTime(2026, 3, 1, 9),
        durationMinutes: 25,
        isAlive: true,
        growthProgress: 1.0,
      ).toJson(),
    ]);
    await FocusService().init();
    await CoinsService().earnCoins(minutes: 25, sessionId: 's1');
  }

  test('the garden and coins are gone, in memory as well as on disk', () async {
    await seedFocus();
    expect(FocusService().garden, hasLength(1), reason: 'premise');
    expect(CoinsService().totalCoins, greaterThan(0), reason: 'premise');

    await CleanStorageService.clearAllPersistentData();

    expect(FocusService().garden, isEmpty);
    expect(CoinsService().totalCoins, 0);
    expect(CoinsService().transactions, isEmpty);
  });

  test('the next save does not bring the deleted history back', () async {
    await seedFocus();
    await CleanStorageService.clearAllPersistentData();

    // Any setting change saves the whole focus state.
    FocusService().setDuration(30);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final garden = CleanStorageService.getAppPreferences()['focusGarden'];
    expect(garden is List ? garden : const [], isEmpty,
        reason: 'the singleton used to write its old garden straight back');
  });

  test('Relaxation history and stats do not survive', () async {
    await CleanStorageService.setAppPreference('relaxationSessions', [
      {'id': 'x'}
    ]);
    await CleanStorageService.setAppPreference('relaxationSelectedMinutes', 40);
    RelaxationService().setDuration(40);
    expect(RelaxationService().selectedMinutes, 40, reason: 'premise');
    await CleanStorageService.clearAllPersistentData();
    expect(CleanStorageService.getAppPreference('relaxationSessions'), isNull);
    expect(CleanStorageService.getAppPreference('relaxationSelectedMinutes'),
        isNull);
    expect(RelaxationService().sessions, isEmpty);
    expect(RelaxationService().selectedMinutes, 15);
  });

  test('a custom tag does not survive; the starter tags do', () async {
    await TagService().init();
    final starter = TagService().tags.length;
    await TagService().createTag(name: 'Thesis', colorValue: 0);
    expect(TagService().customTags, hasLength(1), reason: 'premise');
    await CleanStorageService.clearAllPersistentData();
    expect(TagService().customTags, isEmpty);
    expect(TagService().tags.length, starter);
  });
}
