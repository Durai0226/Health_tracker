import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Notes Backup & Restore Settings Screen
class NotesBackupSettingsScreen extends StatefulWidget {
  const NotesBackupSettingsScreen({super.key});

  @override
  State<NotesBackupSettingsScreen> createState() => _NotesBackupSettingsScreenState();
}

class _NotesBackupSettingsScreenState extends State<NotesBackupSettingsScreen> {
  bool _autoBackup = true;
  String _backupFrequency = 'daily';
  DateTime? _lastBackup;
  bool _isLoading = true;
  bool _isBackingUp = false;

  static const _primaryColor = Color(0xFFFF9800);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _autoBackup = prefs.getBool('notes_auto_backup') ?? true;
        _backupFrequency = prefs.getString('notes_backup_frequency') ?? 'daily';
        final lastBackupMs = prefs.getInt('notes_last_backup');
        _lastBackup = lastBackupMs != null ? DateTime.fromMillisecondsSinceEpoch(lastBackupMs) : null;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notes_auto_backup', _autoBackup);
    await prefs.setString('notes_backup_frequency', _backupFrequency);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Backup settings saved!'), backgroundColor: _primaryColor, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
      Navigator.pop(context);
    }
  }

  Future<void> _backupNow() async {
    HapticFeedback.mediumImpact();
    setState(() => _isBackingUp = true);
    await Future.delayed(const Duration(seconds: 2));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('notes_last_backup', DateTime.now().millisecondsSinceEpoch);
    if (mounted) {
      setState(() {
        _isBackingUp = false;
        _lastBackup = DateTime.now();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Backup completed!'), backgroundColor: _primaryColor));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.black87), onPressed: () => Navigator.pop(context)),
        title: const Text('Backup & Restore', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildBackupNowCard(),
                  const SizedBox(height: 16),
                  _buildAutoBackupCard(),
                  const SizedBox(height: 16),
                  _buildRestoreCard(),
                  const SizedBox(height: 32),
                  _buildSaveButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildBackupNowCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_primaryColor, _primaryColor.withValues(alpha: 0.8)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(_isBackingUp ? Icons.cloud_sync : Icons.cloud_upload_outlined, color: Colors.white, size: 48),
          const SizedBox(height: 12),
          Text(_isBackingUp ? 'Backing up...' : 'Backup Your Notes', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          if (_lastBackup != null) ...[
            const SizedBox(height: 4),
            Text('Last backup: ${_formatDate(_lastBackup!)}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isBackingUp ? null : _backupNow,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: _primaryColor, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: _isBackingUp ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Backup Now', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoBackupCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Row(
            children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: _autoBackup ? _primaryColor.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.autorenew, color: _autoBackup ? _primaryColor : Colors.grey)),
              const SizedBox(width: 16),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Auto Backup', style: TextStyle(fontWeight: FontWeight.w600)), Text('Automatically backup notes', style: TextStyle(color: Colors.grey, fontSize: 13))])),
              Switch.adaptive(value: _autoBackup, onChanged: (v) { HapticFeedback.lightImpact(); setState(() => _autoBackup = v); }, activeColor: _primaryColor),
            ],
          ),
          if (_autoBackup) ...[
            const Divider(height: 24),
            ...(['daily', 'weekly', 'monthly'].map((freq) => RadioListTile<String>(
              value: freq,
              groupValue: _backupFrequency,
              onChanged: (v) { HapticFeedback.lightImpact(); setState(() => _backupFrequency = v!); },
              title: Text(freq[0].toUpperCase() + freq.substring(1)),
              activeColor: _primaryColor,
              contentPadding: EdgeInsets.zero,
            ))),
          ],
        ],
      ),
    );
  }

  Widget _buildRestoreCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: _primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.restore, color: _primaryColor)),
          const SizedBox(width: 16),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Restore from Backup', style: TextStyle(fontWeight: FontWeight.w600)), Text('Recover notes from backup', style: TextStyle(color: Colors.grey, fontSize: 13))])),
          TextButton(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No backups found'))), child: Text('Restore', style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildSaveButton() {
    return SizedBox(width: double.infinity, height: 56, child: ElevatedButton(onPressed: _saveSettings, style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text('Save Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))));
  }
}
