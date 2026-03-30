import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/services/notes_service.dart';
import '../../theme/evernote_theme.dart';
import '../../../../core/widgets/toast/toast.dart';

/// Settings screen for Notes feature
class NotesSettingsScreen extends StatefulWidget {
  const NotesSettingsScreen({super.key});

  @override
  State<NotesSettingsScreen> createState() => _NotesSettingsScreenState();
}

class _NotesSettingsScreenState extends State<NotesSettingsScreen> {
  final NotesService _notesService = NotesService();
  bool _autoSave = true;
  bool _syncEnabled = true;
  bool _showPreview = true;
  String _defaultView = 'Grid';
  String _sortBy = 'Date modified';
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EvernoteTheme.background,
      appBar: AppBar(
        backgroundColor: EvernoteTheme.background,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: EvernoteTheme.textPrimary,
          ),
        ),
        title: Text(
          'Notes Settings',
          style: EvernoteTheme.headlineSmall,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // General Section
          _buildSectionHeader('General'),
          _buildSettingTile(
            icon: Icons.save_outlined,
            title: 'Auto-save',
            subtitle: 'Automatically save notes while editing',
            trailing: Switch.adaptive(
              value: _autoSave,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                setState(() => _autoSave = value);
              },
              activeColor: EvernoteTheme.primary,
            ),
          ),
          _buildSettingTile(
            icon: Icons.cloud_sync_outlined,
            title: 'Sync',
            subtitle: 'Sync notes across devices',
            trailing: Switch.adaptive(
              value: _syncEnabled,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                setState(() => _syncEnabled = value);
              },
              activeColor: EvernoteTheme.primary,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Display Section
          _buildSectionHeader('Display'),
          _buildSettingTile(
            icon: Icons.preview_outlined,
            title: 'Show preview',
            subtitle: 'Show content preview in note cards',
            trailing: Switch.adaptive(
              value: _showPreview,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                setState(() => _showPreview = value);
              },
              activeColor: EvernoteTheme.primary,
            ),
          ),
          _buildSettingTile(
            icon: Icons.grid_view_outlined,
            title: 'Default view',
            subtitle: _defaultView,
            onTap: () => _showViewPicker(),
          ),
          _buildSettingTile(
            icon: Icons.sort_outlined,
            title: 'Sort by',
            subtitle: _sortBy,
            onTap: () => _showSortPicker(),
          ),
          
          const SizedBox(height: 24),
          
          // Data Section
          _buildSectionHeader('Data'),
          _buildSettingTile(
            icon: Icons.download_outlined,
            title: 'Export notes',
            subtitle: 'Export all notes as JSON',
            onTap: () => _exportNotes(),
          ),
          _buildSettingTile(
            icon: Icons.upload_outlined,
            title: 'Import notes',
            subtitle: 'Import notes from backup',
            onTap: () => _importNotes(),
          ),
          _buildSettingTile(
            icon: Icons.delete_outline_rounded,
            title: 'Clear trash',
            subtitle: 'Permanently delete all trashed notes',
            isDestructive: true,
            onTap: () => _showClearTrashDialog(),
          ),
          
          const SizedBox(height: 40),
          
          // Version info
          Center(
            child: Text(
              'Notes v2.0.0',
              style: EvernoteTheme.caption.copyWith(
                color: EvernoteTheme.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: EvernoteTheme.titleSmall.copyWith(
          color: EvernoteTheme.primary,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? EvernoteTheme.error : EvernoteTheme.textPrimary;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: EvernoteTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EvernoteTheme.cardBorder),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (isDestructive ? EvernoteTheme.error : EvernoteTheme.primary)
                .withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: isDestructive ? EvernoteTheme.error : EvernoteTheme.primary,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: EvernoteTheme.titleMedium.copyWith(color: color),
        ),
        subtitle: Text(
          subtitle,
          style: EvernoteTheme.bodySmall.copyWith(
            color: EvernoteTheme.textTertiary,
          ),
        ),
        trailing: trailing ?? (onTap != null
            ? const Icon(
                Icons.chevron_right_rounded,
                color: EvernoteTheme.textTertiary,
              )
            : null),
      ),
    );
  }

  void _showViewPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: EvernoteTheme.modalDecoration,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: EvernoteTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Default View',
                  style: EvernoteTheme.titleLarge,
                ),
              ),
              _OptionTile(
                icon: Icons.grid_view_rounded,
                label: 'Grid',
                isSelected: _defaultView == 'Grid',
                onTap: () {
                  setState(() => _defaultView = 'Grid');
                  Navigator.pop(ctx);
                },
              ),
              _OptionTile(
                icon: Icons.view_list_rounded,
                label: 'List',
                isSelected: _defaultView == 'List',
                onTap: () {
                  setState(() => _defaultView = 'List');
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showSortPicker() {
    final options = [
      'Date modified',
      'Date created',
      'Title A-Z',
      'Title Z-A',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: EvernoteTheme.modalDecoration,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: EvernoteTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Sort By',
                  style: EvernoteTheme.titleLarge,
                ),
              ),
              ...options.map((option) => _OptionTile(
                icon: Icons.sort_rounded,
                label: option,
                isSelected: _sortBy == option,
                onTap: () {
                  setState(() => _sortBy = option);
                  Navigator.pop(ctx);
                },
              )),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportNotes() async {
    if (_isExporting) return;
    
    setState(() => _isExporting = true);
    
    try {
      await _notesService.initialize();
      final notes = _notesService.getAllNotes();
      
      if (notes.isEmpty) {
        if (mounted) {
          NotesToast.info(context, message: 'No notes to export');
        }
        return;
      }
      
      // Convert notes to JSON
      final notesJson = notes.map((n) => n.toJson()).toList();
      final jsonString = const JsonEncoder.withIndent('  ').convert({
        'exportedAt': DateTime.now().toIso8601String(),
        'noteCount': notes.length,
        'notes': notesJson,
      });
      
      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/dlyminder_notes_backup.json');
      await file.writeAsString(jsonString);
      
      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Dlyminder Notes Backup (${notes.length} notes)',
      );
      
      if (mounted) {
          NotesToast.success(context, message: 'Exported ${notes.length} notes successfully');
      }
    } catch (e) {
      if (mounted) {
        NotesToast.error(context, message: 'Export failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  void _importNotes() {
    NotesToast.info(context, message: 'Import feature coming soon');
  }

  void _showClearTrashDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EvernoteTheme.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Clear Trash?',
          style: EvernoteTheme.titleLarge,
        ),
        content: Text(
          'This will permanently delete all notes in trash. This action cannot be undone.',
          style: EvernoteTheme.bodyMedium.copyWith(
            color: EvernoteTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: EvernoteTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _clearTrash();
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: EvernoteTheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _clearTrash() async {
    try {
      await _notesService.initialize();
      final trashedNotes = _notesService.getAllNotes().where((n) => n.isDeleted).toList();
      
      if (trashedNotes.isEmpty) {
        if (mounted) {
          NotesToast.info(context, message: 'Trash is already empty');
        }
        return;
      }
      
      // Permanently delete all trashed notes
      for (final note in trashedNotes) {
        await _notesService.deleteNote(note.id, permanent: true);
      }
      
      if (mounted) {
        NotesToast.permanentlyDeleted(context, message: 'Permanently deleted ${trashedNotes.length} notes');
      }
    } catch (e) {
      if (mounted) {
        NotesToast.error(context, message: 'Failed to clear trash: $e');
      }
    }
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? EvernoteTheme.primary : EvernoteTheme.textSecondary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: EvernoteTheme.bodyLarge.copyWith(
                  color: isSelected ? EvernoteTheme.primary : EvernoteTheme.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_rounded,
                size: 22,
                color: EvernoteTheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}
