import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart';
import '../../data/repositories/notes_repository.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/note_model.dart';

import '../screens/note_editor_screen.dart';

class NoteCard extends StatelessWidget {
  final NoteModel note;

  const NoteCard({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
         Navigator.of(context).push(
           MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)),
         );
      },
      onLongPress: () => _showOptions(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Hero(
                    tag: 'note_title_${note.id}',
                    child: Material(
                      color: Colors.transparent,
                      child: Text(
                        note.title.isNotEmpty ? note.title : "Untitled",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _showOptions(context),
                  child: const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.more_vert_rounded,
                      size: 20,
                      color: AppColors.textLight,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _getPlainText(note.content),
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMM d').format(note.updatedAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                ),
                if (note.isPinned)
                  const Icon(Icons.push_pin_rounded, size: 14, color: AppColors.primary),
                if (note.hasUncheckedItems)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.check_box_outline_blank_rounded, size: 14, color: AppColors.textLight),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getPlainText(String content) {
    if (content.isEmpty) return "No content";
    
    try {
      // Try to parse as Quill Delta JSON
      if (content.trim().startsWith('[')) {
         final json = jsonDecode(content);
         final doc = Document.fromJson(json);
         final text = doc.toPlainText().trim();
         return text.isEmpty ? "Empty note" : (text.length > 100 ? text.substring(0, 100) : text);
      }
    } catch (e) {
      // Ignore error, treat as plain text
    }

    return content.length > 100 ? content.substring(0, 100) : content;
  }

  void _showOptions(BuildContext context) {
    final repository = NotesRepository();
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Show different options based on note state
              if (note.isDeleted) ...[
                // Trash view options
                ListTile(
                  leading: const Icon(Icons.restore_rounded, color: AppColors.primary),
                  title: const Text('Restore'),
                  onTap: () async {
                    Navigator.pop(context);
                    await repository.restoreNote(note.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Note restored')),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: AppColors.error),
                  title: const Text('Delete Permanently'),
                  textColor: AppColors.error,
                  onTap: () {
                    Navigator.pop(context);
                    _confirmPermanentDelete(context);
                  },
                ),
              ] else if (note.isArchived) ...[
                // Archive view options
                ListTile(
                  leading: const Icon(Icons.unarchive_rounded, color: AppColors.primary),
                  title: const Text('Unarchive'),
                  onTap: () async {
                    Navigator.pop(context);
                    await repository.unarchiveNote(note.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Note unarchived')),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_rounded, color: AppColors.error),
                  title: const Text('Delete'),
                  textColor: AppColors.error,
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDelete(context);
                  },
                ),
              ] else ...[
                // Normal notes view options
                ListTile(
                  leading: const Icon(Icons.edit_rounded, color: AppColors.primary),
                  title: const Text('Edit'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    note.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                    color: AppColors.primary,
                  ),
                  title: Text(note.isPinned ? 'Unpin' : 'Pin'),
                  onTap: () async {
                    Navigator.pop(context);
                    await repository.togglePin(note.id);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.archive_rounded, color: AppColors.textSecondary),
                  title: const Text('Archive'),
                  onTap: () async {
                    Navigator.pop(context);
                    await repository.archiveNote(note.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Note archived')),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_rounded, color: AppColors.error),
                  title: const Text('Delete'),
                  textColor: AppColors.error,
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDelete(context);
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note?'),
        content: const Text('This note will be moved to trash.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              await NotesRepository().deleteNote(note.id);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Note moved to trash')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmPermanentDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Permanently?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              await NotesRepository().permanentlyDeleteNote(note.id);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Note permanently deleted')),
                );
              }
            },
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );
  }
}
