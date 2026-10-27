import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import '../../../core/widgets/confirmation_bottom_sheet.dart';
import '../models/custom_tag.dart';
import '../services/tag_service.dart';
import '../services/focus_service.dart';

class CustomTagsScreen extends StatefulWidget {
  const CustomTagsScreen({super.key});

  @override
  State<CustomTagsScreen> createState() => _CustomTagsScreenState();
}

class _CustomTagsScreenState extends State<CustomTagsScreen> {

  /// Tag colours are user-chosen and persisted, so we lighten them for
  /// FOREGROUND use in dark mode rather than rewriting stored data. Deep hues
  /// otherwise fail badly against the dark chip — Meditation's brown
  /// (#795548) measured 2.65:1 and Reading's purple (#9C27B0) 2.80:1.
  Color _readableTagColor(BuildContext context, Color c) {
    if (Theme.of(context).brightness != Brightness.dark) return c;
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness(math.max(hsl.lightness, 0.7)).toColor();
  }
  final TagService _tagService = TagService();
  final FocusService _focusService = FocusService();

  @override
  void initState() {
    super.initState();
    _tagService.init();
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    // The header was a flat pinned SliverAppBar with a boxed 20pt arrow and a
    // raw `TextStyle(fontWeight: bold)` title — a fifth header grammar, and one
    // of the two screens still styling chrome through the legacy `AppColors`
    // shim. Converted to the pattern 51 other screens already use: a fixed
    // AppHeader above the sliver body, which keeps the pinned behaviour it had.
    return AppScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppHeader(
            title: 'Focus tags',
            leading: AppHeader.backButton(context),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: _tagService,
              builder: (context, _) {
                return CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(24),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildTagStats(),
                          const SizedBox(height: 24),
                          _buildTagsSection(
                              'Default Tags', _tagService.defaultTags),
                          const SizedBox(height: 24),
                          _buildTagsSection(
                              'Custom Tags', _tagService.customTags),
                          const SizedBox(height: 24),
                          _buildTagStatistics(),
                          // Was a magic SizedBox(height: 100) — a tab-root
                          // constant on a pushed screen, and it never added the
                          // gesture-bar inset.
                          SizedBox(height: AppInsets.pushed(context)),
                        ]),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      // AppFab, not a raw FloatingActionButton.extended: the raw one re-declared
      // the fill pair by hand and lost `heroTag: null` (the multiple-heroes
      // guard), the brLg shape, labelLarge text and the medium-impact haptic. It
      // also read brand-teal on a Focus screen; the accent is the feature's.
      floatingActionButton: AppFab(
        icon: Symbols.add_rounded,
        label: 'Create tag',
        accent: ext.focus,
        onPressed: _showCreateTagSheet,
      ),
    );
  }

  Widget _buildTagStats() {
    final tags = _tagService.tags;
    final customCount = _tagService.customTags.length;
    final totalUsage = tags.fold(0, (sum, t) => sum + t.usageCount);

    final ext = AppColorsExt.of(context);
    final fg = ext.fillFg(ext.focus);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        // Was a hardcoded #9C27B0 → #7B1FA2 gradient with white labels: not a
        // contrast defect (6.30:1) but a hue that exists nowhere in the palette,
        // on a Focus screen whose accent is violet. The fill pair is the
        // measured one — 5.70:1 light, 5.60:1 dark.
        color: ext.fillBg(ext.focus),
        borderRadius: AppRadius.brCard,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Each stat takes an equal share so the 3-up row can never run past
          // the card edge on a narrow phone or at large text sizes.
          Expanded(child: _buildStatItem(Symbols.label_rounded, '${tags.length}', 'Total Tags')),
          Container(width: 1, height: 50, color: fg.withOpacity(0.4)),
          Expanded(child: _buildStatItem(Symbols.auto_awesome_rounded, '$customCount', 'Custom')),
          Container(width: 1, height: 50, color: fg.withOpacity(0.4)),
          Expanded(child: _buildStatItem(Symbols.insights_rounded, '$totalUsage', 'Total Uses')),
        ],
      ),
    );
  }

  /// Takes an [IconData]: this is chrome, in a coloured header.
  ///
  /// The tag emoji further down the screen stay as they are — those are the
  /// user's own choice, persisted, and the whole point of the picker.
  Widget _buildStatItem(IconData icon, String value, String label) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final fg = ext.fillFg(ext.focus);
    return Column(
      children: [
        Icon(icon, size: 22, color: fg),
        const SizedBox(height: AppSpacing.sm),
        // scaleDown never enlarges, so the default rendering is unchanged and
        // only genuinely-too-wide values shrink to fit their column.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            softWrap: false,
            style: tt.displaySmall?.copyWith(color: fg),
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: tt.bodySmall?.copyWith(color: fg),
          ),
        ),
      ],
    );
  }

  Widget _buildTagsSection(String title, List<FocusTag> tags) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Flexible(
              child: Text(
                '${tags.length} tags',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColorsExt.of(context).textSecondary,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (tags.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColorsExt.of(context).surface,
              borderRadius: AppRadius.brCard,
            ),
            child: Center(
              child: Text(
                title == 'Custom Tags'
                    ? 'Create your first custom tag'
                    : 'No tags available',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColorsExt.of(context).textSecondary,
                    ),
              ),
            ),
          )
        else
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: tags.map((tag) => _buildTagChip(tag)).toList(),
          ),
      ],
    );
  }

  Widget _buildTagChip(FocusTag tag) {
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: () => _showTagDetails(tag),
      onLongPress: tag.isDefault ? null : () => _showDeleteConfirmation(tag),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: tag.color.withOpacity(0.1),
          borderRadius: AppRadius.brLg,
          border: Border.all(color: tag.color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tag.emoji != null) ...[
              // emoji-content-ok: the user's own persisted choice from the picker
              Text(tag.emoji!, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: AppSpacing.sm),
            ],
            // The chip lives in a Wrap, so its width is bounded by the row.
            // Flexible lets a long tag name ellipsize instead of pushing the
            // emoji and usage badge past the chip's right edge at large text.
            Flexible(
              child: Text(
                tag.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.labelLarge?.copyWith(
                  color: _readableTagColor(context, tag.color),
                ),
              ),
            ),
            if (tag.usageCount > 0) ...[
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                decoration: BoxDecoration(
                  color: tag.color.withOpacity(0.2),
                  borderRadius: AppRadius.brSm,
                ),
                child: Text(
                  '${tag.usageCount}',
                  style: tt.labelSmall?.copyWith(
                    color: _readableTagColor(context, tag.color),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTagStatistics() {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final stats = _tagService.calculateTagStatistics(_focusService.sessions);

    if (stats.isEmpty) {
      return const SizedBox();
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      decoration: BoxDecoration(
        color: ext.surface,
        borderRadius: AppRadius.brSheet,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tag Usage Statistics', style: tt.headlineSmall),
          const SizedBox(height: AppSpacing.lg),
          ...stats.take(5).map((stat) {
            final maxMins = stats.first.totalMinutes;
            final percentage = maxMins > 0 ? stat.totalMinutes / maxMins : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: stat.tagColor.withOpacity(0.1),
                          borderRadius: AppRadius.brSm,
                        ),
                        child: Center(
                          // emoji-content-ok: the tag's own persisted glyph
                          child: Text(
                            _tagService.getTagById(stat.tagId)?.emoji ?? '🏷️',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stat.tagName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.titleSmall,
                            ),
                            Text(
                              '${stat.sessionCount} sessions',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.bodySmall
                                  ?.copyWith(color: ext.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      // Trailing totals share the row instead of running off the
                      // card: they shrink and ellipsize at large text sizes.
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${stat.totalHours}h ${stat.totalMinutes % 60}m',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              // Same reason as the chip label: a persisted tag
                              // hue can be #CDDC39, which measures 1.55:1 as
                              // text on the card.
                              style: tt.labelLarge?.copyWith(
                                color: _readableTagColor(context, stat.tagColor),
                              ),
                            ),
                            Text(
                              'avg ${stat.averageSessionMinutes.toStringAsFixed(0)}m',
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
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ClipRRect(
                    borderRadius: AppRadius.brSm,
                    child: LinearProgressIndicator(
                      value: percentage,
                      backgroundColor: ext.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation(stat.tagColor),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Create-tag sheet, routed through [AppBottomSheet].
  ///
  /// The hand-rolled version set `backgroundColor: transparent`, drew its own
  /// 28pt top corners (the theme's `topSheet` is 24) and its own grab handle in
  /// `Colors.grey.shade300` — which measures **1.32:1** on the light surface,
  /// i.e. invisible, and 3.6:1 on the dark one, i.e. a bright bar where the
  /// theme's `dragHandleColor` is a quiet one. AppBottomSheet owns all three,
  /// plus the keyboard inset and the Material that lets rows ink.
  void _showCreateTagSheet() {
    Color selectedColor = FocusTag.availableColors.first;
    String? selectedEmoji;

    AppBottomSheet.show(
      context,
      title: 'Create Custom Tag',
      icon: Symbols.label_rounded,
      accent: AppColorsExt.of(context).focus,
      builder: (sheetContext) => _WithTextController(
       builder: (sheetContext, nameController) => StatefulBuilder(
        builder: (sheetContext, setModalState) {
          final ext = AppColorsExt.of(sheetContext);
          final tt = Theme.of(sheetContext).textTheme;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Tag Name',
                  hintText: 'e.g., Deep Work',
                  border: OutlineInputBorder(borderRadius: AppRadius.brMd),
                ),
              ),
              const SizedBox(height: AppSpacing.gutter),
              Text('Color', style: tt.titleSmall),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: FocusTag.availableColors.map((color) {
                  final isSelected = selectedColor == color;
                  return Semantics(
                    button: true,
                    selected: isSelected,
                    label: 'Tag colour',
                    child: GestureDetector(
                      onTap: () => setModalState(() => selectedColor = color),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: ext.textPrimary, width: 3)
                              : null,
                        ),
                        // The tick sits on twelve different user hues — some of
                        // them #CDDC39 — so it takes the ring colour, which is
                        // `textPrimary` against the app's own text contrast,
                        // rather than a fixed white at 1.55:1.
                        child: isSelected
                            ? Icon(Symbols.check_rounded,
                                color: ext.textPrimary, size: 20)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.gutter),
              Text('Emoji (Optional)', style: tt.titleSmall),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: FocusTag.availableEmojis.map((emoji) {
                  final isSelected = selectedEmoji == emoji;
                  return GestureDetector(
                    onTap: () => setModalState(() {
                      selectedEmoji = isSelected ? null : emoji;
                    }),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? selectedColor.withOpacity(0.2)
                            : ext.surfaceVariant,
                        borderRadius: AppRadius.brMd,
                        border: isSelected
                            ? Border.all(color: selectedColor, width: 2)
                            : null,
                      ),
                      child: Center(
                        // emoji-content-ok: this IS the picker — the glyph the
                        // user is choosing and the app persists
                        child: Text(emoji, style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Create tag',
                fullWidth: true,
                accent: ext.focus,
                onPressed: () async {
                  if (nameController.text.isEmpty) return;

                  await _tagService.createTag(
                    name: nameController.text,
                    colorValue: selectedColor.value,
                    emoji: selectedEmoji,
                  );

                  if (mounted) Navigator.pop(sheetContext);
                },
              ),
            ],
          );
        },
       ),
      ),
    );
  }

  void _showTagDetails(FocusTag tag) {
    AppBottomSheet.show(
      context,
      accent: AppColorsExt.of(context).focus,
      builder: (sheetContext) {
        final ext = AppColorsExt.of(sheetContext);
        final tt = Theme.of(sheetContext).textTheme;
        final tagFg = _readableTagColor(sheetContext, tag.color);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: tag.color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(tag.emoji ?? '🏷️', // emoji-content-ok: the tag's own persisted glyph
                    style: const TextStyle(fontSize: 36)),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              tag.name,
              textAlign: TextAlign.center,
              style: tt.displaySmall?.copyWith(color: tagFg),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text('${tag.usageCount}',
                        style: tt.displayMedium?.copyWith(color: tagFg)),
                    Text('Times Used',
                        style:
                            tt.bodySmall?.copyWith(color: ext.textSecondary)),
                  ],
                ),
                Column(
                  children: [
                    Text(tag.isDefault ? 'Default' : 'Custom',
                        style: tt.headlineSmall?.copyWith(color: tagFg)),
                    Text('Type',
                        style:
                            tt.bodySmall?.copyWith(color: ext.textSecondary)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Rename',
              leadingIcon: Symbols.edit_rounded,
              variant: AppButtonVariant.tonal,
              accent: ext.focus,
              fullWidth: true,
              onPressed: () {
                Navigator.pop(sheetContext);
                _showRenameSheet(tag);
              },
            ),
          ],
        );
      },
    );
  }

  /// Rename a tag. Stays open with the reason when the name cannot be used, so
  /// what was typed is not lost.
  void _showRenameSheet(FocusTag tag) {
    AppBottomSheet.show(
      context,
      title: 'Rename tag',
      icon: Symbols.edit_rounded,
      accent: AppColorsExt.of(context).focus,
      builder: (sheetContext) => _RenameTagForm(
        initial: tag.name,
        rename: (name) => _tagService.renameTag(tag.id, name),
        onDone: () => Navigator.pop(sheetContext),
      ),
    );
  }

  /// Tag deletion, asked in the app's one confirmation grammar.
  ///
  /// This was a raw [AlertDialog] — the second way this app had of asking a
  /// question, on the screen whose only destructive action it guarded.
  /// `showDelete` is the same question: `itemName: 'Tag'` reproduces the
  /// "Delete Tag?" title verbatim and `customMessage` keeps the tag's own name
  /// in the body, where the generic copy would have dropped it. Cancel stays on
  /// the left, the destructive button on the right, and the dialog was
  /// barrier-dismissible, so the sheet's dismissal matches it.
  ///
  /// No `mounted` gate between the answer and the delete: nothing after the
  /// await touches a [BuildContext], and gating a confirmed destructive action
  /// on the screen still being alive is how a "yes" silently becomes a no-op.
  Future<void> _showDeleteConfirmation(FocusTag tag) async {
    final confirmed = await ConfirmationBottomSheet.showDelete(
      context: context,
      itemName: 'Tag',
      customMessage: 'Are you sure you want to delete "${tag.name}"?',
    );
    if (confirmed != true) return;
    await _tagService.deleteTag(tag.id);
  }
}

/// A text controller owned by a sheet's own State.
///
/// Both tag sheets used to create the controller in the caller and dispose it in
/// `whenComplete`, which runs the moment the sheet is popped — before its exit
/// animation has finished. The `TextField` was still in the tree for those
/// frames, and "A TextEditingController was used after being disposed" followed.
/// A State disposes at unmount, which is after the transition.
class _WithTextController extends StatefulWidget {
  const _WithTextController({required this.builder});

  final Widget Function(BuildContext context, TextEditingController controller)
      builder;

  @override
  State<_WithTextController> createState() => _WithTextControllerState();
}

class _WithTextControllerState extends State<_WithTextController> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controller);
}

/// The rename sheet's form. Its own State holds the controller (see
/// [_WithTextController] for why) and the reason a name was refused, so neither
/// is lost when the sheet rebuilds around a keyboard.
class _RenameTagForm extends StatefulWidget {
  const _RenameTagForm(
      {required this.initial, required this.rename, required this.onDone});

  final String initial;
  final Future<TagRename> Function(String name) rename;
  final VoidCallback onDone;

  @override
  State<_RenameTagForm> createState() => _RenameTagFormState();
}

class _RenameTagFormState extends State<_RenameTagForm> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final result = await widget.rename(_controller.text);
    if (!mounted) return;
    switch (result) {
      case TagRename.renamed:
      case TagRename.unchanged:
      case TagRename.notFound:
        widget.onDone();
      case TagRename.empty:
        setState(() => _error = 'Give the tag a name.');
      case TagRename.duplicate:
        setState(() => _error = 'You already have a tag with that name.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _save(),
          decoration: InputDecoration(
            labelText: 'Tag Name',
            errorText: _error,
            border: const OutlineInputBorder(borderRadius: AppRadius.brMd),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: 'Save',
          fullWidth: true,
          accent: ext.focus,
          onPressed: _save,
        ),
      ],
    );
  }
}
