import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/health/insight.dart' show InsightSeverity;
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import '../models/sleep_session.dart';
import '../services/sleep_service.dart';
import '../widgets/sleep_manual_log_sheet.dart';

/// A reverse-chronological list of logged nights. Swipe a row to delete.
class SleepHistoryScreen extends StatelessWidget {
  const SleepHistoryScreen({super.key});

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
          '${_dateLabel(session.wakeTime)} · ${session.durationLabel} asleep will be removed.',
      confirmLabel: 'Delete',
      danger: true,
      icon: Symbols.delete_rounded,
    );
    if (ok == true) {
      await SleepService.deleteSession(session.id);
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
            final sessions = SleepService.getAllSessions();
            return ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                AppHeader(
                  title: 'Sleep history',
                  icon: Symbols.history_rounded,
                  accent: sleep,
                  leading: AppIconButton(
                    icon: Symbols.arrow_back_rounded,
                    tooltip: 'Back',
                    accent: sleep,
                    onPressed: () => Navigator.pop(context),
                  ),
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
                              child: _HistoryRow(session: s),
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

  static String _dateLabel(DateTime d) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    if (that == today) return 'Today';
    if (that == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${weekdays[(d.weekday - 1) % 7]}, ${months[d.month - 1]} ${d.day}';
  }
}

class _HistoryRow extends StatelessWidget {
  final SleepSession session;
  const _HistoryRow({required this.session});

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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${session.efficiencyPercent}%',
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: kTabular,
                ),
              ),
              Text('efficiency',
                  style: tt.bodySmall?.copyWith(color: ext.textTertiary)),
            ],
          ),
        ],
      ),
    );
  }
}
