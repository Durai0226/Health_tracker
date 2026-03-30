import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/task_model.dart';
import '../../data/services/notes_service.dart';
import '../../theme/evernote_theme.dart';

/// Tasks management screen for Notes feature
/// Evernote-style dark theme with lime green accent
class NotesTasksScreen extends StatefulWidget {
  const NotesTasksScreen({super.key});

  @override
  State<NotesTasksScreen> createState() => _NotesTasksScreenState();
}

class _NotesTasksScreenState extends State<NotesTasksScreen>
    with SingleTickerProviderStateMixin {
  final NotesService _notesService = NotesService();
  late TabController _tabController;
  List<TaskModel> _tasks = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  bool _filterByDate = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTasks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    await _notesService.initialize();
    if (mounted) {
      setState(() {
        _tasks = _notesService.getAllTasks();
        _isLoading = false;
      });
    }
  }

  List<TaskModel> get _activeTasks {
    var tasks = _tasks.where((t) => !t.isCompleted).toList();
    
    // Filter by selected date if enabled
    if (_filterByDate) {
      tasks = tasks.where((t) {
        if (t.dueDate == null) return false;
        return _isSameDay(t.dueDate!, _selectedDate);
      }).toList();
    }
    
    tasks.sort((a, b) {
      if (a.dueDate != null && b.dueDate != null) {
        return a.dueDate!.compareTo(b.dueDate!);
      } else if (a.dueDate != null) {
        return -1;
      } else if (b.dueDate != null) {
        return 1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return tasks;
  }

  List<TaskModel> get _completedTasks {
    var tasks = _tasks.where((t) => t.isCompleted).toList();
    
    if (_filterByDate) {
      tasks = tasks.where((t) {
        if (t.dueDate == null) return false;
        return _isSameDay(t.dueDate!, _selectedDate);
      }).toList();
    }
    
    tasks.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return tasks;
  }
  
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EvernoteTheme.background,
      appBar: AppBar(
        backgroundColor: EvernoteTheme.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('Tasks', style: EvernoteTheme.headlineSmall),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: EvernoteTheme.primary,
          indicatorWeight: 3,
          labelColor: EvernoteTheme.primary,
          unselectedLabelColor: EvernoteTheme.textTertiary,
          labelStyle: EvernoteTheme.titleMedium,
          tabs: [
            Tab(text: 'Active (${_activeTasks.length})'),
            Tab(text: 'Completed (${_completedTasks.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: EvernoteTheme.primary,
                strokeWidth: 2,
              ),
            )
          : Column(
              children: [
                // Day-by-day date selector
                _buildDateSelector(),
                
                // Tasks list
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTasksList(_activeTasks, isEmpty: _activeTasks.isEmpty),
                      _buildTasksList(_completedTasks,
                          isEmpty: _completedTasks.isEmpty, isCompleted: true),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskSheet,
        backgroundColor: EvernoteTheme.primary,
        child: const Icon(
          Icons.add_rounded,
          color: EvernoteTheme.textOnPrimary,
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    final today = DateTime.now();
    final dates = List.generate(14, (i) => today.add(Duration(days: i - 7)));
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: EvernoteTheme.surface,
        border: Border(
          bottom: BorderSide(color: EvernoteTheme.border, width: 0.5),
        ),
      ),
      child: Column(
        children: [
          // Filter toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Filter by date',
                  style: EvernoteTheme.labelMedium.copyWith(
                    color: EvernoteTheme.textSecondary,
                  ),
                ),
                const Spacer(),
                Switch.adaptive(
                  value: _filterByDate,
                  onChanged: (v) => setState(() => _filterByDate = v),
                  activeColor: EvernoteTheme.primary,
                ),
              ],
            ),
          ),
          
          if (_filterByDate) ...[
            const SizedBox(height: 8),
            
            // Date pills
            SizedBox(
              height: 70,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: dates.length,
                itemBuilder: (context, index) {
                  final date = dates[index];
                  final isSelected = _isSameDay(date, _selectedDate);
                  final isToday = _isSameDay(date, today);
                  final hasTask = _tasks.any((t) => 
                    t.dueDate != null && _isSameDay(t.dueDate!, date));
                  
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _selectedDate = date);
                    },
                    child: Container(
                      width: 52,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? EvernoteTheme.primary 
                            : EvernoteTheme.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: isToday && !isSelected
                            ? Border.all(color: EvernoteTheme.primary, width: 1.5)
                            : Border.all(color: EvernoteTheme.cardBorder),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _weekdayShort(date.weekday),
                            style: EvernoteTheme.caption.copyWith(
                              color: isSelected 
                                  ? EvernoteTheme.textOnPrimary 
                                  : EvernoteTheme.textTertiary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${date.day}',
                            style: EvernoteTheme.titleMedium.copyWith(
                              color: isSelected 
                                  ? EvernoteTheme.textOnPrimary 
                                  : EvernoteTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (hasTask)
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? EvernoteTheme.textOnPrimary 
                                    : EvernoteTheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _weekdayShort(int weekday) {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return days[weekday - 1];
  }

  Widget _buildTasksList(List<TaskModel> tasks,
      {bool isEmpty = false, bool isCompleted = false}) {
    if (isEmpty) {
      return _buildEmptyState(isCompleted);
    }

    return RefreshIndicator(
      onRefresh: _loadTasks,
      color: EvernoteTheme.primary,
      backgroundColor: EvernoteTheme.surface,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return _TaskTile(
            task: task,
            onToggle: () => _toggleTask(task),
            onDelete: () => _deleteTask(task),
            onEdit: () => _showEditTaskSheet(task),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isCompleted) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  EvernoteTheme.primary.withOpacity(0.2),
                  EvernoteTheme.primaryDark.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              isCompleted ? Icons.task_alt_rounded : Icons.checklist_rounded,
              size: 40,
              color: EvernoteTheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isCompleted ? 'No completed tasks' : 'No active tasks',
            style: EvernoteTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            isCompleted
                ? 'Complete some tasks to see them here'
                : 'Tap + to create your first task',
            style: EvernoteTheme.bodyMedium.copyWith(
              color: EvernoteTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleTask(TaskModel task) async {
    HapticFeedback.lightImpact();
    await _notesService.toggleTask(task.id);
    _loadTasks();
  }

  Future<void> _deleteTask(TaskModel task) async {
    HapticFeedback.mediumImpact();
    await _notesService.deleteTask(task.id);
    _loadTasks();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Task deleted'),
          backgroundColor: EvernoteTheme.surface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          action: SnackBarAction(
            label: 'Undo',
            textColor: EvernoteTheme.primary,
            onPressed: () async {
              // Re-create the task
              await _notesService.createTask(
                noteId: task.noteId,
                title: task.title,
                dueDate: task.dueDate,
                priority: task.priority,
              );
              _loadTasks();
            },
          ),
        ),
      );
    }
  }

  void _showAddTaskSheet() {
    _showTaskSheet();
  }

  void _showEditTaskSheet(TaskModel task) {
    _showTaskSheet(task: task);
  }

  void _showTaskSheet({TaskModel? task}) {
    final isEditing = task != null;
    final titleController = TextEditingController(text: task?.title ?? '');
    DateTime? selectedDate = task?.dueDate;
    String? selectedPriority = task?.priority;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          decoration: EvernoteTheme.modalDecoration,
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: EvernoteTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                isEditing ? 'Edit Task' : 'New Task',
                style: EvernoteTheme.headlineSmall,
              ),
              const SizedBox(height: 20),

              // Title input
              TextField(
                controller: titleController,
                autofocus: true,
                style: EvernoteTheme.bodyLarge,
                cursorColor: EvernoteTheme.primary,
                decoration: InputDecoration(
                  hintText: 'What needs to be done?',
                  hintStyle: EvernoteTheme.bodyLarge.copyWith(
                    color: EvernoteTheme.textTertiary,
                  ),
                  filled: true,
                  fillColor: EvernoteTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: EvernoteTheme.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Due date picker
              GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setS(() => selectedDate = date);
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: EvernoteTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: selectedDate != null
                        ? Border.all(color: EvernoteTheme.primary, width: 1)
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 20,
                        color: selectedDate != null
                            ? EvernoteTheme.primary
                            : EvernoteTheme.textTertiary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        selectedDate != null
                            ? _formatDate(selectedDate!)
                            : 'Set due date',
                        style: EvernoteTheme.bodyMedium.copyWith(
                          color: selectedDate != null
                              ? EvernoteTheme.textPrimary
                              : EvernoteTheme.textTertiary,
                        ),
                      ),
                      const Spacer(),
                      if (selectedDate != null)
                        GestureDetector(
                          onTap: () => setS(() => selectedDate = null),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: EvernoteTheme.textTertiary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Priority selector
              Text(
                'Priority',
                style: EvernoteTheme.labelMedium.copyWith(
                  color: EvernoteTheme.textTertiary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: ['low', 'medium', 'high'].map((p) {
                  final isSelected = selectedPriority == p;
                  final color = _getPriorityColor(p);

                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setS(() {
                          selectedPriority =
                              selectedPriority == p ? null : p;
                        });
                      },
                      child: Container(
                        margin: EdgeInsets.only(
                            right: p != 'high' ? 8 : 0),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withOpacity(0.15)
                              : EvernoteTheme.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color:
                                isSelected ? color : EvernoteTheme.border,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            p[0].toUpperCase() + p.substring(1),
                            style: EvernoteTheme.labelMedium.copyWith(
                              color: isSelected
                                  ? color
                                  : EvernoteTheme.textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;

                    Navigator.pop(ctx);

                    if (isEditing && task != null) {
                      await _notesService.updateTask(
                        task.copyWith(
                          title: title,
                          dueDate: selectedDate,
                          priority: selectedPriority,
                        ),
                      );
                    } else {
                      // Create a standalone task (noteId can be empty for standalone)
                      await _notesService.createTask(
                        noteId: '', // Standalone task
                        title: title,
                        dueDate: selectedDate,
                        priority: selectedPriority,
                      );
                    }
                    _loadTasks();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EvernoteTheme.primary,
                    foregroundColor: EvernoteTheme.textOnPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isEditing ? 'Save Changes' : 'Create Task',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.2, // Ensure text has room
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(DateTime(now.year, now.month, now.day)).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff < 7) return _weekdayName(date.weekday);

    return '${date.day}/${date.month}/${date.year}';
  }

  String _weekdayName(int weekday) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[weekday - 1];
  }

  Color _getPriorityColor(String? priority) {
    switch (priority) {
      case 'high':
        return EvernoteTheme.error;
      case 'medium':
        return EvernoteTheme.warning;
      case 'low':
        return EvernoteTheme.info;
      default:
        return EvernoteTheme.textTertiary;
    }
  }
}

/// Individual task tile widget
class _TaskTile extends StatelessWidget {
  final TaskModel task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _TaskTile({
    required this.task,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
  });

  Color get _priorityColor {
    switch (task.priority) {
      case 'high':
        return EvernoteTheme.error;
      case 'medium':
        return EvernoteTheme.warning;
      case 'low':
        return EvernoteTheme.info;
      default:
        return EvernoteTheme.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: EvernoteTheme.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.delete_rounded,
          color: Colors.white,
        ),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: GestureDetector(
        onTap: onEdit,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: EvernoteTheme.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: EvernoteTheme.cardBorder),
          ),
          child: Row(
            children: [
              // Checkbox
              GestureDetector(
                onTap: onToggle,
                child: AnimatedContainer(
                  duration: EvernoteTheme.durationFast,
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: task.isCompleted
                        ? EvernoteTheme.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: task.isCompleted
                          ? EvernoteTheme.primary
                          : EvernoteTheme.border,
                      width: 2,
                    ),
                  ),
                  child: task.isCompleted
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: EvernoteTheme.textOnPrimary,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 14),

              // Task content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: EvernoteTheme.titleMedium.copyWith(
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: task.isCompleted
                            ? EvernoteTheme.textTertiary
                            : EvernoteTheme.textPrimary,
                      ),
                    ),
                    if (task.dueDate != null || task.priority != null)
                      const SizedBox(height: 6),
                    if (task.dueDate != null || task.priority != null)
                      Row(
                        children: [
                          if (task.dueDate != null) ...[
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 12,
                              color: task.isOverdue
                                  ? EvernoteTheme.error
                                  : EvernoteTheme.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(task.dueDate!),
                              style: EvernoteTheme.caption.copyWith(
                                color: task.isOverdue
                                    ? EvernoteTheme.error
                                    : EvernoteTheme.textTertiary,
                              ),
                            ),
                          ],
                          if (task.dueDate != null && task.priority != null)
                            const SizedBox(width: 12),
                          if (task.priority != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _priorityColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                task.priority.toString().toUpperCase(),
                                style: EvernoteTheme.caption.copyWith(
                                  color: _priorityColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),

              // More options
              IconButton(
                onPressed: onEdit,
                icon: const Icon(
                  Icons.more_vert_rounded,
                  size: 20,
                  color: EvernoteTheme.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(date.year, date.month, date.day);
    final diff = taskDate.difference(today).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    if (diff < 0) return '${-diff} days ago';
    if (diff < 7) {
      const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return names[date.weekday - 1];
    }

    return '${date.day}/${date.month}';
  }
}
