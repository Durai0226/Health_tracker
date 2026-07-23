import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../focus/screens/focus_screen.dart';
import '../../reminders/screens/reminders_screen.dart';
import '../../medication/screens/nunito_medication_dashboard.dart';
import '../../insights/screens/insights_hub_screen.dart';
import 'home_dashboard.dart';
import 'health_browse_screen.dart';
import '../widgets/log_something_sheet.dart';

/// The single persistent shell — one bottom nav with a center action:
/// **Today · Meds · ➕ Log · Health · Insights** over an [IndexedStack].
///
/// The nav has 5 slots but only 4 are destinations; slot 2 ("Log") is an action
/// that opens the unified quick-log sheet and never becomes the selection. So
/// the selected slot is always one of {0,1,3,4} and maps to a stack child via
/// [_stackIndex]. Focus & Reminders are no longer tabs — they're reached from
/// Today (and the Log sheet).
class AppShell extends StatefulWidget {
  final int initialIndex;

  const AppShell({super.key, this.initialIndex = 0});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // Selected NAV SLOT (never 2 — that's the Log action).
  late int _slot = widget.initialIndex;
  // Bumped when Today is re-selected so it refreshes sync-only surfaces
  // (reminders) — see HomeDashboard.refreshTick.
  int _homeTick = 0;

  // Slots {0,1,3,4} → stack children {0,1,2,3}.
  int get _stackIndex => _slot < 2 ? _slot : _slot - 1;

  void _onTap(int slot) {
    if (slot == 2) {
      LogSomethingSheet.show(context);
      return;
    }
    setState(() {
      if (slot == 0 && _slot != 0) _homeTick++;
      _slot = slot;
    });
  }

  /// Translation shim for [HomeDashboard]'s legacy `onNavigate(index,{healthTab})`
  /// call sites (Batch 2 rewrites Today to call the new IA directly):
  /// meds → Meds tab; water → Health tab; focus/reminders → pushed screens.
  void _legacyNavigate(int index, {int? healthTab}) {
    if (index == 1) {
      setState(() => _slot = (healthTab == 1) ? 3 : 1);
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const AccentScope(
              feature: FeatureAccent.focus, child: FocusScreen()),
        ),
      );
    } else if (index == 3) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const RemindersScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final screens = [
      HomeDashboard(onNavigate: _legacyNavigate, refreshTick: _homeTick),
      const NunitoMedicationDashboard(),
      const HealthBrowseScreen(),
      const InsightsHubScreen(isRoot: true),
    ];

    return Scaffold(
      // Docked nav (not floating): keep the body ABOVE the nav so each tab's
      // FAB / bottom content isn't hidden behind the bar.
      extendBody: false,
      backgroundColor: ext.background,
      body: IndexedStack(index: _stackIndex, children: screens),
      bottomNavigationBar: AppNavBar(
        currentIndex: _slot,
        onTap: _onTap,
        items: [
          AppNavItem(
            icon: Symbols.today_rounded,
            activeIcon: Symbols.today_rounded,
            label: 'Today',
            accent: ext.brand,
          ),
          AppNavItem(
            icon: Symbols.medication_rounded,
            activeIcon: Symbols.medication_rounded,
            label: 'Meds',
            accent: ext.medicine,
          ),
          AppNavItem(
            icon: Symbols.add_rounded,
            activeIcon: Symbols.add_rounded,
            label: 'Log',
            accent: ext.brand,
            isAction: true,
          ),
          AppNavItem(
            icon: Symbols.favorite_rounded,
            activeIcon: Symbols.favorite_rounded,
            label: 'Health',
            accent: ext.water,
          ),
          AppNavItem(
            icon: Symbols.insights_rounded,
            activeIcon: Symbols.insights_rounded,
            label: 'Insights',
            accent: ext.brand,
          ),
        ],
      ),
    );
  }
}
