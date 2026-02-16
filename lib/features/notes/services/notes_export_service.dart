import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../data/models/note_model.dart';

class NotesExportService {
  Future<void> exportNoteAsMarkdown(NoteModel note, String plainText) async {
    try {
      final String title = note.title.isNotEmpty ? note.title : 'Untitled_Note';
      final String safeTitle = title.replaceAll(RegExp(r'[^\w\s\-]'), '');
      
      final directory = await getTemporaryDirectory();
      final String filePath = '${directory.path}/$safeTitle.md';
      final File file = File(filePath);
      
      // Construct Markdown content
      final StringBuffer buffer = StringBuffer();
      buffer.writeln('# $title');
      buffer.writeln();
      buffer.writeln(plainText); // For now, just using plain text. enhancing later.
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln('Exported from Dlyminder');
      
      await file.writeAsString(buffer.toString());
      
      await Share.shareXFiles([XFile(filePath)], text: 'Check out this note from Dlyminder!');
    } catch (e) {
      throw Exception('Failed to export note: $e');
    }
  }
}
