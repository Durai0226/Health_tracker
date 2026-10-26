import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/health_data_service.dart';
import 'package:tablet_remainder/features/home/services/setup_checklist.dart';
import 'package:tablet_remainder/features/home/widgets/setup_checklist_card.dart';

/// Probes backed by mutable fields, recording which fixes were requested.
class _Fake {
  bool android;
  bool notifications;
  bool exact;
  bool battery;
  HealthAvailability health;
  bool? widget;
  bool emergency;
  bool backup;
  final fixes = <String>[];

  _Fake({
    this.android = true,
    this.notifications = true,
    this.exact = true,
    this.battery = true,
    this.health = HealthAvailability.available,
    this.widget = true,
    this.emergency = true,
    this.backup = true,
  });

  SetupProbes probes() => SetupProbes(
        isAndroid: android,
        notificationsOn: () async => notifications,
        exactAlarmsOn: () async => exact,
        batteryUnrestricted: () async => battery,
        healthAvailability: () async => health,
        widgetPlaced: () async => widget,
        emergencyContactSet: () => emergency,
        backedUpRecently: () => backup,
        requestNotifications: () async {
          fixes.add(SetupStepId.notifications);
          notifications = true;
        },
        requestExactAlarms: () async {
          fixes.add(SetupStepId.exactAlarms);
          exact = true;
        },
        requestBatteryExemption: () async {
          fixes.add(SetupStepId.battery);
          battery = true;
        },
        requestHealth: () async {
          fixes.add(SetupStepId.health);
          health = HealthAvailability.available;
        },
        requestWidgetPin: () async {
          fixes.add(SetupStepId.widget);
          widget = true;
        },
      );
}

void main() {
  group('SetupChecklistService', () {
    test('everything on is complete with all seven steps counted', () async {
      final list =
          await SetupChecklistService(probes: _Fake().probes()).check();
      expect(list.total, 7);
      expect(list.doneCount, 7);
      expect(list.complete, isTrue);
    });

    test('pending lists exactly what is off, in display order', () async {
      final f = _Fake(
          exact: false, battery: false, health: HealthAvailability.denied);
      final list = await SetupChecklistService(probes: f.probes()).check();
      expect(list.doneCount, 4);
      expect(list.pending.map((s) => s.id), [
        SetupStepId.exactAlarms,
        SetupStepId.battery,
        SetupStepId.health,
      ]);
      expect(list.complete, isFalse);
    });

    test('Android-only steps are left out on iPhone, not counted as done',
        () async {
      // No launcher to ask about a widget on iPhone either: that step is
      // left out too, not counted done.
      final f = _Fake(
          android: false, exact: false, battery: false, widget: null);
      final list = await SetupChecklistService(probes: f.probes()).check();
      expect(list.steps.map((s) => s.id), [
        SetupStepId.notifications,
        SetupStepId.health,
        SetupStepId.emergencyContact,
        SetupStepId.backup,
      ]);
      expect(list.total, 4, reason: 'no "7 of 7" claiming steps that never applied');
      expect(list.steps.firstWhere((s) => s.id == SetupStepId.health).title,
          'Connect Apple Health');
    });

    test('health is left out when the platform has no health store', () async {
      final f = _Fake(health: HealthAvailability.unavailable);
      final list = await SetupChecklistService(probes: f.probes()).check();
      expect(list.steps.any((s) => s.id == SetupStepId.health), isFalse);
    });

    test('a throwing probe degrades instead of failing the whole check',
        () async {
      final base = _Fake(battery: false).probes();
      final probes = SetupProbes(
        isAndroid: true,
        notificationsOn: () async => throw StateError('boom'),
        exactAlarmsOn: () async => throw StateError('boom'),
        batteryUnrestricted: base.batteryUnrestricted,
        healthAvailability: () async => throw StateError('boom'),
        widgetPlaced: () async => throw StateError('boom'),
        emergencyContactSet: base.emergencyContactSet,
        backedUpRecently: base.backedUpRecently,
        requestNotifications: base.requestNotifications,
        requestExactAlarms: base.requestExactAlarms,
        requestBatteryExemption: base.requestBatteryExemption,
        requestHealth: base.requestHealth,
        requestWidgetPin: base.requestWidgetPin,
      );
      final list = await SetupChecklistService(probes: probes).check();
      // notifications fall back to "on" (the OS check is documented as
      // unreliable and must not nag); exact alarms fall back to "off".
      final byId = {for (final s in list.steps) s.id: s.done};
      expect(byId[SetupStepId.notifications], isTrue);
      expect(byId[SetupStepId.exactAlarms], isFalse);
      expect(byId.containsKey(SetupStepId.health), isFalse);
      // A launcher that will not answer is "cannot tell", not "not placed".
      expect(byId.containsKey(SetupStepId.widget), isFalse);
    });

    test('the widget step reflects whether it is on the home screen', () async {
      for (final placed in [true, false]) {
        final list = await SetupChecklistService(
                probes: _Fake(widget: placed).probes())
            .check();
        final step = list.steps.firstWhere((s) => s.id == SetupStepId.widget);
        expect(step.done, placed);
      }
    });

    test('the emergency contact and backup steps follow their probes',
        () async {
      final f = _Fake(emergency: false, backup: false);
      final list = await SetupChecklistService(probes: f.probes()).check();
      expect(list.pending.map((s) => s.id),
          [SetupStepId.emergencyContact, SetupStepId.backup]);
      f.emergency = true;
      f.backup = true;
      expect(
          (await SetupChecklistService(probes: f.probes()).check()).complete,
          isTrue);
    });

    test('fix dispatches to the matching request', () async {
      final f = _Fake();
      final service = SetupChecklistService(probes: f.probes());
      for (final id in [
        SetupStepId.notifications,
        SetupStepId.exactAlarms,
        SetupStepId.battery,
        SetupStepId.health,
        SetupStepId.widget,
      ]) {
        await service.fix(id);
      }
      // The contact and the backup are screens the card opens, so the service
      // has nothing to run for them.
      await service.fix(SetupStepId.emergencyContact);
      await service.fix(SetupStepId.backup);
      await service.fix('nonsense');
      expect(f.fixes, [
        SetupStepId.notifications,
        SetupStepId.exactAlarms,
        SetupStepId.battery,
        SetupStepId.health,
        SetupStepId.widget,
      ]);
    });
  });

  group('SetupChecklistCard', () {
    // Real database I/O never completes under FakeAsync, so the setup runs in
    // tester.runAsync. Each test gets a fresh in-memory database, which is also
    // what resets the Hide flag between tests.
    Future<void> prepare(WidgetTester tester) async {
      await tester.runAsync(() async {
        SharedPreferences.setMockInitialValues({});
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        AppDatabase.setInstanceForTesting(db);
        addTearDown(() async => db.close());
        CleanStorageService.resetForTesting();
        await CleanStorageService.init();
      });
    }

    Future<void> pump(WidgetTester tester, _Fake f) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SetupChecklistCard(
              service: SetupChecklistService(probes: f.probes())),
        ),
      ));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('shows progress and only the steps still off', (tester) async {
      await prepare(tester);
      await pump(tester, _Fake(exact: false, battery: false));
      expect(find.text('5 of 7 set up'), findsOneWidget);
      expect(find.text('Allow exact alarms'), findsOneWidget);
      expect(find.text('Stop battery limits on reminders'), findsOneWidget);
      expect(find.text('Allow notifications'), findsNothing);
    });

    testWidgets('renders nothing when everything is set up', (tester) async {
      await prepare(tester);
      await pump(tester, _Fake());
      expect(find.textContaining('set up'), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('tapping a fix runs it, then the row disappears on re-check',
        (tester) async {
      await prepare(tester);
      final f = _Fake(exact: false);
      await pump(tester, f);
      expect(find.text('6 of 7 set up'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Allow'));
      await tester.pump();
      await tester.pump();

      expect(f.fixes, [SetupStepId.exactAlarms]);
      // Last step fixed → the whole card goes away.
      expect(find.textContaining('set up'), findsNothing);
    });

    testWidgets('Hide removes the card and survives a rebuild', (tester) async {
      await prepare(tester);
      final f = _Fake(battery: false);
      await pump(tester, f);
      await tester.runAsync(() async {
        await tester.tap(find.text('Hide'));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      expect(find.textContaining('set up'), findsNothing);

      // Unmount first: pumping the same widget type again would REUSE the
      // State and never re-read the saved flag, which made this assertion
      // pass with the save deleted.
      await tester.pumpWidget(const SizedBox());
      await pump(tester, f);
      expect(find.textContaining('set up'), findsNothing);
    });
  });
}
