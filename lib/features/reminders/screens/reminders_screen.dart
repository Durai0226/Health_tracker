
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/notification_service.dart';
import '../models/reminder_model.dart';
import '../models/reminder_category_model.dart';
import 'add_reminder_screen.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  String? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Reminders'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddReminderScreen()),
          );
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          _buildCategoryFilter(),
          Expanded(
            child: ValueListenableBuilder<Box<Reminder>>(
              valueListenable: StorageService.reminderListenable,
              builder: (context, box, _) {
                var reminders = box.values.toList();
                
                // Filter by category
                if (_selectedCategoryId != null) {
                  reminders = reminders.where((r) => r.categoryId == _selectedCategoryId).toList();
                }

                reminders.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

                if (reminders.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: reminders.length,
                  itemBuilder: (context, index) {
                    final reminder = reminders[index];
                    return _buildReminderCard(context, reminder);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return ValueListenableBuilder<Box<ReminderCategory>>(
      valueListenable: StorageService.categoriesListenable,
      builder: (context, box, _) {
        final categories = box.values.toList();
        if (categories.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 60,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              _buildFilterChip(null, 'All', Colors.grey, Icons.all_inclusive_rounded),
              ...categories.map((category) {
                return _buildFilterChip(category.id, category.name, category.colorObj, category.iconObj);
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String? id, String label, Color color, IconData icon) {
    final isSelected = _selectedCategoryId == id;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategoryId = id;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? color : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.notifications_none_rounded,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            _selectedCategoryId == null ? 'No reminders yet' : 'No reminders in this category',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          if (_selectedCategoryId == null) ...[
            const SizedBox(height: 8),
            Text(
              'Tap the + button to add one',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary.withOpacity(0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReminderCard(BuildContext context, Reminder reminder) {
    final isOverdue = reminder.scheduledTime.isBefore(DateTime.now()) && !reminder.isCompleted;
    final timeFormat = DateFormat('h:mm a');
    final dateFormat = DateFormat('MMM d, y');
    
    // Get category if exists
    final category = reminder.categoryId != null ? StorageService.getCategory(reminder.categoryId!) : null;

    return Dismissible(
      key: Key(reminder.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) async {
        await StorageService.deleteReminder(reminder.id);
        await NotificationService().cancelNotification(reminder.id.hashCode);
      },
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddReminderScreen(reminder: reminder),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isOverdue ? AppColors.error.withOpacity(0.5) : AppColors.border,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start, // Align to top
            children: [
              // Checkbox / Status
              Padding(
                padding: const EdgeInsets.only(top: 2), // Align with text
                child: GestureDetector(
                  key: Key('checkbox_${reminder.id}'),
                  onTap: () async {
                    await StorageService.toggleReminderCompletion(reminder);
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: reminder.isCompleted
                            ? AppColors.success
                            : (isOverdue ? AppColors.error : AppColors.primary),
                        width: 2,
                      ),
                      color: reminder.isCompleted ? AppColors.success : Colors.transparent,
                    ),
                    child: reminder.isCompleted
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            reminder.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: reminder.isCompleted
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                              decoration: reminder.isCompleted ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                        if (category != null) ...[
                          const SizedBox(width: 8),
                          Icon(category.iconObj, size: 14, color: category.colorObj),
                        ],
                      ],
                    ),
                    if (reminder.body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        reminder.body,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          decoration: reminder.isCompleted ? TextDecoration.lineThrough : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4, // For wrapping items
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Time
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color: isOverdue ? AppColors.error : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${dateFormat.format(reminder.scheduledTime)} • ${timeFormat.format(reminder.scheduledTime)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isOverdue ? AppColors.error : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        // Priority
                        if (reminder.priority != ReminderPriority.medium)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getPriorityColor(reminder.priority).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: _getPriorityColor(reminder.priority), width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getPriorityIcon(reminder.priority),
                                  size: 10,
                                  color: _getPriorityColor(reminder.priority),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  _getPriorityLabel(reminder.priority),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _getPriorityColor(reminder.priority),
                                  ),
                                ),
                              ],
                            ),
                          ),
                         // Repeat
                        if (reminder.repeatType != RepeatType.none)
                          Text(
                            _getRepeatText(reminder),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primary,
                            ),
                          ),
                        // Note Indicator
                        if (reminder.note != null && reminder.note!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.description_rounded,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        // Image Indicator
                        if (reminder.imagePath != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.image_rounded,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getRepeatText(Reminder reminder) {
    switch (reminder.repeatType) {
      case RepeatType.none:
        return '';
      case RepeatType.daily:
        return ' • Daily';
      case RepeatType.weekly:
        return ' • Weekly';
      case RepeatType.weekdays:
        return ' • Weekdays';
      case RepeatType.weekends:
        return ' • Weekends';
      case RepeatType.custom:
        if (reminder.customDays == null || reminder.customDays!.isEmpty) return ' • Custom';
        final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final selected = reminder.customDays!.map((d) => days[d - 1]).join(', ');
        return ' • $selected';
    }
    return '';
  }

  Color _getPriorityColor(ReminderPriority priority) {
    switch (priority) {
      case ReminderPriority.high: return AppColors.error;
      case ReminderPriority.medium: return AppColors.warning;
      case ReminderPriority.low: return AppColors.success;
    }
  }

  IconData _getPriorityIcon(ReminderPriority priority) {
    switch (priority) {
      case ReminderPriority.high: return Icons.priority_high_rounded;
      case ReminderPriority.medium: return Icons.remove_rounded; // Or generic
      case ReminderPriority.low: return Icons.arrow_downward_rounded;
    }
  }

  String _getPriorityLabel(ReminderPriority priority) {
    switch (priority) {
      case ReminderPriority.high: return 'HIGH';
      case ReminderPriority.medium: return 'MED';
      case ReminderPriority.low: return 'LOW';
    }
  }
}
