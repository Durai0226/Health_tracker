import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/health/insight.dart' show InsightSeverity;
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import '../models/sleep_session.dart';
import '../models/sleep_stage.dart';
import '../services/sleep_service.dart';
import '../widgets/sleep_manual_log_sheet.dart';
import '../widgets/sleep_night_detail_sheet.dart';

/// A reverse-chronological list of logged nights. Swipe a row to delete; tap one
/// you logged to change it, or one a health app recorded to see it in full. The
/// last five weeks are on screen at once; "Show earlier nights" reads further back.
class SleepHistoryScreen extends StatefulWidget {
  const SleepHistoryScreen({super.key});

  /// How many earlier nights each tap of "Show earlier nights" adds.
  static const int pageSize = 30;

  @override
  State<SleepHistoryScreen> createState() => _SleepHistoryScreenState();

  static String _dateLabel(DateTime d) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    if (that == today) return 'Today';
    if (that == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${weekdays[(d.weekday - 1) % 7]}, ${months[d.month - 1]} ${d.day}';
  }
}

class _SleepHistoryScreenState extends State<SleepHistoryScreen> {
  /// Nights read from further back than the screen holds in memory, newest first.
  final List<SleepSession> _earlier = [];
  bool _more = false;
  bool _loadingMore = false;
  bool _exhausted = false;

  @override
  void initState() {
    super.initState();
    _checkForMore();
  }

  /// The wake time to read before: the oldest night on screen.
  DateTime? _cursor() {
    if (_earlier.isNotEmpty) return _earlier.last.wakeTime;
    final held = SleepService.getAllSessions();
    return held.isEmpty ? null : held.last.wakeTime;
  }

  Future<void> _checkForMore() async {
    final cursor = _cursor();
    if (cursor == null) return;
    final more = await SleepService.hasEarlier(before: cursor);
    if (mounted) setState(() => _more = more);
  }

  Future<void> _loadEarlier() async {
    final cursor = _cursor();
    if (cursor == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    final page = await SleepService.earlierNights(
        before: cursor, limit: SleepHistoryScreen.pageSize);
    if (!mounted) return;
    _earlier.addAll(page);
    final next = _cursor();
    final more = next != null && await SleepService.hasEarlier(before: next);
    if (!mounted) return;
    setState(() {
      _loadingMore = false;
      _more = more;
      // Said once there is nothing further, so the end of the list is not a
      // button that quietly stops appearing.
      _exhausted = !more;
    });
  }

  /// A night that opens the form (one the person logged) or a read-only sheet
  /// (one a health app recorded).
  Future<void> _open(SleepSession night) async {
    if (night.source == SleepSource.manual) {
      await _edit(night);
    } else {
      await SleepNightDetailSheet.show(context, night);
    }
  }

  Future<void> _edit(SleepSession night) async {
    final result = await SleepManualLogSheet.show(
      context,
      schedule: SleepService.getSchedule(),
      editing: night,
    );
    if (result == null) return;
    final r = await SleepService.editManualNight(
      night,
      bedtime: result.bedtime,
      wakeTime: result.wakeTime,
      quality: result.quality,
      note: result.note,
    );
    if (!mounted) return;
    final edit = r.edit;
    if (edit == null) {
      context.toastError(r.problem ?? 'Could not change that night.');
      return;
    }
    setState(() => _swap(edit.before.id, edit.after));
    context.toastSuccess(
      'Night updated',
      action: AppToastAction(
        label: 'Undo',
        onPressed: () async {
          await SleepService.undoEdit(edit);
          if (mounted) setState(() => _swap(edit.after.id, edit.before));
        },
      ),
    );
  }

  /// Replace an earlier night in place; a night held in memory is updated by the
  /// service's own notifier.
  void _swap(String id, SleepSession replacement) {
    final i = _earlier.indexWhere((e) => e.id == id);
    if (i >= 0) _earlier[i] = replacement;
  }

  Future<void> _logManual(BuildContext context) async {
    final result = await SleepManualLogSheet.show(
      context,
      schedule: SleepService.getSchedule(),
    );
    if (result == null) return;
    await SleepService.logManualSession(
      bedtime: result.bedtime,
      wakeTime: result.wakeTime,
      quality: result.quality,
      note: result.note,
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, SleepSession session) async {
    final ok = await AppBottomSheet.confirm(
      context,
      title: 'Delete this night?',
      message:
          '${SleepHistoryScreen._dateLabel(session.wakeTime)} · ${session.durationLabel} asleep will be removed.',
      confirmLabel: 'Delete',
      danger: true,
      icon: Symbols.delete_rounded,
    );
    if (ok == true) {
      await SleepService.deleteSession(session.id);
      if (mounted) setState(() => _earlier.removeWhere((e) => e.id == session.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final sleep = ext.sleep;

    return AccentScope(
      feature: FeatureAccent.sleep,
      child: AppScaffold(
        floatingActionButton: AppFab(
          icon: Symbols.add_rounded,
          onPressed: () => _logManual(context),
        ),
        body: ValueListenableBuilder<Map<String, SleepSession>>(
          valueListenable: SleepService.listenToSessions(),
          builder: (context, _, _) {
            final held = SleepService.getAllSessions();
            final heldIds = {for (final h in held) h.id};
            final sessions = [
              ...held,
              ..._earlier.where((e) => !heldIds.contains(e.id)),
            ]..sort((a, b) => b.wakeTime.compareTo(a.wakeTime));
            return ListView(
              padding: EdgeInsets.only(bottom: AppInsets.underNav(context)),
              children: [
                AppHeader(
                  title: 'Sleep history',
                  leading: AppHeader.backButton(context),
                ),
                if (sessions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.huge),
                    child: EmptyState(
                      icon: Symbols.nightlight_round_rounded,
                      title: 'No nights logged',
                      message: 'Your logged sleep will appear here.',
                      accent: sleep,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.gutter),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final s in sessions)
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.md),
                            child: Dismissible(
                              key: ValueKey(s.id),
                              direction: DismissDirection.endToStart,
                              background: _deleteBackground(context),
                              confirmDismiss: (_) async {
                                await _confirmDelete(context, s);
                                // The notifier drives the rebuild; keep the tile
                                // (return false) so Dismissible doesn't also try
                                // to remove an already-removed item.
                                return false;
                              },
                              child: _HistoryRow(session: s, onTap: () => _open(s)),
                            ),
                          ),
                        if (_more)
                          AppButton(
                            label: 'Show earlier nights',
                            variant: AppButtonVariant.ghost,
                            fullWidth: true,
                            loading: _loadingMore,
                            onPressed: _loadEarlier,
                          )
                        else if (_exhausted)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.sm),
                            child: Center(
                              child: Text('That is every night on record.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: ext.textTertiary)),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _deleteBackground(BuildContext context) {
    final ext = AppColorsExt.of(context);
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: AppSpacing.xl),
      decoration: BoxDecoration(
        color: ext.error.container,
        borderRadius: AppRadius.brCard,
      ),
      child: Icon(Symbols.delete_rounded, color: ext.error.onContainer),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final SleepSession session;
  final VoidCallback onTap;
  const _HistoryRow({required this.session, required this.onTap});

  static Color _band(AppColorsExt ext, int score) {
    final InsightSeverity sev;
    if (score >= 85) {
      sev = InsightSeverity.good;
    } else if (score >= 70) {
      sev = InsightSeverity.info;
    } else if (score >= 50) {
      sev = InsightSeverity.attention;
    } else {
      sev = InsightSeverity.urgent;
    }
    return InsightVisuals.severityColor(ext, sev);
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final band = _band(ext, session.sleepScore);

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: band.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(color: band.withValues(alpha: 0.5), width: 1.5),
            ),
            child: Text(
              session.sleepScore > 0 ? '${session.sleepScore}' : '--',
              style: tt.titleMedium?.copyWith(
                color: band,
                fontWeight: FontWeight.w800,
                fontFeatures: kTabular,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(SleepHistoryScreen._dateLabel(session.wakeTime),
                    style: tt.titleLarge),
                const SizedBox(height: 2),
                Text(
                  '${session.durationLabel} asleep · ${session.measurementLabel}',
                  style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
                ),
              ],
            ),
          ),
          // The 90 baselined overflow combinations on this screen were all this
          // one column, repeated once per logged night: non-flex, so it took its
          // intrinsic width first and pushed the row over by 64px at 320pt /
          // 2.0x. Three distinct shapes, thirty rows.
          //
          // Same treatment `SettingsTile` gives a trailing value, and for the
          // reason written down there: a trailing figure must stay on one line
          // and shrink to fit, because breaking "efficiency" mid-word reads as a
          // rendering fault. `scaleDown` never enlarges, so at the default text
          // size this renders exactly as before.
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${session.efficiencyPercent}%',
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: kTabular,
                    ),
                    maxLines: 1,
                    softWrap: false,
                  ),
                  Text('efficiency',
                      style: tt.bodySmall?.copyWith(color: ext.textTertiary),
                      maxLines: 1,
                      softWrap: false),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
