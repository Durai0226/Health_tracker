import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/models/stroke_model.dart';
import '../../../theme/livescribe_theme.dart';
import '../canvas/canvas_controller.dart';

/// Floating pen toolbar for drawing tools selection
class PenToolbar extends StatefulWidget {
  final CanvasController controller;
  final VoidCallback? onClose;
  final bool showColorPicker;
  final bool showStrokeWidth;

  const PenToolbar({
    super.key,
    required this.controller,
    this.onClose,
    this.showColorPicker = true,
    this.showStrokeWidth = true,
  });

  @override
  State<PenToolbar> createState() => _PenToolbarState();
}

class _PenToolbarState extends State<PenToolbar> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: LivescribeTheme.durationNormal,
      vsync: this,
    );
    widget.controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    _animController.dispose();
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  void _toggleExpand() {
    HapticFeedback.lightImpact();
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: LivescribeTheme.durationNormal,
      curve: LivescribeTheme.curveDefault,
      padding: EdgeInsets.all(_expanded ? 16 : 12),
      decoration: LivescribeTheme.toolbarDecoration(isDark: isDark),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tool selection row
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ToolButton(
                icon: Icons.edit_rounded,
                isSelected: widget.controller.currentTool == DrawingTool.pen,
                onTap: () => widget.controller.setTool(DrawingTool.pen),
                isDark: isDark,
                tooltip: 'Pen',
              ),
              const SizedBox(width: 8),
              _ToolButton(
                icon: Icons.brush_rounded,
                isSelected: widget.controller.currentTool == DrawingTool.pencil,
                onTap: () => widget.controller.setTool(DrawingTool.pencil),
                isDark: isDark,
                tooltip: 'Pencil',
              ),
              const SizedBox(width: 8),
              _ToolButton(
                icon: Icons.highlight_rounded,
                isSelected: widget.controller.currentTool == DrawingTool.highlighter,
                onTap: () => widget.controller.setTool(DrawingTool.highlighter),
                isDark: isDark,
                tooltip: 'Highlighter',
              ),
              const SizedBox(width: 8),
              _ToolButton(
                icon: Icons.auto_fix_high_rounded,
                isSelected: widget.controller.currentTool == DrawingTool.marker,
                onTap: () => widget.controller.setTool(DrawingTool.marker),
                isDark: isDark,
                tooltip: 'Marker',
              ),
              const SizedBox(width: 8),
              _ToolButton(
                icon: Icons.cleaning_services_rounded,
                isSelected: widget.controller.currentTool == DrawingTool.eraser,
                onTap: () => widget.controller.setTool(DrawingTool.eraser),
                isDark: isDark,
                tooltip: 'Eraser',
              ),
              const SizedBox(width: 12),
              // Expand button
              GestureDetector(
                onTap: _toggleExpand,
                child: AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: LivescribeTheme.durationNormal,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 20,
                      color: isDark ? LivescribeTheme.darkTextSecondary : LivescribeTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Expanded options
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                if (widget.showColorPicker) ...[
                  const SizedBox(height: 16),
                  _buildColorPicker(isDark),
                ],
                if (widget.showStrokeWidth) ...[
                  const SizedBox(height: 16),
                  _buildStrokeWidthPicker(isDark),
                ],
              ],
            ),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: LivescribeTheme.durationNormal,
          ),
        ],
      ),
    );
  }

  Widget _buildColorPicker(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Color',
          style: LivescribeTheme.labelSmall.copyWith(
            color: isDark ? LivescribeTheme.darkTextSecondary : LivescribeTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: LivescribeTheme.inkColors.map((color) {
            final colorHex = '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
            final isSelected = widget.controller.currentColor == colorHex;

            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                widget.controller.setColor(colorHex);
              },
              child: AnimatedContainer(
                duration: LivescribeTheme.durationFast,
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? LivescribeTheme.primary : Colors.transparent,
                    width: 2.5,
                  ),
                  boxShadow: isSelected ? LivescribeTheme.shadowSm : null,
                ),
                child: isSelected
                    ? Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: _getContrastColor(color),
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStrokeWidthPicker(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Stroke Width',
          style: LivescribeTheme.labelSmall.copyWith(
            color: isDark ? LivescribeTheme.darkTextSecondary : LivescribeTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _StrokeWidthOption(
              width: LivescribeTheme.penStrokeWidthThin,
              label: 'Thin',
              isSelected: widget.controller.currentStrokeWidth == LivescribeTheme.penStrokeWidthThin,
              onTap: () => widget.controller.setStrokeWidth(LivescribeTheme.penStrokeWidthThin),
              isDark: isDark,
            ),
            const SizedBox(width: 16),
            _StrokeWidthOption(
              width: LivescribeTheme.penStrokeWidthMedium,
              label: 'Medium',
              isSelected: widget.controller.currentStrokeWidth == LivescribeTheme.penStrokeWidthMedium,
              onTap: () => widget.controller.setStrokeWidth(LivescribeTheme.penStrokeWidthMedium),
              isDark: isDark,
            ),
            const SizedBox(width: 16),
            _StrokeWidthOption(
              width: LivescribeTheme.penStrokeWidthThick,
              label: 'Thick',
              isSelected: widget.controller.currentStrokeWidth == LivescribeTheme.penStrokeWidthThick,
              onTap: () => widget.controller.setStrokeWidth(LivescribeTheme.penStrokeWidthThick),
              isDark: isDark,
            ),
          ],
        ),
      ],
    );
  }

  Color _getContrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;
  final String tooltip;

  const _ToolButton({
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: LivescribeTheme.durationFast,
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isSelected
                ? LivescribeTheme.primary
                : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isSelected
                ? Colors.white
                : (isDark ? LivescribeTheme.darkTextPrimary : LivescribeTheme.textPrimary),
          ),
        ),
      ),
    );
  }
}

class _StrokeWidthOption extends StatelessWidget {
  final double width;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _StrokeWidthOption({
    required this.width,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Column(
        children: [
          AnimatedContainer(
            duration: LivescribeTheme.durationFast,
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isSelected
                  ? LivescribeTheme.primary.withOpacity(0.1)
                  : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? LivescribeTheme.primary
                    : (isDark ? Colors.white12 : Colors.black12),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Container(
                width: width * 3,
                height: width * 3,
                decoration: BoxDecoration(
                  color: isSelected
                      ? LivescribeTheme.primary
                      : (isDark ? LivescribeTheme.darkTextSecondary : LivescribeTheme.textSecondary),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: LivescribeTheme.caption.copyWith(
              color: isSelected
                  ? LivescribeTheme.primary
                  : (isDark ? LivescribeTheme.darkTextSecondary : LivescribeTheme.textTertiary),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
