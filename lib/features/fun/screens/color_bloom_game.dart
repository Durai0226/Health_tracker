import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/relaxation_game_service.dart';
import '../widgets/relaxation_game_widgets.dart';

/// Color Bloom - Fluid ink relaxation game
class ColorBloomGame extends StatefulWidget {
  const ColorBloomGame({super.key});

  @override
  State<ColorBloomGame> createState() => _ColorBloomGameState();
}

class _ColorBloomGameState extends State<ColorBloomGame>
    with TickerProviderStateMixin {
  final RelaxationGameService _service = RelaxationGameService();
  final List<InkBloom> _blooms = [];
  final Random _random = Random();
  
  late AnimationController _bloomController;
  late AnimationController _flowController;
  
  bool _slowMotionMode = false;
  int _bloomCount = 0;
  Color _currentColor = const Color(0xFF6366F1);
  
  final List<Color> _pastelColors = [
    const Color(0xFF6366F1),
    const Color(0xFFA855F7),
    const Color(0xFFEC4899),
    const Color(0xFFF97316),
    const Color(0xFFFBBF24),
    const Color(0xFF10B981),
    const Color(0xFF06B6D4),
    const Color(0xFF3B82F6),
  ];

  @override
  void initState() {
    super.initState();
    _service.init();
    _service.startSession();
    
    _bloomController = AnimationController(
      duration: const Duration(milliseconds: 50),
      vsync: this,
    )..repeat();
    
    _flowController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
    
    _bloomController.addListener(_updateBlooms);
  }

  void _updateBlooms() {
    if (!mounted) return;
    
    final speed = _slowMotionMode ? 0.3 : 1.0;
    
    setState(() {
      for (var bloom in _blooms) {
        if (bloom.radius < bloom.maxRadius) {
          bloom.radius += bloom.growthSpeed * speed;
          bloom.opacity = (1 - (bloom.radius / bloom.maxRadius)) * bloom.initialOpacity;
          
          // Add organic movement
          bloom.wobblePhase += 0.05 * speed;
          bloom.offsetX += sin(bloom.wobblePhase) * 0.3 * speed;
          bloom.offsetY += cos(bloom.wobblePhase * 0.7) * 0.2 * speed;
        }
      }
      
      // Remove fully expanded blooms
      _blooms.removeWhere((b) => b.radius >= b.maxRadius);
    });
  }

  void _createBloom(Offset position) {
    HapticFeedback.lightImpact();
    _service.triggerRippleHaptic();
    
    final color = _currentColor;
    
    // Main bloom
    _blooms.add(InkBloom(
      x: position.dx,
      y: position.dy,
      radius: 0,
      maxRadius: 100 + _random.nextDouble() * 150,
      color: color,
      growthSpeed: 1.5 + _random.nextDouble() * 1.5,
      initialOpacity: 0.7 + _random.nextDouble() * 0.3,
      opacity: 0.8,
      wobblePhase: _random.nextDouble() * pi * 2,
      offsetX: 0,
      offsetY: 0,
    ));
    
    // Secondary blooms for organic effect
    for (int i = 0; i < 3; i++) {
      final angle = _random.nextDouble() * pi * 2;
      final dist = 20 + _random.nextDouble() * 30;
      
      _blooms.add(InkBloom(
        x: position.dx + cos(angle) * dist,
        y: position.dy + sin(angle) * dist,
        radius: 0,
        maxRadius: 50 + _random.nextDouble() * 80,
        color: Color.lerp(color, _pastelColors[_random.nextInt(_pastelColors.length)], 0.3)!,
        growthSpeed: 1.0 + _random.nextDouble() * 1.0,
        initialOpacity: 0.5 + _random.nextDouble() * 0.3,
        opacity: 0.6,
        wobblePhase: _random.nextDouble() * pi * 2,
        offsetX: 0,
        offsetY: 0,
      ));
    }
    
    setState(() {
      _bloomCount++;
    });
    
    // Randomly change color occasionally
    if (_random.nextDouble() < 0.3) {
      _currentColor = _pastelColors[_random.nextInt(_pastelColors.length)];
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    // Create continuous bloom trail
    if (_random.nextDouble() < 0.4) {
      _createBloom(details.localPosition);
    }
  }

  void _toggleSlowMotion() {
    HapticFeedback.selectionClick();
    setState(() {
      _slowMotionMode = !_slowMotionMode;
    });
  }

  void _clearCanvas() {
    HapticFeedback.mediumImpact();
    setState(() {
      _blooms.clear();
    });
  }

  void _selectColor(Color color) {
    HapticFeedback.selectionClick();
    setState(() {
      _currentColor = color;
    });
  }

  @override
  void dispose() {
    _bloomController.dispose();
    _flowController.dispose();
    _service.endSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F0F1A),
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
            ],
          ),
        ),
        child: GestureDetector(
          onTapDown: (details) => _createBloom(details.localPosition),
          onPanUpdate: _onPanUpdate,
          child: Stack(
            children: [
              // Ambient background flow
              AnimatedBuilder(
                animation: _flowController,
                builder: (context, child) {
                  return CustomPaint(
                    size: MediaQuery.of(context).size,
                    painter: AmbientFlowPainter(
                      progress: _flowController.value,
                    ),
                  );
                },
              ),
              
              // Ink blooms
              CustomPaint(
                size: MediaQuery.of(context).size,
                painter: InkBloomPainter(blooms: _blooms),
              ),
              
              // Header
              _buildHeader(),
              
              // Color palette
              _buildColorPalette(),
              
              // Controls
              _buildControls(),
              
              // Instructions overlay
              if (_blooms.isEmpty && _bloomCount == 0)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '🎨',
                        style: TextStyle(fontSize: 64),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tap anywhere to bloom',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.white.withOpacity(0.6),
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Drag for continuous effect',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.4),
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
                    'Color Bloom',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '$_bloomCount blooms created',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
            if (_slowMotionMode)
              GlassmorphicContainer(
                blur: 10,
                opacity: 0.3,
                borderRadius: BorderRadius.circular(12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: const Text(
                  'SLOW',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPalette() {
    return Positioned(
      right: 16,
      top: MediaQuery.of(context).size.height * 0.15,
      child: GlassmorphicContainer(
        blur: 15,
        opacity: 0.1,
        borderRadius: BorderRadius.circular(24),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _pastelColors.map((color) {
            final isSelected = _currentColor == color;
            return GestureDetector(
              onTap: () => _selectColor(color),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(vertical: 4),
                width: isSelected ? 36 : 28,
                height: isSelected ? 36 : 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withOpacity(0.5),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
              ),
            );
          }).toList(),
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
            onTap: _toggleSlowMotion,
            child: GlassmorphicContainer(
              blur: 20,
              opacity: _slowMotionMode ? 0.3 : 0.15,
              borderRadius: BorderRadius.circular(20),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.slow_motion_video,
                    color: _slowMotionMode ? const Color(0xFF10B981) : Colors.white70,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Slow Motion',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _slowMotionMode ? const Color(0xFF10B981) : Colors.white70,
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
              opacity: 0.15,
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
class InkBloom {
  double x;
  double y;
  double radius;
  final double maxRadius;
  final Color color;
  final double growthSpeed;
  final double initialOpacity;
  double opacity;
  double wobblePhase;
  double offsetX;
  double offsetY;

  InkBloom({
    required this.x,
    required this.y,
    required this.radius,
    required this.maxRadius,
    required this.color,
    required this.growthSpeed,
    required this.initialOpacity,
    required this.opacity,
    required this.wobblePhase,
    required this.offsetX,
    required this.offsetY,
  });
}

// Custom painters
class InkBloomPainter extends CustomPainter {
  final List<InkBloom> blooms;

  InkBloomPainter({required this.blooms});

  @override
  void paint(Canvas canvas, Size size) {
    for (var bloom in blooms) {
      final centerX = bloom.x + bloom.offsetX;
      final centerY = bloom.y + bloom.offsetY;
      
      // Main bloom with gradient
      final gradient = RadialGradient(
        colors: [
          bloom.color.withOpacity(bloom.opacity),
          bloom.color.withOpacity(bloom.opacity * 0.6),
          bloom.color.withOpacity(bloom.opacity * 0.3),
          bloom.color.withOpacity(0),
        ],
        stops: const [0.0, 0.4, 0.7, 1.0],
      );
      
      final paint = Paint()
        ..shader = gradient.createShader(
          Rect.fromCircle(center: Offset(centerX, centerY), radius: bloom.radius),
        );
      
      canvas.drawCircle(Offset(centerX, centerY), bloom.radius, paint);
      
      // Inner glow
      final glowPaint = Paint()
        ..color = bloom.color.withOpacity(bloom.opacity * 0.3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, bloom.radius * 0.3);
      
      canvas.drawCircle(Offset(centerX, centerY), bloom.radius * 0.5, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class AmbientFlowPainter extends CustomPainter {
  final double progress;

  AmbientFlowPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100);

    // Flowing ambient shapes
    for (int i = 0; i < 3; i++) {
      final phase = progress * pi * 2 + i * pi * 0.6;
      final x = size.width * (0.3 + i * 0.2) + sin(phase) * size.width * 0.1;
      final y = size.height * (0.3 + i * 0.2) + cos(phase * 0.7) * size.height * 0.1;
      
      paint.color = [
        const Color(0xFF6366F1),
        const Color(0xFFA855F7),
        const Color(0xFF06B6D4),
      ][i].withOpacity(0.03);
      
      canvas.drawCircle(Offset(x, y), 150, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
