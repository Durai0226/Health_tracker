import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/auth_gate_sheet.dart';
import 'feature_selection_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  // Animation Controllers
  late AnimationController _mainController;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late AnimationController _floatController;
  late AnimationController _particleController;

  // Animations
  late Animation<double> _fadeIn;
  late Animation<double> _slideUp;
  late Animation<double> _scaleIn;
  late Animation<double> _logoGlow;
  late Animation<double> _shimmer;
  late Animation<double> _float;

  // Particle positions
  final List<_Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    _initParticles();
    _initAnimations();
  }

  void _initParticles() {
    final random = math.Random();
    for (int i = 0; i < 20; i++) {
      _particles.add(_Particle(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: random.nextDouble() * 4 + 2,
        speed: random.nextDouble() * 0.5 + 0.2,
        opacity: random.nextDouble() * 0.3 + 0.1,
      ));
    }
  }

  void _initAnimations() {
    // Main entrance animation
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _slideUp = Tween<double>(begin: 60.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.1, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _scaleIn = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    // Logo pulse/glow animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _logoGlow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Shimmer animation for button
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _shimmer = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    // Float animation for logo
    _floatController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _float = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    // Particle animation
    _particleController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );

    // Start animations
    _mainController.forward();
    _pulseController.repeat(reverse: true);
    _shimmerController.repeat();
    _floatController.repeat(reverse: true);
    _particleController.repeat();
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    _floatController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  Future<void> _navigateToFeatures() async {
    HapticFeedback.mediumImpact();
    
    final authService = AuthService();
    
    // Check if user is already authenticated
    if (!authService.isAuthenticated) {
      // Show auth gate for sign in or continue as guest
      final shouldProceed = await AuthGateSheet.show(
        context: context,
        featureName: 'Dlyminder',
        featureColor: AppColors.primary,
        featureIcon: Icons.auto_awesome_rounded,
      );
      
      if (!shouldProceed) return;
    }
    
    // Navigate to feature selection
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const FeatureSelectionScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.03),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                )),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFC),
      body: Stack(
        children: [
          // Animated gradient background
          _buildAnimatedBackground(size),

          // Floating particles
          _buildParticles(size),

          // Main content
          SafeArea(
            child: AnimatedBuilder(
              animation: _mainController,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeIn.value,
                  child: Transform.translate(
                    offset: Offset(0, _slideUp.value),
                    child: Transform.scale(
                      scale: _scaleIn.value,
                      child: child,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const Spacer(flex: 2),

                    // Animated Hero Logo with SVG
                    _buildAnimatedLogo(),
                    const SizedBox(height: 28),

                    // App Title with gradient
                    // _buildAppTitle(),
                    const SizedBox(height: 10),

                    // Catchy Tagline
                    _buildTagline(),

                    const Spacer(flex: 1),

                    // Premium Feature Grid
                    _buildFeatureGrid(),

                    const Spacer(flex: 2),

                    // Animated CTA Button
                    _buildAnimatedCTAButton(),
                    SizedBox(height: 20 + bottomPadding),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground(Size size) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Stack(
          children: [
            // Top-right gradient blob
            Positioned(
              top: -size.height * 0.12,
              right: -size.width * 0.25,
              child: Transform.scale(
                scale: 1.0 + (_logoGlow.value * 0.05),
                child: Container(
                  width: size.width * 0.7,
                  height: size.width * 0.7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.12 + _logoGlow.value * 0.03),
                        AppColors.primary.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Bottom-left gradient blob
            Positioned(
              bottom: -size.height * 0.08,
              left: -size.width * 0.2,
              child: Transform.scale(
                scale: 1.0 + ((1 - _logoGlow.value) * 0.05),
                child: Container(
                  width: size.width * 0.55,
                  height: size.width * 0.55,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF4ECDC4).withOpacity(0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Center accent blob
            Positioned(
              top: size.height * 0.35,
              left: size.width * 0.5 - 100,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF8B5CF6).withOpacity(0.06 + _logoGlow.value * 0.02),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildParticles(Size size) {
    return AnimatedBuilder(
      animation: _particleController,
      builder: (context, child) {
        return CustomPaint(
          size: size,
          painter: _ParticlePainter(
            particles: _particles,
            progress: _particleController.value,
            color: AppColors.primary,
          ),
        );
      },
    );
  }

  Widget _buildAnimatedLogo() {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _floatController]),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _float.value),
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary,
                  const Color(0xFF00A08A),
                  const Color(0xFF4ECDC4),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                // Glow effect
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.35 + _logoGlow.value * 0.15),
                  blurRadius: 30 + _logoGlow.value * 15,
                  spreadRadius: _logoGlow.value * 8,
                ),
                // Base shadow
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              child: Padding(
                padding: const EdgeInsets.all(0),
                child: SvgPicture.asset(
                  'assets/images/logo.svg',
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Widget _buildAppTitle() {
  //   return ShaderMask(
  //     shaderCallback: (bounds) => LinearGradient(
  //       colors: [
  //         const Color(0xFF1A1D29),
  //         AppColors.primary.withOpacity(0.9),
  //         const Color(0xFF1A1D29),
  //       ],
  //       stops: const [0.0, 0.5, 1.0],
  //     ).createShader(bounds),
  //     child: const Text(
  //       'Dlyminder',
  //       style: TextStyle(
  //         fontSize: 34,
  //         fontWeight: FontWeight.w800,
  //         letterSpacing: -1.5,
  //         color: Colors.white,
  //         height: 1.1,
  //       ),
  //     ),
  //   );
  // }

  Widget _buildTagline() {
    return const Text(
      'Your Life. Simplified.',
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: Color(0xFF6B7280),
        letterSpacing: 0.5,
        height: 1.4,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildFeatureGrid() {
    // Actual app categories from CategoryManager
    final features = [
      {'icon': Icons.favorite_rounded, 'label': 'Health', 'color': const Color(0xFF00897B)},
      {'icon': Icons.psychology_rounded, 'label': 'Focus', 'color': const Color(0xFF8B5CF6)},
      {'icon': Icons.fitness_center_rounded, 'label': 'Fitness', 'color': const Color(0xFFEF4444)},
      {'icon': Icons.account_balance_wallet_rounded, 'label': 'Finance', 'color': const Color(0xFF22C55E)},
      {'icon': Icons.calendar_month_rounded, 'label': 'Period', 'color': const Color(0xFFEC4899)},
      {'icon': Icons.auto_awesome_rounded, 'label': 'Fun', 'color': const Color(0xFFF59E0B)},
    ];

    return Column(
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                  SizedBox(width: 6),
                  Text(
                    '18+ Features',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6).withOpacity(0.85),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '+12 more',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Feature Grid (no outer white card)
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.05,
          ),
          itemCount: features.length,
          itemBuilder: (context, index) {
            final feature = features[index];
            return _buildFeatureItem(
              feature['icon'] as IconData,
              feature['label'] as String,
              feature['color'] as Color,
              index,
            );
          },
        ),
      ],
    );
  }

  Widget _buildFeatureItem(IconData icon, String label, Color color, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 80)),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.15),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, color.withOpacity(0.8)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color.withOpacity(0.9),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedCTAButton() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return GestureDetector(
          onTap: _navigateToFeatures,
          child: Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary,
                  const Color(0xFF4ECDC4),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.4),
                  blurRadius: 25,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: [
                  // Shimmer highlight (keeps text readable)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final w = constraints.maxWidth;
                          return Transform.translate(
                            offset: Offset(w * (_shimmer.value - 0.5), 0),
                            child: Container(
                              width: w * 0.35,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Colors.white.withOpacity(0.0),
                                    Colors.white.withOpacity(0.18),
                                    Colors.white.withOpacity(0.0),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // Button content
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Begin Your Journey',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Particle class for background animation
class _Particle {
  double x;
  double y;
  final double size;
  final double speed;
  final double opacity;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}

// Custom painter for particles
class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final Color color;

  _ParticlePainter({
    required this.particles,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final y = (particle.y + progress * particle.speed) % 1.0;
      final paint = Paint()
        ..color = color.withOpacity(particle.opacity * (1 - y * 0.5))
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(particle.x * size.width, y * size.height),
        particle.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
