import 'package:flutter/material.dart';
import 'toast.dart';

/// Demo screen to test and showcase the premium toast notification system
class ToastDemoScreen extends StatelessWidget {
  const ToastDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Toast Demo'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSection(
              title: 'Basic Toasts',
              children: [
                _buildDemoButton(
                  context,
                  label: 'Success Toast',
                  color: ToastTheme.successPrimary,
                  onPressed: () => ToastService.success(
                    context,
                    title: 'Success!',
                    message: 'Your action was completed successfully.',
                  ),
                ),
                _buildDemoButton(
                  context,
                  label: 'Error Toast',
                  color: ToastTheme.errorPrimary,
                  onPressed: () => ToastService.error(
                    context,
                    title: 'Error',
                    message: 'Something went wrong. Please try again.',
                  ),
                ),
                _buildDemoButton(
                  context,
                  label: 'Warning Toast',
                  color: ToastTheme.warningPrimary,
                  onPressed: () => ToastService.warning(
                    context,
                    title: 'Warning',
                    message: 'Please review your input before proceeding.',
                  ),
                ),
                _buildDemoButton(
                  context,
                  label: 'Info Toast',
                  color: ToastTheme.infoPrimary,
                  onPressed: () => ToastService.info(
                    context,
                    title: 'Information',
                    message: 'Here is some helpful information.',
                  ),
                ),
                _buildDemoButton(
                  context,
                  label: 'Achievement Toast ✨',
                  color: ToastTheme.achievementPrimary,
                  onPressed: () => ToastService.achievement(
                    context,
                    title: '🎉 Achievement Unlocked!',
                    message: 'You\'ve reached a new milestone!',
                  ),
                ),
                _buildDemoButton(
                  context,
                  label: 'Reminder Toast',
                  color: ToastTheme.infoPrimary,
                  onPressed: () => ToastService.reminder(
                    context,
                    title: '⏰ Reminder',
                    message: 'Don\'t forget your scheduled task.',
                    action: ToastAction(
                      label: 'View',
                      onPressed: () {},
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'Feature-Specific Toasts',
              children: [
                _buildDemoButton(
                  context,
                  label: '💧 Aqua (Water)',
                  color: ToastTheme.waterPrimary,
                  onPressed: () => AquaToast.hydrationLogged(
                    context,
                    amount: 250,
                    beverage: 'Water',
                  ),
                ),
                _buildDemoButton(
                  context,
                  label: '💊 Nunito (Medication)',
                  color: ToastTheme.medicationPrimary,
                  onPressed: () => NunitoToast.medicationTaken(
                    context,
                    medicineName: 'Vitamin D',
                  ),
                ),
                _buildDemoButton(
                  context,
                  label: '🎯 Focus',
                  color: ToastTheme.focusPrimary,
                  onPressed: () => FocusToast.sessionComplete(
                    context,
                    minutes: 25,
                  ),
                ),
                _buildDemoButton(
                  context,
                  label: '💰 Finance',
                  color: ToastTheme.financePrimary,
                  onPressed: () => FinanceToast.transactionAdded(
                    context,
                    type: 'Expense',
                    amount: 45.99,
                  ),
                ),
                _buildDemoButton(
                  context,
                  label: '🔄 Habit',
                  color: ToastTheme.habitPrimary,
                  onPressed: () => HabitToast.habitCompleted(
                    context,
                    habitName: 'Morning Workout',
                  ),
                ),
                _buildDemoButton(
                  context,
                  label: '😊 Mood',
                  color: ToastTheme.moodPrimary,
                  onPressed: () => MoodToast.moodLogged(
                    context,
                    moodLevel: 4,
                  ),
                ),
                _buildDemoButton(
                  context,
                  label: '📚 Exam',
                  color: ToastTheme.examPrimary,
                  onPressed: () => ExamToast.studySessionLogged(
                    context,
                    minutes: 45,
                    subject: 'Mathematics',
                  ),
                ),
                _buildDemoButton(
                  context,
                  label: '💪 Fitness',
                  color: ToastTheme.fitnessPrimary,
                  onPressed: () => FitnessToast.workoutCompleted(
                    context,
                    workoutName: 'HIIT',
                    calories: 350,
                  ),
                ),
                _buildDemoButton(
                  context,
                  label: '📝 Notes',
                  color: ToastTheme.notesPrimary,
                  onPressed: () => NotesToast.noteSaved(context),
                ),
                _buildDemoButton(
                  context,
                  label: '🌸 Period',
                  color: ToastTheme.periodPrimary,
                  onPressed: () => PeriodToast.periodLogged(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'Special Effects',
              children: [
                _buildDemoButton(
                  context,
                  label: '🎯 Goal Reached (Particles)',
                  color: ToastTheme.waterPrimary,
                  onPressed: () => AquaToast.goalReached(
                    context,
                    totalMl: 2500,
                  ),
                ),
                _buildDemoButton(
                  context,
                  label: '🔥 Streak Milestone',
                  color: ToastTheme.habitPrimary,
                  onPressed: () => HabitToast.streakMilestone(
                    context,
                    habitName: 'Exercise',
                    days: 30,
                  ),
                ),
                _buildDemoButton(
                  context,
                  label: '🏆 Perfect Score',
                  color: ToastTheme.examPrimary,
                  onPressed: () => ExamToast.quizCompleted(
                    context,
                    score: 10,
                    total: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'Actions',
              children: [
                _buildDemoButton(
                  context,
                  label: 'Dismiss All Toasts',
                  color: Colors.grey,
                  onPressed: () => ToastService.dismissAll(),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: children,
        ),
      ],
    );
  }

  Widget _buildDemoButton(
    BuildContext context, {
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(label),
    );
  }
}
