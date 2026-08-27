import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import '../../../core/constants/app_colors.dart';
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
                        padding: const EdgeInsets.all(24),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _buildSettingsCard(),
                            const SizedBox(height: 24),
                            _buildPresetSection(),
                            const SizedBox(height: 24),
                            _buildAllowedAppsSection(),
                            const SizedBox(height: 100),
                          ]),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAppDialog,
        // A FAB is a filled control, so `fillBg`/`fillFg` — the pair that is
        // already measured AA-safe in both themes. `AppColors.primary` is the
        // LIGHT teal, which on the dark surface gives ~3.9:1 where the dark
        // token gives 7.07:1.
        backgroundColor: ext.fillBg(ext.brand),
        icon: Icon(Symbols.add_rounded, color: ext.fillFg(ext.brand)),
        label: Text('Add app',
            style: TextStyle(color: ext.fillFg(ext.brand))),
      ),
    );
  }

  Widget _buildSettingsCard() {
    final ext = AppColorsExt.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getCardBg(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.getCardShadow(context),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ext.brand.container,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Symbols.info_rounded,
                color: ext.brand.onContainer, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This is your own list',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'DlyMinder does not block or monitor other apps. Writing down '
                  'what pulls you away makes it easier to notice when it happens '
                  '— and your session only ends when you tap Give Up.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildPresetSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Add Presets',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildPresetChip(Symbols.insights_rounded, 'Productivity', PresetAllowList.getProductivityApps()),
              const SizedBox(width: 12),
              _buildPresetChip(Symbols.school_rounded, 'Education', PresetAllowList.getEducationApps()),
              const SizedBox(width: 12),
              _buildPresetChip(Symbols.music_note_rounded, 'Music', PresetAllowList.getMusicApps()),
            ],
          ),
        ),
      ],
    );
  }

  /// A preset chip. The leading glyph is an icon, not part of the label string.
  ///
  /// Baking an emoji into the label meant it could not be tinted, could not
  /// scale with the text, and was read aloud by a screen reader as its Unicode
  /// name in front of the words that matter.
  Widget _buildPresetChip(IconData icon, String label, List<AllowedApp> apps) {
    final ext = AppColorsExt.of(context);
    return GestureDetector(
      onTap: () => _addPresetApps(apps),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.getCardBg(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.getBorder(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.getTextSecondary(context)),
            const SizedBox(width: 6),
            Text(label),
            const SizedBox(width: 8),
            Icon(Symbols.add_circle_rounded,
                size: 18, color: ext.mark(ext.brand)),
          ],
        ),
      ),
    );
  }

  void _addPresetApps(List<AllowedApp> apps) {
    final existingIds = _allowList.apps.map((a) => a.id).toSet();
    final newApps = apps.where((a) => !existingIds.contains(a.id)).toList();
    
    if (newApps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All apps from this preset are already added')),
      );
      return;
    }

    setState(() {
      _allowList = _allowList.copyWith(apps: [..._allowList.apps, ...newApps]);
    });
    _saveData();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added ${newApps.length} apps')),
    );
  }

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
            const Flexible(
              child: Text(
                'Your list',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                '${_allowList.apps.length} listed',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.getTextSecondary(context),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_allowList.apps.isEmpty)
          // Was a hand-rolled card reading 'No apps added yet' with nothing to
          // tap, on a screen whose entire purpose is adding things. Unlike the
          // garden and the stats chart, the way forward here is on this screen,
          // so the action opens the add dialog directly.
          Container(
            decoration: BoxDecoration(
              color: AppColors.getCardBg(context),
              borderRadius: BorderRadius.circular(20),
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
    final logging = _sessionRunning;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: AppColors.getCardBg(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: logging ? () => _logDistraction(app) : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: app.category.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(app.category.emoji, style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  app.category.name,
                  style: TextStyle(
                    fontSize: 12,
                    color: app.category.color,
                  ),
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
                Text(
                  'Pulled me away',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Symbols.add_circle_rounded,
                    size: 20, color: AppColors.getTextSecondary(context)),
              ],
            )
          else ...[
            AppSwitch(
              value: app.isAllowed,
              onChanged: (value) {
                setState(() {
                  final updatedApps = List<AllowedApp>.from(_allowList.apps);
                  updatedApps[index] = app.copyWith(isAllowed: value);
                  _allowList = _allowList.copyWith(apps: updatedApps);
                });
                _saveData();
              },
            ),
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

  void _showAddAppDialog() {
    final ext = AppColorsExt.of(context);
    final nameController = TextEditingController();
    AppCategory selectedCategory = AppCategory.productivity;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: AppColors.getCardBg(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Add a distraction',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'App Name',
                  hintText: 'e.g., Spotify',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Category',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppCategory.values.map((category) {
                  final isSelected = selectedCategory == category;
                  return GestureDetector(
                    onTap: () => setModalState(() => selectedCategory = category),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? category.color : AppColors.getGrey200(context),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(category.emoji),
                          const SizedBox(width: 4),
                          Text(
                            category.name,
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected ? Colors.white : AppColors.getTextPrimary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
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
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ext.fillBg(ext.brand),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Add App',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(nameController.dispose); // dispose the sheet controller
  }
}
