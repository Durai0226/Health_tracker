import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/note_model.dart';
import '../../theme/evernote_theme.dart';
import 'category_chips.dart';

/// Note card widget with Evernote dark theme styling
/// Supports grid and list view modes with swipe actions
class NoteCard extends StatelessWidget {
  final NoteModel note;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;
  final VoidCallback? onArchive;
  final bool isListView;

  const NoteCard({
    super.key,
    required this.note,
    this.onTap,
    this.onLongPress,
    this.onDelete,
    this.onArchive,
    this.isListView = false,
  });

  @override
  Widget build(BuildContext context) {
    final card = isListView ? _buildListCard() : _buildGridCard();
    
    // Only add swipe actions for list view
    if (isListView && (onDelete != null || onArchive != null)) {
      return Dismissible(
        key: Key(note.id),
        background: _buildSwipeBackground(
          alignment: Alignment.centerLeft,
          color: EvernoteTheme.warning,
          icon: Icons.archive_rounded,
          label: 'Archive',
        ),
        secondaryBackground: _buildSwipeBackground(
          alignment: Alignment.centerRight,
          color: EvernoteTheme.error,
          icon: Icons.delete_rounded,
          label: 'Delete',
        ),
        confirmDismiss: (direction) async {
          HapticFeedback.mediumImpact();
          if (direction == DismissDirection.startToEnd) {
            onArchive?.call();
            return false; // Don't dismiss, let callback handle it
          } else {
            onDelete?.call();
            return false;
          }
        },
        child: card,
      );
    }
    
    return card;
  }

  Widget _buildSwipeBackground({
    required Alignment alignment,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(EvernoteTheme.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: alignment == Alignment.centerLeft
            ? [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ]
            : [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(icon, color: Colors.white, size: 22),
              ],
      ),
    );
  }

  Widget _buildGridCard() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        onLongPress?.call();
      },
      child: Container(
        decoration: BoxDecoration(
          color: _getCardColor(),
          borderRadius: BorderRadius.circular(EvernoteTheme.radiusMd),
          border: Border.all(
            color: EvernoteTheme.cardBorder,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image thumbnail (if available)
            if (note.coverImagePath != null || note.attachments.isNotEmpty)
              _buildThumbnail()
            else
              _buildColorHeader(),
            
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      note.title.isEmpty ? 'Untitled' : note.title,
                      style: EvernoteTheme.titleMedium.copyWith(
                        color: EvernoteTheme.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    
                    // Preview text
                    Expanded(
                      child: Text(
                        _getPreviewText(),
                        style: EvernoteTheme.bodySmall.copyWith(
                          color: EvernoteTheme.textTertiary,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    
                    // Bottom row
                    _buildBottomRow(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListCard() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        onLongPress?.call();
      },
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: EvernoteTheme.cardBackground,
          borderRadius: BorderRadius.circular(EvernoteTheme.radiusMd),
          border: Border.all(
            color: EvernoteTheme.cardBorder,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Thumbnail or color strip
            if (note.coverImagePath != null || note.attachments.isNotEmpty)
              _buildListThumbnail()
            else
              _buildColorStrip(),
            
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Title
                    Text(
                      note.title.isEmpty ? 'Untitled' : note.title,
                      style: EvernoteTheme.titleMedium.copyWith(
                        color: EvernoteTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    
                    // Preview
                    Text(
                      _getPreviewText(),
                      style: EvernoteTheme.bodySmall.copyWith(
                        color: EvernoteTheme.textTertiary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const Spacer(),
                    
                    // Date (lime green as per design)
                    Text(
                      _formatDate(note.updatedAt),
                      style: EvernoteTheme.caption.copyWith(
                        color: EvernoteTheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Pin indicator
            if (note.isPinned)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  Icons.push_pin_rounded,
                  size: 18,
                  color: EvernoteTheme.pinned,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: EvernoteTheme.surfaceLight,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(EvernoteTheme.radiusMd - 1),
        ),
      ),
      child: Stack(
        children: [
          if (note.coverImagePath != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(EvernoteTheme.radiusMd - 1),
              ),
              child: Image.asset(
                note.coverImagePath!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: 120,
                errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
              ),
            )
          else if (note.attachments.isNotEmpty)
            _buildPlaceholderImage()
          else
            _buildPlaceholderImage(),
          
          // Gradient overlay for better text readability
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(EvernoteTheme.radiusMd - 1),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    EvernoteTheme.cardBackground.withOpacity(0.7),
                  ],
                ),
              ),
            ),
          ),
          
          // Pin indicator overlay
          if (note.isPinned)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: EvernoteTheme.background.withOpacity(0.85),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.push_pin_rounded,
                  size: 14,
                  color: EvernoteTheme.pinned,
                ),
              ),
            ),
            
          // Favorite indicator
          if (note.isFavorite && !note.isPinned)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: EvernoteTheme.background.withOpacity(0.85),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.star_rounded,
                  size: 14,
                  color: EvernoteTheme.favorite,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildColorHeader() {
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: _getNoteColor(),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(EvernoteTheme.radiusMd - 1),
        ),
      ),
    );
  }

  Widget _buildListThumbnail() {
    return Container(
      width: 80,
      decoration: BoxDecoration(
        color: EvernoteTheme.surfaceLight,
        borderRadius: const BorderRadius.horizontal(
          left: Radius.circular(EvernoteTheme.radiusMd - 1),
        ),
      ),
      child: note.coverImagePath != null
          ? ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(EvernoteTheme.radiusMd - 1),
              ),
              child: Image.asset(
                note.coverImagePath!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
              ),
            )
          : _buildPlaceholderImage(),
    );
  }

  Widget _buildColorStrip() {
    return Container(
      width: 6,
      decoration: BoxDecoration(
        color: _getNoteColor(),
        borderRadius: const BorderRadius.horizontal(
          left: Radius.circular(EvernoteTheme.radiusMd - 1),
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: EvernoteTheme.surfaceLight,
      child: Center(
        child: Icon(
          _getPlaceholderIcon(),
          size: 28,
          color: EvernoteTheme.textMuted,
        ),
      ),
    );
  }

  Widget _buildBottomRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Date (lime green as per design)
        Text(
          _formatDate(note.updatedAt),
          style: EvernoteTheme.caption.copyWith(
            color: EvernoteTheme.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
        
        // Icons row
        Row(
          children: [
            if (note.isFavorite)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(
                  Icons.star_rounded,
                  size: 14,
                  color: EvernoteTheme.favorite,
                ),
              ),
            if (note.voiceRecordingPath != null)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(
                  Icons.mic_rounded,
                  size: 14,
                  color: EvernoteTheme.textTertiary,
                ),
              ),
            if (note.attachments.isNotEmpty)
              Icon(
                Icons.attach_file_rounded,
                size: 14,
                color: EvernoteTheme.textTertiary,
              ),
          ],
        ),
      ],
    );
  }

  Color _getCardColor() {
    if (note.color != null) {
      try {
        final color = Color(int.parse(note.color!.replaceFirst('#', '0xFF')));
        return color.withOpacity(0.08);
      } catch (_) {}
    }
    return EvernoteTheme.cardBackground;
  }

  Color _getNoteColor() {
    if (note.color != null) {
      try {
        return Color(int.parse(note.color!.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }
    return EvernoteTheme.primary;
  }

  IconData _getPlaceholderIcon() {
    if (note.voiceRecordingPath != null) return Icons.mic_rounded;
    if (note.attachments.isNotEmpty) return Icons.attach_file_rounded;
    if (note.noteType == NoteType.checklist) return Icons.checklist_rounded;
    return Icons.note_rounded;
  }

  String _getPreviewText() {
    if (note.content.isEmpty) return 'No content';
    
    // Try to extract plain text from content
    String text = note.content;
    
    // Remove JSON formatting if present
    if (text.startsWith('[')) {
      try {
        // This is likely Quill Delta format, extract plain text
        text = text.replaceAll(RegExp(r'\[|\]|\{[^}]*\}|"insert"|"attributes"|[:,]'), '');
        text = text.replaceAll(RegExp(r'\\n'), ' ');
        text = text.trim();
      } catch (_) {}
    }
    
    return text;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        if (diff.inMinutes < 1) return 'Just now';
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

/// Compact note preview for search results
class NotePreviewTile extends StatelessWidget {
  final NoteModel note;
  final String? highlightText;
  final VoidCallback? onTap;

  const NotePreviewTile({
    super.key,
    required this.note,
    this.highlightText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Color indicator
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: _getNoteColor(),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title.isEmpty ? 'Untitled' : note.title,
                    style: EvernoteTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(note.updatedAt),
                    style: EvernoteTheme.caption,
                  ),
                ],
              ),
            ),
            
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: EvernoteTheme.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Color _getNoteColor() {
    if (note.color != null) {
      try {
        return Color(int.parse(note.color!.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }
    return EvernoteTheme.primary;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}';
  }
}
