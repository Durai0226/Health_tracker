import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/mood_theme.dart';
import '../models/mood_type.dart';
import '../models/mood_entry.dart';
import '../services/mood_firestore_service.dart';
import '../services/mood_notification_service.dart';
import '../widgets/bloom_glass_container.dart';
import '../widgets/mood_emoji_widget.dart';
import '../widgets/mood_intensity_slider.dart';
import '../widgets/mood_activity_chips.dart';

/// Mood entry screen for logging a new mood
class BloomMoodEntryScreen extends StatefulWidget {
  final MoodType? initialMood;
  final MoodEntry? editEntry;

  const BloomMoodEntryScreen({
    super.key,
    this.initialMood,
    this.editEntry,
  });

  @override
  State<BloomMoodEntryScreen> createState() => _BloomMoodEntryScreenState();
}

class _BloomMoodEntryScreenState extends State<BloomMoodEntryScreen>
    with TickerProviderStateMixin {
  final MoodFirestoreService _firestoreService = MoodFirestoreService();
  final MoodNotificationService _notificationService = MoodNotificationService();
  final TextEditingController _noteController = TextEditingController();
  final PageController _pageController = PageController();

  MoodType? _selectedMood;
  int _intensity = 3;
  List<ActivityType> _selectedActivities = [];
  int _currentPage = 0;
  bool _isSaving = false;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initData();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  void _initData() {
    if (widget.editEntry != null) {
      _selectedMood = widget.editEntry!.mood;
      _intensity = widget.editEntry!.intensity;
      _selectedActivities = List.from(widget.editEntry!.activities);
      _noteController.text = widget.editEntry!.note ?? '';
    } else if (widget.initialMood != null) {
      _selectedMood = widget.initialMood;
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _noteController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    HapticFeedback.selectionClick();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: MoodTheme.animationNormal,
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: MoodTheme.animationNormal,
        curve: Curves.easeOutCubic,
      );
    }
  }

  bool get _canProceed {
    switch (_currentPage) {
      case 0:
        return _selectedMood != null;
      case 1:
        return true; // Intensity always has a value
      case 2:
        return true; // Activities are optional
      default:
        return false;
    }
  }

  Future<void> _saveEntry() async {
    if (_selectedMood == null) return;

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final entry = widget.editEntry != null
          ? widget.editEntry!.copyWith(
              mood: _selectedMood,
              intensity: _intensity,
              activities: _selectedActivities,
              note: _noteController.text.trim().isEmpty
                  ? null
                  : _noteController.text.trim(),
            )
          : MoodEntry.create(
              mood: _selectedMood!,
              intensity: _intensity,
              activities: _selectedActivities,
              note: _noteController.text.trim().isEmpty
                  ? null
                  : _noteController.text.trim(),
            );

      if (widget.editEntry != null) {
        await _firestoreService.updateEntry(entry);
      } else {
        await _firestoreService.addEntry(entry);
        // Check for streak notifications
        await _notificationService.checkAndSendStreakNotifications();
      }

      if (mounted) {
        // Show success feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Text(_selectedMood!.emoji),
                const SizedBox(width: 8),
                Text(widget.editEntry != null
                    ? 'Mood entry updated!'
                    : 'Mood logged successfully!'),
              ],
            ),
            backgroundColor: MoodTheme.getMoodColor(_selectedMood!.value),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: MoodTheme.borderRadiusMd,
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving mood entry: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save mood entry'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: MoodTheme.themeData,
      child: Scaffold(
        backgroundColor: MoodTheme.background,
        body: Stack(
          children: [
            // Animated background
            _buildAnimatedBackground(),

            // Content
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    children: [
                      // Header
                      _buildHeader(),

                      // Progress indicator
                      _buildProgressIndicator(),

                      // Page content
                      Expanded(
                        child: PageView(
                          controller: _pageController,
                          onPageChanged: _onPageChanged,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildMoodSelectionPage(),
                            _buildIntensityPage(),
                            _buildActivitiesPage(),
                          ],
                        ),
                      ),

                      // Navigation buttons
                      _buildNavigationButtons(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    final moodColor = _selectedMood != null
        ? MoodTheme.getMoodColor(_selectedMood!.value)
        : MoodTheme.primary;

    return AnimatedContainer(
      duration: MoodTheme.animationSlow,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            moodColor.withOpacity(0.15),
            MoodTheme.background,
            MoodTheme.background,
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(MoodTheme.spacingMd),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: MoodTheme.borderRadiusMd,
                boxShadow: MoodTheme.softShadow,
              ),
              child: const Icon(
                Icons.close_rounded,
                color: MoodTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: MoodTheme.spacingMd),
          Expanded(
            child: Text(
              widget.editEntry != null ? 'Edit Mood' : 'How are you feeling?',
              style: MoodTheme.headingSm,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: MoodTheme.spacingLg,
        vertical: MoodTheme.spacingSm,
      ),
      child: Row(
        children: List.generate(3, (index) {
          final isActive = index <= _currentPage;
          final isCurrent = index == _currentPage;

          return Expanded(
            child: AnimatedContainer(
              duration: MoodTheme.animationFast,
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: isActive
                    ? (_selectedMood != null
                        ? MoodTheme.getMoodColor(_selectedMood!.value)
                        : MoodTheme.primary)
                    : MoodTheme.backgroundSecondary,
                borderRadius: MoodTheme.borderRadiusRound,
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: MoodTheme.primary.withOpacity(0.3),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMoodSelectionPage() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(MoodTheme.spacingLg),
      child: Column(
        children: [
          const SizedBox(height: MoodTheme.spacingXl),
          Text(
            'Select your mood',
            style: MoodTheme.headingMd.copyWith(
              color: MoodTheme.textPrimary,
            ),
          ),
          const SizedBox(height: MoodTheme.spacingSm),
          Text(
            'Tap on the emoji that best describes how you feel',
            style: MoodTheme.bodyMd.copyWith(
              color: MoodTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: MoodTheme.spacingXxl),

          // Primary moods (large)
          Wrap(
            spacing: MoodTheme.spacingMd,
            runSpacing: MoodTheme.spacingLg,
            alignment: WrapAlignment.center,
            children: MoodType.primaryMoods.map((mood) {
              return MoodEmojiWidget(
                mood: mood,
                size: 64,
                isSelected: _selectedMood == mood,
                onTap: () {
                  setState(() => _selectedMood = mood);
                  HapticFeedback.selectionClick();
                },
              );
            }).toList(),
          ),

          const SizedBox(height: MoodTheme.spacingXl),

          // Secondary moods (smaller)
          Text(
            'Or choose from more options',
            style: MoodTheme.caption.copyWith(
              color: MoodTheme.textMuted,
            ),
          ),
          const SizedBox(height: MoodTheme.spacingMd),
          Wrap(
            spacing: MoodTheme.spacingSm,
            runSpacing: MoodTheme.spacingSm,
            alignment: WrapAlignment.center,
            children: MoodType.values
                .where((m) => !MoodType.primaryMoods.contains(m))
                .map((mood) {
              return MoodEmojiWidget(
                mood: mood,
                size: 44,
                isSelected: _selectedMood == mood,
                showLabel: true,
                showGlow: false,
                onTap: () {
                  setState(() => _selectedMood = mood);
                  HapticFeedback.selectionClick();
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildIntensityPage() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(MoodTheme.spacingLg),
      child: Column(
        children: [
          const SizedBox(height: MoodTheme.spacingXl),

          // Selected mood display
          if (_selectedMood != null) ...[
            MoodEmojiWidget(
              mood: _selectedMood!,
              size: 80,
              isSelected: true,
              showLabel: true,
            ),
            const SizedBox(height: MoodTheme.spacingXl),
          ],

          Text(
            'How intense is this feeling?',
            style: MoodTheme.headingMd.copyWith(
              color: MoodTheme.textPrimary,
            ),
          ),
          const SizedBox(height: MoodTheme.spacingXl),

          // Intensity slider
          BloomGlassContainer(
            padding: const EdgeInsets.all(MoodTheme.spacingLg),
            child: MoodIntensitySlider(
              value: _intensity,
              mood: _selectedMood,
              onChanged: (value) {
                setState(() => _intensity = value);
              },
            ),
          ),

          const SizedBox(height: MoodTheme.spacingXl),

          // Intensity description
          AnimatedSwitcher(
            duration: MoodTheme.animationFast,
            child: Text(
              _getIntensityDescription(),
              key: ValueKey(_intensity),
              style: MoodTheme.bodyMd.copyWith(
                color: MoodTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  String _getIntensityDescription() {
    switch (_intensity) {
      case 1:
        return 'Just a slight feeling, barely noticeable';
      case 2:
        return 'A mild feeling, present but not overwhelming';
      case 3:
        return 'A moderate feeling, clearly present';
      case 4:
        return 'A strong feeling, quite prominent';
      case 5:
        return 'An intense feeling, very powerful';
      default:
        return '';
    }
  }

  Widget _buildActivitiesPage() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(MoodTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: MoodTheme.spacingMd),

          // Activities
          MoodActivityChips(
            selectedActivities: _selectedActivities,
            onChanged: (activities) {
              setState(() => _selectedActivities = activities);
            },
          ),

          const SizedBox(height: MoodTheme.spacingXl),

          // Note section
          Text(
            'Add a note (optional)',
            style: MoodTheme.titleMd.copyWith(
              color: MoodTheme.textPrimary,
            ),
          ),
          const SizedBox(height: MoodTheme.spacingSm),
          Text(
            'Write about what\'s on your mind',
            style: MoodTheme.bodySm.copyWith(
              color: MoodTheme.textSecondary,
            ),
          ),
          const SizedBox(height: MoodTheme.spacingMd),

          BloomGlassContainer(
            padding: EdgeInsets.zero,
            child: TextField(
              controller: _noteController,
              maxLines: 5,
              maxLength: 500,
              style: MoodTheme.bodyMd.copyWith(
                color: MoodTheme.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'What made you feel this way?',
                hintStyle: MoodTheme.bodyMd.copyWith(
                  color: MoodTheme.textMuted,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(MoodTheme.spacingMd),
                counterStyle: MoodTheme.caption,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(MoodTheme.spacingLg),
      decoration: BoxDecoration(
        color: MoodTheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Back button
            if (_currentPage > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _previousPage,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: MoodTheme.primary, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: MoodTheme.borderRadiusMd,
                    ),
                  ),
                  child: const Text('Back'),
                ),
              )
            else
              const Spacer(),

            const SizedBox(width: MoodTheme.spacingMd),

            // Next/Save button
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _canProceed
                    ? (_currentPage == 2 ? _saveEntry : _nextPage)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedMood != null
                      ? MoodTheme.getMoodColor(_selectedMood!.value)
                      : MoodTheme.primary,
                  disabledBackgroundColor: MoodTheme.backgroundSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: MoodTheme.borderRadiusMd,
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _currentPage == 2 ? 'Save Entry' : 'Continue',
                        style: MoodTheme.button,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
