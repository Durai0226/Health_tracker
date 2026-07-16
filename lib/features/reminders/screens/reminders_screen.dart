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
  String? _filterCategoryId; // null = All

  @override
  void initState() {
    super.initState();
    _categories = CleanStorageService.getAllCategories();
    _load();
    _loadCategories();
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
        if (_filterCategoryId != null &&
            !categories.any((c) => c.id == _filterCategoryId)) {
          _filterCategoryId = null;
        }
      });
    }
  }

  List<Reminder> get _visibleReminders => _filterCategoryId == null
      ? _reminders
      : _reminders.where((r) => r.categoryId == _filterCategoryId).toList();

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
    }
    _load();
  }

  Future<void> _delete(Reminder r) async {
    await CleanStorageService.deleteReminder(r.id);
    await NotificationService().cancelNotification(r.id.hashCode);
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
            if (_categories.isNotEmpty) _categoryFilterBar(ext),
            Expanded(
              child: _visibleReminders.isEmpty
                  ? EmptyState(
                      icon: Icons.notifications_none_rounded,
                      title: _filterCategoryId == null
                          ? 'No reminders yet'
                          : 'Nothing in this category',
                      message: _filterCategoryId == null
                          ? 'Tap + to create your first reminder.'
                          : 'Try a different category or tap + to add one.',
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

  /// Horizontal filter row: All + one chip per category.
  Widget _categoryFilterBar(AppColorsExt ext) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: AppChip(
              label: 'All',
              selected: _filterCategoryId == null,
              accent: ext.reminders,
              onTap: () => setState(() => _filterCategoryId = null),
            ),
          ),
          ..._categories.map(
            (c) => Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: AppChip(
                label: c.name,
                icon: c.iconObj,
                selected: _filterCategoryId == c.id,
                accent: ext.reminders,
                onTap: () => setState(() => _filterCategoryId = c.id),
              ),
            ),
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
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _toggle(r),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: r.isCompleted ? ext.reminders.base : Colors.transparent,
                  border: Border.all(
                    color: r.isCompleted ? ext.reminders.base : ext.outlineStrong,
                    width: 2,
                  ),
                ),
                child: r.isCompleted
                    ? Icon(Icons.check_rounded, size: 16, color: ext.reminders.on)
                    : null,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.title,
                    style: tt.titleLarge?.copyWith(
                      decoration: r.isCompleted ? TextDecoration.lineThrough : null,
                      color: r.isCompleted ? ext.textTertiary : ext.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        overdue ? Icons.error_outline_rounded : Icons.schedule_rounded,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
