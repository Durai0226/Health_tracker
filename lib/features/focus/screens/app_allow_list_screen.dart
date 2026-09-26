import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import '../../../core/services/clean_storage_service.dart';
import '../../../core/services/haptic_service.dart';
import '../services/focus_service.dart';
import '../models/app_allow_list.dart';

class AppAllowListScreen extends StatefulWidget {
  const AppAllowListScreen({super.key});

  @override
  State<AppAllowListScreen> createState() => _AppAllowListScreenState();
}

class _AppAllowListScreenState extends State<AppAllowListScreen> {
  AppAllowList _allowList = const AppAllowList();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = CleanStorageService.getAppPreferences();
    final allowListJson = prefs['focusAppAllowList'];
    if (allowListJson != null && allowListJson is Map) {
      setState(() {
        _allowList = AppAllowList.fromJson(Map<String, dynamic>.from(allowListJson));
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveData() async {
    await CleanStorageService.setAppPreference('focusAppAllowList', _allowList.toJson());
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    // Same conversion as custom_tags_screen: a flat pinned SliverAppBar with a
    // boxed 20pt arrow and a raw bold `TextStyle`, replaced by a fixed
    // AppHeader above the sliver body.
    return AppScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppHeader(
            title: 'Distractions',
            leading: AppHeader.backButton(context),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _buildSettingsCard(),
                            const SizedBox(height: AppSpacing.xl),
                            _buildAllowedAppsSection(),
                            // Was a magic SizedBox(height: 100) — the tab-root
                            // constant on a pushed screen, and it never added
                            // the gesture-bar inset.
                            SizedBox(height: AppInsets.pushed(context)),
                          ]),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
      // AppFab, not a raw FloatingActionButton.extended. The raw one re-declared
      // the fill pair by hand and lost what AppFab owns: `heroTag: null` (this
      // shell keeps several FAB screens alive in an IndexedStack, and a shared
      // tag throws "multiple heroes share the same tag" on a push), the brLg
      // shape, labelLarge text, and the medium-impact haptic. The accent is the
      // FEATURE's — brand teal on a Focus screen is the one colour AccentScope
      // exists to prevent.
      floatingActionButton: AppFab(
        icon: Symbols.add_rounded,
        label: 'Add app',
        accent: ext.focus,
        onPressed: _showAddAppDialog,
      ),
    );
  }

  Widget _buildSettingsCard() {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      decoration: BoxDecoration(
        color: ext.surface,
        borderRadius: AppRadius.brSheet,
        // `AppShadows.card` rather than a hand-rolled BoxShadow through the
        // shim's `getCardShadow` — the design system already owns the resting,
        // card and elevated tiers, and this was the last call into that shim
        // anywhere in the app.
        boxShadow: AppShadows.card(context),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ext.focus.container,
              borderRadius: AppRadius.brMd,
            ),
            child: Icon(Symbols.info_rounded,
                color: ext.focus.onContainer, size: 20),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('This is your own list', style: tt.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'DlyMinder does not block or monitor other apps. Writing down '
                  'what pulls you away makes it easier to notice when it happens '
                  '— and your session only ends when you tap Give Up.',
                  style: tt.bodySmall?.copyWith(
                    height: 1.4,
                    color: ext.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // The "Quick Add Presets" strip lived here and is gone.
  //
  // It offered to bulk-add Notion, Todoist, Duolingo, Khan Academy and Spotify
  // — `PresetAllowList`, a vestige of when this screen was an ALLOW list of apps
  // you were permitted to open. The screen now says, in its own settings card,
  // that it is a list of what pulls you away. A one-tap button that files Khan
  // Academy under distractions contradicts the sentence directly above it, and
  // it seeds the list with six apps the user never named — which is the
  // opposite of the noticing this screen is for. `PresetAllowList` itself is in
  // `models/` and is left alone; nothing renders it now.

  Widget _buildAllowedAppsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Both children are Flexible with a one-line clamp. Unconstrained, this
        // `spaceBetween` Row overflowed by 28px at 320pt — a pre-existing defect
        // that only surfaced once the settings card above it got shorter: the
        // SliverList had never laid this header out, because it sat below the
        // fold behind four switches. A lazily-built list hides overflow until
        // something above it shrinks.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'Your list',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Flexible(
              child: Text(
                '${_allowList.apps.length} listed',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColorsExt.of(context).textSecondary,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_allowList.apps.isEmpty)
          // Was a hand-rolled card reading 'No apps added yet' with nothing to
          // tap, on a screen whose entire purpose is adding things. Unlike the
          // garden and the stats chart, the way forward here is on this screen,
          // so the action opens the add dialog directly.
          Container(
            decoration: BoxDecoration(
              color: AppColorsExt.of(context).surface,
              borderRadius: AppRadius.brCard,
            ),
            child: EmptyState(
              icon: Symbols.phone_iphone_rounded,
              title: 'Name what pulls you away',
              message: 'Listing a distraction is how you start noticing it '
                  'sooner.',
              action: AppButton(
                label: 'Add a distraction',
                leadingIcon: Symbols.add_rounded,
                onPressed: _showAddAppDialog,
              ),
            ),
          )
        else
          ...List.generate(
            _allowList.apps.length,
            (index) => _buildAppCard(_allowList.apps[index], index),
          ),
      ],
    );
  }

  /// Whether a focus session is running right now.
  ///
  /// Changes what this screen is FOR. At rest it is a list you curate; during a
  /// session it is a tally you tap. Same list, and still no monitoring of any
  /// kind — the user is the sensor.
  bool get _sessionRunning => FocusService().isRunning;

  /// Log that this distraction pulled at the user, and go back to the ring.
  ///
  /// The tap is the intervention, not the data. Naming what just pulled you away
  /// is the interposed pause the friction research credits, and it is the one
  /// version of that available on a platform where real blocking is a dead end.
  /// The timestamps then answer a question a usage report cannot: not "you were
  /// distracted 14% of the time" but "this one, nine times, mostly early".
  void _logDistraction(AllowedApp app) {
    HapticService().selection();
    FocusService().logDistraction(app.id);
    context.toastSuccess('Noted — ${app.name}');
    Navigator.of(context).maybePop();
  }

  Widget _buildAppCard(AllowedApp app, int index) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final logging = _sessionRunning;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: ext.surface,
        borderRadius: AppRadius.brLg,
      ),
      // The whole row is tappable only WHILE a session is running, when tapping
      // it is the tally. At rest it wrapped an InkWell with a null onTap, which
      // is a row that ripples nowhere: it looks tappable, is tapped, and does
      // nothing. Off-session the row is a list item with its own delete button,
      // so it simply is not a tappable.
      child: _RowShell(
        tappable: logging,
        onTap: () => _logDistraction(app),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: app.category.color.withOpacity(0.1),
              borderRadius: AppRadius.brMd,
            ),
            child: Center(
              // emoji-content-ok: one glyph per category, and the add sheet's
              // picker shows the same one beside the name the user chose
              child: Text(app.category.emoji, style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(app.name, style: tt.titleSmall),
                // The category name reads in a text token, not `category.color`
                // — that palette includes #FF9800 (2.11:1) and #CDDC39-class
                // hues, and it is already carrying the badge tint beside it.
                Text(
                  app.category.name,
                  style: tt.bodySmall?.copyWith(color: ext.textSecondary),
                ),
              ],
            ),
          ),
          // Mid-session the controls give way to the tally affordance. Editing
          // the list is not the mid-session need, and leaving a destructive
          // icon-only button next to the thing the user is meant to be tapping
          // quickly is how an accidental delete happens.
          if (logging)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'Pulled me away',
                    maxLines: 2,
                    style: tt.labelMedium?.copyWith(color: ext.textSecondary),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(Symbols.add_circle_rounded,
                    size: 20, color: ext.textSecondary),
              ],
            )
          else ...[
            // The `isAllowed` switch that sat here is gone.
            //
            // Nothing read it. `AppAllowList.allowedApps` / `blockedApps` are
            // the only consumers of the flag and neither getter has a caller
            // anywhere in `lib/`, so toggling it changed a persisted boolean and
            // nothing else — on a screen that says in its own words that the app
            // does not block anything. A control that looks like it governs
            // whether an app is permitted, on a screen that cannot permit or
            // forbid anything, is worse than no control. The field stays on the
            // model (it is in persisted JSON); it is simply not offered.
            IconButton(
              // Destructive and icon-only: announced as just "button" without
              // this. The a11y sweep never saw it because a fresh install has no
              // apps, so this row only exists once the user has added one.
              tooltip: 'Remove',
              onPressed: () {
                setState(() {
                  final updatedApps = List<AllowedApp>.from(_allowList.apps)
                    ..removeAt(index);
                  _allowList = _allowList.copyWith(apps: updatedApps);
                });
                _saveData();
              },
              icon: Icon(Symbols.delete_rounded, color: ext.mark(ext.error)),
            ),
          ],
            ],
          ),
        ),
      ),
    );
  }

  /// Add-a-distraction sheet, routed through [AppBottomSheet].
  ///
  /// The hand-rolled version set `backgroundColor: transparent`, drew its own
  /// 28pt top corners (the theme's `topSheet` is 24) and its own grab handle in
  /// `Colors.grey.shade300` — **1.32:1** on the light surface, i.e. invisible,
  /// and a bright bar on the dark one. AppBottomSheet already owns the handle
  /// (`dragHandleColor`), the radius, the keyboard inset and the Material that
  /// lets rows ink.
  void _showAddAppDialog() {
    final nameController = TextEditingController();
    AppCategory selectedCategory = AppCategory.productivity;

    AppBottomSheet.show(
      context,
      title: 'Add a distraction',
      icon: Symbols.phone_iphone_rounded,
      accent: AppColorsExt.of(context).focus,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setModalState) {
          final ext = AppColorsExt.of(sheetContext);
          final tt = Theme.of(sheetContext).textTheme;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'App Name',
                  hintText: 'e.g., Spotify',
                  border: OutlineInputBorder(borderRadius: AppRadius.brMd),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Category', style: tt.titleSmall),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: AppCategory.values.map((category) {
                  final isSelected = selectedCategory == category;
                  return GestureDetector(
                    onTap: () =>
                        setModalState(() => selectedCategory = category),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                      decoration: BoxDecoration(
                        // Selected used to fill with `category.color` and put
                        // white on it — 2.11:1 for entertainment's #FF9800 and
                        // 2.35:1 for social's #4CAF50. The Focus fill pair is
                        // 5.70:1 light / 5.60:1 dark, and the category still
                        // reads by its own glyph.
                        color: isSelected
                            ? ext.fillBg(ext.focus)
                            : ext.surfaceVariant,
                        borderRadius: AppRadius.brSm,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // emoji-content-ok: the category glyph the row in the
                          // list will carry, shown here so the choice matches
                          Text(category.emoji),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            category.name,
                            style: tt.labelMedium?.copyWith(
                              color: isSelected
                                  ? ext.fillFg(ext.focus)
                                  : ext.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Add app',
                fullWidth: true,
                accent: ext.focus,
                onPressed: () {
                  if (nameController.text.isEmpty) return;

                  final newApp = AllowedApp(
                    id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                    name: nameController.text,
                    category: selectedCategory,
                    addedAt: DateTime.now(),
                  );

                  setState(() {
                    _allowList = _allowList.copyWith(
                      apps: [..._allowList.apps, newApp],
                    );
                  });
                  _saveData();
                  Navigator.pop(sheetContext);
                },
              ),
            ],
          );
        },
      ),
    ).whenComplete(nameController.dispose); // dispose the sheet controller
  }
}

/// An InkWell when there is something to tap, and nothing when there is not.
///
/// `InkWell(onTap: null)` is not a disabled control — it is a control-shaped
/// wrapper with no feedback of any kind, which is the exact shape the dead-tap
/// gate in `focus_conformance_test.dart` exists to catch. Making the wrapper
/// itself conditional keeps the row identical in both states and removes the
/// affordance rather than leaving it inert.
class _RowShell extends StatelessWidget {
  final bool tappable;
  final VoidCallback onTap;
  final Widget child;

  const _RowShell({
    required this.tappable,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!tappable) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.brLg,
      child: child,
    );
  }
}
