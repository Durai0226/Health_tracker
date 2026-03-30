import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Notes Export Settings Screen
class NotesExportSettingsScreen extends StatefulWidget {
  const NotesExportSettingsScreen({super.key});

  @override
  State<NotesExportSettingsScreen> createState() => _NotesExportSettingsScreenState();
}

class _NotesExportSettingsScreenState extends State<NotesExportSettingsScreen> {
  String _exportFormat = 'pdf';
  bool _includeImages = true;
  bool _includeMetadata = false;
  bool _isExporting = false;

  static const _primaryColor = Color(0xFFFF9800);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.black87), onPressed: () => Navigator.pop(context)),
        title: const Text('Export Notes', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Export Format', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _buildFormatSelector(),
            const SizedBox(height: 24),
            const Text('Options', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _buildToggleCard(Icons.image_outlined, 'Include Images', 'Export attached images', _includeImages, (v) => setState(() => _includeImages = v)),
            const SizedBox(height: 12),
            _buildToggleCard(Icons.info_outline, 'Include Metadata', 'Export dates and tags', _includeMetadata, (v) => setState(() => _includeMetadata = v)),
            const SizedBox(height: 24),
            _buildExportOptions(),
            const SizedBox(height: 32),
            _buildExportButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatSelector() {
    final formats = [
      {'id': 'pdf', 'name': 'PDF', 'icon': Icons.picture_as_pdf},
      {'id': 'txt', 'name': 'Plain Text', 'icon': Icons.text_snippet},
      {'id': 'md', 'name': 'Markdown', 'icon': Icons.code},
      {'id': 'html', 'name': 'HTML', 'icon': Icons.html},
    ];

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: formats.map((fmt) {
          final isSelected = _exportFormat == fmt['id'];
          return Expanded(
            child: GestureDetector(
              onTap: () { HapticFeedback.lightImpact(); setState(() => _exportFormat = fmt['id'] as String); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: isSelected ? _primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(fmt['icon'] as IconData, color: isSelected ? Colors.white : Colors.grey, size: 24),
                    const SizedBox(height: 4),
                    Text(fmt['name'] as String, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.grey, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
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

  Widget _buildExportOptions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          _buildExportOption(Icons.note, 'Export All Notes', 'Export your entire collection', () => _exportNotes('all')),
          const Divider(height: 24),
          _buildExportOption(Icons.push_pin, 'Export Pinned', 'Export only pinned notes', () => _exportNotes('pinned')),
          const Divider(height: 24),
          _buildExportOption(Icons.folder_outlined, 'Export by Folder', 'Choose specific folders', () => _exportNotes('folder')),
        ],
      ),
    );
  }

  Widget _buildExportOption(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: _primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: _primaryColor, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w500)), Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12))])),
          Icon(Icons.chevron_right, color: Colors.grey.shade400),
        ],
      ),
    );
  }

  Widget _buildExportButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isExporting ? null : () => _exportNotes('all'),
        style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        child: _isExporting
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.download), const SizedBox(width: 8), Text('Export as ${_exportFormat.toUpperCase()}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))]),
      ),
    );
  }

  Future<void> _exportNotes(String type) async {
    HapticFeedback.mediumImpact();
    setState(() => _isExporting = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Notes exported as ${_exportFormat.toUpperCase()}!'), backgroundColor: _primaryColor));
    }
  }
}
