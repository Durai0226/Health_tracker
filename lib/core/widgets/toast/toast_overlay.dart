import 'package:flutter/material.dart';
import 'premium_toast.dart';
import 'toast_theme.dart';

/// Toast entry data for managing active toasts
class _ToastEntry {
  final String id;
  final OverlayEntry overlayEntry;
  final DateTime createdAt;

  _ToastEntry({
    required this.id,
    required this.overlayEntry,
    required this.createdAt,
  });
}

/// Global toast overlay manager
/// Handles positioning, queueing, and stacking of toast notifications
class ToastOverlay {
  static ToastOverlay? _instance;
  static ToastOverlay get instance {
    _instance ??= ToastOverlay._();
    return _instance!;
  }

  ToastOverlay._();

  final List<_ToastEntry> _activeToasts = [];
  static const int _maxVisibleToasts = 3;
  static const double _toastSpacing = 8.0;
  
  OverlayState? _overlayState;
  
  /// Initialize the overlay with the navigator's overlay
  void init(BuildContext context) {
    _overlayState = Overlay.of(context);
  }

  /// Show a toast notification
  String show({
    required BuildContext context,
    required ToastType type,
    ToastFeature feature = ToastFeature.general,
    required String title,
    String? message,
    ToastAction? action,
    Duration? duration,
    bool showParticles = false,
    bool showProgress = true,
    IconData? customIcon,
    Color? customColor,
  }) {
    // Ensure overlay is initialized
    _overlayState ??= Overlay.of(context);
    
    if (_overlayState == null) {
      debugPrint('ToastOverlay: No overlay found in context');
      return '';
    }

    // Generate unique ID
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Remove oldest toast if we have too many
    if (_activeToasts.length >= _maxVisibleToasts) {
      _removeToast(_activeToasts.first.id);
    }

    // Create overlay entry
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) {
        final index = _activeToasts.indexWhere((e) => e.id == id);
        final topOffset = ToastTheme.topOffset + (index * (80 + _toastSpacing));
        
        return Positioned(
          top: topOffset,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: PremiumToast(
                  type: type,
                  feature: feature,
                  title: title,
                  message: message,
                  action: action,
                  autoDismissDuration: duration ?? ToastTheme.defaultAutoDismiss,
                  showParticles: showParticles,
                  showProgress: showProgress,
                  customIcon: customIcon,
                  customColor: customColor,
                  onDismiss: () => _removeToast(id),
                ),
              ),
            ),
          ),
        );
      },
    );

    // Add to active toasts
    _activeToasts.add(_ToastEntry(
      id: id,
      overlayEntry: overlayEntry,
      createdAt: DateTime.now(),
    ));

    // Insert into overlay
    _overlayState!.insert(overlayEntry);
    
    // Rebuild other toasts to update positions
    _rebuildAllToasts();

    return id;
  }

  /// Remove a specific toast by ID
  void _removeToast(String id) {
    final index = _activeToasts.indexWhere((e) => e.id == id);
    if (index != -1) {
      _activeToasts[index].overlayEntry.remove();
      _activeToasts.removeAt(index);
      _rebuildAllToasts();
    }
  }

  /// Manually dismiss a toast by ID
  void dismiss(String id) {
    _removeToast(id);
  }

  /// Dismiss all active toasts
  void dismissAll() {
    for (final entry in _activeToasts) {
      entry.overlayEntry.remove();
    }
    _activeToasts.clear();
  }

  /// Rebuild all toasts to update positions
  void _rebuildAllToasts() {
    for (final entry in _activeToasts) {
      entry.overlayEntry.markNeedsBuild();
    }
  }

  /// Check if any toasts are currently visible
  bool get hasActiveToasts => _activeToasts.isNotEmpty;

  /// Get the number of active toasts
  int get activeToastCount => _activeToasts.length;
}

/// Toast overlay widget wrapper
/// Wrap your MaterialApp's home with this to enable toast notifications
class ToastOverlayWrapper extends StatefulWidget {
  final Widget child;

  const ToastOverlayWrapper({
    super.key,
    required this.child,
  });

  @override
  State<ToastOverlayWrapper> createState() => _ToastOverlayWrapperState();
}

class _ToastOverlayWrapperState extends State<ToastOverlayWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ToastOverlay.instance.init(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Navigator observer to maintain overlay reference
class ToastNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (navigator?.overlay != null) {
      // Reinitialize overlay when navigator changes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigator?.context != null) {
          ToastOverlay.instance.init(navigator!.context);
        }
      });
    }
  }
}
