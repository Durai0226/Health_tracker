import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/note_model.dart';
import '../../data/repositories/notes_repository.dart';

import '../../services/notes_media_service.dart';
import '../../services/notes_export_service.dart';
import '../widgets/audio_recorder_sheet.dart';
import 'note_history_screen.dart';
import '../../../../features/reminders/screens/add_reminder_screen.dart';

class NoteEditorScreen extends StatefulWidget {
  final NoteModel? note;
  final String? folderId;
  final String? noteId;

  const NoteEditorScreen({super.key, this.note, this.folderId, this.noteId});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late QuillController _controller;
  final TextEditingController _titleController = TextEditingController();
  final NotesRepository _repository = NotesRepository();
  final FocusNode _editorFocusNode = FocusNode();
  final NotesMediaService _mediaService = NotesMediaService();
  final NotesExportService _exportService = NotesExportService();
  bool _isUploading = false;
  
  bool _isDirty = false;
  bool _isEditing = false; // Add _isEditing flag
  String? _currentNoteId;

  @override
  void initState() {
    super.initState();
    _loadNote();
  }

  Future<void> _loadNote() async {
    if (widget.note != null) {
      _currentNoteId = widget.note!.id;
      final content = await _repository.unlockNoteContent(widget.note!);
      _initializeEditor(widget.note!.copyWith(content: content));
    } else if (widget.noteId != null) {
      _currentNoteId = widget.noteId;
      final note = await _repository.getNote(widget.noteId!);
      if (note != null) {
        final content = await _repository.unlockNoteContent(note);
        if (mounted) {
          setState(() {
            _initializeEditor(note.copyWith(content: content));
          });
        }
      } else {
        // Fallback for invalid ID
        _controller = QuillController.basic();
        _isEditing = true;
      }
    } else {
      _controller = QuillController.basic();
      _isEditing = true; // New note starts in edit mode
    }
    
    _controller.addListener(_markDirty);
    _titleController.addListener(_markDirty);
  }

  void _initializeEditor(NoteModel note) {
    _titleController.text = note.title;
    try {
      if (note.content.startsWith('[')) {
         final json = jsonDecode(note.content);
         _controller = QuillController(
           document: Document.fromJson(json),
           selection: const TextSelection.collapsed(offset: 0),
           readOnly: true, // Initially read-only
         );
      } else {
         _controller = QuillController(
           document: Document()..insert(0, note.content),
           selection: const TextSelection.collapsed(offset: 0),
           readOnly: true,
         );
      }
    } catch (e) {
      _controller = QuillController.basic();
    }
    
    // Default to read-only for existing notes
    _isEditing = false;
  }
  
  void _markDirty() {
    if (!_isDirty && _isEditing) {
      setState(() => _isDirty = true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _titleController.dispose();
    _editorFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickAndInsertImage(ImageSource source) async {
    try {
      final file = await _mediaService.pickImage(source: source);
      if (file == null) return;

      setState(() => _isUploading = true);

      final url = await _mediaService.uploadMedia(file, folder: 'images');
      
      setState(() => _isUploading = false);

      if (url != null) {
        final index = _controller.selection.baseOffset;
        final length = _controller.selection.extentOffset - index;
        
        _controller.replaceText(index, length, BlockEmbed.image(url), null);
        _controller.moveCursorToPosition(index + 1);
      } else {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Failed to upload image')),
           );
        }
      }
    } catch (e) {
      setState(() => _isUploading = false);
      debugPrint('Error inserting image: $e');
    }

  }

  Future<void> _recordAndInsertAudio() async {
    final File? file = await showModalBottomSheet<File>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AudioRecorderSheet(),
    );

    if (file == null) return;

    try {
      setState(() => _isUploading = true);
      
      final url = await _mediaService.uploadMedia(file, folder: 'audio');
      
      setState(() => _isUploading = false);

      if (url != null) {
        final index = _controller.selection.baseOffset;
        final length = _controller.selection.extentOffset - index;
        
        // Insert as link for now, or text. 
        // Ideally we'd use a custom block, but a link is safer for v1.
        _controller.replaceText(index, length, "🎤 Audio Note", null);
        _controller.formatText(index, 13, LinkAttribute(url));
        _controller.moveCursorToPosition(index + 13);
      }
    } catch (e) {
      setState(() => _isUploading = false);
      debugPrint('Error uploading audio: $e');
    }

  }

  Future<void> _setReminder() async {
    // Ensure note is saved first to get an ID
    if (_currentNoteId == null || _isDirty) {
      await _saveNote();
    }
    
    if (_currentNoteId == null) return; // Save failed?

    if (mounted) {
      await Navigator.push(
        context, 
        MaterialPageRoute(
          builder: (_) => AddReminderScreen(noteId: _currentNoteId),
        ),
      );
    }
  }

  Future<void> _toggleLock() async {
    // Use _currentNoteId which handles both nav-by-object and nav-by-id cases
    if (_currentNoteId == null) {
      if (_isDirty) await _saveNote(); // Try to save first to get an ID
      if (_currentNoteId == null) return;
    }
    
    // Toggle lock via repository (handles encryption/decryption)
    await _repository.toggleLock(_currentNoteId!);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note lock state updated 🔒')),
      );
      // We must reload the note to get the new state/content or close
      // Closing is safer to ensure state consistency
      Navigator.pop(context); 
    }
  }

  Future<void> _exportNote() async {
     try {
       // Save first to ensure latest content
       if (_isDirty) await _saveNote();
       
       if (widget.note == null) return;
       
       final plainText = _controller.document.toPlainText();
       await _exportService.exportNoteAsMarkdown(widget.note!, plainText);
     } catch (e) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Export failed: $e')),
         );
       }
     }
  }

  Future<void> _saveNote() async {
    final title = _titleController.text.trim();
    final contentJson = jsonEncode(_controller.document.toDelta().toJson());
    final plainText = _controller.document.toPlainText().trim();

    if (title.isEmpty && plainText.isEmpty) {
        return; // Don't save empty notes
    }

    if (widget.note != null) {
      final updatedNote = widget.note!.copyWith(
        title: title,
        content: contentJson,
        updatedAt: DateTime.now(),
      );
      await _repository.updateNote(updatedNote);
    } else if (_currentNoteId != null) {
      final note = await _repository.getNote(_currentNoteId!);
      if (note != null) {
          final updatedNote = note.copyWith(
            title: title,
            content: contentJson,
            updatedAt: DateTime.now(),
          );
          await _repository.updateNote(updatedNote);
      }
    } else {
      // Create new
      _currentNoteId = await _repository.createNote(
        title: title,
        content: contentJson,
        folderId: widget.folderId,
      );
    }
    
    setState(() => _isDirty = false);
    if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Note saved'), duration: Duration(seconds: 1)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Manage FocusNode based on edit state
    _editorFocusNode.canRequestFocus = _isEditing;
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () async {
             final navigator = Navigator.of(context);
             if (_isDirty) await _saveNote();
             if (mounted) navigator.pop();
          },
        ),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                  _controller.readOnly = false;
                  // Focus the editor after rebuild
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _editorFocusNode.requestFocus();
                  });
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.check, color: AppColors.primary),
              onPressed: () async {
                  await _saveNote();
                  setState(() {
                    _isEditing = false;
                    _controller.readOnly = true;
                    _editorFocusNode.unfocus();
                  });
              },
            ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'delete') {
                 final navigator = Navigator.of(context);
                 if (_currentNoteId != null) {
                   await _repository.deleteNote(_currentNoteId!);
                 }
                 if (mounted) navigator.pop();
              } else if (value == 'reminder') {
                 await _setReminder();
              } else if (value == 'lock') {
                 await _toggleLock();
              } else if (value == 'pin') {
                 if (_currentNoteId != null) {
                   await _repository.togglePin(_currentNoteId!);
                   if (mounted) setState(() {});
                 }
              } else if (value == 'export') {
                 await _exportNote();
              } else if (value == 'history') {
                 if (widget.note != null) {
                   final result = await Navigator.push(
                     context,
                     MaterialPageRoute(builder: (_) => NoteHistoryScreen(note: widget.note!)),
                   );
                   if (result == true) {
                     // Note was restored
                     if (mounted) {
                       Navigator.pop(context); // Close editor to refresh list
                     }
                   }
                 }
              }
            },

            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'lock',
                child: Row(
                  children: [
                    Icon(
                       widget.note?.isLocked == true ? Icons.lock_open_rounded : Icons.lock_outline_rounded, 
                       color: AppColors.textPrimary
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.note?.isLocked == true ? 'Unlock Note' : 'Lock Note',
                      style: const TextStyle(color: AppColors.textPrimary)
                    ),
                  ],
                ),
              ),

              PopupMenuItem(
                value: 'reminder',
                child: Row(
                  children: [
                    Icon(Icons.notification_add_outlined, color: AppColors.textPrimary),
                    SizedBox(width: 8),
                    Text('Set Reminder', style: TextStyle(color: AppColors.textPrimary)),
                  ],
                ),
              ),

              PopupMenuItem(
                value: 'pin',
                child: Row(
                  children: [
                    Icon(
                       widget.note?.isPinned == true ? Icons.push_pin_outlined : Icons.push_pin_rounded, 
                       color: AppColors.textPrimary
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.note?.isPinned == true ? 'Unpin' : 'Pin',
                      style: const TextStyle(color: AppColors.textPrimary)
                    ),
                  ],
                ),
              ),

              const PopupMenuItem(
                value: 'history',
                child: Row(
                  children: [
                    Icon(Icons.history_rounded, color: AppColors.textPrimary),
                    SizedBox(width: 8),
                    Text('Version History', style: TextStyle(color: AppColors.textPrimary)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.ios_share_rounded, color: AppColors.textPrimary),
                    SizedBox(width: 8),
                    Text('Export as Markdown', style: TextStyle(color: AppColors.textPrimary)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Hero(
                  tag: 'note_title_${widget.note?.id ?? "new"}',
                  child: Material(
                    color: Colors.transparent,
                    child: TextField(
                      controller: _titleController,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        hintText: "Title",
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey),
                      ),
                      readOnly: !_isEditing, // Title is also read-only? 
                      // Yes, should be.
                    ),
                  ),
                ),
              ),
              if (_isEditing)
              QuillToolbar.simple(
                controller: _controller,
                configurations: QuillSimpleToolbarConfigurations(
                  showFontFamily: false,
                  showFontSize: false,
                  showSearchButton: false, 
                  customButtons: [
                    QuillToolbarCustomButtonOptions(
                      icon: const Icon(Icons.image_outlined),
                      onPressed: () => _pickAndInsertImage(ImageSource.gallery),
                    ),
                    QuillToolbarCustomButtonOptions(
                      icon: const Icon(Icons.camera_alt_outlined),
                      onPressed: () => _pickAndInsertImage(ImageSource.camera),
                    ),
                    QuillToolbarCustomButtonOptions(
                      icon: const Icon(Icons.mic_none_outlined),
                      onPressed: _recordAndInsertAudio,
                    ),
                  ],
                  showListCheck: true, // Enable checkbox
                  showListBullets: true,
                  showListNumbers: true,
                  showQuote: true,
                  showCodeBlock: false,
                  showInlineCode: false,
                  showLink: true,
                  showUndo: false,
                  showRedo: false,
                ),
              ),
              Expanded(
                child: QuillEditor.basic(
                  controller: _controller,
                  configurations: QuillEditorConfigurations(
                    placeholder: 'Start typing...',
                    padding: const EdgeInsets.all(16),
                    sharedConfigurations: const QuillSharedConfigurations(
                      locale: Locale('en'),
                    ),
                  ),
                  focusNode: _editorFocusNode,
                ),
              ),
            ],
          ),
          if (_isUploading)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
