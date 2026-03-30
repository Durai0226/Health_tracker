import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../theme/aqua_theme.dart';

/// Water Beverages Settings Screen
class WaterBeveragesSettingsScreen extends StatefulWidget {
  const WaterBeveragesSettingsScreen({super.key});

  @override
  State<WaterBeveragesSettingsScreen> createState() => _WaterBeveragesSettingsScreenState();
}

class _WaterBeveragesSettingsScreenState extends State<WaterBeveragesSettingsScreen> {
  Map<String, bool> _enabledBeverages = {};
  bool _isLoading = true;

  final List<Map<String, dynamic>> _allBeverages = [
    {'id': 'water', 'name': 'Water', 'icon': '💧', 'color': AquaTheme.waterPrimary, 'hydration': 100},
    {'id': 'coffee', 'name': 'Coffee', 'icon': '☕', 'color': AquaTheme.coffeePrimary, 'hydration': 80},
    {'id': 'tea', 'name': 'Tea', 'icon': '🍵', 'color': AquaTheme.teaPrimary, 'hydration': 90},
    {'id': 'juice', 'name': 'Juice', 'icon': '🧃', 'color': AquaTheme.juicePrimary, 'hydration': 85},
    {'id': 'soda', 'name': 'Soda', 'icon': '🥤', 'color': AquaTheme.sodaPrimary, 'hydration': 70},
    {'id': 'milk', 'name': 'Milk', 'icon': '🥛', 'color': AquaTheme.milkPrimary, 'hydration': 90},
    {'id': 'smoothie', 'name': 'Smoothie', 'icon': '🥤', 'color': AquaTheme.smoothiePrimary, 'hydration': 85},
    {'id': 'alcohol', 'name': 'Alcohol', 'icon': '🍺', 'color': AquaTheme.alcoholPrimary, 'hydration': 50},
    {'id': 'energy', 'name': 'Energy Drink', 'icon': '⚡', 'color': AquaTheme.energyPrimary, 'hydration': 75},
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
    await prefs.setString('water_enabled_beverages', jsonEncode(_enabledBeverages));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Beverages saved!'),
          backgroundColor: AquaTheme.waterPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AquaTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AquaTheme.backgroundLight,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AquaTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Beverages', style: TextStyle(color: AquaTheme.textPrimary, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AquaTheme.waterPrimary))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Choose which beverages to show in your quick-add menu',
                    style: TextStyle(color: AquaTheme.textSecondary, fontSize: 14),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _allBeverages.length,
                    itemBuilder: (context, index) => _buildBeverageCard(_allBeverages[index]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildSaveButton(),
                ),
              ],
            ),
    );
  }

  Widget _buildBeverageCard(Map<String, dynamic> beverage) {
    final isEnabled = _enabledBeverages[beverage['id']] ?? true;
    final color = beverage['color'] as Color;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isEnabled ? Border.all(color: color.withValues(alpha: 0.3), width: 2) : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Text(beverage['icon'], style: const TextStyle(fontSize: 24))),
        ),
        title: Text(
          beverage['name'], 
          style: TextStyle(
            fontWeight: FontWeight.w600, 
            color: isEnabled ? AquaTheme.textPrimary : AquaTheme.textTertiary,
          ),
        ),
        subtitle: Row(
          children: [
            Icon(Icons.water_drop, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              '${beverage['hydration']}% hydration',
              style: TextStyle(color: AquaTheme.textSecondary, fontSize: 12),
            ),
          ],
        ),
        trailing: Switch.adaptive(
          value: isEnabled,
          onChanged: (v) {
            HapticFeedback.lightImpact();
            setState(() => _enabledBeverages[beverage['id']] = v);
          },
          activeColor: color,
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _saveSettings,
        style: ElevatedButton.styleFrom(
          backgroundColor: AquaTheme.waterPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text('Save Beverages', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
