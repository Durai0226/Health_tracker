import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';

import '../../../core/ai/memory_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/widgets/app/app_widgets.dart';
import 'ai_privacy_screen.dart';

/// Manage what the assistant remembers about you — the ChatGPT/Oura "Memories"
/// pattern. Everything here is user-curated and stays on this device: a master
/// "Use memory" switch (consent), a tone preference, and an inspectable list of
/// saved notes each with a delete control. Nothing is auto-written from health
/// data — memories are created only when you explicitly tell the assistant.
class MemoriesScreen extends StatefulWidget {
  const MemoriesScreen({super.key});

  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen> {
  static const _service = MemoryService();

  bool _enabled = true;
  AssistantTone _tone = AssistantTone.conversational;
  List<AssistantMemoryRow> _memories = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await _service.active();
    if (!mounted) return;
    setState(() {
      _enabled = _service.enabled;
      _tone = _service.tone;
      _memories = rows;
      _loading = false;
    });
  }

  Future<void> _setEnabled(bool v) async {
    await _service.setEnabled(v);
    HapticFeedback.selectionClick();
    await _load();
  }

  Future<void> _setTone(AssistantTone t) async {
    await _service.setTone(t);
    setState(() => _tone = t);
  }

  Future<void> _delete(AssistantMemoryRow m) async {
    await _service.forget(m.id);
    HapticFeedback.selectionClick();
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed'), duration: Duration(seconds: 2)));
    }
  }

  Future<void> _clearAll() async {
    final ext = AppColorsExt.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColorsExt.of(ctx).surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brLg),
        title: const Text('Clear all memories?'),
        content: const Text(
            'This permanently deletes everything the assistant has saved about you. It can\'t be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Clear all',
                style: TextStyle(color: ext.mark(ext.error))),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _service.clear();
      await _load();
    }
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
            title: 'Memory',
            accent: accent,
            leading: AppIconButton(
              icon: Symbols.arrow_back_rounded,
              filled: false,
              accent: accent,
              onPressed: () {
                if (Navigator.canPop(context)) Navigator.pop(context);
              },
            ),
            bottom: Container(height: 1, color: ext.outline),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                        AppSpacing.lg, AppSpacing.gutter, AppSpacing.huge),
                    children: [
                      _intro(ext, tt),
                      const SizedBox(height: AppSpacing.lg),
                      _masterToggle(ext, tt),
                      const SizedBox(height: AppSpacing.md),
                      _toneCard(ext, tt, accent),
                      const SizedBox(height: AppSpacing.xl),
                      SectionHeader(
                          title: 'Saved memories',
                          icon: Symbols.bookmark_rounded,
                          accent: accent),
                      const SizedBox(height: AppSpacing.sm),
                      if (!_enabled)
                        _note(ext, tt,
                            'Memory is off. Turn it on above to let the assistant remember things you tell it.')
                      else if (_memories.isEmpty)
                        _note(ext, tt,
                            'Nothing saved yet. In Ask AI, say something like “remember I prefer evening reminders” or “my goal is 8000 steps”.')
                      else ...[
                        for (final m in _memories)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: _memoryTile(ext, tt, m),
                          ),
                        const SizedBox(height: AppSpacing.sm),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: AppButton(
                            label: 'Clear all',
                            variant: AppButtonVariant.ghost,
                            size: AppButtonSize.sm,
                            leadingIcon: Symbols.delete_sweep_rounded,
                            accent: ext.error,
                            onPressed: _clearAll,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _intro(AppColorsExt ext, TextTheme tt) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Symbols.psychology_rounded, size: 20, color: ext.mark(ext.brand)),
            const SizedBox(width: AppSpacing.sm),
            Text('What I remember',
                style: tt.titleMedium
                    ?.copyWith(color: ext.textPrimary, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: AppSpacing.sm),
          Text(
              'I only remember what you explicitly ask me to — never anything pulled silently from your health data. It stays on this device and is left out of cloud sync and backups.',
              style: tt.bodyMedium?.copyWith(color: ext.textSecondary, height: 1.4)),
          const SizedBox(height: AppSpacing.md),
          InkWell(
            borderRadius: AppRadius.brFull,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AiPrivacyScreen())),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Symbols.shield_rounded,
                    size: 15, color: ext.mark(ext.brand)),
                const SizedBox(width: 6),
                Text('AI & your data',
                    style: tt.labelLarge?.copyWith(
                        color: ext.mark(ext.brand),
                        fontWeight: FontWeight.w600)),
                Icon(Symbols.chevron_right_rounded,
                    size: 18, color: ext.mark(ext.brand)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _masterToggle(AppColorsExt ext, TextTheme tt) {
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Use memory',
                    style: tt.titleSmall?.copyWith(
                        color: ext.textPrimary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('Let the assistant save and use what you tell it',
                    style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
              ],
            ),
          ),
          AppSwitch(value: _enabled, onChanged: _setEnabled),
        ],
      ),
    );
  }

  Widget _toneCard(AppColorsExt ext, TextTheme tt, AccentSwatch accent) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reply tone',
              style: tt.titleSmall?.copyWith(
                  color: ext.textPrimary, fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          SegmentedToggle(
            accent: accent,
            index: _tone == AssistantTone.direct ? 1 : 0,
            onChanged: (i) =>
                _setTone(i == 1 ? AssistantTone.direct : AssistantTone.conversational),
            items: const [
              SegmentItem(icon: Symbols.chat_bubble_rounded, label: 'Conversational'),
              SegmentItem(icon: Symbols.bolt_rounded, label: 'Direct'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _memoryTile(AppColorsExt ext, TextTheme tt, AssistantMemoryRow m) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.sm, AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(_kindIcon(m.kind), size: 16, color: ext.textTertiary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(m.content,
                style: tt.bodyMedium?.copyWith(color: ext.textPrimary, height: 1.35)),
          ),
          const SizedBox(width: AppSpacing.xs),
          InkWell(
            borderRadius: AppRadius.brFull,
            onTap: () => _delete(m),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Symbols.close_rounded, size: 18, color: ext.textTertiary),
            ),
          ),
        ],
      ),
    );
  }

  IconData _kindIcon(String kind) {
    switch (kind) {
      case MemoryService.kKindGoal:
        return Symbols.flag_rounded;
      case MemoryService.kKindPreference:
        return Symbols.favorite_rounded;
      default:
        return Symbols.sticky_note_2_rounded;
    }
  }

  Widget _note(AppColorsExt ext, TextTheme tt, String text) {
    return AppCard(
      child: Text(text,
          style: tt.bodyMedium?.copyWith(color: ext.textSecondary, height: 1.4)),
    );
  }
}
