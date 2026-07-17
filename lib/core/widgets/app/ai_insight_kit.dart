import 'package:flutter/material.dart';
import '../../design/app_design.dart';
import '../../design/app_colors_ext.dart';
import '../../ai/ai_types.dart';
import '../../ai/insight.dart';
import '../../ai/safety_guard.dart';
import 'app_card.dart';
import 'vitals_theme.dart';

/// Shared, honest AI-UX kit (Apple HIG / Google PAIR / Microsoft HAX / NN/g).
/// Deterministic output is labelled by function, generative output carries the
/// sparkle — never "AI-wash" a rule.

/// The single, consistent entry marker for genuinely generative AI.
const IconData kAiSparkle = Icons.auto_awesome_rounded;

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
      case InsightFeature.crossCutting:
        return ext.brand;
    }
  }

  static IconData icon(InsightFeature f) {
    switch (f) {
      case InsightFeature.medicine:
        return Icons.medication_rounded;
      case InsightFeature.water:
        return Icons.water_drop_rounded;
      case InsightFeature.focus:
        return Icons.self_improvement_rounded;
      case InsightFeature.reminders:
        return Icons.notifications_rounded;
      case InsightFeature.bloodPressure:
        return Icons.favorite_rounded;
      case InsightFeature.bloodSugar:
        return Icons.bloodtype_rounded;
      case InsightFeature.crossCutting:
        return Icons.insights_rounded;
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
      AiEngineKind.ruleBased => ('On-device', Icons.offline_bolt_rounded),
      AiEngineKind.onDevice => ('On-device AI', Icons.memory_rounded),
      AiEngineKind.cloud => ('Cloud AI', Icons.cloud_rounded),
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
            Icon(Icons.info_outline_rounded, size: 20, color: ext.textSecondary),
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
          Icon(Icons.help_outline_rounded, size: 13, color: ext.textTertiary),
          const SizedBox(width: 4),
          Text('Why this?',
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

/// Persistent, action-oriented safety line for any AI surface.
class SafetyDisclaimerBar extends StatelessWidget {
  const SafetyDisclaimerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: ext.surfaceVariant,
        borderRadius: AppRadius.brMd,
      ),
      child: Row(children: [
        Icon(Icons.shield_outlined, size: 15, color: ext.textTertiary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(SafetyGuard.disclaimer,
              style: tt.bodySmall?.copyWith(color: ext.textTertiary, height: 1.3)),
        ),
      ]),
    );
  }
}

/// The structured deterministic insight card: feature icon + severity color +
/// engine badge, headline + metric + detail, and a "Why this?" affordance with
/// an optional action. The glanceable "one big thing" surface.
class InsightCard extends StatelessWidget {
  final Insight insight;
  final VoidCallback? onAction;
  final VoidCallback? onTap;

  const InsightCard({super.key, required this.insight, this.onAction, this.onTap});

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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.container,
                  borderRadius: AppRadius.brSm,
                ),
                child: Icon(InsightVisuals.icon(insight.feature),
                    size: 18, color: accent.onContainer),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(insight.title,
                    style: tt.titleMedium?.copyWith(
                        color: ext.textPrimary, fontWeight: FontWeight.w700)),
              ),
              // Severity dot (color + shape redundancy; never color alone).
              Container(width: 9, height: 9, decoration: BoxDecoration(color: sev, shape: BoxShape.circle)),
            ],
          ),
          if (insight.metric != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(insight.metric!,
                style: tt.headlineSmall?.copyWith(
                    color: sev, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          ],
          const SizedBox(height: 6),
          Text(insight.detail,
              style: tt.bodyMedium?.copyWith(color: ext.textSecondary, height: 1.4)),
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
