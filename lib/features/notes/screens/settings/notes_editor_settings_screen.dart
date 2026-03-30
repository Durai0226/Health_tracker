import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Notes Editor Settings Screen
class NotesEditorSettingsScreen extends StatefulWidget {
  const NotesEditorSettingsScreen({super.key});

  @override
  State<NotesEditorSettingsScreen> createState() => _NotesEditorSettingsScreenState();
}

class _NotesEditorSettingsScreenState extends State<NotesEditorSettingsScreen> {
  double _fontSize = 16;
  String _fontFamily = 'default';
  bool _spellCheck = true;
  bool _autoSave = true;
  bool _isLoading = true;

  static const _primaryColor = Color(0xFFFF9800);

  final List<Map<String, String>> _fonts = [
    {'id': 'default', 'name': 'System Default'},
    {'id': 'serif', 'name': 'Serif'},
    {'id': 'mono', 'name': 'Monospace'},
    {'id': 'handwriting', 'name': 'Handwriting'},
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
        _fontSize = prefs.getDouble('notes_font_size') ?? 16;
        _fontFamily = prefs.getString('notes_font_family') ?? 'default';
        _spellCheck = prefs.getBool('notes_spell_check') ?? true;
        _autoSave = prefs.getBool('notes_auto_save') ?? true;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('notes_font_size', _fontSize);
    await prefs.setString('notes_font_family', _fontFamily);
    await prefs.setBool('notes_spell_check', _spellCheck);
    await prefs.setBool('notes_auto_save', _autoSave);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Editor settings saved!'), backgroundColor: _primaryColor, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
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
        title: const Text('Editor Settings', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFontSizeCard(),
                  const SizedBox(height: 16),
                  _buildFontFamilyCard(),
                  const SizedBox(height: 16),
                  _buildToggleCard(Icons.spellcheck, 'Spell Check', 'Highlight spelling errors', _spellCheck, (v) => setState(() => _spellCheck = v)),
                  const SizedBox(height: 12),
                  _buildToggleCard(Icons.save_outlined, 'Auto Save', 'Save notes automatically', _autoSave, (v) => setState(() => _autoSave = v)),
                  const SizedBox(height: 32),
                  _buildSaveButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildFontSizeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.format_size, color: _primaryColor),
              const SizedBox(width: 12),
              const Text('Font Size', style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${_fontSize.round()}px', style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 16),
          Slider(value: _fontSize, min: 12, max: 24, divisions: 12, activeColor: _primaryColor, onChanged: (v) { HapticFeedback.selectionClick(); setState(() => _fontSize = v); }),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
            child: Text('Preview text at ${_fontSize.round()}px', style: TextStyle(fontSize: _fontSize)),
          ),
        ],
      ),
    );
  }

  Widget _buildFontFamilyCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(Icons.font_download_outlined, color: _primaryColor), const SizedBox(width: 12), const Text('Font Family', style: TextStyle(fontWeight: FontWeight.w600))]),
          const SizedBox(height: 16),
          ...(_fonts.map((font) => RadioListTile<String>(
            value: font['id']!,
            groupValue: _fontFamily,
            onChanged: (v) { HapticFeedback.lightImpact(); setState(() => _fontFamily = v!); },
            title: Text(font['name']!),
            activeColor: _primaryColor,
            contentPadding: EdgeInsets.zero,
          ))),
        ],
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
