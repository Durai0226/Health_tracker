import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/storage_service.dart';
import '../models/reminder_category_model.dart';
import '../models/reminder_model.dart';

class CategoryManagementScreen extends StatelessWidget {
  const CategoryManagementScreen({super.key});

  void _showAddEditCategoryDialog(BuildContext context, {ReminderCategory? category}) {
    final nameController = TextEditingController(text: category?.name ?? '');
    int selectedColor = category?.color ?? Colors.blue.value;
    int selectedIcon = category?.icon ?? Icons.label_rounded.codePoint;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(category == null ? 'New Category' : 'Edit Category'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Category Name',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),
                    const Text('Color', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Colors.blue,
                        Colors.red,
                        Colors.green,
                        Colors.orange,
                        Colors.purple,
                        Colors.teal,
                        Colors.pink,
                        Colors.indigo,
                      ].map((color) {
                        final isSelected = selectedColor == color.value;
                        return GestureDetector(
                          onTap: () => setState(() => selectedColor = color.value),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: isSelected ? Border.all(color: Colors.black, width: 2) : null,
                            ),
                            child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text('Icon', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Icons.label_rounded,
                        Icons.work_rounded,
                        Icons.person_rounded,
                        Icons.favorite_rounded,
                        Icons.attach_money_rounded,
                        Icons.school_rounded,
                        Icons.shopping_cart_rounded,
                        Icons.flight_rounded,
                        Icons.home_rounded,
                        Icons.directions_car_rounded,
                      ].map((iconData) {
                        final isSelected = selectedIcon == iconData.codePoint;
                        return GestureDetector(
                          onTap: () => setState(() => selectedIcon = iconData.codePoint),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: isSelected ? Border.all(color: AppColors.primary) : null
                            ),
                            child: Icon(
                                iconData,
                                color: isSelected ? AppColors.primary : Colors.grey,
                                size: 24
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) return;

                    final newCategory = ReminderCategory(
                      id: category?.id ?? const Uuid().v4(),
                      name: nameController.text.trim(),
                      color: selectedColor,
                      icon: selectedIcon,
                      isDefault: category?.isDefault ?? false,
                    );

                    if (category == null) {
                      await StorageService.addCategory(newCategory);
                    } else {
                      await StorageService.updateCategory(newCategory);
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Manage Categories'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditCategoryDialog(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: ValueListenableBuilder<Box<ReminderCategory>>(
        valueListenable: StorageService.categoriesListenable,
        builder: (context, box, _) {
          final categories = box.values.toList();

          if (categories.isEmpty) {
             return const Center(child: Text('No categories'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: category.colorObj.withOpacity(0.1),
                    child: Icon(category.iconObj, color: category.colorObj),
                  ),
                  title: Text(
                      category.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                       IconButton(
                        icon: const Icon(Icons.edit_rounded, color: AppColors.textSecondary),
                        onPressed: () => _showAddEditCategoryDialog(context, category: category),
                      ),
                      if (!category.isDefault)
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Category?'),
                                content: Text('Are you sure you want to delete "${category.name}"? Reminders in this category will become uncategorized.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    style: TextButton.styleFrom(foregroundColor: AppColors.error),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );

                            if (confirmed == true) {
                              await StorageService.deleteCategory(category.id);
                            }
                          },
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
