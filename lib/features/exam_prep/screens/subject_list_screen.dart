import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
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
        title: const Text('Subjects'),
        actions: [
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            onPressed: _showArchivedSubjects,
            tooltip: 'Archived',
          ),
        ],
      ),
      body: subjects.isEmpty
          ? _buildEmptyState(theme)
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: subjects.length,
              onReorder: _reorderSubjects,
              itemBuilder: (context, index) {
                final subject = subjects[index];
                return _buildSubjectCard(subject, theme, key: ValueKey(subject.id));
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSubjectDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Subject'),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No subjects yet',
            style: theme.textTheme.titleLarge?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first subject to start organizing your studies',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddSubjectDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Subject'),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectCard(Subject subject, ThemeData theme, {Key? key}) {
    final topics = _examPrepService.getTopicsBySubject(subject.id);
    final exams = _examPrepService.getExamsBySubject(subject.id);
    final upcomingExams = exams.where((e) => e.daysRemaining >= 0).length;
    final color = Color(int.parse(subject.colorHex.replaceAll('#', '0xFF')));

    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showSubjectDetails(subject),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.book, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (subject.teacherName != null)
                          Text(
                            subject.teacherName!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  ),
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'archive',
                        child: Row(
                          children: [
                            Icon(Icons.archive),
                            SizedBox(width: 8),
                            Text('Archive'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          _showEditSubjectDialog(subject);
                          break;
                        case 'archive':
                          _archiveSubject(subject);
                          break;
                        case 'delete':
                          _deleteSubject(subject);
                          break;
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildStatChip(
                    icon: Icons.topic,
                    label: '${topics.length} topics',
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  _buildStatChip(
                    icon: Icons.event,
                    label: '$upcomingExams exams',
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  _buildStatChip(
                    icon: Icons.timer,
                    label: '${subject.studyHours.toStringAsFixed(1)}h',
                    color: Colors.green,
                  ),
                ],
              ),
              if (subject.currentGrade != null || subject.targetGrade != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (subject.currentGrade != null)
                      Text(
                        'Current: ${subject.currentGrade!.toStringAsFixed(1)}%',
                        style: theme.textTheme.bodySmall,
                      ),
                    if (subject.currentGrade != null && subject.targetGrade != null)
                      const Text(' • '),
                    if (subject.targetGrade != null)
                      Text(
                        'Target: ${subject.targetGrade!.toStringAsFixed(1)}%',
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: subject.weeklyProgress,
                backgroundColor: Colors.grey.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
              const SizedBox(height: 4),
              Text(
                'Weekly: ${subject.totalStudyMinutes} / ${subject.weeklyTargetMinutes} min',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }

  void _reorderSubjects(int oldIndex, int newIndex) async {
    final subjects = _examPrepService.getActiveSubjects();
    if (newIndex > oldIndex) newIndex--;
    
    final subject = subjects[oldIndex];
    await _examPrepService.updateSubject(
      subject.copyWith(orderIndex: newIndex),
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
