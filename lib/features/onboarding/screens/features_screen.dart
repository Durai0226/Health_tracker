
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/storage_service.dart';
import 'category_selection_screen.dart';

class FeaturesScreen extends StatefulWidget {
  const FeaturesScreen({super.key});

  @override
  State<FeaturesScreen> createState() => _FeaturesScreenState();
}

class _FeaturesScreenState extends State<FeaturesScreen> with TickerProviderStateMixin {
  final PageController _controller = PageController();
  int _currentPage = 0;
  late AnimationController _iconController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;

  final List<Map<String, dynamic>> _features = [
    {
      "title": "Medicine Reminders",
      "description": "Never miss your daily doses. Set personalized reminders for all your medications.",
      "icon": Icons.medication_rounded,
      "color": AppColors.primary,
      "gradient": const LinearGradient(
        colors: [Color(0xFF00897B), Color(0xFF26A69A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
    {
      "title": "Timely Alerts",
      "description": "Get gentle, smart notifications at the perfect time for your health routine.",
      "icon": Icons.notifications_active_rounded,
      "color": AppColors.info,
      "gradient": const LinearGradient(
        colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
    {
      "title": "Sugar & Pressure Checks",
      "description": "Track your blood sugar and pressure levels. Monitor vital health metrics easily.",
      "icon": Icons.monitor_heart_rounded,
      "color": AppColors.error,
      "gradient": const LinearGradient(
        colors: [Color(0xFFEF4444), Color(0xFFF87171)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
    {
      "title": "Period Tracking",
      "description": "Monitor your cycle with ease. Get predictions and helpful insights.",
      "icon": Icons.favorite_rounded,
      "color": AppColors.periodPrimary,
      "gradient": const LinearGradient(
        colors: [Color(0xFFE91E63), Color(0xFFF06292)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
    {
      "title": "Daily Health Routine",
      "description": "Build consistent healthy habits. Your personal wellness companion.",
      "icon": Icons.calendar_month_rounded,
      "color": AppColors.success,
      "gradient": const LinearGradient(
        colors: [Color(0xFF10B981), Color(0xFF34D399)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
  ];

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.elasticOut),
    );
    _rotateAnimation = Tween<double>(begin: -0.1, end: 0.0).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.easeOut),
    );
    _iconController.forward();
  }

  @override
  void dispose() {
    _iconController.dispose();
    super.dispose();
  }

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
                  child: const Text("Skip", style: TextStyle(color: AppColors.textSecondary)),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _features.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                  _iconController.reset();
                  _iconController.forward();
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
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
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
            // Premium CTA Button
            Padding(
              padding: const EdgeInsets.fromLTRB(40, 0, 40, 48),
              child: Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  gradient: _currentPage == _features.length - 1
                      ? AppColors.primaryGradient
                      : LinearGradient(
                          colors: [
                            _features[_currentPage]["color"] as Color,
                            (_features[_currentPage]["color"] as Color).withOpacity(0.8),
                          ],
                        ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (_features[_currentPage]["color"] as Color).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    if (_currentPage < _features.length - 1) {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOutCubic,
                      );
                    } else {
                      _navigateToHome();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _currentPage < _features.length - 1 ? "Next" : "Get Started",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
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
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          // Premium Animated Icon
          ScaleTransition(
            scale: _scaleAnimation,
            child: RotationTransition(
              turns: _rotateAnimation,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: feature["gradient"],
                  boxShadow: [
                    BoxShadow(
                      color: (feature["color"] as Color).withOpacity(0.4),
                      blurRadius: 40,
                      spreadRadius: 0,
                      offset: const Offset(0, 20),
                    ),
                    BoxShadow(
                      color: (feature["color"] as Color).withOpacity(0.2),
                      blurRadius: 80,
                      spreadRadius: -10,
                      offset: const Offset(0, 30),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    feature["icon"],
                    size: 55,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 56),
          // Title
          Text(
            feature["title"],
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 28,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          // Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              feature["description"],
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
                height: 1.6,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
            ),
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }

  void _navigateToHome() async {
    await StorageService.setOnboardingComplete();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const CategorySelectionScreen(isOnboarding: true),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }
}
