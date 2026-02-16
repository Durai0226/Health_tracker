import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/focus_mode_service.dart';

class FocusModeScreen extends StatefulWidget {
  const FocusModeScreen({super.key});

  @override
  State<FocusModeScreen> createState() => _FocusModeScreenState();
}

class _FocusModeScreenState extends State<FocusModeScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  // Service
  final FocusModeService _focusService = FocusModeService();
  
  // Animation
  late AnimationController _pulseController;
  late AnimationController _breatheController;
  
  
  final List<Map<String, dynamic>> _activities = [
    {'id': 'reading', 'name': 'Reading', 'icon': Icons.menu_book_rounded, 'color': AppColors.primary},
    {'id': 'studying', 'name': 'Studying', 'icon': Icons.school_rounded, 'color': AppColors.info},
    {'id': 'working', 'name': 'Working', 'icon': Icons.work_rounded, 'color': AppColors.warning},
    {'id': 'meditating', 'name': 'Meditating', 'icon': Icons.self_improvement_rounded, 'color': AppColors.success},
    {'id': 'writing', 'name': 'Writing', 'icon': Icons.edit_rounded, 'color': AppColors.error},
    {'id': 'coding', 'name': 'Coding', 'icon': Icons.code_rounded, 'color': const Color(0xFF9C27B0)},
  ];

  final List<int> _durationOptions = [15, 25, 30, 45, 60, 90];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _initService();
  }
  
  Future<void> _initService() async {
    await _focusService.init();
    _focusService.addListener(_onServiceUpdate);
    if (mounted) setState(() {});
  }
  
  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh state when app comes to foreground
      _focusService.init();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusService.removeListener(_onServiceUpdate);
    _pulseController.dispose();
    _breatheController.dispose();
    super.dispose();
  }

  void _startSession() {
    _focusService.startSession();
  }

  void _stopSession() {
    _focusService.stopSession();
  }
  

  String _getActivityName(String id) {
    return _activities.firstWhere((a) => a['id'] == id)['name'] as String;
  }

  IconData _getActivityIcon(String id) {
    return _activities.firstWhere((a) => a['id'] == id)['icon'] as IconData;
  }

  Color _getActivityColor(String id) {
    return _activities.firstWhere((a) => a['id'] == id)['color'] as Color;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: _getActivityColor(_focusService.selectedActivity),
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Focus Timer',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _getActivityColor(_focusService.selectedActivity),
                      _getActivityColor(_focusService.selectedActivity).withOpacity(0.7),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -20,
                      top: -20,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 30,
                      bottom: 50,
                      child: Icon(
                        _getActivityIcon(_focusService.selectedActivity),
                        size: 50,
                        color: Colors.white.withOpacity(0.2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Stats Cards
                _buildStatsRow(),
                const SizedBox(height: 24),
                
                // Timer Display
                _buildTimerCard(),
                const SizedBox(height: 24),
                
                if (!_focusService.isRunning) ...[
                  // Activity Selection
                  _buildActivitySelector(),
                  const SizedBox(height: 24),
                  
                  // Duration Selection
                  _buildDurationSelector(),
                  const SizedBox(height: 24),
                  
                  // Schedule Section
                  _buildScheduleCard(),
                  const SizedBox(height: 24),
                ],
                
                // Recent Sessions
                if (_focusService.getRecentSessions().isNotEmpty && !_focusService.isRunning) ...[
                  _buildRecentSessions(),
                  const SizedBox(height: 24),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _buildStatCard('Today', '${_focusService.todayMinutes}m', Icons.today_rounded, AppColors.primary)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('This Week', '${_focusService.weekMinutes}m', Icons.date_range_rounded, AppColors.info)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Sessions', '${_focusService.totalSessions}', Icons.flag_rounded, AppColors.success)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerCard() {
    final progress = _focusService.progress;
    
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _getActivityColor(_focusService.selectedActivity).withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Timer Circle
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 200,
                height: 200,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 12,
                  backgroundColor: AppColors.background,
                  valueColor: AlwaysStoppedAnimation(_getActivityColor(_focusService.selectedActivity)),
                ),
              ),
              if (_focusService.isRunning)
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 180 + (_pulseController.value * 10),
                      height: 180 + (_pulseController.value * 10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getActivityColor(_focusService.selectedActivity).withOpacity(0.05 * _pulseController.value),
                      ),
                    );
                  },
                ),
              Column(
                children: [
                  Icon(
                    _getActivityIcon(_focusService.selectedActivity),
                    size: 32,
                    color: _getActivityColor(_focusService.selectedActivity),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _focusService.isRunning ? _focusService.formattedTime : '${_focusService.selectedMinutes}:00',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    _focusService.isRunning ? (_focusService.isPaused ? 'Paused' : 'Focusing...') : 'Ready to focus',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Start/Stop Button
          GestureDetector(
            onTap: _focusService.isRunning ? _stopSession : _startSession,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _focusService.isRunning 
                      ? [AppColors.error, AppColors.error.withOpacity(0.8)]
                      : [_getActivityColor(_focusService.selectedActivity), _getActivityColor(_focusService.selectedActivity).withOpacity(0.8)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: (_focusService.isRunning ? AppColors.error : _getActivityColor(_focusService.selectedActivity)).withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _focusService.isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _focusService.isRunning ? 'Stop Session' : 'Start Focus',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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

  Widget _buildActivitySelector() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What are you focusing on?',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _activities.map((activity) {
              final isSelected = _focusService.selectedActivity == activity['id'];
              final color = activity['color'] as Color;
              
              return GestureDetector(
                onTap: () => _focusService.setActivity(activity['id'] as String),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? color : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? color : AppColors.border,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ] : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        activity['icon'] as IconData,
                        color: isSelected ? Colors.white : color,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        activity['name'] as String,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationSelector() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Focus Duration',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: _durationOptions.map((minutes) {
              final isSelected = _focusService.selectedMinutes == minutes;
              
              return Expanded(
                child: GestureDetector(
                  onTap: () => _focusService.setDuration(minutes),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.only(right: minutes != _durationOptions.last ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? _getActivityColor(_focusService.selectedActivity) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? _getActivityColor(_focusService.selectedActivity) : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${minutes}m',
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard() {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.schedule_rounded, color: AppColors.info, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Scheduled Focus Time',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _focusService.isScheduled 
                          ? 'Auto-starts at scheduled times'
                          : 'Set up automatic focus sessions',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _focusService.isScheduled,
                onChanged: (value) => _focusService.setScheduled(value),
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),
          if (_focusService.isScheduled) ...[
            const SizedBox(height: 20),
            
            // Time Selection
            Row(
              children: [
                Expanded(
                  child: _buildTimeSelector(
                    label: 'Start',
                    time: _focusService.scheduledStartTime,
                    onTap: () => _pickTime(isStart: true),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.arrow_forward_rounded, color: AppColors.textSecondary, size: 20),
                ),
                Expanded(
                  child: _buildTimeSelector(
                    label: 'End',
                    time: _focusService.scheduledEndTime,
                    onTap: () => _pickTime(isStart: false),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Day Selection
            const Text(
              'Active Days',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (index) {
                final dayNum = index + 1; // 1-7
                final isSelected = _focusService.scheduledDays.contains(dayNum);
                
                return GestureDetector(
                  onTap: () {
                    final newDays = List<int>.from(_focusService.scheduledDays);
                    if (isSelected) {
                      newDays.remove(dayNum);
                    } else {
                      newDays.add(dayNum);
                    }
                    _focusService.setScheduledDays(newDays);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        days[index],
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            
            const SizedBox(height: 16),
            
            // Auto-pause reminders option
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_off_rounded, color: AppColors.warning, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Pause other reminders during focus',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Switch(
                    value: _focusService.autoStartReminders,
                    onChanged: (value) => _focusService.setAutoStartReminders(value),
                    activeThumbColor: AppColors.primary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeSelector({
    required String label,
    required FocusTimeOfDay? time,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time != null ? time.format() : 'Set time',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: time != null ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: isStart 
            ? (_focusService.scheduledStartTime?.hour ?? 9)
            : (_focusService.scheduledEndTime?.hour ?? 17),
        minute: isStart 
            ? (_focusService.scheduledStartTime?.minute ?? 0)
            : (_focusService.scheduledEndTime?.minute ?? 0),
      ),
    );
    
    if (picked != null) {
      final time = FocusTimeOfDay(hour: picked.hour, minute: picked.minute);
      if (isStart) {
        _focusService.setScheduledStartTime(time);
      } else {
        _focusService.setScheduledEndTime(time);
      }
    }
  }

  Widget _buildRecentSessions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history_rounded, color: AppColors.textSecondary, size: 20),
              SizedBox(width: 8),
              Text(
                'Recent Sessions',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._focusService.getRecentSessions().map((session) {
            final activity = session['activity'] as String;
            final minutes = session['minutes'] as int;
            final date = DateTime.parse(session['date'] as String);
            final formattedDate = DateFormat('MMM d, h:mm a').format(date);
            
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _getActivityColor(activity).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getActivityIcon(activity),
                      color: _getActivityColor(activity),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getActivityName(activity),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          formattedDate,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getActivityColor(activity).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${minutes}m',
                      style: TextStyle(
                        color: _getActivityColor(activity),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
