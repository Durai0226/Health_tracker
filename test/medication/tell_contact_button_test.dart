/// "Let Priya know…": an offer on a missed dose, never an action.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/care_circle.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/contact_launcher.dart';
import 'package:tablet_remainder/core/services/emergency_contact.dart';
import 'package:tablet_remainder/features/medication/widgets/tell_contact_button.dart';

import '../support/font_free_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
  });

  tearDown(() async {
    ContactLauncher.launcherOverride = null;
    await db.close();
  });

  Future<void> pump(WidgetTester tester, {double width = 430, double scale = 1}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, 1200);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        theme: fontFreeTheme(), home: const Scaffold(body: TellContactButton())));
    await tester.pump();
  }

  Future<void> contact({String name = 'Priya', String phone = '+91 98765 43210', bool offer = true}) async {
    await EmergencyContact.save(name: name, phone: phone);
    await CareCircle.setOfferOnMissedDose(offer);
  }

  testWidgets('nothing while the offer is off', (tester) async {
    await tester.runAsync(() => contact(offer: false));
    await pump(tester);
    expect(find.textContaining('know'), findsNothing);
  });

  testWidgets('nothing without a contact', (tester) async {
    await tester.runAsync(() => CareCircle.setOfferOnMissedDose(true));
    await pump(tester);
    expect(find.textContaining('know'), findsNothing);
  });

  testWidgets('named, when there is a contact and the offer is on', (tester) async {
    await tester.runAsync(contact);
    await pump(tester);
    expect(find.text('Let Priya know…'), findsOneWidget);
  });

  testWidgets('a contact with no name is "your contact"', (tester) async {
    await tester.runAsync(() => contact(name: ''));
    await pump(tester);
    expect(find.text('Let your contact know…'), findsOneWidget);
  });

  testWidgets('a tap opens the messages app with the note, and sends nothing',
      (tester) async {
    await tester.runAsync(contact);
    Uri? opened;
    ContactLauncher.launcherOverride = (uri) async {
      opened = uri;
      return true;
    };
    await pump(tester);

    await tester.tap(find.text('Let Priya know…'));
    await tester.pump();
    await tester.pump();

    expect(opened!.scheme, 'sms');
    expect(opened!.path, '+919876543210');
    expect(
        opened.toString(),
        'sms:+919876543210?body=Hi%20Priya%2C%20I%20missed%20a%20dose%20today%20and%20'
        'could%20use%20a%20nudge.%20Sent%20from%20DlyMinder.');
    final body = Uri.decodeComponent(opened!.query.substring('body='.length));
    expect(body.toLowerCase(), isNot(contains('metformin')));
  });

  testWidgets('no messages app: it says the number', (tester) async {
    await tester.runAsync(contact);
    ContactLauncher.launcherOverride = (_) async => false;
    await pump(tester);
    await tester.tap(find.text('Let Priya know…'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining('The number is +91 98765 43210'), findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('fits at 320pt and ${scale}x text, with a long name', (tester) async {
      await tester.runAsync(() => contact(name: 'Priya Nair Venkataraghavan'));
      final reports = <String>[];
      final prev = FlutterError.onError;
      FlutterError.onError = (d) => reports.add(d.toString());
      try {
        await pump(tester, width: 320, scale: scale);
      } finally {
        FlutterError.onError = prev;
      }
      expect(find.textContaining('Let Priya'), findsOneWidget);
      expect(reports, isEmpty, reason: reports.join('\n').split('\n').take(6).join('\n'));
    });
  }
}
