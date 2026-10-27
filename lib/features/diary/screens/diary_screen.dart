import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:intl/intl.dart';
import '../../../core/design/app_design.dart';
import '../../../core/design/app_colors_ext.dart';
import '../../../core/health/mood_tags.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/widgets/app/vitals_theme.dart';
import '../models/diary_entry.dart';
import '../services/diary_prompt_signals.dart';
import '../services/diary_prompts.dart';
import '../services/diary_search.dart';
import '../services/diary_storage_service.dart';
import '../services/on_this_day.dart';
import '../widgets/diary_cards.dart';
import 'diary_entry_screen.dart';

/// Diary/journal — free-form, timestamped entries. No trend chart or stat
/// row here: unlike every other tracker in this app, there is nothing
/// numeric to chart about a free-text entry.
class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  List<DiaryEntry> _entries = [];
  bool _loading = true;

  bool _searching = false;
  final TextEditingController _query = TextEditingController();

  /// The question on offer today, if there is one (see [DiaryPromptSignals]).
  DiaryPrompt? _prompt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await DiaryStorageService.getAll();
    final prompt = await DiaryPromptSignals.forToday(data);
    if (!mounted) return;
    setState(() {
      _entries = data; // newest first (DAO orders desc)
      _prompt = prompt;
      _loading = false;
    });
  }

  Future<void> _openEntry({DiaryEntry? existing, String? title}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) =>
              DiaryEntryScreen(existing: existing, initialTitle: title)),
    );
    if (saved == true) _load();
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) _query.clear();
    });
  }

  Future<void> _dismissPrompt() async {
    await DiaryPromptSignals.dismissToday();
    if (mounted) setState(() => _prompt = null);
  }

  Future<void> _delete(DiaryEntry e) async {
    await DiaryStorageService.delete(e.id);
    _load();
    if (!mounted) return;
    context.toastSuccess(
      'Entry deleted',
      action: AppToastAction(
        label: 'Undo',
        onPressed: () async {
          await DiaryStorageService.save(e);
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final accent = ext.brand;

    return AppScaffold(
      floatingActionButton: AppFab(
        icon: Symbols.add_rounded,
        label: 'New entry',
        accent: accent,
        onPressed: () => _openEntry(),
      ),
      body: Column(
        children: [
          AppHeader(
            title: 'Diary',
            leading: AppHeader.backButton(context),
            actions: [
              if (_entries.isNotEmpty)
                AppIconButton(
                  icon: _searching ? Symbols.close_rounded : Symbols.search_rounded,
                  filled: false,
                  accent: accent,
                  tooltip: _searching ? 'Close search' : 'Search diary',
                  onPressed: _toggleSearch,
                ),
            ],
          ),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: ext.mark(accent)))
                : _entries.isEmpty
                    ? _EmptyState(accent: accent, onNew: () => _openEntry())
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: ext.mark(accent),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                              AppSpacing.sm, AppSpacing.gutter, 120),
                          children: _listChildren(ext, accent),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  List<Widget> _listChildren(AppColorsExt ext, AccentSwatch accent) {
    final tt = Theme.of(context).textTheme;
    if (_searching) {
      final found = DiarySearch.filter(_entries, _query.text);
      final typed = DiarySearch.words(_query.text).isNotEmpty;
      return [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: AppSearchField(
            controller: _query,
            hint: 'Search your diary',
            accent: accent,
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
        ),
        if (typed && found.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Text('Nothing in your diary matches \u201c${_query.text.trim()}\u201d.',
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
          )
        else
          ...found.map((e) => _entryRow(ext, e)),
      ];
    }

    final now = clock.now();
    final onThisDay = OnThisDay.forDay(_entries, DateTime(now.year, now.month, now.day));
    return [
      if (_prompt case final prompt?) ...[
        DiaryPromptCard(
          prompt: prompt,
          onWrite: () => _openEntry(title: prompt.text),
          onDismiss: _dismissPrompt,
        ),
        const SizedBox(height: AppSpacing.md),
      ],
      if (onThisDay.isNotEmpty) ...[
        OnThisDayCard(
            items: onThisDay, onOpen: (e) => _openEntry(existing: e)),
        const SizedBox(height: AppSpacing.md),
      ],
      ..._entries.map((e) => _entryRow(ext, e)),
    ];
  }

  Widget _entryRow(AppColorsExt ext, DiaryEntry e) {
    final tt = Theme.of(context).textTheme;
    final heading = e.displayTitle;
    // Only what the heading hasn't already said — see [DiaryEntry.previewBody].
    final preview = e.previewBody;
    return Dismissible(
      key: ValueKey(e.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
            color: ext.error.container, borderRadius: AppRadius.brMd),
        child: Icon(Symbols.delete_rounded, color: ext.mark(ext.error)),
      ),
      onDismissed: (_) => _delete(e),
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: AppCard(
          onTap: () => _openEntry(existing: e),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(heading,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleMedium?.copyWith(
                            color: ext.textPrimary, fontWeight: FontWeight.w700)),
                  ),
                  if (e.moodIndex != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Icon(VitalsColors.moodIcon(e.moodIndex!),
                        size: 20,
                        color: VitalsColors.moodBand(ext.isDark, e.moodIndex!)),
                  ],
                ],
              ),
              if (preview.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
              ],
              const SizedBox(height: 6),
              Text(
                  '${DateFormat('MMM d, y · h:mm a').format(e.entryAt)}'
                  '${e.tags.isEmpty ? '' : ' · ${e.tags.map(MoodTags.label).join(', ')}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodySmall?.copyWith(color: ext.textTertiary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AccentSwatch accent;
  final VoidCallback onNew;
  const _EmptyState({required this.accent, required this.onNew});

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      children: [
        const SizedBox(height: 24),
        Icon(Symbols.auto_stories_rounded, size: 56, color: ext.mark(accent)),
        const SizedBox(height: AppSpacing.md),
        Text('Your diary',
            textAlign: TextAlign.center,
            style: tt.headlineSmall?.copyWith(color: ext.textPrimary)),
        const SizedBox(height: AppSpacing.sm),
        Text('A private place for your notes and reflections.',
            textAlign: TextAlign.center,
            style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Write your first entry',
          leadingIcon: Symbols.add_rounded,
          accent: accent,
          fullWidth: true,
          size: AppButtonSize.lg,
          onPressed: onNew,
        ),
      ],
    );
  }
}
