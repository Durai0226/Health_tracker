/// "Directions" on a clinic card, for a clinic that has an address.
///
/// The button was "Map", shown only for a clinic with coordinates — and nothing in
/// the app can set coordinates: the form has no field for them. So it never
/// appeared, on any clinic, and the address people actually type led nowhere.
/// It is offered now for an address too, and opens a maps app with directions to
/// it.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/toast/toast_overlay.dart';
import 'package:tablet_remainder/features/medication/models/clinic.dart';
import 'package:tablet_remainder/features/medication/screens/clinics/nunito_clinic_list_screen.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    ToastOverlay.instance.resetForTesting();
  });

  tearDown(() async {
    ToastOverlay.instance.resetForTesting();
    await db.close();
  });

  Clinic clinic({String? address, double? lat, double? lng, String? phone}) => Clinic(
        id: 'c1',
        name: 'Mercy General',
        address: address,
        latitude: lat,
        longitude: lng,
        phone: phone,
      );

  group('whether it can be offered', () {
    test('an address is enough', () {
      expect(clinic(address: '12 High St, Leeds').canGetDirections, isTrue);
    });

    test('so are coordinates', () {
      expect(clinic(lat: 53.8, lng: -1.55).canGetDirections, isTrue);
    });

    test('half of a pair of coordinates is not, and neither is a blank address', () {
      expect(clinic(lat: 53.8).canGetDirections, isFalse);
      expect(clinic(lng: -1.55).canGetDirections, isFalse);
      expect(clinic(address: '   ').canGetDirections, isFalse);
      expect(clinic().canGetDirections, isFalse);
    });

    test('a phone number alone does not give directions', () {
      expect(clinic(phone: '555 0100').canGetDirections, isFalse);
    });
  });

  group('the link', () {
    test('goes to the address as typed, trimmed', () {
      final uri = clinic(address: '  12 High St, Leeds ').directionsUri()!;

      expect(uri.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/dir/');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['destination'], '12 High St, Leeds');
    });

    test('an address with characters that mean something in a link survives', () {
      final uri = clinic(address: 'Unit 4 & 5, Mill Rd #2 (rear)').directionsUri()!;

      expect(uri.queryParameters['destination'], 'Unit 4 & 5, Mill Rd #2 (rear)');
      expect(uri.hasFragment, isFalse, reason: 'the # is data, not a fragment');
    });

    test('prefers coordinates to the address when it has both', () {
      final uri = clinic(address: '12 High St', lat: 53.8, lng: -1.55).directionsUri()!;

      expect(uri.queryParameters['destination'], '53.8,-1.55');
    });

    test('on an iPhone it is the system maps app\'s own link', () {
      final uri = clinic(address: '12 High St').directionsUri(apple: true)!;

      expect(uri.host, 'maps.apple.com');
      expect(uri.queryParameters['daddr'], '12 High St');
    });

    test('there is none to build without somewhere to go', () {
      expect(clinic().directionsUri(), isNull);
      expect(clinic(address: ' ').directionsUri(), isNull);
      expect(clinic().directionsUri(apple: true), isNull);
    });
  });

  group('on the clinic list', () {
    late List<MethodCall> calls;
    const channel = MethodChannel('plugins.flutter.io/url_launcher');

    /// Under `flutter test` the launcher is the platform interface's method-channel
    /// one, so its channel can be answered: what was asked to be opened, and
    /// whether that worked. `canLaunch` answers false — which is what recent
    /// Android says for a web link unless the app declares it queries them — and
    /// must not matter.
    void mockLauncher({bool launches = true, bool throws = false}) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'canLaunch') return false;
        if (call.method == 'launch') {
          if (throws) throw PlatformException(code: 'ACTIVITY_NOT_FOUND');
          return launches;
        }
        return null;
      });
    }

    setUp(() {
      calls = [];
      mockLauncher();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    Future<void> open(WidgetTester tester, Clinic c) async {
      await MedicineCleanStorageService.saveClinic(c);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const NunitoClinicListScreen(),
      ));
      await tester.pumpAndSettle();
    }

    Iterable<MethodCall> launches() => calls.where((c) => c.method == 'launch');

    testWidgets('an address brings the button', (tester) async {
      await open(tester, clinic(address: '12 High St, Leeds'));

      expect(find.text('Directions'), findsOneWidget);
      expect(find.text('Map'), findsNothing);
    });

    testWidgets('and tapping it opens a maps link for that address', (tester) async {
      await open(tester, clinic(address: '12 High St, Leeds'));

      await tester.tap(find.text('Directions'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(launches(), hasLength(1));
      final url = Uri.parse(launches().single.arguments['url'] as String);
      expect(url.host, 'www.google.com');
      expect(url.queryParameters['destination'], '12 High St, Leeds');
      expect(find.textContaining('Could not open'), findsNothing);
    });

    testWidgets('a web link that canLaunch refuses is still launched', (tester) async {
      // `canLaunch` answers false in `mockLauncher`, as recent Android does.
      await open(tester, clinic(address: '12 High St'));

      await tester.tap(find.text('Directions'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(launches(), hasLength(1));
    });

    testWidgets('a clinic with a phone and an address has both buttons', (tester) async {
      await open(tester, clinic(address: '12 High St', phone: '555 0100'));

      expect(find.text('Call'), findsOneWidget);
      expect(find.text('Directions'), findsOneWidget);
    });

    testWidgets('no address, no coordinates: no button', (tester) async {
      await open(tester, clinic(phone: '555 0100'));

      expect(find.text('Directions'), findsNothing);
      expect(find.text('Call'), findsOneWidget);
    });

    testWidgets('a maps app that cannot be opened says so', (tester) async {
      mockLauncher(launches: false);
      await open(tester, clinic(address: '12 High St'));

      await tester.tap(find.text('Directions'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Could not open a maps app'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('and so does one that throws', (tester) async {
      mockLauncher(throws: true);
      await open(tester, clinic(address: '12 High St'));

      await tester.tap(find.text('Directions'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Could not open a maps app'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });
  });
}
