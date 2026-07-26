import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../../core/widgets/app/app_widgets.dart';

/// Water Beverages Settings Screen
class WaterBeveragesSettingsScreen extends StatefulWidget {
  const WaterBeveragesSettingsScreen({super.key});

  @override
  State<WaterBeveragesSettingsScreen> createState() =>
      _WaterBeveragesSettingsScreenState();
}

class _WaterBeveragesSettingsScreenState
    extends State<WaterBeveragesSettingsScreen> {
  Map<String, bool> _enabledBeverages = {};
  bool _isLoading = true;

  final List<Map<String, dynamic>> _allBeverages = [
    {'id': 'water', 'name': 'Water', 'icon': '💧', 'hydration': 100},
    {'id': 'coffee', 'name': 'Coffee', 'icon': '☕', 'hydration': 80},
    {'id': 'tea', 'name': 'Tea', 'icon': '🍵', 'hydration': 90},
    {'id': 'juice', 'name': 'Juice', 'icon': '🧃', 'hydration': 85},
    {'id': 'soda', 'name': 'Soda', 'icon': '🥤', 'hydration': 70},
    {'id': 'milk', 'name': 'Milk', 'icon': '🥛', 'hydration': 90},
    {'id': 'smoothie', 'name': 'Smoothie', 'icon': '🥤', 'hydration': 85},
    {'id': 'alcohol', 'name': 'Alcohol', 'icon': '🍺', 'hydration': 50},
    {'id': 'energy', 'name': 'Energy Drink', 'icon': '⚡', 'hydration': 75},
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final beveragesJson = prefs.getString('water_enabled_beverages');
    if (mounted) {
      setState(() {
        if (beveragesJson != null) {
          _enabledBeverages = Map<String, bool>.from(jsonDecode(beveragesJson));
        } else {
          for (var bev in _allBeverages) {
            _enabledBeverages[bev['id']] = true;
          }
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'water_enabled_beverages', jsonEncode(_enabledBeverages));

    if (mounted) {
      context.toastSuccess('Beverages saved!');
      Navigator.pop(context);
    }
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
            title: 'Beverages',
            icon: Symbols.local_bar_rounded,
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
                : ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                        AppSpacing.sm, AppSpacing.gutter, AppSpacing.lg),
                    children: [
                      Text(
                        'Choose which beverages to show in your quick-add menu',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: ext.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      ..._allBeverages.map(
                          (bev) => _buildBeverageCard(bev, ext, water)),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.sm,
                AppSpacing.gutter, AppSpacing.lg),
            child: AppButton(
              label: 'Save Beverages',
              accent: water,
              size: AppButtonSize.lg,
              fullWidth: true,
              leadingIcon: Symbols.check_rounded,
              onPressed: _saveSettings,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBeverageCard(
      Map<String, dynamic> beverage, AppColorsExt ext, AccentSwatch water) {
    final isEnabled = _enabledBeverages[beverage['id']] ?? true;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        color: isEnabled ? water.container : null,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isEnabled ? ext.surface : ext.surfaceVariant,
                borderRadius: AppRadius.brMd,
              ),
              child: Center(
                  child: Text(beverage['icon'].toString(),
                      style: const TextStyle(fontSize: 24))),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    beverage['name'].toString(),
                    style: tt.titleMedium?.copyWith(
                      color: isEnabled
                          ? (ext.isDark ? water.onContainer : ext.textPrimary)
                          : ext.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Symbols.water_drop_rounded,
                          size: 14, color: ext.mark(water)),
                      const SizedBox(width: 4),
                      Text(
                        '${beverage['hydration']}% hydration',
                        style: tt.bodySmall?.copyWith(
                          color: isEnabled
                              ? (ext.isDark
                                  ? water.onContainer
                                  : ext.textSecondary)
                              : ext.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            AppSwitch(
              value: isEnabled,
              onChanged: (v) {
                HapticFeedback.lightImpact();
                setState(() => _enabledBeverages[beverage['id']] = v);
              },
              accent: water,
            ),
          ],
        ),
      ),
    );
  }
}
