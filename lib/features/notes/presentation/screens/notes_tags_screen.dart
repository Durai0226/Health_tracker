import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/tag_model.dart';
import '../../data/services/notes_service.dart';
import '../../theme/evernote_theme.dart';

/// Tags management screen for Notes feature
class NotesTagsScreen extends StatefulWidget {
  const NotesTagsScreen({super.key});

  @override
  State<NotesTagsScreen> createState() => _NotesTagsScreenState();
}

class _NotesTagsScreenState extends State<NotesTagsScreen> {
  final NotesService _notesService = NotesService();
  List<TagModel> _tags = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    await _notesService.initialize();
    if (mounted) {
      setState(() {
        _tags = _notesService.getAllTags();
        _isLoading = false;
      });
    }
  }

  void _showAddTagDialog() {
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
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
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
                  
                  Text(
                    'New Tag',
                    style: EvernoteTheme.headlineSmall,
                  ),
                  const SizedBox(height: 20),
                  
                  // Tag name input
                  TextField(
                    controller: controller,
                    autofocus: true,
                    style: EvernoteTheme.bodyLarge,
                    cursorColor: EvernoteTheme.primary,
                    decoration: InputDecoration(
                      hintText: 'Tag name',
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
                  
                  // Color picker
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
                        onTap: () {
                          setModalState(() => selectedColor = color);
                        },
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
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 18,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  
                  // Create button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        if (controller.text.trim().isNotEmpty) {
                          _createTag(
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
                        'Create Tag',
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
        ),
      ),
    );
  }

  Future<void> _createTag(String name, String color) async {
    await _notesService.createTag(name, color: color);
    _loadTags();
  }

  Future<void> _deleteTag(TagModel tag) async {
    await _notesService.deleteTag(tag.id);
    _loadTags();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EvernoteTheme.background,
      appBar: AppBar(
        backgroundColor: EvernoteTheme.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Tags',
          style: EvernoteTheme.headlineSmall,
        ),
        actions: [
          IconButton(
            onPressed: _showAddTagDialog,
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
          : _tags.isEmpty
              ? _buildEmptyState()
              : _buildTagsList(),
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
              color: EvernoteTheme.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.tag_rounded,
              size: 40,
              color: EvernoteTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No tags yet',
            style: EvernoteTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Create tags to organize your notes',
            style: EvernoteTheme.bodyMedium.copyWith(
              color: EvernoteTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddTagDialog,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create Tag'),
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

  Widget _buildTagsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tags.length,
      itemBuilder: (context, index) {
        final tag = _tags[index];
        return _TagTile(
          tag: tag,
          onTap: () {
            // TODO: Show notes with this tag
          },
          onDelete: () => _showDeleteDialog(tag),
        );
      },
    );
  }

  void _showDeleteDialog(TagModel tag) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EvernoteTheme.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Delete Tag?',
          style: EvernoteTheme.titleLarge,
        ),
        content: Text(
          'This will remove the tag "${tag.name}" from all notes.',
          style: EvernoteTheme.bodyMedium.copyWith(
            color: EvernoteTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: EvernoteTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteTag(tag);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: EvernoteTheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagTile extends StatelessWidget {
  final TagModel tag;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TagTile({
    required this.tag,
    required this.onTap,
    required this.onDelete,
  });

  Color get _tagColor {
    if (tag.color != null) {
      try {
        return Color(int.parse(tag.color!.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }
    return EvernoteTheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: EvernoteTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EvernoteTheme.cardBorder),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _tagColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.tag_rounded,
            color: _tagColor,
            size: 20,
          ),
        ),
        title: Text(
          tag.name,
          style: EvernoteTheme.titleMedium,
        ),
        subtitle: Builder(
          builder: (context) {
            final notesService = NotesService();
            final notes = notesService.getAllNotes();
            final count = notes.where((n) => n.tagIds.contains(tag.id)).length;
            return Text(
              '$count ${count == 1 ? 'note' : 'notes'}',
              style: EvernoteTheme.bodySmall,
            );
          },
        ),
        trailing: IconButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            onDelete();
          },
          icon: const Icon(
            Icons.more_vert_rounded,
            color: EvernoteTheme.textTertiary,
          ),
        ),
      ),
    );
  }
}
