import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/gamification_service.dart';
import '../theme/habit_theme.dart';

/// City View Screen - Gamification
/// Shows the user's city that grows with habit completion
class CityViewScreen extends StatefulWidget {
  const CityViewScreen({super.key});

  @override
  State<CityViewScreen> createState() => _CityViewScreenState();
}

class _CityViewScreenState extends State<CityViewScreen>
    with SingleTickerProviderStateMixin {
  final GamificationService _gamificationService = GamificationService();
  
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    
    _floatAnimation = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _floatController.dispose();
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
              Color(0xFF87CEEB), // Sky blue
              Color(0xFFE0F7FA), // Light cyan
            ],
          ),
        ),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: _gamificationService,
            builder: (context, _) {
              return Stack(
                children: [
                  // Background elements
                  _buildBackground(),
                  // City grid
                  _buildCityGrid(),
                  // Top bar with stats
                  _buildTopBar(),
                  // Bottom navigation
                  _buildBottomNav(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return Stack(
      children: [
        // Sun
        Positioned(
          top: 40,
          right: 40,
          child: AnimatedBuilder(
            animation: _floatAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _floatAnimation.value),
                child: child,
              );
            },
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Colors.yellow.shade200,
                    Colors.orange.shade200,
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
          ),
        ),
        // Clouds
        ..._buildClouds(),
      ],
    );
  }

  List<Widget> _buildClouds() {
    return [
      Positioned(
        top: 80,
        left: 30,
        child: _buildCloud(60),
      ),
      Positioned(
        top: 120,
        right: 80,
        child: _buildCloud(40),
      ),
      Positioned(
        top: 60,
        left: 150,
        child: _buildCloud(50),
      ),
    ];
  }

  Widget _buildCloud(double width) {
    return Container(
      width: width,
      height: width * 0.5,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(width),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Back button
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: HabitTheme.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                  boxShadow: HabitTheme.subtleShadow,
                ),
                child: const Icon(Icons.arrow_back, size: 20),
              ),
            ),
            const Spacer(),
            // Points
            _buildStatBadge(
              Icons.star,
              '${_gamificationService.totalPoints}',
              Colors.amber,
            ),
            const SizedBox(width: 12),
            // Coins
            _buildStatBadge(
              Icons.monetization_on,
              '${_gamificationService.coins}',
              Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: HabitTheme.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(HabitTheme.radiusFull),
        boxShadow: HabitTheme.subtleShadow,
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 4),
          Text(
            value,
            style: HabitTheme.b2.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildCityGrid() {
    final buildings = _gamificationService.unlockedBuildings;
    
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 100, bottom: 100),
        child: Stack(
          children: [
            // Ground/grid
            _buildGround(),
            // Buildings
            ...buildings.asMap().entries.map((entry) {
              final index = entry.key;
              final building = entry.value;
              return Positioned(
                left: (index % 3) * 100.0 + 20,
                top: (index ~/ 3) * 80.0 + 50,
                child: _buildBuilding(building.name, building.assetPath),
              );
            }),
            // Next building placeholder
            if (_gamificationService.nextBuildingToUnlock != null)
              Positioned(
                left: (buildings.length % 3) * 100.0 + 20,
                top: (buildings.length ~/ 3) * 80.0 + 50,
                child: _buildLockedBuilding(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGround() {
    return Container(
      width: 350,
      height: 300,
      decoration: BoxDecoration(
        color: Colors.green.shade200.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: CustomPaint(
        painter: _GridPainter(),
      ),
    );
  }

  Widget _buildBuilding(String name, String assetPath) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                HabitTheme.primary.withOpacity(0.8),
                HabitTheme.primaryDark,
              ],
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: HabitTheme.primary.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(2, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.home, color: HabitTheme.white, size: 24),
              Text(
                name.split(' ').first,
                style: HabitTheme.caption.copyWith(
                  color: HabitTheme.white,
                  fontSize: 8,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLockedBuilding() {
    final nextBuilding = _gamificationService.nextBuildingToUnlock;
    
    return GestureDetector(
      onTap: () => _showBuildingInfo(nextBuilding!),
      child: Container(
        width: 80,
        height: 60,
        decoration: BoxDecoration(
          color: HabitTheme.grayLight.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: HabitTheme.gray.withOpacity(0.3),
            style: BorderStyle.solid,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, color: HabitTheme.gray, size: 20),
            Text(
              '${nextBuilding?.pointsRequired ?? 0} pts',
              style: HabitTheme.caption.copyWith(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavButton(
              Icons.location_city,
              'City',
              true,
              () {},
            ),
            _buildNavButton(
              Icons.home_outlined,
              'Home',
              false,
              () {
                // Navigate to home decoration
              },
            ),
            _buildNavButton(
              Icons.collections_outlined,
              'Collection',
              false,
              () => Navigator.pushNamed(context, '/habit/collections'),
            ),
            _buildNavButton(
              Icons.shopping_bag_outlined,
              'Shop',
              false,
              () => Navigator.pushNamed(context, '/habit/shop'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton(
    IconData icon,
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? HabitTheme.primary
              : HabitTheme.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(HabitTheme.radiusL),
          boxShadow: HabitTheme.subtleShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? HabitTheme.white : HabitTheme.gray,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: HabitTheme.caption.copyWith(
                color: isSelected ? HabitTheme.white : HabitTheme.gray,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBuildingInfo(dynamic building) {
    showModalBottomSheet(
      context: context,
      backgroundColor: HabitTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: HabitTheme.grayLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Icon(Icons.lock_outline, size: 48, color: HabitTheme.primary),
            const SizedBox(height: 16),
            Text(
              building.name,
              style: HabitTheme.h2,
            ),
            const SizedBox(height: 8),
            Text(
              building.description,
              style: HabitTheme.b2.copyWith(color: HabitTheme.gray),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 20),
                const SizedBox(width: 4),
                Text(
                  '${building.pointsRequired} points needed',
                  style: HabitTheme.b1.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _gamificationService.totalPoints / building.pointsRequired,
              backgroundColor: HabitTheme.grayLight,
              valueColor: const AlwaysStoppedAnimation(HabitTheme.primary),
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(
              '${_gamificationService.totalPoints} / ${building.pointsRequired}',
              style: HabitTheme.b3,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw isometric grid lines
    for (int i = 0; i <= 6; i++) {
      final y = i * size.height / 6;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }

    for (int i = 0; i <= 6; i++) {
      final x = i * size.width / 6;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
