import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart' as db;
import '../../../core/services/clean_storage_service.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../models/reminder_category_model.dart';

/// Manage reminder categories — real Drift-backed list with create / edit /
/// swipe-to-delete. Calm Clarity, dark-aware.
class CategoryManagementScreen extends StatelessWidget {
  const CategoryManagementScreen({super.key});

  ReminderCategory _toModel(db.ReminderCategory row) => ReminderCategory(
        id: row.id,
        name: row.name,
        color: row.colorValue,
        icon: row.iconCodePoint,
        isDefault: row.isDefault,
      );

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    return AccentScope(
      feature: FeatureAccent.reminders,
      child: AppScaffold(
        floatingActionButton: AppFab(
          icon: Symbols.add_rounded,
          accent: ext.reminders,
          onPressed: () => _showEditor(context),
        ),
        body: Column(
          children: [
            AppHeader(
              title: 'Categories',
              accent: ext.reminders,
              leading: AppIconButton(
                icon: Symbols.arrow_back_rounded,
                filled: false,
                accent: ext.reminders,
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<db.ReminderCategory>>(
                stream: db.AppDatabase.instance.remindersDao.watchCategories(),
                builder: (context, snapshot) {
                  final rows = snapshot.data;
                  if (rows == null) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (rows.isEmpty) {
                    return EmptyState(
                      icon: Symbols.label_rounded,
                      title: 'No categories yet',
                      message: 'Tap + to create your first category.',
                      accent: ext.reminders,
                    );
                  }
                  final categories = rows.map(_toModel).toList();
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                        AppSpacing.sm, AppSpacing.gutter, 120),
                    itemCount: categories.length,
                    itemBuilder: (context, i) =>
                        _categoryTile(context, ext, categories[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryTile(
      BuildContext context, AppColorsExt ext, ReminderCategory category) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Dismissible(
        key: Key(category.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) async {
          final ok = await AppBottomSheet.confirm(
            context,
            title: 'Delete category?',
            message:
                '"${category.name}" will be removed. Reminders using it keep '
                'their data but lose the label.',
            confirmLabel: 'Delete',
            danger: true,
            icon: Symbols.delete_rounded,
          );
          if (ok == true) {
            await CleanStorageService.deleteCategory(category.id);
            return true;
          }
          return false;
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: ext.error.container,
            borderRadius: AppRadius.brCard,
          ),
          child: Icon(Symbols.delete_rounded, color: ext.error.onContainer),
        ),
        child: AppCard(
          onTap: () => _showEditor(context, category: category),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: category.colorObj.withOpacity(0.16),
                  borderRadius: AppRadius.brMd,
                ),
                child: Icon(category.iconObj, size: 22, color: category.colorObj),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Text(category.name, style: tt.titleLarge),
              ),
              if (category.isDefault)
                AppChip(label: 'Default', accent: ext.reminders),
              const SizedBox(width: AppSpacing.sm),
              Icon(Symbols.chevron_right_rounded, color: ext.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditor(BuildContext context, {ReminderCategory? category}) {
    final nameController = TextEditingController(text: category?.name ?? '');
    int selectedColor = category?.color ?? ReminderCategory.availableColors.first;
    int selectedIcon =
        category?.icon ?? ReminderCategory.availableIcons.first.codePoint;

    AppBottomSheet.show(
      context,
      title: category == null ? 'New Category' : 'Edit Category',
      icon: Symbols.label_rounded,
      accent: AppColorsExt.of(context).reminders,
      builder: (ctx) {
        final ext = AppColorsExt.of(ctx);
        final tt = Theme.of(ctx).textTheme;
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.sentences,
                  style: tt.bodyLarge?.copyWith(color: ext.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Category name',
                    hintStyle:
                        tt.bodyLarge?.copyWith(color: ext.textTertiary),
                    filled: true,
                    fillColor: ext.surfaceVariant,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.brMd,
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadius.brMd,
                      borderSide: BorderSide(color: ext.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadius.brMd,
                      borderSide: BorderSide(color: ext.mark(ext.reminders)),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('Color', style: tt.labelLarge?.copyWith(color: ext.textSecondary)),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: ReminderCategory.availableColors.map((c) {
                    final isSelected = selectedColor == c;
                    return GestureDetector(
                      onTap: () => setSheet(() => selectedColor = c),
                      child: Container(
                        width: 40,
                        height: 40,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? ext.textPrimary
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('Icon', style: tt.labelLarge?.copyWith(color: ext.textSecondary)),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: ReminderCategory.availableIcons.map((iconData) {
                    final isSelected = selectedIcon == iconData.codePoint;
                    return GestureDetector(
                      onTap: () =>
                          setSheet(() => selectedIcon = iconData.codePoint),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? ext.reminders.container
                              : ext.surfaceVariant,
                          borderRadius: AppRadius.brMd,
                          border: Border.all(
                            color: isSelected
                                ? ext.mark(ext.reminders)
                                : ext.outline,
                          ),
                        ),
                        child: Icon(
                          iconData,
                          size: 24,
                          color: isSelected
                              ? ext.reminders.onContainer
                              : ext.textSecondary,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Save',
                  fullWidth: true,
                  accent: ext.reminders,
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    final saved = ReminderCategory(
                      id: category?.id ?? const Uuid().v4(),
                      name: name,
                      color: selectedColor,
                      icon: selectedIcon,
                      isDefault: category?.isDefault ?? false,
                    );
                    await CleanStorageService.saveCategory(saved);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(nameController.dispose); // dispose the sheet controller
  }
}
