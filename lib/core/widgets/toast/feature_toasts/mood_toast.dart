import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../toast_service.dart';
import '../toast_theme.dart';
import '../premium_toast.dart';

/// Mood tracking feature-specific toast notifications
class MoodToast {
  MoodToast._();

  // Mood-specific colors
  static const Color _greatColor = Color(0xFF4CAF50);
  static const Color _goodColor = Color(0xFF8BC34A);
  static const Color _okayColor = Color(0xFFFFEB3B);
  static const Color _badColor = Color(0xFFFF9800);
  static const Color _terribleColor = Color(0xFFE53935);

  /// Get color for mood level (1-5, where 5 is great)
  static Color _getMoodColor(int moodLevel) {
    switch (moodLevel) {
      case 5: return _greatColor;
      case 4: return _goodColor;
      case 3: return _okayColor;
      case 2: return _badColor;
      case 1: return _terribleColor;
      default: return _okayColor;
    }
  }

  /// Get emoji for mood level
  static String _getMoodEmoji(int moodLevel) {
    switch (moodLevel) {
      case 5: return '😄';
      case 4: return '🙂';
      case 3: return '😐';
      case 2: return '😕';
      case 1: return '😢';
      default: return '😐';
    }
  }

  /// Show mood logged toast
  static String moodLogged(BuildContext context, {required int moodLevel}) {
    final emoji = _getMoodEmoji(moodLevel);
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.mood,
      title: '$emoji Mood Logged',
      message: 'Your mood has been recorded',
      customColor: _getMoodColor(moodLevel),
      customIcon: Symbols.mood_rounded,
    );
  }

  /// Show journal saved toast
  static String journalSaved(BuildContext context) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.mood,
      title: '📝 Journal Saved',
      message: 'Your thoughts have been recorded',
    );
  }

  /// Show journal deleted toast
  static String journalDeleted(BuildContext context, {required VoidCallback onUndo}) {
    return ToastService.show(
      context,
      type: ToastType.info,
      feature: ToastFeature.mood,
      title: 'Entry Deleted',
      message: 'Journal entry has been removed',
      action: ToastAction(
        label: 'Undo',
        onPressed: onUndo,
      ),
    );
  }

  /// Show mood check-in reminder toast
  static String reminder(BuildContext context, {ToastAction? action}) {
    return ToastService.show(
      context,
      type: ToastType.reminder,
      feature: ToastFeature.mood,
      title: '💭 How are you feeling?',
      message: 'Take a moment to check in with yourself',
      action: action ?? ToastAction(
        label: 'Log Mood',
        onPressed: () {},
      ),
    );
  }

  /// Show streak milestone toast
  static String streakMilestone(BuildContext context, {required int days}) {
    return ToastService.show(
      context,
      type: ToastType.achievement,
      feature: ToastFeature.mood,
      title: '🔥 $days-Day Streak!',
      message: 'You\'ve been tracking your mood consistently',
      showParticles: true,
    );
  }

  /// Show insights ready toast
  static String insightsReady(BuildContext context) {
    return ToastService.show(
      context,
      type: ToastType.info,
      feature: ToastFeature.mood,
      title: '📊 Weekly Insights Ready',
      message: 'Check your mood patterns and trends',
      customIcon: Symbols.insights_rounded,
    );
  }

  /// Show activity added toast
  static String activityAdded(BuildContext context, {required String activityName}) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.mood,
      title: 'Activity Added',
      message: '"$activityName" saved to your entry',
      duration: const Duration(seconds: 2),
    );
  }

  /// Show positive affirmation toast
  static String affirmation(BuildContext context, {required String message}) {
    return ToastService.show(
      context,
      type: ToastType.info,
      feature: ToastFeature.mood,
      title: '✨ Daily Affirmation',
      message: message,
      customIcon: Symbols.auto_awesome_rounded,
      duration: const Duration(seconds: 5),
    );
  }

  /// Show error toast
  static String error(BuildContext context, {required String message}) {
    return ToastService.show(
      context,
      type: ToastType.error,
      feature: ToastFeature.mood,
      title: 'Error',
      message: message,
    );
  }
}
