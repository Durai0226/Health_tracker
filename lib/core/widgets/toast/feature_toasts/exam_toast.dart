import 'package:flutter/material.dart';
import '../toast_service.dart';
import '../toast_theme.dart';
import '../premium_toast.dart';

/// Exam prep feature-specific toast notifications
class ExamToast {
  ExamToast._();

  /// Show study session logged toast
  static String studySessionLogged(BuildContext context, {
    required int minutes,
    String? subject,
  }) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.exam,
      title: '📚 Study Session Logged',
      message: subject != null 
          ? '$minutes min of $subject recorded'
          : '$minutes minutes of study recorded',
    );
  }

  /// Show study goal reached toast
  static String studyGoalReached(BuildContext context, {required int totalMinutes}) {
    return ToastService.show(
      context,
      type: ToastType.achievement,
      feature: ToastFeature.exam,
      title: '🎯 Daily Goal Reached!',
      message: 'You studied for ${totalMinutes} minutes today',
      showParticles: true,
    );
  }

  /// Show exam added toast
  static String examAdded(BuildContext context, {required String examName}) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.exam,
      title: 'Exam Added',
      message: '"$examName" added to your schedule',
    );
  }

  /// Show exam updated toast
  static String examUpdated(BuildContext context, {required String examName}) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.exam,
      title: 'Exam Updated',
      message: '"$examName" has been updated',
      duration: const Duration(seconds: 2),
    );
  }

  /// Show exam reminder toast
  static String examReminder(BuildContext context, {
    required String examName,
    required int daysLeft,
    ToastAction? action,
  }) {
    return ToastService.show(
      context,
      type: ToastType.reminder,
      feature: ToastFeature.exam,
      title: '📅 Exam Coming Up',
      message: '$examName in $daysLeft days',
      action: action ?? ToastAction(
        label: 'Study Now',
        onPressed: () {},
      ),
      duration: const Duration(seconds: 6),
    );
  }

  /// Show subject completed toast
  static String subjectCompleted(BuildContext context, {required String subjectName}) {
    return ToastService.show(
      context,
      type: ToastType.achievement,
      feature: ToastFeature.exam,
      title: '🧠 Subject Mastered!',
      message: 'You\'ve completed all topics in $subjectName',
      showParticles: true,
    );
  }

  /// Show topic marked complete toast
  static String topicComplete(BuildContext context, {required String topicName}) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.exam,
      title: '✓ Topic Complete',
      message: '"$topicName" marked as done',
    );
  }

  /// Show quiz completed toast
  static String quizCompleted(BuildContext context, {
    required int score,
    required int total,
  }) {
    final percentage = ((score / total) * 100).round();
    final isExcellent = percentage >= 80;
    
    return ToastService.show(
      context,
      type: isExcellent ? ToastType.achievement : ToastType.success,
      feature: ToastFeature.exam,
      title: isExcellent ? '🌟 Excellent Score!' : '📝 Quiz Complete',
      message: 'You scored $score/$total ($percentage%)',
      showParticles: isExcellent,
    );
  }

  /// Show study plan generated toast
  static String studyPlanGenerated(BuildContext context) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.exam,
      title: 'Study Plan Created',
      message: 'Your personalized study plan is ready',
      customIcon: Icons.auto_awesome_rounded,
    );
  }

  /// Show streak milestone toast
  static String studyStreak(BuildContext context, {required int days}) {
    return ToastService.show(
      context,
      type: ToastType.achievement,
      feature: ToastFeature.exam,
      title: '🔥 $days-Day Study Streak!',
      message: 'Consistency is the key to success',
      showParticles: true,
    );
  }

  /// Show notes saved toast
  static String notesSaved(BuildContext context, {String? subject}) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.exam,
      title: 'Notes Saved',
      message: subject != null ? '$subject notes updated' : 'Your notes have been saved',
      duration: const Duration(seconds: 2),
    );
  }

  /// Show flashcard created toast
  static String flashcardCreated(BuildContext context) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.exam,
      title: 'Flashcard Created',
      message: 'New flashcard added to your deck',
    );
  }

  /// Show error toast
  static String error(BuildContext context, {required String message}) {
    return ToastService.show(
      context,
      type: ToastType.error,
      feature: ToastFeature.exam,
      title: 'Error',
      message: message,
    );
  }
}
