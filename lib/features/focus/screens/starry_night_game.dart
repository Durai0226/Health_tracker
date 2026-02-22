import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/relaxation_game_service.dart';
import '../widgets/relaxation_game_widgets.dart';

/// Starry Night Creator - Create constellations in the night sky
class StarryNightGame extends StatefulWidget {
  const StarryNightGame({super.key});

  @override
  State<StarryNightGame> createState() => _StarryNightGameState();
}

class _StarryNightGameState extends State<StarryNightGame>
    with TickerProviderStateMixin {
  final RelaxationGameService _service = RelaxationGameService();
  final List<Star> _stars = [];
  final List<Constellation> _constellations = [];
  final List<ShootingStar> _shootingStars = [];
  final Random _random = Random();
  
  late AnimationController _twinkleController;
  late AnimationController _shootingStarController;
  
  List<Star> _currentConstellation = [];
  bool _isDrawingMode = false;
  int _starsCreated = 0;

  @override
  void initState() {
    super.initState();
    _service.init();
    _service.startSession();
    
    _twinkleController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _shootingStarController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    
    _shootingStarController.addListener(_updateShootingStars);
    
    // Spawn initial background stars
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _spawnBackgroundStars();
      _scheduleShootingStar();
    });
  }

  void _spawnBackgroundStars() {
    final size = MediaQuery.of(context).size;
    for (int i = 0; i < 50; i++) {
      _stars.add(Star(
        id: i,
        x: _random.nextDouble() * size.width,
        y: _random.nextDouble() * size.height * 0.7 + 50,
        size: 1 + _random.nextDouble() * 2,
        brightness: 0.3 + _random.nextDouble() * 0.4,
        twinkleOffset: _random.nextDouble() * pi * 2,
        isUserCreated: false,
      ));
    }
    setState(() {});
  }

  void _scheduleShootingStar() {
    Future.delayed(Duration(seconds: 5 + _random.nextInt(10)), () {
      if (mounted) {
        _createShootingStar();
        _scheduleShootingStar();
      }
    });
  }

  void _createShootingStar() {
    final size = MediaQuery.of(context).size;
    setState(() {
      _shootingStars.add(ShootingStar(
        startX: _random.nextDouble() * size.width,
        startY: _random.nextDouble() * size.height * 0.3,
        angle: pi / 4 + _random.nextDouble() * pi / 4,
        speed: 5 + _random.nextDouble() * 3,
        length: 80 + _random.nextDouble() * 60,
        life: 1.0,
      ));
    });
    _service.triggerCrystalHaptic();
  }

  void _updateShootingStars() {
    if (!mounted) return;
    setState(() {
      for (var star in _shootingStars) {
        star.progress += 0.02;
        star.life -= 0.015;
      }
      _shootingStars.removeWhere((s) => s.life <= 0);
    });
  }

  void _onTapScreen(TapDownDetails details) {
    HapticFeedback.lightImpact();
    _service.triggerTapHaptic();
    
    final pos = details.localPosition;
    
    // Check if tapped on existing star
    Star? tappedStar;
    for (var star in _stars.where((s) => s.isUserCreated)) {
      final dist = (Offset(star.x, star.y) - pos).distance;
      if (dist < 25) {
        tappedStar = star;
        break;
      }
    }
    
    if (_isDrawingMode && tappedStar != null) {
      // Add to constellation
      if (!_currentConstellation.contains(tappedStar)) {
        setState(() {
          _currentConstellation.add(tappedStar!);
        });
        _service.triggerTapHaptic();
      }
    } else if (tappedStar == null) {
      // Create new star
      setState(() {
        _starsCreated++;
        _stars.add(Star(
          id: DateTime.now().microsecondsSinceEpoch,
          x: pos.dx,
          y: pos.dy,
          size: 4 + _random.nextDouble() * 4,
          brightness: 0.8 + _random.nextDouble() * 0.2,
          twinkleOffset: _random.nextDouble() * pi * 2,
          isUserCreated: true,
        ));
      });
    }
  }

  void _toggleDrawingMode() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_isDrawingMode && _currentConstellation.length >= 2) {
        // Save constellation
        _constellations.add(Constellation(
          stars: List.from(_currentConstellation),
          color: _getRandomConstellationColor(),
        ));
        _currentConstellation.clear();
      }
      _isDrawingMode = !_isDrawingMode;
    });
  }

  Color _getRandomConstellationColor() {
    final colors = [
      const Color(0xFF74B9FF),
      const Color(0xFFA29BFE),
      const Color(0xFFDFE6E9),
      const Color(0xFFFFD93D),
      const Color(0xFFFF9FF3),
    ];
    return colors[_random.nextInt(colors.length)];
  }

  void _clearCanvas() {
    HapticFeedback.mediumImpact();
    setState(() {
      _stars.removeWhere((s) => s.isUserCreated);
      _constellations.clear();
      _currentConstellation.clear();
      _starsCreated = 0;
    });
  }

  @override
  void dispose() {
    _twinkleController.dispose();
    _shootingStarController.dispose();
    _service.endSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F0F23),
              Color(0xFF1A1A3E),
              Color(0xFF2D1B4E),
              Color(0xFF1A0A30),
            ],
          ),
        ),
        child: GestureDetector(
          onTapDown: _onTapScreen,
          child: Stack(
            children: [
              // Milky way effect
              CustomPaint(
                size: MediaQuery.of(context).size,
                painter: MilkyWayPainter(),
              ),
              
              // Background stars with twinkle
              AnimatedBuilder(
                animation: _twinkleController,
                builder: (context, child) {
                  return CustomPaint(
                    size: MediaQuery.of(context).size,
                    painter: StarFieldPainter(
                      stars: _stars.where((s) => !s.isUserCreated).toList(),
                      twinkleProgress: _twinkleController.value,
                    ),
                  );
                },
              ),
              
              // Constellations
              CustomPaint(
                size: MediaQuery.of(context).size,
                painter: ConstellationPainter(
                  constellations: _constellations,
                  currentConstellation: _currentConstellation,
                  isDrawing: _isDrawingMode,
                ),
              ),
              
              // User created stars
              ...List.generate(
                _stars.where((s) => s.isUserCreated).length,
                (index) {
                  final star = _stars.where((s) => s.isUserCreated).elementAt(index);
                  return AnimatedBuilder(
                    animation: _twinkleController,
                    builder: (context, child) {
                      final twinkle = 0.7 + sin(_twinkleController.value * pi * 2 + star.twinkleOffset) * 0.3;
                      final isInConstellation = _currentConstellation.contains(star);
                      
                      return Positioned(
                        left: star.x - star.size,
                        top: star.y - star.size,
                        child: Container(
                          width: star.size * 2,
                          height: star.size * 2,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(star.brightness * twinkle),
                            boxShadow: [
                              BoxShadow(
                                color: (isInConstellation 
                                    ? const Color(0xFF74B9FF) 
                                    : Colors.white).withOpacity(0.6 * twinkle),
                                blurRadius: star.size * 3,
                                spreadRadius: star.size,
                              ),
                              if (isInConstellation)
                                BoxShadow(
                                  color: const Color(0xFF74B9FF).withOpacity(0.4),
                                  blurRadius: star.size * 5,
                                  spreadRadius: star.size * 2,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              
              // Shooting stars
              ...List.generate(_shootingStars.length, (index) {
                final star = _shootingStars[index];
                return CustomPaint(
                  size: MediaQuery.of(context).size,
                  painter: ShootingStarPainter(shootingStar: star),
                );
              }),
              
              // Moon
              Positioned(
                top: 80,
                right: 40,
                child: _buildMoon(),
              ),
              
              // Header
              _buildHeader(),
              
              // Controls
              _buildControls(),
              
              // Drawing mode indicator
              if (_isDrawingMode)
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.15,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GlassmorphicContainer(
                      blur: 10,
                      opacity: 0.2,
                      borderRadius: BorderRadius.circular(20),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Text(
                        'Tap stars to connect • ${_currentConstellation.length} selected',
                        style: const TextStyle(
                          color: Color(0xFF74B9FF),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
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

  Widget _buildMoon() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.2, -0.2),
          colors: [
            Color(0xFFFFFACD),
            Color(0xFFE6E6AA),
            Color(0xFFD4D496),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFFACD).withOpacity(0.3),
            blurRadius: 40,
            spreadRadius: 15,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Moon craters
          Positioned(
            top: 15,
            left: 20,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFCCCC88).withOpacity(0.5),
              ),
            ),
          ),
          Positioned(
            top: 35,
            left: 35,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFCCCC88).withOpacity(0.4),
              ),
            ),
          ),
          Positioned(
            top: 50,
            left: 15,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFCCCC88).withOpacity(0.3),
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
                    'Starry Night Creator',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '$_starsCreated stars • ${_constellations.length} constellations',
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

  Widget _buildControls() {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _toggleDrawingMode,
            child: GlassmorphicContainer(
              blur: 20,
              opacity: _isDrawingMode ? 0.4 : 0.2,
              borderRadius: BorderRadius.circular(20),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isDrawingMode ? Icons.check : Icons.gesture,
                    color: _isDrawingMode ? const Color(0xFF74B9FF) : Colors.white70,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isDrawingMode ? 'Done' : 'Connect',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _isDrawingMode ? const Color(0xFF74B9FF) : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _clearCanvas,
            child: GlassmorphicContainer(
              blur: 20,
              opacity: 0.2,
              borderRadius: BorderRadius.circular(20),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh, color: Colors.white70, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Clear',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Data models
class Star {
  final int id;
  final double x;
  final double y;
  final double size;
  final double brightness;
  final double twinkleOffset;
  final bool isUserCreated;

  Star({
    required this.id,
    required this.x,
    required this.y,
    required this.size,
    required this.brightness,
    required this.twinkleOffset,
    required this.isUserCreated,
  });

  @override
  bool operator ==(Object other) => other is Star && other.id == id;
  
  @override
  int get hashCode => id.hashCode;
}

class Constellation {
  final List<Star> stars;
  final Color color;

  Constellation({required this.stars, required this.color});
}

class ShootingStar {
  final double startX;
  final double startY;
  final double angle;
  final double speed;
  final double length;
  double progress;
  double life;

  ShootingStar({
    required this.startX,
    required this.startY,
    required this.angle,
    required this.speed,
    required this.length,
    this.progress = 0,
    required this.life,
  });
}

// Custom painters
class MilkyWayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50);
    
    final path = Path();
    path.moveTo(0, size.height * 0.3);
    path.quadraticBezierTo(
      size.width * 0.3, size.height * 0.2,
      size.width * 0.6, size.height * 0.35,
    );
    path.quadraticBezierTo(
      size.width * 0.9, size.height * 0.5,
      size.width, size.height * 0.4,
    );
    path.lineTo(size.width, size.height * 0.5);
    path.quadraticBezierTo(
      size.width * 0.8, size.height * 0.6,
      size.width * 0.5, size.height * 0.45,
    );
    path.quadraticBezierTo(
      size.width * 0.2, size.height * 0.3,
      0, size.height * 0.4,
    );
    path.close();
    
    paint.shader = LinearGradient(
      colors: [
        const Color(0xFF6366F1).withOpacity(0.05),
        const Color(0xFFA855F7).withOpacity(0.08),
        const Color(0xFF6366F1).withOpacity(0.05),
      ],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class StarFieldPainter extends CustomPainter {
  final List<Star> stars;
  final double twinkleProgress;

  StarFieldPainter({required this.stars, required this.twinkleProgress});

  @override
  void paint(Canvas canvas, Size size) {
    for (var star in stars) {
      final twinkle = 0.5 + sin(twinkleProgress * pi * 2 + star.twinkleOffset) * 0.5;
      
      final paint = Paint()
        ..color = Colors.white.withOpacity(star.brightness * twinkle);
      
      canvas.drawCircle(Offset(star.x, star.y), star.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ConstellationPainter extends CustomPainter {
  final List<Constellation> constellations;
  final List<Star> currentConstellation;
  final bool isDrawing;

  ConstellationPainter({
    required this.constellations,
    required this.currentConstellation,
    required this.isDrawing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw saved constellations
    for (var constellation in constellations) {
      _drawConstellationLines(canvas, constellation.stars, constellation.color);
    }
    
    // Draw current constellation being created
    if (isDrawing && currentConstellation.length >= 2) {
      _drawConstellationLines(canvas, currentConstellation, const Color(0xFF74B9FF));
    }
  }

  void _drawConstellationLines(Canvas canvas, List<Star> stars, Color color) {
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    
    final glowPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    
    for (int i = 0; i < stars.length - 1; i++) {
      final p1 = Offset(stars[i].x, stars[i].y);
      final p2 = Offset(stars[i + 1].x, stars[i + 1].y);
      
      canvas.drawLine(p1, p2, glowPaint);
      canvas.drawLine(p1, p2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ShootingStarPainter extends CustomPainter {
  final ShootingStar shootingStar;

  ShootingStarPainter({required this.shootingStar});

  @override
  void paint(Canvas canvas, Size size) {
    final progress = shootingStar.progress;
    final currentX = shootingStar.startX + cos(shootingStar.angle) * progress * 300;
    final currentY = shootingStar.startY + sin(shootingStar.angle) * progress * 300;
    
    final tailLength = shootingStar.length * shootingStar.life;
    final tailX = currentX - cos(shootingStar.angle) * tailLength;
    final tailY = currentY - sin(shootingStar.angle) * tailLength;
    
    final gradient = LinearGradient(
      colors: [
        Colors.transparent,
        Colors.white.withOpacity(shootingStar.life * 0.3),
        Colors.white.withOpacity(shootingStar.life),
      ],
    );
    
    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromPoints(Offset(tailX, tailY), Offset(currentX, currentY)),
      )
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(Offset(tailX, tailY), Offset(currentX, currentY), paint);
    
    // Head glow
    final glowPaint = Paint()
      ..color = Colors.white.withOpacity(shootingStar.life * 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    
    canvas.drawCircle(Offset(currentX, currentY), 3, glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
