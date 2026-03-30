import 'dart:math' as math;
import 'dart:ui';
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
  late AnimationController _progressController;
  late AnimationController _breatheController;
  late AnimationController _floatController;
  
  late Animation<double> _pulseAnimation;
  late Animation<double> _breatheAnimation;
  late Animation<double> _floatAnimation;

  final List<int> _presetMinutes = [15, 25, 45, 60, 90];

  @override
  void initState() {
    super.initState();
    _selectedSubjectId = widget.subjectId;
    _selectedTopicId = widget.topicId;
    _examPrepService.addListener(_onServiceUpdate);
    _initAnimations();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat(reverse: true);
    _breatheAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeInOut),
    );
    
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
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
    _progressController.dispose();
    _breatheController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasActiveSession = _examPrepService.hasActiveSession;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Animated background orbs
          Positioned(
            top: -80,
            right: -80,
            child: AnimatedBuilder(
              animation: _floatController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _floatAnimation.value),
                  child: AnimatedBuilder(
                    animation: _breatheController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _breatheAnimation.value * 0.5,
                        child: Container(
                          width: 250,
                          height: 250,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.primary.withOpacity(0.4),
                                AppColors.primary.withOpacity(0.0),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          Positioned(
            bottom: 150,
            left: -60,
            child: AnimatedBuilder(
              animation: _floatController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, -_floatAnimation.value),
                  child: AnimatedBuilder(
                    animation: _breatheController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _breatheAnimation.value * 0.4,
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.success.withOpacity(0.3),
                                AppColors.success.withOpacity(0.0),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          // Main content
          SafeArea(
            child: Column(
              children: [
                // Premium App Bar
                _buildPremiumAppBar(theme, hasActiveSession),
                // Content
                Expanded(
                  child: hasActiveSession
                      ? _buildPremiumActiveSession(theme)
                      : _buildSessionSetup(theme),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumAppBar(ThemeData theme, bool hasActiveSession) {
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                    ),
                  ),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: AppColors.getTextPrimary(context),
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasActiveSession ? 'Session Active' : 'Study Session',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: hasActiveSession ? AppColors.success : AppColors.getTextSecondary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: hasActiveSession
                        ? [AppColors.success, const Color(0xFF059669)]
                        : [AppColors.primary, AppColors.primary.withOpacity(0.7)],
                  ).createShader(bounds),
                  child: Text(
                    hasActiveSession ? 'Stay Focused' : 'Start Learning',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (hasActiveSession)
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                _showEndSessionDialog();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.stop_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'End',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSessionSetup(ThemeData theme) {
    final subjects = _examPrepService.getActiveSubjects();
    final topics = _selectedSubjectId != null
        ? _examPrepService.getTopicsBySubject(_selectedSubjectId!)
        : <Topic>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Session Type Selection
          _buildSectionCard(
            title: 'Session Type',
            icon: Icons.psychology_rounded,
            child: Column(
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: StudySessionType.values.map((type) {
                    final isSelected = _sessionType == type;
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
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
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : AppColors.getTextPrimary(context),
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.getGrey50(context),
                        onSelected: (_) => setState(() => _sessionType = type),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Duration Selection
          _buildSectionCard(
            title: 'Duration',
            icon: Icons.timer_outlined,
            child: Column(
              children: [
                // Preset durations
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    childAspectRatio: 1.2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _presetMinutes.length,
                  itemBuilder: (context, index) {
                    final mins = _presetMinutes[index];
                    final isSelected = _selectedMinutes == mins;
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ] : null,
                      ),
                      child: Material(
                        color: isSelected ? AppColors.primary : AppColors.getGrey50(context),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () => setState(() => _selectedMinutes = mins),
                          borderRadius: BorderRadius.circular(12),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$mins',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? Colors.white : AppColors.getTextPrimary(context),
                                  ),
                                ),
                                Text(
                                  'min',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isSelected ? Colors.white : AppColors.getTextSecondary(context),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                // Custom duration slider
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
                            'Custom Duration',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.getTextPrimary(context),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$_selectedMinutes min',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 6,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                          activeTrackColor: AppColors.primary,
                          inactiveTrackColor: AppColors.primary.withOpacity(0.2),
                          thumbColor: AppColors.primary,
                          overlayColor: AppColors.primary.withOpacity(0.2),
                        ),
                        child: Slider(
                          value: _selectedMinutes.toDouble(),
                          min: 5,
                          max: 180,
                          divisions: 35,
                          onChanged: (value) => setState(() => _selectedMinutes = value.toInt()),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '5 min',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.getTextSecondary(context),
                            ),
                          ),
                          Text(
                            '3 hours',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.getTextSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Subject & Topic Selection
          _buildSectionCard(
            title: 'Focus Area (Optional)',
            icon: Icons.school_rounded,
            child: Column(
              children: [
                DropdownButtonFormField<String?>(
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
                        'No specific subject',
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
                  onChanged: (value) => setState(() {
                    _selectedSubjectId = value;
                    _selectedTopicId = null;
                  }),
                ),
                const SizedBox(height: 16),

                // Topic Selection (if subject selected)
                if (_selectedSubjectId != null && topics.isNotEmpty) ...[
                  DropdownButtonFormField<String?>(
                    value: _selectedTopicId,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppColors.getTextPrimary(context),
                    ),
                    decoration: InputDecoration(
                      labelText: 'Topic',
                      prefixIcon: Container(
                        margin: const EdgeInsets.all(12),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.info.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.topic_rounded,
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
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(
                          'No specific topic',
                          style: TextStyle(color: AppColors.getTextSecondary(context)),
                        ),
                      ),
                      ...topics.map((topic) => DropdownMenuItem(
                            value: topic.id,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: _getTopicStatusColor(topic.status).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    topic.status.emoji,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    topic.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.getTextPrimary(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                    onChanged: (value) => setState(() => _selectedTopicId = value),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Start Button
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.success, Color(0xFF10B981)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: CommonButton(
              text: 'Start $_selectedMinutes min ${_sessionType.displayName}',
              icon: Icons.play_arrow_rounded,
              variant: ButtonVariant.primary,
              backgroundColor: Colors.transparent,
              onPressed: _startSession,
              textStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
                letterSpacing: -0.2,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Study Tips
          ElevatedCard(
            padding: const EdgeInsets.all(24),
            borderRadius: 20,
            shadowColor: AppColors.warning,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.warning, Color(0xFFF59E0B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.warning.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.lightbulb_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Study Tips',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.getTextPrimary(context),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ...[
                  {'icon': Icons.volume_off_rounded, 'tip': 'Find a quiet place to study'},
                  {'icon': Icons.phone_disabled_rounded, 'tip': 'Put your phone on silent'},
                  {'icon': Icons.free_breakfast_rounded, 'tip': 'Take short breaks between sessions'},
                  {'icon': Icons.water_drop_rounded, 'tip': 'Stay hydrated'},
                ].map((tipData) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          tipData['icon'] as IconData,
                          color: AppColors.warning,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          tipData['tip'] as String,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.getTextSecondary(context),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumActiveSession(ThemeData theme) {
    final session = _examPrepService.activeSession;
    final remainingSeconds = _examPrepService.remainingSeconds;
    final mins = remainingSeconds ~/ 60;
    final secs = remainingSeconds % 60;
    final isDark = theme.brightness == Brightness.dark;
    
    final subject = session?.subjectId != null
        ? _examPrepService.getSubjectById(session!.subjectId!)
        : null;
    final topic = session?.topicId != null
        ? _examPrepService.getTopicById(session!.topicId!)
        : null;

    final progress = session != null && session.plannedMinutes > 0
        ? 1 - (remainingSeconds / (session.plannedMinutes * 60))
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Session Type Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.success.withOpacity(0.15),
                  AppColors.success.withOpacity(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColors.success.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  session?.sessionType.emoji ?? '📚',
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 8),
                Text(
                  session?.sessionType.displayName ?? 'Study Session',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          
          // Premium Circular Timer
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: _examPrepService.isPaused ? 1.0 : _pulseAnimation.value,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer glow
                    Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.success.withOpacity(0.3),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                    ),
                    // Progress ring
                    SizedBox(
                      width: 260,
                      height: 260,
                      child: CustomPaint(
                        painter: _CircularProgressPainter(
                          progress: progress.clamp(0.0, 1.0),
                          strokeWidth: 12,
                          backgroundColor: isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.06),
                          gradientColors: const [
                            Color(0xFF10B981),
                            Color(0xFF059669),
                          ],
                        ),
                      ),
                    ),
                    // Inner circle with glassmorphism
                    ClipOval(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isDark
                                  ? [
                                      Colors.white.withOpacity(0.08),
                                      Colors.white.withOpacity(0.04),
                                    ]
                                  : [
                                      Colors.white.withOpacity(0.9),
                                      Colors.white.withOpacity(0.7),
                                    ],
                            ),
                            border: Border.all(
                              color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_examPrepService.isPaused)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'PAUSED',
                                    style: TextStyle(
                                      color: AppColors.warning,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                                ).createShader(bounds),
                                child: Text(
                                  '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}',
                                  style: theme.textTheme.displayMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -2,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'remaining',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.getTextSecondary(context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          
          // Progress info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${(progress * 100).toInt()}% Complete',
              style: TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Subject/Topic Info Card
          if (subject != null || topic != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (subject != null) ...[
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Color(int.parse(subject.colorHex.replaceAll('#', '0xFF'))),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(int.parse(subject.colorHex.replaceAll('#', '0xFF'))).withOpacity(0.4),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          subject.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                      ],
                      if (topic != null) ...[
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.getTextSecondary(context),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Text(
                          topic.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 40),
          
          // Control Buttons
          Row(
            children: [
              // Pause/Resume Button
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _examPrepService.togglePauseResume();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      gradient: _examPrepService.isPaused
                          ? const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF059669)],
                            )
                          : null,
                      color: _examPrepService.isPaused ? null : AppColors.warning.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: _examPrepService.isPaused
                          ? [
                              BoxShadow(
                                color: AppColors.success.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _examPrepService.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                          color: _examPrepService.isPaused ? Colors.white : AppColors.warning,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _examPrepService.isPaused ? 'Resume' : 'Pause',
                          style: TextStyle(
                            color: _examPrepService.isPaused ? Colors.white : AppColors.warning,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Complete Button
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _showEndSessionDialog();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, Color(0xFF26A69A)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Complete',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Abandon Button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _showAbandonDialog();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'Abandon Session',
                style: TextStyle(
                  color: AppColors.getTextSecondary(context),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // Keep old method for compatibility
  Widget _buildActiveSession(ThemeData theme) {
    return _buildPremiumActiveSession(theme);
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

  Color _getTopicStatusColor(dynamic status) {
    // Fallback color mapping for topic status
    switch (status.toString()) {
      case 'not_started':
        return Colors.grey;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'revision_needed':
        return Colors.orange;
      case 'mastered':
        return Colors.purple;
      default:
        return AppColors.primary;
    }
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

// Custom painter for circular progress
class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color backgroundColor;
  final List<Color> gradientColors;

  _CircularProgressPainter({
    required this.progress,
    required this.strokeWidth,
    required this.backgroundColor,
    required this.gradientColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background circle
    final bgPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc with gradient
    if (progress > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      final gradient = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: gradientColors,
        transform: const GradientRotation(-math.pi / 2),
      );

      final progressPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        progressPaint,
      );

      // Glow effect
      final glowPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..strokeWidth = strokeWidth + 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        glowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
