import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/services/battery_optimization_service.dart';
import '../../../core/services/health_data_service.dart';
import '../../../core/services/notification_service.dart';
import 'package:home_widget/home_widget.dart';
import '../../../core/services/backup_record.dart';
import '../../../core/services/emergency_contact.dart';

/// One thing that has to be on for reminders and health data to be reliable.
@immutable
class SetupStep {
  final String id;
  final String title;

  /// What the user loses while this is off — the reason to bother.
  final String detail;

  /// Label for the one-tap fix button.
  final String fixLabel;
  final bool done;

  const SetupStep({
    required this.id,
    required this.title,
    required this.detail,
    required this.fixLabel,
    required this.done,
  });
}

/// The live result of every check, in the order they are shown.
@immutable
class SetupChecklist {
  final List<SetupStep> steps;
  const SetupChecklist(this.steps);

  int get total => steps.length;
  int get doneCount => steps.where((s) => s.done).length;
  List<SetupStep> get pending => steps.where((s) => !s.done).toList();

  /// True when there is nothing to ask the user — including when no step
  /// applies on this platform, so an empty list never renders a "0 of 0" card.
  bool get complete => pending.isEmpty;
}

/// Step ids, shared with [SetupChecklistService.fix] and the tests.
class SetupStepId {
  const SetupStepId._();
  static const notifications = 'notifications';
  static const exactAlarms = 'exact_alarms';
  static const battery = 'battery';
  static const health = 'health';
  static const widget = 'widget';
  static const emergencyContact = 'emergency_contact';
  static const backup = 'backup';
}

/// The platform answers [SetupChecklistService] needs, as functions so a test
/// can supply them without a device. Defaults ask the real services.
class SetupProbes {
  final bool isAndroid;
  final Future<bool> Function() notificationsOn;
  final Future<bool> Function() exactAlarmsOn;
  final Future<bool> Function() batteryUnrestricted;
  final Future<HealthAvailability> Function() healthAvailability;

  /// Whether the home-screen widget is on the home screen: true / false, or
  /// null when that cannot be told (not Android, or the launcher will not say),
  /// in which case the step is left out rather than guessed.
  final Future<bool?> Function() widgetPlaced;
  final bool Function() emergencyContactSet;
  final bool Function() backedUpRecently;

  final Future<void> Function() requestNotifications;
  final Future<void> Function() requestExactAlarms;
  final Future<void> Function() requestBatteryExemption;
  final Future<void> Function() requestHealth;
  final Future<void> Function() requestWidgetPin;

  const SetupProbes({
    required this.isAndroid,
    required this.notificationsOn,
    required this.exactAlarmsOn,
    required this.batteryUnrestricted,
    required this.healthAvailability,
    required this.widgetPlaced,
    required this.emergencyContactSet,
    required this.backedUpRecently,
    required this.requestNotifications,
    required this.requestExactAlarms,
    required this.requestBatteryExemption,
    required this.requestHealth,
    required this.requestWidgetPin,
  });

  factory SetupProbes.real() => SetupProbes(
        isAndroid: Platform.isAndroid,
        notificationsOn: () => NotificationService().areNotificationsEnabled(),
        exactAlarmsOn: () => NotificationService().canScheduleExactAlarms(),
        batteryUnrestricted: () =>
            BatteryOptimizationService().isIgnoringBatteryOptimizations(),
        healthAvailability: () => HealthDataService.instance.availability(),
        widgetPlaced: () async {
          if (!Platform.isAndroid) return null;
          final installed = await HomeWidget.getInstalledWidgets();
          return installed.any((w) =>
              (w.androidClassName ?? '').endsWith('StepsSleepWidgetProvider'));
        },
        emergencyContactSet: () => EmergencyContact.isSet,
        backedUpRecently: () => BackupRecord.isRecent(),
        requestNotifications: () async {
          await NotificationService().requestPermissionsIfNeeded();
          // A permanently denied permission shows no prompt, so the request
          // above is a silent no-op. Re-check and fall through to the page
          // where the user can flip it, the same fallback
          // NotificationPermissionBanner uses.
          if (!await NotificationService().areNotificationsEnabled()) {
            await openAppSettings();
          }
        },
        requestExactAlarms: () async {
          await NotificationService().requestExactAlarmPermission();
        },
        requestBatteryExemption: () async {
          await BatteryOptimizationService().requestDisableBatteryOptimization();
        },
        requestHealth: () async {
          await HealthDataService.instance.requestPermissions();
        },
        requestWidgetPin: () async {
          if (await HomeWidget.isRequestPinWidgetSupported() == true) {
            await HomeWidget.requestPinWidget(
                androidName: 'StepsSleepWidgetProvider');
          }
        },
      );
}

/// Live checks for the things that silently break reminders, each with the fix
/// behind one tap.
///
/// Every step is read from the platform at call time — nothing is stored — so
/// a user who fixes one in system settings and comes back sees it tick over.
/// Steps that cannot apply here (Android-only ones on iPhone, Health when the
/// platform has no health store) are left out rather than shown as done, so
/// "3 of 4" never counts something the user could not have done.
class SetupChecklistService {
  final SetupProbes probes;
  SetupChecklistService({SetupProbes? probes})
      : probes = probes ?? SetupProbes.real();

  Future<SetupChecklist> check() async {
    final steps = <SetupStep>[];

    final notifications = await _safe(probes.notificationsOn, fallback: true);
    steps.add(SetupStep(
      id: SetupStepId.notifications,
      title: 'Allow notifications',
      detail: 'Without this, no dose or reminder alert can reach you.',
      fixLabel: 'Allow',
      done: notifications,
    ));

    if (probes.isAndroid) {
      // Exact alarms and the battery exemption only matter once notifications
      // work, so don't ask for them first.
      steps.add(SetupStep(
        id: SetupStepId.exactAlarms,
        title: 'Allow exact alarms',
        detail: 'Otherwise Android may deliver reminders minutes late.',
        fixLabel: 'Allow',
        done: await _safe(probes.exactAlarmsOn, fallback: false),
      ));
      steps.add(SetupStep(
        id: SetupStepId.battery,
        title: 'Stop battery limits on reminders',
        detail: 'Some phones pause the app in the background and drop alarms.',
        fixLabel: 'Fix',
        done: await _safe(probes.batteryUnrestricted, fallback: false),
      ));
    }

    HealthAvailability health;
    try {
      health = await probes.healthAvailability();
    } catch (_) {
      health = HealthAvailability.unavailable;
    }
    if (health != HealthAvailability.unavailable) {
      steps.add(SetupStep(
        id: SetupStepId.health,
        title: probes.isAndroid ? 'Connect Health Connect' : 'Connect Apple Health',
        detail: 'Fills in steps, sleep and heart data without typing it.',
        fixLabel: 'Connect',
        done: health == HealthAvailability.available,
      ));
    }

    // The home-screen widget: only where the launcher can answer, and only
    // asked about once everything above is in place. A widget is a convenience,
    // not what makes a reminder arrive.
    final placed = await _safe3(probes.widgetPlaced);
    if (placed != null) {
      steps.add(SetupStep(
        id: SetupStepId.widget,
        title: 'Add the home-screen widget',
        detail: 'Water and steps at a glance, with a one-tap +250 ml.',
        fixLabel: 'Add',
        done: placed,
      ));
    }

    steps.add(SetupStep(
      id: SetupStepId.emergencyContact,
      title: 'Add an emergency contact',
      detail: 'Someone to reach if a reading or a dose goes badly.',
      fixLabel: 'Add',
      done: probes.emergencyContactSet(),
    ));
    steps.add(SetupStep(
      id: SetupStepId.backup,
      title: 'Make a backup',
      detail: 'Your data lives only on this phone until you do.',
      fixLabel: 'Back up',
      done: probes.backedUpRecently(),
    ));

    return SetupChecklist(steps);
  }

  /// Run the fix for [stepId]. Unknown ids do nothing.
  Future<void> fix(String stepId) {
    switch (stepId) {
      case SetupStepId.notifications:
        return probes.requestNotifications();
      case SetupStepId.exactAlarms:
        return probes.requestExactAlarms();
      case SetupStepId.battery:
        return probes.requestBatteryExemption();
      case SetupStepId.health:
        return probes.requestHealth();
      case SetupStepId.widget:
        return probes.requestWidgetPin();
      // The emergency contact and the backup are screens, not platform
      // requests: the card opens them (it has a BuildContext), then re-checks.
    }
    return Future.value();
  }

  Future<bool?> _safe3(Future<bool?> Function() probe) async {
    try {
      return await probe();
    } catch (_) {
      return null;
    }
  }

  Future<bool> _safe(Future<bool> Function() probe,
      {required bool fallback}) async {
    try {
      return await probe();
    } catch (_) {
      return fallback;
    }
  }
}
