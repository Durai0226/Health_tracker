import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../medication/services/medicine_storage_service.dart';
import '../../focus/screens/focus_screen.dart';
import '../../reminders/screens/reminders_screen.dart';
import '../../medication/screens/nunito_medication_dashboard.dart';
import '../../insights/screens/trends_dashboard_screen.dart';
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

  const AppShell({super.key, this.initialIndex = 0})
      : assert(initialIndex >= 0 && initialIndex <= 4,
            'initialIndex must be a nav slot 0-4'),
        assert(initialIndex != 2,
            'slot 2 is the Log action, not a destination — it never becomes '
            'the selection, so it cannot be an initial tab');

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  // Selected NAV SLOT (never 2 — that's the Log action).
  late int _slot = widget.initialIndex;
  // Bumped when Today is re-selected so it refreshes sync-only surfaces
  // (reminders) — see HomeDashboard.refreshTick.
  int _homeTick = 0;

  /// One [ScrollController] per tab.
  ///
  /// This is load-bearing, not tidiness. `ModalRoute` wraps a route's content in
  /// exactly ONE [PrimaryScrollController], and any vertical `ScrollView` with no
  /// explicit controller silently attaches to it. Because [IndexedStack] keeps
  /// every tab alive simultaneously, Today, Health and Insights were all
  /// attaching their scroll views to that single controller at the same time.
  ///
  /// A controller driving three positions at once reports and corrects the wrong
  /// one, which is exactly what the two reported bugs were: skipping a dose on
  /// Today shrank the content, the offset correction landed on another tab's
  /// position, and Today was left unable to scroll — plus visible jumping when
  /// switching tabs. Giving each tab its own controller makes the offsets
  /// independent, and keeps per-tab scroll-to-top working.
  late final List<ScrollController> _tabScrollControllers =
      List<ScrollController>.generate(_tabCount, (_) => ScrollController());

  static const int _tabCount = 4;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    for (final c in _tabScrollControllers) {
      c.dispose();
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// A Take/Skip tapped on a notification is handled in a background isolate that
  /// can't reach Drift, so it lands in the dose-action queue instead. Draining it
  /// here (rather than only inside a screen's own load) means the dose appears the
  /// moment the user comes back, not after they navigate or pull-to-refresh.
  /// Every affected surface listens to `revision`, which the drain's writes bump.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _drainQueuedDoseActions();
  }

  Future<void> _drainQueuedDoseActions() async {
    List<String> ids;
    try {
      ids = await MedicineCleanStorageService.drainPendingDoseActions();
    } catch (e) {
      debugPrint('⚠️ Draining queued dose actions on resume failed: $e');
      return;
    }
    if (ids.isEmpty || !mounted) return;

    // Confirm what we applied on the user's behalf, with a way back — logging a
    // dose silently from a notification tap is not something to leave unsaid.
    final n = ids.length;
    context.toastSuccess(
      'Logged $n dose${n == 1 ? '' : 's'} from your reminder',
      action: AppToastAction(
        label: 'Undo',
        onPressed: () async {
          for (final id in ids) {
            // Put the units back before deleting, or Undo loses inventory.
            final log = await MedicineCleanStorageService.getLog(id);
            if (log != null && log.countsAsTaken) {
              await MedicineCleanStorageService.restoreStock(
                  log.medicineId, log.dosageTaken);
            }
            await MedicineCleanStorageService.deleteLog(id);
          }
        },
      ),
    );
  }

  // Slots {0,1,3,4} → stack children {0,1,2,3}.
  static int _stackIndexOf(int slot) => slot < 2 ? slot : slot - 1;
  int get _stackIndex => _stackIndexOf(_slot);

  /// Stack indices that have ever been selected.
  ///
  /// `IndexedStack` BUILDS AND KEEPS ALIVE every child — it only controls which
  /// one paints. So landing on Today also ran the Medication dashboard's full
  /// load (which additionally WRITES: it drains queued dose actions and
  /// reconciles missed doses), the Trends bundle (which awaits four service
  /// inits then four range queries), and the Health hub's tree — none of it
  /// visible, all of it on the critical path to first interaction.
  ///
  /// Deferring FIRST MOUNT only. Once a tab has been opened it stays alive for
  /// the session, which is what the per-tab `PrimaryScrollController` design
  /// depends on, so scroll positions and state behave exactly as before.
  ///
  /// Seeded from [AppShell.initialIndex], NOT hardcoded to Today. It was `{0}`,
  /// which shipped a blank first screen to every brand-new user: onboarding
  /// finishes into `AppShell(initialIndex: 1)`, whose `_stackIndex` is 1, and
  /// the `IndexedStack` below renders `SizedBox.shrink()` for any index this
  /// set does not contain. The lazy-mount optimisation and a non-zero initial
  /// tab were each correct alone and silently cancelled each other out.
  late final Set<int> _mounted = {_stackIndexOf(widget.initialIndex)};

  void _onTap(int slot) {
    if (slot == 2) {
      LogSomethingSheet.show(context);
      return;
    }
    setState(() {
      if (slot == 0 && _slot != 0) _homeTick++;
      _slot = slot;
      _mounted.add(slot < 2 ? slot : slot - 1);
    });
  }

  /// Translation shim for [HomeDashboard]'s legacy `onNavigate(index,{healthTab})`
  /// call sites (Batch 2 rewrites Today to call the new IA directly):
  /// meds → Meds tab; water → Health tab; focus/reminders → pushed screens.
  void _legacyNavigate(int index, {int? healthTab}) {
    if (index == 1) {
      setState(() {
        _slot = (healthTab == 1) ? 3 : 1;
        _mounted.add(_slot < 2 ? _slot : _slot - 1);
      });
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
      HealthBrowseScreen(onOpenTrends: () => _onTap(4)),
      const TrendsDashboardScreen(isRoot: true),
    ];
    // Adding a tab without a matching controller would silently reintroduce the
    // shared-controller bug for the new tab only — fail loudly instead.
    assert(screens.length == _tabCount,
        'Add a ScrollController for every tab: ${screens.length} tabs vs $_tabCount controllers');

    return Scaffold(
      // Docked nav (not floating): keep the body ABOVE the nav so each tab's
      // FAB / bottom content isn't hidden behind the bar.
      extendBody: false,
      backgroundColor: ext.background,
      // Each tab gets its own PrimaryScrollController so the four live children
      // never share one scroll position. See [_tabScrollControllers].
      body: IndexedStack(
        index: _stackIndex,
        children: [
          for (var i = 0; i < screens.length; i++)
            if (_mounted.contains(i))
              PrimaryScrollController(
                controller: _tabScrollControllers[i],
                child: screens[i],
              )
            else
              const SizedBox.shrink(),
        ],
      ),
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
            icon: Symbols.bar_chart_rounded,
            activeIcon: Symbols.bar_chart_rounded,
            label: 'Trends',
            accent: ext.brand,
          ),
        ],
      ),
    );
  }
}
