import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/note_model.dart';
import '../../data/repositories/notes_repository.dart';
import '../../../../features/reminders/screens/add_reminder_screen.dart';

class NoteEditorScreen extends StatefulWidget {
  final NoteModel? note;
  final String? noteId;

  const NoteEditorScreen({super.key, this.note, this.noteId});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  QuillController? _controller;
  final TextEditingController _titleController = TextEditingController();
  final NotesRepository _repository = NotesRepository();
  final FocusNode _editorFocusNode = FocusNode();
  
  bool _isDirty = false;
  bool _isEditing = false;
  bool _isLoading = true;
  String? _currentNoteId;
  NoteModel? _currentNote;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_markDirty);
    _loadNote();
  }

  Future<void> _loadNote() async {
    setState(() => _isLoading = true);
    
    try {
      if (widget.note != null) {
        _currentNoteId = widget.note!.id;
        _currentNote = widget.note;
        _initializeEditor(widget.note!);
      } else if (widget.noteId != null) {
        _currentNoteId = widget.noteId;
        final note = await _repository.getNote(widget.noteId!);
        if (note != null) {
          _currentNote = note;
          _initializeEditor(note);
        } else {
          _initializeNewNote();
        }
      } else {
        _initializeNewNote();
      }
    } catch (e) {
      debugPrint('Error loading note: $e');
      _initializeNewNote();
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
  
  void _initializeNewNote() {
    _controller = QuillController.basic();
    _controller!.addListener(_markDirty);
    _isEditing = true;
  }

  void _initializeEditor(NoteModel note) {
    _titleController.text = note.title;
    try {
      if (note.content.isNotEmpty && note.content.startsWith('[')) {
         final json = jsonDecode(note.content);
         _controller = QuillController(
           document: Document.fromJson(json),
           selection: const TextSelection.collapsed(offset: 0),
           readOnly: true,
         );
      } else if (note.content.isNotEmpty) {
         _controller = QuillController(
           document: Document()..insert(0, note.content),
           selection: const TextSelection.collapsed(offset: 0),
           readOnly: true,
         );
      } else {
         _controller = QuillController.basic();
         _controller!.readOnly = true;
      }
    } catch (e) {
      debugPrint('Error parsing note content: $e');
      _controller = QuillController.basic();
      _controller!.readOnly = true;
    }
    
    // Add listener after controller is created
    _controller!.addListener(_markDirty);
    
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
    _controller?.dispose();
    _titleController.dispose();
    _editorFocusNode.dispose();
    super.dispose();
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


  Future<void> _saveNote() async {
    if (_controller == null) return;
    
    final title = _titleController.text.trim();
    final contentJson = jsonEncode(_controller!.document.toDelta().toJson());
    final plainText = _controller!.document.toPlainText().trim();

    if (title.isEmpty && plainText.isEmpty) {
        return;
    }

    if (_currentNoteId != null) {
      final note = await _repository.getNote(_currentNoteId!);
      if (note != null) {
          final updatedNote = note.copyWith(
            title: title,
            content: contentJson,
            updatedAt: DateTime.now(),
          );
          await _repository.updateNote(updatedNote);
          _currentNote = await _repository.getNote(_currentNoteId!);
      }
    } else {
      // Create new note
      _currentNoteId = await _repository.createNote(
        title: title,
        content: contentJson,
      );
      _currentNote = await _repository.getNote(_currentNoteId!);
    }
    
    setState(() => _isDirty = false);
    if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Note saved'), duration: Duration(seconds: 1)),
        );
    }
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              size: 22,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbarDivider() {
    return Container(
      height: 24,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: AppColors.divider,
    );
  }

  Future<void> _insertLink() async {
    if (_controller == null) return;
    
    final urlController = TextEditingController();
    final textController = TextEditingController();
    
    // Get selected text if any
    final selection = _controller!.selection;
    if (!selection.isCollapsed) {
      final selectedText = _controller!.document.toPlainText().substring(
        selection.start,
        selection.end,
      );
      textController.text = selectedText;
    }
    
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Insert Link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                labelText: 'Display Text',
                hintText: 'Link text',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://',
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, {
                'text': textController.text,
                'url': urlController.text,
              });
            },
            child: const Text('Insert'),
          ),
        ],
      ),
    );
    
    if (result != null && result['url']!.isNotEmpty && _controller != null) {
      final index = _controller!.selection.baseOffset;
      final length = _controller!.selection.extentOffset - index;
      final text = result['text']!.isNotEmpty ? result['text']! : result['url']!;
      
      _controller!.replaceText(index, length, text, null);
      _controller!.formatText(index, text.length, LinkAttribute(result['url']!));
      _controller!.moveCursorToPosition(index + text.length);
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
                  _controller?.readOnly = false;
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
                    _controller?.readOnly = true;
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
              } else if (value == 'pin') {
                 if (_currentNoteId != null) {
                   await _repository.togglePin(_currentNoteId!);
                   final updatedNote = await _repository.getNote(_currentNoteId!);
                   if (mounted && updatedNote != null) {
                     setState(() => _currentNote = updatedNote);
                   }
                 }
              } else if (value == 'archive') {
                 if (_currentNoteId != null) {
                   if (_currentNote?.isArchived == true) {
                     await _repository.unarchiveNote(_currentNoteId!);
                     if (mounted) {
                       ScaffoldMessenger.of(context).showSnackBar(
                         const SnackBar(content: Text('Note unarchived')),
                       );
                       Navigator.pop(context);
                     }
                   } else {
                     await _repository.archiveNote(_currentNoteId!);
                     if (mounted) {
                       ScaffoldMessenger.of(context).showSnackBar(
                         const SnackBar(content: Text('Note archived')),
                       );
                       Navigator.pop(context);
                     }
                   }
                 }
              }
            },

            itemBuilder: (context) => [
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
                       _currentNote?.isPinned == true ? Icons.push_pin_outlined : Icons.push_pin_rounded, 
                       color: AppColors.textPrimary
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _currentNote?.isPinned == true ? 'Unpin' : 'Pin',
                      style: const TextStyle(color: AppColors.textPrimary)
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'archive',
                child: Row(
                  children: [
                    Icon(
                      _currentNote?.isArchived == true ? Icons.unarchive_rounded : Icons.archive_outlined,
                      color: AppColors.textPrimary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _currentNote?.isArchived == true ? 'Unarchive' : 'Archive',
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
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
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    border: Border(
                      top: BorderSide(color: AppColors.divider, width: 1),
                      bottom: BorderSide(color: AppColors.divider, width: 1),
                    ),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        _buildToolbarButton(
                          icon: Icons.format_bold_rounded,
                          tooltip: 'Bold',
                          onPressed: () => _controller?.formatSelection(Attribute.bold),
                        ),
                        _buildToolbarButton(
                          icon: Icons.format_italic_rounded,
                          tooltip: 'Italic',
                          onPressed: () => _controller?.formatSelection(Attribute.italic),
                        ),
                        _buildToolbarButton(
                          icon: Icons.format_underlined_rounded,
                          tooltip: 'Underline',
                          onPressed: () => _controller?.formatSelection(Attribute.underline),
                        ),
                        _buildToolbarDivider(),
                        _buildToolbarButton(
                          icon: Icons.format_list_bulleted_rounded,
                          tooltip: 'Bullet List',
                          onPressed: () => _controller?.formatSelection(Attribute.ul),
                        ),
                        _buildToolbarButton(
                          icon: Icons.format_list_numbered_rounded,
                          tooltip: 'Numbered List',
                          onPressed: () => _controller?.formatSelection(Attribute.ol),
                        ),
                        _buildToolbarButton(
                          icon: Icons.check_box_outlined,
                          tooltip: 'Checklist',
                          onPressed: () => _controller?.formatSelection(Attribute.unchecked),
                        ),
                        _buildToolbarDivider(),
                        _buildToolbarButton(
                          icon: Icons.format_quote_rounded,
                          tooltip: 'Quote',
                          onPressed: () => _controller?.formatSelection(Attribute.blockQuote),
                        ),
                        _buildToolbarButton(
                          icon: Icons.link_rounded,
                          tooltip: 'Link',
                          onPressed: _insertLink,
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: _isLoading || _controller == null
                  ? const Center(child: CircularProgressIndicator())
                  : Container(
                      color: Colors.white,
                      child: QuillEditor.basic(
                        controller: _controller!,
                        configurations: QuillEditorConfigurations(
                          placeholder: 'Start writing your note...',
                          padding: const EdgeInsets.all(20),
                      customStyles: DefaultStyles(
                        paragraph: DefaultTextBlockStyle(
                          const TextStyle(
                            fontSize: 16,
                            color: AppColors.textPrimary,
                            height: 1.6,
                          ),
                          const HorizontalSpacing(0, 0),
                          const VerticalSpacing(8, 8),
                          const VerticalSpacing(0, 0),
                          null,
                        ),
                        h1: DefaultTextBlockStyle(
                          const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            height: 1.4,
                          ),
                          const HorizontalSpacing(0, 0),
                          const VerticalSpacing(16, 8),
                          const VerticalSpacing(0, 0),
                          null,
                        ),
                        h2: DefaultTextBlockStyle(
                          const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            height: 1.4,
                          ),
                          const HorizontalSpacing(0, 0),
                          const VerticalSpacing(14, 6),
                          const VerticalSpacing(0, 0),
                          null,
                        ),
                        h3: DefaultTextBlockStyle(
                          const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            height: 1.4,
                          ),
                          const HorizontalSpacing(0, 0),
                          const VerticalSpacing(12, 4),
                          const VerticalSpacing(0, 0),
                          null,
                        ),
                        quote: DefaultTextBlockStyle(
                          TextStyle(
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textSecondary,
                            height: 1.6,
                          ),
                          const HorizontalSpacing(0, 0),
                          const VerticalSpacing(8, 8),
                          const VerticalSpacing(0, 0),
                          BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: AppColors.primary,
                                width: 4,
                              ),
                            ),
                          ),
                        ),
                        lists: DefaultListBlockStyle(
                          const TextStyle(
                            fontSize: 16,
                            color: AppColors.textPrimary,
                            height: 1.6,
                          ),
                          const HorizontalSpacing(0, 0),
                          const VerticalSpacing(4, 4),
                          const VerticalSpacing(0, 0),
                          null,
                          null,
                        ),
                        placeHolder: DefaultTextBlockStyle(
                          TextStyle(
                            fontSize: 16,
                            color: AppColors.textLight,
                            height: 1.6,
                          ),
                          const HorizontalSpacing(0, 0),
                          const VerticalSpacing(0, 0),
                          const VerticalSpacing(0, 0),
                          null,
                        ),
                      ),
                      sharedConfigurations: const QuillSharedConfigurations(
                        locale: Locale('en'),
                      ),
                    ),
                    focusNode: _editorFocusNode,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
