import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/storage_service.dart';
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
    final prefs = StorageService.getAppPreferences();
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
    await StorageService.setAppPreference('focusAppAllowList', _allowList.toJson());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  _buildAppBar(),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAppDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add App', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.background,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back_rounded, size: 20),
        ),
      ),
      title: const Text(
        'App Allow List',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Focus Settings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildSettingSwitch(
            'Strict Mode',
            'Only allowed apps can be used during focus',
            Icons.shield_rounded,
            _allowList.isStrictMode,
            (value) {
              setState(() {
                _allowList = _allowList.copyWith(isStrictMode: value);
              });
              _saveData();
            },
          ),
          const Divider(height: 24),
          _buildSettingSwitch(
            'Block Notifications',
            'Silence notifications from non-allowed apps',
            Icons.notifications_off_rounded,
            _allowList.blockNotifications,
            (value) {
              setState(() {
                _allowList = _allowList.copyWith(blockNotifications: value);
              });
              _saveData();
            },
          ),
          const Divider(height: 24),
          _buildSettingSwitch(
            'Show Warning',
            'Display warning when opening blocked app',
            Icons.warning_rounded,
            _allowList.showWarningOnBlockedApp,
            (value) {
              setState(() {
                _allowList = _allowList.copyWith(showWarningOnBlockedApp: value);
              });
              _saveData();
            },
          ),
          const Divider(height: 24),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.timer_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Grace Period',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Seconds before tree dies when leaving app',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<int>(
                  value: _allowList.gracePeriodSeconds,
                  underline: const SizedBox(),
                  isDense: true,
                  items: [5, 10, 15, 30, 60].map((seconds) {
                    return DropdownMenuItem(
                      value: seconds,
                      child: Text('${seconds}s'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _allowList = _allowList.copyWith(gracePeriodSeconds: value);
                      });
                      _saveData();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingSwitch(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.primary,
        ),
      ],
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
              _buildPresetChip('📊 Productivity', PresetAllowList.getProductivityApps()),
              const SizedBox(width: 12),
              _buildPresetChip('📚 Education', PresetAllowList.getEducationApps()),
              const SizedBox(width: 12),
              _buildPresetChip('🎵 Music', PresetAllowList.getMusicApps()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPresetChip(String label, List<AllowedApp> apps) {
    return GestureDetector(
      onTap: () => _addPresetApps(apps),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            const SizedBox(width: 8),
            const Icon(Icons.add_circle_outline_rounded, size: 18, color: AppColors.primary),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Allowed Apps',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${_allowList.allowedApps.length} apps',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_allowList.apps.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Column(
                children: [
                  Text('📱', style: TextStyle(fontSize: 48)),
                  SizedBox(height: 12),
                  Text(
                    'No apps added yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Add apps that won\'t kill your tree during focus',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
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

  Widget _buildAppCard(AllowedApp app, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
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
          Switch(
            value: app.isAllowed,
            onChanged: (value) {
              setState(() {
                final updatedApps = List<AllowedApp>.from(_allowList.apps);
                updatedApps[index] = app.copyWith(isAllowed: value);
                _allowList = _allowList.copyWith(apps: updatedApps);
              });
              _saveData();
            },
            activeThumbColor: AppColors.primary,
          ),
          IconButton(
            onPressed: () {
              setState(() {
                final updatedApps = List<AllowedApp>.from(_allowList.apps)
                  ..removeAt(index);
                _allowList = _allowList.copyWith(apps: updatedApps);
              });
              _saveData();
            },
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
          ),
        ],
      ),
    );
  }

  void _showAddAppDialog() {
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
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                'Add App to Allow List',
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
                        color: isSelected ? category.color : Colors.grey.shade100,
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
                              color: isSelected ? Colors.white : AppColors.textPrimary,
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
                    backgroundColor: AppColors.primary,
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
    );
  }
}
