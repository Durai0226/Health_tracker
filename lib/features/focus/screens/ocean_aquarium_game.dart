import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/relaxation_game_service.dart';
import '../widgets/relaxation_game_widgets.dart';
import 'ocean_aquarium_game_painters.dart';

/// Ocean Calm Aquarium - A relaxing underwater experience
class OceanAquariumGame extends StatefulWidget {
  const OceanAquariumGame({super.key});

  @override
  State<OceanAquariumGame> createState() => _OceanAquariumGameState();
}

class _OceanAquariumGameState extends State<OceanAquariumGame>
    with TickerProviderStateMixin {
  final RelaxationGameService _service = RelaxationGameService();
  final List<Fish> _fishes = [];
  final List<Bubble> _bubbles = [];
  final List<Seaweed> _seaweeds = [];
  final List<Jellyfish> _jellyfish = [];
  final List<Coral> _corals = [];
  final List<Particle> _particles = [];
  final Random _random = Random();
  TreasureChest? _treasureChest;
  
  late AnimationController _waveController;
  late AnimationController _bubbleController;
  late AnimationController _lightController;
  late AnimationController _jellyfishController;
  late AnimationController _particleController;
  late AnimationController _treasureController;
  
  bool _isDayMode = true;
  int _coins = 0;

  @override
  void initState() {
    super.initState();
    _service.init();
    _service.startSession();
    
    _waveController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();
    
    _bubbleController = AnimationController(
      duration: const Duration(milliseconds: 50),
      vsync: this,
    )..repeat();
    
    _lightController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat(reverse: true);
    
    _jellyfishController = AnimationController(
      duration: const Duration(milliseconds: 50),
      vsync: this,
    )..repeat();
    
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 50),
      vsync: this,
    )..repeat();
    
    _treasureController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    
    _bubbleController.addListener(_updateBubbles);
    _jellyfishController.addListener(_updateJellyfish);
    _particleController.addListener(_updateParticles);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAquarium();
    });
  }

  void _initializeAquarium() {
    final size = MediaQuery.of(context).size;
    
    // Add initial fishes with more variety
    for (int i = 0; i < 12; i++) {
      _fishes.add(_createRandomFish(size));
    }
    
    // Add seaweeds
    for (int i = 0; i < 6; i++) {
      _seaweeds.add(Seaweed(
        x: 50 + _random.nextDouble() * (size.width - 100),
        height: 80 + _random.nextDouble() * 120,
        color: Color.lerp(
          const Color(0xFF10B981),
          const Color(0xFF059669),
          _random.nextDouble(),
        )!,
      ));
    }
    
    // Add jellyfish
    for (int i = 0; i < 4; i++) {
      _jellyfish.add(Jellyfish(
        x: _random.nextDouble() * size.width,
        y: 50 + _random.nextDouble() * 200,
        size: 40 + _random.nextDouble() * 40,
        speedY: 0.2 + _random.nextDouble() * 0.3,
        pulsePhase: _random.nextDouble() * pi * 2,
        color: _random.nextBool() 
            ? const Color(0xFF8B5CF6).withOpacity(0.6)
            : const Color(0xFF06B6D4).withOpacity(0.6),
      ));
    }
    
    // Add coral reefs
    for (int i = 0; i < 8; i++) {
      _corals.add(Coral(
        x: 30 + _random.nextDouble() * (size.width - 60),
        y: size.height - 100 - _random.nextDouble() * 50,
        type: CoralType.values[_random.nextInt(CoralType.values.length)],
        size: 30 + _random.nextDouble() * 50,
      ));
    }
    
    // Add treasure chest
    _treasureChest = TreasureChest(
      x: size.width / 2,
      y: size.height - 120,
      isOpen: false,
    );
    
    // Add ambient particles
    for (int i = 0; i < 30; i++) {
      _particles.add(Particle(
        x: _random.nextDouble() * size.width,
        y: _random.nextDouble() * size.height,
        size: 1 + _random.nextDouble() * 2,
        speedY: -0.1 - _random.nextDouble() * 0.3,
        opacity: 0.3 + _random.nextDouble() * 0.4,
      ));
    }
    
    setState(() {});
  }

  Fish _createRandomFish(Size size) {
    final fishTypes = FishType.values;
    final type = fishTypes[_random.nextInt(fishTypes.length)];
    
    return Fish(
      id: DateTime.now().microsecondsSinceEpoch + _random.nextInt(10000),
      type: type,
      x: _random.nextDouble() * size.width,
      y: 100 + _random.nextDouble() * (size.height - 300),
      speedX: (0.5 + _random.nextDouble() * 1.5) * (_random.nextBool() ? 1 : -1),
      speedY: (_random.nextDouble() - 0.5) * 0.3,
      size: 40 + _random.nextDouble() * 30,
      wobbleOffset: _random.nextDouble() * pi * 2,
    );
  }

  void _updateBubbles() {
    if (!mounted) return;
    
    final size = MediaQuery.of(context).size;
    
    setState(() {
      // Update existing bubbles
      for (var bubble in _bubbles) {
        bubble.y -= bubble.speed;
        bubble.x += sin(bubble.wobble) * 0.5;
        bubble.wobble += 0.1;
        bubble.opacity -= 0.003;
      }
      
      // Remove dead bubbles
      _bubbles.removeWhere((b) => b.y < -50 || b.opacity <= 0);
      
      // Update fish positions
      for (var fish in _fishes) {
        fish.x += fish.speedX;
        fish.y += fish.speedY + sin(fish.wobbleOffset + _waveController.value * pi * 2) * 0.5;
        fish.wobbleOffset += 0.02;
        
        // Boundary check
        if (fish.x < -fish.size) {
          fish.x = size.width + fish.size;
        } else if (fish.x > size.width + fish.size) {
          fish.x = -fish.size;
        }
        
        if (fish.y < 80) {
          fish.speedY = _random.nextDouble() * 0.3;
        } else if (fish.y > size.height - 150) {
          fish.speedY = -_random.nextDouble() * 0.3;
        }
      }
    });
  }

  void _onTapFish(Fish fish) {
    HapticFeedback.lightImpact();
    _service.triggerBubblePopHaptic();
    
    // Create bubbles from fish
    for (int i = 0; i < 5; i++) {
      _bubbles.add(Bubble(
        x: fish.x + _random.nextDouble() * 30 - 15,
        y: fish.y,
        size: 5 + _random.nextDouble() * 10,
        speed: 1 + _random.nextDouble() * 2,
        wobble: _random.nextDouble() * pi * 2,
        opacity: 0.8,
      ));
    }
    
    setState(() {
      _coins += 1;
    });
  }

  void _onTapScreen(TapDownDetails details) {
    // Add bubbles where tapped
    for (int i = 0; i < 3; i++) {
      _bubbles.add(Bubble(
        x: details.localPosition.dx + _random.nextDouble() * 20 - 10,
        y: details.localPosition.dy,
        size: 8 + _random.nextDouble() * 15,
        speed: 1.5 + _random.nextDouble() * 2.5,
        wobble: _random.nextDouble() * pi * 2,
        opacity: 0.9,
      ));
    }
    
    _service.triggerWaterFlowHaptic();
  }

  void _feedFish() {
    HapticFeedback.mediumImpact();
    
    // Fish swim towards center briefly
    for (var fish in _fishes) {
      final centerX = MediaQuery.of(context).size.width / 2;
      fish.speedX = (centerX - fish.x) * 0.01;
    }
    
    // Reset after delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        for (var fish in _fishes) {
          fish.speedX = (0.5 + _random.nextDouble() * 1.5) * (_random.nextBool() ? 1 : -1);
        }
      }
    });
  }

  void _toggleDayNight() {
    HapticFeedback.selectionClick();
    setState(() {
      _isDayMode = !_isDayMode;
    });
  }

  void _updateJellyfish() {
    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    
    setState(() {
      for (var jelly in _jellyfish) {
        jelly.y += jelly.speedY;
        jelly.pulsePhase += 0.05;
        jelly.x += sin(jelly.pulsePhase) * 0.5;
        
        // Reset if goes off screen
        if (jelly.y > size.height) {
          jelly.y = -50;
          jelly.x = _random.nextDouble() * size.width;
        }
      }
    });
  }
  
  void _updateParticles() {
    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    
    setState(() {
      for (var particle in _particles) {
        particle.y += particle.speedY;
        particle.x += sin(particle.y * 0.01) * 0.2;
        
        // Reset if goes off screen
        if (particle.y < -10) {
          particle.y = size.height + 10;
          particle.x = _random.nextDouble() * size.width;
        }
      }
    });
  }
  
  void _onTreasureChestTap() {
    if (_treasureChest == null || _treasureChest!.isOpen) return;
    
    HapticFeedback.heavyImpact();
    _service.triggerCrystalHaptic();
    
    setState(() {
      _treasureChest!.isOpen = true;
      _coins += 10;
      
      // Add sparkle particles
      for (int i = 0; i < 20; i++) {
        _particles.add(Particle(
          x: _treasureChest!.x + (_random.nextDouble() - 0.5) * 60,
          y: _treasureChest!.y - 20,
          size: 2 + _random.nextDouble() * 3,
          speedY: -1 - _random.nextDouble() * 2,
          opacity: 1.0,
          isGolden: true,
        ));
      }
    });
    
    // Close after delay
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _treasureChest?.isOpen = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _waveController.dispose();
    _bubbleController.dispose();
    _lightController.dispose();
    _jellyfishController.dispose();
    _particleController.dispose();
    _treasureController.dispose();
    _service.endSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 800),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _isDayMode
                ? [
                    const Color(0xFF87CEEB),
                    const Color(0xFF0EA5E9),
                    const Color(0xFF0369A1),
                    const Color(0xFF1E3A5F),
                  ]
                : [
                    const Color(0xFF0F172A),
                    const Color(0xFF1E293B),
                    const Color(0xFF0F4C75),
                    const Color(0xFF0A2647),
                  ],
          ),
        ),
        child: GestureDetector(
          onTapDown: _onTapScreen,
          child: Stack(
            children: [
              // Animated light rays
              AnimatedBuilder(
                animation: _lightController,
                builder: (context, child) {
                  return CustomPaint(
                    size: MediaQuery.of(context).size,
                    painter: LightRaysPainter(
                      progress: _lightController.value,
                      isDayMode: _isDayMode,
                    ),
                  );
                },
              ),
              
              // Wave effect at top
              AnimatedBuilder(
                animation: _waveController,
                builder: (context, child) {
                  return CustomPaint(
                    size: MediaQuery.of(context).size,
                    painter: WavePainter(
                      progress: _waveController.value,
                      isDayMode: _isDayMode,
                    ),
                  );
                },
              ),
              
              // Ambient particles
              ...List.generate(_particles.length, (index) {
                final particle = _particles[index];
                return Positioned(
                  left: particle.x,
                  top: particle.y,
                  child: Container(
                    width: particle.size,
                    height: particle.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: particle.isGolden 
                          ? const Color(0xFFFFD700).withOpacity(particle.opacity)
                          : Colors.white.withOpacity(particle.opacity),
                      boxShadow: particle.isGolden ? [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withOpacity(0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ] : null,
                    ),
                  ),
                );
              }),
              
              // Coral reefs
              ...List.generate(_corals.length, (index) {
                final coral = _corals[index];
                return Positioned(
                  left: coral.x - coral.size / 2,
                  top: coral.y - coral.size,
                  child: CustomPaint(
                    size: Size(coral.size, coral.size),
                    painter: CoralPainter(
                      type: coral.type,
                      size: coral.size,
                    ),
                  ),
                );
              }),
              
              // Seaweeds
              ...List.generate(_seaweeds.length, (index) {
                final seaweed = _seaweeds[index];
                return AnimatedBuilder(
                  animation: _waveController,
                  builder: (context, child) {
                    return Positioned(
                      left: seaweed.x,
                      bottom: 0,
                      child: CustomPaint(
                        size: Size(30, seaweed.height),
                        painter: SeaweedPainter(
                          color: seaweed.color,
                          sway: sin(_waveController.value * pi * 2 + seaweed.x * 0.01) * 10,
                        ),
                      ),
                    );
                  },
                );
              }),
              
              // Sand/ground
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFFC2B280).withOpacity(0.3),
                        const Color(0xFFC2B280),
                        const Color(0xFFA0956E),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Decorative rocks
              ..._buildRocks(),
              
              // Fishes
              ...List.generate(_fishes.length, (index) {
                final fish = _fishes[index];
                return AnimatedBuilder(
                  animation: _waveController,
                  builder: (context, child) {
                    return Positioned(
                      left: fish.x - fish.size / 2,
                      top: fish.y - fish.size / 2,
                      child: GestureDetector(
                        onTap: () => _onTapFish(fish),
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..scale(fish.speedX > 0 ? 1.0 : -1.0, 1.0),
                          child: _buildFish(fish),
                        ),
                      ),
                    );
                  },
                );
              }),
              
              // Bubbles
              ...List.generate(_bubbles.length, (index) {
                final bubble = _bubbles[index];
                return Positioned(
                  left: bubble.x - bubble.size / 2,
                  top: bubble.y - bubble.size / 2,
                  child: _buildBubble(bubble),
                );
              }),
              
              // Jellyfish
              ...List.generate(_jellyfish.length, (index) {
                final jelly = _jellyfish[index];
                return AnimatedBuilder(
                  animation: _jellyfishController,
                  builder: (context, child) {
                    final pulseScale = 0.9 + sin(jelly.pulsePhase) * 0.1;
                    return Positioned(
                      left: jelly.x - jelly.size / 2,
                      top: jelly.y - jelly.size / 2,
                      child: CustomPaint(
                        size: Size(jelly.size, jelly.size),
                        painter: JellyfishPainter(
                          color: jelly.color,
                          pulseScale: pulseScale,
                        ),
                      ),
                    );
                  },
                );
              }),
              
              // Treasure chest
              if (_treasureChest != null)
                AnimatedBuilder(
                  animation: _treasureController,
                  builder: (context, child) {
                    final glow = _treasureChest!.isOpen 
                        ? 0.5 + sin(_treasureController.value * pi * 2) * 0.5
                        : 0.0;
                    return Positioned(
                      left: _treasureChest!.x - 40,
                      top: _treasureChest!.y - 40,
                      child: GestureDetector(
                        onTap: _onTreasureChestTap,
                        child: CustomPaint(
                          size: const Size(80, 80),
                          painter: TreasureChestPainter(
                            isOpen: _treasureChest!.isOpen,
                            glowIntensity: glow,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              
              // Header
              _buildHeader(),
              
              // Bottom controls
              _buildBottomControls(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildRocks() {
    return [
      Positioned(
        bottom: 30,
        left: 30,
        child: _buildRock(50, 35),
      ),
      Positioned(
        bottom: 25,
        right: 50,
        child: _buildRock(40, 30),
      ),
      Positioned(
        bottom: 35,
        left: MediaQuery.of(context).size.width * 0.4,
        child: _buildRock(60, 40),
      ),
    ];
  }

  Widget _buildRock(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6B7280),
            const Color(0xFF4B5563),
            const Color(0xFF374151),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 5,
            offset: const Offset(2, 3),
          ),
        ],
      ),
    );
  }

  Widget _buildFish(Fish fish) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        final tailWag = sin(_waveController.value * pi * 4 + fish.wobbleOffset) * 0.15;
        
        return SizedBox(
          width: fish.size,
          height: fish.size * 0.6,
          child: CustomPaint(
            painter: FishPainter(
              color: fish.type.color,
              secondaryColor: fish.type.secondaryColor,
              tailWag: tailWag,
              pattern: fish.type.pattern,
            ),
          ),
        );
      },
    );
  }

  Widget _buildBubble(Bubble bubble) {
    return Container(
      width: bubble.size,
      height: bubble.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.3),
          colors: [
            Colors.white.withOpacity(bubble.opacity * 0.9),
            Colors.white.withOpacity(bubble.opacity * 0.3),
            Colors.transparent,
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(bubble.opacity * 0.5),
          width: 1,
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
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: _isDayMode ? Colors.white : Colors.white70,
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
                  Row(
                    children: [
                      Text(
                        'Ocean Calm Aquarium',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _isDayMode ? Colors.white : Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_coins > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFD700).withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.stars, color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '$_coins',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  Text(
                    '${_fishes.length} fish • ${_jellyfish.length} jellyfish • ${_corals.length} corals',
                    style: TextStyle(
                      fontSize: 13,
                      color: _isDayMode ? Colors.white70 : Colors.white54,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _toggleDayNight,
              child: GlassmorphicContainer(
                blur: 15,
                opacity: 0.15,
                borderRadius: BorderRadius.circular(16),
                padding: const EdgeInsets.all(12),
                child: Icon(
                  _isDayMode ? Icons.nights_stay_rounded : Icons.wb_sunny_rounded,
                  color: _isDayMode ? Colors.amber : Colors.amber.shade200,
                  size: 24,
                ),
              ),
            ),
          ],
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
            onTap: _feedFish,
            child: GlassmorphicContainer(
              blur: 20,
              opacity: 0.2,
              borderRadius: BorderRadius.circular(20),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🐟', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    'Feed Fish',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _isDayMode ? Colors.white : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () {
              final size = MediaQuery.of(context).size;
              setState(() {
                _fishes.add(_createRandomFish(size));
              });
              HapticFeedback.mediumImpact();
            },
            child: GlassmorphicContainer(
              blur: 20,
              opacity: 0.2,
              borderRadius: BorderRadius.circular(20),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Add Fish',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _isDayMode ? Colors.white : Colors.white70,
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
enum FishType {
  tropical,
  clownfish,
  angelfish,
  bluefish,
  goldfish,
  pufferfish,
}

extension FishTypeExtension on FishType {
  Color get color {
    switch (this) {
      case FishType.tropical:
        return const Color(0xFFFF6B6B);
      case FishType.clownfish:
        return const Color(0xFFFF9F43);
      case FishType.angelfish:
        return const Color(0xFFA29BFE);
      case FishType.bluefish:
        return const Color(0xFF74B9FF);
      case FishType.goldfish:
        return const Color(0xFFFFD93D);
      case FishType.pufferfish:
        return const Color(0xFF6C5CE7);
    }
  }

  Color get secondaryColor {
    switch (this) {
      case FishType.tropical:
        return const Color(0xFFFFE66D);
      case FishType.clownfish:
        return Colors.white;
      case FishType.angelfish:
        return const Color(0xFFDFE6E9);
      case FishType.bluefish:
        return const Color(0xFF0984E3);
      case FishType.goldfish:
        return const Color(0xFFFF9F43);
      case FishType.pufferfish:
        return const Color(0xFFB8E994);
    }
  }

  FishPattern get pattern {
    switch (this) {
      case FishType.tropical:
        return FishPattern.stripes;
      case FishType.clownfish:
        return FishPattern.bands;
      case FishType.angelfish:
        return FishPattern.gradient;
      case FishType.bluefish:
        return FishPattern.solid;
      case FishType.goldfish:
        return FishPattern.solid;
      case FishType.pufferfish:
        return FishPattern.spots;
    }
  }
}

enum FishPattern { solid, stripes, bands, spots, gradient }

class Fish {
  final int id;
  final FishType type;
  double x;
  double y;
  double speedX;
  double speedY;
  double size;
  double wobbleOffset;

  Fish({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.speedX,
    required this.speedY,
    required this.size,
    required this.wobbleOffset,
  });
}

class Bubble {
  double x;
  double y;
  double size;
  double speed;
  double wobble;
  double opacity;

  Bubble({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.wobble,
    required this.opacity,
  });
}

class Seaweed {
  final double x;
  final double height;
  final Color color;

  Seaweed({required this.x, required this.height, required this.color});
}

class Jellyfish {
  double x;
  double y;
  double size;
  double speedY;
  double pulsePhase;
  Color color;

  Jellyfish({
    required this.x,
    required this.y,
    required this.size,
    required this.speedY,
    required this.pulsePhase,
    required this.color,
  });
}

enum CoralType { brain, fan, staghorn, mushroom }

class Coral {
  final double x;
  final double y;
  final CoralType type;
  final double size;

  Coral({
    required this.x,
    required this.y,
    required this.type,
    required this.size,
  });
}

class Particle {
  double x;
  double y;
  double size;
  double speedY;
  double opacity;
  bool isGolden;

  Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speedY,
    required this.opacity,
    this.isGolden = false,
  });
}

class TreasureChest {
  final double x;
  final double y;
  bool isOpen;

  TreasureChest({
    required this.x,
    required this.y,
    required this.isOpen,
  });
}

// Custom painters
class FishPainter extends CustomPainter {
  final Color color;
  final Color secondaryColor;
  final double tailWag;
  final FishPattern pattern;

  FishPainter({
    required this.color,
    required this.secondaryColor,
    required this.tailWag,
    required this.pattern,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    
    // Body
    final bodyPath = Path();
    final centerY = size.height / 2;
    final bodyLength = size.width * 0.7;
    
    bodyPath.moveTo(bodyLength, centerY);
    bodyPath.quadraticBezierTo(
      bodyLength * 0.6, centerY - size.height * 0.4,
      bodyLength * 0.2, centerY,
    );
    bodyPath.quadraticBezierTo(
      bodyLength * 0.6, centerY + size.height * 0.4,
      bodyLength, centerY,
    );
    
    paint.shader = LinearGradient(
      colors: [color, secondaryColor, color],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    
    canvas.drawPath(bodyPath, paint);
    
    // Tail
    final tailPath = Path();
    tailPath.moveTo(bodyLength * 0.2, centerY);
    tailPath.lineTo(0, centerY - size.height * 0.3 + tailWag * size.height);
    tailPath.lineTo(0, centerY + size.height * 0.3 + tailWag * size.height);
    tailPath.close();
    
    paint.shader = null;
    paint.color = color.withOpacity(0.8);
    canvas.drawPath(tailPath, paint);
    
    // Fin
    final finPath = Path();
    finPath.moveTo(bodyLength * 0.5, centerY - size.height * 0.2);
    finPath.lineTo(bodyLength * 0.6, centerY - size.height * 0.5);
    finPath.lineTo(bodyLength * 0.7, centerY - size.height * 0.2);
    finPath.close();
    
    paint.color = secondaryColor.withOpacity(0.7);
    canvas.drawPath(finPath, paint);
    
    // Eye
    paint.color = Colors.white;
    canvas.drawCircle(
      Offset(bodyLength * 0.75, centerY - size.height * 0.1),
      size.height * 0.12,
      paint,
    );
    
    paint.color = Colors.black;
    canvas.drawCircle(
      Offset(bodyLength * 0.78, centerY - size.height * 0.1),
      size.height * 0.06,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class WavePainter extends CustomPainter {
  final double progress;
  final bool isDayMode;

  WavePainter({required this.progress, required this.isDayMode});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDayMode ? Colors.white : Colors.white30).withOpacity(0.15)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, 40);
    
    for (double x = 0; x <= size.width; x++) {
      final y = 20 + sin((x / size.width * 4 * pi) + progress * pi * 2) * 15;
      path.lineTo(x, y);
    }
    
    path.lineTo(size.width, 0);
    path.lineTo(0, 0);
    path.close();
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class LightRaysPainter extends CustomPainter {
  final double progress;
  final bool isDayMode;

  LightRaysPainter({required this.progress, required this.isDayMode});

  @override
  void paint(Canvas canvas, Size size) {
    if (!isDayMode) return;
    
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);

    for (int i = 0; i < 5; i++) {
      final opacity = (0.03 + sin(progress * pi + i) * 0.02).clamp(0.0, 1.0);
      paint.color = Colors.white.withOpacity(opacity);
      
      final path = Path();
      final startX = size.width * (0.1 + i * 0.2);
      
      path.moveTo(startX, 0);
      path.lineTo(startX - 50 + sin(progress * pi) * 20, size.height);
      path.lineTo(startX + 80 + sin(progress * pi) * 20, size.height);
      path.lineTo(startX + 30, 0);
      path.close();
      
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class SeaweedPainter extends CustomPainter {
  final Color color;
  final double sway;

  SeaweedPainter({required this.color, required this.sway});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(size.width / 2 - 5, size.height);
    
    for (double y = size.height; y >= 0; y -= 10) {
      final progress = 1 - (y / size.height);
      final xOffset = sin(progress * pi * 2) * 8 + sway * progress;
      path.lineTo(size.width / 2 + xOffset - 3, y);
    }
    
    for (double y = 0; y <= size.height; y += 10) {
      final progress = 1 - (y / size.height);
      final xOffset = sin(progress * pi * 2) * 8 + sway * progress;
      path.lineTo(size.width / 2 + xOffset + 3, y);
    }
    
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
