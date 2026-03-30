import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/notebook_model.dart';
import '../../data/models/page_model.dart';
import '../../theme/livescribe_theme.dart';

/// Notebook card widget with cover preview
class LivescribeNotebookCard extends StatelessWidget {
  final NotebookModel notebook;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const LivescribeNotebookCard({
    super.key,
    required this.notebook,
    required this.onTap,
    this.onLongPress,
  });

  Color get _coverColor {
    try {
      return Color(int.parse(notebook.coverColor.replaceFirst('#', '0xFF')));
    } catch (_) {
      return LivescribeTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        onLongPress?.call();
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? LivescribeTheme.darkSurfaceLight : LivescribeTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(16),
          boxShadow: LivescribeTheme.shadowMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cover
            Expanded(
              flex: 3,
              child: _buildCover(isDark),
            ),
            // Info
            Expanded(
              flex: 2,
              child: _buildInfo(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCover(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _coverColor,
            _coverColor.withOpacity(0.8),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Stack(
        children: [
          // Notebook lines decoration
          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: CustomPaint(
                painter: _NotebookLinesPainter(color: Colors.white.withOpacity(0.1)),
              ),
            ),
          ),
          
          // Thumbnail preview or icon
          if (notebook.lastPageThumbnail != null)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Container(
                  color: Colors.white.withOpacity(0.1),
                  // TODO: Load actual thumbnail
                ),
              ),
            )
          else
            Center(
              child: Icon(
                _getTemplateIcon(),
                size: 40,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          
          // Pinned indicator
          if (notebook.isPinned)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.star_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          
          // Page count badge
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                notebook.pageCountText,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfo(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            notebook.title,
            style: LivescribeTheme.titleMedium.copyWith(
              color: isDark ? LivescribeTheme.darkTextPrimary : LivescribeTheme.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 12,
                color: isDark ? LivescribeTheme.darkTextSecondary : LivescribeTheme.textTertiary,
              ),
              const SizedBox(width: 4),
              Text(
                notebook.lastModifiedText,
                style: LivescribeTheme.caption.copyWith(
                  color: isDark ? LivescribeTheme.darkTextSecondary : LivescribeTheme.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getTemplateIcon() {
    switch (notebook.defaultTemplate) {
      case NotebookTemplate.blank:
        return Icons.note_outlined;
      case NotebookTemplate.lined:
        return Icons.format_align_left_rounded;
      case NotebookTemplate.grid:
        return Icons.grid_4x4_rounded;
      case NotebookTemplate.dotted:
        return Icons.more_horiz_rounded;
      case NotebookTemplate.cornell:
        return Icons.view_module_rounded;
      case NotebookTemplate.music:
        return Icons.music_note_rounded;
    }
  }
}

class _NotebookLinesPainter extends CustomPainter {
  final Color color;

  _NotebookLinesPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const spacing = 12.0;
    double y = spacing;
    
    while (y < size.height) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
      y += spacing;
    }
  }

  @override
  bool shouldRepaint(covariant _NotebookLinesPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// Compact notebook list item
class LivescribeNotebookListItem extends StatelessWidget {
  final NotebookModel notebook;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const LivescribeNotebookListItem({
    super.key,
    required this.notebook,
    required this.onTap,
    this.onLongPress,
  });

  Color get _coverColor {
    try {
      return Color(int.parse(notebook.coverColor.replaceFirst('#', '0xFF')));
    } catch (_) {
      return LivescribeTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? LivescribeTheme.darkSurfaceLight : LivescribeTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? LivescribeTheme.darkBorder : LivescribeTheme.border,
          ),
        ),
        child: Row(
          children: [
            // Color indicator
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _coverColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.book_rounded,
                color: Colors.white.withOpacity(0.8),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notebook.title,
                    style: LivescribeTheme.titleMedium.copyWith(
                      color: isDark ? LivescribeTheme.darkTextPrimary : LivescribeTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${notebook.pageCountText} • ${notebook.lastModifiedText}',
                    style: LivescribeTheme.caption.copyWith(
                      color: isDark ? LivescribeTheme.darkTextSecondary : LivescribeTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            
            // Pinned
            if (notebook.isPinned)
              Icon(
                Icons.star_rounded,
                size: 20,
                color: LivescribeTheme.warning,
              ),
          ],
        ),
      ),
    );
  }
}
