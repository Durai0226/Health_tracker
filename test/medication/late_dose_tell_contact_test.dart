/// The missed-dose sheet offers to tell your contact, only if you asked it to.
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
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_log.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/late_dose_recovery.dart';
import 'package:tablet_remainder/features/medication/widgets/late_dose_sheets.dart';

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

  MissedDose dose() => MissedDose(
        MedicineLog.missed(
            id: 'l1', medicineId: 'm1', scheduledTime: DateTime(2026, 3, 10, 8)),
        EnhancedMedicine(
          id: 'm1',
          name: 'Metformin',
          dosageForm: DosageForm.tablet,
          dosageAmount: 1,
          schedule: MedicineSchedule(
              frequencyType: FrequencyType.onceDaily,
              times: [ScheduledTime(hour: 8, minute: 0)]),
        ),
      );

  Future<List<LateChoice?>> pump(WidgetTester tester,
      {double width = 430, double scale = 1}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, 1600);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.reset);
    final choices = <LateChoice?>[];
    await tester.pumpWidget(MaterialApp(
        theme: fontFreeTheme(),
        home: Scaffold(
            body: SingleChildScrollView(
                child: LateDoseForm(dose: dose(), onChoice: choices.add)))));
    await tester.pump();
    return choices;
  }

  testWidgets('nothing extra by default', (tester) async {
    await pump(tester);
    expect(find.textContaining('know'), findsNothing);
  });

  testWidgets('with a contact but the offer off: still nothing', (tester) async {
    await tester.runAsync(() => EmergencyContact.save(name: 'Priya', phone: '+91 98765 43210'));
    await pump(tester);
    expect(find.textContaining('know'), findsNothing);
  });

  testWidgets('with the offer on and a contact: "Let Priya know…"', (tester) async {
    await tester.runAsync(() async {
      await EmergencyContact.save(name: 'Priya', phone: '+91 98765 43210');
      await CareCircle.setOfferOnMissedDose(true);
    });
    await pump(tester);
    expect(find.text('Let Priya know…'), findsOneWidget);
  });

  testWidgets('it sits after the choices, and is not one of them', (tester) async {
    await tester.runAsync(() async {
      await EmergencyContact.save(name: 'Priya', phone: '+91 98765 43210');
      await CareCircle.setOfferOnMissedDose(true);
    });
    Uri? opened;
    ContactLauncher.launcherOverride = (uri) async {
      opened = uri;
      return true;
    };
    final choices = await pump(tester);

    final skip = tester.getTopLeft(find.text('Skip it')).dy;
    final tell = tester.getTopLeft(find.text('Let Priya know…')).dy;
    expect(tell, greaterThan(skip));

    await tester.tap(find.text('Let Priya know…'));
    await tester.pump();
    await tester.pump();
    expect(opened, isNotNull);
    expect(choices, isEmpty,
        reason: 'telling someone is not an answer about the dose; it stays open');
  });

  testWidgets('and the text it opens does not name the medicine', (tester) async {
    await tester.runAsync(() async {
      await EmergencyContact.save(name: 'Priya', phone: '+91 98765 43210');
      await CareCircle.setOfferOnMissedDose(true);
    });
    Uri? opened;
    ContactLauncher.launcherOverride = (uri) async {
      opened = uri;
      return true;
    };
    await pump(tester);
    await tester.tap(find.text('Let Priya know…'));
    await tester.pump();
    await tester.pump();
    expect(Uri.decodeComponent(opened.toString()).toLowerCase(), isNot(contains('metformin')));
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('fits at 320pt and ${scale}x text', (tester) async {
      await tester.runAsync(() async {
        await EmergencyContact.save(name: 'Priya Nair Venkataraghavan', phone: '+91 98765 43210');
        await CareCircle.setOfferOnMissedDose(true);
      });
      final reports = <String>[];
      final prev = FlutterError.onError;
      FlutterError.onError = (d) => reports.add(d.toString());
      try {
        await pump(tester, width: 320, scale: scale);
      } finally {
        FlutterError.onError = prev;
      }
      expect(find.textContaining('Let Priya'), findsOneWidget);
      expect(
          reports.where((r) =>
              r.contains('late_dose_sheets.dart') || r.contains('tell_contact_button.dart')),
          isEmpty,
          reason: reports.join('\n').split('\n').take(6).join('\n'));
    });
  }
}
