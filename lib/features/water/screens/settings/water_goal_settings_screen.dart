import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/widgets/app/app_widgets.dart';

/// Water Daily Goal Settings Screen
class WaterGoalSettingsScreen extends StatefulWidget {
  const WaterGoalSettingsScreen({super.key});

  @override
  State<WaterGoalSettingsScreen> createState() => _WaterGoalSettingsScreenState();
}

class _WaterGoalSettingsScreenState extends State<WaterGoalSettingsScreen> {
  int _dailyGoalMl = 2000;
  String _unit = 'ml';
  bool _isLoading = true;

  final List<int> _presetGoals = [1500, 2000, 2500, 3000, 3500, 4000];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _dailyGoalMl = prefs.getInt('water_daily_goal') ?? 2000;
        _unit = prefs.getString('water_unit') ?? 'ml';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('water_daily_goal', _dailyGoalMl);
    await prefs.setString('water_unit', _unit);

    if (mounted) {
      final ext = AppColorsExt.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Goal saved!'),
          backgroundColor: ext.water.base,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
        ),
      );
      Navigator.pop(context);
    }
  }

  String _formatGoal(int ml) {
    if (_unit == 'oz') {
      return '${(ml / 29.5735).round()} oz';
    }
    return '$ml ml';
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final water = ext.water;

    return AppScaffold(
      safeTop: true,
      body: Column(
        children: [
          AppHeader(
            title: 'Daily Goal',
            icon: Icons.flag_rounded,
            accent: water,
            leading: AppIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              accent: water,
              filled: false,
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: ext.mark(water)))
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                        AppSpacing.sm, AppSpacing.gutter, AppSpacing.huge),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCurrentGoalCard(ext, water),
                        const SizedBox(height: AppSpacing.xl),
                        _buildPresetGoals(ext, water),
                        const SizedBox(height: AppSpacing.xl),
                        _buildUnitSelector(ext, water),
                        const SizedBox(height: AppSpacing.xl),
                        AppButton(
                          label: 'Save Goal',
                          accent: water,
                          size: AppButtonSize.lg,
                          fullWidth: true,
                          leadingIcon: Icons.check_rounded,
                          onPressed: _saveSettings,
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentGoalCard(AppColorsExt ext, AccentSwatch water) {
    final tt = Theme.of(context).textTheme;
    return AppCard(
      color: water.container,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            Icon(Icons.water_drop_rounded, color: water.onContainer, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text(
              _formatGoal(_dailyGoalMl),
              style: tt.displaySmall?.copyWith(
                color: water.onContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('Daily Target',
                style: tt.bodyMedium?.copyWith(color: water.onContainer)),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetGoals(AppColorsExt ext, AccentSwatch water) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Quick Select',
            icon: Icons.bolt_rounded,
            accent: water,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: _presetGoals.map((goal) {
              final isSelected = _dailyGoalMl == goal;
              return AppChip(
                label: _formatGoal(goal),
                selected: isSelected,
                accent: water,
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _dailyGoalMl = goal);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitSelector(AppColorsExt ext, AccentSwatch water) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Measurement Unit',
            icon: Icons.straighten_rounded,
            accent: water,
          ),
          const SizedBox(height: AppSpacing.sm),
          SegmentedToggle(
            index: _unit == 'oz' ? 1 : 0,
            accent: water,
            items: const [
              SegmentItem(icon: Icons.water_drop_outlined, label: 'ml'),
              SegmentItem(icon: Icons.local_drink_outlined, label: 'oz'),
            ],
            onChanged: (i) {
              HapticFeedback.lightImpact();
              setState(() => _unit = i == 1 ? 'oz' : 'ml');
            },
          ),
        ],
      ),
    );
  }
}
