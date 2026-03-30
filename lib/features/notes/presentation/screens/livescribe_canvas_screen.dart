import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/notebook_model.dart';
import '../../data/models/page_model.dart';
import '../../theme/livescribe_theme.dart';
import '../widgets/canvas/drawing_canvas.dart';
import '../widgets/canvas/canvas_controller.dart';
import '../widgets/tools/page_navigator.dart';
import '../widgets/tools/template_picker.dart';
import '../widgets/tools/pen_toolbar.dart';

/// Full-screen canvas editor for handwriting
class LivescribeCanvasScreen extends StatefulWidget {
  final NotebookModel? notebook;
  final bool isNewNotebook;
  final int? initialPageIndex;

  const LivescribeCanvasScreen({
    super.key,
    this.notebook,
    this.isNewNotebook = false,
    this.initialPageIndex,
  });

  @override
  State<LivescribeCanvasScreen> createState() => _LivescribeCanvasScreenState();
}

class _LivescribeCanvasScreenState extends State<LivescribeCanvasScreen>
    with TickerProviderStateMixin {
  final _uuid = const Uuid();
  
  late CanvasController _canvasController;
  late AnimationController _toolbarAnimController;
  
  NotebookModel? _notebook;
  List<PageModel> _pages = [];
  int _currentPageIndex = 0;
  bool _showToolbar = true;
  bool _isLoading = true;
  bool _hasUnsavedChanges = false;
  NotebookTemplate _currentTemplate = NotebookTemplate.blank;

  @override
  void initState() {
    super.initState();
    _canvasController = CanvasController();
    _toolbarAnimController = AnimationController(
      duration: LivescribeTheme.durationNormal,
      vsync: this,
      value: 1.0,
    );
    
    _canvasController.addListener(_onCanvasChanged);
    _initializeNotebook();
  }

  Future<void> _initializeNotebook() async {
    if (widget.isNewNotebook) {
      // Create new notebook
      final now = DateTime.now();
      _notebook = NotebookModel(
        id: _uuid.v4(),
        title: 'Untitled Notebook',
        coverColor: '#0066FF',
        createdAt: now,
        updatedAt: now,
        defaultTemplate: NotebookTemplate.blank,
      );
      
      // Create first page
      _pages = [
        PageModel.create(
          id: _uuid.v4(),
          notebookId: _notebook!.id,
          pageNumber: 1,
          template: NotebookTemplate.blank,
        ),
      ];
      _currentTemplate = NotebookTemplate.blank;
    } else if (widget.notebook != null) {
      _notebook = widget.notebook;
      _currentTemplate = widget.notebook!.defaultTemplate;
      
      // TODO: Load pages from service
      // For now, create mock pages
      _pages = List.generate(
        widget.notebook!.pageCount > 0 ? widget.notebook!.pageCount : 1,
        (index) => PageModel.create(
          id: _uuid.v4(),
          notebookId: widget.notebook!.id,
          pageNumber: index + 1,
          template: widget.notebook!.defaultTemplate,
        ),
      );
    }

    _currentPageIndex = widget.initialPageIndex ?? 0;
    if (_currentPageIndex >= _pages.length) {
      _currentPageIndex = _pages.length - 1;
    }

    if (_pages.isNotEmpty) {
      _canvasController.initWithPage(_pages[_currentPageIndex]);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _onCanvasChanged() {
    if (!_hasUnsavedChanges && _canvasController.hasChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  @override
  void dispose() {
    _canvasController.removeListener(_onCanvasChanged);
    _canvasController.dispose();
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

  void _selectPage(int index) {
    if (index == _currentPageIndex) return;
    
    // Save current page
    _saveCurrentPage();
    
    setState(() {
      _currentPageIndex = index;
      _currentTemplate = _pages[index].template;
    });
    
    _canvasController.initWithPage(_pages[index]);
  }

  void _addNewPage() {
    HapticFeedback.lightImpact();
    
    final newPage = PageModel.create(
      id: _uuid.v4(),
      notebookId: _notebook?.id ?? '',
      pageNumber: _pages.length + 1,
      template: _currentTemplate,
    );
    
    setState(() {
      _pages.add(newPage);
      _hasUnsavedChanges = true;
    });
    
    // Navigate to new page
    _selectPage(_pages.length - 1);
  }

  void _deletePage(int index) {
    if (_pages.length <= 1) return;
    
    setState(() {
      _pages.removeAt(index);
      
      // Update page numbers
      for (int i = 0; i < _pages.length; i++) {
        _pages[i] = _pages[i].copyWith(pageNumber: i + 1);
      }
      
      // Adjust current page index
      if (_currentPageIndex >= _pages.length) {
        _currentPageIndex = _pages.length - 1;
      }
      
      _hasUnsavedChanges = true;
    });
    
    _canvasController.initWithPage(_pages[_currentPageIndex]);
  }

  void _saveCurrentPage() {
    final updatedPage = _canvasController.getUpdatedPage();
    if (updatedPage != null && _currentPageIndex < _pages.length) {
      _pages[_currentPageIndex] = updatedPage;
    }
  }

  Future<void> _saveNotebook() async {
    _saveCurrentPage();
    
    // TODO: Save to NotebookService
    
    setState(() => _hasUnsavedChanges = false);
    _canvasController.markSaved();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Notebook saved'),
          backgroundColor: LivescribeTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _changeTemplate() async {
    final template = await TemplatePicker.show(
      context,
      currentTemplate: _currentTemplate,
    );
    
    if (template != null && template != _currentTemplate) {
      setState(() {
        _currentTemplate = template;
        _pages[_currentPageIndex] = _pages[_currentPageIndex].copyWith(
          template: template,
        );
        _hasUnsavedChanges = true;
      });
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('Do you want to save your changes before leaving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () async {
              await _saveNotebook();
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? LivescribeTheme.darkSurface : LivescribeTheme.surfaceWhite,
        body: _isLoading 
            ? _buildLoading(isDark)
            : Stack(
                children: [
                  // Canvas
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () {
                        if (_showToolbar) _toggleToolbar();
                      },
                      child: DrawingCanvas(
                        controller: _canvasController,
                        template: _currentTemplate,
                        onDrawStart: () {
                          if (_showToolbar) _toggleToolbar();
                        },
                      ),
                    ),
                  ),
                  
                  // Top toolbar
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _buildTopBar(isDark),
                  ),
                  
                  // Pen toolbar
                  Positioned(
                    bottom: MediaQuery.of(context).padding.bottom + 100,
                    left: 16,
                    right: 16,
                    child: FadeTransition(
                      opacity: _toolbarAnimController,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.5),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: _toolbarAnimController,
                          curve: LivescribeTheme.curveDefault,
                        )),
                        child: Center(
                          child: PenToolbar(controller: _canvasController),
                        ),
                      ),
                    ),
                  ),
                  
                  // Page navigator
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: PageNavigator(
                      pages: _pages,
                      currentPageIndex: _currentPageIndex,
                      onPageSelected: _selectPage,
                      onAddPage: _addNewPage,
                      onDeletePage: _deletePage,
                    ),
                  ),
                  
                  // Show toolbar button
                  if (!_showToolbar)
                    Positioned(
                      bottom: MediaQuery.of(context).padding.bottom + 120,
                      right: 16,
                      child: _buildShowToolbarButton(isDark),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildLoading(bool isDark) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildTopBar(bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16, 
        MediaQuery.of(context).padding.top + 8, 
        16, 
        12,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            (isDark ? LivescribeTheme.darkSurface : LivescribeTheme.surfaceWhite),
            (isDark ? LivescribeTheme.darkSurface : LivescribeTheme.surfaceWhite).withOpacity(0),
          ],
        ),
      ),
      child: Row(
        children: [
          // Back button
          _TopBarButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && context.mounted) {
                Navigator.pop(context);
              }
            },
            isDark: isDark,
          ),
          const SizedBox(width: 12),
          
          // Title
          Expanded(
            child: GestureDetector(
              onTap: _showRenameDialog,
              child: Text(
                _notebook?.title ?? 'Untitled',
                style: LivescribeTheme.titleLarge.copyWith(
                  color: isDark ? LivescribeTheme.darkTextPrimary : LivescribeTheme.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          
          // Undo
          _TopBarButton(
            icon: Icons.undo_rounded,
            onTap: _canvasController.canUndo ? _canvasController.undo : null,
            isDark: isDark,
            enabled: _canvasController.canUndo,
          ),
          const SizedBox(width: 8),
          
          // Redo
          _TopBarButton(
            icon: Icons.redo_rounded,
            onTap: _canvasController.canRedo ? _canvasController.redo : null,
            isDark: isDark,
            enabled: _canvasController.canRedo,
          ),
          const SizedBox(width: 8),
          
          // Template
          _TopBarButton(
            icon: Icons.grid_view_rounded,
            onTap: _changeTemplate,
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          
          // Save
          _TopBarButton(
            icon: Icons.check_rounded,
            onTap: _saveNotebook,
            isDark: isDark,
            isPrimary: _hasUnsavedChanges,
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
          size: 22,
        ),
      ),
    );
  }

  void _showRenameDialog() {
    final controller = TextEditingController(text: _notebook?.title ?? '');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? LivescribeTheme.darkSurfaceLight : LivescribeTheme.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Rename Notebook',
          style: TextStyle(
            color: isDark ? LivescribeTheme.darkTextPrimary : LivescribeTheme.textPrimary,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Notebook name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  _notebook = _notebook?.copyWith(title: controller.text.trim());
                  _hasUnsavedChanges = true;
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _TopBarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool isDark;
  final bool enabled;
  final bool isPrimary;

  const _TopBarButton({
    required this.icon,
    this.onTap,
    required this.isDark,
    this.enabled = true,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? () {
        HapticFeedback.lightImpact();
        onTap?.call();
      } : null,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isPrimary 
              ? LivescribeTheme.primary 
              : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04)),
          borderRadius: BorderRadius.circular(10),
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
