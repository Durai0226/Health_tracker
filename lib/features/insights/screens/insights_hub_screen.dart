import 'package:flutter/material.dart';
import '../../../core/design/app_design.dart';
import '../../../core/design/app_colors_ext.dart';
import '../../../core/ai/insight.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../services/insight_service.dart';
import 'assistant_screen.dart';
import 'weekly_recap_screen.dart';

/// The dedicated AI/Insights hub: ranked "one big thing" insights across every
/// feature, plus entries to the Assistant and the weekly recap. All insights are
/// deterministic + on-device (each carries an honest engine badge + why-this).
class InsightsHubScreen extends StatefulWidget {
  const InsightsHubScreen({super.key});

  @override
  State<InsightsHubScreen> createState() => _InsightsHubScreenState();
}

class _InsightsHubScreenState extends State<InsightsHubScreen> {
  late Future<List<Insight>> _future;

  @override
  void initState() {
    super.initState();
    _future = InsightService.gatherAll();
  }

  Future<void> _refresh() async {
    setState(() => _future = InsightService.gatherAll());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final accent = ext.brand;

    return AppScaffold(
      safeTop: true,
      body: Column(
        children: [
          AppHeader(
            title: 'Insights',
            icon: kAiSparkle,
            accent: accent,
            leading: AppIconButton(
              icon: Icons.arrow_back_rounded,
              filled: false,
              accent: accent,
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: ext.mark(accent),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, AppSpacing.huge),
                children: [
                  _entries(ext, accent),
                  const SizedBox(height: AppSpacing.lg),
                  SectionHeader(
                      title: 'For you', icon: Icons.tips_and_updates_rounded, accent: accent),
                  const SizedBox(height: AppSpacing.sm),
                  FutureBuilder<List<Insight>>(
                    future: _future,
                    builder: (context, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return _skeleton(ext);
                      }
                      final items = snap.data ?? const [];
                      if (items.isEmpty) return _empty(ext);
                      return Column(
                        children: [
                          for (final i in items)
                            Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: InsightCard(insight: i),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const SafetyDisclaimerBar(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _entries(AppColorsExt ext, AccentSwatch accent) {
    return Row(
      children: [
        Expanded(
          child: _entryCard(
            ext,
            icon: kAiSparkle,
            label: 'Ask AI',
            sub: 'About your data',
            accent: accent,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AssistantScreen())),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _entryCard(
            ext,
            icon: Icons.calendar_view_week_rounded,
            label: 'Weekly recap',
            sub: 'Your week in review',
            accent: accent,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const WeeklyRecapScreen())),
          ),
        ),
      ],
    );
  }

  Widget _entryCard(AppColorsExt ext,
      {required IconData icon,
      required String label,
      required String sub,
      required AccentSwatch accent,
      required VoidCallback onTap}) {
    final tt = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: accent.container, borderRadius: AppRadius.brSm),
            child: Icon(icon, size: 20, color: accent.onContainer),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(label, style: tt.titleSmall?.copyWith(color: ext.textPrimary, fontWeight: FontWeight.w700)),
          Text(sub, style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
        ],
      ),
    );
  }

  Widget _skeleton(AppColorsExt ext) => Column(
        children: List.generate(
            3,
            (_) => Container(
                  height: 96,
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  decoration: BoxDecoration(
                      color: ext.surfaceVariant, borderRadius: AppRadius.brLg),
                )),
      );

  Widget _empty(AppColorsExt ext) {
    final tt = Theme.of(context).textTheme;
    return AppCard(
      child: Column(children: [
        Icon(Icons.insights_rounded, size: 40, color: ext.textTertiary),
        const SizedBox(height: AppSpacing.sm),
        Text('No insights yet',
            style: tt.titleMedium?.copyWith(color: ext.textPrimary)),
        const SizedBox(height: 4),
        Text('Log a few readings, doses, or focus sessions and personalized insights will appear here.',
            textAlign: TextAlign.center,
            style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
      ]),
    );
  }
}
