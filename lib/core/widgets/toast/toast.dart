/// The celebration toast used by Focus.
///
/// This is NOT the app's general toast kit — that is `showAppToast` /
/// `context.toastSuccess(...)` in `core/widgets/app/app_toast.dart`, which is
/// what every other feature uses and what new code should use. This overlay
/// system exists for one thing the flat kit deliberately does not do: the
/// particle/shimmer celebration Focus shows when a session completes.
///
/// It once carried eleven feature-specific variants (Aqua, Nunito, Finance,
/// Exam, Notes…), several for features this app does not have. Only
/// [FocusToast] was ever called, so the other ten were deleted; the header
/// above used to advertise them, which is why this note is explicit about the
/// boundary.
///
/// Usage:
/// ```dart
/// FocusToast.sessionComplete(context, minutes: 25);
///
/// // With an action
/// ToastService.show(
///   context,
///   type: ToastType.info,
///   title: 'Reminder',
///   message: 'Time for your medication',
///   action: ToastAction(
///     label: 'Take now',
///     onPressed: () => takeMedication(),
///   ),
/// );
/// ```

// Focus celebration toast library

// Core exports
export 'toast_theme.dart';
export 'toast_animations.dart';
export 'toast_particles.dart';
export 'premium_toast.dart';
export 'toast_overlay.dart';
export 'toast_service.dart';

// Feature-specific toasts
export 'feature_toasts/focus_toast.dart';

// Demo/Testing
