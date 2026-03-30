import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/evernote_theme.dart';

/// Horizontal scrollable category chips for filtering notes
/// Matches Evernote's dark theme design
class CategoryChips extends StatefulWidget {
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;

  const CategoryChips({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  @override
  State<CategoryChips> createState() => _CategoryChipsState();
}

class _CategoryChipsState extends State<CategoryChips> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void didUpdateWidget(CategoryChips oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCategory != widget.selectedCategory) {
      _scrollToSelected();
    }
  }

  void _scrollToSelected() {
    final index = widget.categories.indexOf(widget.selectedCategory);
    if (index >= 0 && _scrollController.hasClients) {
      final targetOffset = (index * 100.0).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        targetOffset,
        duration: EvernoteTheme.durationNormal,
        curve: EvernoteTheme.curveDefault,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.categories.length,
        itemBuilder: (context, index) {
          final category = widget.categories[index];
          final isSelected = category == widget.selectedCategory;
          
          return Padding(
            padding: EdgeInsets.only(
              right: index < widget.categories.length - 1 ? 10 : 0,
            ),
            child: _CategoryChip(
              label: category,
              isSelected: isSelected,
              color: _getCategoryColor(index),
              onTap: () {
                HapticFeedback.selectionClick();
                widget.onCategoryChanged(category);
              },
            ),
          );
        },
      ),
    );
  }

  Color _getCategoryColor(int index) {
    if (index >= EvernoteTheme.categoryColors.length) {
      return EvernoteTheme.categoryColors[index % EvernoteTheme.categoryColors.length];
    }
    return EvernoteTheme.categoryColors[index];
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: EvernoteTheme.durationFast,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : EvernoteTheme.surface,
          borderRadius: BorderRadius.circular(EvernoteTheme.radiusFull),
          border: Border.all(
            color: isSelected ? color : EvernoteTheme.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isSelected 
                      ? EvernoteTheme.textOnPrimary.withOpacity(0.9) 
                      : color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected 
                    ? EvernoteTheme.textOnPrimary 
                    : EvernoteTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Single category badge for note cards
class CategoryBadge extends StatelessWidget {
  final String category;
  final Color? color;
  final bool small;

  const CategoryBadge({
    super.key,
    required this.category,
    this.color,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: (color ?? EvernoteTheme.primary).withOpacity(0.15),
        borderRadius: BorderRadius.circular(EvernoteTheme.radiusFull),
      ),
      child: Text(
        category,
        style: TextStyle(
          fontSize: small ? 10 : 11,
          fontWeight: FontWeight.w600,
          color: color ?? EvernoteTheme.primary,
        ),
      ),
    );
  }
}
