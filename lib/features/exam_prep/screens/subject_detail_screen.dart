import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../models/study_subject.dart';
import '../services/exam_prep_service.dart';

class SubjectDetailScreen extends StatefulWidget {
  final StudySubject subject;
  
  const SubjectDetailScreen({super.key, required this.subject});

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen> {
  final ExamPrepService _service = ExamPrepService();
  final _topicController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _service,
      builder: (context, _) {
        final subject = _service.subjects.firstWhere(
          (s) => s.id == widget.subject.id,
          orElse: () => widget.subject,
        );
        
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(subject.name),
            actions: [
              IconButton(
                onPressed: () => _showEditSheet(subject),
                icon: const Icon(Icons.edit_rounded),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProgressCard(subject),
                const SizedBox(height: 24),
                _buildTopicsSection(subject),
                const SizedBox(height: 24),
                _buildConfidenceSlider(subject),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressCard(StudySubject subject) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [subject.color, subject.color.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${subject.completedHours}',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'of ${subject.targetHours} hours',
                    style: TextStyle(color: Colors.white.withOpacity(0.9)),
                  ),
                ],
              ),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${(subject.progressPercent * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: subject.progressPercent,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicsSection(StudySubject subject) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Topics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              '${subject.completedTopics}/${subject.topics.length}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _topicController,
                decoration: const InputDecoration(
                  hintText: 'Add topic...',
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: (_) => _addTopic(subject),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => _addTopic(subject),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: subject.color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...subject.topics.map((topic) {
          final isCompleted = subject.topicCompletion[topic] ?? false;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              onTap: () => _service.toggleTopicCompletion(subject.id, topic),
              leading: Icon(
                isCompleted ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: isCompleted ? AppColors.success : Colors.grey,
              ),
              title: Text(
                topic,
                style: TextStyle(
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                  color: isCompleted ? AppColors.textSecondary : AppColors.textPrimary,
                ),
              ),
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildConfidenceSlider(StudySubject subject) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Confidence Level',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                '${(subject.confidence * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: subject.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: subject.color,
              inactiveTrackColor: subject.color.withOpacity(0.2),
              thumbColor: subject.color,
            ),
            child: Slider(
              value: subject.confidence,
              onChanged: (value) {
                _service.updateSubject(subject.copyWith(confidence: value));
              },
            ),
          ),
        ],
      ),
    );
  }

  void _addTopic(StudySubject subject) {
    final topic = _topicController.text.trim();
    if (topic.isNotEmpty && !subject.topics.contains(topic)) {
      final newTopics = [...subject.topics, topic];
      _service.updateSubject(subject.copyWith(topics: newTopics));
      _topicController.clear();
    }
  }

  void _showEditSheet(StudySubject subject) {
    final nameController = TextEditingController(text: subject.name);
    final hoursController = TextEditingController(text: subject.targetHours.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Subject Name'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: hoursController,
                decoration: const InputDecoration(labelText: 'Target Hours'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _service.deleteSubject(subject.id);
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                      child: const Text('Delete'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _service.updateSubject(subject.copyWith(
                          name: nameController.text,
                          targetHours: int.tryParse(hoursController.text) ?? 50,
                        ));
                        Navigator.pop(context);
                      },
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
