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
        title: Text(
          _isEditing ? 'Edit Exam' : 'Create Exam',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          if (_isEditing)
            CommonIconButton(
              icon: Icons.delete_rounded,
              onPressed: _deleteExam,
              backgroundColor: AppColors.error.withOpacity(0.1),
              iconColor: AppColors.error,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Header Section
            _buildSectionCard(
              title: 'Exam Details',
              icon: Icons.event_note_rounded,
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleController,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppColors.getTextPrimary(context),
                    ),
                    decoration: InputDecoration(
                      labelText: 'Exam Title',
                      hintText: 'e.g., Midterm Mathematics',
                      prefixIcon: Container(
                        margin: const EdgeInsets.all(12),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.title_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppColors.getBorder(context)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppColors.getBorder(context)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                      filled: true,
                      fillColor: AppColors.getGrey50(context),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a title';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  DropdownButtonFormField<String>(
                    value: _selectedSubjectId,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppColors.getTextPrimary(context),
                    ),
                    decoration: InputDecoration(
                      labelText: 'Subject',
                      prefixIcon: Container(
                        margin: const EdgeInsets.all(12),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.book_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppColors.getBorder(context)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppColors.getBorder(context)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                      filled: true,
                      fillColor: AppColors.getGrey50(context),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(
                          'Select a subject',
                          style: TextStyle(color: AppColors.getTextSecondary(context)),
                        ),
                      ),
                      ...subjects.map((subject) => DropdownMenuItem(
                            value: subject.id,
                            child: Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: Color(int.parse(
                                        subject.colorHex.replaceAll('#', '0xFF'))),
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(int.parse(
                                            subject.colorHex.replaceAll('#', '0xFF'))).withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  subject.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.getTextPrimary(context),
                                  ),
                                ),
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
                      padding: const EdgeInsets.only(top: 16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.warning.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: AppColors.warning,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'No subjects available',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AppColors.warning,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            CommonButton(
                              text: 'Create Subject First',
                              variant: ButtonVariant.secondary,
                              onPressed: _createQuickSubject,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Exam Type & Priority Section
            _buildSectionCard(
              title: 'Type & Priority',
              icon: Icons.category_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Exam Type',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ExamType.values.map((type) {
                      final isSelected = _selectedExamType == type;
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: isSelected ? [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ] : null,
                        ),
                        child: ChoiceChip(
                          label: Text(
                            '${type.emoji} ${type.displayName}',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: isSelected ? Colors.white : AppColors.getTextPrimary(context),
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          backgroundColor: AppColors.getGrey50(context),
                          onSelected: (_) => setState(() => _selectedExamType = type),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Priority Section
                  Text(
                    'Priority',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.getGrey50(context),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SegmentedButton<ExamPriority>(
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: AppColors.primary,
                        selectedForegroundColor: Colors.white,
                        backgroundColor: Colors.transparent,
                        foregroundColor: AppColors.getTextSecondary(context),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        textStyle: const TextStyle(fontWeight: FontWeight.w500),
                      ),
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
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Date & Time Section
            _buildSectionCard(
              title: 'Date & Time',
              icon: Icons.schedule_rounded,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildDateTimeField(
                          label: 'Date',
                          value: DateFormat('EEE, MMM dd, yyyy').format(_examDate),
                          icon: Icons.calendar_today_rounded,
                          onTap: _selectDate,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDateTimeField(
                          label: 'Time',
                          value: _examTime.format(context),
                          icon: Icons.access_time_rounded,
                          onTap: _selectTime,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Additional Details Section
            _buildSectionCard(
              title: 'Additional Details',
              icon: Icons.notes_rounded,
              child: Column(
                children: [
                  TextFormField(
                    controller: _descriptionController,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppColors.getTextPrimary(context),
                    ),
                    decoration: InputDecoration(
                      labelText: 'Description',
                      hintText: 'Additional notes about the exam',
                      prefixIcon: Container(
                        margin: const EdgeInsets.all(12),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.info.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.description_rounded,
                          color: AppColors.info,
                          size: 20,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppColors.getBorder(context)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppColors.getBorder(context)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                      filled: true,
                      fillColor: AppColors.getGrey50(context),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _locationController,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppColors.getTextPrimary(context),
                    ),
                    decoration: InputDecoration(
                      labelText: 'Location',
                      hintText: 'e.g., Room 101, Building A',
                      prefixIcon: Container(
                        margin: const EdgeInsets.all(12),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: AppColors.warning,
                          size: 20,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppColors.getBorder(context)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppColors.getBorder(context)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                      filled: true,
                      fillColor: AppColors.getGrey50(context),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

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
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF26A69A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: CommonButton(
                text: _isEditing ? 'Update Exam' : 'Create Exam',
                variant: ButtonVariant.primary,
                backgroundColor: Colors.transparent,
                onPressed: _saveExam,
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return ElevatedCard(
      padding: const EdgeInsets.all(24),
      borderRadius: 20,
      shadowColor: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.getTextPrimary(context),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildDateTimeField({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.getGrey50(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.getBorder(context)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: AppColors.info,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.getTextSecondary(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppColors.getTextSecondary(context),
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
