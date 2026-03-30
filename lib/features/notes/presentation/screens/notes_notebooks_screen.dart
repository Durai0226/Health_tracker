import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/folder_model.dart';
import '../../data/services/notes_service.dart';
import '../../theme/evernote_theme.dart';

/// Notebooks/Folders management screen for Notes feature
class NotesNotebooksScreen extends StatefulWidget {
  const NotesNotebooksScreen({super.key});

  @override
  State<NotesNotebooksScreen> createState() => _NotesNotebooksScreenState();
}

class _NotesNotebooksScreenState extends State<NotesNotebooksScreen> {
  final NotesService _notesService = NotesService();
  List<FolderModel> _folders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    await _notesService.initialize();
    if (mounted) {
      setState(() {
        _folders = _notesService.getAllFolders();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EvernoteTheme.background,
      appBar: AppBar(
        backgroundColor: EvernoteTheme.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('Notebooks', style: EvernoteTheme.headlineSmall),
        actions: [
          IconButton(
            onPressed: _showAddNotebookDialog,
            icon: const Icon(
              Icons.add_rounded,
              color: EvernoteTheme.primary,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: EvernoteTheme.primary,
                strokeWidth: 2,
              ),
            )
          : _folders.isEmpty
              ? _buildEmptyState()
              : _buildNotebooksList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  EvernoteTheme.primary.withOpacity(0.2),
                  EvernoteTheme.primaryDark.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.book_outlined,
              size: 40,
              color: EvernoteTheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No notebooks yet',
            style: EvernoteTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Create a notebook to organize your notes',
            style: EvernoteTheme.bodyMedium.copyWith(
              color: EvernoteTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddNotebookDialog,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create Notebook'),
            style: ElevatedButton.styleFrom(
              backgroundColor: EvernoteTheme.primary,
              foregroundColor: EvernoteTheme.textOnPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotebooksList() {
    return RefreshIndicator(
      onRefresh: _loadFolders,
      color: EvernoteTheme.primary,
      backgroundColor: EvernoteTheme.surface,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _folders.length,
        itemBuilder: (context, index) {
          final folder = _folders[index];
          return _NotebookTile(
            folder: folder,
            noteCount: _notesService.getNotesInFolder(folder.id).length,
            onTap: () => _openNotebook(folder),
            onEdit: () => _showEditNotebookDialog(folder),
            onDelete: () => _deleteNotebook(folder),
          );
        },
      ),
    );
  }

  void _openNotebook(FolderModel folder) {
    // TODO: Navigate to notes filtered by folder
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening "${folder.name}"...'),
        backgroundColor: EvernoteTheme.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showAddNotebookDialog() {
    final controller = TextEditingController();
    Color selectedColor = EvernoteTheme.categoryColors[0];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: EvernoteTheme.modalDecoration,
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: EvernoteTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('New Notebook', style: EvernoteTheme.headlineSmall),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                autofocus: true,
                style: EvernoteTheme.bodyLarge,
                cursorColor: EvernoteTheme.primary,
                decoration: InputDecoration(
                  hintText: 'Notebook name',
                  hintStyle: EvernoteTheme.bodyLarge.copyWith(
                    color: EvernoteTheme.textTertiary,
                  ),
                  filled: true,
                  fillColor: EvernoteTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: EvernoteTheme.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Color',
                style: EvernoteTheme.titleSmall.copyWith(
                  color: EvernoteTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: EvernoteTheme.categoryColors.map((color) {
                  final isSelected = color == selectedColor;
                  return GestureDetector(
                    onTap: () => setModalState(() => selectedColor = color),
                    child: AnimatedContainer(
                      duration: EvernoteTheme.durationFast,
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? EvernoteTheme.textPrimary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check_rounded,
                              size: 18, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    if (controller.text.trim().isNotEmpty) {
                      _createNotebook(
                        controller.text.trim(),
                        '#${selectedColor.value.toRadixString(16).substring(2).toUpperCase()}',
                      );
                      Navigator.pop(ctx);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EvernoteTheme.primary,
                    foregroundColor: EvernoteTheme.textOnPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Create Notebook',
                    style: EvernoteTheme.labelLarge.copyWith(
                      color: EvernoteTheme.textOnPrimary,
                      fontWeight: FontWeight.w600,
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

  void _showEditNotebookDialog(FolderModel folder) {
    final controller = TextEditingController(text: folder.name);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: EvernoteTheme.modalDecoration,
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: EvernoteTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Edit Notebook', style: EvernoteTheme.headlineSmall),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              autofocus: true,
              style: EvernoteTheme.bodyLarge,
              cursorColor: EvernoteTheme.primary,
              decoration: InputDecoration(
                hintText: 'Notebook name',
                hintStyle: EvernoteTheme.bodyLarge.copyWith(
                  color: EvernoteTheme.textTertiary,
                ),
                filled: true,
                fillColor: EvernoteTheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: EvernoteTheme.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  if (controller.text.trim().isNotEmpty) {
                    _updateNotebook(folder, controller.text.trim());
                    Navigator.pop(ctx);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: EvernoteTheme.primary,
                  foregroundColor: EvernoteTheme.textOnPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Save Changes',
                  style: EvernoteTheme.labelLarge.copyWith(
                    color: EvernoteTheme.textOnPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createNotebook(String name, String color) async {
    await _notesService.createFolder(name, color: color);
    _loadFolders();
  }

  Future<void> _updateNotebook(FolderModel folder, String name) async {
    await _notesService.updateFolder(folder.copyWith(name: name));
    _loadFolders();
  }

  Future<void> _deleteNotebook(FolderModel folder) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EvernoteTheme.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Notebook?', style: EvernoteTheme.titleLarge),
        content: Text(
          'Notes in this notebook will not be deleted.',
          style: EvernoteTheme.bodyMedium.copyWith(
            color: EvernoteTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: EvernoteTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: EvernoteTheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _notesService.deleteFolder(folder.id);
      _loadFolders();
    }
  }
}

class _NotebookTile extends StatelessWidget {
  final FolderModel folder;
  final int noteCount;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _NotebookTile({
    required this.folder,
    required this.noteCount,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  Color get _folderColor {
    try {
      if (folder.color != null) {
        return Color(
            int.parse(folder.color!.replaceFirst('#', '0xFF')));
      }
    } catch (_) {}
    return EvernoteTheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: EvernoteTheme.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: EvernoteTheme.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _folderColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.book_rounded,
                color: _folderColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    folder.name,
                    style: EvernoteTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$noteCount notes',
                    style: EvernoteTheme.caption.copyWith(
                      color: EvernoteTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert_rounded,
                color: EvernoteTheme.textTertiary,
              ),
              color: EvernoteTheme.surfaceLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      const Icon(Icons.edit_outlined,
                          size: 20, color: EvernoteTheme.textSecondary),
                      const SizedBox(width: 12),
                      Text('Edit', style: EvernoteTheme.bodyMedium),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline,
                          size: 20, color: EvernoteTheme.error),
                      const SizedBox(width: 12),
                      Text('Delete',
                          style: EvernoteTheme.bodyMedium
                              .copyWith(color: EvernoteTheme.error)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
