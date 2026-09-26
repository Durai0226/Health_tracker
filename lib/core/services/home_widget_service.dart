import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../../features/sleep/models/sleep_session.dart';
import '../../features/sleep/services/sleep_service.dart';
import '../../features/steps/services/step_service.dart';
import '../../features/water/services/water_service.dart';
import 'water_action_queue.dart';

/// Entry point for taps on the widget's "+250" button.
///
/// Runs in a **background Flutter isolate** started by
/// `HomeWidgetBackgroundReceiver` — no Drift, no app state. So, exactly like
/// the notification action, it only records the intent; `AppShell` drains it
/// into a real log on the next resume.
///
/// Must be top-level and annotated, or the isolate cannot find it.
@pragma('vm:entry-point')
Future<void> homeWidgetBackgroundCallback(Uri? uri) async {
  if (uri == null) return;
  if (uri.host != 'water' || !uri.path.startsWith('/log')) return;
  final ml = int.tryParse(uri.queryParameters['ml'] ?? '') ??
      WaterActionQueue.defaultQuickAddMl;
  await WaterActionQueue.enqueue(amountMl: ml, at: DateTime.now());
}

/// Pushes a glanceable snapshot (today's steps, water and last night's sleep)
/// to an Android home-screen widget via the `home_widget` plugin.
///
/// This is the Dart half of the home-widget feature (#17): it stores the data
/// and requests a redraw. It is a **safe no-op until the native Android widget
/// provider is installed** (a receiver + layout + manifest entry), so calling
/// it before that ships does no harm. All data stays on-device (the widget
/// renders locally); nothing leaves the phone.
class HomeWidgetService {
  HomeWidgetService._();

  /// Simple class name of the Android [AppWidgetProvider] to refresh.
  static const _androidProvider = 'StepsSleepWidgetProvider';

  /// WidgetKit `kind` of the iOS widget, matching `WaterWidget.swift`.
  static const _iosWidgetName = 'WaterWidget';

  /// App Group shared between Runner and the WaterWidget extension.
  ///
  /// On iOS an extension has its own container, so nothing is shared until both
  /// targets carry this group and the plugin is told to use it. Must match
  /// `appGroupId` in `ios/WaterWidget/WaterWidget.swift` and the
  /// `com.apple.security.application-groups` entries in both entitlements files.
  static const _appGroupId =
      'group.com.implementation.tabletremainder.tabletRemainder';

  /// Key the iOS widget's quick-add writes into. Mirrors
  /// `LogWaterIntent.queueKey`.
  static const _iosQueueKey = 'widgetWaterQueue';

  /// Register the tap handler and the App Group. Call once at start-up.
  static Future<void> init() async {
    try {
      if (Platform.isIOS) {
        await HomeWidget.setAppGroupId(_appGroupId);
      }
      await HomeWidget.registerInteractivityCallback(
          homeWidgetBackgroundCallback);
    } catch (e) {
      debugPrint('⚠️ HomeWidget interactivity registration skipped: $e');
    }
  }

  /// Move any taps the iOS widget recorded into [WaterActionQueue].
  ///
  /// Android goes through a background isolate, so its taps are already queued
  /// by the time the app runs. iOS App Intents cannot start a Flutter isolate,
  /// so the extension writes into the shared App Group and this is where it gets
  /// picked up — the two platforms converge on one queue, and therefore on one
  /// drain, one confirmation and one Undo.
  ///
  /// Records are newline-separated `"<ml>@<iso8601>"`.
  static Future<void> drainIosWidgetQueue() async {
    if (!Platform.isIOS) return;
    try {
      final raw = await HomeWidget.getWidgetData<String>(_iosQueueKey);
      if (raw == null || raw.isEmpty) return;
      // Clear FIRST: a failure part-way through must not re-log every tap on
      // the next resume. Losing one tap beats silently duplicating them.
      await HomeWidget.saveWidgetData<String>(_iosQueueKey, '');

      for (final line in raw.split('\n')) {
        final parts = line.split('@');
        if (parts.length != 2) continue;
        final ml = int.tryParse(parts[0]);
        // `ISO8601DateFormatter()` in the extension always emits Zulu, and the
        // day a drink is filed under is read off `.year/.month/.day`. Kept as
        // UTC, a +250 tapped at 02:00 in Asia/Kolkata landed on YESTERDAY's
        // row — yesterday's goal, a 20:30 timeline entry, today's dial at 0.
        final at = DateTime.tryParse(parts[1])?.toLocal();
        if (ml == null || ml <= 0 || at == null) continue;
        await WaterActionQueue.enqueue(amountMl: ml, at: at);
      }
    } catch (e) {
      debugPrint('⚠️ iOS widget queue drain failed: $e');
    }
  }

  /// The calendar day the values below describe, as `yyyy-MM-dd`.
  ///
  /// The widget has no clock of its own and this only runs while the app is
  /// open, so without a stamp yesterday's 9,412 steps kept being drawn as
  /// today's — most visibly first thing in the morning, before the app has been
  /// opened at all. The native provider compares this against the current date
  /// and blanks the values when they disagree.
  static const snapshotDayKey = 'snapshotDay';

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static Future<void> pushSnapshot() async {
    try {
      final today = StepService.getTodayData();
      final night = SleepService.getLastNight();

      await HomeWidget.saveWidgetData<String>(
          snapshotDayKey, _dayKey(clock.now()));
      await HomeWidget.saveWidgetData<int>('steps', today.effectiveSteps);
      await HomeWidget.saveWidgetData<int>('stepGoal', today.goalSteps);
      await HomeWidget.saveWidgetData<int>(
          'stepPct', (today.progress * 100).round());
      await HomeWidget.saveWidgetData<String>(
        'sleep',
        night != null ? SleepSession.formatMinutes(night.asleepMinutes) : '—',
      );
      await HomeWidget.saveWidgetData<int>('sleepScore', night?.sleepScore ?? 0);

      // Water. Absent from this widget until now, which meant the one metric
      // people most want to log from the home screen was the one metric the
      // home screen could not show.
      final water = WaterService.getDataForDate(clock.now());
      final restricted = WaterService.isFluidRestricted;
      final goal = water?.dailyGoalMl ?? WaterService.getDailyGoal();
      // Under a restriction the meaningful number is raw volume against the
      // ceiling; otherwise it is hydration-adjusted intake against the target.
      final intake = restricted
          ? (water?.totalIntakeMl ?? 0)
          : (water?.effectiveHydrationMl ?? 0);
      await HomeWidget.saveWidgetData<int>('waterMl', intake);
      await HomeWidget.saveWidgetData<int>('waterGoalMl', goal);
      await HomeWidget.saveWidgetData<int>(
          'waterPct', goal > 0 ? (intake / goal * 100).round().clamp(0, 100) : 0);
      await HomeWidget.saveWidgetData<bool>('waterRestricted', restricted);

      await HomeWidget.updateWidget(
        androidName: _androidProvider,
        iOSName: _iosWidgetName,
      );
    } catch (e) {
      // Expected until the native widget provider is installed on Android.
      debugPrint('⚠️ HomeWidget push skipped (no native widget yet): $e');
    }
  }
}
