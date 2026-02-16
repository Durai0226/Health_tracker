import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart';
import '../../data/repositories/notes_repository.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/note_model.dart';

import '../../services/notes_security_service.dart';
import '../screens/note_editor_screen.dart';

class NoteCard extends StatelessWidget {
  final NoteModel note;

  const NoteCard({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
         if (note.isLocked) {
           final bool authenticated = await NotesSecurityService().authenticate();
           if (!authenticated) return;
         }
         
         if (context.mounted) {
           Navigator.of(context).push(
             MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)),
           );
         }
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
            Hero(
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
            const SizedBox(height: 8),
            Text(
              note.isLocked 
                  ? "🔒 Locked Note" 
                  : _getPlainText(note.content),
              style: TextStyle(
                fontSize: 14,
                color: note.isLocked ? AppColors.textLight : AppColors.textSecondary,
                height: 1.4,
                fontStyle: note.isLocked ? FontStyle.italic : FontStyle.normal,
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
                if (note.isLocked)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.lock_rounded, size: 14, color: AppColors.textLight),
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
                  await NotesRepository().togglePin(note.id);
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
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              await NotesRepository().deleteNote(note.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
