import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../services/exam_prep_service.dart';
import '../models/exam_model.dart';
import '../models/subject_model.dart';

class AddExamScreen extends StatefulWidget {
  final Exam? exam;

  const AddExamScreen({super.key, this.exam});

  @override
  State<AddExamScreen> createState() => _AddExamScreenState();
}

class _AddExamScreenState extends State<AddExamScreen> {
  final ExamPrepService _examPrepService = ExamPrepService();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _totalMarksController = TextEditingController();
  final _passingMarksController = TextEditingController();
  final _targetStudyMinutesController = TextEditingController();

  String? _selectedSubjectId;
  ExamType _selectedExamType = ExamType.test;
  ExamPriority _selectedPriority = ExamPriority.medium;
  DateTime _examDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _examTime = const TimeOfDay(hour: 9, minute: 0);
  bool _reminderEnabled = true;
  List<int> _reminderDays = [7, 3, 1];

  bool get _isEditing => widget.exam != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadExamData();
    }
  }

  void _loadExamData() {
    final exam = widget.exam!;
    _titleController.text = exam.title;
    _descriptionController.text = exam.description ?? '';
    _locationController.text = exam.location ?? '';
    _totalMarksController.text = exam.totalMarks?.toString() ?? '';
    _passingMarksController.text = exam.passingMarks?.toString() ?? '';
    _targetStudyMinutesController.text = exam.targetStudyMinutes.toString();
    _selectedSubjectId = exam.subjectId;
    _selectedExamType = exam.examType;
    _selectedPriority = exam.priority;
    _examDate = exam.examDate;
    _examTime = TimeOfDay.fromDateTime(exam.examDate);
    _reminderEnabled = exam.reminderEnabled;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _totalMarksController.dispose();
    _passingMarksController.dispose();
    _targetStudyMinutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subjects = _examPrepService.getActiveSubjects();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Exam' : 'Add Exam'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteExam,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Exam Title *',
                hintText: 'e.g., Midterm Mathematics',
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Subject Selection
            DropdownButtonFormField<String>(
              value: _selectedSubjectId,
              decoration: const InputDecoration(
                labelText: 'Subject *',
                prefixIcon: Icon(Icons.book),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Select a subject'),
                ),
                ...subjects.map((subject) => DropdownMenuItem(
                      value: subject.id,
                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Color(int.parse(
                                  subject.colorHex.replaceAll('#', '0xFF'))),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(subject.name),
                        ],
                      ),
                    )),
              ],
              onChanged: (value) => setState(() => _selectedSubjectId = value),
              validator: (value) {
                if (value == null) {
                  return 'Please select a subject';
                }
                return null;
              },
            ),
            if (subjects.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: CommonButton(
                  text: 'Create a subject first',
                  variant: ButtonVariant.secondary,
                  onPressed: _createQuickSubject,
                ),
              ),
            const SizedBox(height: 16),

            // Exam Type
            Text('Exam Type', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ExamType.values.map((type) {
                final isSelected = _selectedExamType == type;
                return ChoiceChip(
                  label: Text('${type.emoji} ${type.displayName}'),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedExamType = type),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Date & Time
            Text('Date & Time', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(DateFormat('EEE, MMM dd, yyyy').format(_examDate)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: _selectTime,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.access_time),
                      ),
                      child: Text(_examTime.format(context)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Additional notes about the exam',
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Location
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location',
                hintText: 'e.g., Room 101, Building A',
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 16),

            // Marks
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _totalMarksController,
                    decoration: const InputDecoration(
                      labelText: 'Total Marks',
                      prefixIcon: Icon(Icons.grade),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _passingMarksController,
                    decoration: const InputDecoration(
                      labelText: 'Passing Marks',
                      prefixIcon: Icon(Icons.check_circle_outline),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Priority
            Text('Priority', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<ExamPriority>(
              showSelectedIcon: false,
              segments: ExamPriority.values.map((priority) {
                return ButtonSegment(
                  value: priority,
                  label: Text(priority.displayName),
                );
              }).toList(),
              selected: {_selectedPriority},
              onSelectionChanged: (selected) {
                setState(() => _selectedPriority = selected.first);
              },
            ),
            const SizedBox(height: 16),

            // Target Study Time
            TextFormField(
              controller: _targetStudyMinutesController,
              decoration: const InputDecoration(
                labelText: 'Target Study Time (minutes)',
                hintText: 'e.g., 600 for 10 hours',
                prefixIcon: Icon(Icons.timer),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // Reminders
            SwitchListTile(
              title: const Text('Enable Reminders'),
              subtitle: const Text('Get notified before the exam'),
              value: _reminderEnabled,
              onChanged: (value) => setState(() => _reminderEnabled = value),
            ),
            if (_reminderEnabled)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  children: [1, 3, 7, 14].map((days) {
                    final isSelected = _reminderDays.contains(days);
                    return FilterChip(
                      label: Text('$days day${days > 1 ? 's' : ''} before'),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _reminderDays.add(days);
                          } else {
                            _reminderDays.remove(days);
                          }
                          _reminderDays.sort();
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 32),

            // Save Button
            CommonButton(
              text: _isEditing ? 'Update Exam' : 'Create Exam',
              variant: ButtonVariant.primary,
              onPressed: _saveExam,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _examDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _examDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _examTime,
    );
    if (picked != null) {
      setState(() => _examTime = picked);
    }
  }

  void _createQuickSubject() {
    showDialog(
      context: context,
      builder: (context) {
        final nameController = TextEditingController();
        return AlertDialog(
          title: const Text('Create Subject'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Subject Name',
              hintText: 'e.g., Mathematics',
            ),
            autofocus: true,
          ),
          actions: [
            CommonButton(
              text: 'Cancel',
              variant: ButtonVariant.secondary,
              onPressed: () => Navigator.pop(context),
            ),
            CommonButton(
              text: 'Create',
              variant: ButtonVariant.primary,
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty) {
                  final subject = await _examPrepService.createSubject(
                    Subject(
                      id: const Uuid().v4(),
                      name: nameController.text.trim(),
                    ),
                  );
                  setState(() => _selectedSubjectId = subject.id);
                  if (mounted) Navigator.pop(context);
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveExam() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSubjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a subject')),
      );
      return;
    }

    final examDateTime = DateTime(
      _examDate.year,
      _examDate.month,
      _examDate.day,
      _examTime.hour,
      _examTime.minute,
    );

    List<DateTime> reminderTimes = [];
    if (_reminderEnabled) {
      for (final days in _reminderDays) {
        reminderTimes.add(examDateTime.subtract(Duration(days: days)));
      }
    }

    final exam = Exam(
      id: widget.exam?.id ?? const Uuid().v4(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      subjectId: _selectedSubjectId!,
      examType: _selectedExamType,
      examDate: examDateTime,
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      priority: _selectedPriority,
      totalMarks: double.tryParse(_totalMarksController.text),
      passingMarks: double.tryParse(_passingMarksController.text),
      targetStudyMinutes:
          int.tryParse(_targetStudyMinutesController.text) ?? 0,
      reminderEnabled: _reminderEnabled,
      reminderTimes: reminderTimes,
      status: widget.exam?.status ?? ExamStatus.upcoming,
      actualStudyMinutes: widget.exam?.actualStudyMinutes ?? 0,
      topicIds: widget.exam?.topicIds ?? [],
    );

    try {
      if (_isEditing) {
        await _examPrepService.updateExam(exam);
      } else {
        await _examPrepService.createExam(exam);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Exam updated!' : 'Exam created!'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _deleteExam() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Exam'),
        content: Text(
            'Are you sure you want to delete "${widget.exam!.title}"? This action cannot be undone.'),
        actions: [
          CommonButton(
            text: 'Cancel',
            variant: ButtonVariant.secondary,
            onPressed: () => Navigator.pop(context),
          ),
          CommonButton(
            text: 'Delete',
            variant: ButtonVariant.danger,
            onPressed: () async {
              await _examPrepService.deleteExam(widget.exam!.id);
              if (mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Exam deleted')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
