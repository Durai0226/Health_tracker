import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/relaxation_game_service.dart';
import '../widgets/relaxation_game_widgets.dart';

/// Floating Lantern Wishes - Release lanterns with wishes into the sky
class FloatingLanternGame extends StatefulWidget {
  const FloatingLanternGame({super.key});

  @override
  State<FloatingLanternGame> createState() => _FloatingLanternGameState();
}

class _FloatingLanternGameState extends State<FloatingLanternGame>
    with TickerProviderStateMixin {
  final RelaxationGameService _service = RelaxationGameService();
  final List<Lantern> _lanterns = [];
  final List<String> _wishes = [];
  final Random _random = Random();
  final TextEditingController _wishController = TextEditingController();
  
  late AnimationController _floatController;
  late AnimationController _glowController;
  late AnimationController _starController;
  
  int _lanternsReleased = 0;
  bool _showWishInput = false;
  LanternTheme _currentTheme = LanternTheme.classic;

  @override
  void initState() {
    super.initState();
    _service.init();
    _service.startSession();
    
    _floatController = AnimationController(
      duration: const Duration(milliseconds: 50),
      vsync: this,
    )..repeat();
    
    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _starController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    
    _floatController.addListener(_updateLanterns);
  }

  void _updateLanterns() {
    if (!mounted) return;
    
    setState(() {
      for (var lantern in _lanterns) {
        // Gentle upward floating
        lantern.y -= lantern.speed;
        
        // Subtle horizontal sway
        lantern.swayPhase += 0.02;
        lantern.x += sin(lantern.swayPhase) * 0.3;
        
        // Slight rotation
        lantern.rotation = sin(lantern.swayPhase * 0.5) * 0.1;
        
        // Fade as it rises higher
        if (lantern.y < MediaQuery.of(context).size.height * 0.2) {
          lantern.opacity -= 0.005;
        }
        
        // Scale down slightly as it rises
        if (lantern.y < MediaQuery.of(context).size.height * 0.4) {
          lantern.scale = max(0.5, lantern.scale - 0.001);
        }
      }
      
      // Remove lanterns that have floated away
      _lanterns.removeWhere((l) => l.opacity <= 0 || l.y < -100);
    });
  }

  void _showWishDialog() {
    HapticFeedback.selectionClick();
    setState(() {
      _showWishInput = true;
    });
  }

  void _releaseLantern() {
    final wish = _wishController.text.trim();
    if (wish.isEmpty) return;
    
    HapticFeedback.mediumImpact();
    _service.triggerTapHaptic();
    
    final size = MediaQuery.of(context).size;
    
    setState(() {
      _wishes.add(wish);
      _lanterns.add(Lantern(
        id: DateTime.now().microsecondsSinceEpoch,
        x: size.width / 2 + (_random.nextDouble() - 0.5) * 100,
        y: size.height - 200,
        speed: 0.8 + _random.nextDouble() * 0.4,
        swayPhase: _random.nextDouble() * pi * 2,
        rotation: 0,
        opacity: 1.0,
        scale: 1.0,
        theme: _currentTheme,
        wish: wish,
        glowOffset: _random.nextDouble() * pi * 2,
      ));
      
      _lanternsReleased++;
      _showWishInput = false;
      _wishController.clear();
    });
    
    // Add sparkle effect
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _service.triggerCrystalHaptic();
    });
  }

  void _quickRelease() {
    HapticFeedback.lightImpact();
    _service.triggerTapHaptic();
    
    final size = MediaQuery.of(context).size;
    
    setState(() {
      _lanterns.add(Lantern(
        id: DateTime.now().microsecondsSinceEpoch,
        x: size.width * (0.2 + _random.nextDouble() * 0.6),
        y: size.height - 150 - _random.nextDouble() * 100,
        speed: 0.6 + _random.nextDouble() * 0.5,
        swayPhase: _random.nextDouble() * pi * 2,
        rotation: 0,
        opacity: 1.0,
        scale: 0.8 + _random.nextDouble() * 0.3,
        theme: _currentTheme,
        wish: null,
        glowOffset: _random.nextDouble() * pi * 2,
      ));
      _lanternsReleased++;
    });
  }

  void _selectTheme(LanternTheme theme) {
    HapticFeedback.selectionClick();
    setState(() {
      _currentTheme = theme;
    });
  }

  @override
  void dispose() {
    _floatController.dispose();
    _glowController.dispose();
    _starController.dispose();
    _wishController.dispose();
    _service.endSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A0A1A),
              Color(0xFF1A1A3E),
              Color(0xFF2D1B4E),
              Color(0xFF1A0A30),
            ],
          ),
        ),
        child: GestureDetector(
          onTapDown: (details) {
            if (!_showWishInput && details.localPosition.dy > 200) {
              _quickRelease();
            }
          },
          child: Stack(
            children: [
              // Stars background
              AnimatedBuilder(
                animation: _starController,
                builder: (context, child) {
                  return CustomPaint(
                    size: MediaQuery.of(context).size,
                    painter: NightSkyPainter(
                      twinkleProgress: _starController.value,
                    ),
                  );
                },
              ),
              
              // Mountains silhouette
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: CustomPaint(
                  size: Size(MediaQuery.of(context).size.width, 200),
                  painter: MountainSilhouettePainter(),
                ),
              ),
              
              // Floating lanterns
              ...List.generate(_lanterns.length, (index) {
                final lantern = _lanterns[index];
                return AnimatedBuilder(
                  animation: _glowController,
                  builder: (context, child) {
                    final glow = 0.7 + sin(_glowController.value * pi * 2 + lantern.glowOffset) * 0.3;
                    
                    return Positioned(
                      left: lantern.x - 40 * lantern.scale,
                      top: lantern.y - 60 * lantern.scale,
                      child: Transform.rotate(
                        angle: lantern.rotation,
                        child: Transform.scale(
                          scale: lantern.scale,
                          child: Opacity(
                            opacity: lantern.opacity,
                            child: _buildLantern(lantern, glow),
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
              
              // Header
              _buildHeader(),
              
              // Theme selector
              _buildThemeSelector(),
              
              // Bottom controls
              _buildBottomControls(),
              
              // Wish input overlay
              if (_showWishInput) _buildWishInput(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLantern(Lantern lantern, double glow) {
    final theme = lantern.theme;
    
    return SizedBox(
      width: 80,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow effect
          Container(
            width: 70,
            height: 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(35),
              boxShadow: [
                BoxShadow(
                  color: theme.glowColor.withOpacity(0.4 * glow),
                  blurRadius: 40,
                  spreadRadius: 15,
                ),
                BoxShadow(
                  color: theme.glowColor.withOpacity(0.2 * glow),
                  blurRadius: 60,
                  spreadRadius: 25,
                ),
              ],
            ),
          ),
          
          // Lantern body
          CustomPaint(
            size: const Size(80, 120),
            painter: LanternPainter(
              primaryColor: theme.primaryColor,
              secondaryColor: theme.secondaryColor,
              glowIntensity: glow,
            ),
          ),
          
          // Wish text (if any)
          if (lantern.wish != null)
            Positioned(
              top: 45,
              child: SizedBox(
                width: 50,
                child: Text(
                  lantern.wish!,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 6,
                    color: Colors.white.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
              child: GlassmorphicContainer(
                blur: 15,
                opacity: 0.15,
                borderRadius: BorderRadius.circular(16),
                padding: const EdgeInsets.all(12),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white70,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Floating Lanterns',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '$_lanternsReleased lanterns • ${_wishes.length} wishes',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSelector() {
    return Positioned(
      right: 16,
      top: MediaQuery.of(context).size.height * 0.15,
      child: GlassmorphicContainer(
        blur: 15,
        opacity: 0.1,
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: LanternTheme.values.map((theme) {
            final isSelected = _currentTheme == theme;
            return GestureDetector(
              onTap: () => _selectTheme(theme),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? theme.primaryColor.withOpacity(0.3) : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? theme.primaryColor : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Text(theme.emoji, style: const TextStyle(fontSize: 20)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _showWishDialog,
            child: GlassmorphicContainer(
              blur: 20,
              opacity: 0.2,
              borderRadius: BorderRadius.circular(24),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_currentTheme.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Make a Wish',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Release a lantern',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWishInput() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: GlassmorphicContainer(
          blur: 20,
          opacity: 0.2,
          borderRadius: BorderRadius.circular(24),
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentTheme.emoji,
                  style: const TextStyle(fontSize: 48),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Write Your Wish',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your wish will float into the sky',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _wishController,
                  autofocus: true,
                  maxLines: 3,
                  maxLength: 100,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter your wish...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    counterStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _showWishInput = false;
                            _wishController.clear();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Center(
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _releaseLantern,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _currentTheme.primaryColor,
                                _currentTheme.secondaryColor,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Center(
                            child: Text(
                              'Release ✨',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Enums and data models
enum LanternTheme {
  classic,
  golden,
  rose,
  ocean,
  festival,
}

extension LanternThemeExtension on LanternTheme {
  String get emoji {
    switch (this) {
      case LanternTheme.classic:
        return '🏮';
      case LanternTheme.golden:
        return '✨';
      case LanternTheme.rose:
        return '🌸';
      case LanternTheme.ocean:
        return '🌊';
      case LanternTheme.festival:
        return '🎆';
    }
  }

  Color get primaryColor {
    switch (this) {
      case LanternTheme.classic:
        return const Color(0xFFFF6B6B);
      case LanternTheme.golden:
        return const Color(0xFFFFD93D);
      case LanternTheme.rose:
        return const Color(0xFFFF9FF3);
      case LanternTheme.ocean:
        return const Color(0xFF74B9FF);
      case LanternTheme.festival:
        return const Color(0xFFA29BFE);
    }
  }

  Color get secondaryColor {
    switch (this) {
      case LanternTheme.classic:
        return const Color(0xFFFF9F43);
      case LanternTheme.golden:
        return const Color(0xFFF9CA24);
      case LanternTheme.rose:
        return const Color(0xFFFD79A8);
      case LanternTheme.ocean:
        return const Color(0xFF0984E3);
      case LanternTheme.festival:
        return const Color(0xFF6C5CE7);
    }
  }

  Color get glowColor {
    switch (this) {
      case LanternTheme.classic:
        return const Color(0xFFFF9F43);
      case LanternTheme.golden:
        return const Color(0xFFFFD93D);
      case LanternTheme.rose:
        return const Color(0xFFFF9FF3);
      case LanternTheme.ocean:
        return const Color(0xFF74B9FF);
      case LanternTheme.festival:
        return const Color(0xFFA29BFE);
    }
  }
}

class Lantern {
  final int id;
  double x;
  double y;
  final double speed;
  double swayPhase;
  double rotation;
  double opacity;
  double scale;
  final LanternTheme theme;
  final String? wish;
  final double glowOffset;

  Lantern({
    required this.id,
    required this.x,
    required this.y,
    required this.speed,
    required this.swayPhase,
    required this.rotation,
    required this.opacity,
    required this.scale,
    required this.theme,
    this.wish,
    required this.glowOffset,
  });
}

// Custom painters
class NightSkyPainter extends CustomPainter {
  final double twinkleProgress;

  NightSkyPainter({required this.twinkleProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(42);
    final paint = Paint();
    
    // Draw stars
    for (int i = 0; i < 80; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height * 0.7;
      final starSize = 0.5 + random.nextDouble() * 1.5;
      final twinkle = 0.4 + sin(twinkleProgress * pi * 2 + i) * 0.6;
      
      paint.color = Colors.white.withOpacity(twinkle * 0.8);
      canvas.drawCircle(Offset(x, y), starSize, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class MountainSilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0A0A15)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(0, size.height * 0.6);
    path.lineTo(size.width * 0.15, size.height * 0.4);
    path.lineTo(size.width * 0.25, size.height * 0.55);
    path.lineTo(size.width * 0.4, size.height * 0.25);
    path.lineTo(size.width * 0.55, size.height * 0.45);
    path.lineTo(size.width * 0.7, size.height * 0.2);
    path.lineTo(size.width * 0.85, size.height * 0.5);
    path.lineTo(size.width, size.height * 0.35);
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LanternPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;
  final double glowIntensity;

  LanternPainter({
    required this.primaryColor,
    required this.secondaryColor,
    required this.glowIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    
    // Lantern body
    final bodyPath = Path();
    bodyPath.moveTo(centerX - 25, 30);
    bodyPath.quadraticBezierTo(centerX - 30, 60, centerX - 20, 90);
    bodyPath.lineTo(centerX + 20, 90);
    bodyPath.quadraticBezierTo(centerX + 30, 60, centerX + 25, 30);
    bodyPath.close();

    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          primaryColor.withOpacity(0.9),
          secondaryColor.withOpacity(0.8),
        ],
      ).createShader(Rect.fromLTWH(0, 30, size.width, 60));

    canvas.drawPath(bodyPath, bodyPaint);

    // Top cap
    final capPaint = Paint()..color = const Color(0xFF2D2D2D);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(centerX - 20, 20, 40, 12),
        const Radius.circular(3),
      ),
      capPaint,
    );

    // Handle
    final handlePaint = Paint()
      ..color = const Color(0xFF4A4A4A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    final handlePath = Path();
    handlePath.moveTo(centerX - 10, 20);
    handlePath.quadraticBezierTo(centerX, 5, centerX + 10, 20);
    canvas.drawPath(handlePath, handlePaint);

    // Bottom
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(centerX - 18, 88, 36, 8),
        const Radius.circular(2),
      ),
      capPaint,
    );

    // Inner glow
    final glowPaint = Paint()
      ..color = Colors.white.withOpacity(0.3 * glowIntensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    
    canvas.drawOval(
      Rect.fromCenter(center: Offset(centerX, 60), width: 30, height: 40),
      glowPaint,
    );

    // Flame
    final flamePath = Path();
    flamePath.moveTo(centerX, 95);
    flamePath.quadraticBezierTo(centerX - 4, 102, centerX, 110);
    flamePath.quadraticBezierTo(centerX + 4, 102, centerX, 95);

    final flamePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFD93D), Color(0xFFFF9F43), Color(0xFFFF6B6B)],
      ).createShader(Rect.fromLTWH(centerX - 5, 95, 10, 20));

    canvas.drawPath(flamePath, flamePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
