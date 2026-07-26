import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../../core/widgets/app/app_widgets.dart';

/// Water Cup Sizes Settings Screen
class WaterCupsSettingsScreen extends StatefulWidget {
  const WaterCupsSettingsScreen({super.key});

  @override
  State<WaterCupsSettingsScreen> createState() => _WaterCupsSettingsScreenState();
}

class _WaterCupsSettingsScreenState extends State<WaterCupsSettingsScreen> {
  List<Map<String, dynamic>> _cups = [];
  bool _isLoading = true;

  final List<Map<String, dynamic>> _defaultCups = [
    {'name': 'Small Glass', 'ml': 150, 'icon': '🥃'},
    {'name': 'Regular Glass', 'ml': 250, 'icon': '🥛'},
    {'name': 'Large Glass', 'ml': 350, 'icon': '🍺'},
    {'name': 'Water Bottle', 'ml': 500, 'icon': '🍼'},
    {'name': 'Sports Bottle', 'ml': 750, 'icon': '🧴'},
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final cupsJson = prefs.getString('water_cups');
    if (mounted) {
      setState(() {
        if (cupsJson != null) {
          _cups = List<Map<String, dynamic>>.from(jsonDecode(cupsJson));
        } else {
          _cups = List.from(_defaultCups);
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('water_cups', jsonEncode(_cups));

    if (mounted) {
      context.toastSuccess('Cup sizes saved!');
      Navigator.pop(context);
    }
  }

  void _editCup(int index) {
    final cup = _cups[index];
    final nameController = TextEditingController(text: cup['name'].toString());
    final mlController = TextEditingController(text: cup['ml'].toString());
    final water = AppColorsExt.of(context).water;

    AppBottomSheet.show(
      context,
      title: 'Edit Cup Size',
      icon: Symbols.local_drink_rounded,
      accent: water,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: nameController,
            label: 'Name',
            accent: water,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: mlController,
            label: 'Amount (ml)',
            accent: water,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Save',
            accent: water,
            size: AppButtonSize.lg,
            fullWidth: true,
            leadingIcon: Symbols.check_rounded,
            onPressed: () {
              setState(() {
                _cups[index] = {
                  'name': nameController.text,
                  'ml': int.tryParse(mlController.text) ?? cup['ml'],
                  'icon': cup['icon'],
                };
              });
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
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
            title: 'Cup Sizes',
            icon: Symbols.local_drink_rounded,
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
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                        AppSpacing.sm, AppSpacing.gutter, AppSpacing.lg),
                    itemCount: _cups.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) =>
                        _buildCupCard(_cups[index], index, ext, water),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.sm,
                AppSpacing.gutter, AppSpacing.lg),
            child: AppButton(
              label: 'Save Cup Sizes',
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

  Widget _buildCupCard(
      Map<String, dynamic> cup, int index, AppColorsExt ext, AccentSwatch water) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: water.container,
              borderRadius: AppRadius.brMd,
            ),
            child: Center(
                child: Text(cup['icon'].toString(),
                    style: const TextStyle(fontSize: 24))),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cup['name'].toString(),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: ext.textPrimary)),
                const SizedBox(height: 2),
                Text('${cup['ml']} ml',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: ext.textSecondary)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Symbols.edit_rounded, color: ext.mark(water)),
            onPressed: () => _editCup(index),
          ),
        ],
      ),
    );
  }
}
