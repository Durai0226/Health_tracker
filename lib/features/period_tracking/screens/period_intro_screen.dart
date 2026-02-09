
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import 'period_setup_screen.dart';

class PeriodIntroScreen extends StatelessWidget {
  const PeriodIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.periodLight,
              Colors.white,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              children: [
                // Close Button
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  ),
                ),
                Spacer(flex: 2),
                // Icon
                Container(
                  padding: EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: AppColors.periodGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.periodPrimary.withOpacity(0.3),
                        blurRadius: 30,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.favorite_rounded,
                    size: 56,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 48),
                Text(
                  "Period Tracking",
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: AppColors.periodPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                Text(
                  "Track your cycle alongside your\nmedication reminders",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                Spacer(flex: 3),
                // Enable Button
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: AppColors.periodGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.periodPrimary.withOpacity(0.4),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PeriodSetupScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                    ),
                    child: Text("Enable Period Tracking"),
                  ),
                ),
                SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    "Maybe Later",
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
