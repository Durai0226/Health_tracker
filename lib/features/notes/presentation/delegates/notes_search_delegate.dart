import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/note_model.dart';
import '../screens/note_editor_screen.dart';

class NotesSearchDelegate extends SearchDelegate {
  final List<NoteModel> notes;

  NotesSearchDelegate({required this.notes});

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: AppColors.textLight),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear_rounded),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    final searchLower = query.toLowerCase();
    
    final results = notes.where((note) {
      final titleMatch = note.title.toLowerCase().contains(searchLower);
      if (titleMatch) return true;
      
      final plainText = _getPlainText(note.content).toLowerCase();
      return plainText.contains(searchLower);
    }).toList();

    if (results.isEmpty && query.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded, size: 64, color: AppColors.textLight),
            const SizedBox(height: 16),
            Text(
              'No results for "$query"',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }
    
    if (query.isEmpty) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               Icon(Icons.search_rounded, size: 64, color: AppColors.textLight),
               SizedBox(height: 16),
               Text(
                 'Search your notes',
                 style: TextStyle(color: AppColors.textSecondary),
               ),
            ],
          ),
        );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final note = results[index];
        return ListTile(
          tileColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            note.title.isNotEmpty ? note.title : "Untitled",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            _getPlainText(note.content),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)),
            );
          },
        );
      },
    );
  }

  String _getPlainText(String content) {
    if (content.isEmpty) return "";
    
    try {
      if (content.trim().startsWith('[')) {
         final json = jsonDecode(content);
         final doc = Document.fromJson(json);
         return doc.toPlainText().trim();
      }
    } catch (e) {
      // Ignore
    }
    return content;
  }
}
