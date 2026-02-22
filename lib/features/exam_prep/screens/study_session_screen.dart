import 'package:flutter/material.dart';
import '../services/exam_prep_service.dart';
import '../models/study_session_model.dart';
import '../models/topic_model.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';

class StudySessionScreen extends StatefulWidget {
  final String? subjectId;
  final String? topicId;
  final String? examId;

  const StudySessionScreen({
    super.key,
    this.subjectId,
    this.topicId,
    this.examId,
  });

  @override
  State<StudySessionScreen> createState() => _StudySessionScreenState();
}

class _StudySessionScreenState extends State<StudySessionScreen>
    with TickerProviderStateMixin {
  final ExamPrepService _examPrepService = ExamPrepService();
  
  String? _selectedSubjectId;
  String? _selectedTopicId;
  StudySessionType _sessionType = StudySessionType.pomodoro;
  int _selectedMinutes = 25;
  
  late AnimationController _pulseController;

  final List<int> _presetMinutes = [15, 25, 45, 60, 90];

  @override
  void initState() {
    super.initState();
    _selectedSubjectId = widget.subjectId;
    _selectedTopicId = widget.topicId;
    _examPrepService.addListener(_onServiceUpdate);
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  void _onServiceUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _examPrepService.removeListener(_onServiceUpdate);
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasActiveSession = _examPrepService.hasActiveSession;

    return Scaffold(
      appBar: AppBar(
        title: Text(hasActiveSession ? 'Study Session' : 'Start Study'),
        actions: [
          if (hasActiveSession)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _showEndSessionDialog,
              tooltip: 'End Session',
            ),
        ],
      ),
      body: hasActiveSession ? _buildActiveSession(theme) : _buildSessionSetup(theme),
    );
  }

  Widget _buildSessionSetup(ThemeData theme) {
    final subjects = _examPrepService.getActiveSubjects();
    final topics = _selectedSubjectId != null
        ? _examPrepService.getTopicsBySubject(_selectedSubjectId!)
        : <Topic>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Session Type Selection
          Text('Session Type', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: StudySessionType.values.map((type) {
              final isSelected = _sessionType == type;
              return ChoiceChip(
                label: Text('${type.emoji} ${type.displayName}'),
                selected: isSelected,
                onSelected: (_) => setState(() => _sessionType = type),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Duration Selection
          Text('Duration', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: _presetMinutes.map((mins) {
              final isSelected = _selectedMinutes == mins;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text('$mins'),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedMinutes = mins),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Custom: '),
              Expanded(
                child: Slider(
                  value: _selectedMinutes.toDouble(),
                  min: 5,
                  max: 180,
                  divisions: 35,
                  label: '$_selectedMinutes min',
                  onChanged: (value) => setState(() => _selectedMinutes = value.toInt()),
                ),
              ),
              Text('$_selectedMinutes min'),
            ],
          ),
          const SizedBox(height: 24),

          // Subject Selection (Optional)
          Text('Subject (Optional)', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            value: _selectedSubjectId,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.book),
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('No specific subject'),
              ),
              ...subjects.map((subject) => DropdownMenuItem(
                    value: subject.id,
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
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
            onChanged: (value) => setState(() {
              _selectedSubjectId = value;
              _selectedTopicId = null;
            }),
          ),
          const SizedBox(height: 16),

          // Topic Selection (if subject selected)
          if (_selectedSubjectId != null && topics.isNotEmpty) ...[
            Text('Topic (Optional)', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: _selectedTopicId,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.topic),
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('No specific topic'),
                ),
                ...topics.map((topic) => DropdownMenuItem(
                      value: topic.id,
                      child: Text(topic.name),
                    )),
              ],
              onChanged: (value) => setState(() => _selectedTopicId = value),
            ),
            const SizedBox(height: 24),
          ],

          // Start Button
          SizedBox(
            width: double.infinity,
            child: CommonButton(
              text: 'Start $_selectedMinutes min Session',
              variant: ButtonVariant.primary,
              onPressed: _startSession,
            ),
          ),
          const SizedBox(height: 24),

          // Quick Tips
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lightbulb_outline, color: Colors.amber),
                      const SizedBox(width: 8),
                      Text('Study Tips', style: theme.textTheme.titleSmall),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('• Find a quiet place to study'),
                  const Text('• Put your phone on silent'),
                  const Text('• Take short breaks between sessions'),
                  const Text('• Stay hydrated'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSession(ThemeData theme) {
    final session = _examPrepService.activeSession;
    final remainingSeconds = _examPrepService.remainingSeconds;
    final mins = remainingSeconds ~/ 60;
    final secs = remainingSeconds % 60;
    
    final subject = session?.subjectId != null
        ? _examPrepService.getSubjectById(session!.subjectId!)
        : null;
    final topic = session?.topicId != null
        ? _examPrepService.getTopicById(session!.topicId!)
        : null;

    final progress = session != null && session.plannedMinutes > 0
        ? 1 - (remainingSeconds / (session.plannedMinutes * 60))
        : 0.0;

    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Session Type
                Text(
                  session?.sessionType.emoji ?? '📚',
                  style: const TextStyle(fontSize: 48),
                ),
                const SizedBox(height: 8),
                Text(
                  session?.sessionType.displayName ?? 'Study Session',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 32),

                // Timer
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(
                            0.3 + (_pulseController.value * 0.2),
                          ),
                          width: 8,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}',
                              style: theme.textTheme.displayLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'remaining',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),

                // Progress Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(progress * 100).toInt()}% complete',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Subject/Topic Info
                if (subject != null || topic != null)
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (subject != null) ...[
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Color(int.parse(
                                    subject.colorHex.replaceAll('#', '0xFF'))),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(subject.name),
                          ],
                          if (topic != null) ...[
                            const Text(' • '),
                            Text(topic.name),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Control Buttons
        Padding(
          padding: const EdgeInsets.all(32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Pause/Resume Button
              CommonButton(
                text: _examPrepService.isPaused ? 'Resume' : 'Pause',
                variant: _examPrepService.isPaused ? ButtonVariant.success : ButtonVariant.secondary,
                onPressed: () {
                  _examPrepService.togglePauseResume();
                },
              ),
              // End Session Button
              CommonButton(
                text: 'End Session',
                variant: ButtonVariant.primary,
                onPressed: _showEndSessionDialog,
              ),
              // Abandon Button
              CommonButton(
                text: 'Abandon',
                variant: ButtonVariant.danger,
                onPressed: _showAbandonDialog,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _startSession() async {
    await _examPrepService.startStudySession(
      subjectId: _selectedSubjectId,
      topicId: _selectedTopicId,
      examId: widget.examId,
      sessionType: _sessionType,
      plannedMinutes: _selectedMinutes,
    );
  }

  void _showEndSessionDialog() {
    SessionQuality? selectedQuality;
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('End Session'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('How was your study session?'),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: SessionQuality.values.map((quality) {
                    final isSelected = selectedQuality == quality;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedQuality = quality),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                                  : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: isSelected
                                  ? Border.all(
                                      color: Theme.of(context).colorScheme.primary,
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: Text(
                              quality.emoji,
                              style: const TextStyle(fontSize: 32),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            quality.displayName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : null,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    hintText: 'What did you learn?',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            CommonButton(
              text: 'Cancel',
              variant: ButtonVariant.secondary,
              onPressed: () => Navigator.pop(context),
            ),
            CommonButton(
              text: 'Complete Session',
              variant: ButtonVariant.primary,
              onPressed: () async {
                await _examPrepService.endStudySession(
                  wasCompleted: true,
                  quality: selectedQuality,
                  notes: notesController.text.trim().isEmpty
                      ? null
                      : notesController.text.trim(),
                );
                if (mounted) {
                  Navigator.pop(context);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Great job! Session completed! 🎉'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAbandonDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abandon Session?'),
        content: const Text(
          'Are you sure you want to abandon this session? '
          'Your progress will still be saved.',
        ),
        actions: [
          CommonButton(
            text: 'Continue Studying',
            variant: ButtonVariant.secondary,
            onPressed: () => Navigator.pop(context),
          ),
          CommonButton(
            text: 'Abandon',
            variant: ButtonVariant.danger,
            onPressed: () async {
              await _examPrepService.endStudySession(wasCompleted: false);
              if (mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }
}
