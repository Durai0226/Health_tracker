import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reminders Categories Settings Screen
class RemindersCategoriesSettingsScreen extends StatefulWidget {
  const RemindersCategoriesSettingsScreen({super.key});

  @override
  State<RemindersCategoriesSettingsScreen> createState() => _RemindersCategoriesSettingsScreenState();
}

class _RemindersCategoriesSettingsScreenState extends State<RemindersCategoriesSettingsScreen> {
  static const _primaryColor = Color(0xFFEC4899);

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Personal', 'icon': Icons.person, 'color': Colors.blue, 'count': 12},
    {'name': 'Work', 'icon': Icons.work, 'color': Colors.orange, 'count': 8},
    {'name': 'Health', 'icon': Icons.favorite, 'color': Colors.red, 'count': 5},
    {'name': 'Shopping', 'icon': Icons.shopping_cart, 'color': Colors.green, 'count': 3},
    {'name': 'Finance', 'icon': Icons.attach_money, 'color': Colors.purple, 'count': 4},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF2F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFDF2F8),
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.black87), onPressed: () => Navigator.pop(context)),
        title: const Text('Categories', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [IconButton(icon: Icon(Icons.add_circle_outline, color: _primaryColor), onPressed: _addCategory)],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _categories.length,
        itemBuilder: (context, index) => _buildCategoryCard(_categories[index], index),
      ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: (category['color'] as Color).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(category['icon'], color: category['color']),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('${category['count']} reminders', style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
          IconButton(icon: Icon(Icons.edit_outlined, color: _primaryColor), onPressed: () => _editCategory(index)),
          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteCategory(index)),
        ],
      ),
    );
  }

  void _addCategory() {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Add category'), backgroundColor: _primaryColor));
  }

  void _editCategory(int index) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Edit ${_categories[index]['name']}'), backgroundColor: _primaryColor));
  }

  void _deleteCategory(int index) {
    HapticFeedback.mediumImpact();
    setState(() => _categories.removeAt(index));
  }
}
