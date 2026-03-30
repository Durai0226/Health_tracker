import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Particle data model
class Particle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  double opacity;
  double rotation;
  double rotationSpeed;
  Color color;
  ParticleShape shape;
  double lifetime;
  double age;

  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.opacity,
    required this.rotation,
    required this.rotationSpeed,
    required this.color,
    required this.shape,
    required this.lifetime,
    this.age = 0,
  });

  bool get isAlive => age < lifetime;
  
  double get progress => (age / lifetime).clamp(0.0, 1.0);
  
  double get currentOpacity => opacity * (1 - progress);
  
  double get currentSize => size * (1 - progress * 0.3);
}

/// Particle shapes
enum ParticleShape {
  circle,
  star,
  sparkle,
  bubble,
  confetti,
  glow,
}

/// Particle effect types
enum ParticleEffectType {
  celebration,    // Confetti burst
  bubbles,        // Rising bubbles (water)
  sparkles,       // Twinkling sparkles
  glow,           // Soft glow particles
  confetti,       // Falling confetti
  rings,          // Expanding rings (focus)
  coins,          // Coin sparkles (finance)
  fire,           // Fire particles (streak)
}

/// Particle system widget
class ParticleSystem extends StatefulWidget {
  final ParticleEffectType effectType;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isPlaying;
  final int particleCount;
  final Size containerSize;

  const ParticleSystem({
    super.key,
    required this.effectType,
    required this.primaryColor,
    required this.secondaryColor,
    this.isPlaying = true,
    this.particleCount = 20,
    this.containerSize = const Size(400, 100),
  });

  @override
  State<ParticleSystem> createState() => _ParticleSystemState();
}

class _ParticleSystemState extends State<ParticleSystem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    if (widget.isPlaying) {
      _spawnParticles();
      _controller.repeat();
      _controller.addListener(_updateParticles);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _spawnParticles() {
    _particles.clear();
    
    for (int i = 0; i < widget.particleCount; i++) {
      _particles.add(_createParticle());
    }
  }

  Particle _createParticle() {
    final size = widget.containerSize;
    
    switch (widget.effectType) {
      case ParticleEffectType.celebration:
        return _createCelebrationParticle(size);
      case ParticleEffectType.bubbles:
        return _createBubbleParticle(size);
      case ParticleEffectType.sparkles:
        return _createSparkleParticle(size);
      case ParticleEffectType.glow:
        return _createGlowParticle(size);
      case ParticleEffectType.confetti:
        return _createConfettiParticle(size);
      case ParticleEffectType.rings:
        return _createRingParticle(size);
      case ParticleEffectType.coins:
        return _createCoinParticle(size);
      case ParticleEffectType.fire:
        return _createFireParticle(size);
    }
  }

  Particle _createCelebrationParticle(Size size) {
    return Particle(
      x: size.width / 2 + (_random.nextDouble() - 0.5) * 100,
      y: size.height / 2,
      vx: (_random.nextDouble() - 0.5) * 8,
      vy: -_random.nextDouble() * 6 - 2,
      size: _random.nextDouble() * 8 + 4,
      opacity: 1.0,
      rotation: _random.nextDouble() * math.pi * 2,
      rotationSpeed: (_random.nextDouble() - 0.5) * 0.3,
      color: _random.nextBool() ? widget.primaryColor : widget.secondaryColor,
      shape: ParticleShape.confetti,
      lifetime: _random.nextDouble() * 1.5 + 1.0,
    );
  }

  Particle _createBubbleParticle(Size size) {
    return Particle(
      x: _random.nextDouble() * size.width,
      y: size.height + 20,
      vx: (_random.nextDouble() - 0.5) * 1,
      vy: -_random.nextDouble() * 2 - 1,
      size: _random.nextDouble() * 10 + 5,
      opacity: 0.6,
      rotation: 0,
      rotationSpeed: 0,
      color: widget.primaryColor.withOpacity(0.4),
      shape: ParticleShape.bubble,
      lifetime: _random.nextDouble() * 2 + 2,
    );
  }

  Particle _createSparkleParticle(Size size) {
    return Particle(
      x: _random.nextDouble() * size.width,
      y: _random.nextDouble() * size.height,
      vx: 0,
      vy: 0,
      size: _random.nextDouble() * 6 + 2,
      opacity: _random.nextDouble() * 0.5 + 0.5,
      rotation: _random.nextDouble() * math.pi * 2,
      rotationSpeed: (_random.nextDouble() - 0.5) * 0.1,
      color: _random.nextBool() ? widget.primaryColor : widget.secondaryColor,
      shape: ParticleShape.sparkle,
      lifetime: _random.nextDouble() * 1.5 + 0.5,
    );
  }

  Particle _createGlowParticle(Size size) {
    return Particle(
      x: _random.nextDouble() * size.width,
      y: _random.nextDouble() * size.height,
      vx: (_random.nextDouble() - 0.5) * 0.5,
      vy: (_random.nextDouble() - 0.5) * 0.5,
      size: _random.nextDouble() * 15 + 10,
      opacity: 0.3,
      rotation: 0,
      rotationSpeed: 0,
      color: widget.primaryColor,
      shape: ParticleShape.glow,
      lifetime: _random.nextDouble() * 2 + 1,
    );
  }

  Particle _createConfettiParticle(Size size) {
    final colors = [
      widget.primaryColor,
      widget.secondaryColor,
      Colors.yellow,
      Colors.pink,
      Colors.cyan,
    ];
    return Particle(
      x: _random.nextDouble() * size.width,
      y: -20,
      vx: (_random.nextDouble() - 0.5) * 2,
      vy: _random.nextDouble() * 3 + 2,
      size: _random.nextDouble() * 8 + 4,
      opacity: 1.0,
      rotation: _random.nextDouble() * math.pi * 2,
      rotationSpeed: (_random.nextDouble() - 0.5) * 0.2,
      color: colors[_random.nextInt(colors.length)],
      shape: ParticleShape.confetti,
      lifetime: _random.nextDouble() * 2 + 2,
    );
  }

  Particle _createRingParticle(Size size) {
    return Particle(
      x: size.width / 2,
      y: size.height / 2,
      vx: 0,
      vy: 0,
      size: 10,
      opacity: 0.8,
      rotation: 0,
      rotationSpeed: 0,
      color: widget.primaryColor,
      shape: ParticleShape.circle,
      lifetime: 1.5,
    );
  }

  Particle _createCoinParticle(Size size) {
    return Particle(
      x: _random.nextDouble() * size.width,
      y: _random.nextDouble() * size.height,
      vx: (_random.nextDouble() - 0.5) * 1,
      vy: -_random.nextDouble() * 1,
      size: _random.nextDouble() * 4 + 2,
      opacity: 1.0,
      rotation: _random.nextDouble() * math.pi * 2,
      rotationSpeed: (_random.nextDouble() - 0.5) * 0.2,
      color: const Color(0xFFFFD700),
      shape: ParticleShape.star,
      lifetime: _random.nextDouble() * 1.5 + 0.5,
    );
  }

  Particle _createFireParticle(Size size) {
    return Particle(
      x: size.width / 2 + (_random.nextDouble() - 0.5) * 30,
      y: size.height,
      vx: (_random.nextDouble() - 0.5) * 1,
      vy: -_random.nextDouble() * 3 - 1,
      size: _random.nextDouble() * 8 + 4,
      opacity: 1.0,
      rotation: 0,
      rotationSpeed: 0,
      color: Color.lerp(
        const Color(0xFFFF6B00),
        const Color(0xFFFFD700),
        _random.nextDouble(),
      )!,
      shape: ParticleShape.circle,
      lifetime: _random.nextDouble() * 1 + 0.5,
    );
  }

  void _updateParticles() {
    if (!mounted) return;
    
    setState(() {
      for (var particle in _particles) {
        particle.age += 0.016; // ~60fps
        particle.x += particle.vx;
        particle.y += particle.vy;
        particle.rotation += particle.rotationSpeed;
        
        // Add gravity for some effects
        if (widget.effectType == ParticleEffectType.celebration ||
            widget.effectType == ParticleEffectType.confetti) {
          particle.vy += 0.1;
        }
        
        // Respawn dead particles
        if (!particle.isAlive) {
          final index = _particles.indexOf(particle);
          _particles[index] = _createParticle();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: widget.containerSize,
      painter: ParticlePainter(
        particles: _particles,
        effectType: widget.effectType,
      ),
    );
  }
}

/// Particle painter
class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final ParticleEffectType effectType;

  ParticlePainter({
    required this.particles,
    required this.effectType,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      if (!particle.isAlive) continue;
      
      final paint = Paint()
        ..color = particle.color.withOpacity(particle.currentOpacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(particle.x, particle.y);
      canvas.rotate(particle.rotation);

      switch (particle.shape) {
        case ParticleShape.circle:
          canvas.drawCircle(Offset.zero, particle.currentSize / 2, paint);
          break;
          
        case ParticleShape.star:
          _drawStar(canvas, particle.currentSize, paint);
          break;
          
        case ParticleShape.sparkle:
          _drawSparkle(canvas, particle.currentSize, paint);
          break;
          
        case ParticleShape.bubble:
          _drawBubble(canvas, particle.currentSize, paint);
          break;
          
        case ParticleShape.confetti:
          _drawConfetti(canvas, particle.currentSize, paint);
          break;
          
        case ParticleShape.glow:
          _drawGlow(canvas, particle.currentSize, paint);
          break;
      }

      canvas.restore();
    }
  }

  void _drawStar(Canvas canvas, double size, Paint paint) {
    final path = Path();
    final outerRadius = size / 2;
    final innerRadius = outerRadius * 0.4;
    
    for (int i = 0; i < 5; i++) {
      final outerAngle = (i * 72 - 90) * math.pi / 180;
      final innerAngle = ((i * 72) + 36 - 90) * math.pi / 180;
      
      if (i == 0) {
        path.moveTo(
          outerRadius * math.cos(outerAngle),
          outerRadius * math.sin(outerAngle),
        );
      } else {
        path.lineTo(
          outerRadius * math.cos(outerAngle),
          outerRadius * math.sin(outerAngle),
        );
      }
      
      path.lineTo(
        innerRadius * math.cos(innerAngle),
        innerRadius * math.sin(innerAngle),
      );
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawSparkle(Canvas canvas, double size, Paint paint) {
    final halfSize = size / 2;
    
    // Four-pointed sparkle
    final path = Path()
      ..moveTo(0, -halfSize)
      ..lineTo(halfSize * 0.2, 0)
      ..lineTo(halfSize, 0)
      ..lineTo(halfSize * 0.2, 0)
      ..lineTo(0, halfSize)
      ..lineTo(-halfSize * 0.2, 0)
      ..lineTo(-halfSize, 0)
      ..lineTo(-halfSize * 0.2, 0)
      ..close();
    
    canvas.drawPath(path, paint);
  }

  void _drawBubble(Canvas canvas, double size, Paint paint) {
    // Outer bubble
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.5;
    canvas.drawCircle(Offset.zero, size / 2, paint);
    
    // Inner highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(-size * 0.15, -size * 0.15),
      size * 0.15,
      highlightPaint,
    );
  }

  void _drawConfetti(Canvas canvas, double size, Paint paint) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: size, height: size * 0.4),
      const Radius.circular(2),
    );
    canvas.drawRRect(rect, paint);
  }

  void _drawGlow(Canvas canvas, double size, Paint paint) {
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset.zero, size / 2, paint);
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) => true;
}

/// Helper extension for particle effects based on feature
extension ParticleEffectForFeature on ParticleEffectType {
  static ParticleEffectType fromFeatureName(String feature) {
    switch (feature) {
      case 'water':
        return ParticleEffectType.bubbles;
      case 'focus':
        return ParticleEffectType.rings;
      case 'finance':
        return ParticleEffectType.coins;
      case 'habit':
        return ParticleEffectType.fire;
      case 'achievement':
        return ParticleEffectType.celebration;
      default:
        return ParticleEffectType.sparkles;
    }
  }
}
