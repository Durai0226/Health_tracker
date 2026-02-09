
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/storage_service.dart';
import '../models/water_intake.dart';

class WaterTrackingScreen extends StatefulWidget {
  const WaterTrackingScreen({super.key});

  @override
  State<WaterTrackingScreen> createState() => _WaterTrackingScreenState();
}

class _WaterTrackingScreenState extends State<WaterTrackingScreen> {
  int _dailyGoal = 2500;

  WaterIntake get _todayData {
    return StorageService.getTodayWaterIntake() ??
        WaterIntake(
          id: DateTime.now().toIso8601String(),
          date: DateTime.now(),
          dailyGoalMl: _dailyGoal,
        );
  }

  void _addWater(int amount) async {
    await StorageService.addWaterLog(amount);
    setState(() {});
  }

  void _editGoal() async {
    final controller = TextEditingController(text: _todayData.dailyGoalMl.toString());
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set Daily Goal'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Goal (ml)',
            suffixText: 'ml',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newGoal = int.tryParse(controller.text);
              if (newGoal != null && newGoal > 0) {
                final water = _todayData;
                final updated = water.copyWith(dailyGoalMl: newGoal);
                await StorageService.saveWaterIntake(updated);
                setState(() {
                  _dailyGoal = newGoal; // Update local fallback too
                });
                if (context.mounted) Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final water = _todayData;
    final progress = water.dailyGoalMl > 0
        ? (water.currentIntakeMl / water.dailyGoalMl).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Water Intake',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              // Water Drop Progress
              _buildWaterProgress(water, progress),
              SizedBox(height: 32),

              // Quick Add Buttons
              Text(
                'Quick Add',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 16),
              _buildQuickAddButtons(),
              SizedBox(height: 32),

              // Today's Log
              if (water.logs.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Today\'s Log',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${water.logs.length} entries',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                _buildLogList(water.logs),
              ],
              SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaterProgress(WaterIntake water, double progress) {
    return Container(
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Water Drop Icon with Progress
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 180,
                height: 180,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 12,
                  backgroundColor: AppColors.info.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation(AppColors.info),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('💧', style: TextStyle(fontSize: 48)),
                  SizedBox(height: 8),
                  Text(
                    '${water.currentIntakeMl}',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'of ${water.dailyGoalMl} ml',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SizedBox(width: 4),
                      GestureDetector(
                        onTap: _editGoal,
                        child: Icon(
                          Icons.edit_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 20),
          // Progress Text
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: progress >= 1.0
                  ? AppColors.success.withOpacity(0.1)
                  : AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              progress >= 1.0
                  ? '🎉 Goal reached!'
                  : '${(progress * 100).round()}% of daily goal',
              style: TextStyle(
                color: progress >= 1.0 ? AppColors.success : AppColors.info,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAddButtons() {
    final amounts = [
      {'ml': 150, 'label': 'Glass', 'icon': '🥛'},
      {'ml': 250, 'label': 'Cup', 'icon': '☕'},
      {'ml': 500, 'label': 'Bottle', 'icon': '🍶'},
      {'ml': 750, 'label': 'Large', 'icon': '🧴'},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: amounts.map((item) {
        return GestureDetector(
          onTap: () => _addWater(item['ml'] as int),
          child: Container(
            width: 75,
            padding: EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(item['icon'] as String, style: TextStyle(fontSize: 28)),
                SizedBox(height: 8),
                Text(
                  '+${item['ml']}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.info,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'ml',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLogList(List<WaterLog> logs) {
    final reversedLogs = logs.reversed.toList();
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: reversedLogs.take(5).map((log) {
          final timeStr = '${log.time.hour.toString().padLeft(2, '0')}:${log.time.minute.toString().padLeft(2, '0')}';
          return Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.divider,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('💧', style: TextStyle(fontSize: 16)),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '+${log.amountMl} ml',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  timeStr,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
