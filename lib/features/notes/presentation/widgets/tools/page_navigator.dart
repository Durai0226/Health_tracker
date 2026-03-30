import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/models/page_model.dart';
import '../../../theme/livescribe_theme.dart';
import '../canvas/stroke_painter.dart';

/// Horizontal page navigator with thumbnails
class PageNavigator extends StatefulWidget {
  final List<PageModel> pages;
  final int currentPageIndex;
  final ValueChanged<int> onPageSelected;
  final VoidCallback onAddPage;
  final ValueChanged<int>? onDeletePage;
  final bool canDelete;

  const PageNavigator({
    super.key,
    required this.pages,
    required this.currentPageIndex,
    required this.onPageSelected,
    required this.onAddPage,
    this.onDeletePage,
    this.canDelete = true,
  });

  @override
  State<PageNavigator> createState() => _PageNavigatorState();
}

class _PageNavigatorState extends State<PageNavigator> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentPage());
  }

  @override
  void didUpdateWidget(PageNavigator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPageIndex != widget.currentPageIndex) {
      _scrollToCurrentPage();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentPage() {
    if (!_scrollController.hasClients) return;
    
    const itemWidth = 80.0;
    const spacing = 12.0;
    final targetOffset = widget.currentPageIndex * (itemWidth + spacing);
    final maxOffset = _scrollController.position.maxScrollExtent;
    
    _scrollController.animateTo(
      targetOffset.clamp(0.0, maxOffset),
      duration: LivescribeTheme.durationNormal,
      curve: LivescribeTheme.curveDefault,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: isDark ? LivescribeTheme.darkSurface : LivescribeTheme.surfaceWhite,
        border: Border(
          top: BorderSide(
            color: isDark ? LivescribeTheme.darkBorder : LivescribeTheme.border,
          ),
        ),
      ),
      child: Row(
        children: [
          // Page list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: widget.pages.length + 1, // +1 for add button
              itemBuilder: (context, index) {
                if (index == widget.pages.length) {
                  return _buildAddPageButton(isDark);
                }
                return _buildPageThumbnail(index, isDark);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageThumbnail(int index, bool isDark) {
    final page = widget.pages[index];
    final isSelected = index == widget.currentPageIndex;

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onPageSelected(index);
        },
        onLongPress: widget.canDelete && widget.pages.length > 1
            ? () => _showDeleteDialog(index)
            : null,
        child: AnimatedContainer(
          duration: LivescribeTheme.durationFast,
          width: 60,
          decoration: BoxDecoration(
            color: isDark ? LivescribeTheme.darkSurfaceLight : LivescribeTheme.surfaceWhite,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? LivescribeTheme.primary
                  : (isDark ? LivescribeTheme.darkBorder : LivescribeTheme.border),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected ? LivescribeTheme.shadowSm : null,
          ),
          child: Column(
            children: [
              // Page preview
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                  child: Container(
                    color: _getPageBackgroundColor(page, isDark),
                    child: page.strokes.isNotEmpty
                        ? CustomPaint(
                            painter: StrokePreviewPainter(
                              strokes: page.strokes,
                              originalSize: const Size(400, 600),
                            ),
                            child: Container(),
                          )
                        : Center(
                            child: Icon(
                              _getTemplateIcon(page.template),
                              size: 16,
                              color: isDark ? Colors.white24 : Colors.black12,
                            ),
                          ),
                  ),
                ),
              ),
              // Page number
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? LivescribeTheme.primary
                      : (isDark ? LivescribeTheme.darkSurfaceLight : LivescribeTheme.surfaceGray),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(7)),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? LivescribeTheme.darkTextSecondary : LivescribeTheme.textSecondary),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddPageButton(bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onAddPage();
      },
      child: Container(
        width: 60,
        decoration: BoxDecoration(
          color: isDark ? LivescribeTheme.darkSurfaceLight : LivescribeTheme.surfaceGray,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? LivescribeTheme.darkBorder : LivescribeTheme.border,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_rounded,
              size: 24,
              color: LivescribeTheme.primary,
            ),
            const SizedBox(height: 4),
            Text(
              'Add',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: LivescribeTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPageBackgroundColor(PageModel page, bool isDark) {
    if (page.backgroundColor != null) {
      try {
        return Color(int.parse(page.backgroundColor!.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }

    switch (page.template) {
      case NotebookTemplate.lined:
        return isDark ? LivescribeTheme.darkSurface : LivescribeTheme.canvasBeige;
      case NotebookTemplate.grid:
        return isDark ? LivescribeTheme.darkSurface : LivescribeTheme.canvasGrid;
      default:
        return isDark ? LivescribeTheme.darkSurface : LivescribeTheme.canvasWhite;
    }
  }

  IconData _getTemplateIcon(NotebookTemplate template) {
    switch (template) {
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

  void _showDeleteDialog(int index) {
    HapticFeedback.mediumImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? LivescribeTheme.darkSurfaceLight : LivescribeTheme.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Page ${index + 1}?',
          style: TextStyle(
            color: isDark ? LivescribeTheme.darkTextPrimary : LivescribeTheme.textPrimary,
          ),
        ),
        content: Text(
          'This action cannot be undone.',
          style: TextStyle(
            color: isDark ? LivescribeTheme.darkTextSecondary : LivescribeTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? LivescribeTheme.darkTextSecondary : LivescribeTheme.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDeletePage?.call(index);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: LivescribeTheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
