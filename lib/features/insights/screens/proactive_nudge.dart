import 'package:flutter/material.dart';
import '../../../core/ai/insight.dart';
import '../../../core/ai/nudge_scheduler.dart';
import '../../../core/services/clean_storage_service.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../services/insight_service.dart';
import 'insights_hub_screen.dart';

/// A self-managing, frequency-capped proactive nudge for the Home screen. Loads
/// the top actionable insight, shows it only if the frequency cap allows and it
/// hasn't been dismissed, and records show/dismiss state in app preferences.
/// Renders nothing (zero height) when there's nothing to nudge.
class ProactiveNudge extends StatefulWidget {
  const ProactiveNudge({super.key});

  @override
  State<ProactiveNudge> createState() => _ProactiveNudgeState();
}

class _ProactiveNudgeState extends State<ProactiveNudge> {
  static const _showsKey = 'nudge_shows';
  static const _dismissedKey = 'nudge_dismissed';

  Insight? _insight;

  @override
  void initState() {
    super.initState();
    _maybeLoad();
  }

  Future<void> _maybeLoad() async {
    try {
      final shows = _readList(_showsKey)
          .map(DateTime.tryParse)
          .whereType<DateTime>()
          .toList();
      final now = DateTime.now();
      if (!NudgeScheduler.shouldShow(recentShows: shows, now: now)) return;

      final dismissed = _readList(_dismissedKey).toSet();
      final insights = await InsightService.gatherAll();
      Insight? top;
      for (final i in insights) {
        if (i.severity.index < InsightSeverity.attention.index) break; // ranked
        if (!dismissed.contains(i.id)) {
          top = i;
          break;
        }
      }
      if (top == null || !mounted) return;

      // Record the show.
      shows.add(now);
      await CleanStorageService.setAppPreference(
          _showsKey,
          shows
              .where((t) => now.difference(t).inDays < 8)
              .map((t) => t.toIso8601String())
              .toList());
      setState(() => _insight = top);
    } catch (_) {/* silent — nudges are best-effort */}
  }

  Future<void> _dismiss() async {
    final id = _insight?.id;
    if (id != null) {
      final dismissed = _readList(_dismissedKey).toSet()..add(id);
      await CleanStorageService.setAppPreference(_dismissedKey, dismissed.toList());
    }
    if (mounted) setState(() => _insight = null);
  }

  List<String> _readList(String key) {
    final v = CleanStorageService.getAppPreference(key, const <String>[]);
    if (v is List) return v.map((e) => e.toString()).toList();
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    if (_insight == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: ProactiveNudgeBanner(
        insight: _insight!,
        onDismiss: _dismiss,
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const InsightsHubScreen())),
      ),
    );
  }
}
