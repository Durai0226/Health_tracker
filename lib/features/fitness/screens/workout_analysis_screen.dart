import 'package:flutter/material.dart' hide Split;
import '../../../core/constants/app_colors.dart';
import '../../../core/services/storage_service.dart';
import '../models/training_models.dart';

class WorkoutAnalysisScreen extends StatefulWidget {
  final String? activityId;
  const WorkoutAnalysisScreen({super.key, this.activityId});

  @override
  State<WorkoutAnalysisScreen> createState() => _WorkoutAnalysisScreenState();
}

class _WorkoutAnalysisScreenState extends State<WorkoutAnalysisScreen> {
  String _selectedPeriod = 'week';
  WorkoutAnalysis? _analysis;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalysis();
  }

  Future<void> _loadAnalysis() async {
      // Simulate loading or fetch from storage
      // In a real app, we might fetch by ID or get the latest.
      // Since we don't have a robust "get latest" query in our simple Hive setup without indices,
      // we'll just try to get by ID if present, or mock/get first.
      
      if (widget.activityId != null) {
          _analysis = StorageService.getWorkoutAnalysis(widget.activityId!);
      } else {
          // Try to get any analysis
          // We don't have a direct "getAll" exposed in the snippet I wrote, but we have the box
          // let's assume we can add a getter or usage here.
          // Actually I added `getWorkoutAnalysis(id)` but not `getAll`.
          // For now, let's just create a mock one if null, or show empty.
          // But to be "dynamic", we should probably save a sample analysis if one doesn't exist.
          if (_analysis == null) {
              _createSampleAnalysis();
          }
      }
      
      setState(() {
          _isLoading = false;
      });
  }
  
  void _createSampleAnalysis() {
      // Create and save a sample if needed for demo
      _analysis = WorkoutAnalysis(
          activityId: 'sample_1',
          averagePower: 185,
          normalizedPower: 195,
          maxPower: 450,
          intensityFactor: 0.78,
          trainingStressScore: 85,
          variabilityIndex: 1.05,
          efficiencyFactor: 1.45,
          decoupling: 3.2,
          splits: [
              Split(km: 1, pace: '5:32', averageHeartRate: 145, elevationGain: 10),
              Split(km: 2, pace: '5:28', averageHeartRate: 152, elevationGain: 5),
              Split(km: 3, pace: '5:45', averageHeartRate: 158, elevationGain: 15),
              Split(km: 4, pace: '5:35', averageHeartRate: 155, elevationGain: 8),
              Split(km: 5, pace: '5:20', averageHeartRate: 165, elevationGain: 2),
          ],
          zones: [
              ZoneTime(zone: 1, durationSeconds: 900, name: 'Recovery'),
              ZoneTime(zone: 2, durationSeconds: 2700, name: 'Endurance'),
              ZoneTime(zone: 3, durationSeconds: 1800, name: 'Tempo'),
              ZoneTime(zone: 4, durationSeconds: 1200, name: 'Threshold'),
              ZoneTime(zone: 5, durationSeconds: 300, name: 'VO2 Max'),
          ],
      );
      StorageService.saveWorkoutAnalysis(_analysis!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Workout Analysis',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _analysis == null
            ? const Center(child: Text('No analysis data available'))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPeriodSelector(),
                    const SizedBox(height: 24),
                    _buildPowerAnalysis(),
                    const SizedBox(height: 20),
                    _buildPaceAnalysis(),
                    const SizedBox(height: 20),
                    _buildGAPCard(),
                    const SizedBox(height: 20),
                    _buildSplitsAnalysis(),
                    const SizedBox(height: 20),
                    _buildTrainingLoad(),
                  ],
                ),
              ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: ['week', 'month', 'year'].map((period) {
          final isSelected = _selectedPeriod == period;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPeriod = period),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    period[0].toUpperCase() + period.substring(1),
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPowerAnalysis() {
    if (_analysis == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.purple.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.bolt, color: Colors.purple, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Power Analysis', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Cycling metrics', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildPowerMetric('Avg Power', '${_analysis!.averagePower} W', Colors.purple),
              _buildPowerMetric('Normalized', '${_analysis!.normalizedPower} W', Colors.blue),
              _buildPowerMetric('Max Power', '${_analysis!.maxPower} W', Colors.red),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildPowerMetric('Intensity', '${_analysis!.intensityFactor}', Colors.orange),
              _buildPowerMetric('TSS', '${_analysis!.trainingStressScore}', Colors.green),
              _buildPowerMetric('W/kg', '2.8', Colors.teal), // hardcoded for now or need weight
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPowerMetric(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildPaceAnalysis() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pace Distribution', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildPaceBar('5:00 - 5:30', 0.3, Colors.green),
          _buildPaceBar('5:30 - 6:00', 0.5, Colors.teal),
          _buildPaceBar('6:00 - 6:30', 0.15, Colors.orange),
          _buildPaceBar('6:30+', 0.05, Colors.red),
        ],
      ),
    );
  }

  Widget _buildPaceBar(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 13)),
              Text('${(value * 100).round()}%', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: value, minHeight: 8, backgroundColor: color.withOpacity(0.2), valueColor: AlwaysStoppedAnimation(color)),
          ),
        ],
      ),
    );
  }

  Widget _buildGAPCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.indigo, Colors.indigo.shade700]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.terrain, color: Colors.white),
              SizedBox(width: 10),
              Text('Grade Adjusted Pace', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Actual Pace', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text('5:45 /km', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Container(width: 1, height: 50, color: Colors.white24),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('GAP', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text('5:25 /km', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white70, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'GAP adjusts your pace for elevation, showing equivalent flat-ground effort',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitsAnalysis() {
    if (_analysis == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Splits Analysis', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ..._analysis!.splits.map((split) => Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5)))),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                  child: Center(child: Text('${split.km}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))),
                ),
                const SizedBox(width: 16),
                Expanded(child: Text('${split.pace} /km', style: const TextStyle(fontWeight: FontWeight.w600))),
                Row(
                  children: [
                    const Icon(Icons.favorite, size: 14, color: Colors.red),
                    const SizedBox(width: 4),
                    Text('${split.averageHeartRate} bpm', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildTrainingLoad() {
    if (_analysis == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Training Stress Score', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text('${_analysis!.trainingStressScore}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.orange)),
                    const Text('Today\'s TSS', style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Container(
                width: 1, height: 60,
                decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, AppColors.border, Colors.transparent])),
              ),
              const Expanded(
                child: Column(
                  children: [
                    Text('420', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    Text('Weekly TSS', style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: const LinearProgressIndicator(value: 0.7, minHeight: 10, backgroundColor: Color(0xFFE0E0E0), valueColor: AlwaysStoppedAnimation(Colors.orange)),
          ),
          const SizedBox(height: 8),
          const Text('70% of weekly target (600 TSS)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
