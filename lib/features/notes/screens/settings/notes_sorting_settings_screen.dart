import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Notes Sorting & Display Settings Screen
class NotesSortingSettingsScreen extends StatefulWidget {
  const NotesSortingSettingsScreen({super.key});

  @override
  State<NotesSortingSettingsScreen> createState() => _NotesSortingSettingsScreenState();
}

class _NotesSortingSettingsScreenState extends State<NotesSortingSettingsScreen> {
  String _sortBy = 'modified';
  bool _sortDescending = true;
  String _viewMode = 'grid';
  bool _showPreview = true;
  bool _isLoading = true;

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
        _sortBy = prefs.getString('notes_sort_by') ?? 'modified';
        _sortDescending = prefs.getBool('notes_sort_desc') ?? true;
        _viewMode = prefs.getString('notes_view_mode') ?? 'grid';
        _showPreview = prefs.getBool('notes_show_preview') ?? true;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notes_sort_by', _sortBy);
    await prefs.setBool('notes_sort_desc', _sortDescending);
    await prefs.setString('notes_view_mode', _viewMode);
    await prefs.setBool('notes_show_preview', _showPreview);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Display settings saved!'), backgroundColor: _primaryColor, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
      Navigator.pop(context);
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
        title: const Text('Sorting & Display', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sort By', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  _buildSortOptions(),
                  const SizedBox(height: 24),
                  const Text('View Mode', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  _buildViewModeSelector(),
                  const SizedBox(height: 16),
                  _buildToggleCard(Icons.preview, 'Show Preview', 'Display note content preview', _showPreview, (v) => setState(() => _showPreview = v)),
                  const SizedBox(height: 32),
                  _buildSaveButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildSortOptions() {
    final options = [
      {'id': 'modified', 'name': 'Last Modified', 'icon': Icons.update},
      {'id': 'created', 'name': 'Date Created', 'icon': Icons.calendar_today},
      {'id': 'title', 'name': 'Title', 'icon': Icons.sort_by_alpha},
      {'id': 'color', 'name': 'Color', 'icon': Icons.palette},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          ...options.map((opt) => _buildSortOption(opt)),
          const Divider(height: 24),
          Row(
            children: [
              Icon(Icons.arrow_downward, color: _primaryColor, size: 20),
              const SizedBox(width: 12),
              const Expanded(child: Text('Descending Order', style: TextStyle(fontWeight: FontWeight.w500))),
              Switch.adaptive(value: _sortDescending, onChanged: (v) { HapticFeedback.lightImpact(); setState(() => _sortDescending = v); }, activeColor: _primaryColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSortOption(Map<String, dynamic> option) {
    final isSelected = _sortBy == option['id'];
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); setState(() => _sortBy = option['id']); },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: isSelected ? _primaryColor.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(option['icon'], color: isSelected ? _primaryColor : Colors.grey, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(option['name'], style: TextStyle(fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal, color: isSelected ? _primaryColor : Colors.black87))),
            if (isSelected) Icon(Icons.check_circle, color: _primaryColor, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildViewModeSelector() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          _buildViewModeOption('grid', 'Grid', Icons.grid_view_rounded),
          const SizedBox(width: 8),
          _buildViewModeOption('list', 'List', Icons.view_list_rounded),
          const SizedBox(width: 8),
          _buildViewModeOption('compact', 'Compact', Icons.view_headline_rounded),
        ],
      ),
    );
  }

  Widget _buildViewModeOption(String id, String label, IconData icon) {
    final isSelected = _viewMode == id;
    return Expanded(
      child: GestureDetector(
        onTap: () { HapticFeedback.lightImpact(); setState(() => _viewMode = id); },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? _primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.grey, size: 24),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.grey, fontWeight: FontWeight.w500)),
            ],
          ),
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

  Widget _buildSaveButton() {
    return SizedBox(width: double.infinity, height: 56, child: ElevatedButton(onPressed: _saveSettings, style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text('Save Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))));
  }
}
