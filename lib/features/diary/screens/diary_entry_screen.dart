import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/design/app_design.dart';
import '../../../core/design/app_colors_ext.dart';
import '../../../core/widgets/app/app_widgets.dart';
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

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _body = TextEditingController(text: e?.body ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
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

    return AppScaffold(
      safeTop: true,
      body: Column(
        children: [
          AppHeader(
            title: widget.existing == null ? 'New entry' : 'Edit entry',
            icon: Symbols.auto_stories_rounded,
            accent: accent,
            leading: AppIconButton(
              icon: Symbols.arrow_back_rounded,
              filled: false,
              accent: accent,
              onPressed: () => Navigator.pop(context),
            ),
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
    );
  }
}
