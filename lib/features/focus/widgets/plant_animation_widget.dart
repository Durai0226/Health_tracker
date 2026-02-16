import 'dart:math';
import 'package:flutter/material.dart';
import '../models/focus_plant.dart';

class PlantAnimationWidget extends StatefulWidget {
  final PlantType plantType;
  final double progress;
  final bool isAlive;
  final bool isAnimating;
  final double size;

  const PlantAnimationWidget({
    super.key,
    required this.plantType,
    required this.progress,
    this.isAlive = true,
    this.isAnimating = true,
    this.size = 200,
  });

  @override
  State<PlantAnimationWidget> createState() => _PlantAnimationWidgetState();
}

class _PlantAnimationWidgetState extends State<PlantAnimationWidget>
    with TickerProviderStateMixin {
  late AnimationController _swayController;
  late AnimationController _growController;
  late AnimationController _sparkleController;
  late Animation<double> _swayAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    _swayController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    _growController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _sparkleController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _swayAnimation = Tween<double>(begin: -0.03, end: 0.03).animate(
      CurvedAnimation(parent: _swayController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _growController, curve: Curves.elasticOut),
    );

    if (widget.isAnimating) {
      _swayController.repeat(reverse: true);
      _sparkleController.repeat();
    }
    _growController.forward();
  }

  @override
  void didUpdateWidget(PlantAnimationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.progress != oldWidget.progress) {
      _growController.forward(from: 0);
    }
    if (widget.isAnimating != oldWidget.isAnimating) {
      if (widget.isAnimating) {
        _swayController.repeat(reverse: true);
        _sparkleController.repeat();
      } else {
        _swayController.stop();
        _sparkleController.stop();
      }
    }
  }

  @override
  void dispose() {
    _swayController.dispose();
    _growController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_swayController, _growController, _sparkleController]),
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow effect
              if (widget.isAlive && widget.progress > 0.5)
                _buildGlow(),
              
              // Plant container
              Transform.rotate(
                angle: widget.isAnimating ? _swayAnimation.value : 0,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: _buildPlant(),
                ),
              ),
              
              // Sparkles for completed plant
              if (widget.isAlive && widget.progress >= 1.0)
                ..._buildSparkles(),
              
              // Dead overlay
              if (!widget.isAlive)
                _buildDeadOverlay(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGlow() {
    return Container(
      width: widget.size * 0.8,
      height: widget.size * 0.8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: widget.plantType.primaryColor.withOpacity(0.3 * widget.progress),
            blurRadius: 40,
            spreadRadius: 10,
          ),
        ],
      ),
    );
  }

  Widget _buildPlant() {
    final growthStage = (widget.progress * 4).floor().clamp(0, 4);
    
    return Container(
      width: widget.size * 0.7,
      height: widget.size * 0.7,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            widget.plantType.secondaryColor.withOpacity(0.3),
            widget.plantType.primaryColor.withOpacity(0.1),
          ],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Plant emoji with size based on growth
            Text(
              _getPlantEmoji(growthStage),
              style: TextStyle(
                fontSize: widget.size * (0.2 + widget.progress * 0.2),
              ),
            ),
            const SizedBox(height: 8),
            // Growth stage text
            Text(
              _getGrowthText(growthStage),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: widget.plantType.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPlantEmoji(int stage) {
    if (!widget.isAlive) return '🥀';
    
    switch (stage) {
      case 0:
        return '🌱';
      case 1:
        return '🌿';
      case 2:
        return '🪴';
      case 3:
        return widget.plantType.emoji;
      case 4:
        return widget.plantType.emoji;
      default:
        return '🌱';
    }
  }

  String _getGrowthText(int stage) {
    if (!widget.isAlive) return 'Withered';
    
    switch (stage) {
      case 0:
        return 'Seed';
      case 1:
        return 'Sprouting';
      case 2:
        return 'Growing';
      case 3:
        return 'Blooming';
      case 4:
        return 'Flourishing';
      default:
        return 'Starting';
    }
  }

  List<Widget> _buildSparkles() {
    return List.generate(6, (index) {
      final angle = (index / 6) * 2 * pi + _sparkleController.value * 2 * pi;
      final radius = widget.size * 0.35;
      final x = cos(angle) * radius;
      final y = sin(angle) * radius;
      
      return Positioned(
        left: widget.size / 2 + x - 8,
        top: widget.size / 2 + y - 8,
        child: Opacity(
          opacity: (sin(_sparkleController.value * 2 * pi + index) + 1) / 2,
          child: const Text('✨', style: TextStyle(fontSize: 16)),
        ),
      );
    });
  }

  Widget _buildDeadOverlay() {
    return Container(
      width: widget.size * 0.7,
      height: widget.size * 0.7,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.3),
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Text('💔', style: TextStyle(fontSize: 24)),
      ),
    );
  }
}

class PlantGridItem extends StatelessWidget {
  final PlantType type;
  final bool isUnlocked;
  final bool isSelected;
  final VoidCallback? onTap;
  final int? unlockMinutes;

  const PlantGridItem({
    super.key,
    required this.type,
    this.isUnlocked = false,
    this.isSelected = false,
    this.onTap,
    this.unlockMinutes,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isUnlocked ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? type.primaryColor.withOpacity(0.2)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? type.primaryColor
                : Colors.grey.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: type.primaryColor.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isUnlocked ? type.emoji : '🔒',
              style: TextStyle(
                fontSize: 32,
                color: isUnlocked ? null : Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              type.name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isUnlocked ? type.primaryColor : Colors.grey,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (!isUnlocked && unlockMinutes != null)
              Text(
                '${unlockMinutes}min',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey.shade500,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
