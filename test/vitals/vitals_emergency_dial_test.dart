import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/health/vitals_analyzer.dart';
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/medication/models/blood_pressure_reading.dart';
import 'package:tablet_remainder/features/medication/models/glucose_reading.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/blood_pressure_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/blood_sugar_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/vitals_emergency_call.dart';
import 'package:tablet_remainder/features/medication/services/vitals_storage_service.dart';

/// PV-08 / MED-UI-11 — the "Call emergency" button on the two vitals crisis
/// cards used to show a toast telling the user to call a number themselves,
/// and do nothing else. These tests pin that it now opens the dialer, on both
/// screens, through the one shared helper.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late List<Uri> launched;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    launched = [];
    VitalsEmergencyCall.launcherOverride = (uri) async {
      launched.add(uri);
      return true;
    };
  });

  tearDown(() async {
    VitalsEmergencyCall.launcherOverride = null;
    await db.close();
  });

  BloodPressureReading bp(int sys, int dia, DateTime at) =>
      BloodPressureReading(
        id: 'bp_${at.microsecondsSinceEpoch}',
        systolic: sys,
        diastolic: dia,
        takenAt: at,
        createdAt: at,
      );

  GlucoseReading glucose(int mgdl, DateTime at) => GlucoseReading(
        id: 'g_${at.microsecondsSinceEpoch}',
        valueMgdl: mgdl,
        context: GlucoseContext.fasting,
        takenAt: at,
        createdAt: at,
      );

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 2000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: home));
    await tester.pumpAndSettle();
  }

  group('the number dialled', () {
    test('known regions get their own national number', () {
      expect(VitalsEmergencyCall.numberForRegion('US'), '911');
      expect(VitalsEmergencyCall.numberForRegion('GB'), '999');
      expect(VitalsEmergencyCall.numberForRegion('AU'), '000');
    });

    test('the region code is matched case-insensitively', () {
      expect(VitalsEmergencyCall.numberForRegion('us'), '911');
    });

    test('an unknown, empty or absent region falls back to 112', () {
      expect(VitalsEmergencyCall.numberForRegion('ZZ'),
          VitalsEmergencyCall.fallbackNumber);
      expect(VitalsEmergencyCall.numberForRegion(''),
          VitalsEmergencyCall.fallbackNumber);
      expect(VitalsEmergencyCall.numberForRegion(null),
          VitalsEmergencyCall.fallbackNumber);
      expect(VitalsEmergencyCall.fallbackNumber, '112');
    });

    test('India is covered by the 112 fallback, not a stale 108/102', () {
      expect(VitalsEmergencyCall.numberForRegion('IN'), '112');
    });
  });

  testWidgets('BP crisis card: Call emergency opens the dialer', (tester) async {
    final now = DateTime.now();
    await VitalsStorageService.saveBp(bp(196, 126, now));
    await pump(tester, const BloodPressureScreen());

    expect(find.text('Call emergency'), findsOneWidget);
    await tester.tap(find.text('Call emergency'));
    await tester.pumpAndSettle();

    expect(launched, hasLength(1));
    expect(launched.single.scheme, 'tel');
    expect(launched.single.path, VitalsEmergencyCall.currentNumber);
  });

  testWidgets('severe-low glucose card: Call emergency opens the dialer',
      (tester) async {
    final now = DateTime.now();
    await VitalsStorageService.saveGlucose(glucose(42, now));
    await pump(tester, const BloodSugarScreen());

    expect(find.text('Call emergency'), findsOneWidget);
    await tester.tap(find.text('Call emergency'));
    await tester.pumpAndSettle();

    expect(launched, hasLength(1));
    expect(launched.single.scheme, 'tel');
    expect(launched.single.path, VitalsEmergencyCall.currentNumber);
  });

  testWidgets('no dialer: the failure is honest and still names the number',
      (tester) async {
    VitalsEmergencyCall.launcherOverride = (uri) async {
      launched.add(uri);
      return false;
    };
    final now = DateTime.now();
    await VitalsStorageService.saveBp(bp(196, 126, now));
    await pump(tester, const BloodPressureScreen());

    await tester.tap(find.text('Call emergency'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(launched, hasLength(1));
    expect(
      find.textContaining('Could not open the dialer'),
      findsOneWidget,
      reason: 'a launch that fails must say so, not look like it worked',
    );
    expect(find.textContaining(VitalsEmergencyCall.currentNumber), findsWidgets);
  });

  group('the real launch path — no test override', () {
    late List<MethodCall> urlLauncherCalls;

    /// Under `flutter test`, `UrlLauncherPlatform.instance` is the platform
    /// interface's `MethodChannelUrlLauncher`, so the plugin's own channel can
    /// be mocked — the only way to exercise the branch that
    /// [VitalsEmergencyCall.launcherOverride] otherwise stands in for. Every
    /// test above runs through the override and so says nothing about how the
    /// helper talks to url_launcher.
    void mockUrlLauncher({required bool canLaunch, bool launchThrows = false}) {
      VitalsEmergencyCall.launcherOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/url_launcher'),
              (call) async {
        urlLauncherCalls.add(call);
        if (call.method == 'canLaunch') return canLaunch;
        if (call.method == 'launch') {
          if (launchThrows) {
            throw PlatformException(code: 'ACTIVITY_NOT_FOUND');
          }
          return true;
        }
        return null;
      });
    }

    setUp(() => urlLauncherCalls = []);

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/url_launcher'), null);
    });

    testWidgets('a "no" from canLaunchUrl does not block the call',
        (tester) async {
      // This is the real answer on the app's primary target: `canLaunchUrl`
      // resolves the intent through the package manager, and Android 11+
      // package visibility hides the dialer from it. Its own documentation
      // says it "will always return false" on recent Android and iOS unless
      // the app is configured to query for launch support. Gating the dial on
      // it turned "Call emergency" back into the advice toast it replaced.
      mockUrlLauncher(canLaunch: false);
      await VitalsStorageService.saveBp(bp(196, 126, DateTime.now()));
      await pump(tester, const BloodPressureScreen());

      await tester.tap(find.text('Call emergency'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final launch = urlLauncherCalls.where((c) => c.method == 'launch');
      expect(launch, hasLength(1),
          reason: 'the dialer must be opened, not pre-vetoed');
      expect((launch.single.arguments as Map)['url'],
          'tel:${VitalsEmergencyCall.currentNumber}');
      expect(find.textContaining('Could not open the dialer'), findsNothing,
          reason: 'the launch succeeded; nothing failed to report');
    });

    testWidgets('a launch the OS refuses is still reported honestly',
        (tester) async {
      mockUrlLauncher(canLaunch: true, launchThrows: true);
      await VitalsStorageService.saveBp(bp(196, 126, DateTime.now()));
      await pump(tester, const BloodPressureScreen());

      await tester.tap(find.text('Call emergency'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Could not open the dialer'), findsOneWidget,
          reason: 'a PlatformException out of launchUrl is a real failure');
      expect(find.textContaining(VitalsEmergencyCall.currentNumber),
          findsWidgets);
    });
  });

  /// The emergency button no longer consults `canLaunchUrl`, but the doctor
  /// and clinic call buttons still do (nunito_doctor_list_screen.dart:74,
  /// nunito_clinic_list_screen.dart:74). Without a `<queries>` entry the
  /// package manager hides every dialer from them on Android 11+, so those
  /// buttons silently do nothing on a phone that dials perfectly well.
  test('the manifest lets the app see a dialer', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final queries =
        RegExp(r'<queries>(.*?)</queries>', dotAll: true).firstMatch(manifest);
    expect(queries, isNotNull, reason: 'no <queries> block in the manifest');
    final body = queries!.group(1)!;
    expect(body, contains('android.intent.action.DIAL'));
    expect(body, contains('android:scheme="tel"'));
  });
}
