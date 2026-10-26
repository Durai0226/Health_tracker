import 'package:clock/clock.dart';
import '../../../core/database/app_database.dart' show ReminderOccurrence;
import '../../../core/utils/calendar_day.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/utils/date_formats.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/services/clean_storage_service.dart';
import '../../../core/health/coach_text.dart';
import '../models/reminder_model.dart';
import '../models/reminder_category_model.dart';
import '../models/reminder_recurrence.dart';
import '../utils/reminder_helper.dart';
import 'add_reminder_screen.dart';
import '../services/reminder_adherence.dart';
import '../services/reminder_service.dart';
import '../services/reminder_alarm.dart';
import '../services/reminder_pause_until.dart';
import '../widgets/vacation_sheet.dart';
import '../utils/reminder_later.dart';
import '../services/reminder_tune_up.dart';
import '../services/reminder_tune_up_service.dart';

/// The occurrence a tick belongs to — the most recent one at or before [now].
///
/// `Reminder.scheduledTime` is an ANCHOR, not the instant that just came due:
/// for a repeating reminder it is where the last roll-forward left it (or the
/// creation time, for one that has never been ticked), which can be days behind
/// the occurrence the user is actually ticking off. Recording `done` against the
/// anchor wrote the outcome onto an occurrence that was already history and left
/// the one that was genuinely due sitting `pending` — until the reconcile sweep
/// wrote it off as MISSED. So a reminder answered every single day still
/// reported poor adherence, and the "still pending" follow-up (keyed by
/// occurrence instant) fired anyway for something already done.
///
/// The direct analogue of `resolveDoseInstant` on the medication side. Steps
/// through [ReminderRecurrence] — the same walk
/// `CleanStorageService.recordDueReminderOccurrences` uses — so the tick lands
/// on the very row that pass derived, and by CALENDAR day, so an 08:00 reminder
/// is still 08:00 across a DST transition.
DateTime resolveReminderOccurrence(Reminder reminder, {DateTime? now}) {
  final at = now ?? clock.now();
  // Nothing has come due yet (or it is paused): the anchor IS the occurrence.
  if (reminder.isPaused || !reminder.scheduledTime.isBefore(at)) {
    return reminder.scheduledTime;
  }
  final recurrence = ReminderRecurrence.parse(
    reminder.recurrenceRule,
    fallback: reminder.repeatType,
    fallbackDays: reminder.customDays,
  );
  if (!recurrence.repeats) return reminder.scheduledTime;

  var latest = reminder.scheduledTime;
  // Bounded exactly as the derive pass bounds its own walk: a malformed rule
  // must not spin on a tap.
  for (var i = 0; i < 400; i++) {
    final next =
        recurrence.nextAfter(start: reminder.scheduledTime, after: latest);
    if (next == null || next.isAfter(at)) break;
    if (reminder.endsAt != null && next.isAfter(reminder.endsAt!)) break;
    latest = next;
  }
  return latest;
}

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
    // Live: any write to the reminders table — here, from the reschedule pass,
    // from a cloud arrival, from an occurrence being recorded — refreshes this
    // screen. Before ReminderService there was no notifier at all, so every
    // surface re-read a static cache after each Navigator.push returned, and two
    // surfaces could disagree until one happened to be re-entered.
    ReminderService.instance.addListener(_onRemindersChanged);
    // Idempotent; covers a deep-link straight to this screen in a build where
    // the launch-time start has not run.
    ReminderService.instance.start();
  }

  @override
  void dispose() {
    ReminderService.instance.removeListener(_onRemindersChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onRemindersChanged() {
    if (mounted) _load();
  }

  void _load() {
    // Prefer the notifier's list once it has loaded; fall back to the
    // synchronous cache for the very first frame. Both are the same data —
    // ReminderService refreshes that cache on every emission — so this is a
    // freshness preference, not a second source of truth.
    final source = ReminderService.instance.isLoaded
        ? ReminderService.instance.reminders
        : CleanStorageService.getReminders();
    final all = source.toList()
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    setState(() => _reminders = all);
    _loadAdherence();
    _loadTuneUps(all);
  }

  /// One suggestion per repeating reminder at most, from its own history.
  Map<String, TuneUp> _tuneUps = const {};

  Future<void> _loadTuneUps(List<Reminder> all) async {
    final found = await ReminderTuneUpService.forAll(all);
    if (mounted) setState(() => _tuneUps = found);
  }

  /// Apply a suggestion the user accepted, and say exactly what changed, with a
  /// way back.
  Future<void> _applyTuneUp(Reminder r, TuneUp t) async {
    final changed = await ReminderTuneUpService.apply(r, t);
    _load();
    if (!mounted) return;
    final what = switch (t.kind) {
      TuneUpKind.move =>
        'Moved to ${TimeOfDay.fromDateTime(changed.scheduledTime).format(context)}',
      TuneUpKind.louder => 'Made louder',
      TuneUpKind.pause => 'Paused',
    };
    context.toastSuccess(
      what,
      action: AppToastAction(
        label: 'Undo',
        onPressed: () async {
          await ReminderTuneUpService.saveAndRearm(r);
          _load();
        },
      ),
    );
  }

  Future<void> _dismissTuneUp(Reminder r, TuneUp t) async {
    await ReminderTuneUpService.dismiss(r.id, t.kind);
    _load();
  }

  /// The suggestion strip under a card: what the history says, the one-tap fix,
  /// and "not now".
  Widget _tuneUpRow(AppColorsExt ext, Reminder r, TuneUp t, TextTheme tt) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.only(left: AppSpacing.md),
        decoration: BoxDecoration(
          color: ext.reminders.container,
          borderRadius: AppRadius.brSm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(t.message,
                  style: tt.bodySmall?.copyWith(color: ext.reminders.onContainer)),
            ),
            TextButton(
              onPressed: () => _applyTuneUp(r, t),
              child: Text(t.actionLabel),
            ),
            IconButton(
              tooltip: 'Not now',
              onPressed: () => _dismissTuneUp(r, t),
              icon: Icon(Symbols.close_rounded,
                  size: 18, color: ext.reminders.onContainer),
            ),
          ],
        ),
      ),
    );
  }

  ReminderAdherenceSummary? _adherence;

  Future<void> _loadAdherence() async {
    final a = await ReminderService.instance.adherence();
    if (mounted) setState(() => _adherence = a);
  }

  /// How the last 30 days actually went.
  ///
  /// The occurrence log was built to make this answerable and nothing had ever
  /// asked. `ReminderAdherence` was written to answer it and had no caller.
  ///
  /// Renders nothing at all when there is nothing to say — a day on which the
  /// user resolved nothing is excluded rather than scored zero, so somebody who
  /// has not opened the app in a week gets silence instead of a 0% that would
  /// be measuring app-opening rather than adherence.
  Widget _adherenceCard(AppColorsExt ext) {
    final a = _adherence;
    if (a == null) return const SizedBox.shrink();
    final tt = Theme.of(context).textTheme;
    final pct = (a.proportionOfDaysCovered * 100).round();
    final accent = a.isAdherent ? ext.success : ext.warning;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, 0),
      child: AppCard(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: accent.container,
                borderRadius: AppRadius.brMd,
              ),
              child: Icon(Symbols.event_available_rounded,
                  size: 20, color: accent.onContainer),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$pct% of days fully covered',
                      style: tt.titleMedium?.copyWith(color: ext.textPrimary)),
                  const SizedBox(height: 2),
                  // The denominator, stated. Days nobody resolved anything on
                  // are not in it, so "30 days" would be a lie.
                  Text(
                    'across ${a.daysCounted} '
                    '${a.daysCounted == 1 ? 'day' : 'days'} with something due'
                    '${a.streak.current > 0 ? ' · ${a.streak.current}-day streak' : ''}',
                    style: tt.bodySmall?.copyWith(color: ext.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Only when the two rates disagree, which is the case a
                  // single figure hides: three of four reminders every day is
                  // 75% of occurrences and 0% of days covered.
                  if (a.ratesDisagree) ...[
                    const SizedBox(height: 4),
                    Text(
                      'You did '
                      '${((a.proportionOfOccurrencesDone ?? 0) * 100).round()}% '
                      'of individual reminders — most of them, most days',
                      style: tt.bodySmall?.copyWith(color: ext.textTertiary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
      return DateUtils.isSameDay(r.scheduledTime, clock.now());
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

  /// "Smart Add": type a reminder in plain English and the on-device parser
  /// fills the form for review. Deterministic and offline — see
  /// [CoachText.parseReminder]. The manual + FAB flow stays intact as fallback.
  void _openSmartAdd() {
    final rem = AppColorsExt.of(context).reminders;
    AppBottomSheet.show<void>(
      context,
      title: 'Smart Add',
      icon: Symbols.auto_awesome_rounded,
      accent: rem,
      builder: (sheetCtx) => _SmartAddSheet(
        accent: rem,
        onSubmit: (text) => _handleSmartAdd(sheetCtx, text),
      ),
    );
  }

  /// Parses [text], closes the sheet, then opens the reminder form — prefilled
  /// when the parse succeeded, blank with an explanation when it did not.
  Future<void> _handleSmartAdd(BuildContext sheetCtx, String text) async {
    // Resolve the sheet's Navigator BEFORE the await. Afterwards `sheetCtx`
    // may already be deactivated, and looking up an ancestor through a
    // deactivated element is exactly the unsafe access this whole fix is
    // about — a `mounted` check on the State does not vouch for the sheet's
    // own context.
    final sheetNavigator = Navigator.of(sheetCtx);
    final result = await _parseSmartReminder(text);
    if (!mounted) return;
    sheetNavigator.pop(); // close the sheet

    if (result == null) {
      // Couldn't parse — open a blank form so the user can fill it.
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddReminderScreen()),
      );
      if (mounted) {
        context.toastInfo("Couldn't parse — fill it in manually");
      }
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddReminderScreen(
            initialTitle: result.title,
            initialTime: result.time,
            initialRepeat: result.repeat,
            initialCategoryId: result.categoryId,
            initialPriority: result.priority,
            initialCustomDays: result.customDays,
            initialRecurrenceRule: result.recurrenceRule,
            initialEndsAt: result.endsAt,
            initialOccurrenceLimit: result.occurrenceLimit,
          ),
        ),
      );
    }
    if (!mounted) return;
    _load();
    _loadCategories();
  }

  /// Extracts structured reminder fields from free text. Deterministic and
  /// offline — see [CoachText.parseReminder]. Returns null for blank input.
  Future<_SmartReminder?> _parseSmartReminder(String text) async {
    if (text.trim().isEmpty) return null;
    final parsed = const CoachText().parseReminder(text);

    final repeat = _repeatFromString(parsed.repeat);
    final priority = _priorityFromString(parsed.priority);
    final categoryId = await _categoryIdForName(parsed.categoryHint);

    return _SmartReminder(
      title: parsed.title,
      time: parsed.time,
      repeat: repeat,
      priority: priority,
      categoryId: categoryId,
      customDays: parsed.customDays,
      recurrenceRule: parsed.recurrenceRule,
      endsAt: parsed.endsAt,
      occurrenceLimit: parsed.occurrenceLimit,
    );
  }

  RepeatType? _repeatFromString(String? s) {
    switch (s?.trim().toLowerCase()) {
      case 'daily':
        return RepeatType.daily;
      case 'weekly':
        return RepeatType.weekly;
      case 'weekdays':
        return RepeatType.weekdays;
      case 'weekends':
        return RepeatType.weekends;
      case 'custom':
        return RepeatType.custom;
      case 'none':
        return RepeatType.none;
      default:
        return null;
    }
  }

  ReminderPriority? _priorityFromString(String? s) {
    switch (s?.trim().toLowerCase()) {
      case 'low':
        return ReminderPriority.low;
      case 'medium':
        return ReminderPriority.medium;
      case 'high':
        return ReminderPriority.high;
      default:
        return null;
    }
  }

  /// Match an AI-suggested category name (case-insensitive) to an existing
  /// category id, or null if there's no match / it's empty.
  Future<String?> _categoryIdForName(String? name) async {
    final n = name?.trim().toLowerCase();
    if (n == null || n.isEmpty) return null;
    final categories = await CleanStorageService.getAllCategoriesAsync();
    for (final c in categories) {
      if (c.name.trim().toLowerCase() == n) return c.id;
    }
    return null;
  }

  /// Start or end vacation mode. The list is reloaded afterwards: ending a
  /// vacation re-arms reminders and starting one disarms them, and the banner
  /// has to follow.
  Future<void> _openVacation() async {
    final changed = await VacationSheet.show(context);
    if (changed && mounted) {
      setState(() {});
      _load();
    }
  }

  Future<void> _edit(Reminder r) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => AddReminderScreen(reminder: r)));
    _load();
    _loadCategories();
  }

  Future<void> _toggle(Reminder r) async {
    final markingComplete = !r.isCompleted;

    // Whether the NEXT occurrence is actually armed by the end of this tick.
    //
    // `arm` already returns the OS's answer — `scheduleGenericReminder` reports
    // an AlarmManager refusal honestly, which is what happens on Android 14+
    // with SCHEDULE_EXACT_ALARM revoked — and that answer used to be thrown
    // away here. So a repeating reminder whose next occurrence was never
    // scheduled still vanished from Today under a plain "Marked done": the
    // confirmation said the one thing the user could not check.
    var armed = true;

    // Write the occurrence BEFORE anything mutates the reminder.
    //
    // The roll-forward below overwrites `scheduledTime`, and `isCompleted` is a
    // single boolean it also resets — so until this row existed, completing a
    // repeating reminder erased the only evidence it had ever been due. That is
    // why no adherence rate, streak or digest was possible for these.
    //
    // Un-completing is a correction, not an event: it reverts the occurrence to
    // pending rather than recording a second one.
    //
    // Against the occurrence the tick BELONGS to, never the stored anchor —
    // see [resolveReminderOccurrence].
    final occurrence = resolveReminderOccurrence(r);
    await CleanStorageService.recordReminderOutcome(
      reminderId: r.id,
      scheduledFor: occurrence,
      outcome: markingComplete
          ? ReminderOutcome.done
          : ReminderOutcome.pending,
      source: 'app',
    );

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
      // Through the seam, so the follow-up rolls forward with the reminder
      // instead of staying armed against the occurrence just ticked.
      final request = ReminderArmRequest.forNextOccurrence(rolled);
      if (request != null) {
        // Arming is best-effort and MUST NOT abort the tick.
        //
        // The tick is already persisted by this point (the occurrence outcome
        // and the rolled-forward row are both written above), so letting a
        // scheduling failure propagate skipped `_load()` and the confirmation
        // toast below: the card stayed on screen showing its old date, the
        // user saw no feedback at all, and the only clue that anything had
        // happened was that a second tap behaved differently. The re-arm pass
        // retries at the next launch, which is the right place to recover.
        try {
          armed = await const NotificationReminderAlarm().arm(request);
        } catch (e) {
          armed = false;
          debugPrint('⚠️ Re-arming "${rolled.title}" after a tick failed: $e');
        }
      }
    } else {
      // Non-repeating reminders keep the simple toggle behavior.
      await CleanStorageService.toggleReminderCompletion(r);

      // A completed one-off shouldn't keep a pending notification firing.
      // (Repeating reminders are handled above via roll-forward reschedule.)
      if (markingComplete) {
        // disarm(), not cancelGenericReminder(): the latter clears the base and
        // weekday sub-ids but leaves the +2000 follow-up armed, which then
        // fires "Still pending: …" for something already done.
        // Best-effort for the same reason as the arm above.
        try {
          await const NotificationReminderAlarm().disarm(
            id: r.notificationSlot,
            repeatType: r.repeatType,
            customDays: r.customDays,
          );
        } catch (e) {
          debugPrint('⚠️ Disarming "${r.title}" after a tick failed: $e');
        }
      }
    }
    _load();

    // A ticked card silently vanishes from Today — it either rolls forward to
    // its next occurrence or drops into Completed — with no confirmation and,
    // until now, no way back short of finding it again and un-ticking it. Say
    // what happened and offer one tap of regret.
    if (!mounted || !markingComplete) return;
    if (!armed) {
      // Say the part the user cannot see. The tick itself stuck — the row has
      // already rolled forward — so this is a warning about the schedule, not
      // an error about the tick, and it offers the one action that fixes it.
      context.toastWarning(
        "Marked done, but the next one couldn't be scheduled — check "
        'notification and alarm permissions.',
        action: AppToastAction(
          label: 'Open settings',
          onPressed: () => openAppSettings(),
        ),
      );
      return;
    }
    context.toastSuccess(
      'Marked done',
      action: AppToastAction(
        label: 'Undo',
        onPressed: () => _undoToggle(r, occurrence),
      ),
    );
  }

  /// Put back everything [_toggle] changed: the reminder row (a repeating tick
  /// has already rolled `scheduledTime` forward), the armed notification, and
  /// the occurrence.
  ///
  /// The occurrence goes back to `pending`, not deleted: the row is the evidence
  /// that the reminder came due, and the derive pass would recreate it anyway.
  Future<void> _undoToggle(Reminder original, DateTime occurrence) async {
    await CleanStorageService.recordReminderOutcome(
      reminderId: original.id,
      scheduledFor: occurrence,
      outcome: ReminderOutcome.pending,
      // Same shape the derive pass writes a pending row in, so an undone tick
      // is indistinguishable from one that was never made.
      firedAt: occurrence,
      source: 'app',
    );
    // The row as it was BEFORE the tick — same id, so this is an upsert back to
    // the old scheduledTime/isCompleted rather than a second reminder.
    await CleanStorageService.saveReminder(original);
    final request = ReminderArmRequest.forNextOccurrence(original);
    if (request != null) {
      // Guarded for the same reason [_toggle] guards its own arm, and more
      // urgently: this runs from a toast action callback, so an escaping throw
      // is an unhandled async error AND skips the `_load()` below — the row is
      // restored in the database while the list keeps showing the ticked state.
      try {
        await const NotificationReminderAlarm().arm(request);
      } catch (e) {
        debugPrint('⚠️ Re-arming "${original.title}" after an undo failed: $e');
      }
    }
    if (mounted) _load();
  }

  Future<void> _delete(Reminder r) async {
    // Keep the history so Undo can put it back: a delete that could not be
    // undone is the reason this used to be a swipe nobody could take back.
    final history = await CleanStorageService.getReminderOccurrences(r.id);
    await CleanStorageService.deleteReminder(r.id);
    // The occurrence rows go with it. They are history, so this is the ONLY
    // place that clears them — never as routine cleanup.
    await CleanStorageService.deleteReminderOccurrences(r.id);
    // Recurring weekday/weekends/custom reminders schedule one notification per
    // day, so cancel ALL sub-notifications — not just the base id — otherwise
    // 2–5 alerts keep firing forever after delete.
    // disarm(), not cancelGenericReminder(): the latter cancels the base id and
    // the weekday sub-ids but NOT the +2000 follow-up, so a deleted Insistent
    // reminder still popped "Still pending: Call Dr Rao" half an hour later —
    // and for the critical tier repeated it every 5 minutes to the snooze cap.
    await const NotificationReminderAlarm().disarm(
      id: r.notificationSlot,
      repeatType: r.repeatType,
      customDays: r.customDays,
    );
    _load();
    if (!mounted) return;
    context.toastSuccess(
      'Deleted "${r.title}"',
      action: AppToastAction(
        label: 'Undo',
        onPressed: () => _undoDelete(r, history),
      ),
    );
  }

  /// Bring back a deleted reminder: the row (same id, so it keeps the alarm slot
  /// it was armed under), its occurrence history, and its alarm.
  Future<void> _undoDelete(Reminder r, List<ReminderOccurrence> history) async {
    await CleanStorageService.saveReminder(r);
    await CleanStorageService.restoreReminderOccurrences(history);
    final request = ReminderArmRequest.forNextOccurrence(r);
    if (request != null) {
      try {
        await const NotificationReminderAlarm().arm(request);
      } catch (e) {
        debugPrint('⚠️ Re-arming "${r.title}" after Undo failed: $e');
      }
    }
    _load();
  }

  /// "Later": move a one-off to this evening, or tomorrow morning if the day is
  /// nearly over, with a way back.
  Future<void> _later(Reminder r) async {
    final now = clock.now();
    final target = ReminderLater.from(now);
    await _reschedule(r, to: target);
    if (!mounted) return;
    context.toastSuccess(
      'Moved to ${ReminderLater.label(now)}',
      action: AppToastAction(
        label: 'Undo',
        onPressed: () => _reschedule(r, to: r.scheduledTime),
      ),
    );
  }

  Future<void> _reschedule(Reminder r, {required DateTime to}) async {
    final moved = r.copyWith(scheduledTime: to, isCompleted: false);
    await CleanStorageService.saveReminder(moved);
    final request = ReminderArmRequest.forNextOccurrence(moved);
    if (request != null) {
      // Best-effort, like the tick: the move is saved, and the next launch's
      // re-arm pass recovers anything the OS refused.
      try {
        await const NotificationReminderAlarm().arm(request);
      } catch (e) {
        debugPrint('⚠️ Re-arming "${moved.title}" after a move failed: $e');
      }
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    return AccentScope(
      feature: FeatureAccent.reminders,
      child: AppScaffold(
        // Lift the FAB clear of the docked bottom nav so it isn't cramped.
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: AppFab(
            icon: Symbols.add_rounded,
            accent: ext.reminders,
            onPressed: _addReminder,
          ),
        ),
        body: Column(
          children: [
            AppHeader(
              title: 'Reminders',
              actions: [
                IconButton(
                  icon: Icon(Symbols.beach_access_rounded,
                      color: ext.mark(ext.reminders)),
                  tooltip: 'Vacation mode',
                  onPressed: _openVacation,
                ),
                IconButton(
                  icon: Icon(Symbols.auto_awesome_rounded,
                      color: ext.mark(ext.reminders)),
                  tooltip: 'Smart Add',
                  onPressed: _openSmartAdd,
                ),
              ],
            ),
            VacationBanner(onTap: _openVacation),
            if (_reminders.isNotEmpty) _adherenceCard(ext),
            if (_reminders.isNotEmpty) _searchRow(ext),
            if (_reminders.isNotEmpty) _filterBar(ext),
            Expanded(
              child: _visibleReminders.isEmpty
                  ? _emptyState(ext)
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

  /// Empty state that stays centred while it fits and scrolls once it doesn't.
  /// [EmptyState] is a Center + Column with no scrolling of its own, so inside
  /// the Expanded it was pinned to the leftover viewport height and overflowed
  /// at 200% text on a short phone. The minHeight keeps the centred look at
  /// every normal size — only the overflow case starts scrolling.
  Widget _emptyState(AppColorsExt ext) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: EmptyState(
            icon: Symbols.notifications_none_rounded,
            title: _hasActiveFilter
                ? 'No matching reminders'
                : 'No reminders yet',
            message: _hasActiveFilter
                ? 'Try a different search or filter.'
                : 'Tap + to create your first reminder.',
            accent: ext.reminders,
          ),
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
            child: AppSearchField(
              controller: _searchController,
              hint: 'Search reminders',
              accent: ext.reminders,
              onChanged: (v) => setState(() => _searchQuery = v),
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
              active ? Symbols.flag_rounded : Symbols.sort_rounded,
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
          chip('active', 'Active', icon: Symbols.radio_button_unchecked_rounded),
          chip('today', 'Today', icon: Symbols.today_rounded),
          chip('prio:high', 'High',
              icon: Symbols.flag_rounded, accent: ext.error),
          chip('prio:medium', 'Medium',
              icon: Symbols.flag_rounded, accent: ext.warning),
          chip('prio:low', 'Low', icon: Symbols.flag_rounded, accent: ext.success),
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
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    // `dayOffset`, not `add(Duration(days: 1))`. A civil day containing a
    // fall-back transition is 25 hours, so adding 24 to local midnight lands
    // on the SAME date — `DateTime(2026,11,1).add(Duration(days:1))` is
    // 2026-11-01 23:00 under TZ=America/New_York. The "Tomorrow" bucket then
    // matched today, and tomorrow's reminders were filed under "Upcoming".
    final tomorrow = dayOffset(today, 1);

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

    section('Overdue', Symbols.error_rounded, overdue, ext.error);
    section('Today', Symbols.today_rounded, dueToday, ext.reminders);
    section('Tomorrow', Symbols.wb_sunny_rounded, dueTomorrow, ext.reminders);
    section('Upcoming', Symbols.event_rounded, upcoming, ext.reminders);
    section('Completed', Symbols.check_circle_rounded, completed,
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
          // Category names are user-typed, so the pill has to be able to give
          // up width at large text sizes.
          Flexible(
            child: Text(
              c.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.labelSmall?.copyWith(
                color: col,
                fontWeight: FontWeight.w600,
              ),
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
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.labelSmall?.copyWith(color: ext.textSecondary)),
          ),
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
          Symbols.repeat_rounded, _repeatLabel(r.repeatType), ext, tt));
    }
    if (r.isPaused) {
      final back = ReminderPauseUntil.get(r.id);
      items.add(_metaItem(
          Symbols.pause_circle_rounded,
          back == null
              ? 'Paused'
              : 'Paused until ${DateFormats.dayMonth.format(back)}',
          ext,
          tt));
    }
    if (r.endsAt != null) {
      items.add(_metaItem(Symbols.event_busy_rounded,
          'Ends ${DateFormats.dayMonth.format(r.endsAt!)}', ext, tt));
    } else if (r.occurrenceLimit != null) {
      items.add(_metaItem(
          Symbols.event_busy_rounded, '${r.occurrenceLimit}×', ext, tt));
    }
    if (r.note != null && r.note!.trim().isNotEmpty) {
      items.add(_metaItem(Symbols.sticky_note_2_rounded, null, ext, tt));
    }
    if (r.imagePath != null && r.imagePath!.trim().isNotEmpty) {
      items.add(_metaItem(Symbols.image_rounded, null, ext, tt));
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
    final overdue = r.scheduledTime.isBefore(clock.now()) && !r.isCompleted;
    final isToday = DateUtils.isSameDay(r.scheduledTime, clock.now());
    final when = isToday
        ? DateFormats.time.format(r.scheduledTime)
        : DateFormats.dayMonthDotTime.format(r.scheduledTime);

    // Swipe right finishes it, swipe left puts it off. Delete moved to the menu
    // on the card, where it has an Undo: swipe-to-delete sat on the same gesture
    // people reach for to tick things off.
    //
    // "Later" is offered for a one-off that is still open. A repeating
    // reminder's time IS its schedule, so moving it would move every future
    // occurrence; that one is edited, not swiped.
    final canLater = r.repeatType == RepeatType.none &&
        r.recurrenceRule == null &&
        !r.isCompleted;
    return Dismissible(
      key: Key(r.id),
      direction:
          canLater ? DismissDirection.horizontal : DismissDirection.startToEnd,
      background: _swipeBackground(ext,
          alignment: Alignment.centerLeft,
          color: ext.success.container,
          fg: ext.success.onContainer,
          icon: Symbols.check_rounded,
          label: r.isCompleted ? 'Not done' : 'Done'),
      secondaryBackground: canLater
          ? _swipeBackground(ext,
              alignment: Alignment.centerRight,
              color: ext.reminders.container,
              fg: ext.reminders.onContainer,
              icon: Symbols.schedule_rounded,
              label: 'Later')
          : null,
      // Never removes the card itself: ticking or moving updates the list, and
      // the card returns to wherever it now belongs.
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          await _toggle(r);
        } else {
          await _later(r);
        }
        return false;
      },
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
                child: Semantics(
                  button: true,
                  checked: r.isCompleted,
                  label: r.isCompleted
                      ? 'Mark "${r.title}" not done'
                      : 'Mark "${r.title}" done',
                  excludeSemantics: true,
                  child: GestureDetector(
                  onTap: () => _toggle(r),
                  behavior: HitTestBehavior.opaque,
                  // 44px hit target around the 26px visual checkbox.
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: r.isCompleted
                              ? ext.reminders.base
                              : Colors.transparent,
                          border: Border.all(
                            color: r.isCompleted
                                ? ext.reminders.base
                                : ext.outlineStrong,
                            width: 2,
                          ),
                        ),
                        child: r.isCompleted
                            ? Icon(Symbols.check_rounded,
                                size: 16, color: ext.reminders.on)
                            : null,
                      ),
                    ),
                  ),
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
                              ? Symbols.error_rounded
                              : Symbols.schedule_rounded,
                          size: 14,
                          color: overdue ? ext.error.strong : ext.textSecondary,
                        ),
                        const SizedBox(width: 5),
                        // "Mar 3 · 9:30 AM · overdue" is wider than the card at
                        // 200% text, so let it wrap instead of overflowing.
                        Expanded(
                          child: Text(
                            overdue ? '$when · overdue' : when,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: tt.bodySmall?.copyWith(
                              color:
                                  overdue ? ext.error.strong : ext.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    ..._cardMeta(ext, r, tt),
                    if (_tuneUps[r.id] != null)
                      _tuneUpRow(ext, r, _tuneUps[r.id]!, tt),
                  ],
                ),
              ),
              // A light trigger, not a PopupMenuButton: that is dozens of elements
              // per card, and the list is the most element-hungry screen the
              // build-cost budget measures. Same visible "more" affordance,
              // and the 44pt target, for a handful of elements.
              Semantics(
                button: true,
                label: 'More options for ${r.title}',
                excludeSemantics: true,
                child: InkResponse(
                  onTap: () => _openCardMenu(r),
                  radius: 22,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(Symbols.more_vert_rounded,
                        color: ext.textTertiary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The card's "more" menu. Delete lives here (not on a swipe) and is undoable.
  Future<void> _openCardMenu(Reminder r) async {
    final ext = AppColorsExt.of(context);
    final choice = await AppBottomSheet.show<String>(
      context,
      title: r.title,
      icon: Symbols.notifications_rounded,
      accent: ext.reminders,
      builder: (ctx) => AppListTile(
        icon: Symbols.delete_rounded,
        title: 'Delete',
        iconColor: ext.error.strong,
        titleColor: ext.error.strong,
        onTap: () => Navigator.of(ctx).pop('delete'),
      ),
    );
    if (choice == 'delete') await _delete(r);
  }

  /// The strip revealed under a card as it is swiped.
  Widget _swipeBackground(
    AppColorsExt ext, {
    required Alignment alignment,
    required Color color,
    required Color fg,
    required IconData icon,
    required String label,
  }) {
    final left = alignment == Alignment.centerLeft;
    final tt = Theme.of(context).textTheme;
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(color: color, borderRadius: AppRadius.brCard),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: left
            ? [
                Icon(icon, color: fg),
                const SizedBox(width: 8),
                Text(label, style: tt.labelLarge?.copyWith(color: fg)),
              ]
            : [
                Text(label, style: tt.labelLarge?.copyWith(color: fg)),
                const SizedBox(width: 8),
                Icon(icon, color: fg),
              ],
      ),
    );
  }
}

/// Parsed result of an AI "Smart Add" query — all fields optional (except
/// title) so the review form can fill in whatever the model extracted.
class _SmartReminder {
  final String title;
  final DateTime? time;
  final RepeatType? repeat;
  final ReminderPriority? priority;
  final String? categoryId;
  final List<int>? customDays;

  /// An RFC 5545 rule for repeats [RepeatType] cannot express — "every other
  /// Tuesday", "every 3 days", "monthly", optionally bounded. Null when the
  /// phrase was ordinary and [repeat] already covers it.
  final String? recurrenceRule;
  final DateTime? endsAt;
  final int? occurrenceLimit;

  _SmartReminder({
    required this.title,
    this.time,
    this.repeat,
    this.priority,
    this.categoryId,
    this.customDays,
    this.recurrenceRule,
    this.endsAt,
    this.occurrenceLimit,
  });
}

/// The Smart Add sheet body, owning its own [TextEditingController].
///
/// The controller used to live in `_openSmartAdd` and be released with
/// `AppBottomSheet.show(...).whenComplete(controller.dispose)`. That future
/// completes when `Navigator.pop` is CALLED, not when the sheet has finished
/// animating out — so the controller was disposed while the sheet was still
/// being rebuilt with it, and Flutter threw
///
///   A TextEditingController was used after being disposed.
///
/// on every use of Smart Add, followed by a `_dependents.isEmpty` assertion and
/// "Looking up a deactivated widget's ancestor is unsafe". None of it was ever
/// seen, because `main.dart` was overwriting `FlutterError.onError`.
///
/// A `State` disposes at unmount, which is after the transition. Owning the
/// controller here is not a style preference — it is the fix.
class _SmartAddSheet extends StatefulWidget {
  final AccentSwatch accent;
  final Future<void> Function(String text) onSubmit;

  const _SmartAddSheet({required this.accent, required this.onSubmit});

  @override
  State<_SmartAddSheet> createState() => _SmartAddSheetState();
}

class _SmartAddSheetState extends State<_SmartAddSheet> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    await widget.onSubmit(text);
    // The sheet is normally gone by now; guard for the parse-failure path.
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: _controller,
          hint: 'e.g. Take vitamin D every morning at 8am',
          accent: widget.accent,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Create',
          accent: widget.accent,
          fullWidth: true,
          loading: _submitting,
          leadingIcon: Symbols.auto_awesome_rounded,
          onPressed: _submit,
        ),
      ],
    );
  }
}
