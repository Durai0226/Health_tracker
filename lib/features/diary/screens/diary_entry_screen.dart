import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/design/app_design.dart';
import '../../../core/design/app_colors_ext.dart';
import '../../../core/health/mood_tags.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/widgets/app/vitals_theme.dart';
import '../../../core/widgets/confirmation_bottom_sheet.dart';
import '../../medication/models/medicine_log.dart' show moodRatingLabels;
import '../models/diary_entry.dart';
import '../services/diary_storage_service.dart';
import '../widgets/diary_details_sheet.dart';

/// Full-screen create/edit editor — pushed, not a bottom sheet, since the
/// body is open-ended multi-line text (the primary input, not an optional
/// one-liner), which is cramped inside a sheet with the keyboard up.
class DiaryEntryScreen extends StatefulWidget {
  final DiaryEntry? existing;

  /// A title to start a NEW entry with — the question of a prompt the person
  /// chose to write about. Ignored when editing.
  final String? initialTitle;

  const DiaryEntryScreen({super.key, this.existing, this.initialTitle});

  @override
  State<DiaryEntryScreen> createState() => _DiaryEntryScreenState();
}

class _DiaryEntryScreenState extends State<DiaryEntryScreen> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  String? _error;
  bool _saving = false;

  /// What the entry is dated, how the writer felt and what it was about. A new
  /// entry starts at now with neither; they change only through the details
  /// sheet, so none of them is ever a surprise.
  late DiaryDetails _details;

  /// How the editor opened, so a change is measured against it.
  late final DiaryDetails _openedWith;

  /// The title it opened with: the entry's own, or a prompt's question.
  late final String _openedTitle;

  /// Whether the editor holds text that differs from the entry it opened with.
  ///
  /// Measured against the ORIGINAL rather than against empty: reopening a
  /// saved entry and backing straight out is not a discard, and prompting
  /// there would train the user to dismiss the sheet without reading it.
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _openedTitle = e?.title ?? widget.initialTitle ?? '';
    _title = TextEditingController(text: _openedTitle);
    _body = TextEditingController(text: e?.body ?? '');
    _openedWith = DiaryDetails(
      at: e?.entryAt ?? clock.now(),
      mood: e?.moodIndex,
      tags: e?.tags ?? const [],
    );
    _details = _openedWith;
    // [PopScope] reads `canPop` at BUILD time, so dirtiness has to drive a
    // rebuild. Both controllers are listened to, not just the body: a
    // title-only edit is just as unsaved, and gating on the body alone would
    // have left the discard silent for it — the same bug, one field narrower.
    _title.addListener(_refreshDirty);
    _body.addListener(_refreshDirty);
  }

  @override
  void dispose() {
    _title.removeListener(_refreshDirty);
    _body.removeListener(_refreshDirty);
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _refreshDirty() {
    final e = widget.existing;
    final dirty = _title.text.trim() != _openedTitle.trim() ||
        _body.text.trim() != (e?.body.trim() ?? '') ||
        _details != _openedWith;
    if (dirty != _dirty) setState(() => _dirty = dirty);
  }

  Future<void> _editDetails() async {
    final picked = await DiaryDetailsSheet.show(
      context,
      initial: _details,
      accent: AppColorsExt.of(context).brand,
    );
    if (picked == null || !mounted) return;
    setState(() => _details = picked);
    _refreshDirty();
  }

  /// Back with unsaved text used to throw it away without a word. Clean, the
  /// screen pops straight through — `canPop` is already true and this never
  /// runs.
  Future<void> _confirmDiscard() async {
    final discard = await ConfirmationBottomSheet.show(
      context: context,
      title: 'Discard this entry?',
      message: 'You have unsaved text. Going back will lose it.',
      confirmText: 'Discard',
      cancelText: 'Keep editing',
      icon: Symbols.warning_rounded,
      isDangerous: true,
    );
    if (discard == true && mounted) Navigator.pop(context);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_body.text.trim().isEmpty) {
      setState(() => _error = 'Write something before saving.');
      return;
    }
    setState(() => _saving = true);
    final e = widget.existing;
    final entry = DiaryEntry(
      id: e?.id ?? 'diary_${DateTime.now().microsecondsSinceEpoch}',
      dependentId: e?.dependentId,
      title: _title.text.trim().isEmpty ? null : _title.text.trim(),
      body: _body.text.trim(),
      entryAt: _details.at,
      createdAt: e?.createdAt ?? DateTime.now(),
      moodIndex: _details.mood,
      tags: _details.tags,
    );
    await DiaryStorageService.save(entry);
    if (mounted) Navigator.pop(context, true);
  }

  /// One tappable line under the title: when it is dated, and — if given — the
  /// mood and tags. Opens the details sheet.
  Widget _detailsRow(AppColorsExt ext, TextTheme tt) {
    final mood = _details.mood;
    final tags = _details.tags;
    final said = [
      DiaryDetails.whenLabel(_details.at),
      if (mood != null) moodRatingLabels[mood.clamp(0, moodRatingLabels.length - 1)],
      if (tags.isNotEmpty) tags.map(MoodTags.label).join(', '),
    ].join(' · ');
    return Semantics(
      button: true,
      label: 'Entry details: $said',
      excludeSemantics: true,
      onTap: _editDetails,
      child: InkWell(
        onTap: _editDetails,
        borderRadius: AppRadius.brSm,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              Icon(Symbols.event_rounded, size: 18, color: ext.textTertiary),
              const SizedBox(width: AppSpacing.sm),
              if (mood != null) ...[
                Icon(VitalsColors.moodIcon(mood),
                    size: 18, color: VitalsColors.moodBand(ext.isDark, mood)),
                const SizedBox(width: AppSpacing.xs),
              ],
              Expanded(
                child: Text(said,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
              ),
              Icon(Symbols.chevron_right_rounded,
                  size: 20, color: ext.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final accent = ext.brand;
    final tt = Theme.of(context).textTheme;

    return PopScope(
      // The header arrow and the system back gesture both route through here,
      // so the confirm cannot be sidestepped by swiping instead of tapping.
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: AppScaffold(
        body: Column(
          children: [
            AppHeader(
              title: widget.existing == null ? 'New entry' : 'Edit entry',
              // NOT `AppHeader.backButton`, and this is the one screen where
              // that matters. The static pops IMPERATIVELY
              // (`Navigator.pop`), which bypasses [PopScope] entirely — the
              // discard guard would then cover the system back gesture and
              // not the arrow sitting next to the text it is about to throw
              // away. `maybePop` consults the route's pop disposition, so
              // both ways out reach [_confirmDiscard]. Everything else about
              // the button — flat, neutral `textPrimary`, tooltip "Back" — is
              // the static's own grammar, copied so the arrow still looks and
              // announces the same as every other screen's.
              leading: Navigator.of(context).canPop()
                  ? AppIconButton(
                      icon: Symbols.arrow_back_rounded,
                      filled: false,
                      color: ext.textPrimary,
                      tooltip: 'Back',
                      onPressed: () => Navigator.maybePop(context),
                    )
                  : null,
              actions: [
                AppIconButton(
                  icon: Symbols.check_rounded,
                  filled: true,
                  accent: accent,
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.gutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      controller: _title,
                      label: 'Title (optional)',
                      hint: 'A short title',
                      accent: accent,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _detailsRow(ext, tt),
                    const SizedBox(height: AppSpacing.sm),
                    Text('Entry',
                        style: tt.labelLarge?.copyWith(color: ext.textSecondary)),
                    const SizedBox(height: AppSpacing.sm),
                    // Not AppTextField here: its internal Column is sized to its
                    // own content (mainAxisSize.min), so wrapping IT in Expanded
                    // would just leave dead space below instead of growing the
                    // field. `expands: true` on a plain TextField is the
                    // correct way to fill the remaining screen height.
                    Expanded(
                      child: TextFormField(
                        controller: _body,
                        expands: true,
                        maxLines: null,
                        minLines: null,
                        textAlignVertical: TextAlignVertical.top,
                        textCapitalization: TextCapitalization.sentences,
                        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                        onChanged: (_) => setState(() => _error = null),
                        style: tt.bodyLarge?.copyWith(color: ext.textPrimary),
                        cursorColor: ext.mark(accent),
                        decoration: InputDecoration(
                          hintText: 'Write whatever\'s on your mind…',
                          hintStyle: tt.bodyLarge?.copyWith(color: ext.textTertiary),
                          filled: true,
                          fillColor: ext.surfaceVariant,
                          contentPadding: const EdgeInsets.all(AppSpacing.md),
                          border: OutlineInputBorder(
                            borderRadius: AppRadius.brMd,
                            borderSide: BorderSide(color: ext.outline),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: AppRadius.brMd,
                            borderSide: BorderSide(color: ext.mark(accent), width: 2),
                          ),
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(_error!,
                          style: tt.bodySmall?.copyWith(color: ext.mark(ext.error))),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
