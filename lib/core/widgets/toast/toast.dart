/// Premium Toast Notification System
/// 
/// A modern 2025/2026 toast notification system with:
/// - Glassmorphism effects with backdrop blur
/// - Feature-specific theming (Aqua, Nunito, Focus, Finance, etc.)
/// - Particle animations for celebrations
/// - Shimmer border effects
/// - Haptic feedback integration
/// - Swipe-to-dismiss gestures
/// - Auto-dismiss with progress indicator
/// 
/// Usage:
/// ```dart
/// // Basic usage
/// ToastService.success(context, title: 'Saved!', message: 'Your changes have been saved.');
/// 
/// // Feature-specific
/// AquaToast.hydrationLogged(context, amount: 250);
/// NunitoToast.medicationTaken(context, medicineName: 'Vitamin D');
/// FocusToast.sessionComplete(context, minutes: 25);
/// 
/// // With action
/// ToastService.show(
///   context,
///   type: ToastType.info,
///   title: 'Reminder',
///   message: 'Time for your medication',
///   action: ToastAction(
///     label: 'Take Now',
///     onPressed: () => takeMedication(),
///   ),
/// );
/// ```

// Premium Toast Notification System Library

// Core exports
export 'toast_theme.dart';
export 'toast_animations.dart';
export 'toast_particles.dart';
export 'premium_toast.dart';
export 'toast_overlay.dart';
export 'toast_service.dart';

// Feature-specific toasts
export 'feature_toasts/aqua_toast.dart';
export 'feature_toasts/nunito_toast.dart';
export 'feature_toasts/focus_toast.dart';
export 'feature_toasts/finance_toast.dart';
export 'feature_toasts/habit_toast.dart';
export 'feature_toasts/mood_toast.dart';
export 'feature_toasts/exam_toast.dart';
export 'feature_toasts/fitness_toast.dart';
export 'feature_toasts/notes_toast.dart';
export 'feature_toasts/period_toast.dart';
export 'feature_toasts/reminder_toast.dart';

// Demo/Testing
