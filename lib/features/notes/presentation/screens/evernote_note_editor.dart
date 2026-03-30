import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:share_plus/share_plus.dart';
import '../../data/models/note_model.dart';
import '../../data/services/notes_service.dart';
import '../../data/services/voice_recording_service.dart';
import '../../data/services/attachment_service.dart';
import '../../theme/evernote_theme.dart';

/// Evernote-style Note Editor with dark theme and custom bottom toolbar
class EvernoteNoteEditor extends StatefulWidget {
  final NoteModel? note;
  final String? initialFolderId;
  final NoteType? initialType;

  const EvernoteNoteEditor({
    super.key,
    this.note,
    this.initialFolderId,
    this.initialType,
  });

  @override
  State<EvernoteNoteEditor> createState() => _EvernoteNoteEditorState();
}

class _EvernoteNoteEditorState extends State<EvernoteNoteEditor>
    with TickerProviderStateMixin {
  final NotesService _notesService = NotesService();
  final VoiceRecordingService _voiceService = VoiceRecordingService();
  final AttachmentService _attachmentService = AttachmentService();

  final TextEditingController _titleController = TextEditingController();
  late quill.QuillController _quillController;
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _contentFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  bool _isNewNote = true;
  String? _noteId;
  bool _isPinned = false;
  bool _isFavorite = false;
  bool _isArchived = false;
  String? _selectedColor;
  List<String> _selectedTagIds = [];
  DateTime? _reminderDate;
  NotePriority _priority = NotePriority.none;
  String? _folderId;
  NoteType _noteType = NoteType.text;
  String? _voiceRecordingPath;
  int? _voiceDurationSeconds;
  List<String> _attachments = [];
  String? _voiceTranscript;
  bool _isLocked = false;
  String? _aiSummary;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _hasChanges = false;
  bool _isSaving = false;
  bool _showFormatBar = false;

  @override
  void initState() {
    super.initState();
    _initializeNote();
    _fadeController = AnimationController(
      duration: EvernoteTheme.durationNormal,
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: EvernoteTheme.curveDefault,
    );
    _fadeController.forward();
  }

  void _initializeNote() {
    if (widget.note != null) {
      _isNewNote = false;
      _noteId = widget.note!.id;
      _titleController.text = widget.note!.title;
      _isPinned = widget.note!.isPinned;
      _isFavorite = widget.note!.isFavorite;
      _isArchived = widget.note!.isArchived;
      _selectedColor = widget.note!.color;
      _selectedTagIds = List.from(widget.note!.tagIds);
      _reminderDate = widget.note!.reminderDate;
      _priority = widget.note!.priority;
      _folderId = widget.note!.folderId;
      _voiceRecordingPath = widget.note!.voiceRecordingPath;
      _voiceDurationSeconds = widget.note!.voiceDurationSeconds;
      _attachments = List.from(widget.note!.attachments);
      _voiceTranscript = widget.note!.voiceTranscript;
      _isLocked = widget.note!.isLocked;
      _aiSummary = widget.note!.aiSummary;

      try {
        if (widget.note!.content.isNotEmpty &&
            widget.note!.content.startsWith('[')) {
          _quillController = quill.QuillController(
            document: quill.Document.fromJson(jsonDecode(widget.note!.content)),
            selection: const TextSelection.collapsed(offset: 0),
          );
        } else {
          _quillController = quill.QuillController.basic();
          if (widget.note!.content.isNotEmpty) {
            _quillController.document.insert(0, widget.note!.content);
          }
        }
      } catch (_) {
        _quillController = quill.QuillController.basic();
      }
    } else {
      _folderId = widget.initialFolderId;
      _noteType = widget.initialType ?? NoteType.text;
      _quillController = quill.QuillController.basic();
    }

    _titleController.addListener(_onContentChanged);
    _quillController.addListener(_onContentChanged);
  }

  void _onContentChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _titleController.dispose();
    _quillController.dispose();
    _titleFocusNode.dispose();
    _contentFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: EvernoteTheme.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_hasChanges) await _saveNote();
        if (mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: EvernoteTheme.background,
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(child: _buildBody()),
                if (_showFormatBar) _buildFormatBar(),
                _buildBottomToolbar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: EvernoteTheme.background,
        border: Border(
          bottom: BorderSide(
            color: EvernoteTheme.border.withOpacity(0.5),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Back button
          _buildIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () async {
              if (_hasChanges) await _saveNote();
              if (mounted) Navigator.pop(context);
            },
          ),
          const Spacer(),

          // Saving indicator
          if (_isSaving)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: EvernoteTheme.primary,
              ),
            )
          else ...[
            // Pin button
            _buildIconButton(
              icon: _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              color: _isPinned ? EvernoteTheme.pinned : null,
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _isPinned = !_isPinned;
                  _hasChanges = true;
                });
              },
            ),

            // Favorite button
            _buildIconButton(
              icon: _isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
              color: _isFavorite ? EvernoteTheme.favorite : null,
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _isFavorite = !_isFavorite;
                  _hasChanges = true;
                });
              },
            ),

            // More options
            _buildIconButton(
              icon: Icons.more_vert_rounded,
              onTap: _showMoreOptions,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    Color? color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: EvernoteTheme.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 20,
          color: color ?? EvernoteTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // Title field
          _buildTitleField(),

          // Tags display
          if (_selectedTagIds.isNotEmpty) _buildTagsDisplay(),

          // Voice recording card
          if (_voiceRecordingPath != null) _buildVoiceCard(),

          // Attachments
          if (_attachments.isNotEmpty) _buildAttachmentsSection(),

          // Editor
          _buildEditor(),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildTitleField() {
    return TextField(
      controller: _titleController,
      focusNode: _titleFocusNode,
      style: EvernoteTheme.displayMedium.copyWith(
        color: EvernoteTheme.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      cursorColor: EvernoteTheme.primary,
      decoration: InputDecoration(
        hintText: 'Title',
        hintStyle: EvernoteTheme.displayMedium.copyWith(
          color: EvernoteTheme.textMuted,
          fontWeight: FontWeight.w600,
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        contentPadding: EdgeInsets.zero,
      ),
      maxLines: null,
      textCapitalization: TextCapitalization.sentences,
    );
  }

  Widget _buildTagsDisplay() {
    final tags = _selectedTagIds
        .map((id) => _notesService.getTag(id))
        .where((t) => t != null)
        .toList();

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: tags.map((tag) {
          final color = _parseColor(tag!.color) ?? EvernoteTheme.primary;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(EvernoteTheme.radiusFull),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tag_rounded, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  tag.name,
                  style: EvernoteTheme.labelSmall.copyWith(color: color),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildVoiceCard() {
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            EvernoteTheme.primary.withOpacity(0.15),
            EvernoteTheme.primaryDark.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EvernoteTheme.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: EvernoteTheme.primary.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mic_rounded,
              color: EvernoteTheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Voice Recording',
                  style: EvernoteTheme.titleMedium.copyWith(
                    color: EvernoteTheme.textPrimary,
                  ),
                ),
                Text(
                  _formatDuration(_voiceDurationSeconds ?? 0),
                  style: EvernoteTheme.bodySmall.copyWith(
                    color: EvernoteTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          ValueListenableBuilder<RecordingState>(
            valueListenable: _voiceService.stateNotifier,
            builder: (_, state, __) => IconButton(
              icon: Icon(
                state == RecordingState.playing
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                color: EvernoteTheme.primary,
                size: 44,
              ),
              onPressed: () {
                if (state == RecordingState.playing) {
                  _voiceService.pausePlayback();
                } else {
                  _voiceService.playRecording(_voiceRecordingPath!);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            'Attachments',
            style: EvernoteTheme.titleSmall.copyWith(
              color: EvernoteTheme.textSecondary,
            ),
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _attachments.length,
            itemBuilder: (_, i) => _buildAttachmentTile(_attachments[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentTile(String path) {
    final isImage = _attachmentService.isImage(path);

    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EvernoteTheme.border),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: isImage
                ? Image.file(
                    File(path),
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 100,
                    height: 100,
                    color: EvernoteTheme.surface,
                    child: Icon(
                      _attachmentService.isPdf(path)
                          ? Icons.picture_as_pdf
                          : Icons.insert_drive_file,
                      size: 32,
                      color: EvernoteTheme.textTertiary,
                    ),
                  ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () async {
                await _attachmentService.deleteAttachment(path);
                setState(() {
                  _attachments.remove(path);
                  _hasChanges = true;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: EvernoteTheme.error.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: quill.QuillEditor(
        controller: _quillController,
        scrollController: ScrollController(),
        focusNode: _contentFocusNode,
        configurations: quill.QuillEditorConfigurations(
          placeholder: 'Start writing...',
          padding: EdgeInsets.zero,
          expands: false,
          autoFocus: false,
          customStyles: quill.DefaultStyles(
            paragraph: quill.DefaultTextBlockStyle(
              EvernoteTheme.bodyLarge.copyWith(
                color: EvernoteTheme.textPrimary,
                height: 1.7,
              ),
              const quill.HorizontalSpacing(0, 0),
              const quill.VerticalSpacing(8, 8),
              const quill.VerticalSpacing(0, 0),
              null,
            ),
            placeHolder: quill.DefaultTextBlockStyle(
              EvernoteTheme.bodyLarge.copyWith(
                color: EvernoteTheme.textMuted,
              ),
              const quill.HorizontalSpacing(0, 0),
              const quill.VerticalSpacing(0, 0),
              const quill.VerticalSpacing(0, 0),
              null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormatBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: EvernoteTheme.surface,
        border: Border(
          top: BorderSide(color: EvernoteTheme.border, width: 0.5),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFormatButton(Icons.format_bold, () {
              _quillController.formatSelection(quill.Attribute.bold);
            }),
            _buildFormatButton(Icons.format_italic, () {
              _quillController.formatSelection(quill.Attribute.italic);
            }),
            _buildFormatButton(Icons.format_underlined, () {
              _quillController.formatSelection(quill.Attribute.underline);
            }),
            _buildFormatButton(Icons.strikethrough_s, () {
              _quillController.formatSelection(quill.Attribute.strikeThrough);
            }),
            Container(
              width: 1,
              height: 24,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: EvernoteTheme.border,
            ),
            _buildFormatButton(Icons.format_list_bulleted, () {
              _quillController.formatSelection(quill.Attribute.ul);
            }),
            _buildFormatButton(Icons.format_list_numbered, () {
              _quillController.formatSelection(quill.Attribute.ol);
            }),
            _buildFormatButton(Icons.checklist, () {
              _quillController.formatSelection(quill.Attribute.unchecked);
            }),
            Container(
              width: 1,
              height: 24,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: EvernoteTheme.border,
            ),
            _buildFormatButton(Icons.format_quote, () {
              _quillController.formatSelection(quill.Attribute.blockQuote);
            }),
            _buildFormatButton(Icons.code, () {
              _quillController.formatSelection(quill.Attribute.codeBlock);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: EvernoteTheme.surfaceLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color: EvernoteTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _buildBottomToolbar() {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: EvernoteTheme.surface,
        border: Border(
          top: BorderSide(color: EvernoteTheme.border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Format toggle
          _buildToolbarIcon(
            icon: _showFormatBar ? Icons.keyboard_hide : Icons.text_format,
            isActive: _showFormatBar,
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _showFormatBar = !_showFormatBar);
            },
          ),

          // Color picker
          _buildToolbarIcon(
            icon: Icons.palette_outlined,
            onTap: _showColorPicker,
          ),

          // Tags
          _buildToolbarIcon(
            icon: Icons.tag_rounded,
            onTap: _showTagPicker,
          ),

          // Voice
          _buildToolbarIcon(
            icon: Icons.mic_outlined,
            onTap: _startVoiceRecording,
          ),

          // Attachments
          _buildToolbarIcon(
            icon: Icons.attach_file_rounded,
            onTap: _showAttachmentOptions,
          ),

          // Reminder
          _buildToolbarIcon(
            icon: _reminderDate != null
                ? Icons.alarm_on_rounded
                : Icons.alarm_outlined,
            isActive: _reminderDate != null,
            onTap: _showReminderPicker,
          ),

          const Spacer(),

          // Save button - constrained to prevent overflow
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 100),
            child: GestureDetector(
              onTap: _saveNote,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: EvernoteTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(EvernoteTheme.radiusFull),
                  boxShadow: [
                    BoxShadow(
                      color: EvernoteTheme.primary.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: EvernoteTheme.textOnPrimary,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: EvernoteTheme.textOnPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarIcon({
    required IconData icon,
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: isActive
              ? EvernoteTheme.primary.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 22,
          color: isActive ? EvernoteTheme.primary : EvernoteTheme.textSecondary,
        ),
      ),
    );
  }

  // ============ Actions ============

  Future<void> _saveNote() async {
    if (_isSaving) return;

    final title = _titleController.text.trim();
    final content = jsonEncode(_quillController.document.toDelta().toJson());

    if (title.isEmpty && _quillController.document.isEmpty()) {
      if (!_isNewNote && _noteId != null) {
        await _notesService.deleteNote(_noteId!);
      }
      if (mounted) Navigator.pop(context);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final noteType = _voiceRecordingPath != null
          ? NoteType.voice
          : (_attachments.isNotEmpty ? NoteType.image : NoteType.text);

      if (_isNewNote) {
        _noteId = await _notesService.createNote(
          title: title.isEmpty ? 'Untitled' : title,
          content: content,
          tagIds: _selectedTagIds,
          color: _selectedColor,
          folderId: _folderId,
        );
        _isNewNote = false;

        final note = _notesService.getNote(_noteId!);
        if (note != null) {
          await _notesService.updateNote(
            note.copyWith(
              isPinned: _isPinned,
              isFavorite: _isFavorite,
              reminderDate: _reminderDate,
              priority: _priority,
              noteType: noteType,
              voiceRecordingPath: _voiceRecordingPath,
              voiceDurationSeconds: _voiceDurationSeconds,
              attachments: _attachments,
            ),
          );
        }
      } else {
        final note = _notesService.getNote(_noteId!);
        if (note != null) {
          await _notesService.updateNote(
            note.copyWith(
              title: title.isEmpty ? 'Untitled' : title,
              content: content,
              tagIds: _selectedTagIds,
              color: _selectedColor,
              isPinned: _isPinned,
              isFavorite: _isFavorite,
              isArchived: _isArchived,
              reminderDate: _reminderDate,
              priority: _priority,
              folderId: _folderId,
              noteType: noteType,
              voiceRecordingPath: _voiceRecordingPath,
              voiceDurationSeconds: _voiceDurationSeconds,
              attachments: _attachments,
            ),
          );
        }
      }

      _hasChanges = false;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Note saved'),
            backgroundColor: EvernoteTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: EvernoteTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _shareNote() async {
    final title = _titleController.text.trim();
    final plainText = _quillController.document.toPlainText().trim();
    
    if (title.isEmpty && plainText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Nothing to share'),
          backgroundColor: EvernoteTheme.surface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    
    // Format the note content for sharing
    final shareText = StringBuffer();
    if (title.isNotEmpty) {
      shareText.writeln(title);
      shareText.writeln('─' * 20);
      shareText.writeln();
    }
    if (plainText.isNotEmpty) {
      shareText.writeln(plainText);
    }
    shareText.writeln();
    shareText.writeln('Shared from Dlyminder Notes');
    
    try {
      await Share.share(
        shareText.toString(),
        subject: title.isNotEmpty ? title : 'Note from Dlyminder',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: $e'),
            backgroundColor: EvernoteTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: EvernoteTheme.modalDecoration,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: EvernoteTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              _buildOptionTile(
                icon: Icons.archive_outlined,
                label: _isArchived ? 'Unarchive' : 'Archive',
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _isArchived = !_isArchived;
                    _hasChanges = true;
                  });
                },
              ),
              _buildOptionTile(
                icon: Icons.lock_outlined,
                label: _isLocked ? 'Remove Lock' : 'Lock Note',
                onTap: () {
                  Navigator.pop(ctx);
                  // TODO: Implement lock
                },
              ),
              _buildOptionTile(
                icon: Icons.share_outlined,
                label: 'Share',
                onTap: () {
                  Navigator.pop(ctx);
                  _shareNote();
                },
              ),
              _buildOptionTile(
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                isDestructive: true,
                onTap: () async {
                  Navigator.pop(ctx);
                  if (_noteId != null) {
                    await _notesService.deleteNote(_noteId!);
                    if (mounted) Navigator.pop(context);
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? EvernoteTheme.error : EvernoteTheme.textPrimary;

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 16),
            Text(
              label,
              style: EvernoteTheme.bodyLarge.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }

  void _showColorPicker() {
    final colors = EvernoteTheme.categoryColors;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: EvernoteTheme.modalDecoration,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: EvernoteTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Note Color', style: EvernoteTheme.titleLarge),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                // Clear color option
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = null;
                      _hasChanges = true;
                    });
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: EvernoteTheme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selectedColor == null
                            ? EvernoteTheme.primary
                            : EvernoteTheme.border,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.format_color_reset,
                      size: 20,
                      color: EvernoteTheme.textTertiary,
                    ),
                  ),
                ),
                ...colors.map((color) {
                  final hex =
                      '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
                  final isSelected = _selectedColor == hex;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedColor = hex;
                        _hasChanges = true;
                      });
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      width: 44,
                      height: 44,
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
                              size: 20,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  );
                }),
              ],
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  void _showTagPicker() {
    final tags = _notesService.getAllTags();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          decoration: EvernoteTheme.modalDecoration,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: EvernoteTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Tags', style: EvernoteTheme.titleLarge),
                  TextButton.icon(
                    onPressed: () => _createNewTag(setS),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New'),
                    style: TextButton.styleFrom(
                      foregroundColor: EvernoteTheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (tags.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No tags yet',
                      style: EvernoteTheme.bodyMedium.copyWith(
                        color: EvernoteTheme.textTertiary,
                      ),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: tags.length,
                    itemBuilder: (_, i) {
                      final tag = tags[i];
                      final isSelected = _selectedTagIds.contains(tag.id);
                      final color =
                          _parseColor(tag.color) ?? EvernoteTheme.primary;

                      return ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.tag_rounded,
                            size: 18,
                            color: color,
                          ),
                        ),
                        title: Text(
                          tag.name,
                          style: EvernoteTheme.titleMedium,
                        ),
                        trailing: Icon(
                          isSelected
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          color: isSelected
                              ? EvernoteTheme.primary
                              : EvernoteTheme.textTertiary,
                        ),
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedTagIds.remove(tag.id);
                            } else {
                              _selectedTagIds.add(tag.id);
                            }
                            _hasChanges = true;
                          });
                          setS(() {});
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _createNewTag(StateSetter setS) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: EvernoteTheme.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text('New Tag', style: EvernoteTheme.titleLarge),
        content: TextField(
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
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: EvernoteTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await _notesService.createTag(controller.text.trim());
                Navigator.pop(context);
                setS(() {});
                setState(() {});
              }
            },
            child: const Text(
              'Create',
              style: TextStyle(color: EvernoteTheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  void _startVoiceRecording() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _VoiceRecordingSheet(
        voiceService: _voiceService,
        onComplete: (path, duration) {
          setState(() {
            _voiceRecordingPath = path;
            _voiceDurationSeconds = duration;
            _hasChanges = true;
          });
        },
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: EvernoteTheme.modalDecoration,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: EvernoteTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            _buildAttachmentOption(
              icon: Icons.photo_library_rounded,
              color: EvernoteTheme.info,
              label: 'Gallery',
              onTap: () async {
                Navigator.pop(ctx);
                final path = await _attachmentService.pickImage();
                if (path != null) {
                  setState(() {
                    _attachments.add(path);
                    _hasChanges = true;
                  });
                }
              },
            ),
            _buildAttachmentOption(
              icon: Icons.camera_alt_rounded,
              color: EvernoteTheme.success,
              label: 'Camera',
              onTap: () async {
                Navigator.pop(ctx);
                final path = await _attachmentService.takePhoto();
                if (path != null) {
                  setState(() {
                    _attachments.add(path);
                    _hasChanges = true;
                  });
                }
              },
            ),
            _buildAttachmentOption(
              icon: Icons.attach_file_rounded,
              color: EvernoteTheme.warning,
              label: 'File',
              onTap: () async {
                Navigator.pop(ctx);
                final path = await _attachmentService.pickFile();
                if (path != null) {
                  setState(() {
                    _attachments.add(path);
                    _hasChanges = true;
                  });
                }
              },
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(label, style: EvernoteTheme.titleMedium),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
    );
  }

  void _showReminderPicker() {
    final now = DateTime.now();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: EvernoteTheme.modalDecoration,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: EvernoteTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Set Reminder', style: EvernoteTheme.titleLarge),
                if (_reminderDate != null)
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _reminderDate = null;
                        _hasChanges = true;
                      });
                    },
                    child: const Text(
                      'Clear',
                      style: TextStyle(color: EvernoteTheme.error),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Quick Presets',
              style: EvernoteTheme.labelMedium.copyWith(
                color: EvernoteTheme.textTertiary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildReminderChip('In 15 min', now.add(const Duration(minutes: 15))),
                _buildReminderChip('In 1 hour', now.add(const Duration(hours: 1))),
                _buildReminderChip('In 3 hours', now.add(const Duration(hours: 3))),
                _buildReminderChip(
                  'Tomorrow 9am',
                  DateTime(now.year, now.month, now.day + 1, 9, 0),
                ),
                _buildReminderChip(
                  'Tomorrow 2pm',
                  DateTime(now.year, now.month, now.day + 1, 14, 0),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: EvernoteTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: EvernoteTheme.textSecondary,
                ),
              ),
              title: const Text('Custom Date & Time'),
              trailing: const Icon(
                Icons.chevron_right,
                color: EvernoteTheme.textTertiary,
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final date = await showDatePicker(
                  context: context,
                  initialDate: now,
                  firstDate: now,
                  lastDate: now.add(const Duration(days: 365)),
                );
                if (date != null && mounted) {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (time != null) {
                    setState(() {
                      _reminderDate = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time.hour,
                        time.minute,
                      );
                      _hasChanges = true;
                    });
                  }
                }
              },
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderChip(String label, DateTime time) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        HapticFeedback.lightImpact();
        setState(() {
          _reminderDate = time;
          _hasChanges = true;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: EvernoteTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: EvernoteTheme.border),
        ),
        child: Text(
          label,
          style: EvernoteTheme.labelMedium.copyWith(
            color: EvernoteTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  // ============ Helpers ============

  Color? _parseColor(String? c) {
    if (c == null || c.isEmpty) return null;
    try {
      return Color(int.parse(c.replaceFirst('#', '0xFF')));
    } catch (_) {
      return null;
    }
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins}:${secs.toString().padLeft(2, '0')}';
  }
}

// ============ Voice Recording Sheet ============

class _VoiceRecordingSheet extends StatefulWidget {
  final VoiceRecordingService voiceService;
  final Function(String path, int duration) onComplete;

  const _VoiceRecordingSheet({
    required this.voiceService,
    required this.onComplete,
  });

  @override
  State<_VoiceRecordingSheet> createState() => _VoiceRecordingSheetState();
}

class _VoiceRecordingSheetState extends State<_VoiceRecordingSheet> {
  bool _isRecording = false;
  int _duration = 0;
  String? _recordingPath;

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  Future<void> _startRecording() async {
    final started = await widget.voiceService.startRecording();
    if (started) {
      setState(() => _isRecording = true);
      _updateDuration();
    }
  }

  void _updateDuration() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_isRecording && mounted) {
        setState(() => _duration++);
        _updateDuration();
      }
    });
  }

  Future<void> _stopRecording() async {
    _recordingPath = await widget.voiceService.stopRecording();
    setState(() => _isRecording = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: EvernoteTheme.modalDecoration,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: EvernoteTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            _isRecording ? 'Recording...' : 'Recording Complete',
            style: EvernoteTheme.headlineSmall,
          ),
          const SizedBox(height: 24),

          // Duration display
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: EvernoteTheme.primary.withOpacity(0.1),
              border: Border.all(
                color: _isRecording
                    ? EvernoteTheme.primary
                    : EvernoteTheme.success,
                width: 3,
              ),
            ),
            child: Center(
              child: Text(
                _formatDuration(_duration),
                style: EvernoteTheme.displayMedium.copyWith(
                  color: _isRecording
                      ? EvernoteTheme.primary
                      : EvernoteTheme.success,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Cancel
              TextButton(
                onPressed: () async {
                  if (_isRecording) await _stopRecording();
                  if (_recordingPath != null) {
                    await widget.voiceService.deleteRecording(_recordingPath!);
                  }
                  if (mounted) Navigator.pop(context);
                },
                child: Text(
                  'Cancel',
                  style: TextStyle(color: EvernoteTheme.textSecondary),
                ),
              ),
              const SizedBox(width: 24),

              // Stop/Save
              GestureDetector(
                onTap: () async {
                  if (_isRecording) {
                    await _stopRecording();
                  } else if (_recordingPath != null) {
                    widget.onComplete(_recordingPath!, _duration);
                    Navigator.pop(context);
                  }
                },
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isRecording
                        ? EvernoteTheme.error
                        : EvernoteTheme.primary,
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop_rounded : Icons.check_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins}:${secs.toString().padLeft(2, '0')}';
  }
}
