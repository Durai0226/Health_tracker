import 'package:flutter/material.dart';

import '../../../core/services/app_lock_service.dart';
import 'pin_entry_screen.dart';

/// Route name the medicine alarm screen is pushed under (see `main.dart`'s
/// `routes` map and `NotificationService`'s `pushNamed` call) — kept here as
/// the single place [AppLockGate] and [AppLockRouteObserver] agree on it.
const String kAlarmRouteName = '/alarm';

/// Tracks the current top route's name so [AppLockGate] can suppress its
/// overlay while an alarm is showing — a medicine alarm must stay instantly
/// actionable, never buried behind a PIN prompt. Register one instance on
/// `MaterialApp.navigatorObservers`.
class AppLockRouteObserver extends NavigatorObserver {
  final ValueNotifier<String?> currentRouteName = ValueNotifier<String?>(null);

  void _update(Route<dynamic>? route) {
    currentRouteName.value = route?.settings.name;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _update(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _update(previousRoute);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _update(previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _update(newRoute);
}

/// The single [AppLockRouteObserver] instance shared between the
/// `MaterialApp.navigatorObservers` registration in `main.dart` and
/// [AppLockGate].
final AppLockRouteObserver appLockRouteObserver = AppLockRouteObserver();

/// Wraps the whole app in a `Stack` and overlays a full-screen
/// [PinEntryScreen] whenever [AppLockService.isLockedNotifier] is true —
/// except while the top route is the medicine alarm screen
/// ([kAlarmRouteName]), which must never be obscured by a PIN prompt.
///
/// Intended for `MaterialApp.builder`, wrapping the `child` it's given (the
/// app's own `Navigator`) rather than being placed inside a route — that is
/// what lets one overlay sit above EVERY screen without having to thread
/// itself into each route individually.
class AppLockGate extends StatelessWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final service = AppLockService();
    return ValueListenableBuilder<bool>(
      valueListenable: service.isLockedNotifier,
      builder: (context, isLocked, _) {
        if (!isLocked) return child;
        return ValueListenableBuilder<String?>(
          valueListenable: appLockRouteObserver.currentRouteName,
          builder: (context, routeName, __) {
            final suppressed = routeName == kAlarmRouteName;
            return Stack(
              children: [
                child,
                // A nested Navigator (rather than the bare PinEntryScreen)
                // because this overlay sits BESIDE the app's own Navigator in
                // this Stack, not inside it — without one, anything the PIN
                // screen pushes via `Navigator.of(context)` (critically, the
                // "Forgot PIN?" confirmation sheet) would throw for lack of an
                // ancestor Navigator, right on the one escape hatch this
                // feature exists to guarantee.
                if (!suppressed)
                  Positioned.fill(
                    child: Navigator(
                      onGenerateRoute: (_) => MaterialPageRoute<void>(
                        builder: (_) =>
                            const PinEntryScreen(mode: PinEntryMode.unlock),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
