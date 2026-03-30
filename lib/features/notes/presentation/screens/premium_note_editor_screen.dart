import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../../data/models/note_model.dart';
import '../../data/models/folder_model.dart';
import '../../data/services/notes_service.dart';
import '../../data/services/voice_recording_service.dart';
import '../../data/services/attachment_service.dart';
import '../../../../core/widgets/toast/toast.dart';

class PremiumNoteEditorScreen extends StatefulWidget {
  final NoteModel? note;
  final String? initialFolderId;
  final NoteType? initialType;

  const PremiumNoteEditorScreen({super.key, this.note, this.initialFolderId, this.initialType});

  @override
  State<PremiumNoteEditorScreen> createState() => _PremiumNoteEditorScreenState();
}

class _PremiumNoteEditorScreenState extends State<PremiumNoteEditorScreen> with TickerProviderStateMixin {
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
  bool _isGeneratingSummary = false;
  bool _isTranscribing = false;
  bool _noteUnlocked = false;
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _hasChanges = false;
  bool _isSaving = false;

  final List<Color> _noteColors = [
    Colors.transparent, const Color(0xFFFFCDD2), const Color(0xFFF8BBD9),
    const Color(0xFFE1BEE7), const Color(0xFFD1C4E9), const Color(0xFFC5CAE9),
    const Color(0xFFBBDEFB), const Color(0xFFB3E5FC), const Color(0xFFB2EBF2),
    const Color(0xFFB2DFDB), const Color(0xFFC8E6C9), const Color(0xFFDCEDC8),
    const Color(0xFFF0F4C3), const Color(0xFFFFF9C4), const Color(0xFFFFECB3),
    const Color(0xFFFFE0B2), const Color(0xFFFFCCBC), const Color(0xFFD7CCC8),
  ];

  @override
  void initState() {
    super.initState();
    _initializeNote();
    _fadeController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
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
      _noteUnlocked = !widget.note!.isLocked;
      try {
        if (widget.note!.content.isNotEmpty && widget.note!.content.startsWith('[')) {
          _quillController = quill.QuillController(
            document: quill.Document.fromJson(jsonDecode(widget.note!.content)),
            selection: const TextSelection.collapsed(offset: 0),
          );
        } else {
          _quillController = quill.QuillController.basic();
          if (widget.note!.content.isNotEmpty) _quillController.document.insert(0, widget.note!.content);
        }
      } catch (_) {
        _quillController = quill.QuillController.basic();
      }
    } else {
      _folderId = widget.initialFolderId;
      _noteType = widget.initialType ?? NoteType.text;
      
      // Load meeting template for new meeting notes
      if (_noteType == NoteType.meeting) {
        final template = _notesService.generateMeetingTemplate();
        try {
          _quillController = quill.QuillController(
            document: quill.Document.fromJson(jsonDecode(template)),
            selection: const TextSelection.collapsed(offset: 0),
          );
          _titleController.text = 'Meeting Notes';
        } catch (_) {
          _quillController = quill.QuillController.basic();
        }
      } else {
        _quillController = quill.QuillController.basic();
      }
    }
    _titleController.addListener(_onContentChanged);
    _quillController.addListener(_onContentChanged);
  }

  void _onContentChanged() { if (!_hasChanges) setState(() => _hasChanges = true); }

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

  Color? _parseColor(String? c) {
    if (c == null || c.isEmpty) return null;
    try { return Color(int.parse(c.replaceFirst('#', '0xFF'))); } catch (_) { return null; }
  }

  // Continued in part 2...
  @override
  Widget build(BuildContext context) => _buildScaffold();

  Widget _buildScaffold() {
    final bg = _parseColor(_selectedColor) ?? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0B0F19) : const Color(0xFFF9FAFB));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_hasChanges) await _saveNote();
        if (mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: bg,
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: SafeArea(child: Column(children: [
            _buildAppBar(isDark),
            _buildToolbar(isDark),
            Expanded(child: _buildBody(isDark))
          ])),
        ),
        bottomNavigationBar: _buildBottomBar(isDark),
      ),
    );
  }

  Widget _buildToolbar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
           bottom: BorderSide(color: isDark ? Colors.white.withAlpha(8) : Colors.black.withAlpha(5)),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: quill.QuillSimpleToolbar(
        controller: _quillController,
        configurations: quill.QuillSimpleToolbarConfigurations(
          showFontFamily: false,
          showFontSize: false,
          showSearchButton: false,
          showInlineCode: false,
          showSubscript: false,
          showSuperscript: false,
          toolbarIconAlignment: WrapAlignment.start,
          multiRowsDisplay: false,
          buttonOptions: const quill.QuillSimpleToolbarButtonOptions(
            base: quill.QuillToolbarBaseButtonOptions(
              iconSize: 18,
            ),
          ),
          decoration: const BoxDecoration(
            color: Colors.transparent,
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(children: [
        GestureDetector(
          onTap: () async { if (_hasChanges) await _saveNote(); if (mounted) Navigator.pop(context); },
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withAlpha(8) : Colors.black.withAlpha(5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: isDark ? Colors.white70 : Colors.black87),
          ),
        ),
        const Spacer(),
        if (_isSaving) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 1.5))
        else ...[
          _buildAppBarButton(
            icon: _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
            color: _isPinned ? Colors.amber : (isDark ? Colors.white70 : Colors.black54),
            onTap: () { setState(() { _isPinned = !_isPinned; _hasChanges = true; }); HapticFeedback.lightImpact(); },
          ),
          const SizedBox(width: 4),
          _buildAppBarButton(
            icon: _isFavorite ? Icons.favorite : Icons.favorite_border,
            color: _isFavorite ? Colors.red : (isDark ? Colors.white70 : Colors.black54),
            onTap: () { setState(() { _isFavorite = !_isFavorite; _hasChanges = true; }); HapticFeedback.lightImpact(); },
          ),
          const SizedBox(width: 4),
          _buildAppBarButton(
            icon: Icons.more_horiz_rounded,
            color: isDark ? Colors.white70 : Colors.black54,
            onTap: _showMoreOptions,
          ),
        ],
      ]),
    );
  }

  Widget _buildAppBarButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLocked && !_noteUnlocked && !_isNewNote) {
      return _buildLockedScreen(isDark);
    }
    
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildTitleField(isDark),
        _buildFolderChip(isDark),
        if (_aiSummary != null && _aiSummary!.isNotEmpty) _buildAiSummaryCard(isDark),
        if (_voiceRecordingPath != null) _buildVoiceCard(isDark),
        if (_voiceTranscript != null && _voiceTranscript!.isNotEmpty) _buildTranscriptCard(isDark),
        if (_attachments.isNotEmpty) _buildAttachments(isDark),
        _buildEditor(isDark),
        const SizedBox(height: 100),
      ]),
    );
  }

  Widget _buildLockedScreen(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_rounded, size: 48, color: Colors.orange),
            ),
            const SizedBox(height: 24),
            Text(
              'This Note is Protected',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Enter your password or use biometrics to unlock',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _showPasswordUnlockDialog,
                  icon: const Icon(Icons.password),
                  label: const Text('Password'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _unlockWithBiometric,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Biometric'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPasswordUnlockDialog() {
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.lock_open, color: Colors.blue),
            const SizedBox(width: 12),
            const Text('Unlock Note'),
          ],
        ),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter password',
            prefixIcon: const Icon(Icons.password),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty && _noteId != null) {
                final verified = await _notesService.verifyNotePassword(_noteId!, controller.text);
                if (verified) {
                  setState(() => _noteUnlocked = true);
                  Navigator.pop(context);
                  NotesToast.noteUnlocked(context);
                } else {
                  NotesToast.error(context, message: 'Incorrect password');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
  }

  Future<void> _unlockWithBiometric() async {
    final canUseBiometric = await _notesService.isBiometricAvailable();
    if (!canUseBiometric) {
      if (mounted) {
        NotesToast.error(context, message: 'Biometric authentication not available');
      }
      return;
    }

    final authenticated = await _notesService.authenticateWithBiometric();
    if (authenticated && mounted) {
      setState(() => _noteUnlocked = true);
      NotesToast.noteUnlocked(context);
    }
  }

  Widget _buildAiSummaryCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.withOpacity(0.15), Colors.purple.withOpacity(0.15)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome, size: 18, color: Colors.blue),
              ),
              const SizedBox(width: 12),
              Text(
                'AI Summary',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _aiSummary = null),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _aiSummary!,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black54,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.withOpacity(0.15), Colors.teal.withOpacity(0.15)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.text_fields, size: 18, color: Colors.green),
              ),
              const SizedBox(width: 12),
              Text(
                'Voice Transcript',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _voiceTranscript!,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black54,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleField(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: TextField(
        controller: _titleController,
        focusNode: _titleFocusNode,
        style: TextStyle(
          fontSize: 24, 
          fontWeight: FontWeight.w700, 
          letterSpacing: -0.3,
          color: isDark ? Colors.white : const Color(0xFF111827),
        ),
        decoration: InputDecoration(
          hintText: 'Title', 
          border: InputBorder.none, 
          hintStyle: TextStyle(
            color: isDark ? Colors.white30 : const Color(0xFFD1D5DB),
            fontWeight: FontWeight.w600,
          ),
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        maxLines: null,
        textCapitalization: TextCapitalization.sentences,
      ),
    );
  }

  Widget _buildVoiceCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.purple.withOpacity(0.2), Colors.blue.withOpacity(0.2)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.purple.withOpacity(0.3), shape: BoxShape.circle),
          child: const Icon(Icons.mic, color: Colors.purple)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Voice Recording', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          Text('${(_voiceDurationSeconds ?? 0) ~/ 60}:${((_voiceDurationSeconds ?? 0) % 60).toString().padLeft(2, '0')}',
            style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
        ])),
        ValueListenableBuilder<RecordingState>(
          valueListenable: _voiceService.stateNotifier,
          builder: (_, state, __) => IconButton(
            icon: Icon(state == RecordingState.playing ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.purple, size: 40),
            onPressed: () => state == RecordingState.playing ? _voiceService.pausePlayback() : _voiceService.playRecording(_voiceRecordingPath!),
          ),
        ),
        IconButton(icon: Icon(Icons.delete_outline, color: Colors.red.shade400), onPressed: _deleteVoice),
      ]),
    );
  }

  void _deleteVoice() async {
    if (_voiceRecordingPath != null) await _voiceService.deleteRecording(_voiceRecordingPath!);
    setState(() { _voiceRecordingPath = null; _voiceDurationSeconds = null; _hasChanges = true; });
  }

  Widget _buildAttachments(bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Attachments', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black54)),
      const SizedBox(height: 8),
      SizedBox(height: 100, child: ListView.builder(
        scrollDirection: Axis.horizontal, itemCount: _attachments.length,
        itemBuilder: (_, i) => _buildAttachmentTile(_attachments[i], isDark),
      )),
      const SizedBox(height: 16),
    ]);
  }

  Widget _buildAttachmentTile(String path, bool isDark) {
    final isImg = _attachmentService.isImage(path);
    return Container(
      width: 100, margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.white24 : Colors.black12)),
      child: Stack(children: [
        ClipRRect(borderRadius: BorderRadius.circular(11),
          child: isImg ? Image.file(File(path), width: 100, height: 100, fit: BoxFit.cover)
            : Container(width: 100, height: 100, color: isDark ? Colors.white10 : const Color(0x0D000000),
                child: Icon(_attachmentService.isPdf(path) ? Icons.picture_as_pdf : Icons.insert_drive_file, size: 32)),
        ),
        Positioned(top: 4, right: 4, child: GestureDetector(
          onTap: () async { await _attachmentService.deleteAttachment(path); setState(() { _attachments.remove(path); _hasChanges = true; }); },
          child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.red.withOpacity(0.8), shape: BoxShape.circle),
            child: const Icon(Icons.close, size: 14, color: Colors.white)),
        )),
      ]),
    );
  }

  Widget _buildEditor(bool isDark) {
    return quill.QuillEditor(
      controller: _quillController, scrollController: ScrollController(), focusNode: _contentFocusNode,
      configurations: quill.QuillEditorConfigurations(
        placeholder: 'Start writing...', 
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8), 
        expands: false, 
        autoFocus: false,
        customStyles: quill.DefaultStyles(
          paragraph: quill.DefaultTextBlockStyle(
            TextStyle(fontSize: 16, color: isDark ? Colors.white : const Color(0xFF4B5563), height: 1.6),
            const quill.HorizontalSpacing(0, 0), 
            const quill.VerticalSpacing(8, 8), 
            const quill.VerticalSpacing(0, 0), 
            null
          ),
          placeHolder: quill.DefaultTextBlockStyle(
             TextStyle(fontSize: 16, color: isDark ? Colors.white38 : const Color(0xFFA0AEC0)),
             const quill.HorizontalSpacing(0, 0), const quill.VerticalSpacing(0, 0), const quill.VerticalSpacing(0, 0), null
          )
        ),
      ),
    );
  }

  Widget _buildBottomBarIcon(IconData icon, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(icon, size: 20, color: isDark ? Colors.white60 : Colors.black54),
      ),
    );
  }

  Widget _buildBottomBar(bool isDark) {
    return Container(
      padding: EdgeInsets.only(left: 8, right: 12, top: 8, bottom: MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF9FAFB),
        border: Border(top: BorderSide(color: isDark ? Colors.white.withAlpha(8) : Colors.black.withAlpha(5))),
      ),
      child: Row(children: [
        _buildBottomBarIcon(Icons.palette_outlined, isDark, _showColorPicker),
        _buildBottomBarIcon(Icons.label_outline, isDark, _showTagPicker),
        _buildBottomBarIcon(Icons.folder_open_outlined, isDark, _showFolderPicker),
        _buildBottomBarIcon(Icons.mic_outlined, isDark, _startVoiceRecording),
        _buildBottomBarIcon(Icons.image_outlined, isDark, _showAttachmentOptions),
        _buildBottomBarIcon(Icons.alarm_outlined, isDark, _showReminderPicker),
        const Spacer(),
        GestureDetector(
          onTap: _saveNote,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check, color: Color(0xFF006D5B), size: 20),
              const SizedBox(width: 4),
              Text(
                'Save',
                style: TextStyle(
                  color: const Color(0xFF006D5B),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Future<void> _saveNote() async {
    if (_isSaving) return;
    final title = _titleController.text.trim();
    final content = jsonEncode(_quillController.document.toDelta().toJson());
    if (title.isEmpty && _quillController.document.isEmpty()) {
      if (!_isNewNote) await _notesService.deleteNote(_noteId!);
      if (mounted) Navigator.pop(context);
      return;
    }
    setState(() => _isSaving = true);
    try {
      NoteType noteType = _voiceRecordingPath != null ? NoteType.voice : (_attachments.isNotEmpty ? NoteType.image : NoteType.text);
      if (_isNewNote) {
        _noteId = await _notesService.createNote(title: title.isEmpty ? 'Untitled' : title, content: content, tagIds: _selectedTagIds, color: _selectedColor, folderId: _folderId);
        _isNewNote = false;
        final note = _notesService.getNote(_noteId!);
        if (note != null) await _notesService.updateNote(note.copyWith(isPinned: _isPinned, isFavorite: _isFavorite, reminderDate: _reminderDate, priority: _priority, noteType: noteType, voiceRecordingPath: _voiceRecordingPath, voiceDurationSeconds: _voiceDurationSeconds, attachments: _attachments));
      } else {
        final note = _notesService.getNote(_noteId!);
        if (note != null) await _notesService.updateNote(note.copyWith(title: title.isEmpty ? 'Untitled' : title, content: content, tagIds: _selectedTagIds, color: _selectedColor, isPinned: _isPinned, isFavorite: _isFavorite, isArchived: _isArchived, reminderDate: _reminderDate, priority: _priority, folderId: _folderId, noteType: noteType, voiceRecordingPath: _voiceRecordingPath, voiceDurationSeconds: _voiceDurationSeconds, attachments: _attachments));
      }
      _hasChanges = false;
      if (mounted) NotesToast.noteSaved(context);
    } catch (e) {
      if (mounted) NotesToast.error(context, message: 'Error: $e');
    } finally { if (mounted) setState(() => _isSaving = false); }
  }

  void _showColorPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(context: context, backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Note Color', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 16),
        Wrap(spacing: 12, runSpacing: 12, children: _noteColors.map((c) {
          final hex = c == Colors.transparent ? null : '#${c.value.toRadixString(16).substring(2)}';
          final sel = _selectedColor == hex;
          return GestureDetector(onTap: () { setState(() { _selectedColor = hex; _hasChanges = true; }); Navigator.pop(context); },
            child: Container(width: 44, height: 44, decoration: BoxDecoration(color: c == Colors.transparent ? (isDark ? Colors.white10 : const Color(0x0D000000)) : c, shape: BoxShape.circle, border: Border.all(color: sel ? Colors.blue : Colors.transparent, width: 3)),
              child: c == Colors.transparent ? Icon(Icons.format_color_reset, size: 20, color: isDark ? Colors.white54 : Colors.black38) : (sel ? const Icon(Icons.check, color: Colors.blue, size: 20) : null)));
        }).toList()),
      ])));
  }

  void _showTagPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tags = _notesService.getAllTags();
    showModalBottomSheet(context: context, backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(builder: (ctx, setS) => Container(padding: const EdgeInsets.all(20), constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Tags', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            TextButton.icon(onPressed: () => _createTag(setS), icon: const Icon(Icons.add, size: 18), label: const Text('New')),
          ]),
          const SizedBox(height: 16),
          if (tags.isEmpty) Center(child: Text('No tags yet', style: TextStyle(color: isDark ? Colors.white54 : Colors.black38)))
          else Flexible(child: ListView.builder(shrinkWrap: true, itemCount: tags.length, itemBuilder: (_, i) {
            final t = tags[i]; final sel = _selectedTagIds.contains(t.id);
            return ListTile(leading: Icon(Icons.label, color: _parseColor(t.color) ?? Colors.blue), title: Text(t.name),
              trailing: Icon(sel ? Icons.check_circle : Icons.circle_outlined, color: sel ? Colors.blue : null),
              onTap: () { setState(() { sel ? _selectedTagIds.remove(t.id) : _selectedTagIds.add(t.id); _hasChanges = true; }); setS(() {}); });
          })),
        ]))));
  }

  void _createTag(StateSetter setS) {
    final c = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(title: const Text('New Tag'), content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(hintText: 'Tag name')),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: () async { if (c.text.trim().isNotEmpty) { await _notesService.createTag(c.text.trim()); Navigator.pop(context); setS(() {}); setState(() {}); } }, child: const Text('Create'))]));
  }

  void _startVoiceRecording() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(context: context, backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white, isDismissible: false, enableDrag: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _VoiceRecordingSheet(voiceService: _voiceService, isDark: isDark, onComplete: (p, d) { setState(() { _voiceRecordingPath = p; _voiceDurationSeconds = d; _hasChanges = true; }); }));
  }

  void _showAttachmentOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(context: context, backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.photo_library, color: Colors.blue), title: const Text('Gallery'), onTap: () async { Navigator.pop(context); final p = await _attachmentService.pickImage(); if (p != null) setState(() { _attachments.add(p); _hasChanges = true; }); }),
        ListTile(leading: const Icon(Icons.camera_alt, color: Colors.green), title: const Text('Camera'), onTap: () async { Navigator.pop(context); final p = await _attachmentService.takePhoto(); if (p != null) setState(() { _attachments.add(p); _hasChanges = true; }); }),
        ListTile(leading: const Icon(Icons.attach_file, color: Colors.orange), title: const Text('File'), onTap: () async { Navigator.pop(context); final p = await _attachmentService.pickFile(); if (p != null) setState(() { _attachments.add(p); _hasChanges = true; }); }),
      ])));
  }

  void _showReminderPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1A1F) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Set Reminder', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                if (_reminderDate != null)
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() { _reminderDate = null; _hasChanges = true; });
                    },
                    child: const Text('Clear', style: TextStyle(color: Colors.red)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Quick Presets', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white54 : Colors.black54)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildReminderChip('In 15 min', now.add(const Duration(minutes: 15)), isDark),
                _buildReminderChip('In 1 hour', now.add(const Duration(hours: 1)), isDark),
                _buildReminderChip('In 3 hours', now.add(const Duration(hours: 3)), isDark),
                _buildReminderChip('Tomorrow 9am', DateTime(now.year, now.month, now.day + 1, 9, 0), isDark),
                _buildReminderChip('Tomorrow 2pm', DateTime(now.year, now.month, now.day + 1, 14, 0), isDark),
                _buildReminderChip('Next Monday', _getNextMonday(now), isDark),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.calendar_month_rounded, size: 20, color: isDark ? Colors.white70 : Colors.black54),
              ),
              title: const Text('Custom Date & Time'),
              subtitle: _reminderDate != null 
                  ? Text(_formatReminderDate(_reminderDate!), style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 12))
                  : null,
              trailing: Icon(Icons.chevron_right, color: isDark ? Colors.white38 : Colors.black38),
              onTap: () async {
                Navigator.pop(context);
                await _showCustomDateTimePicker();
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderChip(String label, DateTime time, bool isDark) {
    final isSelected = _reminderDate != null && 
        _reminderDate!.year == time.year && 
        _reminderDate!.month == time.month && 
        _reminderDate!.day == time.day && 
        _reminderDate!.hour == time.hour && 
        _reminderDate!.minute == time.minute;
    
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        setState(() { _reminderDate = time; _hasChanges = true; });
        HapticFeedback.lightImpact();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFF006D5B) 
              : isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(5),
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? null : Border.all(color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(8)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black54),
          ),
        ),
      ),
    );
  }

  DateTime _getNextMonday(DateTime from) {
    var daysUntilMonday = DateTime.monday - from.weekday;
    if (daysUntilMonday <= 0) daysUntilMonday += 7;
    return DateTime(from.year, from.month, from.day + daysUntilMonday, 9, 0);
  }

  String _formatReminderDate(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now);
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour:${date.minute.toString().padLeft(2, '0')} $ampm';
    
    if (diff.inDays == 0 && date.day == now.day) return 'Today at $timeStr';
    if (diff.inDays == 1 || (diff.inDays == 0 && date.day == now.day + 1)) return 'Tomorrow at $timeStr';
    return '${date.month}/${date.day}/${date.year} at $timeStr';
  }

  Future<void> _showCustomDateTimePicker() async {
    final date = await showDatePicker(
      context: context, 
      initialDate: _reminderDate ?? DateTime.now(), 
      firstDate: DateTime.now(), 
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context, 
      initialTime: TimeOfDay.fromDateTime(_reminderDate ?? DateTime.now()),
    );
    if (time == null) return;
    setState(() { 
      _reminderDate = DateTime(date.year, date.month, date.day, time.hour, time.minute); 
      _hasChanges = true; 
    });
  }

  void _showMoreOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(_isLocked ? Icons.lock_open : Icons.lock, color: Colors.orange),
              title: Text(_isLocked ? 'Unlock Note' : 'Lock Note'),
              subtitle: Text(_isLocked ? 'Remove password protection' : 'Protect with password'),
              onTap: () {
                Navigator.pop(context);
                if (_isLocked) {
                  _showRemoveLockDialog();
                } else {
                  _showSetPasswordDialog();
                }
              },
            ),
            ListTile(
              leading: Icon(
                _isGeneratingSummary ? Icons.hourglass_top : Icons.auto_awesome,
                color: Colors.blue,
              ),
              title: const Text('Generate AI Summary'),
              subtitle: const Text('Create a smart summary of your note'),
              onTap: _isGeneratingSummary ? null : () {
                Navigator.pop(context);
                _generateSummary();
              },
            ),
            if (_voiceRecordingPath != null)
              ListTile(
                leading: Icon(
                  _isTranscribing ? Icons.hourglass_top : Icons.text_fields,
                  color: Colors.green,
                ),
                title: const Text('Transcribe Voice'),
                subtitle: const Text('Convert speech to text'),
                onTap: _isTranscribing ? null : () {
                  Navigator.pop(context);
                  _transcribeVoice();
                },
              ),
            const Divider(),
            ListTile(
              leading: Icon(_isArchived ? Icons.unarchive : Icons.archive, color: Colors.purple),
              title: Text(_isArchived ? 'Unarchive' : 'Archive'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _isArchived = !_isArchived;
                  _hasChanges = true;
                });
              },
            ),
            if (!_isNewNote)
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red.shade400),
                title: Text('Delete', style: TextStyle(color: Colors.red.shade400)),
                onTap: () async {
                  Navigator.pop(context);
                  await _notesService.deleteNote(_noteId!);
                  if (mounted) Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showSetPasswordDialog() {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.lock, color: Colors.orange, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Lock Note'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Enter password',
                prefixIcon: const Icon(Icons.password),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Confirm password',
                prefixIcon: const Icon(Icons.password),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (passwordController.text.isEmpty) {
                NotesToast.error(context, message: 'Please enter a password');
                return;
              }
              if (passwordController.text != confirmController.text) {
                NotesToast.error(context, message: 'Passwords do not match');
                return;
              }
              if (passwordController.text.length < 4) {
                NotesToast.error(context, message: 'Password must be at least 4 characters');
                return;
              }

              // Save note first if new
              if (_isNewNote) {
                await _saveNote();
              }

              if (_noteId != null) {
                await _notesService.lockNote(_noteId!, passwordController.text);
                setState(() {
                  _isLocked = true;
                  _noteUnlocked = true;
                  _hasChanges = true;
                });
                Navigator.pop(context);
                NotesToast.noteLocked(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Lock'),
          ),
        ],
      ),
    );
  }

  void _showRemoveLockDialog() {
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.lock_open, color: Colors.green, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Remove Lock'),
          ],
        ),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter current password',
            prefixIcon: const Icon(Icons.password),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_noteId != null) {
                final verified = await _notesService.verifyNotePassword(_noteId!, controller.text);
                if (verified) {
                  await _notesService.unlockNote(_noteId!);
                  setState(() {
                    _isLocked = false;
                    _noteUnlocked = true;
                    _hasChanges = true;
                  });
                  Navigator.pop(context);
                  NotesToast.noteUnlocked(context);
                } else {
                  NotesToast.error(context, message: 'Incorrect password');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove Lock'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateSummary() async {
    if (_isNewNote) {
      await _saveNote();
    }
    
    if (_noteId == null) return;

    setState(() => _isGeneratingSummary = true);
    
    try {
      final summary = await _notesService.generateAiSummary(_noteId!);
      if (mounted) {
        setState(() {
          _aiSummary = summary;
          _isGeneratingSummary = false;
        });
        NotesToast.success(context, message: 'Summary generated successfully');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingSummary = false);
        NotesToast.error(context, message: 'Error: $e');
      }
    }
  }

  Future<void> _transcribeVoice() async {
    if (_voiceRecordingPath == null) return;

    setState(() => _isTranscribing = true);

    try {
      final transcript = await _notesService.transcribeVoiceNote(_voiceRecordingPath!);
      if (mounted && transcript != null) {
        setState(() {
          _voiceTranscript = transcript;
          _isTranscribing = false;
          _hasChanges = true;
        });
        
        if (_noteId != null) {
          await _notesService.setVoiceTranscript(_noteId!, transcript);
        }
        
        NotesToast.success(context, message: 'Voice transcribed successfully');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTranscribing = false);
        NotesToast.error(context, message: 'Error: $e');
      }
    }
  }

  void _showFolderPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final folders = _notesService.getAllFolders();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Move to Folder',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _createFolder(setS),
                    icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                    label: const Text('New'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (folders.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'No folders yet',
                      style: TextStyle(color: isDark ? Colors.white54 : Colors.black38),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: folders.length + 1, // +1 for "None" option
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        final isSelected = _folderId == null;
                        return ListTile(
                          leading: Icon(Icons.folder_off_outlined, color: isDark ? Colors.white54 : Colors.black54),
                          title: Text('No Folder', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                          trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
                          onTap: () {
                            setState(() {
                              _folderId = null;
                              _hasChanges = true;
                            });
                            Navigator.pop(context);
                          },
                        );
                      }
                      
                      final folder = folders[i - 1];
                      final isSelected = _folderId == folder.id;
                      final folderColor = _parseColor(folder.color) ?? Colors.amber;
                      
                      return ListTile(
                        leading: Icon(Icons.folder_rounded, color: folderColor),
                        title: Text(folder.name, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                        trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
                        onTap: () {
                          setState(() {
                            _folderId = folder.id;
                            _hasChanges = true;
                          });
                          Navigator.pop(context);
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

  void _createFolder(StateSetter setS) {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Folder name'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (c.text.trim().isNotEmpty) {
                await _notesService.createFolder(c.text.trim());
                Navigator.pop(context);
                setS(() {}); // Refresh the sheet
                setState(() {}); // Refresh the parent
              }
            },
            child: const Text('Create'),
          )
        ],
      ),
    );
  }

  Widget _buildFolderChip(bool isDark) {
    if (_folderId == null) return const SizedBox.shrink();
    
    try {
      final folders = _notesService.getAllFolders();
      final folderIndex = folders.indexWhere((f) => f.id == _folderId);
      if (folderIndex == -1) return const SizedBox.shrink();
      final folder = folders[folderIndex];
      
      return Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: GestureDetector(
          onTap: _showFolderPicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (_parseColor(folder.color) ?? Colors.amber).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.folder_open_rounded, size: 16, color: _parseColor(folder.color) ?? Colors.amber),
                const SizedBox(width: 8),
                Text(
                  folder.name,
                  style: TextStyle(
                    fontSize: 12, 
                    fontWeight: FontWeight.w600,
                    color: (_parseColor(folder.color) ?? Colors.amber).withOpacity(isDark ? 1.0 : 0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
}

class _VoiceRecordingSheet extends StatefulWidget {
  final VoiceRecordingService voiceService;
  final bool isDark;
  final void Function(String path, int duration) onComplete;

  const _VoiceRecordingSheet({required this.voiceService, required this.isDark, required this.onComplete});

  @override
  State<_VoiceRecordingSheet> createState() => _VoiceRecordingSheetState();
}

class _VoiceRecordingSheetState extends State<_VoiceRecordingSheet> {
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  void _startRecording() async {
    final ok = await widget.voiceService.startRecording();
    if (ok) setState(() => _isRecording = true);
  }

  void _stopRecording() async {
    final path = await widget.voiceService.stopRecording();
    final dur = widget.voiceService.durationNotifier.value.inSeconds;
    if (path != null && mounted) {
      Navigator.pop(context);
      widget.onComplete(path, dur);
    }
  }

  void _cancelRecording() async {
    await widget.voiceService.cancelRecording();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('Recording...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black87)),
      const SizedBox(height: 24),
      ValueListenableBuilder<Duration>(valueListenable: widget.voiceService.durationNotifier, builder: (_, d, __) =>
        Text('${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.red.shade400))),
      const SizedBox(height: 32),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        TextButton(onPressed: _cancelRecording, child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
        GestureDetector(onTap: _stopRecording, child: Container(width: 72, height: 72, decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
          child: const Icon(Icons.stop, color: Colors.white, size: 36))),
        const SizedBox(width: 60),
      ]),
      const SizedBox(height: 16),
    ]));
  }
}
