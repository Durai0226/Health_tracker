import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/flo_theme.dart';
import '../widgets/widgets.dart';
import '../models/period_settings.dart';
import '../services/period_storage_service.dart';

/// Settings screen for period tracking
class FloSettingsScreen extends StatefulWidget {
  const FloSettingsScreen({super.key});

  @override
  State<FloSettingsScreen> createState() => _FloSettingsScreenState();
}

class _FloSettingsScreenState extends State<FloSettingsScreen> {
  late PeriodSettings _settings;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    _settings = PeriodCleanStorageService.getSettings();
    setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    await PeriodCleanStorageService.saveSettings(_settings);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Settings saved'),
          backgroundColor: FloTheme.periodPink,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: FloTheme.getBackground(context),
      appBar: FloAppBar(
        title: 'Settings',
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: Text(
              'Save',
              style: FloTheme.titleMedium.copyWith(
                color: FloTheme.periodPink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(FloTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cycle settings
            _buildSectionTitle('Cycle Settings', Icons.loop_rounded),
            const SizedBox(height: FloTheme.spacingMd),
            
            _buildNumberSetting(
              'Default Cycle Length',
              '${_settings.defaultCycleLength} days',
              () => _showNumberPicker(
                'Cycle Length',
                _settings.defaultCycleLength,
                21,
                45,
                (value) {
                  setState(() {
                    _settings = _settings.copyWith(defaultCycleLength: value);
                  });
                },
              ),
            ),
            
            _buildNumberSetting(
              'Default Period Duration',
              '${_settings.defaultPeriodDuration} days',
              () => _showNumberPicker(
                'Period Duration',
                _settings.defaultPeriodDuration,
                2,
                10,
                (value) {
                  setState(() {
                    _settings = _settings.copyWith(defaultPeriodDuration: value);
                  });
                },
              ),
            ),

            const SizedBox(height: FloTheme.spacing2xl),

            // Tracking preferences
            _buildSectionTitle('Tracking', Icons.track_changes_rounded),
            const SizedBox(height: FloTheme.spacingMd),

            _buildToggleSetting(
              'Track Ovulation',
              'Get predictions for your ovulation day',
              _settings.trackOvulation,
              (value) {
                setState(() {
                  _settings = _settings.copyWith(trackOvulation: value);
                });
              },
            ),

            _buildToggleSetting(
              'Track Fertility',
              'See your fertile window predictions',
              _settings.trackFertility,
              (value) {
                setState(() {
                  _settings = _settings.copyWith(trackFertility: value);
                });
              },
            ),

            _buildToggleSetting(
              'Track Symptoms',
              'Log and track your daily symptoms',
              _settings.trackSymptoms,
              (value) {
                setState(() {
                  _settings = _settings.copyWith(trackSymptoms: value);
                });
              },
            ),

            _buildToggleSetting(
              'Track Mood',
              'Record your mood patterns',
              _settings.trackMood,
              (value) {
                setState(() {
                  _settings = _settings.copyWith(trackMood: value);
                });
              },
            ),

            const SizedBox(height: FloTheme.spacing2xl),

            // Reminders
            _buildSectionTitle('Reminders', Icons.notifications_rounded),
            const SizedBox(height: FloTheme.spacingMd),

            _buildToggleSetting(
              'Period Reminders',
              'Get notified before your period starts',
              _settings.enablePeriodReminders,
              (value) {
                setState(() {
                  _settings = _settings.copyWith(enablePeriodReminders: value);
                });
              },
            ),

            if (_settings.enablePeriodReminders)
              _buildNumberSetting(
                'Days Before Period',
                '${_settings.periodReminderDaysBefore} days',
                () => _showNumberPicker(
                  'Days Before',
                  _settings.periodReminderDaysBefore,
                  1,
                  7,
                  (value) {
                    setState(() {
                      _settings = _settings.copyWith(periodReminderDaysBefore: value);
                    });
                  },
                ),
              ),

            _buildToggleSetting(
              'Ovulation Reminders',
              'Get notified on ovulation day',
              _settings.enableOvulationReminders,
              (value) {
                setState(() {
                  _settings = _settings.copyWith(enableOvulationReminders: value);
                });
              },
            ),

            _buildToggleSetting(
              'Fertile Window Reminders',
              'Know when your fertile window starts',
              _settings.enableFertileWindowReminders,
              (value) {
                setState(() {
                  _settings = _settings.copyWith(enableFertileWindowReminders: value);
                });
              },
            ),

            _buildToggleSetting(
              'PMS Reminders',
              'Prepare for PMS symptoms',
              _settings.enablePMSReminders,
              (value) {
                setState(() {
                  _settings = _settings.copyWith(enablePMSReminders: value);
                });
              },
            ),

            const SizedBox(height: FloTheme.spacing2xl),

            // Extras
            _buildSectionTitle('Extras', Icons.auto_awesome_rounded),
            const SizedBox(height: FloTheme.spacingMd),

            _buildToggleSetting(
              'Health Tips',
              'Get daily tips based on your cycle phase',
              _settings.enableHealthTips,
              (value) {
                setState(() {
                  _settings = _settings.copyWith(enableHealthTips: value);
                });
              },
            ),

            _buildToggleSetting(
              'Motivational Messages',
              'Receive encouraging messages',
              _settings.showMotivationalMessages,
              (value) {
                setState(() {
                  _settings = _settings.copyWith(showMotivationalMessages: value);
                });
              },
            ),

            const SizedBox(height: FloTheme.spacing2xl),

            // Privacy
            _buildSectionTitle('Privacy', Icons.lock_rounded),
            const SizedBox(height: FloTheme.spacingMd),

            _buildToggleSetting(
              'Privacy Mode',
              'Hide sensitive info on lock screen',
              _settings.privacyMode,
              (value) {
                setState(() {
                  _settings = _settings.copyWith(privacyMode: value);
                });
              },
            ),

            const SizedBox(height: FloTheme.spacing2xl),

            // Data management
            _buildSectionTitle('Data', Icons.storage_rounded),
            const SizedBox(height: FloTheme.spacingMd),

            _buildActionSetting(
              'Export Data',
              'Download your cycle data',
              Icons.download_rounded,
              () {
                // TODO: Export data
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Export feature coming soon')),
                );
              },
            ),

            _buildActionSetting(
              'Clear All Data',
              'Delete all period tracking data',
              Icons.delete_forever_rounded,
              _showClearDataDialog,
              isDestructive: true,
            ),

            const SizedBox(height: FloTheme.spacing4xl),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: FloTheme.periodPink, size: 20),
        const SizedBox(width: FloTheme.spacingSm),
        Text(
          title,
          style: FloTheme.headlineSmall.copyWith(
            color: FloTheme.getTextPrimary(context),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleSetting(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return FloGlassCard(
      padding: const EdgeInsets.symmetric(
        horizontal: FloTheme.spacingLg,
        vertical: FloTheme.spacingMd,
      ),
      margin: const EdgeInsets.only(bottom: FloTheme.spacingSm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: FloTheme.titleMedium.copyWith(
                    color: FloTheme.getTextPrimary(context),
                  ),
                ),
                Text(
                  subtitle,
                  style: FloTheme.bodySmall.copyWith(
                    color: FloTheme.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onChanged(v);
            },
            activeColor: FloTheme.periodPink,
          ),
        ],
      ),
    );
  }

  Widget _buildNumberSetting(
    String title,
    String value,
    VoidCallback onTap,
  ) {
    return FloGlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(FloTheme.spacingLg),
      margin: const EdgeInsets.only(bottom: FloTheme.spacingSm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: FloTheme.titleMedium.copyWith(
                color: FloTheme.getTextPrimary(context),
              ),
            ),
          ),
          Text(
            value,
            style: FloTheme.titleMedium.copyWith(
              color: FloTheme.periodPink,
            ),
          ),
          const SizedBox(width: FloTheme.spacingSm),
          Icon(
            Icons.chevron_right_rounded,
            color: FloTheme.getTextSecondary(context),
          ),
        ],
      ),
    );
  }

  Widget _buildActionSetting(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return FloGlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(FloTheme.spacingLg),
      margin: const EdgeInsets.only(bottom: FloTheme.spacingSm),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(FloTheme.spacingSm),
            decoration: BoxDecoration(
              color: (isDestructive ? Colors.red : FloTheme.periodPink)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(FloTheme.radiusSm),
            ),
            child: Icon(
              icon,
              color: isDestructive ? Colors.red : FloTheme.periodPink,
              size: 20,
            ),
          ),
          const SizedBox(width: FloTheme.spacingLg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: FloTheme.titleMedium.copyWith(
                    color: isDestructive
                        ? Colors.red
                        : FloTheme.getTextPrimary(context),
                  ),
                ),
                Text(
                  subtitle,
                  style: FloTheme.bodySmall.copyWith(
                    color: FloTheme.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: FloTheme.getTextSecondary(context),
          ),
        ],
      ),
    );
  }

  void _showNumberPicker(
    String title,
    int currentValue,
    int min,
    int max,
    ValueChanged<int> onChanged,
  ) {
    int selectedValue = currentValue;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: BoxDecoration(
            color: FloTheme.getSurface(context),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(FloTheme.radius2xl),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: FloTheme.spacingMd),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: FloTheme.getDivider(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(FloTheme.spacingLg),
                child: Text(
                  title,
                  style: FloTheme.headlineSmall.copyWith(
                    color: FloTheme.getTextPrimary(context),
                  ),
                ),
              ),
              SizedBox(
                height: 200,
                child: ListWheelScrollView.useDelegate(
                  itemExtent: 50,
                  perspective: 0.005,
                  diameterRatio: 1.2,
                  physics: const FixedExtentScrollPhysics(),
                  controller: FixedExtentScrollController(
                    initialItem: currentValue - min,
                  ),
                  onSelectedItemChanged: (index) {
                    setSheetState(() => selectedValue = min + index);
                    HapticFeedback.selectionClick();
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: max - min + 1,
                    builder: (context, index) {
                      final value = min + index;
                      final isSelected = value == selectedValue;
                      return Center(
                        child: Text(
                          '$value days',
                          style: FloTheme.headlineMedium.copyWith(
                            color: isSelected
                                ? FloTheme.periodPink
                                : FloTheme.getTextSecondary(context),
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(FloTheme.spacingLg),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        onChanged(selectedValue);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FloTheme.periodPink,
                        padding: const EdgeInsets.symmetric(
                          vertical: FloTheme.spacingLg,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(FloTheme.radiusMd),
                        ),
                      ),
                      child: const Text('Done'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FloTheme.getSurface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FloTheme.radiusXl),
        ),
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will permanently delete all your period tracking data including cycle history, symptoms, and settings. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await PeriodCleanStorageService.clearAllData();
              _loadSettings();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All data cleared')),
                );
              }
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
