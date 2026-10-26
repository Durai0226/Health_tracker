import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../../core/design/app_design.dart';
import '../../../../core/design/app_colors_ext.dart';
import '../../../../core/widgets/app/app_widgets.dart';
import '../../../../core/widgets/app/insight_kit.dart' show SafetyDisclaimerBar;
import '../../../../core/health/drug_info_catalog.dart';
import '../../models/condition_info.dart';
import '../../services/condition_library_service.dart';
import '../../services/condition_search_index.dart';
import '../../services/medicine_storage_service.dart';
import 'condition_detail_screen.dart';
import '../../../../core/services/active_profile_service.dart';

/// Browsable, searchable library of common-condition reference entries —
/// general education only (see [ConditionInfo]'s doc). Grouped by category;
/// searching filters within each group and hides empty ones.
class ConditionLibraryScreen extends StatefulWidget {
  const ConditionLibraryScreen({super.key});

  @override
  State<ConditionLibraryScreen> createState() => _ConditionLibraryScreenState();
}

class _ConditionLibraryScreenState extends State<ConditionLibraryScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  /// Null until the medicine read completes — so the pinned sliver is ABSENT
  /// rather than empty on the first frame. An empty "Related to what you
  /// track" box is a worse answer than no box.
  ConditionLibraryPersonalisation? _personal;

  @override
  void initState() {
    super.initState();
    _buildIndex();
    _loadPersonalisation();
    // Adding a medicine should change what is pinned here without a restart.
    MedicineCleanStorageService.revision.addListener(_loadPersonalisation);
    // Switching to a family member changes the list without writing a medicine.
    ActiveProfileService().addListener(_loadPersonalisation);
  }

  @override
  void dispose() {
    MedicineCleanStorageService.revision.removeListener(_loadPersonalisation);
    ActiveProfileService().removeListener(_loadPersonalisation);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _buildIndex() async {
    if (ConditionSearchIndex.isBuilt) return;
    try {
      await DrugInfoCatalog.ensureLoaded();
      ConditionSearchIndex.build(
        genericsForCondition: () => ConditionSearchIndex.drugTermsFrom(
            DrugInfoCatalog.all.map((d) => (generic: d.generic, klass: d.klass))),
      );
    } catch (_) {
      // Search degrades to name-and-aliases rather than to nothing — see
      // ConditionSearchIndex.search's fallback.
      ConditionSearchIndex.build();
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadPersonalisation() async {
    final p = await ConditionLibraryService.load();
    if (mounted) setState(() => _personal = p);
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final accent = ext.medicine;
    final tt = Theme.of(context).textTheme;
    final query = _query.trim().toLowerCase();

    // Ranked, and widened past name-and-aliases: "chest pain", "swelling" and
    // "statin" all returned the empty state before this.
    final hits = ConditionSearchIndex.search(query);
    final byCategory = <ConditionCategory, List<ConditionInfo>>{};
    for (final h in hits) {
      (byCategory[h.condition.category] ??= []).add(h.condition);
    }
    final hasResults = byCategory.isNotEmpty;

    // The pinned sliver shows only while browsing. During a search the user has
    // told us what they want, and a "related to you" block above their results
    // is in the way.
    final related = query.isEmpty
        ? (_personal?.relatedConditions ?? const <ConditionInfo>[])
        : const <ConditionInfo>[];

    return AppScaffold(
      body: Column(
        children: [
          AppHeader(
            title: 'Condition library',
            leading: AppHeader.backButton(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter, AppSpacing.md, AppSpacing.gutter, 0),
            child: AppSearchField(
              controller: _searchController,
              hint: 'Search conditions',
              accent: accent,
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: !hasResults
                ? _NoResults(query: query)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                        AppSpacing.lg, AppSpacing.gutter, AppSpacing.xl),
                    children: [
                      if (related.isNotEmpty) ...[
                        SectionHeader(
                            title: 'Related to what you track',
                            icon: Symbols.medication_rounded,
                            accent: accent),
                        const SizedBox(height: AppSpacing.sm),
                        AppListGroup(
                          children: [
                            for (final c in related)
                              _row(context, ext, tt, accent, c,
                                  trailingCount:
                                      _personal!.linksFor(c.id).length),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      for (final category in ConditionCategory.values)
                        if (byCategory[category]?.isNotEmpty ?? false) ...[
                          SectionHeader(
                              title: category.label,
                              icon: category.icon,
                              accent: accent),
                          const SizedBox(height: AppSpacing.sm),
                          AppListGroup(
                            children: byCategory[category]!
                                .map((c) => _row(context, ext, tt, accent, c))
                                .toList(),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                      const SafetyDisclaimerBar(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, AppColorsExt ext, TextTheme tt,
      AccentSwatch accent, ConditionInfo c, {int? trailingCount}) {
    return AppListTile(
      icon: c.category.icon,
      iconColor: ext.mark(accent),
      title: c.name,
      // In the pinned sliver the useful subtitle is the connection, not the
      // encyclopedia blurb the reader can get by tapping through.
      subtitle: trailingCount == null
          ? c.overview
          : '$trailingCount of your medicines ${trailingCount == 1 ? 'relates' : 'relate'} to this area',
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ConditionDetailScreen(condition: c)),
      ),
    );
  }

}

class _NoResults extends StatelessWidget {
  final String query;
  const _NoResults({required this.query});

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.search_off_rounded, size: 40, color: ext.textTertiary),
            const SizedBox(height: AppSpacing.md),
            Text('No conditions match "$query"',
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
          ],
        ),
      ),
    );
  }
}
