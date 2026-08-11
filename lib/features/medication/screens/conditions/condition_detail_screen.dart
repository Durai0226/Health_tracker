import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../../core/design/app_design.dart';
import '../../../../core/design/app_colors_ext.dart';
import '../../../../core/widgets/app/app_widgets.dart';
import '../../../../core/widgets/app/insight_kit.dart' show SafetyDisclaimerBar;
import '../../models/condition_info.dart';

/// Detail view for one [ConditionInfo] — overview, common symptoms, self-care
/// tips, and red-flag symptoms. General education only; see
/// [ConditionInfo]'s doc and the persistent [SafetyDisclaimerBar] at the foot
/// of this screen.
class ConditionDetailScreen extends StatelessWidget {
  final ConditionInfo condition;
  const ConditionDetailScreen({super.key, required this.condition});

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final accent = ext.medicine;
    final tt = Theme.of(context).textTheme;

    return AppScaffold(
      safeTop: true,
      body: Column(
        children: [
          AppHeader(
            title: condition.name,
            icon: condition.category.icon,
            accent: accent,
            leading: AppIconButton(
              icon: Symbols.arrow_back_rounded,
              filled: false,
              accent: accent,
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter, AppSpacing.md, AppSpacing.gutter, AppSpacing.xl),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CategoryChip(category: condition.category, accent: accent),
                      const SizedBox(height: AppSpacing.sm),
                      Text(condition.overview,
                          style: tt.bodyMedium
                              ?.copyWith(color: ext.textPrimary, height: 1.4)),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _bulletSection(
                  ext,
                  tt,
                  title: 'Common symptoms',
                  icon: Symbols.checklist_rounded,
                  accent: accent,
                  items: condition.commonSymptoms,
                  bulletIcon: Symbols.circle,
                  bulletColor: ext.textTertiary,
                ),
                const SizedBox(height: AppSpacing.lg),
                _bulletSection(
                  ext,
                  tt,
                  title: 'Self-care tips',
                  icon: Symbols.self_improvement_rounded,
                  accent: accent,
                  items: condition.selfCareTips,
                  bulletIcon: Symbols.done_rounded,
                  bulletColor: ext.mark(accent),
                ),
                const SizedBox(height: AppSpacing.lg),
                SectionHeader(
                    title: 'When to seek help',
                    icon: Symbols.emergency_rounded,
                    accent: ext.warning),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  color: ext.warning.container,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final item in condition.whenToSeekHelp)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Symbols.warning_amber_rounded,
                                  size: 16, color: ext.warning.onContainer),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(item,
                                    style: tt.bodyMedium?.copyWith(
                                        color: ext.warning.onContainer,
                                        height: 1.35)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const SafetyDisclaimerBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bulletSection(
    AppColorsExt ext,
    TextTheme tt, {
    required String title,
    required IconData icon,
    required AccentSwatch accent,
    required List<String> items,
    required IconData bulletIcon,
    required Color bulletColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, icon: icon, accent: accent),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(bulletIcon, size: 14, color: bulletColor),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(item,
                            style: tt.bodyMedium
                                ?.copyWith(color: ext.textPrimary, height: 1.35)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final ConditionCategory category;
  final AccentSwatch accent;
  const _CategoryChip({required this.category, required this.accent});

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ext.mark(accent).withOpacity(0.12),
        borderRadius: AppRadius.brFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(category.icon, size: 14, color: ext.mark(accent)),
          const SizedBox(width: 6),
          Text(category.label,
              style: tt.labelMedium
                  ?.copyWith(color: ext.mark(accent), fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
