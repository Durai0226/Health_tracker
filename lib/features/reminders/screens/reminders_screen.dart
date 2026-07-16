import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/services/clean_storage_service.dart';
import '../../../core/services/notification_service.dart';
import '../models/reminder_model.dart';
import '../models/reminder_category_model.dart';
import '../utils/reminder_helper.dart';
import 'add_reminder_screen.dart';

/// The Reminders destination — Calm Clarity, dark-aware, lists real reminders.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  List<Reminder> _reminders = [];
  List<ReminderCategory> _categories = [];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  /// One unified filter selection. Keys: 'all', 'active', 'today',
  /// 'prio:<name>', 'cat:<id>'.
  String _filterKey = 'all';

  /// false = sort by time (default), true = sort by priority (high → low).
  bool _sortByPriority = false;

  @override
  void initState() {
    super.initState();
    _categories = CleanStorageService.getAllCategories();
    _load();
    _loadCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _load() {
    final all = CleanStorageService.getReminders().toList()
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    setState(() => _reminders = all);
  }

  Future<void> _loadCategories() async {
    final categories = await CleanStorageService.getAllCategoriesAsync();
    if (mounted) {
      setState(() {
        _categories = categories;
        // Clear a filter that points at a now-deleted category.
        if (_filterKey.startsWith('cat:') &&
            !categories.any((c) => 'cat:${c.id}' == _filterKey)) {
          _filterKey = 'all';
        }
      });
    }
  }

  bool get _hasActiveFilter =>
      _filterKey != 'all' || _searchQuery.trim().isNotEmpty;

  bool _matchesSearch(Reminder r) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return true;
    return r.title.toLowerCase().contains(q) ||
        r.body.toLowerCase().contains(q) ||
        (r.note?.toLowerCase().contains(q) ?? false);
  }

  bool _matchesFilter(Reminder r) {
    if (_filterKey == 'all') return true;
    if (_filterKey == 'active') return !r.isCompleted;
    if (_filterKey == 'today') {
      return DateUtils.isSameDay(r.scheduledTime, DateTime.now());
    }
    if (_filterKey.startsWith('prio:')) {
      return r.priority.name == _filterKey.substring(5);
    }
    if (_filterKey.startsWith('cat:')) {
      return r.categoryId == _filterKey.substring(4);
    }
    return true;
  }

  int _priorityRank(ReminderPriority p) {
    switch (p) {
      case ReminderPriority.high:
        return 2;
      case ReminderPriority.medium:
        return 1;
      case ReminderPriority.low:
        return 0;
    }
  }

  List<Reminder> get _visibleReminders {
    // _reminders is already time-sorted (see _load).
    final list =
        _reminders.where(_matchesSearch).where(_matchesFilter).toList();
    if (_sortByPriority) {
      list.sort((a, b) {
        final byPriority =
            _priorityRank(b.priority).compareTo(_priorityRank(a.priority));
        if (byPriority != 0) return byPriority;
        return a.scheduledTime.compareTo(b.scheduledTime);
      });
    }
    return list;
  }

  Future<void> _addReminder() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const AddReminderScreen()));
    _load();
    _loadCategories();
  }

  Future<void> _edit(Reminder r) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => AddReminderScreen(reminder: r)));
    _load();
    _loadCategories();
  }

  Future<void> _toggle(Reminder r) async {
    final markingComplete = !r.isCompleted;

    // Roll a repeating reminder forward to its next occurrence instead of
    // letting it die in the Completed section. Same row (same id) is reused via
    // copyWith + saveReminder upsert, so no duplicates are created.
    if (markingComplete && r.repeatType != RepeatType.none) {
      final next = ReminderHelper.getNextOccurrence(r);
      final rolled = r.copyWith(
        scheduledTime: next,
        isCompleted: false,
      );
      await CleanStorageService.saveReminder(rolled);

      // Reschedule the notification for the new time (consistent with the
      // add/edit path which keys notifications off id.hashCode).
      await NotificationService().scheduleGenericReminder(
        id: rolled.id.hashCode,
        title: rolled.title,
        body: rolled.body,
        scheduledTime: next,
        repeatType: rolled.repeatType,
        customDays: rolled.customDays,
        snoozeDuration: rolled.snoozeDuration,
        sound: rolled.sound,
        priority: rolled.priority,
        payload: rolled.noteId != null ? 'note:${rolled.noteId}' : null,
      );
    } else {
      // Non-repeating reminders keep the simple toggle behavior.
      await CleanStorageService.toggleReminderCompletion(r);

      // A completed one-off shouldn't keep a pending notification firing.
      // (Repeating reminders are handled above via roll-forward reschedule.)
      if (markingComplete) {
        await NotificationService()
            .cancelGenericReminder(r.id.hashCode, r.repeatType, r.customDays);
      }
    }
    _load();
  }

  Future<void> _delete(Reminder r) async {
    await CleanStorageService.deleteReminder(r.id);
    // Recurring weekday/weekends/custom reminders schedule one notification per
    // day, so cancel ALL sub-notifications — not just the base id — otherwise
    // 2–5 alerts keep firing forever after delete.
    await NotificationService()
        .cancelGenericReminder(r.id.hashCode, r.repeatType, r.customDays);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    return AccentScope(
      feature: FeatureAccent.reminders,
      child: AppScaffold(
        floatingActionButton: AppFab(
          icon: Icons.add_rounded,
          accent: ext.reminders,
          onPressed: _addReminder,
        ),
        body: Column(
          children: [
            AppHeader(title: 'Reminders', accent: ext.reminders),
            if (_reminders.isNotEmpty) _searchRow(ext),
            if (_reminders.isNotEmpty) _filterBar(ext),
            Expanded(
              child: _visibleReminders.isEmpty
                  ? EmptyState(
                      icon: Icons.notifications_none_rounded,
                      title: _hasActiveFilter
                          ? 'No matching reminders'
                          : 'No reminders yet',
                      message: _hasActiveFilter
                          ? 'Try a different search or filter.'
                          : 'Tap + to create your first reminder.',
                      accent: ext.reminders,
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.gutter, AppSpacing.xs, AppSpacing.gutter, 120),
                      children: _buildGroups(ext),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Search field + sort toggle on one line.
  Widget _searchRow(AppColorsExt ext) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter, AppSpacing.xs, AppSpacing.gutter, AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: AppTextField(
              controller: _searchController,
              hint: 'Search reminders',
              prefixIcon: Icons.search_rounded,
              accent: ext.reminders,
              textInputAction: TextInputAction.search,
              onChanged: (v) => setState(() => _searchQuery = v),
              suffix: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(Icons.close_rounded,
                          size: 18, color: ext.textTertiary),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _sortButton(ext),
        ],
      ),
    );
  }

  /// Compact sort toggle: time (default) ↔ priority.
  Widget _sortButton(AppColorsExt ext) {
    final active = _sortByPriority;
    return Tooltip(
      message: active ? 'Sorted by priority' : 'Sorted by time',
      child: Material(
        color: active ? ext.reminders.container : ext.surfaceVariant,
        borderRadius: AppRadius.brMd,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() => _sortByPriority = !_sortByPriority),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md + 2),
            child: Icon(
              active ? Icons.flag_rounded : Icons.sort_rounded,
              size: 22,
              color: active ? ext.reminders.onContainer : ext.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  /// Unified horizontal filter row: status + priority + one chip per category.
  Widget _filterBar(AppColorsExt ext) {
    Widget chip(String key, String label,
        {IconData? icon, AccentSwatch? accent}) {
      return Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: AppChip(
          label: label,
          icon: icon,
          selected: _filterKey == key,
          accent: accent ?? ext.reminders,
          onTap: () => setState(() => _filterKey = key),
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        children: [
          chip('all', 'All'),
          chip('active', 'Active', icon: Icons.radio_button_unchecked_rounded),
          chip('today', 'Today', icon: Icons.today_rounded),
          chip('prio:high', 'High',
              icon: Icons.flag_rounded, accent: ext.error),
          chip('prio:medium', 'Medium',
              icon: Icons.flag_rounded, accent: ext.warning),
          chip('prio:low', 'Low', icon: Icons.flag_rounded, accent: ext.success),
          ..._categories.map(
            (c) => chip('cat:${c.id}', c.name, icon: c.iconObj),
          ),
        ],
      ),
    );
  }

  /// Groups reminders into an agenda: Overdue · Today · Tomorrow · Upcoming ·
  /// Completed — each section shown only when it has items.
  List<Widget> _buildGroups(AppColorsExt ext) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final overdue = <Reminder>[];
    final dueToday = <Reminder>[];
    final dueTomorrow = <Reminder>[];
    final upcoming = <Reminder>[];
    final completed = <Reminder>[];

    for (final r in _visibleReminders) {
      if (r.isCompleted) {
        completed.add(r);
      } else if (r.scheduledTime.isBefore(now)) {
        overdue.add(r);
      } else if (DateUtils.isSameDay(r.scheduledTime, today)) {
        dueToday.add(r);
      } else if (DateUtils.isSameDay(r.scheduledTime, tomorrow)) {
        dueTomorrow.add(r);
      } else {
        upcoming.add(r);
      }
    }

    final widgets = <Widget>[];
    void section(String title, IconData icon, List<Reminder> items,
        AccentSwatch accent) {
      if (items.isEmpty) return;
      widgets.add(Padding(
        padding: const EdgeInsets.only(
            top: AppSpacing.lg, bottom: AppSpacing.sm),
        child: SectionHeader(
          title: '$title (${items.length})',
          icon: icon,
          accent: accent,
        ),
      ));
      for (final r in items) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _reminderCard(ext, r),
        ));
      }
    }

    section('Overdue', Icons.error_outline_rounded, overdue, ext.error);
    section('Today', Icons.today_rounded, dueToday, ext.reminders);
    section('Tomorrow', Icons.wb_sunny_rounded, dueTomorrow, ext.reminders);
    section('Upcoming', Icons.event_rounded, upcoming, ext.reminders);
    section('Completed', Icons.check_circle_outline_rounded, completed,
        ext.success);
    return widgets;
  }

  AccentSwatch _prioritySwatch(AppColorsExt ext, ReminderPriority p) {
    switch (p) {
      case ReminderPriority.high:
        return ext.error;
      case ReminderPriority.medium:
        return ext.warning;
      case ReminderPriority.low:
        return ext.success;
    }
  }

  ReminderCategory? _categoryFor(String? id) {
    if (id == null) return null;
    for (final c in _categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  String _repeatLabel(RepeatType t) {
    switch (t) {
      case RepeatType.none:
        return '';
      case RepeatType.daily:
        return 'Daily';
      case RepeatType.weekly:
        return 'Weekly';
      case RepeatType.weekdays:
        return 'Weekdays';
      case RepeatType.weekends:
        return 'Weekends';
      case RepeatType.custom:
        return 'Custom';
    }
  }

  /// Category color pill (color + icon + name) built from stored category data.
  Widget _categoryChip(ReminderCategory c, TextTheme tt) {
    final col = c.colorObj;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: col.withOpacity(0.16),
        borderRadius: AppRadius.brFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(c.iconObj, size: 12, color: col),
          const SizedBox(width: 4),
          Text(
            c.name,
            style: tt.labelSmall?.copyWith(
              color: col,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Small icon + label meta pill (repeat / note / photo).
  Widget _metaItem(IconData icon, String? label, AppColorsExt ext, TextTheme tt) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: ext.textTertiary),
        if (label != null && label.isNotEmpty) ...[
          const SizedBox(width: 4),
          Text(label, style: tt.labelSmall?.copyWith(color: ext.textSecondary)),
        ],
      ],
    );
  }

  /// Second metadata line: category chip, repeat, note/photo glyphs.
  /// Returns an empty list (no spacing added) when the reminder has none.
  List<Widget> _cardMeta(AppColorsExt ext, Reminder r, TextTheme tt) {
    final items = <Widget>[];
    final cat = _categoryFor(r.categoryId);
    if (cat != null) items.add(_categoryChip(cat, tt));
    if (r.repeatType != RepeatType.none) {
      items.add(_metaItem(
          Icons.repeat_rounded, _repeatLabel(r.repeatType), ext, tt));
    }
    if (r.note != null && r.note!.trim().isNotEmpty) {
      items.add(_metaItem(Icons.sticky_note_2_outlined, null, ext, tt));
    }
    if (r.imagePath != null && r.imagePath!.trim().isNotEmpty) {
      items.add(_metaItem(Icons.image_outlined, null, ext, tt));
    }
    if (items.isEmpty) return const [];
    return [
      const SizedBox(height: AppSpacing.sm),
      Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: items,
      ),
    ];
  }

  Widget _reminderCard(AppColorsExt ext, Reminder r) {
    final tt = Theme.of(context).textTheme;
    final overdue = r.scheduledTime.isBefore(DateTime.now()) && !r.isCompleted;
    final isToday = DateUtils.isSameDay(r.scheduledTime, DateTime.now());
    final when = isToday
        ? DateFormat('h:mm a').format(r.scheduledTime)
        : DateFormat('MMM d · h:mm a').format(r.scheduledTime);

    return Dismissible(
      key: Key(r.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: ext.error.container,
          borderRadius: AppRadius.brCard,
        ),
        child: Icon(Icons.delete_outline_rounded, color: ext.error.onContainer),
      ),
      onDismissed: (_) => _delete(r),
      child: AppCard(
        onTap: () => _edit(r),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Priority accent stripe: low=success · medium=warning · high=error.
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: r.isCompleted
                      ? ext.outline
                      : _prioritySwatch(ext, r.priority).base,
                  borderRadius: AppRadius.brFull,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Center(
                child: GestureDetector(
                  onTap: () => _toggle(r),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          r.isCompleted ? ext.reminders.base : Colors.transparent,
                      border: Border.all(
                        color: r.isCompleted
                            ? ext.reminders.base
                            : ext.outlineStrong,
                        width: 2,
                      ),
                    ),
                    child: r.isCompleted
                        ? Icon(Icons.check_rounded,
                            size: 16, color: ext.reminders.on)
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      r.title,
                      style: tt.titleLarge?.copyWith(
                        decoration:
                            r.isCompleted ? TextDecoration.lineThrough : null,
                        color: r.isCompleted ? ext.textTertiary : ext.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          overdue
                              ? Icons.error_outline_rounded
                              : Icons.schedule_rounded,
                          size: 14,
                          color: overdue ? ext.error.strong : ext.textSecondary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          overdue ? '$when · overdue' : when,
                          style: tt.bodySmall?.copyWith(
                            color: overdue ? ext.error.strong : ext.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    ..._cardMeta(ext, r, tt),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
