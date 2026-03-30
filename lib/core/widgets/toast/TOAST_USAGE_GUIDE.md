# Premium Toast Notification System

A modern 2025/2026 push notification toast system with glassmorphism, particle animations, and feature-specific theming.

## Quick Start

### 1. Import the toast system
```dart
import 'package:volt/core/widgets/toast/toast.dart';
```

### 2. Basic Usage
```dart
// Success toast
ToastService.success(context, title: 'Saved!', message: 'Your changes have been saved.');

// Error toast
ToastService.error(context, title: 'Error', message: 'Something went wrong.');

// Warning toast
ToastService.warning(context, title: 'Warning', message: 'Please check your input.');

// Info toast
ToastService.info(context, title: 'Info', message: 'New updates available.');

// Achievement toast (with particles)
ToastService.achievement(context, title: '🎉 Goal Reached!', message: 'Congratulations!');

// Reminder toast
ToastService.reminder(context, title: 'Reminder', message: 'Don\'t forget!');
```

### 3. Feature-Specific Toasts

#### Water (Aqua)
```dart
AquaToast.hydrationLogged(context, amount: 250, beverage: 'Water');
AquaToast.goalReached(context, totalMl: 2500);
AquaToast.streakMilestone(context, days: 7);
AquaToast.reminder(context);
```

#### Medication (Nunito)
```dart
NunitoToast.medicationTaken(context, medicineName: 'Vitamin D');
NunitoToast.doseSkipped(context, medicineName: 'Aspirin', reason: 'Felt nauseous');
NunitoToast.reminder(context, medicineName: 'Medication', dosage: '500mg');
NunitoToast.perfectAdherence(context, days: 30);
```

#### Focus
```dart
FocusToast.sessionStarted(context, minutes: 25);
FocusToast.sessionComplete(context, minutes: 25);
FocusToast.plantUnlocked(context, plantName: 'Sunflower');
FocusToast.streak(context, days: 14);
```

#### Finance
```dart
FinanceToast.transactionAdded(context, type: 'Expense', amount: 45.99);
FinanceToast.budgetWarning(context, category: 'Food', percentUsed: 85);
FinanceToast.savingsGoalReached(context, goalName: 'Vacation Fund');
FinanceToast.billReminder(context, billName: 'Electricity', dueDate: 'Mar 28');
```

#### Habit
```dart
HabitToast.habitCompleted(context, habitName: 'Morning Workout');
HabitToast.streakMilestone(context, habitName: 'Reading', days: 30);
HabitToast.allHabitsCompleted(context);
HabitToast.challengeCompleted(context, challengeName: '30-Day Fitness');
```

#### Mood
```dart
MoodToast.moodLogged(context, moodLevel: 4); // 1-5 scale
MoodToast.journalSaved(context);
MoodToast.streakMilestone(context, days: 7);
MoodToast.affirmation(context, message: 'You are capable of great things!');
```

#### Exam Prep
```dart
ExamToast.studySessionLogged(context, minutes: 45, subject: 'Math');
ExamToast.quizCompleted(context, score: 8, total: 10);
ExamToast.examReminder(context, examName: 'Physics Final', daysLeft: 3);
ExamToast.studyStreak(context, days: 14);
```

#### Fitness
```dart
FitnessToast.workoutCompleted(context, workoutName: 'HIIT', calories: 350);
FitnessToast.personalRecord(context, achievement: 'New bench press PR: 100kg');
FitnessToast.streakMilestone(context, days: 30);
FitnessToast.stepsGoalReached(context, steps: 10000);
```

#### Notes
```dart
NotesToast.noteSaved(context);
NotesToast.noteDeleted(context, onUndo: () => restoreNote());
NotesToast.notesSynced(context, count: 5);
NotesToast.checklistToggled(context, completed: 5, total: 5);
```

#### Period Tracking
```dart
PeriodToast.periodLogged(context);
PeriodToast.periodPrediction(context, daysUntil: 5);
PeriodToast.fertileWindow(context, isStart: true);
PeriodToast.cycleInsights(context);
```

### 4. Toast with Actions
```dart
ToastService.show(
  context,
  type: ToastType.info,
  title: 'Reminder',
  message: 'Time for your medication',
  action: ToastAction(
    label: 'Take Now',
    onPressed: () {
      // Handle action
    },
  ),
);
```

### 5. Custom Toast
```dart
ToastService.show(
  context,
  type: ToastType.success,
  feature: ToastFeature.general,
  title: 'Custom Toast',
  message: 'With custom settings',
  customIcon: Icons.star,
  customColor: Colors.purple,
  duration: Duration(seconds: 5),
  showParticles: true,
  showProgress: true,
);
```

### 6. Context Extensions
```dart
// Quick access via context
context.showSuccessToast('Saved!', message: 'Changes saved');
context.showErrorToast('Error', message: 'Something failed');
context.showInfoToast('Info', message: 'New update available');
context.showAchievementToast('🎉 Goal!', message: 'You did it!');
```

### 7. Dismiss Toasts
```dart
// Dismiss specific toast by ID
final toastId = ToastService.success(context, title: 'Hello');
ToastService.dismiss(toastId);

// Dismiss all toasts
ToastService.dismissAll();
```

## Toast Types

| Type | Icon | Use Case |
|------|------|----------|
| `success` | ✓ | Actions completed successfully |
| `error` | ✗ | Failures and errors |
| `warning` | ⚠ | Caution needed |
| `info` | ℹ | General information |
| `achievement` | ★ | Milestones and rewards |
| `reminder` | 🔔 | Scheduled alerts |

## Features

| Feature | Colors | Particle Effect |
|---------|--------|-----------------|
| Water | Cyan blue | Rising bubbles |
| Medication | Deep purple | Soft glow |
| Focus | Violet | Floating rings |
| Finance | Emerald | Coin sparkles |
| Habit | Indigo | Fire/confetti |
| Mood | Dynamic | Mood aura |
| Exam | Amber | Knowledge sparkles |
| Fitness | Orange | Energy burst |
| Notes | Indigo | Sparkles |
| Period | Rose/Pink | Soft glow |

## Animation Details

- **Entry:** Slide from top + fade + scale (350ms, easeOutCubic)
- **Exit:** Slide up + fade (250ms, easeInCubic)
- **Shimmer:** Continuous border animation (2s loop)
- **Particles:** Physics-based movement (3s lifetime)
- **Icon pulse:** Scale bounce (800ms, elasticOut)
- **Progress bar:** Linear countdown with glow

## Interaction

- **Swipe up:** Dismiss toast
- **Tap:** Pause auto-dismiss
- **Hover (desktop):** Pause auto-dismiss
- **Action button:** Execute callback + dismiss

## Auto-dismiss Durations

| Type | Duration |
|------|----------|
| Success | 3 seconds |
| Error | 5 seconds |
| Warning | 4 seconds |
| Info | 4 seconds |
| Achievement | 5 seconds |
| Reminder | 6 seconds |
