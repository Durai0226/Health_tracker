
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/storage_service.dart';
import '../models/period_data.dart';
import 'period_overview_screen.dart';

class PeriodSetupScreen extends StatefulWidget {
  const PeriodSetupScreen({super.key});

  @override
  State<PeriodSetupScreen> createState() => _PeriodSetupScreenState();
}

class _PeriodSetupScreenState extends State<PeriodSetupScreen> {
  DateTime _lastPeriodDate = DateTime.now().subtract(Duration(days: 14));
  int _cycleLength = 28;
  int _periodDuration = 5;

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _lastPeriodDate,
      firstDate: DateTime.now().subtract(Duration(days: 90)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.periodPrimary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() => _lastPeriodDate = date);
    }
  }

  Future<void> _save() async {
    final periodData = PeriodData(
      lastPeriodDate: _lastPeriodDate,
      cycleLength: _cycleLength,
      periodDuration: _periodDuration,
      isEnabled: true,
    );
    await StorageService.savePeriodData(periodData);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PeriodOverviewScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.periodPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text("Setup", style: TextStyle(color: AppColors.periodPrimary)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Let's set up your cycle",
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: AppColors.periodPrimary,
                ),
              ),
              SizedBox(height: 32),
              // Last Period Card
              _buildSettingCard(
                title: "Last period started",
                child: GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.periodLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.periodPrimary.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, color: AppColors.periodPrimary),
                        SizedBox(width: 16),
                        Text(
                          "${_lastPeriodDate.day}/${_lastPeriodDate.month}/${_lastPeriodDate.year}",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        Spacer(),
                        Icon(Icons.edit_rounded, color: AppColors.periodPrimary, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
              // Cycle Length
              _buildSettingCard(
                title: "Average cycle length",
                child: _buildStepper(
                  value: _cycleLength,
                  unit: "days",
                  onDecrement: () {
                    if (_cycleLength > 21) setState(() => _cycleLength--);
                  },
                  onIncrement: () {
                    if (_cycleLength < 45) setState(() => _cycleLength++);
                  },
                ),
              ),
              SizedBox(height: 20),
              // Period Duration
              _buildSettingCard(
                title: "Period duration",
                child: _buildStepper(
                  value: _periodDuration,
                  unit: "days",
                  onDecrement: () {
                    if (_periodDuration > 2) setState(() => _periodDuration--);
                  },
                  onIncrement: () {
                    if (_periodDuration < 10) setState(() => _periodDuration++);
                  },
                ),
              ),
              Spacer(),
              // Save Button
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: AppColors.periodGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.periodPrimary.withOpacity(0.4),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                  ),
                  child: Text("Save & Continue"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingCard({required String title, required Widget child}) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildStepper({
    required int value,
    required String unit,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
  }) {
    return Row(
      children: [
        GestureDetector(
          onTap: onDecrement,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.periodLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.remove_rounded, color: AppColors.periodPrimary),
          ),
        ),
        Expanded(
          child: Text(
            "$value $unit",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        GestureDetector(
          onTap: onIncrement,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.periodLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.add_rounded, color: AppColors.periodPrimary),
          ),
        ),
      ],
    );
  }
}
