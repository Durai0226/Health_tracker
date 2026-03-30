import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/evernote_theme.dart';
import '../../data/services/notes_service.dart';

/// Side drawer navigation for Notes feature
/// Evernote-style dark theme with lime green accent
class NotesDrawer extends StatelessWidget {
  final VoidCallback? onAllNotesTap;
  final VoidCallback? onTasksTap;
  final VoidCallback? onNotebooksTap;
  final VoidCallback? onTagsTap;
  final VoidCallback? onTrashTap;
  final VoidCallback? onSettingsTap;
  final String? userName;
  final String? userEmail;
  final String? avatarUrl;

  const NotesDrawer({
    super.key,
    this.onAllNotesTap,
    this.onTasksTap,
    this.onNotebooksTap,
    this.onTagsTap,
    this.onTrashTap,
    this.onSettingsTap,
    this.userName,
    this.userEmail,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final notesService = NotesService();
    final totalNotes = notesService.getAllNotes().length;
    final trashedNotes = notesService.getAllNotes().where((n) => n.isDeleted).length;
    final tags = notesService.getAllTags();

    return Drawer(
      backgroundColor: EvernoteTheme.background,
      child: SafeArea(
        child: Column(
          children: [
            // User profile header
            _buildHeader(),
            
            const SizedBox(height: 8),
            
            // Navigation items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _buildNavItem(
                    icon: Icons.notes_rounded,
                    label: 'All Notes',
                    count: totalNotes,
                    isSelected: true,
                    onTap: () {
                      Navigator.pop(context);
                      onAllNotesTap?.call();
                    },
                  ),
                  
                  _buildNavItem(
                    icon: Icons.checklist_rounded,
                    label: 'Tasks',
                    count: notesService.getIncompleteTasks().length,
                    onTap: () {
                      Navigator.pop(context);
                      onTasksTap?.call();
                    },
                  ),
                  
                  _buildNavItem(
                    icon: Icons.book_rounded,
                    label: 'Notebooks',
                    onTap: () {
                      Navigator.pop(context);
                      onNotebooksTap?.call();
                    },
                  ),
                  
                  _buildNavItem(
                    icon: Icons.tag_rounded,
                    label: 'Tags',
                    count: tags.length,
                    onTap: () {
                      Navigator.pop(context);
                      onTagsTap?.call();
                    },
                  ),
                  
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(color: EvernoteTheme.divider, height: 1),
                  ),
                  
                  _buildNavItem(
                    icon: Icons.delete_outline_rounded,
                    label: 'Trash',
                    count: trashedNotes,
                    onTap: () {
                      Navigator.pop(context);
                      onTrashTap?.call();
                    },
                  ),
                  
                  _buildNavItem(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onTap: () {
                      Navigator.pop(context);
                      onSettingsTap?.call();
                    },
                  ),
                ],
              ),
            ),
            
            // Bottom section with sync status
            _buildBottomSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            EvernoteTheme.primary.withOpacity(0.15),
            EvernoteTheme.primaryDark.withOpacity(0.05),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: EvernoteTheme.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: EvernoteTheme.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: avatarUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildDefaultAvatar(),
                    ),
                  )
                : _buildDefaultAvatar(),
          ),
          
          const SizedBox(height: 16),
          
          // User name
          Text(
            userName ?? 'Welcome',
            style: EvernoteTheme.headlineSmall.copyWith(
              color: EvernoteTheme.textPrimary,
            ),
          ),
          
          const SizedBox(height: 4),
          
          // Email
          if (userEmail != null)
            Text(
              userEmail!,
              style: EvernoteTheme.bodySmall.copyWith(
                color: EvernoteTheme.textTertiary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Center(
      child: Text(
        (userName?.isNotEmpty == true ? userName![0] : 'U').toUpperCase(),
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: EvernoteTheme.textOnPrimary,
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    int? count,
    bool isSelected = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: EvernoteTheme.durationFast,
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? EvernoteTheme.primary.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected
                  ? EvernoteTheme.primary
                  : EvernoteTheme.textSecondary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: EvernoteTheme.titleMedium.copyWith(
                  color: isSelected
                      ? EvernoteTheme.primary
                      : EvernoteTheme.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            if (count != null && count > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? EvernoteTheme.primary.withOpacity(0.2)
                      : EvernoteTheme.surface,
                  borderRadius: BorderRadius.circular(EvernoteTheme.radiusFull),
                ),
                child: Text(
                  '$count',
                  style: EvernoteTheme.labelSmall.copyWith(
                    color: isSelected
                        ? EvernoteTheme.primary
                        : EvernoteTheme.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: EvernoteTheme.divider, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: EvernoteTheme.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Synced',
            style: EvernoteTheme.bodySmall.copyWith(
              color: EvernoteTheme.textTertiary,
            ),
          ),
          const Spacer(),
          Text(
            'Notes v2.0',
            style: EvernoteTheme.caption.copyWith(
              color: EvernoteTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
