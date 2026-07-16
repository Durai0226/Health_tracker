import 'package:flutter/material.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../focus/screens/focus_screen.dart';
import '../../reminders/screens/reminders_screen.dart';
import 'home_dashboard.dart';
import 'health_hub_screen.dart';

/// The single persistent shell — one bottom nav, four destinations
/// (Home · Health · Focus · Reminders) over an [IndexedStack]. The selected
/// nav item glows in the active feature's accent; on Health it follows the
/// active Medicine/Water sub-tab.
class AppShell extends StatefulWidget {
  final int initialIndex;

  const AppShell({super.key, this.initialIndex = 0});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _currentIndex = widget.initialIndex;
  int _healthTab = 0;
  // Bumped each time Home is re-selected so the dashboard refreshes its
  // sync-only surfaces (reminders) on return — see HomeDashboard.refreshTick.
  int _homeTick = 0;
  final ValueNotifier<FeatureAccent> _healthAccent =
      ValueNotifier(FeatureAccent.medicine);

  void _goTo(int index, {int? healthTab}) {
    setState(() {
      if (index == 0 && _currentIndex != 0) _homeTick++;
      _currentIndex = index;
      if (index == 1 && healthTab != null) {
        _healthTab = healthTab;
        _healthAccent.value =
            healthTab == 1 ? FeatureAccent.water : FeatureAccent.medicine;
      }
    });
  }

  @override
  void dispose() {
    _healthAccent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final screens = [
      HomeDashboard(onNavigate: _goTo, refreshTick: _homeTick),
      HealthHubScreen(
        key: ValueKey('health_$_healthTab'),
        initialTab: _healthTab,
        onAccentChanged: (a) => _healthAccent.value = a,
        onTabChanged: (i) => _healthTab = i,
      ),
      const FocusScreen(),
      const RemindersScreen(),
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: ext.background,
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: ValueListenableBuilder<FeatureAccent>(
        valueListenable: _healthAccent,
        builder: (context, healthAcc, _) {
          return AppNavBar(
            currentIndex: _currentIndex,
            onTap: (i) => _goTo(i),
            items: [
              AppNavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Home',
                accent: ext.brand,
              ),
              AppNavItem(
                icon: Icons.favorite_outline_rounded,
                activeIcon: Icons.favorite_rounded,
                label: 'Health',
                accent: ext.accent(healthAcc),
              ),
              AppNavItem(
                icon: Icons.self_improvement_outlined,
                activeIcon: Icons.self_improvement_rounded,
                label: 'Focus',
                accent: ext.focus,
              ),
              AppNavItem(
                icon: Icons.notifications_outlined,
                activeIcon: Icons.notifications_rounded,
                label: 'Reminders',
                accent: ext.reminders,
              ),
            ],
          );
        },
      ),
    );
  }
}
