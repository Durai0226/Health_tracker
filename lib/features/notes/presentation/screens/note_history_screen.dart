import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/note_model.dart';
import '../../data/models/note_version_model.dart';
import '../../data/repositories/notes_repository.dart';

class NoteHistoryScreen extends StatefulWidget {
  final NoteModel note;

  const NoteHistoryScreen({super.key, required this.note});

  @override
  State<NoteHistoryScreen> createState() => _NoteHistoryScreenState();
}

class _NoteHistoryScreenState extends State<NoteHistoryScreen> {
  final NotesRepository _repository = NotesRepository();
  List<NoteVersionModel> _versions = [];
  NoteVersionModel? _selectedVersion;
  QuillController? _previewController;

  @override
  void initState() {
    super.initState();
    _loadVersions();
  }

  void _loadVersions() {
    setState(() {
      _versions = _repository.getNoteVersions(widget.note.id);
      if (_versions.isNotEmpty) {
        _selectVersion(_versions.first);
      }
    });
  }

  void _selectVersion(NoteVersionModel version) {
    _selectedVersion = version;
    try {
      if (version.content.startsWith('[')) {
        final json = jsonDecode(version.content);
        _previewController = QuillController(
          document: Document.fromJson(json),
          selection: const TextSelection.collapsed(offset: 0),
        );
      } else {
        _previewController = QuillController(
          document: Document()..insert(0, version.content),
          selection: const TextSelection.collapsed(offset: 0),
        );
      }
    } catch (e) {
      _previewController = QuillController.basic();
    }
    setState(() {});
  }

  Future<void> _restoreSelectedVersion() async {
    if (_selectedVersion == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Version?'),
        content: const Text('This will overwrite the current note content. A new version of the current state will be saved before restoring.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _repository.restoreVersion(_selectedVersion!);
      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate change
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Version History'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
      ),
      body: Column(
        children: [
          // List of versions
          SizedBox(
            height: 120,
            child: _versions.isEmpty
                ? const Center(child: Text("No history available"))
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(8),
                    itemCount: _versions.length,
                    itemBuilder: (context, index) {
                      final version = _versions[index];
                      final isSelected = _selectedVersion?.id == version.id;
                      return GestureDetector(
                        onTap: () => _selectVersion(version),
                        child: Container(
                          width: 140,
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.grey[100],
                            border: isSelected ? Border.all(color: AppColors.primary, width: 2) : null,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                DateFormat('MMM d, y').format(version.createdAt),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? AppColors.primary : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('h:mm a').format(version.createdAt),
                                style: TextStyle(
                                  color: isSelected ? AppColors.primary : Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const Divider(),
          // Preview Area
          Expanded(
            child: _previewController == null
                ? const Center(child: Text("Select a version to preview"))
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Preview",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            ElevatedButton.icon(
                              onPressed: _restoreSelectedVersion,
                              icon: const Icon(Icons.restore),
                              label: const Text("Restore This Version"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                            boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4)
                                )
                            ]
                          ),
                          child: QuillEditor.basic(
                            controller: _previewController!,
                            configurations: const QuillEditorConfigurations(
                              sharedConfigurations: QuillSharedConfigurations(
                                locale: Locale('en'),
                              ),
                            ),
                            // readOnly: true, // Deprecated? Often set in controller or configurations
                            // Actually in 10.x it might be different. 
                            // Usually: focusNode: FocusNode(canRequestFocus: false)
                            focusNode: FocusNode(canRequestFocus: false),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
