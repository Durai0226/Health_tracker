
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../home/screens/home_screen.dart';

class FeaturesScreen extends StatefulWidget {
  const FeaturesScreen({super.key});

  @override
  State<FeaturesScreen> createState() => _FeaturesScreenState();
}

class _FeaturesScreenState extends State<FeaturesScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _features = [
    {
      "title": "Medicine Reminders",
      "subtitle": "💊",
      "description": "Never miss your daily doses. Set personalized reminders for all your medications.",
      "icon": Icons.medication_rounded,
      "color": AppColors.primary,
    },
    {
      "title": "Timely Alerts",
      "subtitle": "⏰",
      "description": "Get gentle, smart notifications at the perfect time for your health routine.",
      "icon": Icons.notifications_active_rounded,
      "color": AppColors.info,
    },
    {
      "title": "Sugar & Pressure Checks",
      "subtitle": "🩸",
      "description": "Track your blood sugar and pressure levels. Monitor vital health metrics easily.",
      "icon": Icons.monitor_heart_rounded,
      "color": AppColors.error,
    },
    {
      "title": "Period Tracking",
      "subtitle": "🌸",
      "description": "Monitor your cycle with ease. Get predictions and helpful insights.",
      "icon": Icons.favorite_rounded,
      "color": AppColors.periodPrimary,
    },
    {
      "title": "Daily Health Routine",
      "subtitle": "📅",
      "description": "Build consistent healthy habits. Your personal wellness companion.",
      "icon": Icons.calendar_month_rounded,
      "color": AppColors.success,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Skip Button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextButton(
                  onPressed: () => _navigateToHome(),
                  child: Text("Skip", style: TextStyle(color: AppColors.textSecondary)),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _features.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  final feature = _features[index];
                  return _buildFeatureCard(feature);
                },
              ),
            ),
            // Progress Indicators
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _features.length,
                  (index) => AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 32 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index ? AppColors.primary : AppColors.divider,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
            // CTA Button
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    if (_currentPage < _features.length - 1) {
                      _controller.nextPage(
                        duration: Duration(milliseconds: 400),
                        curve: Curves.easeInOutCubic,
                      );
                    } else {
                      _navigateToHome();
                    }
                  },
                  child: Text(
                    _currentPage < _features.length - 1 ? "Next" : "Let's Go!",
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(Map<String, dynamic> feature) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Emoji Badge
          Text(
            feature["subtitle"] ?? "",
            style: TextStyle(fontSize: 48),
          ),
          SizedBox(height: 24),
          // Icon Container with Gradient
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  (feature["color"] as Color).withOpacity(0.2),
                  (feature["color"] as Color).withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (feature["color"] as Color).withOpacity(0.2),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              feature["icon"],
              size: 56,
              color: feature["color"],
            ),
          ),
          SizedBox(height: 40),
          Text(
            feature["title"],
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          Text(
            feature["description"],
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => HomeScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: Duration(milliseconds: 400),
      ),
    );
  }
}
