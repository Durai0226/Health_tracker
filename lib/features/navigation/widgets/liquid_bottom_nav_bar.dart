import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import '../../../core/constants/app_colors.dart';

class LiquidBottomNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<IconData> icons;
  final List<IconData> inactiveIcons;

  const LiquidBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.icons,
    required this.inactiveIcons,
  }) : assert(icons.length == 4 && inactiveIcons.length == 4);

  @override
  State<LiquidBottomNavBar> createState() => _LiquidBottomNavBarState();
}

class _LiquidBottomNavBarState extends State<LiquidBottomNavBar>
    with TickerProviderStateMixin {
  late AnimationController _positionController;
  late AnimationController _morphController;
  late AnimationController _circleController;

  double _currentX = 0;
  double _startX = 0;
  double _endX = 0;

  static const double barHeight = 72;
  static const double baseDepth = 28;
  static const double baseWidth = 68;

  @override
  void initState() {
    super.initState();

    _positionController = AnimationController.unbounded(vsync: this);
    _morphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _circleController = AnimationController.unbounded(vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setInitial(widget.currentIndex);
    });
  }

  void _setInitial(int index) {
    final width = MediaQuery.of(context).size.width - 32;
    final itemWidth = width / 4;
    final center = itemWidth * index + itemWidth / 2;

    _currentX = center;
    _startX = center;
    _endX = center;
    _positionController.value = center;
    _circleController.value = 1.0;

    setState(() {});
  }

  void _animateTo(int index) {
    final width = MediaQuery.of(context).size.width - 32;
    final itemWidth = width / 4;
    final newCenter = itemWidth * index + itemWidth / 2;

    _startX = _currentX;
    _endX = newCenter;

    // Spring for position - smooth liquid movement
    const spring = SpringDescription(
      mass: 1,
      stiffness: 400,
      damping: 28,
    );

    final simulation = SpringSimulation(spring, _startX, _endX, 0);
    _positionController.animateWith(simulation);

    // Morph burst animation
    _morphController
      ..reset()
      ..forward();

    // Circle spring with slight delay for staggered effect
    Future.delayed(const Duration(milliseconds: 80), () {
      if (!mounted) return;
      const circleSpring = SpringDescription(
        mass: 1,
        stiffness: 500,
        damping: 18,
      );

      final circleSim = SpringSimulation(circleSpring, 0, 1, -2.5);
      _circleController.animateWith(circleSim);
    });
  }

  @override
  void didUpdateWidget(covariant LiquidBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _animateTo(widget.currentIndex);
    }
  }

  @override
  void dispose() {
    _positionController.dispose();
    _morphController.dispose();
    _circleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width - 32;
    final isDark = AppColors.isDark(context);
    const primaryColor = AppColors.primary;
    final barColor = isDark 
        ? const Color(0xFF2D2D2D)
        : const Color(0xFF4A4A4A);
    final shadowColor = isDark 
        ? Colors.black.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.15);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      height: 90,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Liquid bar with animated notch
          AnimatedBuilder(
            animation: Listenable.merge([_positionController, _morphController]),
            builder: (context, child) {
              _currentX = _positionController.value;

              final morphT = _morphController.value;

              // Width expansion early burst - creates the "stretching" effect
              final widthExpansion = sin(min(morphT * 1.5, 1) * pi) * 0.22;
              final animatedWidth = baseWidth * (1 + widthExpansion);

              // Depth pulse - makes the dip deeper during transition
              final depthMultiplier = 1 + (0.4 * sin(morphT * pi));

              // Directional lean - tilts the dip in direction of movement
              final direction = (_endX - _startX).sign;
              final lean = sin(min(morphT * 1.3, 1) * pi) * 22 * direction;

              return RepaintBoundary(
                child: CustomPaint(
                  painter: _LiquidPainter(
                    centerX: _currentX,
                    depth: baseDepth * depthMultiplier,
                    width: animatedWidth,
                    lean: lean,
                    barColor: barColor,
                    shadowColor: shadowColor,
                  ),
                  child: SizedBox(
                    width: width,
                    height: barHeight,
                  ),
                ),
              );
            },
          ),

          // Floating Circle with icon
          AnimatedBuilder(
            animation: Listenable.merge([_positionController, _circleController]),
            builder: (context, child) {
              final t = _circleController.value.clamp(0.0, 1.3);

              // Lift amount - how high the circle floats
              final lift = -28 * t;
              // Scale with overshoot
              final scale = 0.85 + (0.18 * t);
              // Glow intensity based on animation
              final glowIntensity = 0.3 + (0.15 * t);

              return Positioned(
                left: _currentX - 30,
                top: 4 + lift,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          primaryColor.withValues(alpha: 0.9),
                          primaryColor,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: glowIntensity),
                          blurRadius: 24 * t,
                          spreadRadius: 2,
                          offset: Offset(0, 8 * t),
                        ),
                        BoxShadow(
                          color: primaryColor.withValues(alpha: glowIntensity * 0.5),
                          blurRadius: 40 * t,
                          spreadRadius: 0,
                          offset: Offset(0, 12 * t),
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.icons[widget.currentIndex],
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              );
            },
          ),

          // Tap targets with inactive icons
          Positioned.fill(
            top: 12,
            child: Row(
              children: List.generate(4, (index) {
                final isSelected = widget.currentIndex == index;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => widget.onTap(index),
                    child: Container(
                      height: barHeight - 12,
                      alignment: Alignment.center,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: isSelected ? 0.0 : 1.0,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.3)
                                  : Colors.white.withValues(alpha: 0.6),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            widget.inactiveIcons[index],
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.6)
                                : Colors.white.withValues(alpha: 0.85),
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiquidPainter extends CustomPainter {
  final double centerX;
  final double depth;
  final double width;
  final double lean;
  final Color barColor;
  final Color shadowColor;

  _LiquidPainter({
    required this.centerX,
    required this.depth,
    required this.width,
    required this.lean,
    required this.barColor,
    required this.shadowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;

    final path = Path();

    final halfWidth = width / 2;
    const cornerRadius = 30.0;

    final left = centerX - halfWidth;
    final right = centerX + halfWidth;

    // Start from top-left corner
    path.moveTo(cornerRadius, 0);

    // Top edge to left side of dip
    path.lineTo(left - 24, 0);

    // Left curve of the dip - smooth bezier
    path.cubicTo(
      left - 12 + lean * 0.35,
      0,
      centerX - width * 0.38 + lean,
      depth * 0.55,
      centerX + lean * 0.5,
      depth,
    );

    // Right curve of the dip - smooth bezier
    path.cubicTo(
      centerX + width * 0.38 + lean,
      depth * 0.55,
      right + 12 + lean * 0.35,
      0,
      right + 24,
      0,
    );

    // Top edge to top-right corner
    path.lineTo(size.width - cornerRadius, 0);

    // Top-right corner
    path.quadraticBezierTo(size.width, 0, size.width, cornerRadius);

    // Right edge
    path.lineTo(size.width, size.height - cornerRadius);

    // Bottom-right corner
    path.quadraticBezierTo(
        size.width, size.height, size.width - cornerRadius, size.height);

    // Bottom edge
    path.lineTo(cornerRadius, size.height);

    // Bottom-left corner
    path.quadraticBezierTo(0, size.height, 0, size.height - cornerRadius);

    // Left edge
    path.lineTo(0, cornerRadius);

    // Top-left corner
    path.quadraticBezierTo(0, 0, cornerRadius, 0);

    path.close();

    // Draw shadow
    canvas.drawShadow(path, shadowColor, 20, false);
    
    // Draw the bar
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LiquidPainter oldDelegate) {
    return centerX != oldDelegate.centerX ||
        depth != oldDelegate.depth ||
        width != oldDelegate.width ||
        lean != oldDelegate.lean ||
        barColor != oldDelegate.barColor;
  }
}
