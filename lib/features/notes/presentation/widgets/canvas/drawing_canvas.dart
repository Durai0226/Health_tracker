import 'package:flutter/material.dart';
import '../../../data/models/page_model.dart';
import '../../../data/models/stroke_model.dart';
import '../../../theme/livescribe_theme.dart';
import 'canvas_controller.dart';
import 'stroke_painter.dart';
import 'paper_background.dart';

/// Main drawing canvas widget for handwriting and sketching
class DrawingCanvas extends StatefulWidget {
  final CanvasController controller;
  final NotebookTemplate template;
  final Color? backgroundColor;
  final bool enableZoom;
  final bool enablePan;
  final VoidCallback? onDrawStart;
  final VoidCallback? onDrawEnd;

  const DrawingCanvas({
    super.key,
    required this.controller,
    this.template = NotebookTemplate.blank,
    this.backgroundColor,
    this.enableZoom = true,
    this.enablePan = true,
    this.onDrawStart,
    this.onDrawEnd,
  });

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  double _baseScale = 1.0;
  Offset _basePan = Offset.zero;
  int _activePointers = 0;
  bool _isPanning = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  void _handlePointerDown(PointerDownEvent event) {
    _activePointers++;
    
    if (_activePointers > 1) {
      // Multiple fingers - switch to pan/zoom mode
      _isPanning = true;
      return;
    }

    // Single finger - start drawing
    final position = _transformPosition(event.localPosition);
    final pressure = event.pressure;
    widget.controller.startStroke(position, pressure: pressure);
    widget.onDrawStart?.call();
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_isPanning || _activePointers > 1) return;

    final position = _transformPosition(event.localPosition);
    final pressure = event.pressure;
    widget.controller.updateStroke(position, pressure: pressure);
  }

  void _handlePointerUp(PointerUpEvent event) {
    _activePointers--;
    
    if (_activePointers == 0) {
      _isPanning = false;
    }

    if (widget.controller.isDrawing) {
      widget.controller.endStroke();
      widget.onDrawEnd?.call();
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _activePointers = 0;
    _isPanning = false;
    
    if (widget.controller.isDrawing) {
      widget.controller.endStroke();
    }
  }

  Offset _transformPosition(Offset position) {
    // Transform screen position to canvas position accounting for zoom and pan
    final zoom = widget.controller.zoomLevel;
    final pan = widget.controller.panOffset;
    
    return Offset(
      (position.dx - pan.dx) / zoom,
      (position.dy - pan.dy) / zoom,
    );
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _baseScale = widget.controller.zoomLevel;
    _basePan = widget.controller.panOffset;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (!widget.enableZoom && !widget.enablePan) return;

    if (widget.enableZoom && details.scale != 1.0) {
      final newScale = (_baseScale * details.scale).clamp(0.5, 3.0);
      widget.controller.setZoom(newScale);
    }

    if (widget.enablePan) {
      final newPan = _basePan + details.focalPointDelta;
      widget.controller.setPan(newPan);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onScaleStart: _handleScaleStart,
      onScaleUpdate: _handleScaleUpdate,
      child: Listener(
        onPointerDown: _handlePointerDown,
        onPointerMove: _handlePointerMove,
        onPointerUp: _handlePointerUp,
        onPointerCancel: _handlePointerCancel,
        child: ClipRect(
          child: CustomPaint(
            painter: PaperBackgroundPainter(
              template: widget.template,
              backgroundColor: widget.backgroundColor,
              isDark: isDark,
              zoom: widget.controller.zoomLevel,
              pan: widget.controller.panOffset,
            ),
            foregroundPainter: StrokePainter(
              strokes: widget.controller.strokes,
              currentStroke: widget.controller.currentStroke,
              zoom: widget.controller.zoomLevel,
              pan: widget.controller.panOffset,
            ),
            child: Container(
              color: Colors.transparent,
            ),
          ),
        ),
      ),
    );
  }
}

/// A canvas with all tools and controls built-in
class DrawingCanvasWithTools extends StatefulWidget {
  final PageModel? initialPage;
  final NotebookTemplate template;
  final Function(PageModel)? onSave;
  final VoidCallback? onClose;

  const DrawingCanvasWithTools({
    super.key,
    this.initialPage,
    this.template = NotebookTemplate.blank,
    this.onSave,
    this.onClose,
  });

  @override
  State<DrawingCanvasWithTools> createState() => _DrawingCanvasWithToolsState();
}

class _DrawingCanvasWithToolsState extends State<DrawingCanvasWithTools>
    with SingleTickerProviderStateMixin {
  late CanvasController _controller;
  late AnimationController _toolbarAnimController;
  bool _showToolbar = true;

  @override
  void initState() {
    super.initState();
    _controller = CanvasController();
    
    if (widget.initialPage != null) {
      _controller.initWithPage(widget.initialPage!);
    }

    _toolbarAnimController = AnimationController(
      duration: LivescribeTheme.durationNormal,
      vsync: this,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _toolbarAnimController.dispose();
    super.dispose();
  }

  void _toggleToolbar() {
    setState(() {
      _showToolbar = !_showToolbar;
      if (_showToolbar) {
        _toolbarAnimController.forward();
      } else {
        _toolbarAnimController.reverse();
      }
    });
  }

  void _save() {
    final page = _controller.getUpdatedPage();
    if (page != null) {
      widget.onSave?.call(page);
      _controller.markSaved();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? LivescribeTheme.darkSurface : LivescribeTheme.surfaceWhite,
      body: Stack(
        children: [
          // Main canvas
          Positioned.fill(
            child: DrawingCanvas(
              controller: _controller,
              template: widget.template,
              onDrawStart: () {
                if (_showToolbar) _toggleToolbar();
              },
            ),
          ),

          // Top toolbar
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: FadeTransition(
              opacity: _toolbarAnimController,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _toolbarAnimController,
                  curve: Curves.easeOutCubic,
                )),
                child: _buildTopToolbar(isDark),
              ),
            ),
          ),

          // Bottom pen toolbar
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 16,
            right: 16,
            child: FadeTransition(
              opacity: _toolbarAnimController,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _toolbarAnimController,
                  curve: Curves.easeOutCubic,
                )),
                child: _buildPenToolbar(isDark),
              ),
            ),
          ),

          // Show toolbar button when hidden
          if (!_showToolbar)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              right: 16,
              child: _buildShowToolbarButton(isDark),
            ),
        ],
      ),
    );
  }

  Widget _buildTopToolbar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: LivescribeTheme.toolbarDecoration(isDark: isDark),
      child: Row(
        children: [
          // Close button
          _ToolbarButton(
            icon: Icons.close_rounded,
            onTap: () {
              if (_controller.hasChanges) {
                _showSaveDialog();
              } else {
                widget.onClose?.call();
              }
            },
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          
          // Undo/Redo
          _ToolbarButton(
            icon: Icons.undo_rounded,
            onTap: _controller.canUndo ? _controller.undo : null,
            isDark: isDark,
            enabled: _controller.canUndo,
          ),
          const SizedBox(width: 4),
          _ToolbarButton(
            icon: Icons.redo_rounded,
            onTap: _controller.canRedo ? _controller.redo : null,
            isDark: isDark,
            enabled: _controller.canRedo,
          ),

          const Spacer(),

          // Zoom controls
          _ToolbarButton(
            icon: Icons.zoom_out_rounded,
            onTap: () => _controller.setZoom(_controller.zoomLevel - 0.25),
            isDark: isDark,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '${(_controller.zoomLevel * 100).round()}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? LivescribeTheme.darkTextPrimary : LivescribeTheme.textPrimary,
              ),
            ),
          ),
          _ToolbarButton(
            icon: Icons.zoom_in_rounded,
            onTap: () => _controller.setZoom(_controller.zoomLevel + 0.25),
            isDark: isDark,
          ),

          const Spacer(),

          // Clear and Save
          _ToolbarButton(
            icon: Icons.delete_outline_rounded,
            onTap: _controller.strokes.isNotEmpty ? _controller.clear : null,
            isDark: isDark,
            enabled: _controller.strokes.isNotEmpty,
          ),
          const SizedBox(width: 8),
          _ToolbarButton(
            icon: Icons.check_rounded,
            onTap: _save,
            isDark: isDark,
            isPrimary: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPenToolbar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: LivescribeTheme.toolbarDecoration(isDark: isDark),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tool selection
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _PenToolButton(
                icon: Icons.edit_rounded,
                label: 'Pen',
                isSelected: _controller.currentTool == DrawingTool.pen,
                onTap: () => _controller.setTool(DrawingTool.pen),
                isDark: isDark,
              ),
              _PenToolButton(
                icon: Icons.brush_rounded,
                label: 'Pencil',
                isSelected: _controller.currentTool == DrawingTool.pencil,
                onTap: () => _controller.setTool(DrawingTool.pencil),
                isDark: isDark,
              ),
              _PenToolButton(
                icon: Icons.highlight_rounded,
                label: 'Highlight',
                isSelected: _controller.currentTool == DrawingTool.highlighter,
                onTap: () => _controller.setTool(DrawingTool.highlighter),
                isDark: isDark,
              ),
              _PenToolButton(
                icon: Icons.auto_fix_high_rounded,
                label: 'Marker',
                isSelected: _controller.currentTool == DrawingTool.marker,
                onTap: () => _controller.setTool(DrawingTool.marker),
                isDark: isDark,
              ),
              _PenToolButton(
                icon: Icons.cleaning_services_rounded,
                label: 'Eraser',
                isSelected: _controller.currentTool == DrawingTool.eraser,
                onTap: () => _controller.setTool(DrawingTool.eraser),
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Color selection
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: LivescribeTheme.inkColors.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final color = LivescribeTheme.inkColors[index];
                final colorHex = '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
                final isSelected = _controller.currentColor == colorHex;
                
                return GestureDetector(
                  onTap: () => _controller.setColor(colorHex),
                  child: AnimatedContainer(
                    duration: LivescribeTheme.durationFast,
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected 
                            ? LivescribeTheme.primary 
                            : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: isSelected ? LivescribeTheme.shadowSm : null,
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: _getContrastColor(color),
                          )
                        : null,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          
          // Stroke width selection
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StrokeWidthButton(
                width: LivescribeTheme.penStrokeWidthThin,
                isSelected: _controller.currentStrokeWidth == LivescribeTheme.penStrokeWidthThin,
                onTap: () => _controller.setStrokeWidth(LivescribeTheme.penStrokeWidthThin),
                isDark: isDark,
              ),
              const SizedBox(width: 16),
              _StrokeWidthButton(
                width: LivescribeTheme.penStrokeWidthMedium,
                isSelected: _controller.currentStrokeWidth == LivescribeTheme.penStrokeWidthMedium,
                onTap: () => _controller.setStrokeWidth(LivescribeTheme.penStrokeWidthMedium),
                isDark: isDark,
              ),
              const SizedBox(width: 16),
              _StrokeWidthButton(
                width: LivescribeTheme.penStrokeWidthThick,
                isSelected: _controller.currentStrokeWidth == LivescribeTheme.penStrokeWidthThick,
                onTap: () => _controller.setStrokeWidth(LivescribeTheme.penStrokeWidthThick),
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShowToolbarButton(bool isDark) {
    return GestureDetector(
      onTap: _toggleToolbar,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: LivescribeTheme.primary,
          shape: BoxShape.circle,
          boxShadow: LivescribeTheme.shadowMd,
        ),
        child: const Icon(
          Icons.edit_rounded,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Color _getContrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  void _showSaveDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save changes?'),
        content: const Text('You have unsaved changes. Would you like to save before closing?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onClose?.call();
            },
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _save();
              widget.onClose?.call();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool isDark;
  final bool enabled;
  final bool isPrimary;

  const _ToolbarButton({
    required this.icon,
    this.onTap,
    required this.isDark,
    this.enabled = true,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isPrimary 
              ? LivescribeTheme.primary 
              : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isPrimary
              ? Colors.white
              : (enabled
                  ? (isDark ? LivescribeTheme.darkTextPrimary : LivescribeTheme.textPrimary)
                  : (isDark ? Colors.white24 : Colors.black26)),
        ),
      ),
    );
  }
}

class _PenToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _PenToolButton({
    required this.icon,
    required this.label,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? LivescribeTheme.primary.withOpacity(0.1) 
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected 
                ? LivescribeTheme.primary 
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected 
                  ? LivescribeTheme.primary 
                  : (isDark ? LivescribeTheme.darkTextSecondary : LivescribeTheme.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected 
                    ? LivescribeTheme.primary 
                    : (isDark ? LivescribeTheme.darkTextSecondary : LivescribeTheme.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StrokeWidthButton extends StatelessWidget {
  final double width;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _StrokeWidthButton({
    required this.width,
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
            width: width * 4,
            height: width * 4,
            decoration: BoxDecoration(
              color: isSelected 
                  ? LivescribeTheme.primary 
                  : (isDark ? LivescribeTheme.darkTextSecondary : LivescribeTheme.textSecondary),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
