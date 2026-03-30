import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reminders Notification Settings Screen
class RemindersNotificationsSettingsScreen extends StatefulWidget {
  const RemindersNotificationsSettingsScreen({super.key});

  @override
  State<RemindersNotificationsSettingsScreen> createState() => _RemindersNotificationsSettingsScreenState();
}

class _RemindersNotificationsSettingsScreenState extends State<RemindersNotificationsSettingsScreen> {
  bool _pushNotifications = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _showPreview = true;
  int _snoozeMinutes = 10;
  bool _isLoading = true;

  static const _primaryColor = Color(0xFFEC4899);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _pushNotifications = prefs.getBool('reminders_push') ?? true;
        _soundEnabled = prefs.getBool('reminders_sound') ?? true;
        _vibrationEnabled = prefs.getBool('reminders_vibration') ?? true;
        _showPreview = prefs.getBool('reminders_preview') ?? true;
        _snoozeMinutes = prefs.getInt('reminders_snooze') ?? 10;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reminders_push', _pushNotifications);
    await prefs.setBool('reminders_sound', _soundEnabled);
    await prefs.setBool('reminders_vibration', _vibrationEnabled);
    await prefs.setBool('reminders_preview', _showPreview);
    await prefs.setInt('reminders_snooze', _snoozeMinutes);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Notification settings saved!'), backgroundColor: _primaryColor, behavior: SnackBarBehavior.floating));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF2F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFDF2F8),
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.black87), onPressed: () => Navigator.pop(context)),
        title: const Text('Notification Settings', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: _isLoading ? Center(child: CircularProgressIndicator(color: _primaryColor)) : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildToggleCard(Icons.notifications, 'Push Notifications', 'Receive reminder alerts', _pushNotifications, (v) => setState(() => _pushNotifications = v)),
            const SizedBox(height: 12),
            _buildToggleCard(Icons.volume_up, 'Sound', 'Play notification sound', _soundEnabled, (v) => setState(() => _soundEnabled = v)),
            const SizedBox(height: 12),
            _buildToggleCard(Icons.vibration, 'Vibration', 'Vibrate on notification', _vibrationEnabled, (v) => setState(() => _vibrationEnabled = v)),
            const SizedBox(height: 12),
            _buildToggleCard(Icons.preview, 'Show Preview', 'Display reminder content', _showPreview, (v) => setState(() => _showPreview = v)),
            const SizedBox(height: 12),
            _buildSnoozeCard(),
            const SizedBox(height: 32),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleCard(IconData icon, String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: value ? _primaryColor.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: value ? _primaryColor : Colors.grey)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w600)), Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13))])),
          Switch.adaptive(value: value, onChanged: (v) { HapticFeedback.lightImpact(); onChanged(v); }, activeColor: _primaryColor),
        ],
      ),
    );
  }

  Widget _buildSnoozeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(Icons.snooze, color: _primaryColor), const SizedBox(width: 12), const Text('Default Snooze Time', style: TextStyle(fontWeight: FontWeight.w600)), const Spacer(), Text('$_snoozeMinutes min', style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w500))]),
          const SizedBox(height: 12),
          Slider(value: _snoozeMinutes.toDouble(), min: 5, max: 60, divisions: 11, activeColor: _primaryColor, onChanged: (v) { HapticFeedback.selectionClick(); setState(() => _snoozeMinutes = v.round()); }),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(width: double.infinity, height: 56, child: ElevatedButton(onPressed: _saveSettings, style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text('Save Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))));
  }
}
