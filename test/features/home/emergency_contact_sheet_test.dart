import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/emergency_contact.dart';
import 'package:tablet_remainder/core/services/health_data_service.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import 'package:tablet_remainder/features/home/services/setup_checklist.dart';
import 'package:tablet_remainder/features/home/widgets/emergency_contact_sheet.dart';
import 'package:tablet_remainder/features/home/widgets/setup_checklist_card.dart';

Future<void> _prepare(WidgetTester tester) async {
  await tester.runAsync(() async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    addTearDown(() async => db.close());
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
  });
}

void main() {
  group('EmergencyContactForm', () {
    Future<List<bool>> pump(WidgetTester tester) async {
      final done = <bool>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
              child: EmergencyContactForm(onDone: done.add)),
        ),
      ));
      await tester.pump();
      return done;
    }

    testWidgets('Save stays off until the number can be dialled', (tester) async {
      await _prepare(tester);
      await pump(tester);
      Future<bool> enabled() async => tester
          .widget<AppButton>(find.widgetWithText(AppButton, 'Save'))
          .onPressed != null;

      expect(await enabled(), isFalse);
      await tester.enterText(find.byType(TextField).last, 'call me');
      await tester.pump();
      expect(await enabled(), isFalse);
      expect(find.text('Enter a number that can be dialled.'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, '+91 98765 43210');
      await tester.pump();
      expect(await enabled(), isTrue);
      expect(find.text('Enter a number that can be dialled.'), findsNothing);
    });

    testWidgets('saving stores the contact and reports done', (tester) async {
      await _prepare(tester);
      final done = await pump(tester);
      await tester.enterText(find.byType(TextField).first, '  Priya ');
      await tester.enterText(find.byType(TextField).last, '+91 98765 43210');
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.text('Save'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      expect(done, [true]);
      final c = EmergencyContact.get();
      expect(c?.name, 'Priya');
      expect(c?.phone, '+91 98765 43210');
    });

    testWidgets('an existing contact is prefilled and can be removed',
        (tester) async {
      await _prepare(tester);
      await tester.runAsync(() =>
          EmergencyContact.save(name: 'Priya', phone: '+91 98765 43210'));
      final done = await pump(tester);
      String textOf(int i) => tester
          .widget<TextField>(find.byType(TextField).at(i))
          .controller!
          .text;
      expect(textOf(0), 'Priya');
      expect(textOf(1), '+91 98765 43210');
      await tester.runAsync(() async {
        await tester.tap(find.text('Remove'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      expect(done, [true]);
      expect(EmergencyContact.isSet, isFalse);
    });

    testWidgets('there is nothing to remove before one is saved', (tester) async {
      await _prepare(tester);
      await pump(tester);
      expect(find.text('Remove'), findsNothing);
    });
  });

  group('the checklist card opens it', () {
    testWidgets('tapping Add on the contact step opens the sheet and, once '
        'saved, the step is ticked off', (tester) async {
      await _prepare(tester);
      var saved = false;
      final probes = SetupProbes(
        isAndroid: false,
        notificationsOn: () async => true,
        exactAlarmsOn: () async => true,
        batteryUnrestricted: () async => true,
        healthAvailability: () async => HealthAvailability.unavailable,
        widgetPlaced: () async => null,
        emergencyContactSet: () => EmergencyContact.isSet,
        backedUpRecently: () => true,
        requestNotifications: () async {},
        requestExactAlarms: () async {},
        requestBatteryExemption: () async {},
        requestHealth: () async {},
        requestWidgetPin: () async {},
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SetupChecklistCard(service: SetupChecklistService(probes: probes)),
        ),
      ));
      await tester.pump();
      await tester.pump();
      expect(find.text('Add an emergency contact'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Add'));
      await tester.pumpAndSettle();
      expect(find.text('Emergency contact'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, '+91 98765 43210');
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.text('Save'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        saved = true;
      });
      await tester.pumpAndSettle();
      expect(saved, isTrue);
      expect(EmergencyContact.isSet, isTrue);
      // Notifications, contact and backup are all on: nothing left to ask.
      expect(find.textContaining('set up'), findsNothing);
    });
  });
}
