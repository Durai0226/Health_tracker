import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../models/study_subject.dart';
import '../models/study_session.dart';
import '../services/exam_prep_service.dart';

class StudySessionScreen extends StatefulWidget {
  final StudyType? initialStudyType;
  
  const StudySessionScreen({super.key, this.initialStudyType});

  @override
  State<StudySessionScreen> createState() => _StudySessionScreenState();
}

class _StudySessionScreenState extends State<StudySessionScreen> {
  final ExamPrepService _service = ExamPrepService();
  
  StudySubject? _selectedSubject;
  StudyType _selectedType = StudyType.reading;
  String? _selectedTopic;
  
  bool _isRunning = false;
  bool _isPaused = false;
  int _elapsedSeconds = 0;
  Timer? _timer;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    if (widget.initialStudyType != null) {
      _selectedType = widget.initialStudyType!;
    }
    final subjects = _service.activeExamId != null 
        ? _service.getSubjectsForExam(_service.activeExamId!)
        : <StudySubject>[];
    if (subjects.isNotEmpty) {
      _selectedSubject = subjects.first;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isRunning) {
          _showExitConfirmation();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Study Session'),
          leading: IconButton(
            onPressed: () {
              if (_isRunning) {
                _showExitConfirmation();
              } else {
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.close_rounded),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTimerDisplay(),
              const SizedBox(height: 32),
              if (!_isRunning) ...[
                _buildSubjectSelector(),
                const SizedBox(height: 20),
                _buildStudyTypeSelector(),
                const SizedBox(height: 20),
                if (_selectedSubject != null && _selectedSubject!.topics.isNotEmpty)
                  _buildTopicSelector(),
              ],
              const SizedBox(height: 32),
              _buildControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimerDisplay() {
    final hours = _elapsedSeconds ~/ 3600;
    final minutes = (_elapsedSeconds % 3600) ~/ 60;
    final seconds = _elapsedSeconds % 60;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _selectedSubject?.color ?? AppColors.primary,
            (_selectedSubject?.color ?? AppColors.primary).withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: (_selectedSubject?.color ?? AppColors.primary).withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          if (_selectedSubject != null) ...[
            Text(
              _selectedSubject!.name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
            style: const TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_selectedType.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  _selectedType.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectSelector() {
    final subjects = _service.activeExamId != null 
        ? _service.getSubjectsForExam(_service.activeExamId!)
        : <StudySubject>[];
    
    if (subjects.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('Please add subjects first'),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Subject',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: subjects.map((subject) {
            final isSelected = _selectedSubject?.id == subject.id;
            return GestureDetector(
              onTap: () => setState(() {
                _selectedSubject = subject;
                _selectedTopic = null;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? subject.color : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? subject.color : Colors.grey.shade200,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: subject.color.withOpacity(0.3), blurRadius: 8)]
                      : null,
                ),
                child: Text(
                  subject.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStudyTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Study Type',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: StudyType.values.map((type) {
            final isSelected = _selectedType == type;
            return GestureDetector(
              onTap: () => setState(() => _selectedType = type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(type.emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      type.name,
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

  Widget _buildTopicSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Topic (Optional)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _selectedSubject!.topics.map((topic) {
            final isSelected = _selectedTopic == topic;
            final isCompleted = _selectedSubject!.topicCompletion[topic] ?? false;
            return GestureDetector(
              onTap: () => setState(() => _selectedTopic = isSelected ? null : topic),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? _selectedSubject!.color.withOpacity(0.15)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: isSelected 
                      ? Border.all(color: _selectedSubject!.color)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isCompleted)
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: AppColors.success,
                      ),
                    if (isCompleted) const SizedBox(width: 4),
                    Text(
                      topic,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? _selectedSubject!.color : AppColors.textPrimary,
                        decoration: isCompleted ? TextDecoration.lineThrough : null,
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

  Widget _buildControls() {
    if (!_isRunning) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _selectedSubject != null ? _startSession : null,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Start Studying'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isPaused ? _resumeSession : _pauseSession,
            icon: Icon(_isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
            label: Text(_isPaused ? 'Resume' : 'Pause'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _finishSession,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Finish'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  void _startSession() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isRunning = true;
      _isPaused = false;
      _elapsedSeconds = 0;
      _startTime = DateTime.now();
    });
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        setState(() => _elapsedSeconds++);
      }
    });
  }

  void _pauseSession() {
    HapticFeedback.lightImpact();
    setState(() => _isPaused = true);
  }

  void _resumeSession() {
    HapticFeedback.lightImpact();
    setState(() => _isPaused = false);
  }

  void _finishSession() {
    _timer?.cancel();
    
    if (_elapsedSeconds < 60) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session too short (minimum 1 minute)'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        _isRunning = false;
        _elapsedSeconds = 0;
      });
      return;
    }

    _showProductivityRating();
  }

  void _showProductivityRating() {
    int rating = 3;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'How productive was this session?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final isSelected = index < rating;
                  return GestureDetector(
                    onTap: () => setState(() => rating = index + 1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: isSelected ? AppColors.warning : Colors.grey,
                        size: 40,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _saveSession(rating);
                  },
                  child: const Text('Save Session'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveSession(int rating) {
    final session = StudySession(
      id: _service.generateId(),
      examId: _service.activeExamId!,
      subjectId: _selectedSubject!.id,
      topicName: _selectedTopic,
      startTime: _startTime!,
      endTime: DateTime.now(),
      durationMinutes: _elapsedSeconds ~/ 60,
      type: _selectedType,
      productivityRating: rating,
    );

    _service.addStudySession(session);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Session saved: ${_elapsedSeconds ~/ 60} minutes'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
      ),
    );
    
    Navigator.pop(context);
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Session?'),
        content: const Text('Your current progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue Studying'),
          ),
          TextButton(
            onPressed: () {
              _timer?.cancel();
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }
}
