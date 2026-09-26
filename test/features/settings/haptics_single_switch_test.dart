/// Settings offered TWO entries for one concept, each with its own master
/// switch, backed by different services — so turning "Haptic Feedback" off left
/// the "Haptix" pattern library buzzing, and a user who wanted silence had to
/// find and flip both. `docs/ux-review.md` logged it as needing a product
/// decision; the decision was to merge.
///
/// What merged: the duplicate entry and the duplicate master switch. What did
/// NOT merge: the pattern library itself (heartbeat, rain, meditation bell),
/// which Focus and Relaxation genuinely use and `HapticService` has no
/// equivalent for.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/services/haptic_service.dart';
import 'package:tablet_remainder/core/services/vitavibe_service.dart';
import 'package:drift/native.dart';
import 'package:tablet_remainder/core/database/app_database.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // Both services persist through Drift, so they need a database — without
    // one `_saveSettings` reaches path_provider and throws.
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
  });

  tearDown(() async => db.close());

  group('one master switch', () {
    test('negative: silencing haptics silences the pattern library too',
        () async {
      await HapticService().setEnabled(true);
      await VitaVibeService().setEnabled(true);
      expect(VitaVibeService().isEnabled, isTrue, reason: 'sanity');

      await HapticService().setEnabled(false);

      expect(VitaVibeService().isEnabled, isFalse,
          reason: 'this is the whole defect: "off" has to mean off, not "off '
              'unless you also find the second switch"');
    });

    test('positive: re-enabling haptics brings the patterns back', () async {
      await HapticService().setEnabled(false);
      await VitaVibeService().setEnabled(true);
      expect(VitaVibeService().isEnabled, isFalse);

      await HapticService().setEnabled(true);
      expect(VitaVibeService().isEnabled, isTrue);
    });

    test('negative: a deliberately-silenced pattern library STAYS silenced',
        () async {
      // The sub-setting is kept on purpose. Someone who switched off the
      // advanced patterns while keeping ordinary haptics must not have them
      // switched back on by the merge.
      await HapticService().setEnabled(true);
      await VitaVibeService().setEnabled(false);

      expect(VitaVibeService().isEnabled, isFalse,
          reason: 'the master switch gates it; it does not override it');
    });
  });

  group('one settings entry', () {
    final settings = File('lib/features/settings/screens/settings_screen.dart')
        .readAsStringSync();

    test('the duplicate row and screen are gone', () {
      expect(File('lib/features/settings/screens/vitavibe_settings_screen.dart')
          .existsSync(), isFalse);
      expect(settings.contains('VitaVibeSettingsScreen'), isFalse,
          reason: 'two rows for one concept is the reported defect');
      expect(settings.contains('_buildVitaVibeSettingsTile'), isFalse);
    });

    test("the deleted screen's only unique entry survives", () {
      // "Early access" had no equivalent on the Haptic screen, so it moved
      // rather than disappearing with its host.
      expect(settings.contains('Early access'), isTrue);
      expect(settings.contains('EarlyAccessScreen'), isTrue);
    });

    test('nothing still routes to the deleted screen', () {
      for (final path in const [
        'lib/main_qa.dart',
        'test/responsive/responsive_overflow_test.dart',
        'test/responsive/touch_target_audit_test.dart',
      ]) {
        expect(File(path).readAsStringSync().contains('VitaVibeSettingsScreen'),
            isFalse,
            reason: '$path still registers a screen that no longer exists');
      }
    });
  });
}
