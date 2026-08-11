import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:intl/intl.dart';
import '../../../core/design/app_design.dart';
import '../../../core/design/app_colors_ext.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../models/diary_entry.dart';
import '../services/diary_storage_service.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await DiaryStorageService.getAll();
    if (!mounted) return;
    setState(() {
      _entries = data; // newest first (DAO orders desc)
      _loading = false;
    });
  }

  Future<void> _openEntry({DiaryEntry? existing}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => DiaryEntryScreen(existing: existing)),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(DiaryEntry e) async {
    final messenger = ScaffoldMessenger.of(context);
    await DiaryStorageService.delete(e.id);
    _load();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Entry deleted'),
        persist: false,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await DiaryStorageService.save(e);
            _load();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final accent = ext.brand;

    return AppScaffold(
      safeTop: true,
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
            icon: Symbols.auto_stories_rounded,
            accent: accent,
            leading: AppIconButton(
              icon: Symbols.arrow_back_rounded,
              filled: false,
              accent: accent,
              onPressed: () => Navigator.pop(context),
            ),
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
                          children: _entries.map((e) => _entryRow(ext, e)).toList(),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _entryRow(AppColorsExt ext, DiaryEntry e) {
    final tt = Theme.of(context).textTheme;
    final preview = e.body.trim();
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
              Text(e.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleMedium
                      ?.copyWith(color: ext.textPrimary, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
              const SizedBox(height: 6),
              Text(DateFormat('MMM d, y · h:mm a').format(e.entryAt),
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
