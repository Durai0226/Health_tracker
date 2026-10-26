import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/utils/date_formats.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../models/focus_plant.dart';
import '../services/focus_service.dart';
import '../../../core/utils/calendar_day.dart';
import 'package:clock/clock.dart';

class FocusGardenScreen extends StatelessWidget {
  const FocusGardenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final focusService = FocusService();
    
    return Scaffold(
      backgroundColor: AppColorsExt.of(context).background,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: focusService,
          builder: (context, _) {
            final garden = focusService.garden;
            final groupedByDate = _groupPlantsByDate(garden);
            
            return CustomScrollView(
              slivers: [
                _buildAppBar(context, garden),
                if (garden.isEmpty)
                  // hasScrollBody: false sizes the sliver to max(remaining
                  // space, the empty state's own height) instead of forcing it
                  // into the leftover viewport — at 200% text the illustration
                  // and copy are taller than what's left under the header, and
                  // the forced fit clipped them by 210px.
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(context),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final date = groupedByDate.keys.toList()[index];
                          final plants = groupedByDate[date]!;
                          return _buildDateSection(context, date, plants);
                        },
                        childCount: groupedByDate.length,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, List<FocusPlant> garden) {
    final alivePlants = garden.where((p) => p.isAlive).length;
    final deadPlants = garden.where((p) => !p.isAlive).length;

    // FlexibleSpaceBar always lays its background out at exactly `expandedHeight`,
    // so a flat 200 clipped the title block by 18px at 200% text. 104 of that
    // header is fixed chrome (60 + 24 padding and the 20 gap); the rest is text
    // and has to grow with the user's text size. At 1.0x this is still 200.
    final double expandedHeight =
        104 + MediaQuery.textScalerOf(context).scale(96);

    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      backgroundColor: AppColorsExt.of(context).background,
      leading: IconButton(
        // Announced as just "button" by TalkBack and VoiceOver without this.
        tooltip: 'Back',
        onPressed: () => Navigator.pop(context),
        icon: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColorsExt.of(context).surface,
            borderRadius: AppRadius.brMd,
          ),
          child: const Icon(Symbols.arrow_back_rounded, size: 20),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColorsExt.of(context).focus.container,
                AppColorsExt.of(context).background,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Chrome, so a Material Symbol. The PLANTS below keep
                      // their emoji — those are each species' identity and the
                      // whole point of a garden.
                      Icon(Symbols.park_rounded,
                          size: 40, color: AppColorsExt.of(context).mark(AppColorsExt.of(context).focus)),
                      const SizedBox(width: 16),
                      // Flexible so the title block shares the row instead of
                      // pushing past the right edge on narrow phones.
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'My Garden',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '$alivePlants alive • $deadPlants withered',
                              style: Theme.of(context).textTheme.bodyMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildGardenStats(context, garden),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGardenStats(BuildContext context, List<FocusPlant> garden) {
    final tt = Theme.of(context).textTheme;
    final plantCounts = <PlantType, int>{};
    for (final plant in garden.where((p) => p.isAlive)) {
      plantCounts[plant.type] = (plantCounts[plant.type] ?? 0) + 1;
    }
    
    if (plantCounts.isEmpty) return const SizedBox();
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: plantCounts.entries.map((entry) {
          return Container(
            margin: const EdgeInsets.only(right: AppSpacing.md),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: entry.key.primaryColor.withOpacity(0.15),
              borderRadius: AppRadius.brMd,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // emoji-content-ok: the plant species IS the garden metaphor
                Text(entry.key.emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Text(
                  '${entry.value}',
                  style: tt.labelLarge
                      ?.copyWith(color: AppColorsExt.of(context).textPrimary),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Map<DateTime, List<FocusPlant>> _groupPlantsByDate(List<FocusPlant> plants) {
    final Map<DateTime, List<FocusPlant>> grouped = {};
    for (final plant in plants.reversed) {
      final date = DateTime(
        plant.plantedAt.year,
        plant.plantedAt.month,
        plant.plantedAt.day,
      );
      grouped.putIfAbsent(date, () => []);
      grouped[date]!.add(plant);
    }
    
    // Sort by date descending
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (var key in sortedKeys) key: grouped[key]!};
  }

  Widget _buildDateSection(BuildContext context, DateTime date, List<FocusPlant> plants) {
    final isToday = _isToday(date);
    final isYesterday = _isYesterday(date);
    
    String dateLabel;
    if (isToday) {
      dateLabel = 'Today';
    } else if (isYesterday) {
      dateLabel = 'Yesterday';
    } else {
      // `weekdayDayMonthMedium` ("Monday, Sep 28"), not the Long form.
      //
      // The row below caps this at one line with an ellipsis so it cannot push
      // the minutes total off the right edge — which is right — but at the
      // DEFAULT text size on a 411dp phone "Monday, September 28" was already
      // too wide, so every day older than yesterday rendered as
      // "Monday, Septemb…" and lost the one thing the header is for.
      // Abbreviating the month keeps the date; ellipsising it did not.
      dateLabel = DateFormats.weekdayDayMonthMedium.format(date);
    }
    
    final totalMinutes = plants.fold(0, (sum, p) => sum + p.durationMinutes);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 'Wednesday, September 10' is the widest label this can hold; at
            // large text sizes it has to share the row with the total instead
            // of pushing it off the right edge.
            Expanded(
              child: Text(
                dateLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Flexible(
              child: Text(
                '$totalMinutes min',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColorsExt.of(context).textSecondary,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppListGroup(
          children: [
            for (final plant in plants) _buildPlantRow(context, plant),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  /// One session, as a full-width row on the house metrics.
  ///
  /// Was a `width: 100` tile in a `Wrap`. A session writes exactly one plant
  /// (`FocusService` appends one per completed or abandoned session), so a day
  /// section almost always held a single tile: 100pt of a 363pt content row,
  /// leaving 72% of the row blank under a full-width header. A `Wrap` with one
  /// fixed-width child is a `Row` with one child and no alignment.
  ///
  /// Every other per-session history in the app is already a full-width row —
  /// `steps_history_screen`, `sleep_history_screen`, `workouts_screen`, and
  /// both list tabs of Plant Trees. This follows `workouts_screen`'s anatomy
  /// (day eyebrow, then one card of rows) so the Garden stops being the only
  /// tile grid in `lib/`.
  ///
  /// The species tint moves onto the leading chip. `PlantType.primaryColor` is
  /// a raw light-mode Material hex with no dark variant, so it belongs at MARK
  /// scale — a 36pt chip — not washed across a card ground. The emoji is the
  /// only thing drawn on it, so the tint carries no text-contrast obligation.
  Widget _buildPlantRow(BuildContext context, FocusPlant plant) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final alive = plant.isAlive;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppRowMetrics.minHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppRowMetrics.horizontalPadding,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              width: AppRowMetrics.iconBox,
              height: AppRowMetrics.iconBox,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: alive
                    ? plant.type.primaryColor.withOpacity(ext.isDark ? 0.22 : 0.12)
                    : ext.surfaceVariant,
                borderRadius: AppRadius.brMd,
              ),
              child: Opacity(
                opacity: alive ? 1 : 0.5,
                child: Text(alive ? plant.type.emoji : '🥀', // emoji-content-ok: the species, or the withered marker that shares its slot
                    style: const TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: AppRowMetrics.iconGap),
            // The row has the whole width now, so the species name fits beside
            // the number instead of being left to the emoji alone.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alive ? plant.type.name : 'Given up',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleSmall?.copyWith(
                      color: alive ? ext.textPrimary : ext.textSecondary,
                    ),
                  ),
                  Text(
                    DateFormats.time.format(plant.plantedAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.labelSmall?.copyWith(
                      fontWeight: FontWeight.w400,
                      color: ext.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppRowMetrics.trailingGap),
            // Was `plant.type.primaryColor` as text: sakura's #F8BBD9 measures
            // 1.31:1 and sunflower's #FFC107 1.90:1 on the card. The species
            // reads from the emoji and the chip tint; the NUMBER has to be
            // legible.
            Text(
              '${plant.durationMinutes}m',
              maxLines: 1,
              style: tt.titleSmall?.copyWith(
                color: alive ? ext.textPrimary : ext.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// What a brand-new user meets here.
  ///
  /// Was a hand-rolled Column reading *"Your garden is empty / Complete focus
  /// sessions to grow plants!"* — which states an absence, blames the reader for
  /// it, and offers nothing to do about it. This screen is reached from the Focus
  /// screen, so the way forward is one tap back.
  ///
  /// Routed through the shared [EmptyState] on purpose: a hand-rolled empty state
  /// carries no action contract, so nothing can check that it offers a way out.
  /// The `dead-end-empty-state` gate in `focus_first_run_test.dart` requires the
  /// shared widget for exactly that reason.
  Widget _buildEmptyState(BuildContext context) {
    final ext = AppColorsExt.of(context);
    return EmptyState(
      icon: Symbols.potted_plant_rounded,
      title: 'Your garden grows as you focus',
      message: 'Every session you finish plants something here.',
      accent: ext.focus,
      action: AppButton(
        label: 'Start a session',
        leadingIcon: Symbols.play_arrow_rounded,
        // Explicit, like the EmptyState above it.
        //
        // `AppButton` falls back to `AccentScope.swatchOf(context)`, and this
        // screen is a pushed route — a child of the Navigator, not of the
        // widget that pushed it — so for a long time it resolved to `brand`
        // and this empty state drew a violet icon above a teal button, four
        // lines apart. `_buildPageRoute` now scopes the route, so this would
        // inherit `focus` anyway; it stays explicit because an empty state
        // that states its own accent cannot be broken again by how it is
        // opened, and `focus_routes_carry_the_accent_test` guards the route.
        accent: ext.focus,
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  bool _isYesterday(DateTime date) {
    // prevDay, not subtract(Duration(days: 1)): on a 23-hour spring-forward day
    // subtracting 24 hours lands back on the SAME calendar day, so "yesterday"
    // matched today and a plant planted yesterday read as planted today.
    final yesterday = prevDay(clock.now());
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }
}
