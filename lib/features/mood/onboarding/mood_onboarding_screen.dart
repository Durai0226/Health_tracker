import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/mood_theme.dart';
import '../navigation/mood_tab_navigation.dart';

/// Onboarding screen for Mood Tracker matching Behance design
/// Dark background with floating emojis and smooth page transitions
class MoodOnboardingScreen extends StatefulWidget {
  const MoodOnboardingScreen({super.key});

  @override
  State<MoodOnboardingScreen> createState() => _MoodOnboardingScreenState();
}

class _MoodOnboardingScreenState extends State<MoodOnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _floatController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Welcome to\nMood Tracker',
      subtitle: 'Track your emotions, understand yourself better',
      emojis: ['😊', '🥰', '😌', '🤗'],
    ),
    OnboardingPage(
      title: 'Your Daily\nMood Check',
      subtitle: 'Quick daily check-ins to capture how you feel',
      emojis: ['😊', '😔', '😐', '🥰', '😣'],
    ),
    OnboardingPage(
      title: 'Track Daily\nYour Mood',
      subtitle: 'See patterns and insights over time',
      emojis: ['📊', '📈', '🎯', '✨'],
    ),
    OnboardingPage(
      title: 'Take Deep\nCalm Rest',
      subtitle: 'Breathing exercises for peace of mind',
      emojis: ['🧘', '💨', '🌿', '☁️'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _floatController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _nextPage() {
    HapticFeedback.lightImpact();
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _completeOnboarding() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const MoodTabNavigation(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // Skip button
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(MoodTheme.spacingMd),
                  child: TextButton(
                    onPressed: _completeOnboarding,
                    child: Text(
                      'Skip',
                      style: MoodTheme.titleSm.copyWith(
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ),
                ),
              ),

              // Page content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return _OnboardingPageView(
                      page: _pages[index],
                      floatController: _floatController,
                    );
                  },
                ),
              ),

              // Page indicators
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: MoodTheme.spacingLg,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pages.length, (index) {
                    final isActive = index == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isActive ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isActive
                            ? MoodTheme.purple400
                            : Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ),

              // Next/Get Started button
              Padding(
                padding: const EdgeInsets.all(MoodTheme.spacingLg),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MoodTheme.purple500,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: MoodTheme.borderRadiusRound,
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _currentPage == _pages.length - 1
                          ? 'Get Started'
                          : 'Next',
                      style: MoodTheme.button,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String subtitle;
  final List<String> emojis;

  const OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.emojis,
  });
}

class _OnboardingPageView extends StatelessWidget {
  final OnboardingPage page;
  final AnimationController floatController;

  const _OnboardingPageView({
    required this.page,
    required this.floatController,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MoodTheme.spacingLg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Floating emojis
          SizedBox(
            height: 250,
            child: Stack(
              alignment: Alignment.center,
              children: List.generate(page.emojis.length, (index) {
                return _FloatingEmoji(
                  emoji: page.emojis[index],
                  controller: floatController,
                  index: index,
                  total: page.emojis.length,
                );
              }),
            ),
          ),

          const SizedBox(height: 48),

          // Title
          Text(
            page.title,
            style: MoodTheme.headingXl.copyWith(
              color: Colors.white,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Subtitle
          Text(
            page.subtitle,
            style: MoodTheme.bodyLg.copyWith(
              color: Colors.white.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _FloatingEmoji extends StatelessWidget {
  final String emoji;
  final AnimationController controller;
  final int index;
  final int total;

  const _FloatingEmoji({
    required this.emoji,
    required this.controller,
    required this.index,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final angle = (index / total) * 2 * math.pi;
    final radius = 80.0 + (index % 2) * 30;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final floatOffset = math.sin(controller.value * 2 * math.pi + angle) * 15;
        final scaleOffset = 0.9 + math.sin(controller.value * 2 * math.pi + angle) * 0.1;

        final x = math.cos(angle) * radius;
        final y = math.sin(angle) * radius + floatOffset;

        return Transform.translate(
          offset: Offset(x, y),
          child: Transform.scale(
            scale: scaleOffset,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: MoodTheme.purple500.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Text(
                emoji,
                style: TextStyle(
                  fontSize: 36 + (index % 2) * 12,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
