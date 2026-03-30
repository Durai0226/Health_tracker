import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/luna_theme.dart';
import '../widgets/luna_widgets.dart';
import '../services/period_storage_service.dart';

/// Settings screen for Luna Cycle
class LunaSettingsScreen extends StatefulWidget {
  const LunaSettingsScreen({super.key});

  @override
  State<LunaSettingsScreen> createState() => _LunaSettingsScreenState();
}

class _LunaSettingsScreenState extends State<LunaSettingsScreen> {
  int _cycleLength = 28;
  int _periodDuration = 5;
  bool _periodReminders = true;
  bool _fertileReminders = false;
  bool _dailyInsights = true;
  bool _communityNotifications = true;
  bool _anonymousMode = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final settings = PeriodCleanStorageService.getSettings();
    setState(() {
      _cycleLength = settings.defaultCycleLength;
      _periodDuration = settings.defaultPeriodDuration;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LunaTheme.getBackground(context),
      appBar: LunaAppBar(
        title: 'Settings',
        showBackButton: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(LunaTheme.spacingLg),
        children: [
          // Profile section
          _buildSectionHeader('Profile'),
          LunaGlassCard(
            onTap: () {},
            padding: const EdgeInsets.all(LunaTheme.spacingLg),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LunaTheme.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      'L',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: LunaTheme.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Luna User',
                        style: LunaTheme.titleLarge.copyWith(
                          color: LunaTheme.getTextPrimary(context),
                        ),
                      ),
                      Text(
                        'Tap to edit profile',
                        style: LunaTheme.bodySmall.copyWith(
                          color: LunaTheme.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: LunaTheme.getTextTertiary(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: LunaTheme.spacingXl),

          // Cycle settings
          _buildSectionHeader('Cycle Settings'),
          _buildSettingCard(
            icon: Icons.loop,
            title: 'Average Cycle Length',
            subtitle: '$_cycleLength days',
            onTap: () => _showCycleLengthPicker(),
          ),
          const SizedBox(height: LunaTheme.spacingSm),
          _buildSettingCard(
            icon: Icons.water_drop,
            title: 'Average Period Duration',
            subtitle: '$_periodDuration days',
            onTap: () => _showPeriodDurationPicker(),
          ),

          const SizedBox(height: LunaTheme.spacingXl),

          // Notifications
          _buildSectionHeader('Notifications'),
          _buildToggleSetting(
            icon: Icons.notifications_outlined,
            title: 'Period Reminders',
            subtitle: 'Get notified before your period',
            value: _periodReminders,
            onChanged: (value) => setState(() => _periodReminders = value),
          ),
          const SizedBox(height: LunaTheme.spacingSm),
          _buildToggleSetting(
            icon: Icons.favorite_outline,
            title: 'Fertile Window Alerts',
            subtitle: 'Get notified about fertile days',
            value: _fertileReminders,
            onChanged: (value) => setState(() => _fertileReminders = value),
          ),
          const SizedBox(height: LunaTheme.spacingSm),
          _buildToggleSetting(
            icon: Icons.lightbulb_outline,
            title: 'Daily Insights',
            subtitle: 'Receive daily health tips',
            value: _dailyInsights,
            onChanged: (value) => setState(() => _dailyInsights = value),
          ),
          const SizedBox(height: LunaTheme.spacingSm),
          _buildToggleSetting(
            icon: Icons.people_outline,
            title: 'Community Updates',
            subtitle: 'Get notified about community activity',
            value: _communityNotifications,
            onChanged: (value) => setState(() => _communityNotifications = value),
          ),

          const SizedBox(height: LunaTheme.spacingXl),

          // Privacy
          _buildSectionHeader('Privacy'),
          _buildToggleSetting(
            icon: Icons.visibility_off,
            title: 'Anonymous Mode',
            subtitle: 'Post anonymously by default',
            value: _anonymousMode,
            onChanged: (value) => setState(() => _anonymousMode = value),
          ),
          const SizedBox(height: LunaTheme.spacingSm),
          _buildSettingCard(
            icon: Icons.lock_outline,
            title: 'App Lock',
            subtitle: 'Require authentication to open',
            onTap: () {},
          ),
          const SizedBox(height: LunaTheme.spacingSm),
          _buildSettingCard(
            icon: Icons.shield_outlined,
            title: 'Data Privacy',
            subtitle: 'Manage your data and privacy',
            onTap: () {},
          ),

          const SizedBox(height: LunaTheme.spacingXl),

          // Partner
          _buildSectionHeader('Partner Sharing'),
          _buildSettingCard(
            icon: Icons.favorite,
            title: 'Manage Partner',
            subtitle: 'Share data with your partner',
            onTap: () {},
            showBadge: false,
          ),

          const SizedBox(height: LunaTheme.spacingXl),

          // Data
          _buildSectionHeader('Data Management'),
          _buildSettingCard(
            icon: Icons.cloud_upload_outlined,
            title: 'Backup Data',
            subtitle: 'Save your data to cloud',
            onTap: () {},
          ),
          const SizedBox(height: LunaTheme.spacingSm),
          _buildSettingCard(
            icon: Icons.cloud_download_outlined,
            title: 'Restore Data',
            subtitle: 'Restore from backup',
            onTap: () {},
          ),
          const SizedBox(height: LunaTheme.spacingSm),
          _buildSettingCard(
            icon: Icons.download_outlined,
            title: 'Export Data',
            subtitle: 'Download your data',
            onTap: () {},
          ),
          const SizedBox(height: LunaTheme.spacingSm),
          _buildSettingCard(
            icon: Icons.delete_outline,
            title: 'Delete All Data',
            subtitle: 'Permanently remove all data',
            onTap: () => _showDeleteConfirmation(),
            isDestructive: true,
          ),

          const SizedBox(height: LunaTheme.spacingXl),

          // About
          _buildSectionHeader('About'),
          _buildSettingCard(
            icon: Icons.info_outline,
            title: 'About Luna Cycle',
            subtitle: 'Version 1.0.0',
            onTap: () {},
          ),
          const SizedBox(height: LunaTheme.spacingSm),
          _buildSettingCard(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            subtitle: 'Read our terms',
            onTap: () {},
          ),
          const SizedBox(height: LunaTheme.spacingSm),
          _buildSettingCard(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'How we handle your data',
            onTap: () {},
          ),
          const SizedBox(height: LunaTheme.spacingSm),
          _buildSettingCard(
            icon: Icons.help_outline,
            title: 'Help & Support',
            subtitle: 'Get help with Luna Cycle',
            onTap: () {},
          ),

          const SizedBox(height: LunaTheme.spacing4xl),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        left: LunaTheme.spacingXs,
        bottom: LunaTheme.spacingMd,
      ),
      child: Text(
        title,
        style: LunaTheme.titleMedium.copyWith(
          color: LunaTheme.primaryPink,
        ),
      ),
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
    bool showBadge = false,
  }) {
    final color = isDestructive ? LunaTheme.error : LunaTheme.primaryPink;
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(LunaTheme.spacingLg),
        decoration: BoxDecoration(
          color: LunaTheme.getSurface(context),
          borderRadius: BorderRadius.circular(LunaTheme.radiusMd),
          border: Border.all(
            color: LunaTheme.getDivider(context),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(LunaTheme.spacingSm),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(LunaTheme.radiusSm),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: LunaTheme.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: LunaTheme.titleMedium.copyWith(
                      color: isDestructive
                          ? LunaTheme.error
                          : LunaTheme.getTextPrimary(context),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: LunaTheme.bodySmall.copyWith(
                      color: LunaTheme.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: LunaTheme.getTextTertiary(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleSetting({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(LunaTheme.spacingLg),
      decoration: BoxDecoration(
        color: LunaTheme.getSurface(context),
        borderRadius: BorderRadius.circular(LunaTheme.radiusMd),
        border: Border.all(
          color: LunaTheme.getDivider(context),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(LunaTheme.spacingSm),
            decoration: BoxDecoration(
              color: LunaTheme.primaryPink.withOpacity(0.1),
              borderRadius: BorderRadius.circular(LunaTheme.radiusSm),
            ),
            child: Icon(icon, color: LunaTheme.primaryPink, size: 20),
          ),
          const SizedBox(width: LunaTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: LunaTheme.titleMedium.copyWith(
                    color: LunaTheme.getTextPrimary(context),
                  ),
                ),
                Text(
                  subtitle,
                  style: LunaTheme.bodySmall.copyWith(
                    color: LunaTheme.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (newValue) {
              HapticFeedback.lightImpact();
              onChanged(newValue);
            },
            activeColor: LunaTheme.primaryPink,
          ),
        ],
      ),
    );
  }

  void _showCycleLengthPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _NumberPickerSheet(
        title: 'Cycle Length',
        value: _cycleLength,
        min: 21,
        max: 35,
        unit: 'days',
        onChanged: (value) {
          Navigator.pop(context);
          setState(() => _cycleLength = value);
        },
      ),
    );
  }

  void _showPeriodDurationPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _NumberPickerSheet(
        title: 'Period Duration',
        value: _periodDuration,
        min: 2,
        max: 10,
        unit: 'days',
        onChanged: (value) {
          Navigator.pop(context);
          setState(() => _periodDuration = value);
        },
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Data?'),
        content: const Text(
          'This will permanently delete all your cycle data, logs, and settings. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Delete all data
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberPickerSheet extends StatefulWidget {
  final String title;
  final int value;
  final int min;
  final int max;
  final String unit;
  final ValueChanged<int> onChanged;

  const _NumberPickerSheet({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
  });

  @override
  State<_NumberPickerSheet> createState() => _NumberPickerSheetState();
}

class _NumberPickerSheetState extends State<_NumberPickerSheet> {
  late int _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(LunaTheme.spacingLg),
      decoration: BoxDecoration(
        color: LunaTheme.getSurface(context),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(LunaTheme.radius2xl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: LunaTheme.getDivider(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: LunaTheme.spacingLg),
          Text(
            widget.title,
            style: LunaTheme.headlineMedium.copyWith(
              color: LunaTheme.getTextPrimary(context),
            ),
          ),
          const SizedBox(height: LunaTheme.spacingXl),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _currentValue > widget.min
                    ? () => setState(() => _currentValue--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
                iconSize: 40,
                color: LunaTheme.primaryPink,
              ),
              const SizedBox(width: LunaTheme.spacingLg),
              Column(
                children: [
                  Text(
                    '$_currentValue',
                    style: LunaTheme.displayLarge.copyWith(
                      color: LunaTheme.primaryPink,
                    ),
                  ),
                  Text(
                    widget.unit,
                    style: LunaTheme.bodyMedium.copyWith(
                      color: LunaTheme.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: LunaTheme.spacingLg),
              IconButton(
                onPressed: _currentValue < widget.max
                    ? () => setState(() => _currentValue++)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
                iconSize: 40,
                color: LunaTheme.primaryPink,
              ),
            ],
          ),
          const SizedBox(height: LunaTheme.spacingXl),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => widget.onChanged(_currentValue),
              child: const Text('Save'),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(height: LunaTheme.spacingMd),
          ),
        ],
      ),
    );
  }
}
