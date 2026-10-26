import 'package:flutter/foundation.dart';
import 'package:quick_actions/quick_actions.dart';

import '../../features/medication/services/today_schedule_service.dart';
import '../../features/water/services/water_service.dart';
import '../utils/date_formats.dart';
import 'app_lock_service.dart';

/// What a launcher shortcut does when tapped.
enum AppShortcutKind { takeDose, logWater, logBloodPressure, startFocus }

/// A shortcut as shown on a long-press of the app icon.
@immutable
class AppShortcut {
  /// The opaque string the OS hands back on tap. For a dose it carries the
  /// exact slot (see [AppShortcutTarget.parse]).
  final String type;
  final String title;
  const AppShortcut(this.type, this.title);
}

/// A tapped shortcut's `type`, decoded.
@immutable
class AppShortcutTarget {
  final AppShortcutKind kind;
  final String? medicineId;
  final DateTime? scheduledTime;

  const AppShortcutTarget(this.kind, {this.medicineId, this.scheduledTime});

  static const _water = 'log_water';
  static const _bp = 'log_bp';
  static const _focus = 'start_focus';
  static const _dose = 'take_dose';

  static String forWater() => _water;
  static String forBloodPressure() => _bp;
  static String forFocus() => _focus;

  /// The dose slot is baked into the string, so a shortcut that outlives its
  /// dose (taken in the app, then the launcher menu is opened before the next
  /// refresh) still says WHICH dose it meant and can be checked before it
  /// writes anything.
  static String forDose(String medicineId, DateTime scheduledTime) =>
      '$_dose|$medicineId|${scheduledTime.toIso8601String()}';

  /// Decode [type], or null for anything this app did not create.
  static AppShortcutTarget? parse(String type) {
    switch (type) {
      case _water:
        return const AppShortcutTarget(AppShortcutKind.logWater);
      case _bp:
        return const AppShortcutTarget(AppShortcutKind.logBloodPressure);
      case _focus:
        return const AppShortcutTarget(AppShortcutKind.startFocus);
    }
    final parts = type.split('|');
    if (parts.length != 3 || parts.first != _dose) return null;
    final at = DateTime.tryParse(parts[2]);
    if (parts[1].isEmpty || at == null) return null;
    return AppShortcutTarget(AppShortcutKind.takeDose,
        medicineId: parts[1], scheduledTime: at);
  }
}

/// Long-press shortcuts on the app icon: Log water, Log blood pressure, Start
/// focus, and — only while one is due — "Take Metformin 8:00".
class AppShortcuts {
  const AppShortcuts._();

  /// A dose is offered from [dueWindowAhead] before its scheduled time until
  /// [dueWindowLate] after it. Beyond that the dashboard already calls the dose
  /// missed, and a launcher shortcut should not log one on a guess.
  static const Duration dueWindowAhead = Duration(hours: 1);
  static const Duration dueWindowLate = Duration(hours: 3);

  /// The dose a shortcut should offer at [now], or null.
  ///
  /// Earliest pending dose inside the window. Taken, skipped, pre-logged and
  /// missed slots never qualify.
  static ScheduledDose? dueDose(List<ScheduledDose> doses, DateTime now) {
    final due = doses.where((d) {
      if (d.isTaken || d.isSkipped || d.isPreLogged || d.isMissed) return false;
      final delta = d.scheduledTime.difference(now);
      return delta <= dueWindowAhead && delta >= -dueWindowLate;
    }).toList()
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    return due.isEmpty ? null : due.first;
  }

  /// The shortcut list, most useful first.
  ///
  /// [waterRestricted] drops Log water for the same reason the Quick Settings
  /// tile and the widget do: under a medical fluid limit one tap that adds
  /// 250 ml with no total in sight is not a convenience.
  ///
  /// [hideMedicineNames] is set while app lock is on: the launcher menu is
  /// readable without unlocking, so the medicine's name stays off it.
  static List<AppShortcut> plan({
    required List<ScheduledDose> doses,
    required DateTime now,
    required bool waterRestricted,
    required bool hideMedicineNames,
  }) {
    final out = <AppShortcut>[];
    final dose = dueDose(doses, now);
    if (dose != null) {
      final title = hideMedicineNames
          ? 'Take next dose'
          : 'Take ${dose.medicine.name} ${DateFormats.time.format(dose.scheduledTime)}';
      out.add(AppShortcut(
          AppShortcutTarget.forDose(dose.medicine.id, dose.scheduledTime),
          title));
    }
    if (!waterRestricted) {
      out.add(AppShortcut(AppShortcutTarget.forWater(), 'Log water'));
    }
    out.add(AppShortcut(
        AppShortcutTarget.forBloodPressure(), 'Log blood pressure'));
    out.add(AppShortcut(AppShortcutTarget.forFocus(), 'Start focus'));
    return out;
  }
}

/// Registers the shortcuts with the OS and routes taps back to the app.
class AppShortcutsService {
  AppShortcutsService({QuickActions quickActions = const QuickActions()})
      : _quickActions = quickActions;

  final QuickActions _quickActions;

  /// Start listening. [onTap] receives each tapped shortcut, including the one
  /// that cold-started the app.
  Future<void> init(void Function(AppShortcutTarget target) onTap) async {
    try {
      await _quickActions.initialize((type) {
        final target = AppShortcutTarget.parse(type);
        if (target != null) onTap(target);
      });
    } catch (e) {
      // No plugin on desktop and in widget tests; shortcuts are a convenience.
      debugPrint('AppShortcutsService.init skipped: $e');
    }
  }

  /// Rebuild the list from today's doses. Cheap enough for every pause.
  Future<void> refresh() async {
    try {
      final now = DateTime.now();
      final doses = await TodayScheduleService.getTodaysDoses(now);
      final items = AppShortcuts.plan(
        doses: doses,
        now: now,
        waterRestricted: WaterService.isFluidRestricted,
        hideMedicineNames: AppLockService().isLockEnabled,
      );
      await _quickActions.setShortcutItems([
        for (final s in items)
          ShortcutItem(type: s.type, localizedTitle: s.title),
      ]);
    } catch (e) {
      debugPrint('AppShortcutsService.refresh skipped: $e');
    }
  }
}
