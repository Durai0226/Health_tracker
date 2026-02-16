import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/relaxation_game_models.dart';
import '../services/relaxation_game_service.dart';
import '../widgets/relaxation_game_widgets.dart';

/// Main experience mode screen that switches between different modes
class ExperienceModeScreen extends StatefulWidget {
  final ExperienceMode mode;

  const ExperienceModeScreen({super.key, required this.mode});

  @override
  State<ExperienceModeScreen> createState() => _ExperienceModeScreenState();
}

class _ExperienceModeScreenState extends State<ExperienceModeScreen>
    with TickerProviderStateMixin {
  final RelaxationGameService _service = RelaxationGameService();
  
  @override
  void initState() {
    super.initState();
    _service.startSession();
  }

  @override
  void dispose() {
    _service.endSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _service,
      builder: (context, _) {
        return _buildModeScreen();
      },
    );
  }

  Widget _buildModeScreen() {
    switch (widget.mode) {
      case ExperienceMode.zenFlow:
        return ZenFlowScreen(service: _service);
      case ExperienceMode.liquidRipple:
        return LiquidRippleScreen(service: _service);
      case ExperienceMode.auraSculpt:
        return AuraSculptScreen(service: _service);
      case ExperienceMode.breathingRitual:
        return BreathingRitualScreen(service: _service);
      case ExperienceMode.cosmicDrift:
        return CosmicDriftScreen(service: _service);
      case ExperienceMode.emberMeditation:
        return EmberMeditationScreen(service: _service);
      case ExperienceMode.chromaticHarmony:
        return ChromaticHarmonyScreen(service: _service);
      case ExperienceMode.hypnoticLoop:
        return HypnoticLoopScreen(service: _service);
    }
  }
}

/// Base class for experience screens
abstract class BaseExperienceScreen extends StatefulWidget {
  final RelaxationGameService service;

  const BaseExperienceScreen({super.key, required this.service});
}

/// Zen Flow Mode - Light trails with haptics
class ZenFlowScreen extends StatefulWidget {
  final RelaxationGameService service;

  const ZenFlowScreen({super.key, required this.service});

  @override
  State<ZenFlowScreen> createState() => _ZenFlowScreenState();
}

class _ZenFlowScreenState extends State<ZenFlowScreen>
    with SingleTickerProviderStateMixin {
  final List<TouchPoint> _touchPoints = [];
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  void _addTouchPoint(Offset position) {
    setState(() {
      _touchPoints.add(TouchPoint(
        position: position,
        timestamp: DateTime.now(),
      ));
      
      // Keep only recent points
      if (_touchPoints.length > 100) {
        _touchPoints.removeAt(0);
      }
    });
    
    // Trigger haptic on movement
    if (_touchPoints.length % 5 == 0) {
      widget.service.triggerTapHaptic();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.service.settings.theme;
    const mode = ExperienceMode.zenFlow;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: AnimatedGradientBackground(
        theme: theme,
        child: GestureDetector(
          onPanStart: (details) => _addTouchPoint(details.localPosition),
          onPanUpdate: (details) => _addTouchPoint(details.localPosition),
          onPanEnd: (_) {
            // Fade out trail
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                setState(() => _touchPoints.clear());
              }
            });
          },
          child: Stack(
            children: [
              // Particles background
              ParticleSystemWidget(
                particleCount: (50 * widget.service.settings.particleDensity).round(),
                primaryColor: mode.primaryColor,
                secondaryColor: mode.secondaryColor,
                speed: widget.service.settings.animationSpeed,
                size: MediaQuery.of(context).size,
              ),
              
              // Light trail
              if (_touchPoints.isNotEmpty)
                LightTrailWidget(
                  points: _touchPoints,
                  color: mode.primaryColor,
                  width: 8 * widget.service.settings.glowIntensity,
                  glowIntensity: widget.service.settings.glowIntensity,
                ),
              
              // Header
              _buildHeader(context, mode, theme),
              
              // Instructions
              if (_touchPoints.isEmpty)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        mode.emoji,
                        style: const TextStyle(fontSize: 64),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Touch and drag to create',
                        style: TextStyle(
                          fontSize: 18,
                          color: theme.textColor.withOpacity(0.7),
                        ),
                      ),
                      Text(
                        'flowing light trails',
                        style: TextStyle(
                          fontSize: 18,
                          color: theme.textColor.withOpacity(0.7),
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

  Widget _buildHeader(BuildContext context, ExperienceMode mode, RelaxationTheme theme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
              child: GlassmorphicContainer(
                blur: 10,
                opacity: 0.1,
                borderRadius: BorderRadius.circular(14),
                padding: const EdgeInsets.all(10),
                child: Icon(Icons.close_rounded, color: theme.textColor, size: 22),
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  mode.name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: mode.primaryColor,
                  ),
                ),
                Text(
                  widget.service.formattedSessionTime,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Liquid Ripple Mode - Expanding ripples with haptics
class LiquidRippleScreen extends StatefulWidget {
  final RelaxationGameService service;

  const LiquidRippleScreen({super.key, required this.service});

  @override
  State<LiquidRippleScreen> createState() => _LiquidRippleScreenState();
}

class _LiquidRippleScreenState extends State<LiquidRippleScreen>
    with SingleTickerProviderStateMixin {
  final List<RippleEffect> _ripples = [];
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..repeat();

    _animController.addListener(() {
      setState(() {
        _ripples.removeWhere((r) => r.isComplete);
      });
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _addRipple(Offset position) {
    const mode = ExperienceMode.liquidRipple;
    
    setState(() {
      _ripples.add(RippleEffect(
        center: position,
        startTime: DateTime.now(),
        color: mode.primaryColor,
        maxRadius: 150 + Random().nextDouble() * 100,
        duration: Duration(milliseconds: 800 + Random().nextInt(400)),
      ));
    });

    widget.service.triggerRippleHaptic();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.service.settings.theme;
    const mode = ExperienceMode.liquidRipple;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: AnimatedGradientBackground(
        theme: theme,
        child: GestureDetector(
          onTapDown: (details) => _addRipple(details.localPosition),
          child: Stack(
            children: [
              // Ripples
              RippleEffectWidget(
                ripples: _ripples,
                defaultColor: mode.primaryColor,
              ),
              
              // Particles
              ParticleSystemWidget(
                particleCount: (30 * widget.service.settings.particleDensity).round(),
                primaryColor: mode.primaryColor.withOpacity(0.5),
                secondaryColor: mode.secondaryColor.withOpacity(0.5),
                speed: widget.service.settings.animationSpeed * 0.5,
                size: MediaQuery.of(context).size,
              ),
              
              // Header
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                        },
                        child: GlassmorphicContainer(
                          blur: 10,
                          opacity: 0.1,
                          borderRadius: BorderRadius.circular(14),
                          padding: const EdgeInsets.all(10),
                          child: Icon(Icons.close_rounded, color: theme.textColor, size: 22),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            mode.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: mode.primaryColor,
                            ),
                          ),
                          Text(
                            widget.service.formattedSessionTime,
                            style: TextStyle(fontSize: 12, color: theme.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              // Instructions
              if (_ripples.isEmpty)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(mode.emoji, style: const TextStyle(fontSize: 64)),
                      const SizedBox(height: 16),
                      Text(
                        'Tap anywhere to create ripples',
                        style: TextStyle(
                          fontSize: 18,
                          color: theme.textColor.withOpacity(0.7),
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
}

/// Aura Sculpt Mode - Shape energy fields
class AuraSculptScreen extends StatefulWidget {
  final RelaxationGameService service;

  const AuraSculptScreen({super.key, required this.service});

  @override
  State<AuraSculptScreen> createState() => _AuraSculptScreenState();
}

class _AuraSculptScreenState extends State<AuraSculptScreen>
    with SingleTickerProviderStateMixin {
  Offset _orbPosition = Offset.zero;
  double _orbSize = 80;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.of(context).size;
      setState(() {
        _orbPosition = Offset(size.width / 2, size.height / 2);
      });
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.service.settings.theme;
    const mode = ExperienceMode.auraSculpt;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: AnimatedGradientBackground(
        theme: theme,
        child: GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              _orbPosition = details.localPosition;
            });
            if (Random().nextDouble() < 0.1) {
              widget.service.triggerTapHaptic();
            }
          },
          onScaleUpdate: (details) {
            setState(() {
              _orbSize = (80 * details.scale).clamp(40, 200);
            });
          },
          child: Stack(
            children: [
              // Particles
              ParticleSystemWidget(
                particleCount: (40 * widget.service.settings.particleDensity).round(),
                primaryColor: mode.primaryColor,
                secondaryColor: mode.secondaryColor,
                speed: widget.service.settings.animationSpeed,
                size: MediaQuery.of(context).size,
              ),
              
              // Energy orb
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final pulse = 1.0 + _pulseController.value * 0.2;
                  return Positioned(
                    left: _orbPosition.dx - _orbSize * pulse / 2,
                    top: _orbPosition.dy - _orbSize * pulse / 2,
                    child: Container(
                      width: _orbSize * pulse,
                      height: _orbSize * pulse,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            mode.primaryColor.withOpacity(0.8),
                            mode.primaryColor.withOpacity(0.4),
                            mode.secondaryColor.withOpacity(0.2),
                            Colors.transparent,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: mode.primaryColor.withOpacity(0.5),
                            blurRadius: 40 * widget.service.settings.glowIntensity,
                            spreadRadius: 15 * widget.service.settings.glowIntensity,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              
              // Header
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                        },
                        child: GlassmorphicContainer(
                          blur: 10,
                          opacity: 0.1,
                          borderRadius: BorderRadius.circular(14),
                          padding: const EdgeInsets.all(10),
                          child: Icon(Icons.close_rounded, color: theme.textColor, size: 22),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            mode.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: mode.primaryColor,
                            ),
                          ),
                          Text(
                            widget.service.formattedSessionTime,
                            style: TextStyle(fontSize: 12, color: theme.textSecondary),
                          ),
                        ],
                      ),
                    ],
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

/// Breathing Ritual Mode
class BreathingRitualScreen extends StatefulWidget {
  final RelaxationGameService service;

  const BreathingRitualScreen({super.key, required this.service});

  @override
  State<BreathingRitualScreen> createState() => _BreathingRitualScreenState();
}

class _BreathingRitualScreenState extends State<BreathingRitualScreen> {
  @override
  void initState() {
    super.initState();
    widget.service.startTherapyLoop(HapticTherapyMode.stressRelease);
  }

  @override
  void dispose() {
    widget.service.stopTherapyLoop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.service.settings.theme;
    const mode = ExperienceMode.breathingRitual;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: AnimatedGradientBackground(
        theme: theme,
        child: Stack(
          children: [
            // Particles
            ParticleSystemWidget(
              particleCount: (20 * widget.service.settings.particleDensity).round(),
              primaryColor: mode.primaryColor.withOpacity(0.3),
              secondaryColor: mode.secondaryColor.withOpacity(0.3),
              speed: widget.service.settings.animationSpeed * 0.3,
              size: MediaQuery.of(context).size,
            ),
            
            // Breathing circle
            Center(
              child: BreathingCircleWidget(
                size: 200,
                color: mode.primaryColor,
                onPhaseChange: () {
                  widget.service.triggerHeartbeatSync();
                },
              ),
            ),
            
            // Header
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
                      child: GlassmorphicContainer(
                        blur: 10,
                        opacity: 0.1,
                        borderRadius: BorderRadius.circular(14),
                        padding: const EdgeInsets.all(10),
                        child: Icon(Icons.close_rounded, color: theme.textColor, size: 22),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          mode.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: mode.primaryColor,
                          ),
                        ),
                        Text(
                          widget.service.formattedSessionTime,
                          style: TextStyle(fontSize: 12, color: theme.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cosmic Drift Mode
class CosmicDriftScreen extends StatefulWidget {
  final RelaxationGameService service;

  const CosmicDriftScreen({super.key, required this.service});

  @override
  State<CosmicDriftScreen> createState() => _CosmicDriftScreenState();
}

class _CosmicDriftScreenState extends State<CosmicDriftScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = widget.service.settings.theme;
    const mode = ExperienceMode.cosmicDrift;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0221),
      body: Stack(
        children: [
          // Multiple particle layers for depth
          ParticleSystemWidget(
            particleCount: (80 * widget.service.settings.particleDensity).round(),
            primaryColor: Colors.white.withOpacity(0.8),
            secondaryColor: mode.primaryColor.withOpacity(0.6),
            speed: widget.service.settings.animationSpeed * 0.3,
            size: MediaQuery.of(context).size,
          ),
          ParticleSystemWidget(
            particleCount: (30 * widget.service.settings.particleDensity).round(),
            primaryColor: mode.secondaryColor,
            secondaryColor: const Color(0xFFEC4899),
            speed: widget.service.settings.animationSpeed * 0.6,
            size: MediaQuery.of(context).size,
          ),
          
          // Header
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    child: GlassmorphicContainer(
                      blur: 10,
                      opacity: 0.1,
                      borderRadius: BorderRadius.circular(14),
                      padding: const EdgeInsets.all(10),
                      child: Icon(Icons.close_rounded, color: theme.textColor, size: 22),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        mode.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: mode.primaryColor,
                        ),
                      ),
                      Text(
                        widget.service.formattedSessionTime,
                        style: TextStyle(fontSize: 12, color: theme.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Center instruction
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(mode.emoji, style: const TextStyle(fontSize: 48)),
                const SizedBox(height: 16),
                Text(
                  'Drift among the stars',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white.withOpacity(0.7),
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ember Meditation Mode
class EmberMeditationScreen extends StatefulWidget {
  final RelaxationGameService service;

  const EmberMeditationScreen({super.key, required this.service});

  @override
  State<EmberMeditationScreen> createState() => _EmberMeditationScreenState();
}

class _EmberMeditationScreenState extends State<EmberMeditationScreen> {
  Offset _touchPosition = Offset.zero;
  bool _isTouching = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.service.settings.theme;
    const mode = ExperienceMode.emberMeditation;

    return Scaffold(
      backgroundColor: const Color(0xFF1A0A00),
      body: GestureDetector(
        onPanStart: (details) {
          setState(() {
            _isTouching = true;
            _touchPosition = details.localPosition;
          });
        },
        onPanUpdate: (details) {
          setState(() => _touchPosition = details.localPosition);
          if (Random().nextDouble() < 0.15) {
            widget.service.triggerEmberHaptic();
          }
        },
        onPanEnd: (_) => setState(() => _isTouching = false),
        child: Stack(
          children: [
            // Ember particles
            ParticleSystemWidget(
              particleCount: (60 * widget.service.settings.particleDensity).round(),
              primaryColor: const Color(0xFFF97316),
              secondaryColor: const Color(0xFFFBBF24),
              speed: widget.service.settings.animationSpeed * 0.5,
              size: MediaQuery.of(context).size,
            ),
            
            // Touch ember effect
            if (_isTouching)
              Positioned(
                left: _touchPosition.dx - 60,
                top: _touchPosition.dy - 60,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFFBBF24).withOpacity(0.8),
                        const Color(0xFFF97316).withOpacity(0.5),
                        const Color(0xFFEF4444).withOpacity(0.2),
                        Colors.transparent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF97316).withOpacity(0.6),
                        blurRadius: 50,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                ),
              ),
            
            // Header
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
                      child: GlassmorphicContainer(
                        blur: 10,
                        opacity: 0.1,
                        borderRadius: BorderRadius.circular(14),
                        padding: const EdgeInsets.all(10),
                        child: Icon(Icons.close_rounded, color: theme.textColor, size: 22),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          mode.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: mode.primaryColor,
                          ),
                        ),
                        Text(
                          widget.service.formattedSessionTime,
                          style: TextStyle(fontSize: 12, color: theme.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            if (!_isTouching)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(mode.emoji, style: const TextStyle(fontSize: 48)),
                    const SizedBox(height: 16),
                    Text(
                      'Touch to ignite embers',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white.withOpacity(0.7),
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
}

/// Chromatic Harmony Mode
class ChromaticHarmonyScreen extends StatefulWidget {
  final RelaxationGameService service;

  const ChromaticHarmonyScreen({super.key, required this.service});

  @override
  State<ChromaticHarmonyScreen> createState() => _ChromaticHarmonyScreenState();
}

class _ChromaticHarmonyScreenState extends State<ChromaticHarmonyScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _colorController;
  
  final List<Color> _colors = [
    const Color(0xFFEF4444),
    const Color(0xFFF97316),
    const Color(0xFFFBBF24),
    const Color(0xFF10B981),
    const Color(0xFF06B6D4),
    const Color(0xFF6366F1),
    const Color(0xFF8B5CF6),
    const Color(0xFFEC4899),
  ];

  @override
  void initState() {
    super.initState();
    _colorController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _colorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.service.settings.theme;
    const mode = ExperienceMode.chromaticHarmony;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _colorController,
        builder: (context, child) {
          final colorIndex = (_colorController.value * _colors.length).floor() % _colors.length;
          final nextIndex = (colorIndex + 1) % _colors.length;
          final t = (_colorController.value * _colors.length) - colorIndex;
          
          final currentColor = Color.lerp(_colors[colorIndex], _colors[nextIndex], t)!;

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  currentColor.withOpacity(0.3),
                  currentColor.withOpacity(0.1),
                  Colors.black,
                ],
              ),
            ),
            child: Stack(
              children: [
                // Color waves
                Center(
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          currentColor.withOpacity(0.6),
                          currentColor.withOpacity(0.3),
                          currentColor.withOpacity(0.1),
                          Colors.transparent,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: currentColor.withOpacity(0.4),
                          blurRadius: 60,
                          spreadRadius: 30,
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Header
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context);
                          },
                          child: GlassmorphicContainer(
                            blur: 10,
                            opacity: 0.1,
                            borderRadius: BorderRadius.circular(14),
                            padding: const EdgeInsets.all(10),
                            child: Icon(Icons.close_rounded, color: theme.textColor, size: 22),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              mode.name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: currentColor,
                              ),
                            ),
                            Text(
                              widget.service.formattedSessionTime,
                              style: TextStyle(fontSize: 12, color: theme.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(mode.emoji, style: const TextStyle(fontSize: 48)),
                      const SizedBox(height: 16),
                      Text(
                        'Feel the color frequencies',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Hypnotic Loop Mode
class HypnoticLoopScreen extends StatefulWidget {
  final RelaxationGameService service;

  const HypnoticLoopScreen({super.key, required this.service});

  @override
  State<HypnoticLoopScreen> createState() => _HypnoticLoopScreenState();
}

class _HypnoticLoopScreenState extends State<HypnoticLoopScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = widget.service.settings.theme;
    const mode = ExperienceMode.hypnoticLoop;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0221),
      body: Stack(
        children: [
          // Hypnotic spiral
          HypnoticSpiralWidget(
            primaryColor: mode.primaryColor,
            secondaryColor: mode.secondaryColor,
            speed: widget.service.settings.animationSpeed + 0.5,
          ),
          
          // Header
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    child: GlassmorphicContainer(
                      blur: 10,
                      opacity: 0.1,
                      borderRadius: BorderRadius.circular(14),
                      padding: const EdgeInsets.all(10),
                      child: Icon(Icons.close_rounded, color: theme.textColor, size: 22),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        mode.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: mode.primaryColor,
                        ),
                      ),
                      Text(
                        widget.service.formattedSessionTime,
                        style: TextStyle(fontSize: 12, color: theme.textSecondary),
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
}

/// Play Mode Screen for interactive games
class PlayModeScreen extends StatefulWidget {
  final PlayMode mode;

  const PlayModeScreen({super.key, required this.mode});

  @override
  State<PlayModeScreen> createState() => _PlayModeScreenState();
}

class _PlayModeScreenState extends State<PlayModeScreen> {
  final RelaxationGameService _service = RelaxationGameService();

  @override
  void initState() {
    super.initState();
    _service.startSession();
  }

  @override
  void dispose() {
    _service.endSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _service,
      builder: (context, _) {
        return _buildPlayScreen();
      },
    );
  }

  Widget _buildPlayScreen() {
    switch (widget.mode) {
      case PlayMode.liquidTouch:
        return LiquidTouchPlayScreen(service: _service);
      case PlayMode.energyOrb:
        return EnergyOrbPlayScreen(service: _service);
      case PlayMode.zenGarden:
        return ZenGardenPlayScreen(service: _service);
      case PlayMode.bubblePop:
        return BubblePopPlayScreen(service: _service);
      case PlayMode.sandFlow:
        return SandFlowPlayScreen(service: _service);
    }
  }
}

/// Liquid Touch Play Screen
class LiquidTouchPlayScreen extends StatefulWidget {
  final RelaxationGameService service;

  const LiquidTouchPlayScreen({super.key, required this.service});

  @override
  State<LiquidTouchPlayScreen> createState() => _LiquidTouchPlayScreenState();
}

class _LiquidTouchPlayScreenState extends State<LiquidTouchPlayScreen> {
  final List<RippleEffect> _ripples = [];

  @override
  Widget build(BuildContext context) {
    final theme = widget.service.settings.theme;
    const mode = PlayMode.liquidTouch;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: GestureDetector(
        onTapDown: (details) {
          setState(() {
            _ripples.add(RippleEffect(
              center: details.localPosition,
              startTime: DateTime.now(),
              color: mode.color,
            ));
          });
          widget.service.triggerWaterFlowHaptic();
        },
        child: Stack(
          children: [
            AnimatedGradientBackground(theme: theme, child: null),
            RippleEffectWidget(ripples: _ripples, defaultColor: mode.color),
            _buildHeader(context, mode.name, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String title, RelaxationTheme theme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
              child: GlassmorphicContainer(
                blur: 10,
                opacity: 0.1,
                borderRadius: BorderRadius.circular(14),
                padding: const EdgeInsets.all(10),
                child: Icon(Icons.close_rounded, color: theme.textColor, size: 22),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Energy Orb Play Screen
class EnergyOrbPlayScreen extends StatefulWidget {
  final RelaxationGameService service;

  const EnergyOrbPlayScreen({super.key, required this.service});

  @override
  State<EnergyOrbPlayScreen> createState() => _EnergyOrbPlayScreenState();
}

class _EnergyOrbPlayScreenState extends State<EnergyOrbPlayScreen> {
  Offset _orbPosition = const Offset(200, 400);

  @override
  Widget build(BuildContext context) {
    final theme = widget.service.settings.theme;
    final element = widget.service.currentElement;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: GestureDetector(
        onPanUpdate: (details) {
          setState(() => _orbPosition = details.localPosition);
          if (Random().nextDouble() < 0.1) {
            widget.service.triggerElementHaptic(element);
          }
        },
        child: Stack(
          children: [
            AnimatedGradientBackground(theme: theme, child: null),
            EnergyOrbWidget(
              position: _orbPosition,
              element: element,
              size: 100,
              pulseIntensity: widget.service.settings.glowIntensity,
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
                      child: GlassmorphicContainer(
                        blur: 10,
                        opacity: 0.1,
                        borderRadius: BorderRadius.circular(14),
                        padding: const EdgeInsets.all(10),
                        child: Icon(Icons.close_rounded, color: theme.textColor, size: 22),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Energy Orb - ${element.name}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: element.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Zen Garden Play Screen
class ZenGardenPlayScreen extends StatefulWidget {
  final RelaxationGameService service;

  const ZenGardenPlayScreen({super.key, required this.service});

  @override
  State<ZenGardenPlayScreen> createState() => _ZenGardenPlayScreenState();
}

class _ZenGardenPlayScreenState extends State<ZenGardenPlayScreen> {
  final List<List<Offset>> _rakeLines = [];
  List<Offset> _currentLine = [];

  @override
  Widget build(BuildContext context) {
    final theme = widget.service.settings.theme;

    return Scaffold(
      backgroundColor: const Color(0xFFD4C4A8),
      body: GestureDetector(
        onPanStart: (details) {
          _currentLine = [details.localPosition];
        },
        onPanUpdate: (details) {
          setState(() {
            _currentLine.add(details.localPosition);
          });
          widget.service.triggerSandTextureHaptic();
        },
        onPanEnd: (_) {
          setState(() {
            _rakeLines.add(List.from(_currentLine));
            _currentLine = [];
          });
        },
        child: Stack(
          children: [
            ZenGardenPatternWidget(
              rakeLines: [..._rakeLines, if (_currentLine.isNotEmpty) _currentLine],
              sandColor: const Color(0xFFD4C4A8),
              lineColor: const Color(0xFFB8A88A),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.close_rounded, color: theme.backgroundColor, size: 22),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Zen Garden',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.backgroundColor,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        setState(() => _rakeLines.clear());
                        HapticFeedback.mediumImpact();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.refresh_rounded, color: theme.backgroundColor, size: 22),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bubble Pop Play Screen
class BubblePopPlayScreen extends StatefulWidget {
  final RelaxationGameService service;

  const BubblePopPlayScreen({super.key, required this.service});

  @override
  State<BubblePopPlayScreen> createState() => _BubblePopPlayScreenState();
}

class _BubblePopPlayScreenState extends State<BubblePopPlayScreen> {
  List<_BubbleData> _bubbles = [];
  int _poppedCount = 0;

  @override
  void initState() {
    super.initState();
    _generateBubbles();
  }

  void _generateBubbles() {
    final random = Random();
    final size = MediaQuery.of(context).size;
    
    _bubbles = List.generate(20, (index) {
      return _BubbleData(
        id: index,
        position: Offset(
          50 + random.nextDouble() * (size.width - 100),
          100 + random.nextDouble() * (size.height - 200),
        ),
        size: 40 + random.nextDouble() * 40,
        color: [
          const Color(0xFFEC4899),
          const Color(0xFF8B5CF6),
          const Color(0xFF06B6D4),
          const Color(0xFF10B981),
        ][random.nextInt(4)],
        isPopped: false,
      );
    });
  }

  void _popBubble(int id) {
    setState(() {
      final index = _bubbles.indexWhere((b) => b.id == id);
      if (index != -1 && !_bubbles[index].isPopped) {
        _bubbles[index] = _bubbles[index].copyWith(isPopped: true);
        _poppedCount++;
      }
    });
    widget.service.triggerBubblePopHaptic();
    
    // Regenerate if all popped
    if (_bubbles.every((b) => b.isPopped)) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _generateBubbles();
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.service.settings.theme;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: Stack(
        children: [
          AnimatedGradientBackground(theme: theme, child: null),
          ..._bubbles.where((b) => !b.isPopped).map((bubble) {
            return BubbleWidget(
              position: bubble.position,
              size: bubble.size,
              color: bubble.color,
              onPop: () => _popBubble(bubble.id),
            );
          }),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    child: GlassmorphicContainer(
                      blur: 10,
                      opacity: 0.1,
                      borderRadius: BorderRadius.circular(14),
                      padding: const EdgeInsets.all(10),
                      child: Icon(Icons.close_rounded, color: theme.textColor, size: 22),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Bubble Pop',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.textColor,
                        ),
                      ),
                      Text(
                        'Popped: $_poppedCount',
                        style: TextStyle(fontSize: 12, color: theme.textSecondary),
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
}

class _BubbleData {
  final int id;
  final Offset position;
  final double size;
  final Color color;
  final bool isPopped;

  _BubbleData({
    required this.id,
    required this.position,
    required this.size,
    required this.color,
    required this.isPopped,
  });

  _BubbleData copyWith({bool? isPopped}) {
    return _BubbleData(
      id: id,
      position: position,
      size: size,
      color: color,
      isPopped: isPopped ?? this.isPopped,
    );
  }
}

/// Sand Flow Play Screen
class SandFlowPlayScreen extends StatefulWidget {
  final RelaxationGameService service;

  const SandFlowPlayScreen({super.key, required this.service});

  @override
  State<SandFlowPlayScreen> createState() => _SandFlowPlayScreenState();
}

class _SandFlowPlayScreenState extends State<SandFlowPlayScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = widget.service.settings.theme;

    return Scaffold(
      backgroundColor: const Color(0xFF2D1B0E),
      body: Stack(
        children: [
          // Sand particle effect
          ParticleSystemWidget(
            particleCount: 100,
            primaryColor: const Color(0xFFD4A574),
            secondaryColor: const Color(0xFFC4956A),
            speed: 2.0,
            size: MediaQuery.of(context).size,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    child: GlassmorphicContainer(
                      blur: 10,
                      opacity: 0.1,
                      borderRadius: BorderRadius.circular(14),
                      padding: const EdgeInsets.all(10),
                      child: Icon(Icons.close_rounded, color: theme.textColor, size: 22),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Sand Flow',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('⏳', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                Text(
                  'Watch the sand flow',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
