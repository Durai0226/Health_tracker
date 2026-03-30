import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../theme/aqua_theme.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cup sizes saved!'),
          backgroundColor: AquaTheme.waterPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context);
    }
  }

  void _editCup(int index) {
    final cup = _cups[index];
    final nameController = TextEditingController(text: cup['name']);
    final mlController = TextEditingController(text: cup['ml'].toString());
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AquaTheme.textTertiary, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 24),
            const Text('Edit Cup Size', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AquaTheme.textPrimary)),
            const SizedBox(height: 20),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AquaTheme.waterPrimary)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: mlController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount (ml)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AquaTheme.waterPrimary)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _cups[index] = {
                      'name': nameController.text,
                      'ml': int.tryParse(mlController.text) ?? cup['ml'],
                      'icon': cup['icon'],
                    };
                  });
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: AquaTheme.waterPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
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
        title: const Text('Cup Sizes', style: TextStyle(color: AquaTheme.textPrimary, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AquaTheme.waterPrimary))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _cups.length,
                    itemBuilder: (context, index) => _buildCupCard(_cups[index], index),
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

  Widget _buildCupCard(Map<String, dynamic> cup, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: AquaTheme.waterPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Text(cup['icon'], style: const TextStyle(fontSize: 24))),
        ),
        title: Text(cup['name'], style: const TextStyle(fontWeight: FontWeight.w600, color: AquaTheme.textPrimary)),
        subtitle: Text('${cup['ml']} ml', style: const TextStyle(color: AquaTheme.textSecondary)),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined, color: AquaTheme.waterPrimary),
          onPressed: () => _editCup(index),
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
        child: const Text('Save Cup Sizes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
