/// "Readings from other apps" as the person meets it: the switch in Vitals
/// settings, the button on an empty tracker, what the toast says and what Undo
/// does, and the readings showing up on the blood-pressure and blood-sugar screens
/// without anyone reopening them.
///
/// The platform is a fake source; the readings it "finds" go through the real
/// import into a real in-memory database.
library;

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/health_data_service.dart' show HealthReadException;
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart' show SettingsTile;
import 'package:tablet_remainder/features/medication/models/blood_pressure_reading.dart';
import 'package:tablet_remainder/features/medication/models/glucose_reading.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/blood_pressure_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/blood_sugar_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/vitals_reminder_settings_screen.dart';
import 'package:tablet_remainder/features/medication/services/vitals_health_import.dart';
import 'package:tablet_remainder/features/medication/services/vitals_storage_service.dart';
import 'package:tablet_remainder/features/medication/widgets/vitals_import_flow.dart';

/// A health store that answers from fields, and remembers what it was asked.
class FakeVitalsSource implements VitalsImportSource {
  FakeVitalsSource({
    this.store = 'Health Connect',
    this.alreadyAllowed = false,
    this.grants = true,
    this.runner,
    this.gate,
  });

  final String store;
  /// What [allowed] answers: true, false, or null when the look at the platform
  /// failed.
  bool? alreadyAllowed;
  bool grants;

  /// What "reading the health store" does. Null finds nothing.
  Future<VitalsImportResult> Function()? runner;

  /// When set, [ask] waits on it: a permission sheet not yet answered.
  Completer<bool>? gate;

  int asked = 0;
  int ran = 0;

  @override
  String get storeName => store;

  @override
  Future<bool?> allowed() async => alreadyAllowed;

  @override
  Future<bool> ask() async {
    asked++;
    if (gate != null) return gate!.future;
    return grants;
  }

  @override
  Future<VitalsImportResult> run() async {
    ran++;
    return runner == null ? const VitalsImportResult() : runner!();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;
  final eight = DateTime(2026, 9, 30, 8, 3);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    await ActiveProfileService().init();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
  });

  tearDown(() async {
    ActiveProfileService().resetForTesting();
    await db.close();
  });

  HealthDataPoint point(HealthDataType type, DateTime at, num value,
          {String source = 'com.omron.connect'}) =>
      HealthDataPoint(
        uuid: '$type-${at.millisecondsSinceEpoch}-$source',
        value: NumericHealthValue(numericValue: value),
        type: type,
        unit: HealthDataUnit.NO_UNIT,
        dateFrom: at,
        dateTo: at,
        sourcePlatform: HealthPlatformType.googleHealthConnect,
        sourceDeviceId: 'unknown',
        sourceId: source,
        sourceName: 'Omron connect',
        recordingMethod: RecordingMethod.automatic,
      );

  List<HealthDataPoint> cuff(DateTime at, int sys, int dia) => [
        point(HealthDataType.BLOOD_PRESSURE_SYSTOLIC, at, sys),
        point(HealthDataType.BLOOD_PRESSURE_DIASTOLIC, at, dia),
      ];

  /// A source whose "health store" holds these readings, kept by the real import.
  FakeVitalsSource holding({
    List<HealthDataPoint> bp = const [],
    List<HealthDataPoint> sugar = const [],
    bool? alreadyAllowed = false,
    bool grants = true,
  }) {
    final s = FakeVitalsSource(alreadyAllowed: alreadyAllowed, grants: grants);
    s.runner = () => VitalsHealthImport.run(
        now: DateTime(2026, 9, 30, 12), bpSamples: bp, glucoseSamples: sugar);
    return s;
  }

  Future<void> settle(WidgetTester tester, [int ms = 600]) async {
    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    try {
      for (var t = 0; t < ms; t += 100) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    } finally {
      FlutterError.onError = prev;
    }
  }

  void bigView(WidgetTester tester, [Size size = const Size(400, 2000)]) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
  }

  Future<void> show(WidgetTester tester, Widget home) async {
    bigView(tester);
    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    try {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: home));
      await settle(tester, 800);
    } finally {
      FlutterError.onError = prev;
    }
  }

  /// A page with one button that runs [action] with its own context.
  Widget host(Future<void> Function(BuildContext) action) => Scaffold(
        body: Center(
          child: Builder(
            builder: (context) => TextButton(
                onPressed: () => action(context), child: const Text('go')),
          ),
        ),
      );

  Future<List<BloodPressureReading>> storedBp() =>
      VitalsStorageService.getAllBp(scopeToActiveProfile: false);

  group('one import', () {
    testWidgets('asks once, reads, and says what it brought in, with Undo',
        (tester) async {
      final source = holding(bp: cuff(eight, 128, 82));
      await show(tester, host((c) => VitalsImportFlow.run(c, source: source)));

      await tester.tap(find.text('go'));
      await settle(tester);

      expect(source.asked, 1);
      expect(find.text('Brought in 1 blood pressure reading from Health Connect'),
          findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      expect(await storedBp(), hasLength(1));
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('the Undo takes them back, and they do not return', (tester) async {
      final source = holding(bp: cuff(eight, 128, 82));
      await show(tester, host((c) => VitalsImportFlow.run(c, source: source)));
      await tester.tap(find.text('go'));
      await settle(tester);

      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(await storedBp(), isEmpty);

      await tester.tap(find.text('go'));
      await settle(tester);
      expect(await storedBp(), isEmpty, reason: 'an Undone reading stays gone');
      expect(find.text('No new readings in Health Connect.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('a store already allowed is not asked again', (tester) async {
      final source = holding(bp: cuff(eight, 128, 82), alreadyAllowed: true);
      await show(tester, host((c) => VitalsImportFlow.run(c, source: source)));

      await tester.tap(find.text('go'));
      await settle(tester);

      expect(source.asked, 0);
      expect(source.ran, 1);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('declined: says nothing was imported, and does not read',
        (tester) async {
      final source = holding(bp: cuff(eight, 128, 82), grants: false);
      await show(tester, host((c) => VitalsImportFlow.run(c, source: source)));

      await tester.tap(find.text('go'));
      await settle(tester);

      expect(find.textContaining('did not share your readings'), findsOneWidget);
      expect(source.ran, 0);
      expect(await storedBp(), isEmpty);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('nothing new is said plainly', (tester) async {
      final source = holding();
      await show(tester, host((c) => VitalsImportFlow.run(c, source: source)));

      await tester.tap(find.text('go'));
      await settle(tester);

      expect(find.text('No new readings in Health Connect.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('a read that throws says so and changes nothing', (tester) async {
      final source = FakeVitalsSource(grants: true)
        ..runner = () async => throw StateError('no provider');
      await show(tester, host((c) => VitalsImportFlow.run(c, source: source)));

      await tester.tap(find.text('go'));
      await settle(tester);

      expect(find.text('Could not import from Health Connect. Please try again.'),
          findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('a store that does not answer says so, not that it failed', (tester) async {
      final source = FakeVitalsSource(grants: true)
        ..runner = () async => throw const HealthReadException('provider busy');
      await show(tester, host((c) => VitalsImportFlow.run(c, source: source)));

      await tester.tap(find.text('go'));
      await settle(tester);

      expect(find.textContaining('did not answer just now. Nothing was imported'),
          findsOneWidget);
      expect(find.textContaining('Could not import'), findsNothing);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('names the phone\'s own health app', (tester) async {
      final source = FakeVitalsSource(store: 'Apple Health')
        ..runner = () => VitalsHealthImport.run(
            now: DateTime(2026, 9, 30, 12),
            bpSamples: cuff(eight, 128, 82),
            glucoseSamples: const []);
      await show(tester, host((c) => VitalsImportFlow.run(c, source: source)));

      await tester.tap(find.text('go'));
      await settle(tester);

      expect(find.text('Brought in 1 blood pressure reading from Apple Health'),
          findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });
  });

  group('turning it on', () {
    testWidgets('granted: it is on, and reads straight away', (tester) async {
      final source = holding(bp: cuff(eight, 128, 82));
      var on = false;
      await show(tester, host((c) async {
        on = await VitalsImportFlow.turnOn(c, source: source);
      }));

      await tester.tap(find.text('go'));
      await settle(tester);

      expect(on, isTrue);
      expect(await VitalsHealthImport.isEnabled(), isTrue);
      expect(await storedBp(), hasLength(1));
      expect(find.text('Brought in 1 blood pressure reading from Health Connect'),
          findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('granted with nothing there yet: says new ones will appear',
        (tester) async {
      final source = holding();
      await show(tester, host((c) => VitalsImportFlow.turnOn(c, source: source)));

      await tester.tap(find.text('go'));
      await settle(tester);

      expect(find.textContaining('New readings from Health Connect will appear'),
          findsOneWidget);
      expect(await VitalsHealthImport.isEnabled(), isTrue);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('a platform that could not be asked is not taken to have said yes — it is asked',
        (tester) async {
      final source = holding(bp: cuff(eight, 128, 82), alreadyAllowed: null);
      var on = false;
      await show(tester, host((c) async {
        on = await VitalsImportFlow.turnOn(c, source: source);
      }));

      await tester.tap(find.text('go'));
      await settle(tester);

      expect(source.asked, 1, reason: 'null is not a grant');
      expect(on, isTrue);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('declined: it stays off', (tester) async {
      final source = holding(grants: false);
      var on = true;
      await show(tester, host((c) async {
        on = await VitalsImportFlow.turnOn(c, source: source);
      }));

      await tester.tap(find.text('go'));
      await settle(tester);

      expect(on, isFalse);
      expect(await VitalsHealthImport.isEnabled(), isFalse);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('a first read that fails leaves it OFF, so the toast and the stored choice agree',
        (tester) async {
      // Say a reading cannot be saved. The toast says it could not be switched
      // on and the switch snaps back — but the choice was written before the
      // read, and left on it kept importing at every resume behind a switch that
      // read off.
      final source = FakeVitalsSource(grants: true)
        ..runner = () async => throw StateError('disk full');
      var on = true;
      await show(tester, host((c) async {
        on = await VitalsImportFlow.turnOn(c, source: source);
      }));

      await tester.tap(find.text('go'));
      await settle(tester);

      expect(on, isFalse);
      expect(find.text('Could not switch this on. Please try again.'), findsOneWidget);
      expect(await VitalsHealthImport.isEnabled(), isFalse);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('a store that does not answer leaves it ON, and says it will catch up',
        (tester) async {
      // Unlike the above, nothing is wrong with the choice: the store was busy,
      // and the next run reads the same stretch again.
      final source = FakeVitalsSource(grants: true)
        ..runner = () async => throw const HealthReadException('provider busy');
      var on = false;
      await show(tester, host((c) async {
        on = await VitalsImportFlow.turnOn(c, source: source);
      }));

      await tester.tap(find.text('go'));
      await settle(tester);

      expect(on, isTrue);
      expect(find.textContaining('Switched on, but Health Connect did not answer just now'),
          findsOneWidget);
      expect(await VitalsHealthImport.isEnabled(), isTrue);
      await tester.pump(const Duration(seconds: 8));
    });
  });

  group('the button on an empty tracker', () {
    testWidgets('is named for the health app, and runs the import', (tester) async {
      final source = holding(bp: cuff(eight, 128, 82));
      await show(tester, Scaffold(body: Center(child: VitalsImportButton(source: source))));

      expect(find.text('Import from Health Connect'), findsOneWidget);
      await tester.tap(find.text('Import from Health Connect'));
      await settle(tester);

      expect(await storedBp(), hasLength(1));
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('two taps in the same frame ask once', (tester) async {
      final gate = Completer<bool>();
      final source = FakeVitalsSource(gate: gate);
      await show(tester, Scaffold(body: Center(child: VitalsImportButton(source: source))));

      await tester.tap(find.text('Import from Health Connect'));
      await tester.tap(find.text('Import from Health Connect'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));

      expect(source.asked, 1);
      gate.complete(false);
      await settle(tester);
      await tester.pump(const Duration(seconds: 8));
    });
  });

  group('the settings switch', () {
    Future<void> openSettings(WidgetTester tester, FakeVitalsSource source) =>
        show(tester, VitalsReminderSettingsScreen(importSource: source));

    testWidgets('is there, off, and says what it does', (tester) async {
      await openSettings(tester, holding());

      expect(find.text('Readings from other apps'), findsOneWidget);
      expect(find.text('Bring them in'), findsOneWidget);
      expect(find.textContaining('stay gone if you delete them'), findsOneWidget);
      final tile = tester
          .widget<SettingsTile>(find.widgetWithText(SettingsTile, 'Bring them in'));
      expect(tile.switchValue, isFalse);
    });

    testWidgets('turned on, it asks, reads, and stays on', (tester) async {
      final source = holding(bp: cuff(eight, 128, 82));
      await openSettings(tester, source);

      await tester.tap(find.text('Bring them in'));
      await settle(tester, 1000);

      expect(source.asked, 1);
      expect(await VitalsHealthImport.isEnabled(), isTrue);
      expect(await storedBp(), hasLength(1));
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('declined, it stays off', (tester) async {
      final source = holding(grants: false);
      await openSettings(tester, source);

      await tester.tap(find.text('Bring them in'));
      await settle(tester, 1000);

      expect(await VitalsHealthImport.isEnabled(), isFalse);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('turned off, it stops', (tester) async {
      await VitalsHealthImport.setEnabled(true);
      final source = holding(alreadyAllowed: true);
      await openSettings(tester, source);

      await tester.tap(find.text('Bring them in'));
      await settle(tester, 1000);

      expect(await VitalsHealthImport.isEnabled(), isFalse);
      expect(source.ran, 0, reason: 'switching off reads nothing');
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('on and still allowed: no notice', (tester) async {
      await VitalsHealthImport.setEnabled(true);
      await openSettings(tester, holding(alreadyAllowed: true));

      expect(find.textContaining('stopped'), findsNothing);
      expect(await VitalsHealthImport.isEnabled(), isTrue);
    });

    testWidgets('on but the permission was turned off outside the app: says so, and is off',
        (tester) async {
      await VitalsHealthImport.setEnabled(true);
      await openSettings(tester, holding(alreadyAllowed: false));

      expect(find.textContaining('Bringing in readings from Health Connect stopped'),
          findsOneWidget);
      expect(await VitalsHealthImport.isEnabled(), isFalse);
    });

    testWidgets('on and the platform could not be asked: stays on, with no notice',
        (tester) async {
      // Health Connect updating, or not answering. Only a no is a revoked grant;
      // a look that failed says nothing, and the person's choice is not theirs to
      // lose to it — nor is a notice that they revoked something they did not.
      await VitalsHealthImport.setEnabled(true);
      await openSettings(tester, holding(alreadyAllowed: null));

      expect(find.textContaining('stopped'), findsNothing);
      expect(await VitalsHealthImport.isEnabled(), isTrue);
    });
  });

  group('on the trackers', () {
    BloodPressureReading typed(String id, int sys, int dia, DateTime at) =>
        BloodPressureReading(
            id: id, systolic: sys, diastolic: dia, takenAt: at, createdAt: at);

    testWidgets('an empty blood-pressure tracker offers the import', (tester) async {
      await show(tester, const BloodPressureScreen());

      expect(find.text('Log reading'), findsOneWidget);
      expect(find.byType(VitalsImportButton), findsOneWidget);
    });

    testWidgets('an empty blood-sugar tracker offers it too', (tester) async {
      await show(tester, const BloodSugarScreen());

      expect(find.byType(VitalsImportButton), findsOneWidget);
    });

    testWidgets('a reading that came from the health app says so; one typed in does not',
        (tester) async {
      await VitalsStorageService.saveBp(typed('typed', 118, 76, eight),
          stampActiveProfile: false, syncToHealthConnect: false);
      await VitalsHealthImport.run(
          now: DateTime(2026, 9, 30, 12),
          bpSamples: cuff(eight.add(const Duration(hours: 3)), 131, 84),
          glucoseSamples: const []);

      await show(tester, const BloodPressureScreen());

      expect(find.textContaining('131/84 mmHg'), findsWidgets);
      expect(find.textContaining('from Health Connect'), findsOneWidget,
          reason: 'only the imported row carries it');
    });

    testWidgets('a reading that arrives while the screen is open appears without reopening it',
        (tester) async {
      await VitalsStorageService.saveBp(typed('typed', 118, 76, eight),
          stampActiveProfile: false, syncToHealthConnect: false);
      await show(tester, const BloodPressureScreen());
      expect(find.textContaining('131/84 mmHg'), findsNothing);

      await VitalsHealthImport.run(
          now: DateTime(2026, 9, 30, 12),
          bpSamples: cuff(eight.add(const Duration(hours: 3)), 131, 84),
          glucoseSamples: const []);
      await settle(tester);

      expect(find.textContaining('131/84 mmHg'), findsWidgets);
    });

    testWidgets('a blood sugar that came from the health app says so, and arrives live',
        (tester) async {
      await VitalsStorageService.saveGlucose(
          GlucoseReading(id: 'typed', valueMgdl: 95, takenAt: eight, createdAt: eight),
          stampActiveProfile: false,
          syncToHealthConnect: false);
      await show(tester, const BloodSugarScreen());
      expect(find.textContaining('from Health Connect'), findsNothing);

      await VitalsHealthImport.run(
          now: DateTime(2026, 9, 30, 12),
          bpSamples: const [],
          glucoseSamples: [
            point(HealthDataType.BLOOD_GLUCOSE, eight.add(const Duration(hours: 3)), 112,
                source: 'com.glucose.meter')
          ]);
      await settle(tester);

      expect(find.textContaining('from Health Connect'), findsOneWidget);
    });
  });
}
