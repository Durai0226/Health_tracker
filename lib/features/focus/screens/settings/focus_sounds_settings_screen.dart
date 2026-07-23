import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';

/// Focus Ambient Sounds Settings Screen
class FocusSoundsSettingsScreen extends StatefulWidget {
  const FocusSoundsSettingsScreen({super.key});

  @override
  State<FocusSoundsSettingsScreen> createState() => _FocusSoundsSettingsScreenState();
}

class _FocusSoundsSettingsScreenState extends State<FocusSoundsSettingsScreen> {
  String _selectedSound = 'rain';
  double _volume = 0.7;
  bool _autoPlay = true;
  bool _isLoading = true;

  static const _primaryColor = Color(0xFF4CAF50);

  final List<Map<String, dynamic>> _sounds = [
    {'id': 'rain', 'name': 'Rain', 'icon': Symbols.water_drop_rounded},
    {'id': 'forest', 'name': 'Forest', 'icon': Symbols.forest_rounded},
    {'id': 'ocean', 'name': 'Ocean Waves', 'icon': Symbols.waves_rounded},
    {'id': 'fire', 'name': 'Fireplace', 'icon': Symbols.local_fire_department_rounded},
    {'id': 'cafe', 'name': 'Coffee Shop', 'icon': Symbols.coffee_rounded},
    {'id': 'white', 'name': 'White Noise', 'icon': Symbols.graphic_eq_rounded},
    {'id': 'birds', 'name': 'Birds', 'icon': Symbols.flutter_dash_rounded},
    {'id': 'wind', 'name': 'Wind', 'icon': Symbols.air_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _selectedSound = prefs.getString('focus_sound') ?? 'rain';
        _volume = prefs.getDouble('focus_volume') ?? 0.7;
        _autoPlay = prefs.getBool('focus_autoplay') ?? true;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('focus_sound', _selectedSound);
    await prefs.setDouble('focus_volume', _volume);
    await prefs.setBool('focus_autoplay', _autoPlay);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Sound settings saved!'), backgroundColor: _primaryColor, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
        leading: IconButton(icon: const Icon(Symbols.arrow_back_rounded, color: Colors.black87), onPressed: () => Navigator.pop(context)),
        title: const Text('Ambient Sounds', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Sound', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  _buildSoundGrid(),
                  const SizedBox(height: 24),
                  _buildVolumeCard(),
                  const SizedBox(height: 12),
                  _buildAutoPlayCard(),
                  const SizedBox(height: 32),
                  _buildSaveButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildSoundGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, childAspectRatio: 0.9, crossAxisSpacing: 12, mainAxisSpacing: 12),
      itemCount: _sounds.length,
      itemBuilder: (context, index) {
        final sound = _sounds[index];
        final isSelected = _selectedSound == sound['id'];
        return GestureDetector(
          onTap: () { HapticFeedback.lightImpact(); setState(() => _selectedSound = sound['id']); },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected ? _primaryColor : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isSelected ? _primaryColor : Colors.grey.shade300),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(sound['icon'], color: isSelected ? Colors.white : _primaryColor, size: 28),
                const SizedBox(height: 6),
                Text(sound['name'], style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVolumeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Symbols.volume_up_rounded, color: _primaryColor),
              const SizedBox(width: 12),
              const Text('Volume', style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${(_volume * 100).round()}%', style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 12),
          Slider(value: _volume, onChanged: (v) { HapticFeedback.selectionClick(); setState(() => _volume = v); }, activeColor: _primaryColor, inactiveColor: _primaryColor.withValues(alpha: 0.2)),
        ],
      ),
    );
  }

  Widget _buildAutoPlayCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: _autoPlay ? _primaryColor.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(Symbols.play_circle_rounded, color: _autoPlay ? _primaryColor : Colors.grey)),
          const SizedBox(width: 16),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Auto-Play', style: TextStyle(fontWeight: FontWeight.w600)), Text('Play sound when session starts', style: TextStyle(color: Colors.grey, fontSize: 13))])),
          AppSwitch(value: _autoPlay, onChanged: (v) { HapticFeedback.lightImpact(); setState(() => _autoPlay = v); }),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(onPressed: _saveSettings, style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text('Save Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
    );
  }
}
