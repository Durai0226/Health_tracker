import 'package:flutter/material.dart';
import 'dart:async';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/storage_service.dart';
import '../models/fitness_activity.dart';

class LiveWorkoutScreen extends StatefulWidget {
  final String workoutType;
  
  const LiveWorkoutScreen({super.key, required this.workoutType});

  @override
  State<LiveWorkoutScreen> createState() => _LiveWorkoutScreenState();
}

class _LiveWorkoutScreenState extends State<LiveWorkoutScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  Timer? _timer;
  // Workout state tracked via _timer
  bool _isPaused = false;
  bool _beaconActive = false;
  
  // Live metrics
  int _elapsedSeconds = 0;
  double _distanceKm = 0.0;
  int _currentHeartRate = 0;
  double _currentPace = 0.0;
  int _calories = 0;
  int _currentCadence = 0;
  String _currentZone = 'Zone 2';
  
  // Splits
  final List<Map<String, dynamic>> _splits = [];
  double _lastSplitDistance = 0;
  int _lastSplitTime = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _startWorkout();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startWorkout() {
    setState(() {
      _isPaused = false;
    });
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        setState(() {
          _elapsedSeconds++;
          _simulateMetrics();
          _checkForSplit();
        });
      }
    });
  }

  void _simulateMetrics() {
    // Simulate realistic workout data
    _distanceKm += 0.003 + (0.001 * (DateTime.now().millisecond % 3));
    _currentHeartRate = 140 + (DateTime.now().second % 30);
    _currentPace = 5.5 + (DateTime.now().millisecond % 100) / 100;
    _calories = (_elapsedSeconds * 0.15).round();
    _currentCadence = 170 + (DateTime.now().second % 10);
    
    // Update zone based on heart rate
    if (_currentHeartRate < 130) {
      _currentZone = 'Zone 1';
    } else if (_currentHeartRate < 150) {
      _currentZone = 'Zone 2';
    } else if (_currentHeartRate < 165) {
      _currentZone = 'Zone 3';
    } else if (_currentHeartRate < 180) {
      _currentZone = 'Zone 4';
    } else {
      _currentZone = 'Zone 5';
    }
  }

  void _checkForSplit() {
    final currentKm = _distanceKm.floor();
    final lastKm = _lastSplitDistance.floor();
    
    if (currentKm > lastKm && currentKm > 0) {
      final splitTime = _elapsedSeconds - _lastSplitTime;
      _splits.add({
        'km': currentKm,
        'time': splitTime,
        'pace': splitTime / 60,
      });
      _lastSplitDistance = _distanceKm;
      _lastSplitTime = _elapsedSeconds;
    }
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });
  }

  void _toggleBeacon() {
    setState(() {
      _beaconActive = !_beaconActive;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _beaconActive ? Icons.location_on : Icons.location_off,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Text(_beaconActive 
                ? 'Beacon activated - Location shared with contacts' 
                : 'Beacon deactivated'),
          ],
        ),
        backgroundColor: _beaconActive ? AppColors.success : AppColors.textSecondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _endWorkout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('End Workout?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSummaryRow('Duration', _formatDuration(_elapsedSeconds)),
            _buildSummaryRow('Distance', '${_distanceKm.toStringAsFixed(2)} km'),
            _buildSummaryRow('Calories', '$_calories kcal'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Resume'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showWorkoutSummary();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Save & End', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showWorkoutSummary() {
    _timer?.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutSummaryScreen(
          workoutType: widget.workoutType,
          duration: _elapsedSeconds,
          distance: _distanceKm,
          calories: _calories,
          avgHeartRate: _currentHeartRate,
          avgPace: _currentPace,
          splits: _splits,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildMetricsDisplay()),
            _buildSplitsSection(),
            _buildControlBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _buildWorkoutTypeChip(),
          const Spacer(),
          if (_beaconActive)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2 + _pulseController.value * 0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on, color: Colors.green, size: 16),
                      SizedBox(width: 4),
                      Text('LIVE', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: _toggleBeacon,
            icon: Icon(
              _beaconActive ? Icons.share_location : Icons.location_searching,
              color: _beaconActive ? Colors.green : Colors.white70,
            ),
            tooltip: 'Beacon',
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.lock_outline, color: Colors.white70),
            tooltip: 'Lock Screen',
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutTypeChip() {
    IconData icon;
    String label;
    
    switch (widget.workoutType) {
      case 'run':
        icon = Icons.directions_run;
        label = 'Running';
        break;
      case 'cycling':
        icon = Icons.pedal_bike;
        label = 'Cycling';
        break;
      case 'gym':
        icon = Icons.fitness_center;
        label = 'Strength';
        break;
      default:
        icon = Icons.directions_run;
        label = 'Workout';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildMetricsDisplay() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Duration - Main metric
          Text(
            _formatDuration(_elapsedSeconds),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 72,
              fontWeight: FontWeight.w200,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: _getZoneColor().withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _currentZone,
              style: TextStyle(
                color: _getZoneColor(),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 40),
          
          // Main metrics grid
          Row(
            children: [
              Expanded(child: _buildMetricCard('Distance', _distanceKm.toStringAsFixed(2), 'km', Icons.straighten)),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard('Pace', _formatPace(_currentPace), '/km', Icons.speed)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildMetricCard('Heart Rate', '$_currentHeartRate', 'bpm', Icons.favorite, isHeartRate: true)),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard('Calories', '$_calories', 'kcal', Icons.local_fire_department)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildMetricCard('Cadence', '$_currentCadence', 'spm', Icons.av_timer)),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard('Elevation', '+${(_distanceKm * 15).toInt()}', 'm', Icons.terrain)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, String unit, IconData icon, {bool isHeartRate = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: isHeartRate ? Colors.red : Colors.white54, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isHeartRate)
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Text(
                      value,
                      style: TextStyle(
                        color: Colors.red.withOpacity(0.8 + _pulseController.value * 0.2),
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                )
              else
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSplitsSection() {
    if (_splits.isEmpty) return const SizedBox.shrink();
    
    return Container(
      height: 80,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SPLITS',
            style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _splits.length,
              itemBuilder: (context, index) {
                final split = _splits[index];
                return Container(
                  width: 70,
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Km ${split['km']}',
                        style: const TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                      Text(
                        _formatPace(split['pace']),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // End button
          GestureDetector(
            onTap: _endWorkout,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.red, width: 2),
              ),
              child: const Icon(Icons.stop_rounded, color: Colors.red, size: 32),
            ),
          ),
          
          // Pause/Resume button
          GestureDetector(
            onTap: _togglePause,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isPaused 
                      ? [Colors.green, Colors.green.shade700]
                      : [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_isPaused ? Colors.green : AppColors.primary).withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
          
          // Lap button
          GestureDetector(
            onTap: () {
              final splitTime = _elapsedSeconds - _lastSplitTime;
              _splits.add({
                'km': _distanceKm,
                'time': splitTime,
                'pace': splitTime / 60 / (_distanceKm - _lastSplitDistance).clamp(0.1, 100),
              });
              _lastSplitDistance = _distanceKm;
              _lastSplitTime = _elapsedSeconds;
              setState(() {});
            },
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white54, width: 2),
              ),
              child: const Icon(Icons.flag_rounded, color: Colors.white54, size: 28),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _formatPace(double pace) {
    final minutes = pace.floor();
    final seconds = ((pace - minutes) * 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Color _getZoneColor() {
    switch (_currentZone) {
      case 'Zone 1': return Colors.blue;
      case 'Zone 2': return Colors.green;
      case 'Zone 3': return Colors.yellow;
      case 'Zone 4': return Colors.orange;
      case 'Zone 5': return Colors.red;
      default: return Colors.green;
    }
  }
}

class WorkoutSummaryScreen extends StatelessWidget {
  final String workoutType;
  final int duration;
  final double distance;
  final int calories;
  final int avgHeartRate;
  final double avgPace;
  final List<Map<String, dynamic>> splits;

  const WorkoutSummaryScreen({
    super.key,
    required this.workoutType,
    required this.duration,
    required this.distance,
    required this.calories,
    required this.avgHeartRate,
    required this.avgPace,
    required this.splits,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('Workout Summary', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMainStats(),
            const SizedBox(height: 24),
            _buildDetailedStats(),
            const SizedBox(height: 24),
            if (splits.isNotEmpty) _buildSplitsTable(),
            const SizedBox(height: 24),
            _buildRelativeEffort(),
            const SizedBox(height: 32),
            _buildSaveButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMainStats() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            _formatDuration(duration),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            'Total Time',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMainStat(distance.toStringAsFixed(2), 'km', 'Distance'),
              _buildMainStat(_formatPace(avgPace), '/km', 'Avg Pace'),
              _buildMainStat('$calories', 'kcal', 'Calories'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainStat(String value, String unit, String label) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                ' $unit',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          ],
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildDetailedStats() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow('Avg Heart Rate', '$avgHeartRate bpm', Icons.favorite, Colors.red),
          _buildDetailRow('Max Heart Rate', '${avgHeartRate + 15} bpm', Icons.favorite, Colors.red),
          _buildDetailRow('Avg Cadence', '172 spm', Icons.av_timer, Colors.blue),
          _buildDetailRow('Elevation Gain', '+${(distance * 15).toInt()} m', Icons.terrain, Colors.green),
          _buildDetailRow('Relative Effort', '${(duration / 60 * 1.2).round()}', Icons.bolt, Colors.orange),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitsTable() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Splits',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...splits.asMap().entries.map((entry) {
            final index = entry.key;
            final split = entry.value;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.border.withOpacity(0.5)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Km ${split['km']}'),
                  ),
                  Text(
                    _formatPace(split['pace']),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRelativeEffort() {
    final effort = (duration / 60 * 1.2).round();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange, Colors.orange.shade700],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$effort',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Relative Effort',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Moderate workout - Good cardio stimulus',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          _saveWorkout();
          Navigator.popUntil(context, (route) => route.isFirst);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Workout saved successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Save Workout',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _saveWorkout() {
    // Create new activity
    final activity = FitnessActivity(
       id: DateTime.now().toIso8601String(),
       type: workoutType,
       title: '${workoutType.substring(0,1).toUpperCase()}${workoutType.substring(1)} Workout',
       notes: 'Completed on ${DateTime.now().toString().split(' ')[0]}',
       startTime: DateTime.now().subtract(Duration(seconds: duration)),
       durationMinutes: (duration / 60).round(),
       caloriesBurned: calories,
       distanceKm: distance,
       isCompleted: true,
    );
    
    // Save to storage
    StorageService.saveFitnessActivity(activity);
    
    // Also save detailed analysis if needed (mocking keys for now)
    // In a real app we'd map the splits to the analysis model
  }
  
  String _getWorkoutEmoji(String type) {
      switch (type) {
          case 'run': return '🏃';
          case 'cycling': return '🚴';
          case 'gym': return '🏋️';
          case 'yoga': return '🧘';
          case 'swimming': return '🏊';
          default: return '🏃';
      }
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${secs}s';
    }
    return '${minutes}m ${secs}s';
  }

  String _formatPace(double pace) {
    final minutes = pace.floor();
    final seconds = ((pace - minutes) * 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
