import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/fitness_theme.dart';
import '../widgets/fitness_card.dart';
import '../widgets/fitness_button.dart';
import '../widgets/fitness_progress_ring.dart';
import '../models/workout_challenge.dart';
import '../data/challenge_library.dart';
import '../services/fitness_storage_service.dart';
import 'fitness_workout_detail_screen.dart';

class FitnessChallengeScreen extends StatefulWidget {
  const FitnessChallengeScreen({super.key});

  @override
  State<FitnessChallengeScreen> createState() => _FitnessChallengeScreenState();
}

class _FitnessChallengeScreenState extends State<FitnessChallengeScreen> {
  final ChallengeLibrary _challengeLib = ChallengeLibrary();
  final FitnessStorageService _storage = FitnessStorageService();
  
  ChallengeProgress? _activeChallenge;
  List<ChallengeProgress> _completedChallenges = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final active = await _storage.getActiveChallengeProgress();
    final completed = await _storage.getCompletedChallenges();
    
    if (mounted) {
      setState(() {
        _activeChallenge = active;
        _completedChallenges = completed;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: FitnessTheme.themeData,
      child: Scaffold(
        backgroundColor: FitnessTheme.background,
        appBar: AppBar(
          backgroundColor: FitnessTheme.background,
          title: const Text('30-Day Challenges', style: FitnessTheme.headingSm),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: FitnessTheme.primary))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(FitnessTheme.spacingMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_activeChallenge != null) ...[
                      _buildActiveChallenge(),
                      const SizedBox(height: FitnessTheme.spacingLg),
                    ],
                    _buildAvailableChallenges(),
                    const SizedBox(height: FitnessTheme.spacingLg),
                    if (_completedChallenges.isNotEmpty) ...[
                      _buildCompletedChallenges(),
                    ],
                    const SizedBox(height: 50),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildActiveChallenge() {
    final challenge = _challengeLib.getById(_activeChallenge!.challengeId);
    if (challenge == null) return const SizedBox.shrink();

    final progress = _activeChallenge!;
    final completedDays = progress.completedDays.length;
    final progressPercent = completedDays / challenge.durationDays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.local_fire_department, color: FitnessTheme.warning, size: 20),
            const SizedBox(width: 8),
            Text('Active Challenge', style: FitnessTheme.titleLg),
          ],
        ),
        const SizedBox(height: FitnessTheme.spacingMd),
        FitnessCard(
          backgroundColor: FitnessTheme.primary.withValues(alpha: 0.1),
          borderColor: FitnessTheme.primary.withValues(alpha: 0.3),
          onTap: () => _openChallengeDetail(challenge, progress),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(challenge.name, style: FitnessTheme.titleLg),
                        const SizedBox(height: 4),
                        Text(
                          'Day ${progress.currentDay} of ${challenge.durationDays}',
                          style: FitnessTheme.bodySm,
                        ),
                      ],
                    ),
                  ),
                  AnimatedProgressRing(
                    progress: progressPercent,
                    size: 60,
                    strokeWidth: 5,
                    child: Text(
                      '${(progressPercent * 100).toInt()}%',
                      style: FitnessTheme.titleSm.copyWith(color: FitnessTheme.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: FitnessTheme.spacingMd),
              // Progress dots
              _buildProgressDots(challenge.durationDays, progress.completedDays),
              const SizedBox(height: FitnessTheme.spacingMd),
              FitnessPrimaryButton(
                text: 'Continue Day ${progress.currentDay}',
                icon: Icons.play_arrow,
                onPressed: () => _startDay(challenge, progress.currentDay),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressDots(int totalDays, List<int> completedDays) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: List.generate(totalDays, (index) {
        final day = index + 1;
        final isCompleted = completedDays.contains(day);
        final isCurrent = day == (_activeChallenge?.currentDay ?? 1);
        
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: isCompleted 
                ? FitnessTheme.success 
                : isCurrent 
                    ? FitnessTheme.primary 
                    : FitnessTheme.surface,
            shape: BoxShape.circle,
            border: isCurrent ? Border.all(color: FitnessTheme.primary, width: 2) : null,
          ),
          child: Center(
            child: isCompleted 
                ? const Icon(Icons.check, size: 12, color: Colors.white)
                : Text(
                    '$day',
                    style: FitnessTheme.caption.copyWith(
                      fontSize: 8,
                      color: isCurrent ? FitnessTheme.textOnPrimary : FitnessTheme.textMuted,
                    ),
                  ),
          ),
        );
      }),
    );
  }

  Widget _buildAvailableChallenges() {
    final challenges = _challengeLib.allChallenges;
    final activeId = _activeChallenge?.challengeId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Available Challenges', style: FitnessTheme.titleLg),
        const SizedBox(height: FitnessTheme.spacingMd),
        ...challenges.where((c) => c.id != activeId).map((challenge) {
          return _buildChallengeCard(challenge);
        }),
      ],
    );
  }

  Widget _buildChallengeCard(WorkoutChallenge challenge) {
    final categoryColor = _getCategoryColor(challenge.category);

    return FitnessCard(
      margin: const EdgeInsets.only(bottom: FitnessTheme.spacingMd),
      onTap: () => _showChallengeInfo(challenge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.2),
                  borderRadius: FitnessTheme.borderRadiusSm,
                ),
                child: Center(
                  child: Text(
                    challenge.category.emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: FitnessTheme.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(challenge.name, style: FitnessTheme.titleMd),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        _buildTag(challenge.difficulty.displayName, 
                            FitnessTheme.getDifficultyColor(challenge.difficulty.displayName)),
                        const SizedBox(width: 8),
                        _buildTag('${challenge.durationDays} days', FitnessTheme.info),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: FitnessTheme.textMuted),
            ],
          ),
          const SizedBox(height: FitnessTheme.spacingSm),
          Text(
            challenge.description,
            style: FitnessTheme.bodySm,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: FitnessTheme.borderRadiusSm,
      ),
      child: Text(
        text,
        style: FitnessTheme.caption.copyWith(color: color, fontSize: 10),
      ),
    );
  }

  Widget _buildCompletedChallenges() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.emoji_events, color: FitnessTheme.success, size: 20),
            const SizedBox(width: 8),
            Text('Completed', style: FitnessTheme.titleLg),
          ],
        ),
        const SizedBox(height: FitnessTheme.spacingMd),
        ..._completedChallenges.map((progress) {
          final challenge = _challengeLib.getById(progress.challengeId);
          if (challenge == null) return const SizedBox.shrink();

          return FitnessCard(
            margin: const EdgeInsets.only(bottom: FitnessTheme.spacingSm),
            backgroundColor: FitnessTheme.success.withValues(alpha: 0.1),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: FitnessTheme.success.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: FitnessTheme.success),
                ),
                const SizedBox(width: FitnessTheme.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(challenge.name, style: FitnessTheme.titleSm),
                      Text(
                        'Completed ${_formatDate(progress.completedAt!)}',
                        style: FitnessTheme.caption,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${progress.totalCaloriesBurned}',
                      style: FitnessTheme.titleSm.copyWith(color: FitnessTheme.warning),
                    ),
                    Text('cal burned', style: FitnessTheme.caption),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Color _getCategoryColor(ChallengeCategory category) {
    switch (category) {
      case ChallengeCategory.weightLoss:
        return FitnessTheme.warning;
      case ChallengeCategory.muscleBuilding:
        return FitnessTheme.primary;
      case ChallengeCategory.flexibility:
        return FitnessTheme.info;
      case ChallengeCategory.endurance:
        return FitnessTheme.error;
      case ChallengeCategory.fullBody:
        return FitnessTheme.primary;
      case ChallengeCategory.abs:
        return FitnessTheme.warning;
      case ChallengeCategory.legs:
        return FitnessTheme.success;
      case ChallengeCategory.arms:
        return FitnessTheme.info;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showChallengeInfo(WorkoutChallenge challenge) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: FitnessTheme.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(FitnessTheme.radiusLg)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: FitnessTheme.spacingSm),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: FitnessTheme.textMuted,
                  borderRadius: FitnessTheme.borderRadiusRound,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(FitnessTheme.spacingLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(challenge.name, style: FitnessTheme.headingMd),
                      const SizedBox(height: FitnessTheme.spacingSm),
                      Text(challenge.description, style: FitnessTheme.bodyMd),
                      const SizedBox(height: FitnessTheme.spacingLg),
                      // Stats
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(Icons.calendar_today, '${challenge.durationDays}', 'Days'),
                          _buildStatItem(Icons.local_fire_department, '${challenge.estimatedCaloriesTotal}', 'Calories'),
                          _buildStatItem(Icons.speed, challenge.difficulty.displayName, 'Level'),
                        ],
                      ),
                      const SizedBox(height: FitnessTheme.spacingLg),
                      // Benefits
                      Text('Benefits', style: FitnessTheme.titleLg),
                      const SizedBox(height: FitnessTheme.spacingSm),
                      ...challenge.benefits.map((benefit) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: FitnessTheme.success, size: 18),
                            const SizedBox(width: 8),
                            Text(benefit, style: FitnessTheme.bodyMd),
                          ],
                        ),
                      )),
                      const SizedBox(height: FitnessTheme.spacingLg),
                      FitnessPrimaryButton(
                        text: 'Start Challenge',
                        icon: Icons.play_arrow,
                        onPressed: () {
                          Navigator.pop(context);
                          _startChallenge(challenge);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: FitnessTheme.primary),
        const SizedBox(height: 4),
        Text(value, style: FitnessTheme.titleMd),
        Text(label, style: FitnessTheme.caption),
      ],
    );
  }

  void _startChallenge(WorkoutChallenge challenge) async {
    if (_activeChallenge != null) {
      final shouldReplace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: FitnessTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: FitnessTheme.borderRadiusLg),
          title: Text('Replace Current Challenge?', style: FitnessTheme.headingSm),
          content: Text(
            'You already have an active challenge. Starting a new one will replace your current progress.',
            style: FitnessTheme.bodyMd,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: FitnessTheme.textMuted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Replace', style: TextStyle(color: FitnessTheme.primary)),
            ),
          ],
        ),
      );
      if (shouldReplace != true) return;
    }

    final progress = ChallengeProgress(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      challengeId: challenge.id,
      startedAt: DateTime.now(),
      currentDay: 1,
    );

    await _storage.saveChallengeProgress(progress);
    HapticFeedback.mediumImpact();
    _loadData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Challenge started! Day 1 begins now.'),
          backgroundColor: FitnessTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openChallengeDetail(WorkoutChallenge challenge, ChallengeProgress progress) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ChallengeDetailScreen(
          challenge: challenge,
          progress: progress,
          onDayCompleted: () => _loadData(),
        ),
      ),
    );
  }

  void _startDay(WorkoutChallenge challenge, int day) async {
    final challengeDay = challenge.days.firstWhere(
      (d) => d.dayNumber == day,
      orElse: () => challenge.days.first,
    );

    if (challengeDay.isRestDay) {
      _showRestDayDialog(day);
      return;
    }

    if (challengeDay.workoutId != null) {
      final workout = await _storage.getWorkoutById(challengeDay.workoutId!);
      if (workout != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FitnessWorkoutDetailScreen(workout: workout),
          ),
        );
      }
    }
  }

  void _showRestDayDialog(int day) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FitnessTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: FitnessTheme.borderRadiusLg),
        title: Row(
          children: [
            const Icon(Icons.self_improvement, color: FitnessTheme.info),
            const SizedBox(width: 8),
            Text('Rest Day', style: FitnessTheme.headingSm),
          ],
        ),
        content: Text(
          'Today is a rest day! Your body needs recovery to grow stronger. Focus on light stretching and staying hydrated.',
          style: FitnessTheme.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _markDayComplete(day);
              Navigator.pop(context);
            },
            child: Text('Mark as Complete', style: TextStyle(color: FitnessTheme.primary)),
          ),
        ],
      ),
    );
  }

  Future<void> _markDayComplete(int day) async {
    if (_activeChallenge == null) return;

    final updated = _activeChallenge!.copyWith(
      completedDays: [..._activeChallenge!.completedDays, day],
      currentDay: day + 1,
    );

    await _storage.saveChallengeProgress(updated);
    HapticFeedback.mediumImpact();
    _loadData();
  }
}

// Challenge Detail Screen
class _ChallengeDetailScreen extends StatelessWidget {
  final WorkoutChallenge challenge;
  final ChallengeProgress progress;
  final VoidCallback onDayCompleted;

  const _ChallengeDetailScreen({
    required this.challenge,
    required this.progress,
    required this.onDayCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: FitnessTheme.themeData,
      child: Scaffold(
        backgroundColor: FitnessTheme.background,
        appBar: AppBar(
          backgroundColor: FitnessTheme.background,
          title: Text(challenge.name, style: FitnessTheme.headingSm),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: ListView.builder(
          padding: const EdgeInsets.all(FitnessTheme.spacingMd),
          itemCount: challenge.days.length,
          itemBuilder: (context, index) {
            final day = challenge.days[index];
            final isCompleted = progress.completedDays.contains(day.dayNumber);
            final isCurrent = day.dayNumber == progress.currentDay;
            final isLocked = day.dayNumber > progress.currentDay;

            return FitnessCard(
              margin: const EdgeInsets.only(bottom: FitnessTheme.spacingSm),
              backgroundColor: isCompleted 
                  ? FitnessTheme.success.withValues(alpha: 0.1)
                  : isCurrent 
                      ? FitnessTheme.primary.withValues(alpha: 0.1)
                      : null,
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isCompleted 
                          ? FitnessTheme.success 
                          : isCurrent 
                              ? FitnessTheme.primary 
                              : FitnessTheme.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: isCompleted 
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : Text(
                              '${day.dayNumber}',
                              style: FitnessTheme.titleSm.copyWith(
                                color: isCurrent ? FitnessTheme.textOnPrimary : FitnessTheme.textMuted,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: FitnessTheme.spacingMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(day.title, style: FitnessTheme.titleSm),
                        if (day.description != null)
                          Text(day.description!, style: FitnessTheme.caption),
                      ],
                    ),
                  ),
                  if (!day.isRestDay && !isLocked)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${day.estimatedMinutes} min', style: FitnessTheme.caption),
                        Text('${day.estimatedCalories} cal', style: FitnessTheme.caption),
                      ],
                    ),
                  if (isLocked)
                    const Icon(Icons.lock, color: FitnessTheme.textMuted, size: 18),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
