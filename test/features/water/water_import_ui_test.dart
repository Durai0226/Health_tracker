/// "Count drinks from other apps" as the person meets it: the switch in the
/// Hydration profile, what the toast says, what Undo does, and the mark on a drink
/// that came from elsewhere. The platform is a fake; what it "finds" goes through
/// the real import into a real in-memory database.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/health_data_service.dart' show HealthReadException;
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/water/models/beverage_type.dart';
import 'package:tablet_remainder/features/water/models/enhanced_water_log.dart';
import 'package:tablet_remainder/features/water/screens/hydration_profile_screen.dart';
import 'package:tablet_remainder/features/water/services/water_health_import.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';
import 'package:tablet_remainder/features/water/widgets/aqua_timeline_list.dart';
import 'package:tablet_remainder/features/water/widgets/water_import_flow.dart';

/// A health store that answers from fields, and remembers what it was asked.
class FakeWaterSource implements WaterImportSource {
  FakeWaterSource({
    this.alreadyAllowed = false,
    this.grants = true,
    this.runner,
  });

  /// What [allowed] answers: true, false, or null when the look at the platform
  /// failed.
  bool? alreadyAllowed;
  bool grants;
  Future<WaterImportResult> Function()? runner;

  int asked = 0;
  int ran = 0;

  @override
  String get storeName => 'Health Connect';

  @override
  Future<bool?> allowed() async => alreadyAllowed;

  @override
  Future<bool> ask() async {
    asked++;
    return grants;
  }

  @override
  Future<WaterImportResult> run() async {
    ran++;
    return runner == null ? const WaterImportResult() : runner!();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late db.AppDatabase database;
  final ten = DateTime(2026, 9, 30, 10, 15);
  final now = DateTime(2026, 9, 30, 12);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    WaterService.clearInMemory();
    await WaterService.resetForTesting();
    await WaterService.init();
  });

  tearDown(() async => database.close());

  HealthDataPoint drink(DateTime end, double litres, {String uuid = 'abc'}) =>
      HealthDataPoint(
        uuid: uuid,
        value: NumericHealthValue(numericValue: litres),
        type: HealthDataType.WATER,
        unit: HealthDataUnit.LITER,
        dateFrom: end.subtract(const Duration(minutes: 1)),
        dateTo: end,
        sourcePlatform: HealthPlatformType.googleHealthConnect,
        sourceDeviceId: 'unknown',
        sourceId: 'com.sec.android.app.shealth',
        sourceName: 'Samsung Health',
        recordingMethod: RecordingMethod.automatic,
      );

  /// A source whose "health store" holds one drink, kept by the real import.
  FakeWaterSource holding({bool? alreadyAllowed = false, bool grants = true}) =>
      FakeWaterSource(alreadyAllowed: alreadyAllowed, grants: grants)
        ..runner = () => WaterHealthImport.run(
            now: now, samples: [drink(ten, 0.35)]);

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

  Future<void> show(WidgetTester tester, Widget home, {double height = 4000}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(411, height);
    addTearDown(tester.view.reset);
    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    try {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: home));
      await settle(tester, 800);
    } finally {
      FlutterError.onError = prev;
    }
  }

  Widget host(Future<void> Function(BuildContext) action) => Scaffold(
        body: Center(
          child: Builder(
            builder: (context) => TextButton(
                onPressed: () => action(context), child: const Text('go')),
          ),
        ),
      );

  Future<List<String>> todaysIds() async => [
        for (final l in (await WaterService.loadDataForDate(DateTime(2026, 9, 30)))
                ?.logs ??
            [])
          l.id
      ];

  group('turning it on', () {
    testWidgets('granted: it is on, reads straight away, and says what came in',
        (tester) async {
      final source = holding();
      var on = false;
      await show(tester, host((c) async {
        on = await WaterImportFlow.turnOn(c, source: source);
      }));

      await tester.tap(find.text('go'));
      await settle(tester);

      expect(on, isTrue);
      expect(source.asked, 1);
      expect(await WaterHealthImport.isEnabled(), isTrue);
      expect(await todaysIds(), ['hc_water_abc']);
      expect(find.text('Counted 1 drink (350 ml) from Health Connect'),
          findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('the Undo takes the drink back, and it does not return',
        (tester) async {
      final source = holding();
      await show(tester, host((c) => WaterImportFlow.turnOn(c, source: source)));
      await tester.tap(find.text('go'));
      await settle(tester);

      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(await todaysIds(), isEmpty);

      final again = await WaterHealthImport.run(now: now, samples: [drink(ten, 0.35)]);
      expect(again.isEmpty, isTrue, reason: 'an Undone drink stays gone');
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('already allowed: not asked again', (tester) async {
      final source = holding(alreadyAllowed: true);
      await show(tester, host((c) => WaterImportFlow.turnOn(c, source: source)));

      await tester.tap(find.text('go'));
      await settle(tester);

      expect(source.asked, 0);
      expect(source.ran, 1);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('granted with nothing there yet: says new ones will be counted',
        (tester) async {
      final source = FakeWaterSource();
      await show(tester, host((c) => WaterImportFlow.turnOn(c, source: source)));

      await tester.tap(find.text('go'));
      await settle(tester);

      expect(find.textContaining('will be counted here by themselves'),
          findsOneWidget);
      expect(await WaterHealthImport.isEnabled(), isTrue);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('a platform that could not be asked is not taken to have said yes — it is asked',
        (tester) async {
      final source = holding(alreadyAllowed: null);
      var on = false;
      await show(tester, host((c) async {
        on = await WaterImportFlow.turnOn(c, source: source);
      }));

      await tester.tap(find.text('go'));
      await settle(tester);

      expect(source.asked, 1, reason: 'null is not a grant');
      expect(on, isTrue);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('declined: it stays off, and nothing is read', (tester) async {
      final source = holding(grants: false);
      var on = true;
      await show(tester, host((c) async {
        on = await WaterImportFlow.turnOn(c, source: source);
      }));

      await tester.tap(find.text('go'));
      await settle(tester);

      expect(on, isFalse);
      expect(source.ran, 0);
      expect(await WaterHealthImport.isEnabled(), isFalse);
      expect(find.textContaining('did not share your drinks'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('a read that throws says so — and leaves it OFF, so the toast and the stored choice agree',
        (tester) async {
      // The choice is written before the first read. Left on after a failure, the
      // silent import at every resume kept going behind a switch that read off.
      final source = FakeWaterSource()..runner = () async => throw StateError('x');
      var on = true;
      await show(tester, host((c) async {
        on = await WaterImportFlow.turnOn(c, source: source);
      }));

      await tester.tap(find.text('go'));
      await settle(tester);

      expect(on, isFalse);
      expect(find.text('Could not switch this on. Please try again.'),
          findsOneWidget);
      expect(await WaterHealthImport.isEnabled(), isFalse);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('a store that does not answer leaves it ON, and says it will catch up',
        (tester) async {
      final source = FakeWaterSource()
        ..runner = () async => throw const HealthReadException('provider busy');
      var on = false;
      await show(tester, host((c) async {
        on = await WaterImportFlow.turnOn(c, source: source);
      }));

      await tester.tap(find.text('go'));
      await settle(tester);

      expect(on, isTrue);
      expect(find.textContaining('Switched on, but Health Connect did not answer just now'),
          findsOneWidget);
      expect(await WaterHealthImport.isEnabled(), isTrue);
      await tester.pump(const Duration(seconds: 8));
    });
  });

  group('in Today\'s Log', () {
    EnhancedWaterLog log(String id) {
      final b = BeverageType.defaultBeverages.first;
      return EnhancedWaterLog(
        id: id,
        time: DateTime(2026, 9, 30, 10, 15),
        amountMl: 350,
        effectiveHydrationMl: 350,
        beverageId: b.id,
        beverageName: b.name,
        beverageEmoji: b.emoji,
      );
    }

    Future<void> pumpList(WidgetTester tester, List<EnhancedWaterLog> logs) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: SingleChildScrollView(child: AquaTimelineList(logs: logs))),
      ));
      await tester.pump();
    }

    testWidgets('a drink from another app says so', (tester) async {
      await pumpList(tester, [log('hc_water_abc')]);
      expect(find.textContaining('from Health Connect'), findsOneWidget);
    });

    testWidgets('a drink logged here does not', (tester) async {
      await pumpList(tester, [log('3f2a9c1e-uuid')]);
      expect(find.textContaining('from Health Connect'), findsNothing);
    });
  });

  group('the Hydration profile switch', () {
    Future<void> openProfile(WidgetTester tester, FakeWaterSource source) =>
        show(tester, HydrationProfileScreen(importSource: source));

    Finder row() => find.text('Count drinks from other apps');

    testWidgets('is there, off, and says so', (tester) async {
      await openProfile(tester, holding());

      expect(find.text('Share drinks with other health apps'), findsOneWidget);
      await tester.ensureVisible(row());
      expect(row(), findsOneWidget);
      expect(find.text('Off. Only drinks you log here count.'), findsOneWidget);
    });

    testWidgets('turned on: asks, counts the drink, and the line under it changes',
        (tester) async {
      final source = holding();
      await openProfile(tester, source);
      await tester.ensureVisible(row());
      await tester.pump();

      await tester.tap(row());
      await settle(tester, 1000);

      expect(source.asked, 1);
      expect(await WaterHealthImport.isEnabled(), isTrue);
      expect(await todaysIds(), ['hc_water_abc']);
      expect(find.textContaining('are counted toward today, as plain water'),
          findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('declined: stays off', (tester) async {
      await openProfile(tester, holding(grants: false));
      await tester.ensureVisible(row());
      await tester.pump();

      await tester.tap(row());
      await settle(tester, 1000);

      expect(await WaterHealthImport.isEnabled(), isFalse);
      expect(find.text('Off. Only drinks you log here count.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('on but the permission was taken away outside the app: it opens off',
        (tester) async {
      await WaterHealthImport.setEnabled(true);
      await openProfile(tester, holding(alreadyAllowed: false));

      expect(await WaterHealthImport.isEnabled(), isFalse);
      await tester.ensureVisible(row());
      expect(find.text('Off. Only drinks you log here count.'), findsOneWidget);
    });

    testWidgets('on and the platform could not be asked: it opens on, and stays on',
        (tester) async {
      // Only a no switches it off: a look that failed says nothing.
      await WaterHealthImport.setEnabled(true);
      await openProfile(tester, holding(alreadyAllowed: null));

      expect(await WaterHealthImport.isEnabled(), isTrue);
      await tester.ensureVisible(row());
      expect(find.textContaining('are counted toward today'), findsOneWidget);
    });

    testWidgets('on and still allowed: it opens on', (tester) async {
      await WaterHealthImport.setEnabled(true);
      await openProfile(tester, holding(alreadyAllowed: true));

      expect(await WaterHealthImport.isEnabled(), isTrue);
      await tester.ensureVisible(row());
      expect(find.textContaining('are counted toward today'), findsOneWidget);
    });

    testWidgets('turned off, it stops and reads nothing', (tester) async {
      await WaterHealthImport.setEnabled(true);
      final source = holding(alreadyAllowed: true);
      await openProfile(tester, source);
      await tester.ensureVisible(row());
      await tester.pump();

      await tester.tap(row());
      await settle(tester, 1000);

      expect(await WaterHealthImport.isEnabled(), isFalse);
      expect(source.ran, 0);
    });
  });
}
