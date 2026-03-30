import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
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

                    // TODO: Replace with Drift storage when migration is complete
                    debugPrint('addCategory/updateCategory temporarily disabled - Drift migration needed');
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
      // TODO: Replace with Drift stream when migration is complete
      body: const Center(
        child: Text('Categories temporarily disabled - Drift migration in progress'),
      ),
    );
  }
}
