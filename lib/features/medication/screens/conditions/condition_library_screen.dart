import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../../core/design/app_design.dart';
import '../../../../core/design/app_colors_ext.dart';
import '../../../../core/widgets/app/app_widgets.dart';
import '../../../../core/widgets/app/insight_kit.dart' show SafetyDisclaimerBar;
import '../../data/condition_library_data.dart';
import '../../models/condition_info.dart';
import 'condition_detail_screen.dart';

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final accent = ext.medicine;
    final tt = Theme.of(context).textTheme;
    final query = _query.trim().toLowerCase();

    final byCategory = <ConditionCategory, List<ConditionInfo>>{};
    for (final c in conditionLibrary) {
      if (!c.matches(query)) continue;
      (byCategory[c.category] ??= []).add(c);
    }
    final hasResults = byCategory.isNotEmpty;

    return AppScaffold(
      safeTop: true,
      body: Column(
        children: [
          AppHeader(
            title: 'Condition library',
            icon: Symbols.menu_book_rounded,
            accent: accent,
            leading: AppIconButton(
              icon: Symbols.arrow_back_rounded,
              filled: false,
              accent: accent,
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter, AppSpacing.md, AppSpacing.gutter, 0),
            child: AppTextField(
              controller: _searchController,
              hint: 'Search conditions',
              prefixIcon: Symbols.search_rounded,
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
                      for (final category in ConditionCategory.values)
                        if (byCategory[category]?.isNotEmpty ?? false) ...[
                          SectionHeader(
                              title: category.label,
                              icon: category.icon,
                              accent: accent),
                          const SizedBox(height: AppSpacing.sm),
                          AppCard(
                            padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.xs),
                            child: Column(
                              children: _withDividers(
                                ext,
                                byCategory[category]!
                                    .map((c) => _row(context, ext, tt, accent, c))
                                    .toList(),
                              ),
                            ),
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
      AccentSwatch accent, ConditionInfo c) {
    return AppListTile(
      icon: c.category.icon,
      iconColor: ext.mark(accent),
      title: c.name,
      subtitle: c.overview,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ConditionDetailScreen(condition: c)),
      ),
    );
  }

  List<Widget> _withDividers(AppColorsExt ext, List<Widget> tiles) {
    final out = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      out.add(tiles[i]);
      if (i < tiles.length - 1) {
        out.add(Divider(height: 1, indent: 52, endIndent: 8, color: ext.outline));
      }
    }
    return out;
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
