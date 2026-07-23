import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/widgets/app/app_widgets.dart';
import '../../../../core/ai/ai_assistant.dart';
import '../../services/water_service.dart';

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
  bool _suggesting = false;

  final List<int> _presetGoals = [1500, 2000, 2500, 3000, 3500, 4000];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    // Source the real goal from WaterService (the app uses the hydration
    // profile's effective goal), not just the local pref.
    await WaterService.init();
    final effectiveGoal = WaterService.getDailyGoal();
    if (mounted) {
      setState(() {
        _dailyGoalMl = effectiveGoal > 0 ? effectiveGoal : 2000;
        _unit = prefs.getString('water_unit') ?? 'ml';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('water_unit', _unit);

    // Persist through WaterService so the goal actually takes effect app-wide.
    final profile = WaterService.getProfile();
    await WaterService.saveProfile(
        profile.copyWith(customGoalMl: _dailyGoalMl, useCustomGoal: true));

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

  /// Ask the AI to suggest a daily goal from the hydration profile, then set the
  /// goal field so the user can review and Save. Always available: backed by the
  /// free on-device rule engine via AiAssistant. On any failure it leaves the
  /// current goal untouched. Manual entry stays fully intact either way.
  Future<void> _suggestGoalWithAi() async {
    final ext = AppColorsExt.of(context);

    setState(() => _suggesting = true);
    HapticFeedback.mediumImpact();

    try {
      await WaterService.init();
      final p = WaterService.getProfile();

      final goalMl = await AiAssistant().suggestWaterGoal(
        weightKg: p.weightKg,
        activity: p.activityLevelString,
        climate: p.climateString,
      );

      if (!mounted) return;

      if (goalMl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Couldn't suggest a goal right now. Try again."),
            backgroundColor: ext.water.base,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
          ),
        );
        return;
      }

      final clamped = goalMl.clamp(1500, 4000);
      setState(() => _dailyGoalMl = clamped);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'AI suggests ${_formatGoal(clamped)}. Review, then tap Save Goal.'),
          backgroundColor: ext.water.base,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
        ),
      );
    } finally {
      if (mounted) setState(() => _suggesting = false);
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
            icon: Symbols.flag_rounded,
            accent: water,
            leading: AppIconButton(
              icon: Symbols.arrow_back_rounded,
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
                          label: 'Suggest my goal (AI)',
                          accent: water,
                          variant: AppButtonVariant.secondary,
                          size: AppButtonSize.lg,
                          fullWidth: true,
                          leadingIcon: Symbols.auto_awesome_rounded,
                          loading: _suggesting,
                          onPressed: _suggesting ? null : _suggestGoalWithAi,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppButton(
                          label: 'Save Goal',
                          accent: water,
                          size: AppButtonSize.lg,
                          fullWidth: true,
                          leadingIcon: Symbols.check_rounded,
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
            Icon(Symbols.water_drop_rounded, color: water.onContainer, size: 48),
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
            icon: Symbols.bolt_rounded,
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
            icon: Symbols.straighten_rounded,
            accent: water,
          ),
          const SizedBox(height: AppSpacing.sm),
          SegmentedToggle(
            index: _unit == 'oz' ? 1 : 0,
            accent: water,
            items: const [
              SegmentItem(icon: Symbols.water_drop_rounded, label: 'ml'),
              SegmentItem(icon: Symbols.local_drink_rounded, label: 'oz'),
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
