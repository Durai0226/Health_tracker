import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../design/app_design.dart';
import '../../design/app_colors_ext.dart';
import '../../design/app_icons.dart';
import '../../ai/ai_types.dart';
import '../../ai/insight.dart';
import '../../ai/safety_guard.dart';
import 'app_card.dart';
import 'progress_ring.dart';
import 'vitals_theme.dart';

/// Shared, honest AI-UX kit (Apple HIG / Google PAIR / Microsoft HAX / NN/g).
/// Deterministic output is labelled by function, generative output carries the
/// sparkle — never "AI-wash" a rule.
///
/// The "Briefing" design language: one outlined [AiSeal] hallmark at three
/// sizes, tabular figures on every numeral, small-caps overlines, and 1px
/// hairlines on a strict 4pt grid — an Oura/Whoop data-page feel that stays
/// inside the flat, no-gradient Calm Clarity contract.

/// The single, consistent entry marker for genuinely generative AI — routed
/// through the icon facade so the hallmark upgrades app-wide from one place.
const IconData kAiSparkle = AppIcons.aiSeal;

/// Tabular figures — the identity cue and the fix for numeral misalignment.
/// Applied to every number rendered by the AI surfaces.
const List<FontFeature> kTabular = [FontFeature.tabularFigures()];

/// The cohesive AI hallmark: an outlined circle enclosing the sparkle. Repeated
/// at 20 / 24 / 32 / 36 / 56 across every AI surface so one mark — not a
/// gradient orb — carries the AI identity. Asset-free, theme-aware.
class AiSeal extends StatelessWidget {
  final double size;
  final AccentSwatch? accent;

  /// Override the stroke/glyph colour (e.g. `onContainer` on a tinted cover).
  final Color? color;
  const AiSeal({super.key, this.size = 36, this.accent, this.color});

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final c = color ?? ext.mark(accent ?? ext.brand);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: c, width: size >= 48 ? 2.5 : 2.0),
      ),
      child: Icon(kAiSparkle, size: size * 0.5, color: c),
    );
  }
}

/// A 7-dot week strip: filled dots = accent, remainder = outline. Makes a
/// "days hit" count legible at a glance without dead space.
class WeekDotStrip extends StatelessWidget {
  final int filled;
  final int total;
  final AccentSwatch accent;
  const WeekDotStrip(
      {super.key, required this.filled, this.total = 7, required this.accent});

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++)
          Padding(
            padding: EdgeInsets.only(right: i == total - 1 ? 0 : AppSpacing.xs),
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: i < filled ? ext.mark(accent) : ext.outline,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

/// A ring-backed KPI cell — a [ProgressRing] wrapping a tabular numeral over a
/// small-caps label. Empty state → track-only ring + muted numeral so a zero
/// reads as "nothing yet", not broken.
class KpiCell extends StatelessWidget {
  final double progress;
  final String value;
  final String label;
  final AccentSwatch accent;
  final bool muted;
  const KpiCell({
    super.key,
    required this.progress,
    required this.value,
    required this.label,
    required this.accent,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ProgressRing(
          progress: progress,
          size: 60,
          stroke: 6,
          accent: accent,
          animate: !MediaQuery.of(context).disableAnimations,
          center: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: tt.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: kTabular,
                color: muted ? ext.textTertiary : ext.textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
          style: tt.labelSmall
              ?.copyWith(color: ext.textSecondary, letterSpacing: 0.5),
        ),
      ],
    );
  }
}

/// Resolve a feature's accent + icon.
class InsightVisuals {
  const InsightVisuals._();

  static AccentSwatch accent(BuildContext context, InsightFeature f) {
    final ext = AppColorsExt.of(context);
    switch (f) {
      case InsightFeature.medicine:
        return ext.medicine;
      case InsightFeature.water:
        return ext.water;
      case InsightFeature.focus:
        return ext.focus;
      case InsightFeature.reminders:
        return ext.reminders;
      case InsightFeature.bloodPressure:
        return VitalsColors.bpAccent(ext.isDark);
      case InsightFeature.bloodSugar:
        return VitalsColors.glucoseAccent(ext.isDark);
      case InsightFeature.period:
        return ext.period;
      case InsightFeature.steps:
        return ext.steps;
      case InsightFeature.sleep:
        return ext.sleep;
      case InsightFeature.crossCutting:
        return ext.brand;
    }
  }

  static IconData icon(InsightFeature f) {
    switch (f) {
      case InsightFeature.medicine:
        return Symbols.medication_rounded;
      case InsightFeature.water:
        return Symbols.water_drop_rounded;
      case InsightFeature.focus:
        return Symbols.self_improvement_rounded;
      case InsightFeature.reminders:
        return Symbols.notifications_rounded;
      case InsightFeature.bloodPressure:
        return Symbols.favorite_rounded;
      case InsightFeature.bloodSugar:
        return Symbols.bloodtype_rounded;
      case InsightFeature.period:
        return Symbols.calendar_month_rounded;
      case InsightFeature.steps:
        return Symbols.directions_walk_rounded;
      case InsightFeature.sleep:
        return Symbols.bedtime_rounded;
      case InsightFeature.crossCutting:
        return Symbols.insights_rounded;
    }
  }

  static Color severityColor(AppColorsExt ext, InsightSeverity s) {
    switch (s) {
      case InsightSeverity.good:
        return ext.mark(ext.success);
      case InsightSeverity.info:
        return ext.mark(ext.info);
      case InsightSeverity.attention:
        return ext.mark(ext.warning);
      case InsightSeverity.urgent:
        return ext.mark(ext.error);
    }
  }
}

/// Honest engine/privacy pill: deterministic → "On-device", generative on-device
/// → "On-device AI", cloud → "Cloud AI".
class EngineBadge extends StatelessWidget {
  final AiEngineKind engine;
  const EngineBadge({super.key, required this.engine});

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final (label, icon) = switch (engine) {
      AiEngineKind.ruleBased => ('On-device', Symbols.offline_bolt_rounded),
      AiEngineKind.onDevice => ('On-device AI', Symbols.memory_rounded),
      AiEngineKind.cloud => ('Cloud AI', Symbols.cloud_rounded),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ext.surfaceVariant,
        borderRadius: AppRadius.brFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: ext.textTertiary),
          const SizedBox(width: 4),
          Text(label,
              style: tt.labelSmall?.copyWith(
                  color: ext.textTertiary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// "Why this?" affordance — reveals the exact rule/data behind an insight.
class WhyThisChip extends StatelessWidget {
  final String why;
  const WhyThisChip({super.key, required this.why});

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: AppRadius.brFull,
      onTap: () => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColorsExt.of(ctx).surface,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.brLg),
          title: Row(children: [
            Icon(Symbols.info_rounded, size: 20, color: ext.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            const Text('Why you\'re seeing this'),
          ]),
          content: Text(why,
              style: Theme.of(ctx)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColorsExt.of(ctx).textSecondary)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Got it')),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Symbols.help_rounded, size: 13, color: ext.textTertiary),
          const SizedBox(width: 4),
          Text('Why this?',
              style: tt.labelSmall?.copyWith(color: ext.textTertiary)),
        ]),
      ),
    );
  }
}

/// Provenance affordance for a grounded (RAG) answer — a "Source" chip that
/// reveals the exact curated knowledge-base text the answer was drawn from.
/// Makes the assistant inspectable: the user can see it isn't inventing claims.
class SourceChip extends StatelessWidget {
  final String label;
  final String quote;
  const SourceChip({super.key, required this.label, required this.quote});

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: AppRadius.brFull,
      onTap: () => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColorsExt.of(ctx).surface,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.brLg),
          title: Row(children: [
            Icon(Symbols.menu_book_rounded, size: 20, color: ext.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(child: Text('Source')),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: tt.labelLarge?.copyWith(
                      color: AppColorsExt.of(ctx).textPrimary,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.sm),
              Text('“$quote”',
                  style: tt.bodyMedium?.copyWith(
                      color: AppColorsExt.of(ctx).textSecondary, height: 1.4)),
              const SizedBox(height: AppSpacing.md),
              Text('General wellness information — not a diagnosis.',
                  style: tt.labelSmall
                      ?.copyWith(color: AppColorsExt.of(ctx).textTertiary)),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Got it')),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Symbols.menu_book_rounded, size: 13, color: ext.textTertiary),
          const SizedBox(width: 4),
          Text('Source',
              style: tt.labelSmall?.copyWith(color: ext.textTertiary)),
        ]),
      ),
    );
  }
}

/// A horizontally-scrolling row of tappable suggestion prompts (empty states,
/// follow-ups, inline "Ask"). Teaches range in one tap (HAX G1).
class PromptChipRow extends StatelessWidget {
  final List<String> prompts;
  final ValueChanged<String> onTap;
  final AccentSwatch? accent;
  const PromptChipRow(
      {super.key, required this.prompts, required this.onTap, this.accent});

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final s = accent ?? ext.brand;
    final tt = Theme.of(context).textTheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: prompts
            .map((p) => Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: InkWell(
                    borderRadius: AppRadius.brFull,
                    onTap: () => onTap(p),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: s.container,
                        borderRadius: AppRadius.brFull,
                        border: Border.all(color: s.base.withOpacity(0.25)),
                      ),
                      child: Text(p,
                          style: tt.labelMedium?.copyWith(
                              color: s.onContainer, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

/// Persistent safety line for any AI surface — a quiet print-footnote: a top
/// hairline + shield + tertiary text. Distinct from cards (which keep fills),
/// consistent across all three screens.
class SafetyDisclaimerBar extends StatelessWidget {
  const SafetyDisclaimerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 1, color: ext.outline),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Symbols.shield_rounded, size: 14, color: ext.textTertiary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(SafetyGuard.disclaimer,
                  style: tt.bodySmall
                      ?.copyWith(color: ext.textTertiary, height: 1.3)),
            ),
          ],
        ),
      ],
    );
  }
}

/// A dismissible proactive nudge banner (frequency-capped by the caller). Shows
/// the single most important insight with a "Why this?" and a dismiss.
class ProactiveNudgeBanner extends StatelessWidget {
  final Insight insight;
  final VoidCallback onDismiss;
  final VoidCallback? onTap;
  const ProactiveNudgeBanner(
      {super.key, required this.insight, required this.onDismiss, this.onTap});

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final accent = InsightVisuals.accent(context, insight.feature);
    final sev = InsightVisuals.severityColor(ext, insight.severity);
    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: accent.container, borderRadius: AppRadius.brSm),
            child: Icon(InsightVisuals.icon(insight.feature), size: 18, color: accent.onContainer),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(insight.title,
                        style: tt.titleSmall?.copyWith(
                            color: ext.textPrimary, fontWeight: FontWeight.w700)),
                  ),
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: sev, shape: BoxShape.circle)),
                ]),
                const SizedBox(height: 2),
                Text(insight.detail,
                    style: tt.bodySmall?.copyWith(color: ext.textSecondary, height: 1.35)),
                const SizedBox(height: 4),
                Row(children: [
                  WhyThisChip(why: insight.why),
                  const Spacer(),
                  TextButton(
                    onPressed: onDismiss,
                    style: TextButton.styleFrom(
                        foregroundColor: ext.textTertiary,
                        visualDensity: VisualDensity.compact),
                    child: const Text('Dismiss'),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The structured deterministic insight card, in the "Briefing" grammar:
/// a small-caps overline (feature glyph + feature word + severity word + dot),
/// an editorial title, the metric set large as a tabular-figure hero on its own
/// line, the detail, a footer hairline, then engine badge + why-this + action.
/// The glanceable "one big thing" surface.
class InsightCard extends StatelessWidget {
  final Insight insight;
  final VoidCallback? onAction;
  final VoidCallback? onTap;

  const InsightCard({super.key, required this.insight, this.onAction, this.onTap});

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

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final accent = InsightVisuals.accent(context, insight.feature);
    final sev = InsightVisuals.severityColor(ext, insight.severity);

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1 — OVERLINE: feature glyph + feature · severity + severity dot.
          Row(
            children: [
              Icon(InsightVisuals.icon(insight.feature),
                  size: 14, color: ext.mark(accent)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${_featureName(insight.feature).toUpperCase()} · ${_severityWord(insight.severity).toUpperCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.labelSmall
                      ?.copyWith(color: ext.textTertiary, letterSpacing: 0.5),
                ),
              ),
              const SizedBox(width: 6),
              // Severity dot (colour + shape redundancy; never colour alone).
              Container(
                  width: 9,
                  height: 9,
                  decoration:
                      BoxDecoration(color: sev, shape: BoxShape.circle)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Row 2 — editorial title.
          Text(insight.title,
              style: tt.headlineSmall?.copyWith(color: ext.textPrimary)),
          // Row 3 — METRIC HERO on its own left-aligned line.
          if (insight.metric != null) ...[
            const SizedBox(height: 6),
            Text(insight.metric!,
                style: tt.headlineMedium?.copyWith(
                    color: sev,
                    fontWeight: FontWeight.w800,
                    fontFeatures: kTabular,
                    letterSpacing: -0.5)),
          ],
          const SizedBox(height: 6),
          Text(insight.detail,
              style: tt.bodyMedium?.copyWith(color: ext.textSecondary, height: 1.4)),
          const SizedBox(height: AppSpacing.md),
          Container(height: 1, color: ext.outline),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              EngineBadge(engine: insight.engine),
              const SizedBox(width: AppSpacing.sm),
              WhyThisChip(why: insight.why),
              const Spacer(),
              if (insight.actionLabel != null && onAction != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                      foregroundColor: ext.mark(accent),
                      visualDensity: VisualDensity.compact),
                  child: Text(insight.actionLabel!),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
