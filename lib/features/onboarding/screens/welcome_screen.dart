
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import 'features_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(begin: Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withOpacity(0.1),
              AppColors.background,
              Colors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  children: [
                    Spacer(flex: 2),
                    // Premium Icon Container
                    Container(
                      padding: EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 30,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.medication_rounded,
                        size: 64,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 48),
                    // Title
                    Text(
                      "Tablet Reminder",
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: AppColors.primary,
                        letterSpacing: -1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16),
                    // Subtitle
                    Text(
                      "Never miss a dose.\nSimple reminders for your medication routine.",
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Spacer(flex: 3),
                    // Premium CTA Button
                    Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.4),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            PageRouteBuilder(
                              pageBuilder: (_, __, ___) => FeaturesScreen(),
                              transitionsBuilder: (_, animation, __, child) {
                                return FadeTransition(opacity: animation, child: child);
                              },
                              transitionDuration: Duration(milliseconds: 500),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Get Started", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
