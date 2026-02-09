
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/storage_service.dart';
import '../models/period_data.dart';
import 'package:intl/intl.dart';

class PeriodOverviewScreen extends StatelessWidget {
  const PeriodOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final periodData = StorageService.getPeriodData();

    if (periodData == null) {
      return Scaffold(
        body: Center(child: Text("No period data found.")),
      );
    }

    final today = DateTime.now();
    final daysUntil = periodData.daysUntilNextPeriod(today);
    final isOnPeriod = periodData.isOnPeriod(today);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.periodPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text("Period Tracker", style: TextStyle(color: AppColors.periodPrimary)),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            // Status Card
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: AppColors.periodGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.periodPrimary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isOnPeriod ? Icons.water_drop_rounded : Icons.favorite_rounded,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    isOnPeriod ? "You're on your period" : "Period expected in",
                    style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.9)),
                  ),
                  SizedBox(height: 8),
                  Text(
                    isOnPeriod ? "Take care of yourself 💜" : "$daysUntil days",
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            // Cycle Info
            Container(
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
                children: [
                  _buildInfoRow(Icons.calendar_today_rounded, "Last Period",
                      DateFormat('MMM d, yyyy').format(periodData.lastPeriodDate)),
                  Divider(height: 24),
                  _buildInfoRow(Icons.event_rounded, "Next Period",
                      DateFormat('MMM d, yyyy').format(periodData.nextPeriodDate)),
                  Divider(height: 24),
                  _buildInfoRow(Icons.loop_rounded, "Cycle Length", "${periodData.cycleLength} days"),
                  Divider(height: 24),
                  _buildInfoRow(Icons.timelapse_rounded, "Period Duration", "${periodData.periodDuration} days"),
                ],
              ),
            ),
            SizedBox(height: 24),
            // Mini Calendar
            _buildMiniCalendar(periodData, today),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.periodLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.periodPrimary, size: 20),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Text(label, style: TextStyle(color: AppColors.textSecondary)),
        ),
        Text(value, style: TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildMiniCalendar(PeriodData data, DateTime today) {
    final startOfMonth = DateTime(today.year, today.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(today.year, today.month);

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
        children: [
          Text(
            DateFormat('MMMM yyyy').format(today),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          // Weekday Headers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ["S", "M", "T", "W", "T", "F", "S"]
                .map((d) => SizedBox(
                      width: 36,
                      child: Text(d, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
                    ))
                .toList(),
          ),
          SizedBox(height: 8),
          // Days Grid
          Wrap(
            spacing: 4,
            runSpacing: 8,
            children: List.generate(daysInMonth + startOfMonth.weekday % 7, (index) {
              if (index < startOfMonth.weekday % 7) {
                return SizedBox(width: 36, height: 36);
              }
              final day = startOfMonth.add(Duration(days: index - startOfMonth.weekday % 7));
              final isOnPeriod = data.isOnPeriod(day);
              final isToday = day.day == today.day && day.month == today.month;

              return Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isOnPeriod
                      ? AppColors.periodHighlight
                      : (isToday ? AppColors.periodPrimary.withOpacity(0.1) : Colors.transparent),
                  shape: BoxShape.circle,
                  border: isToday ? Border.all(color: AppColors.periodPrimary, width: 2) : null,
                ),
                child: Center(
                  child: Text(
                    "${day.day}",
                    style: TextStyle(
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      color: isOnPeriod ? AppColors.periodPrimary : AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
