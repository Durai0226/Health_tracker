import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/models/page_model.dart';
import '../../../theme/livescribe_theme.dart';
import '../canvas/paper_background.dart';

/// Bottom sheet for selecting page templates
class TemplatePicker extends StatelessWidget {
  final NotebookTemplate? selectedTemplate;
  final ValueChanged<NotebookTemplate> onTemplateSelected;

  const TemplatePicker({
    super.key,
    this.selectedTemplate,
    required this.onTemplateSelected,
  });

  static Future<NotebookTemplate?> show(
    BuildContext context, {
    NotebookTemplate? currentTemplate,
  }) {
    return showModalBottomSheet<NotebookTemplate>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => TemplatePicker(
        selectedTemplate: currentTemplate,
        onTemplateSelected: (template) {
          Navigator.pop(ctx, template);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? LivescribeTheme.darkSurface : LivescribeTheme.surfaceWhite,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Title
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Choose Template',
                style: LivescribeTheme.headlineMedium.copyWith(
                  color: isDark ? LivescribeTheme.darkTextPrimary : LivescribeTheme.textPrimary,
                ),
              ),
            ),

            // Template grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.75,
                children: NotebookTemplate.values.map((template) {
                  return _TemplateCard(
                    template: template,
                    isSelected: selectedTemplate == template,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onTemplateSelected(template);
                    },
                    isDark: isDark,
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final NotebookTemplate template;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _TemplateCard({
    required this.template,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: LivescribeTheme.durationFast,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
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
            // Preview
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                child: PaperBackground(
                  template: template,
                ),
              ),
            ),
            
            // Label
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? LivescribeTheme.primary
                    : (isDark ? LivescribeTheme.darkSurfaceLight : LivescribeTheme.surfaceGray),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _getIcon(),
                    size: 14,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? LivescribeTheme.darkTextSecondary : LivescribeTheme.textSecondary),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _getName(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? LivescribeTheme.darkTextPrimary : LivescribeTheme.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon() {
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

  String _getName() {
    switch (template) {
      case NotebookTemplate.blank:
        return 'Blank';
      case NotebookTemplate.lined:
        return 'Lined';
      case NotebookTemplate.grid:
        return 'Grid';
      case NotebookTemplate.dotted:
        return 'Dotted';
      case NotebookTemplate.cornell:
        return 'Cornell';
      case NotebookTemplate.music:
        return 'Music';
    }
  }
}

/// Quick template selector row (for inline use)
class TemplateSelector extends StatelessWidget {
  final NotebookTemplate selectedTemplate;
  final ValueChanged<NotebookTemplate> onTemplateChanged;

  const TemplateSelector({
    super.key,
    required this.selectedTemplate,
    required this.onTemplateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: NotebookTemplate.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final template = NotebookTemplate.values[index];
          final isSelected = selectedTemplate == template;

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onTemplateChanged(template);
            },
            child: AnimatedContainer(
              duration: LivescribeTheme.durationFast,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected
                    ? LivescribeTheme.primary
                    : (isDark ? LivescribeTheme.darkSurfaceLight : LivescribeTheme.surfaceGray),
                borderRadius: BorderRadius.circular(20),
                border: isSelected
                    ? null
                    : Border.all(
                        color: isDark ? LivescribeTheme.darkBorder : LivescribeTheme.border,
                      ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getIcon(template),
                    size: 16,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? LivescribeTheme.darkTextSecondary : LivescribeTheme.textSecondary),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getName(template),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? LivescribeTheme.darkTextPrimary : LivescribeTheme.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _getIcon(NotebookTemplate template) {
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

  String _getName(NotebookTemplate template) {
    switch (template) {
      case NotebookTemplate.blank:
        return 'Blank';
      case NotebookTemplate.lined:
        return 'Lined';
      case NotebookTemplate.grid:
        return 'Grid';
      case NotebookTemplate.dotted:
        return 'Dotted';
      case NotebookTemplate.cornell:
        return 'Cornell';
      case NotebookTemplate.music:
        return 'Music';
    }
  }
}
