import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../../features/sleep/models/sleep_session.dart';
import '../../features/sleep/services/sleep_service.dart';
import '../../features/steps/services/step_service.dart';

/// Pushes a glanceable snapshot (today's steps + last night's sleep) to an
/// Android home-screen widget via the `home_widget` plugin.
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

  static Future<void> pushSnapshot() async {
    try {
      final today = StepService.getTodayData();
      final night = SleepService.getLastNight();

      await HomeWidget.saveWidgetData<int>('steps', today.effectiveSteps);
      await HomeWidget.saveWidgetData<int>('stepGoal', today.goalSteps);
      await HomeWidget.saveWidgetData<int>(
          'stepPct', (today.progress * 100).round());
      await HomeWidget.saveWidgetData<String>(
        'sleep',
        night != null ? SleepSession.formatMinutes(night.asleepMinutes) : '—',
      );
      await HomeWidget.saveWidgetData<int>('sleepScore', night?.sleepScore ?? 0);

      await HomeWidget.updateWidget(androidName: _androidProvider);
    } catch (e) {
      // Expected until the native widget provider is installed on Android.
      debugPrint('⚠️ HomeWidget push skipped (no native widget yet): $e');
    }
  }
}
