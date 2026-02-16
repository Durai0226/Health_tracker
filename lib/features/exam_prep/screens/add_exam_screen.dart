import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../models/exam_type.dart';
import '../services/exam_prep_service.dart';

class AddExamScreen extends StatefulWidget {
  final ExamType? existingExam;
  
  const AddExamScreen({super.key, this.existingExam});

  @override
  State<AddExamScreen> createState() => _AddExamScreenState();
}

class _AddExamScreenState extends State<AddExamScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  ExamCategory _selectedCategory = ExamCategory.banking;
  String? _selectedExamName;
  DateTime? _examDate;
  List<String> _subjects = [];
  final _subjectController = TextEditingController();

  bool get isEditing => widget.existingExam != null;

  @override
  void initState() {
    super.initState();
    if (widget.existingExam != null) {
      _nameController.text = widget.existingExam!.name;
      _descriptionController.text = widget.existingExam!.description ?? '';
      _selectedCategory = widget.existingExam!.category;
      _examDate = widget.existingExam!.examDate;
      _subjects = List.from(widget.existingExam!.subjects);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Exam' : 'Add Exam'),
        actions: [
          if (isEditing)
            IconButton(
              onPressed: _deleteExam,
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCategorySelector(),
              const SizedBox(height: 24),
              _buildPopularExams(),
              const SizedBox(height: 24),
              _buildExamNameField(),
              const SizedBox(height: 20),
              _buildExamDatePicker(),
              const SizedBox(height: 20),
              _buildDescriptionField(),
              const SizedBox(height: 24),
              _buildSubjectsSection(),
              const SizedBox(height: 32),
              _buildSaveButton(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Exam Category',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: ExamCategory.values.map((category) {
            final isSelected = _selectedCategory == category;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategory = category;
                  _selectedExamName = null;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? category.color : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? category.color : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(category.emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      category.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPopularExams() {
    final popularExams = _selectedCategory.popularExams;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Popular ${_selectedCategory.name} Exams',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: popularExams.map((exam) {
            final isSelected = _selectedExamName == exam;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedExamName = exam;
                  _nameController.text = exam;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? _selectedCategory.color.withOpacity(0.15) 
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: isSelected 
                      ? Border.all(color: _selectedCategory.color)
                      : null,
                ),
                child: Text(
                  exam,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? _selectedCategory.color : AppColors.textPrimary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildExamNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: const InputDecoration(
        labelText: 'Exam Name',
        hintText: 'e.g., IBPS PO 2024',
      ),
      textCapitalization: TextCapitalization.words,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter exam name';
        }
        return null;
      },
    );
  }

  Widget _buildExamDatePicker() {
    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _examDate ?? DateTime.now().add(const Duration(days: 90)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
        );
        if (date != null) {
          setState(() => _examDate = date);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              color: _examDate != null ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Exam Date',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _examDate != null
                        ? DateFormat('EEEE, MMMM d, yyyy').format(_examDate!)
                        : 'Select exam date (optional)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: _examDate != null ? FontWeight.w600 : FontWeight.normal,
                      color: _examDate != null ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (_examDate != null)
              GestureDetector(
                onTap: () => setState(() => _examDate = null),
                child: const Icon(Icons.close_rounded, size: 20),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      decoration: const InputDecoration(
        labelText: 'Description (Optional)',
        hintText: 'Add notes about this exam...',
      ),
      maxLines: 3,
    );
  }

  Widget _buildSubjectsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Subjects',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  hintText: 'Add subject...',
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                textCapitalization: TextCapitalization.words,
                onSubmitted: (_) => _addSubject(),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _addSubject,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _subjects.map((subject) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    subject,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => setState(() => _subjects.remove(subject)),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _addSubject() {
    final subject = _subjectController.text.trim();
    if (subject.isNotEmpty && !_subjects.contains(subject)) {
      setState(() {
        _subjects.add(subject);
        _subjectController.clear();
      });
    }
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _saveExam,
        child: Text(isEditing ? 'Update Exam' : 'Add Exam'),
      ),
    );
  }

  void _saveExam() {
    if (_formKey.currentState!.validate()) {
      final service = ExamPrepService();
      final exam = ExamType(
        id: widget.existingExam?.id ?? service.generateId(),
        name: _nameController.text,
        category: _selectedCategory,
        examDate: _examDate,
        description: _descriptionController.text.isNotEmpty 
            ? _descriptionController.text 
            : null,
        subjects: _subjects,
        createdAt: widget.existingExam?.createdAt ?? DateTime.now(),
      );

      if (isEditing) {
        service.updateExam(exam);
      } else {
        service.addExam(exam);
      }

      Navigator.pop(context);
    }
  }

  void _deleteExam() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Exam?'),
        content: const Text(
          'This will delete all study sessions, mock tests, and progress for this exam.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ExamPrepService().deleteExam(widget.existingExam!.id);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
