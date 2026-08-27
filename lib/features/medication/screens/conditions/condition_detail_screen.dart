import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../../core/design/app_design.dart';
import '../../../../core/design/app_colors_ext.dart';
import '../../../../core/widgets/app/app_widgets.dart';
import '../../../../core/widgets/app/insight_kit.dart' show SafetyDisclaimerBar;
import '../../../../core/utils/relative_time.dart';
import '../../models/condition_info.dart';
import '../../services/condition_library_service.dart';
import '../nunito_medication_detail_screen.dart';

/// Detail view for one [ConditionInfo] — overview, common symptoms, self-care
/// tips, and red-flag symptoms. General education only; see
/// [ConditionInfo]'s doc and the persistent [SafetyDisclaimerBar] at the foot
/// of this screen.
class ConditionDetailScreen extends StatefulWidget {
  final ConditionInfo condition;
  const ConditionDetailScreen({super.key, required this.condition});

  @override
  State<ConditionDetailScreen> createState() => _ConditionDetailScreenState();
}

class _ConditionDetailScreenState extends State<ConditionDetailScreen> {
  /// Null until loaded — so both personalised sections are ABSENT rather than
  /// empty on the first frame. A "Your medicines in this area" heading over
  /// nothing reads as a bug.
  ConditionLibraryPersonalisation? _personal;
  ConditionReadings? _readings;

  ConditionInfo get condition => widget.condition;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await ConditionLibraryService.load();
    if (!mounted) return;
    setState(() => _personal = p);

    // The second select of the 1-3 contract, and only for the two conditions
    // that have an objective measurement. Twelve of the fourteen pages never
    // ask.
    final r = await ConditionLibraryService.readingsFor(condition.id);
    if (mounted) setState(() => _readings = r);
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final accent = ext.medicine;
    final tt = Theme.of(context).textTheme;

    return AppScaffold(
      body: Column(
        children: [
          AppHeader(
            title: condition.name,
            leading: AppHeader.backButton(context),
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
                ..._yourMedicines(context, ext, tt, accent),
                ..._yourReadings(context, ext, tt, accent),
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

  // ------------------------------------------- Your medicines in this area

  /// The heading is the safety design, not decoration.
  ///
  /// *"Your medicines in this area"* — the subject is the medicine, the
  /// predicate is its drug family, and the condition is context the reader
  /// supplied by opening this page. Nothing here says the reader has anything.
  List<Widget> _yourMedicines(BuildContext context, AppColorsExt ext,
      TextTheme tt, AccentSwatch accent) {
    final links = _personal?.linksFor(condition.id) ?? const [];
    if (links.isEmpty) return const [];

    return [
      const SizedBox(height: AppSpacing.lg),
      SectionHeader(
          title: 'Your medicines in this area',
          icon: Symbols.medication_rounded,
          accent: accent),
      const SizedBox(height: AppSpacing.sm),
      AppListGroup(
        children: [
          for (final l in links)
            AppListTile(
              icon: Symbols.pill_rounded,
              iconColor: ext.mark(accent),
              title: l.medicineName,
              // The drug class, not a restatement of the condition.
              subtitle: l.drugClass ?? 'You noted this is for this area',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  // Deliberately NOT duplicating the monograph here: the
                  // medicine detail screen already renders all four paragraphs,
                  // and a second rendering is bloat plus a divergence risk.
                  builder: (_) =>
                      NunitoMedicationDetailScreen(medicine: l.medicine),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      // One chip carrying the reasoning for the strongest link on the page, so
      // the inference is inspectable rather than taken on trust.
      WhyThisChip(why: links.first.why),
    ];
  }

  // ------------------------------------------------ Your recent readings

  List<Widget> _yourReadings(BuildContext context, AppColorsExt ext,
      TextTheme tt, AccentSwatch accent) {
    final r = _readings;
    // Absent on the twelve pages with no objective measurement, and absent
    // while loading or after a failed read — null is not zero.
    if (r == null || !r.hasAny) return const [];

    return [
      const SizedBox(height: AppSpacing.lg),
      SectionHeader(
          title: 'Your recent readings',
          icon: Symbols.monitoring_rounded,
          accent: accent),
      const SizedBox(height: AppSpacing.sm),
      AppCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.latestValue ?? '—',
                      style: tt.headlineSmall?.copyWith(
                          color: ext.textPrimary,
                          fontWeight: FontWeight.w800)),
                  if (r.latestLabel != null)
                    Text(r.latestLabel!,
                        style:
                            tt.bodySmall?.copyWith(color: ext.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Flexible(
              child: Text(
                // A count belongs in text like this, not in a meter with an
                // invented denominator.
                '${r.count} in the last 90 days'
                '${r.latestAt == null ? '' : '\nLatest ${RelativeTime.since(r.latestAt!)}'}',
                textAlign: TextAlign.end,
                style: tt.bodySmall?.copyWith(color: ext.textTertiary),
              ),
            ),
          ],
        ),
      ),
    ];
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
