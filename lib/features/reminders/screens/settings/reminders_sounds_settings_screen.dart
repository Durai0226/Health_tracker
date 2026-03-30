import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reminders Sounds Settings Screen
class RemindersSoundsSettingsScreen extends StatefulWidget {
  const RemindersSoundsSettingsScreen({super.key});

  @override
  State<RemindersSoundsSettingsScreen> createState() => _RemindersSoundsSettingsScreenState();
}

class _RemindersSoundsSettingsScreenState extends State<RemindersSoundsSettingsScreen> {
  String _selectedSound = 'chime';
  bool _isLoading = true;

  static const _primaryColor = Color(0xFFEC4899);

  final List<Map<String, dynamic>> _sounds = [
    {'id': 'chime', 'name': 'Gentle Chime', 'icon': Icons.music_note},
    {'id': 'bell', 'name': 'Classic Bell', 'icon': Icons.notifications},
    {'id': 'ping', 'name': 'Quick Ping', 'icon': Icons.circle_notifications},
    {'id': 'melody', 'name': 'Soft Melody', 'icon': Icons.audiotrack},
    {'id': 'alert', 'name': 'Alert Tone', 'icon': Icons.warning},
    {'id': 'none', 'name': 'Silent', 'icon': Icons.volume_off},
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
        _selectedSound = prefs.getString('reminders_sound_type') ?? 'chime';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reminders_sound_type', _selectedSound);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Sound saved!'), backgroundColor: _primaryColor, behavior: SnackBarBehavior.floating));
      Navigator.pop(context);
    }
  }

  void _playPreview(String soundId) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Playing ${_sounds.firstWhere((s) => s['id'] == soundId)['name']}...'), duration: const Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF2F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFDF2F8),
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.black87), onPressed: () => Navigator.pop(context)),
        title: const Text('Notification Sounds', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: _isLoading ? Center(child: CircularProgressIndicator(color: _primaryColor)) : Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _sounds.length,
              itemBuilder: (context, index) => _buildSoundCard(_sounds[index]),
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: _buildSaveButton()),
        ],
      ),
    );
  }

  Widget _buildSoundCard(Map<String, dynamic> sound) {
    final isSelected = _selectedSound == sound['id'];
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); setState(() => _selectedSound = sound['id']); },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? _primaryColor : Colors.transparent, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: isSelected ? _primaryColor.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(sound['icon'], color: isSelected ? _primaryColor : Colors.grey),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(sound['name'], style: TextStyle(fontWeight: FontWeight.w600, color: isSelected ? _primaryColor : Colors.black87))),
            IconButton(icon: Icon(Icons.play_circle_outline, color: _primaryColor), onPressed: () => _playPreview(sound['id'])),
            if (isSelected) Icon(Icons.check_circle, color: _primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(width: double.infinity, height: 56, child: ElevatedButton(onPressed: _saveSettings, style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text('Save Sound', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))));
  }
}
