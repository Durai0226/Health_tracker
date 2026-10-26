import 'package:flutter/material.dart';

import '../../../core/health/insight.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/widgets/app/insight_kit.dart';
import '../services/insight_service.dart';
import '../services/pattern_insights.dart';

/// "Patterns": the cross-day insights the engine works out on every refresh and
/// used to show nowhere, grouped as Needs attention, Patterns and Wins.
///
/// Each card carries its own "Why this?", and "Not useful" hides that pattern
/// for 30 days. Renders NOTHING when there is nothing to say — never a heading
/// over an empty box, and never a placeholder.
class PatternsSection extends StatefulWidget {
  const PatternsSection(
      {super.key, required this.reloadKey, this.load, this.onResolved});

  /// Called after each load with whether there is anything to show, so a list
  /// that puts a gap between its items can drop the one around an empty
  /// section instead of leaving a doubled gap.
  final ValueChanged<bool>? onResolved;

  /// Changes whenever the data behind the page was rebuilt; the section loads
  /// again when it does, and not otherwise.
  final Object reloadKey;

  /// The insight source. Defaults to the real engine; a test supplies its own.
  final Future<List<Insight>> Function()? load;

  @override
  State<PatternsSection> createState() => _PatternsSectionState();
}

class _PatternsSectionState extends State<PatternsSection> {
  late Future<PatternGroups> _groups = _fetch();

  Future<PatternGroups> _fetch() async {
    try {
      final all = await (widget.load ?? InsightService.gatherAll)();
      final g = PatternInsights.group(all, hidden: HiddenPatterns.current());
      _announce(!g.isEmpty);
      return g;
    } catch (_) {
      // A pattern is a nicety; a failure to find one must never break Trends.
      _announce(false);
      return const PatternGroups(needsAttention: [], patterns: [], wins: []);
    }
  }

  void _announce(bool hasAny) {
    // After the frame: this runs from a future the first build started, and the
    // parent may rebuild in response.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onResolved?.call(hasAny);
    });
  }

  @override
  void didUpdateWidget(PatternsSection old) {
    super.didUpdateWidget(old);
    if (!identical(old.reloadKey, widget.reloadKey)) {
      _groups = _fetch();
    }
  }

  Future<void> _hide(Insight i) async {
    await HiddenPatterns.hide(i.id);
    // A BLOCK, not an arrow: `_fetch()` returns a Future, and an arrow closure
    // would hand it to setState, which asserts in debug that the callback
    // returned nothing.
    if (mounted) {
      setState(() {
        _groups = _fetch();
      });
    }
  }

  Widget _group(AppColorsExt ext, String title, List<Insight> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
          child: AppEyebrow(title.toUpperCase()),
        ),
        for (final i in items) ...[
          InsightCard(insight: i),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _hide(i),
              style: TextButton.styleFrom(
                  foregroundColor: ext.textTertiary,
                  visualDensity: VisualDensity.compact),
              child: const Text('Not useful'),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return FutureBuilder<PatternGroups>(
      future: _groups,
      builder: (context, snap) {
        final g = snap.data;
        if (g == null || g.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Patterns', style: tt.titleLarge?.copyWith(color: ext.textPrimary)),
            const SizedBox(height: 2),
            Text('What your own logs say across days.',
                style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
            _group(ext, 'Needs attention', g.needsAttention),
            _group(ext, 'Patterns', g.patterns),
            _group(ext, 'Wins', g.wins),
          ],
        );
      },
    );
  }
}
