import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/design/app_design.dart';
import '../../../core/design/app_colors_ext.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/widgets/confirmation_bottom_sheet.dart';
import '../models/diary_entry.dart';
import '../services/diary_storage_service.dart';

/// Full-screen create/edit editor — pushed, not a bottom sheet, since the
/// body is open-ended multi-line text (the primary input, not an optional
/// one-liner), which is cramped inside a sheet with the keyboard up.
class DiaryEntryScreen extends StatefulWidget {
  final DiaryEntry? existing;
  const DiaryEntryScreen({super.key, this.existing});

  @override
  State<DiaryEntryScreen> createState() => _DiaryEntryScreenState();
}

class _DiaryEntryScreenState extends State<DiaryEntryScreen> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  String? _error;
  bool _saving = false;

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
    _title = TextEditingController(text: e?.title ?? '');
    _body = TextEditingController(text: e?.body ?? '');
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
    final dirty = _title.text.trim() != (e?.title?.trim() ?? '') ||
        _body.text.trim() != (e?.body.trim() ?? '');
    if (dirty != _dirty) setState(() => _dirty = dirty);
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
      entryAt: e?.entryAt ?? DateTime.now(),
      createdAt: e?.createdAt ?? DateTime.now(),
    );
    await DiaryStorageService.save(entry);
    if (mounted) Navigator.pop(context, true);
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
                    const SizedBox(height: AppSpacing.md),
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
