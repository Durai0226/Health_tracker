import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/design/app_design.dart';
import '../../../core/design/app_colors_ext.dart';
import '../../../core/ai/insight.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../services/insight_service.dart';
import 'assistant_screen.dart';
import 'weekly_recap_screen.dart';
import 'memories_screen.dart';
import 'trends_dashboard_screen.dart';

/// The dedicated AI/Insights hub, reworked into an Oura/Whoop-style "Today"
/// data-page: an editorial cover with a live on-device status line, a single
/// elevated "briefing" hero built from the top-ranked insight, a generative
/// Ask-AI composer, a quiet nav rail (Weekly recap + Memory), an optional
/// week-over-week Trends strip, then the ranked InsightCard feed (hero
/// excluded) closed by the safety footnote. All insights are deterministic +
/// on-device (each carries an honest engine badge + why-this). The AI sparkle
/// (AiSeal) appears exactly twice — cover + composer — and nowhere else.
class InsightsHubScreen extends StatefulWidget {
  /// When shown as a root tab there's nothing to pop, so the back button is
  /// hidden (a dead back arrow reads as broken).
  final bool isRoot;
  const InsightsHubScreen({super.key, this.isRoot = false});

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

  void _push(Widget screen) => Navigator.push(
      context, MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final accent = ext.brand;

    // ONE snapshot feeds cover status + hero + trends + feed so the whole page
    // reads a single coherent state.
    return AppScaffold(
      safeTop: true,
      body: FutureBuilder<List<Insight>>(
        future: _future,
        builder: (context, snap) {
          final loading = snap.connectionState != ConnectionState.done;
          final hasError = snap.hasError;
          final ranked = snap.data ?? const <Insight>[];
          final trends = ranked
              .where((i) => i.id == 'water_trend' || i.id == 'steps_trend')
              .toList();
          final core = ranked.where((i) => !trends.contains(i)).toList();
          final hero = core.isEmpty ? null : core.first;
          final feed = hero == null ? const <Insight>[] : core.skip(1).toList();

          return Column(
            children: [
              _cover(ext, accent,
                  loading: loading, hasError: hasError, ranked: ranked),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  color: ext.mark(accent),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                        AppSpacing.lg, AppSpacing.gutter, AppSpacing.huge),
                    children: [
                      // 1 — the single focal point: today's briefing hero.
                      if (hero != null) ...[
                        _briefingHero(ext, hero),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                      // 2 — generative Ask-AI composer (the 2nd & last seal).
                      _askComposer(ext),
                      const SizedBox(height: AppSpacing.xl),
                      // 3 — quiet two-tile nav rail.
                      _navRail(ext, accent),
                      // 3b — always-visible entry into the full Trends dashboard
                      // (charts every feature, 7/14/30-day selectable).
                      const SizedBox(height: AppSpacing.md),
                      _navTile(ext,
                          glyph: Symbols.monitoring_rounded,
                          accent: accent,
                          title: 'Trends dashboard',
                          stat: 'Chart every feature · 7/14/30 days',
                          onTap: () => _push(const TrendsDashboardScreen())),
                      // 4 — optional week-over-week trends.
                      if (trends.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xl),
                        _trendsStrip(ext, trends),
                      ],
                      // 5 — the ranked feed (hero excluded).
                      const SizedBox(height: AppSpacing.xl),
                      SectionHeader(
                          title: 'For you',
                          icon: Symbols.recommend_rounded,
                          accent: accent),
                      const SizedBox(height: AppSpacing.sm),
                      if (loading)
                        _skeleton(ext)
                      else if (hasError)
                        _error(ext)
                      else if (core.isEmpty)
                        _empty(ext)
                      else if (feed.isEmpty)
                        _feedTail(ext)
                      else
                        Column(
                          children: [
                            for (final i in feed)
                              Padding(
                                padding:
                                    const EdgeInsets.only(bottom: AppSpacing.sm),
                                child: InsightCard(insight: i),
                              ),
                          ],
                        ),
                      const SizedBox(height: AppSpacing.lg),
                      const SafetyDisclaimerBar(),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------------ COVER

  /// Editorial cover: back → overline → display title + seal → LIVE status line
  /// → provenance micro-line → the signature hairline that seats the page.
  Widget _cover(
    AppColorsExt ext,
    AccentSwatch accent, {
    required bool loading,
    required bool hasError,
    required List<Insight> ranked,
  }) {
    final tt = Theme.of(context).textTheme;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.isRoot) ...[
              AppIconButton(
                icon: Symbols.arrow_back_rounded,
                filled: false,
                accent: accent,
                // Guard against emptying the root history.
                onPressed: () {
                  if (Navigator.canPop(context)) Navigator.pop(context);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            Text('ON-DEVICE · PRIVATE',
                style: tt.labelSmall
                    ?.copyWith(color: ext.textTertiary, letterSpacing: 0.6)),
            const SizedBox(height: AppSpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: Text('Insights', style: tt.displayMedium)),
                const AiSeal(size: 36),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            // LIVE status line — freshness of the on-device analysis.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(Symbols.sensors_rounded,
                      size: 13, color: ext.textSecondary),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _statusText(loading, hasError, ranked),
                    style: tt.bodySmall?.copyWith(color: ext.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            // Provenance micro-line — the honest privacy promise.
            Row(
              children: [
                Icon(Symbols.lock_rounded, size: 12, color: ext.textTertiary),
                const SizedBox(width: 6),
                Text('Computed on this device — never uploaded',
                    style: tt.labelSmall?.copyWith(color: ext.textTertiary)),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(height: 1, color: ext.outline),
          ],
        ),
      ),
    );
  }

  String _statusText(bool loading, bool hasError, List<Insight> ranked) {
    if (loading) return 'Analysing your logs…';
    if (hasError) return "Couldn't refresh — pull down to retry";
    if (ranked.isEmpty) return 'No signals yet — log to begin';
    final n = ranked.length;
    final features = ranked.map((i) => i.feature).toSet().length;
    final flagged = ranked
        .where((i) =>
            i.severity == InsightSeverity.attention ||
            i.severity == InsightSeverity.urgent)
        .length;
    final parts = <String>[
      '$n signal${n == 1 ? '' : 's'} across $features feature${features == 1 ? '' : 's'}',
      if (flagged > 0) '$flagged need${flagged == 1 ? 's' : ''} attention',
      'updated just now',
    ];
    return parts.join(' · ');
  }

  // ------------------------------------------------------------------- HERO

  /// The single elevated figure — today's most important insight, feature-tinted,
  /// with a big tabular metric and one real microviz from the kit's vocabulary.
  Widget _briefingHero(AppColorsExt ext, Insight hero) {
    final tt = Theme.of(context).textTheme;
    final accent = InsightVisuals.accent(context, hero.feature);
    final onC = accent.onContainer;
    final disableAnim = MediaQuery.of(context).disableAnimations;

    final viz = _heroViz(ext, hero, accent, onC, disableAnim);

    return AppCard(
      color: accent.container,
      shadow: AppShadows.card(context),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: onC.withOpacity(0.14),
                          borderRadius: AppRadius.brSm),
                      child: Icon(InsightVisuals.icon(hero.feature),
                          size: 20, color: onC),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '${_featureName(hero.feature)} · ${_severityWord(hero.severity)}'
                            .toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.labelSmall?.copyWith(
                            color: onC.withOpacity(0.7), letterSpacing: 0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(hero.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tt.headlineSmall
                        ?.copyWith(color: onC, fontWeight: FontWeight.w700)),
                if (hero.metric != null) ...[
                  const SizedBox(height: 6),
                  Text(hero.metric!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.headlineMedium?.copyWith(
                          color: onC,
                          fontWeight: FontWeight.w800,
                          fontFeatures: kTabular,
                          letterSpacing: -0.5)),
                ],
                const SizedBox(height: 6),
                Text(hero.detail,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyMedium
                        ?.copyWith(color: onC.withOpacity(0.85), height: 1.4)),
                const SizedBox(height: AppSpacing.md),
                Container(height: 1, color: onC.withOpacity(0.15)),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    EngineBadge(engine: hero.engine),
                    const SizedBox(width: AppSpacing.sm),
                    WhyThisChip(why: hero.why),
                    const Spacer(),
                    if (hero.actionLabel != null)
                      TextButton(
                        onPressed: () => _push(
                            AssistantScreen(initialQuestion: hero.title)),
                        style: TextButton.styleFrom(
                            foregroundColor: onC,
                            visualDensity: VisualDensity.compact),
                        child: Text(hero.actionLabel!),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (viz != null) ...[
            const SizedBox(width: AppSpacing.md),
            viz,
          ],
        ],
      ),
    );
  }

  /// The hero's one real microviz — chosen strictly by available data, never
  /// fabricated: goal ratio → ProgressRing; streak → WeekDotStrip; week-over-week
  /// delta → directional badge; otherwise none (the big metric carries it).
  Widget? _heroViz(AppColorsExt ext, Insight hero, AccentSwatch accent,
      Color onC, bool disableAnim) {
    // (a) A genuine goal ratio → real ProgressRing.
    if (hero.progress != null) {
      final done = hero.progress! >= 1.0;
      return ProgressRing(
        progress: hero.progress!,
        size: 64,
        stroke: 7,
        accent: accent,
        animate: !disableAnim,
        center: done ? Icon(Symbols.check_rounded, size: 24, color: onC) : null,
      );
    }
    // (b) Streak insight → a filled week-dot strip (count parsed from the metric).
    if (hero.id.endsWith('_streak')) {
      final n = _leadingInt(hero.metric);
      if (n != null) {
        return SizedBox(
          width: 76,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const SizedBox(height: 4),
              WeekDotStrip(
                  filled: n.clamp(0, 7), total: 7, accent: accent),
            ],
          ),
        );
      }
    }
    // (c) Week-over-week / vs-average delta → a directional badge.
    final m = hero.metric;
    if (m != null && (m.startsWith('+') || m.startsWith('-'))) {
      final up = m.startsWith('+');
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
            color: onC.withOpacity(0.12), shape: BoxShape.circle),
        child: Icon(
            up ? Symbols.trending_up_rounded : Symbols.trending_down_rounded,
            size: 22,
            color: onC),
      );
    }
    return null;
  }

  // --------------------------------------------------------------- COMPOSER

  /// Generative Ask-AI composer — a faux input tap target (NOT an editable field
  /// on the hub) that carries the second and last seal, plus data-aware starters.
  Widget _askComposer(AppColorsExt ext) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _push(const AssistantScreen()),
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: ext.surface,
              borderRadius: AppRadius.brCard,
              border: Border.all(color: ext.outline),
              boxShadow: AppShadows.resting(context),
            ),
            child: Row(
              children: [
                AiSeal(size: 24, accent: ext.brand),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text('Ask about your sleep, meds, or water…',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodyMedium?.copyWith(color: ext.textTertiary)),
                ),
                const SizedBox(width: AppSpacing.md),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: ext.fillBg(ext.brand), shape: BoxShape.circle),
                  child: Icon(Symbols.arrow_upward_rounded,
                      size: 18, color: ext.fillFg(ext.brand)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        PromptChipRow(
          accent: ext.brand,
          prompts: const [
            'Why is my adherence down?',
            'Am I hydrated this week?',
            'Best focus hour?',
          ],
          onTap: (p) => _push(AssistantScreen(initialQuestion: p)),
        ),
      ],
    );
  }

  // --------------------------------------------------------------- NAV RAIL

  /// Two co-equal destination tiles, each with its own distinct squircle-badged
  /// glyph — no seals. Folds in the old memory link as the second tile.
  Widget _navRail(AppColorsExt ext, AccentSwatch accent) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _navTile(ext,
                glyph: Symbols.calendar_view_week_rounded,
                accent: accent,
                title: 'Weekly recap',
                stat: 'Your week in review',
                onTap: () => _push(const WeeklyRecapScreen())),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _navTile(ext,
                glyph: Symbols.psychology_rounded,
                accent: accent,
                title: 'Memory',
                stat: 'What the assistant remembers',
                onTap: () => _push(const MemoriesScreen())),
          ),
        ],
      ),
    );
  }

  Widget _navTile(
    AppColorsExt ext, {
    required IconData glyph,
    required AccentSwatch accent,
    required String title,
    required String stat,
    required VoidCallback onTap,
  }) {
    final tt = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      color: ext.surface,
      shadow: AppShadows.resting(context),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: ext.surfaceVariant, borderRadius: AppRadius.brMd),
                child: Icon(glyph, size: 20, color: ext.mark(accent)),
              ),
              const Spacer(),
              Icon(Symbols.chevron_right_rounded,
                  size: 18, color: ext.textTertiary),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.titleSmall?.copyWith(
                  color: ext.textPrimary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(stat,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------- TRENDS

  /// Week-over-week strip fed by the water/steps trend insights the service
  /// already computes. Severity maps to the trend arrow.
  Widget _trendsStrip(AppColorsExt ext, List<Insight> trends) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
            title: 'Trends',
            icon: Symbols.monitoring_rounded,
            accent: ext.brand,
            actionLabel: 'See dashboard',
            onAction: () => _push(const TrendsDashboardScreen())),
        const SizedBox(height: AppSpacing.sm),
        StatTileRow(
          tiles: [
            for (final i in trends)
              StatTile(
                value: i.metric ?? '—',
                label: _featureName(i.feature),
                icon: InsightVisuals.icon(i.feature),
                accent: InsightVisuals.accent(context, i.feature),
                trend: _severityTrend(i.severity),
              ),
          ],
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ STATES

  /// Hero consumed the only insight — a quiet, honest tail rather than a
  /// dangling section header.
  Widget _feedTail(AppColorsExt ext) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Text("That's the one that matters today — more appears as you log.",
          style: tt.bodyMedium?.copyWith(color: ext.textTertiary, height: 1.4)),
    );
  }

  Widget _skeleton(AppColorsExt ext) => Column(
        children: List.generate(
            3,
            (_) => Container(
                  height: 128,
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  decoration: BoxDecoration(
                      color: ext.surfaceVariant, borderRadius: AppRadius.brCard),
                )),
      );

  /// Empty state — NO seal/sparkle. A query_stats badge, a payoff-preview
  /// heading + body, then three dimmed, non-interactive ghost cards so the user
  /// sees what's coming instead of a dead void.
  Widget _empty(AppColorsExt ext) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: ext.surfaceVariant, borderRadius: AppRadius.brMd),
              child: Icon(Symbols.query_stats_rounded,
                  size: 20, color: ext.textSecondary),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text('Insights appear as your data builds',
                  style: tt.titleMedium?.copyWith(
                      color: ext.textPrimary, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
            "We're watching your logs — log water, a dose, or a focus session and your briefing fills in here.",
            style:
                tt.bodyMedium?.copyWith(color: ext.textSecondary, height: 1.4)),
        const SizedBox(height: AppSpacing.lg),
        // Dimmed, non-interactive previews of the payoff.
        Opacity(
          opacity: 0.4,
          child: IgnorePointer(
            child: Column(
              children: [
                _ghostCard(ext, InsightFeature.medicine, 'Adherence slipping',
                    '82%'),
                const SizedBox(height: AppSpacing.sm),
                _ghostCard(
                    ext, InsightFeature.water, 'Hydration goal reached', '100%'),
                const SizedBox(height: AppSpacing.sm),
                _ghostCard(ext, InsightFeature.sleep, 'Short on sleep last night',
                    '6h 10m'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// A compact InsightCard-styled stub for the empty-state preview.
  Widget _ghostCard(
      AppColorsExt ext, InsightFeature feature, String title, String metric) {
    final tt = Theme.of(context).textTheme;
    final accent = InsightVisuals.accent(context, feature);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(InsightVisuals.icon(feature),
                  size: 14, color: ext.mark(accent)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_featureName(feature).toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.labelSmall
                        ?.copyWith(color: ext.textTertiary, letterSpacing: 0.5)),
              ),
              Container(
                  width: 9,
                  height: 9,
                  decoration:
                      BoxDecoration(color: ext.outline, shape: BoxShape.circle)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(title, style: tt.headlineSmall?.copyWith(color: ext.textPrimary)),
          const SizedBox(height: 6),
          Text(metric,
              style: tt.headlineMedium?.copyWith(
                  color: ext.textTertiary,
                  fontWeight: FontWeight.w800,
                  fontFeatures: kTabular,
                  letterSpacing: -0.5)),
          const SizedBox(height: AppSpacing.sm),
          WeekDotStrip(filled: 4, total: 7, accent: accent),
        ],
      ),
    );
  }

  Widget _error(AppColorsExt ext) {
    final tt = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Symbols.error_rounded, size: 32, color: ext.textTertiary),
          const SizedBox(height: AppSpacing.md),
          Text("Couldn't load your insights",
              style: tt.headlineSmall?.copyWith(color: ext.textPrimary)),
          const SizedBox(height: 6),
          Text(
              'Something went wrong while gathering your briefing. Your data is safe — please try again.',
              style: tt.bodyMedium
                  ?.copyWith(color: ext.textSecondary, height: 1.4)),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Try again',
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.sm,
            leadingIcon: Symbols.refresh_rounded,
            accent: ext.brand,
            onPressed: () =>
                setState(() => _future = InsightService.gatherAll()),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ HELPERS

  static StatTrend _severityTrend(InsightSeverity s) {
    switch (s) {
      case InsightSeverity.good:
        return StatTrend.up;
      case InsightSeverity.attention:
      case InsightSeverity.urgent:
        return StatTrend.down;
      case InsightSeverity.info:
        return StatTrend.flat;
    }
  }

  static int? _leadingInt(String? s) {
    if (s == null) return null;
    final m = RegExp(r'^(\d+)').firstMatch(s);
    return m == null ? null : int.tryParse(m.group(1)!);
  }

  static String _featureName(InsightFeature f) {
    switch (f) {
      case InsightFeature.medicine:
        return 'Medicine';
      case InsightFeature.water:
        return 'Water';
      case InsightFeature.focus:
        return 'Focus';
      case InsightFeature.reminders:
        return 'Reminders';
      case InsightFeature.bloodPressure:
        return 'Blood pressure';
      case InsightFeature.bloodSugar:
        return 'Blood sugar';
      case InsightFeature.period:
        return 'Cycle';
      case InsightFeature.steps:
        return 'Steps';
      case InsightFeature.sleep:
        return 'Sleep';
      case InsightFeature.crossCutting:
        return 'Across features';
    }
  }

  static String _severityWord(InsightSeverity s) {
    switch (s) {
      case InsightSeverity.good:
        return 'On track';
      case InsightSeverity.info:
        return 'Note';
      case InsightSeverity.attention:
        return 'Needs attention';
      case InsightSeverity.urgent:
        return 'Act now';
    }
  }
}
