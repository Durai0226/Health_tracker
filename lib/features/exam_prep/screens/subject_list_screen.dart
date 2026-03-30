import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../services/exam_prep_service.dart';
import '../models/subject_model.dart';
import '../models/topic_model.dart';

class SubjectListScreen extends StatefulWidget {
  const SubjectListScreen({super.key});

  @override
  State<SubjectListScreen> createState() => _SubjectListScreenState();
}

class _SubjectListScreenState extends State<SubjectListScreen> {
  final ExamPrepService _examPrepService = ExamPrepService();

  @override
  void initState() {
    super.initState();
    _examPrepService.addListener(_onServiceUpdate);
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _examPrepService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subjects = _examPrepService.getActiveSubjects();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Subjects',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          CommonIconButton(
            icon: Icons.archive_rounded,
            onPressed: _showArchivedSubjects,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            iconColor: AppColors.primary,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: subjects.isEmpty
          ? _buildEmptyState(theme)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              itemCount: subjects.length,
              itemBuilder: (context, index) {
                final subject = subjects[index];
                return _buildPremiumSubjectCard(subject, theme, index);
              },
            ),
      floatingActionButton: Container(
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
        child: FloatingActionButton.extended(
          onPressed: _showAddSubjectDialog,
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text(
            'Add Subject',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.school_rounded,
                size: 64,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No subjects yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first subject to start organizing your studies and track your progress',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.getTextSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            CommonButton(
              text: 'Add Subject',
              icon: Icons.add_rounded,
              variant: ButtonVariant.primary,
              onPressed: _showAddSubjectDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumSubjectCard(Subject subject, ThemeData theme, int index) {
    final topics = _examPrepService.getTopicsBySubject(subject.id);
    final exams = _examPrepService.getExamsBySubject(subject.id);
    final upcomingExams = exams.where((e) => e.daysRemaining >= 0).length;
    final color = Color(int.parse(subject.colorHex.replaceAll('#', '0xFF')));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ElevatedCard(
        onTap: () => _showSubjectDetails(subject),
        padding: const EdgeInsets.all(20),
        borderRadius: 20,
        shadowColor: color,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.book_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.getTextPrimary(context),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (subject.teacherName != null)
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline_rounded,
                              size: 16,
                              color: AppColors.getTextSecondary(context),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              subject.teacherName!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.getTextSecondary(context),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                CommonIconButton(
                  icon: Icons.more_vert_rounded,
                  size: 36,
                  iconSize: 18,
                  backgroundColor: AppColors.getGrey100(context),
                  iconColor: AppColors.getTextSecondary(context),
                  onPressed: () => _showSubjectMenu(context, subject),
                ),
                ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildPremiumStatItem(
                    icon: Icons.topic_rounded,
                    label: 'Topics',
                    value: '${topics.length}',
                    color: AppColors.info,
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: AppColors.getDivider(context),
                ),
                Expanded(
                  child: _buildPremiumStatItem(
                    icon: Icons.event_note_rounded,
                    label: 'Exams',
                    value: '$upcomingExams',
                    color: AppColors.warning,
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: AppColors.getDivider(context),
                ),
                Expanded(
                  child: _buildPremiumStatItem(
                    icon: Icons.timer_outlined,
                    label: 'Hours',
                    value: '${subject.studyHours.toStringAsFixed(1)}',
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
            if (subject.currentGrade != null || subject.targetGrade != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    if (subject.currentGrade != null) ...[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Grade',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.getTextSecondary(context),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${subject.currentGrade!.toStringAsFixed(1)}%',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (subject.targetGrade != null) ...[
                      if (subject.currentGrade != null)
                        Container(
                          width: 1,
                          height: 24,
                          color: AppColors.getDivider(context),
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Target Grade',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.getTextSecondary(context),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${subject.targetGrade!.toStringAsFixed(1)}%',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.getGrey50(context),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Weekly Progress',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextPrimary(context),
                        ),
                      ),
                      Text(
                        '${subject.totalStudyMinutes}/${subject.weeklyTargetMinutes} min',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: color.withOpacity(0.1),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: subject.weeklyProgress.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: LinearGradient(
                            colors: [color, color.withOpacity(0.8)],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.getTextPrimary(context),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.getTextSecondary(context),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _showSubjectMenu(BuildContext context, Subject subject) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.getModalBackground(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.getDivider(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(int.parse(subject.colorHex.replaceAll('#', '0xFF'))).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.book_rounded,
                    color: Color(int.parse(subject.colorHex.replaceAll('#', '0xFF'))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextPrimary(context),
                        ),
                      ),
                      Text(
                        'Subject Options',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ListTileCard(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Edit Subject'),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () {
                Navigator.pop(context);
                _showEditSubjectDialog(subject);
              },
            ),
            ListTileCard(
              leading: const Icon(Icons.archive_rounded),
              title: const Text('Archive Subject'),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () {
                Navigator.pop(context);
                _archiveSubject(subject);
              },
            ),
            ListTileCard(
              leading: const Icon(Icons.delete_rounded, color: AppColors.error),
              title: const Text('Delete Subject', style: TextStyle(color: AppColors.error)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.error),
              onTap: () {
                Navigator.pop(context);
                _deleteSubject(subject);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }


  void _showAddSubjectDialog() {
    _showSubjectDialog();
  }

  void _showEditSubjectDialog(Subject subject) {
    _showSubjectDialog(subject: subject);
  }

  void _showSubjectDialog({Subject? subject}) {
    final isEditing = subject != null;
    final nameController = TextEditingController(text: subject?.name ?? '');
    final teacherController = TextEditingController(text: subject?.teacherName ?? '');
    final creditController = TextEditingController(text: subject?.creditHours.toString() ?? '3');
    final targetController = TextEditingController(text: subject?.targetGrade?.toString() ?? '');
    final weeklyTargetController = TextEditingController(
      text: subject?.weeklyTargetMinutes.toString() ?? '120',
    );
    String selectedColor = subject?.colorHex ?? '#4CAF50';

    final colors = [
      '#F44336', '#E91E63', '#9C27B0', '#673AB7',
      '#3F51B5', '#2196F3', '#03A9F4', '#00BCD4',
      '#009688', '#4CAF50', '#8BC34A', '#CDDC39',
      '#FFEB3B', '#FFC107', '#FF9800', '#FF5722',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Edit Subject' : 'Add Subject'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Subject Name *',
                    hintText: 'e.g., Mathematics',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: teacherController,
                  decoration: const InputDecoration(
                    labelText: 'Teacher Name',
                    hintText: 'e.g., Dr. Smith',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: creditController,
                        decoration: const InputDecoration(
                          labelText: 'Credit Hours',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: targetController,
                        decoration: const InputDecoration(
                          labelText: 'Target Grade %',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: weeklyTargetController,
                  decoration: const InputDecoration(
                    labelText: 'Weekly Study Target (minutes)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                const Text('Color'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: colors.map((colorHex) {
                    final color = Color(int.parse(colorHex.replaceAll('#', '0xFF')));
                    final isSelected = selectedColor == colorHex;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = colorHex),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: isSelected
                              ? [BoxShadow(color: color, blurRadius: 8)]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 16)
                            : null,
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
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a subject name')),
                  );
                  return;
                }

                final newSubject = Subject(
                  id: subject?.id ?? const Uuid().v4(),
                  name: nameController.text.trim(),
                  teacherName: teacherController.text.trim().isEmpty
                      ? null
                      : teacherController.text.trim(),
                  colorHex: selectedColor,
                  creditHours: int.tryParse(creditController.text) ?? 3,
                  targetGrade: double.tryParse(targetController.text),
                  weeklyTargetMinutes: int.tryParse(weeklyTargetController.text) ?? 120,
                  totalStudyMinutes: subject?.totalStudyMinutes ?? 0,
                  orderIndex: subject?.orderIndex ?? _examPrepService.subjects.length,
                );

                if (isEditing) {
                  await _examPrepService.updateSubject(newSubject);
                } else {
                  await _examPrepService.createSubject(newSubject);
                }

                if (mounted) Navigator.pop(context);
              },
              child: Text(isEditing ? 'Update' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSubjectDetails(Subject subject) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubjectDetailScreen(subject: subject),
      ),
    );
  }

  void _archiveSubject(Subject subject) async {
    await _examPrepService.updateSubject(subject.copyWith(isArchived: true));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${subject.name} archived'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await _examPrepService.updateSubject(subject.copyWith(isArchived: false));
            },
          ),
        ),
      );
    }
  }

  void _deleteSubject(Subject subject) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Subject'),
        content: Text(
          'Are you sure you want to delete "${subject.name}"? '
          'This will also delete all associated topics and exams.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _examPrepService.deleteSubject(subject.id);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${subject.name} deleted')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showArchivedSubjects() {
    final archived = _examPrepService.subjects.where((s) => s.isArchived).toList();
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Archived Subjects',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (archived.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No archived subjects'),
                ),
              )
            else
              ...archived.map((subject) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Color(
                        int.parse(subject.colorHex.replaceAll('#', '0xFF')),
                      ),
                      child: const Icon(Icons.book, color: Colors.white),
                    ),
                    title: Text(subject.name),
                    trailing: TextButton(
                      onPressed: () async {
                        await _examPrepService.updateSubject(
                          subject.copyWith(isArchived: false),
                        );
                        if (mounted) Navigator.pop(context);
                      },
                      child: const Text('Restore'),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

class SubjectDetailScreen extends StatefulWidget {
  final Subject subject;

  const SubjectDetailScreen({super.key, required this.subject});

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen> {
  final ExamPrepService _examPrepService = ExamPrepService();

  @override
  void initState() {
    super.initState();
    _examPrepService.addListener(_onServiceUpdate);
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _examPrepService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subject = _examPrepService.getSubjectById(widget.subject.id) ?? widget.subject;
    final topics = _examPrepService.getRootTopics(subject.id);
    final color = Color(int.parse(subject.colorHex.replaceAll('#', '0xFF')));

    return Scaffold(
      appBar: AppBar(
        title: Text(subject.name),
        backgroundColor: color.withOpacity(0.1),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Subject Stats
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Study Progress', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn('${subject.studyHours.toStringAsFixed(1)}h', 'Total'),
                      _buildStatColumn('${topics.length}', 'Topics'),
                      _buildStatColumn(
                        '${_examPrepService.getExamsBySubject(subject.id).length}',
                        'Exams',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Topics Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Topics', style: theme.textTheme.titleMedium),
              TextButton.icon(
                onPressed: () => _showAddTopicDialog(subject.id),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (topics.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.topic_outlined, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    const Text('No topics yet'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => _showAddTopicDialog(subject.id),
                      child: const Text('Add Topic'),
                    ),
                  ],
                ),
              ),
            )
          else
            ...topics.map((topic) => _buildTopicCard(topic, theme)),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildTopicCard(Topic topic, ThemeData theme) {
    final childTopics = _examPrepService.getChildTopics(topic.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getStatusColor(topic.status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(topic.status.emoji, style: const TextStyle(fontSize: 20)),
          ),
        ),
        title: Text(topic.name),
        subtitle: Row(
          children: [
            Text('${topic.actualStudyMinutes}/${topic.estimatedMinutes} min'),
            const SizedBox(width: 8),
            Text(topic.difficulty.displayName,
                style: TextStyle(color: _getDifficultyColor(topic.difficulty))),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (topic.isImportantForExam)
              const Icon(Icons.star, color: Colors.amber, size: 20),
            const Icon(Icons.chevron_right),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(value: topic.studyProgress),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildTopicAction(Icons.play_arrow, 'Study', () {
                      _startStudySession(topic);
                    }),
                    _buildTopicAction(Icons.edit, 'Edit', () {
                      _showEditTopicDialog(topic);
                    }),
                    _buildTopicAction(Icons.check, 'Complete', () {
                      _markTopicComplete(topic);
                    }),
                  ],
                ),
                if (childTopics.isNotEmpty) ...[
                  const Divider(),
                  Text('Subtopics (${childTopics.length})',
                      style: theme.textTheme.titleSmall),
                  ...childTopics.map((child) => ListTile(
                        dense: true,
                        leading: Text(child.status.emoji),
                        title: Text(child.name),
                        subtitle: Text('${child.actualStudyMinutes} min'),
                      )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Icon(icon, size: 24),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(TopicStatus status) {
    switch (status) {
      case TopicStatus.not_started:
        return Colors.grey;
      case TopicStatus.in_progress:
        return Colors.blue;
      case TopicStatus.completed:
        return Colors.green;
      case TopicStatus.revision_needed:
        return Colors.orange;
      case TopicStatus.mastered:
        return Colors.purple;
    }
  }

  Color _getDifficultyColor(TopicDifficulty difficulty) {
    switch (difficulty) {
      case TopicDifficulty.easy:
        return Colors.green;
      case TopicDifficulty.medium:
        return Colors.orange;
      case TopicDifficulty.hard:
        return Colors.red;
      case TopicDifficulty.very_hard:
        return Colors.purple;
    }
  }

  void _showAddTopicDialog(String subjectId, {String? parentTopicId}) {
    final nameController = TextEditingController();
    final estimatedController = TextEditingController(text: '30');
    TopicDifficulty difficulty = TopicDifficulty.medium;
    bool isImportant = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Topic'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Topic Name *',
                    hintText: 'e.g., Chapter 1: Introduction',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: estimatedController,
                  decoration: const InputDecoration(
                    labelText: 'Estimated Study Time (minutes)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                const Text('Difficulty'),
                Wrap(
                  spacing: 8,
                  children: TopicDifficulty.values.map((d) {
                    return ChoiceChip(
                      label: Text(d.displayName),
                      selected: difficulty == d,
                      onSelected: (_) => setDialogState(() => difficulty = d),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text('Important for exam'),
                  value: isImportant,
                  onChanged: (v) => setDialogState(() => isImportant = v ?? false),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;

                await _examPrepService.createTopic(Topic(
                  id: const Uuid().v4(),
                  name: nameController.text.trim(),
                  subjectId: subjectId,
                  parentTopicId: parentTopicId,
                  difficulty: difficulty,
                  estimatedMinutes: int.tryParse(estimatedController.text) ?? 30,
                  isImportantForExam: isImportant,
                ));

                if (mounted) Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTopicDialog(Topic topic) {
    // Similar to add dialog but with existing values
  }

  void _startStudySession(Topic topic) {
    _examPrepService.startStudySession(
      subjectId: topic.subjectId,
      topicId: topic.id,
    );
    Navigator.pop(context);
  }

  void _markTopicComplete(Topic topic) async {
    await _examPrepService.updateTopic(
      topic.copyWith(status: TopicStatus.completed),
    );
  }
}
