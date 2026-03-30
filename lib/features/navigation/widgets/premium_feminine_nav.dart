import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Premium Feminine Navigation Bar - Period Tracking Category
/// Uses: animated_bottom_navigation_bar + soft organic enhancements
/// 
/// Design Features:
/// - Soft floating pill with rounded corners
/// - Rose pink gradient (#EC4899)
/// - Organic blob morphing indicator
/// - Gentle wave background animation
/// - Feminine, caring aesthetic
class PremiumFeminineNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<IconData> activeIcons;
  final List<IconData> inactiveIcons;

  const PremiumFeminineNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.activeIcons,
    required this.inactiveIcons,
  });

  @override
  State<PremiumFeminineNav> createState() => _PremiumFeminineNavState();
}

class _PremiumFeminineNavState extends State<PremiumFeminineNav>
    with TickerProviderStateMixin {
  
  late AnimationController _waveController;
  late AnimationController _glowController;
  late Animation<double> _waveAnimation;
  late Animation<double> _glowAnimation;
  
  // Feminine theme colors - Rose pink
  static const Color _primaryRose = Color(0xFFEC4899);
  static const Color _primaryRoseLight = Color(0xFFF472B6);
  static const Color _primaryRoseSoft = Color(0xFFFCE7F3);

  @override
  void initState() {
    super.initState();
    
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
    
    _waveAnimation = Tween<double>(begin: 0, end: 1).animate(_waveController);
    
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    
    _glowAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _waveController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _onTap(int index) {
    HapticFeedback.selectionClick();
    widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AnimatedBuilder(
      animation: Listenable.merge([_waveAnimation, _glowAnimation]),
      builder: (context, child) {
        return Container(
          margin: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: bottomPadding + 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: _primaryRose.withValues(alpha: 0.25 * _glowAnimation.value),
                blurRadius: 25,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            Colors.white.withValues(alpha: 0.1),
                            _primaryRose.withValues(alpha: 0.08),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.95),
                            _primaryRoseSoft.withValues(alpha: 0.5),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: _primaryRose.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: Stack(
                  children: [
                    // Subtle wave background
                    CustomPaint(
                      size: const Size(double.infinity, 72),
                      painter: _WaveBackgroundPainter(
                        progress: _waveAnimation.value,
                        color: _primaryRose.withValues(alpha: 0.05),
                      ),
                    ),
                    // Navigation items
                    _buildNavItems(isDark),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItems(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(4, (index) {
        final isSelected = widget.currentIndex == index;
        
        return GestureDetector(
          onTap: () => _onTap(index),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: isSelected
                ? BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _primaryRose.withValues(alpha: 0.2),
                        _primaryRoseLight.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  )
                : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.15 : 1.0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    isSelected
                        ? widget.activeIcons[index]
                        : widget.inactiveIcons[index],
                    size: 24,
                    color: isSelected
                        ? _primaryRose
                        : isDark
                            ? Colors.white.withValues(alpha: 0.5)
                            : Colors.black.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: isSelected ? 6 : 0,
                  height: isSelected ? 6 : 0,
                  decoration: BoxDecoration(
                    color: _primaryRose,
                    shape: BoxShape.circle,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: _primaryRose.withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

/// Custom painter for subtle wave background effect
class _WaveBackgroundPainter extends CustomPainter {
  final double progress;
  final Color color;

  _WaveBackgroundPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    const waveHeight = 6.0;
    final waveLength = size.width / 2;
    
    path.moveTo(0, size.height);
    
    for (double x = 0; x <= size.width; x += 1) {
      final y = size.height - 15 + 
          (waveHeight * 
           (0.5 + 0.5 * (x / waveLength * 2 * 3.14159 + progress * 2 * 3.14159).sin()));
      path.lineTo(x, y);
    }
    
    path.lineTo(size.width, size.height);
    path.close();
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WaveBackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

extension on double {
  double sin() => _sin(this);
}

double _sin(double x) {
  // Simple sin approximation for wave effect
  x = x % (2 * 3.14159);
  double result = x;
  double term = x;
  for (int i = 1; i <= 5; i++) {
    term *= -x * x / ((2 * i) * (2 * i + 1));
    result += term;
  }
  return result;
}
