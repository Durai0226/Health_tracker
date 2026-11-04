import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../models/beverage_type.dart';
import '../models/custom_drink.dart';
import '../services/water_service.dart';
import '../theme/aqua_theme.dart';

/// Make a drink of your own, or change one you made.
///
/// Pops with the drink's id once it is saved, so the caller can select it.
class CustomDrinkScreen extends StatefulWidget {
  /// The drink being edited; null makes a new one.
  final BeverageType? existing;

  const CustomDrinkScreen({super.key, this.existing});

  @override
  State<CustomDrinkScreen> createState() => _CustomDrinkScreenState();
}

class _CustomDrinkScreenState extends State<CustomDrinkScreen> {
  final _nameController = TextEditingController();

  /// Shown under the name once a save has been tried, and cleared as soon as the
  /// name is touched, so it never lingers over a name that has been fixed.
  String? _nameError;
  late Color _color;

  /// What the drink had when the screen opened, so a value the form's own choices do
  /// not include stays on offer after something else is picked.
  late Color _originalColor;
  late int _originalCountsAs;
  late int _countsAs;
  late bool _hasCaffeine;
  late int _caffeineMg;
  bool _saving = false;

  /// Caffeine strengths worth naming, in mg per 100 ml. What a person knows about
  /// their drink is "about as strong as tea", not a number of milligrams.
  static const List<(int, String)> _caffeineSteps = [
    (20, 'Light · tea'),
    (40, 'Medium · coffee'),
    (80, 'Strong'),
    (200, 'Very strong · espresso'),
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameController.text = e?.name ?? '';
    _color = e == null
        ? AquaTheme.pickerColors.first
        : AquaTheme.colorFromHex(e.colorHex);
    _countsAs = e?.hydrationPercent ?? 100;
    _originalColor = _color;
    _originalCountsAs = _countsAs;
    _hasCaffeine = e?.hasCaffeine ?? false;
    _caffeineMg = (e != null && e.hasCaffeine && e.caffeinePerMl > 0)
        ? e.caffeinePerMl
        : CustomDrink.defaultCaffeineMg;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String get _colorHex =>
      '#${_color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

  /// What the form says right now, as the drink it would save. The id is the real
  /// one when editing and a placeholder while a new drink is being previewed.
  BeverageType get _draft {
    final existing = widget.existing;
    final caffeine = _hasCaffeine ? _caffeineMg : 0;
    return existing != null
        ? CustomDrink.edited(existing,
            name: _nameController.text,
            colorHex: _colorHex,
            countsAsPercent: _countsAs,
            caffeineMg: caffeine)
        : CustomDrink.build(
            id: '${CustomDrink.idPrefix}preview',
            name: _nameController.text,
            colorHex: _colorHex,
            countsAsPercent: _countsAs,
            caffeineMg: caffeine,
          );
  }

  Future<void> _save() async {
    if (_saving) return;
    final all = WaterService.getAllBeverages();
    final error = CustomDrink.nameError(_nameController.text, all,
        editingId: widget.existing?.id);
    if (error != null) {
      setState(() => _nameError = error);
      return;
    }
    setState(() => _saving = true);
    try {
      final existing = widget.existing;
      final caffeine = _hasCaffeine ? _caffeineMg : 0;
      final drink = existing != null
          ? CustomDrink.edited(existing,
              name: _nameController.text,
              colorHex: _colorHex,
              countsAsPercent: _countsAs,
              caffeineMg: caffeine)
          : CustomDrink.build(
              // Not an id that is in use, and not one that only the log
              // remembers: a drink that was deleted has logs under its id, and a
              // new drink under it would be read as the same one.
              id: CustomDrink.newId(_nameController.text,
                  {...all.map((b) => b.id), ...WaterService.loggedBeverageIds()}),
              name: _nameController.text,
              colorHex: _colorHex,
              countsAsPercent: _countsAs,
              caffeineMg: caffeine,
            );
      if (existing == null) {
        await WaterService.addCustomBeverage(drink);
      } else {
        await WaterService.updateCustomBeverage(drink);
      }
      if (!mounted) return;
      context.toastSuccess(
          existing == null ? 'Added ${drink.name}' : 'Saved ${drink.name}');
      Navigator.pop(context, drink.id);
    } catch (e) {
      debugPrint('Saving a custom drink failed: $e');
      if (mounted) context.toastError('Could not save the drink. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final water = ext.water;
    final isEditing = widget.existing != null;

    return AppScaffold(
      body: Column(
        children: [
          AppHeader(
            title: isEditing ? 'Edit Drink' : 'New Drink',
            leading: AppIconButton(
              icon: Symbols.close_rounded,
              accent: water,
              filled: false,
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              AppButton(
                label: 'Save',
                accent: water,
                size: AppButtonSize.sm,
                loading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                  AppSpacing.sm, AppSpacing.gutter, AppSpacing.huge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPreview(ext),
                  const SizedBox(height: AppSpacing.xl),
                  _buildNameCard(water),
                  const SizedBox(height: AppSpacing.lg),
                  _buildCountsCard(ext, water),
                  const SizedBox(height: AppSpacing.lg),
                  _buildCaffeineCard(ext, water),
                  const SizedBox(height: AppSpacing.lg),
                  _buildColorCard(ext, water),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: isEditing ? 'Save Changes' : 'Add Drink',
                    accent: water,
                    size: AppButtonSize.lg,
                    fullWidth: true,
                    loading: _saving,
                    leadingIcon: Symbols.check_rounded,
                    onPressed: _saving ? null : _save,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(AppColorsExt ext) {
    final tt = Theme.of(context).textTheme;
    final draft = _draft;
    return Center(
      child: AppCard(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl, vertical: AppSpacing.xl),
        child: Column(
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.12),
                borderRadius: AppRadius.brLg,
                border: Border.all(color: _color, width: 2),
              ),
              child: Center(
                child: Icon(AquaTheme.iconFor(draft.id),
                    size: 40, color: _color, applyTextScaling: false),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              draft.name.isEmpty ? 'Drink name' : draft.name,
              style: tt.headlineSmall?.copyWith(color: ext.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              CustomDrink.summary(draft),
              style: tt.bodySmall?.copyWith(color: ext.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameCard(AccentSwatch water) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Name',
            icon: Symbols.edit_note_rounded,
            accent: water,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: _nameController,
            label: 'Drink name',
            hint: 'e.g. Protein shake',
            prefixIcon: Symbols.local_drink_rounded,
            accent: water,
            textCapitalization: TextCapitalization.sentences,
            errorText: _nameError,
            onChanged: (_) => setState(() => _nameError = null),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
    );
  }

  Widget _buildCountsCard(AppColorsExt ext, AccentSwatch water) {
    final tt = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Counts toward your goal',
            icon: Symbols.water_drop_rounded,
            accent: water,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              // The steps, and the drink's own value when it is not one of them (a
              // drink an earlier version made, or one restored from a file): shown
              // and selected, not silently kept behind a form that looks unset.
              for (final p in ({...CustomDrink.countsAsChoices, _originalCountsAs}.toList()
                    ..sort((a, b) => b.compareTo(a))))
                AppChip(
                  label: p >= 100 ? 'In full' : '$p%',
                  selected: _countsAs == p,
                  accent: water,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _countsAs = p);
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Most drinks count in full. Pick less for something that is only '
            'partly water, like a thick smoothie.',
            style: tt.bodySmall?.copyWith(color: ext.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildCaffeineCard(AppColorsExt ext, AccentSwatch water) {
    final tt = Theme.of(context).textTheme;
    final steps = {..._caffeineSteps.map((s) => s.$1), _caffeineMg}.toList()
      ..sort();
    String label(int mg) {
      for (final s in _caffeineSteps) {
        if (s.$1 == mg) return s.$2;
      }
      return '$mg mg';
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Contains caffeine',
                        style:
                            tt.titleMedium?.copyWith(color: ext.textPrimary)),
                    const SizedBox(height: 2),
                    Text('Adds to the day\'s caffeine total',
                        style:
                            tt.bodySmall?.copyWith(color: ext.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: AppRowMetrics.trailingGap),
              AppSwitch(
                value: _hasCaffeine,
                onChanged: (v) => setState(() => _hasCaffeine = v),
                accent: water,
              ),
            ],
          ),
          if (_hasCaffeine) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final mg in steps)
                  AppChip(
                    label: label(mg),
                    selected: _caffeineMg == mg,
                    accent: water,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _caffeineMg = mg);
                    },
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Milligrams of caffeine in every 100 ml.',
              style: tt.bodySmall?.copyWith(color: ext.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildColorCard(AppColorsExt ext, AccentSwatch water) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Color',
            icon: Symbols.palette_rounded,
            accent: water,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              for (final (i, color) in [
                // The drink's own colour first when it is not one of the accents
                // (an older drink, or one restored from a file), so it shows as
                // selected instead of the form looking as if none were chosen.
                if (!AquaTheme.pickerColors.contains(_originalColor)) _originalColor,
                ...AquaTheme.pickerColors,
              ].indexed)
                Semantics(
                  button: true,
                  selected: color == _color,
                  label: 'Color ${i + 1}',
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _color = color);
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color == _color
                              ? ext.textPrimary
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: color == _color
                          ? Icon(Symbols.check_rounded,
                              color: AquaTheme.onBeverage(color), size: 22)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
