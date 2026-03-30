import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';

/// Premium Fitness Navigation Bar - Fitness & Activity Category
/// Uses: curved_navigation_bar + neon glow effects
/// 
/// Design Features:
/// - Dramatic curved notch with center highlight
/// - Neon lime glow (#CDFF00) on dark background
/// - Energetic bounce animation (elastic curve)
/// - Bold, athletic aesthetic
class PremiumFitnessNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<IconData> activeIcons;
  final List<IconData> inactiveIcons;

  const PremiumFitnessNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.activeIcons,
    required this.inactiveIcons,
  });

  @override
  State<PremiumFitnessNav> createState() => _PremiumFitnessNavState();
}

class _PremiumFitnessNavState extends State<PremiumFitnessNav>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  
  // Fitness theme colors - Neon lime
  static const Color _primaryLime = Color(0xFFCDFF00);
  static const Color _darkBg = Color(0xFF0D0D0D);
  static const Color _darkSurface = Color(0xFF1A1A1A);

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  void _onTap(int index) {
    HapticFeedback.mediumImpact();
    widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: _primaryLime.withValues(alpha: 0.2 * _glowAnimation.value),
                blurRadius: 30,
                spreadRadius: 5,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CurvedNavigationBar(
                index: widget.currentIndex,
                height: 70,
                backgroundColor: Colors.transparent,
                color: _darkSurface,
                buttonBackgroundColor: _primaryLime,
                animationCurve: Curves.easeOutCubic,
                animationDuration: const Duration(milliseconds: 400),
                items: [
                  _buildNavIcon(0),
                  _buildNavIcon(1),
                  _buildNavIcon(2),
                  _buildNavIcon(3),
                ],
                onTap: _onTap,
              ),
              // Bottom safe area padding
              Container(
                height: bottomPadding,
                color: _darkSurface,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavIcon(int index) {
    final isSelected = widget.currentIndex == index;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(8),
      child: Icon(
        isSelected ? widget.activeIcons[index] : widget.inactiveIcons[index],
        size: 26,
        color: isSelected ? _darkBg : Colors.white.withValues(alpha: 0.6),
      ),
    );
  }
}
