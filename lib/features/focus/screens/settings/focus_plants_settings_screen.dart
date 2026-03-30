import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Focus Plants & Garden Settings Screen
class FocusPlantsSettingsScreen extends StatefulWidget {
  const FocusPlantsSettingsScreen({super.key});

  @override
  State<FocusPlantsSettingsScreen> createState() => _FocusPlantsSettingsScreenState();
}

class _FocusPlantsSettingsScreenState extends State<FocusPlantsSettingsScreen> {
  static const _primaryColor = Color(0xFF4CAF50);

  final List<Map<String, dynamic>> _plants = [
    {'name': 'Sunflower', 'icon': '🌻', 'unlocked': true, 'sessions': 0},
    {'name': 'Rose', 'icon': '🌹', 'unlocked': true, 'sessions': 5},
    {'name': 'Tulip', 'icon': '🌷', 'unlocked': true, 'sessions': 10},
    {'name': 'Cactus', 'icon': '🌵', 'unlocked': false, 'sessions': 20},
    {'name': 'Palm Tree', 'icon': '🌴', 'unlocked': false, 'sessions': 30},
    {'name': 'Cherry Blossom', 'icon': '🌸', 'unlocked': false, 'sessions': 50},
    {'name': 'Bamboo', 'icon': '🎋', 'unlocked': false, 'sessions': 75},
    {'name': 'Bonsai', 'icon': '🌳', 'unlocked': false, 'sessions': 100},
  ];

  int _totalSessions = 15;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.black87), onPressed: () => Navigator.pop(context)),
        title: const Text('Plants & Garden', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProgressCard(),
            const SizedBox(height: 24),
            const Text('Your Collection', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _buildPlantsGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_primaryColor, _primaryColor.withValues(alpha: 0.7)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text('🌱', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text('$_totalSessions Sessions Completed', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('${_plants.where((p) => p['unlocked']).length}/${_plants.length} Plants Unlocked', style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildPlantsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.2, crossAxisSpacing: 12, mainAxisSpacing: 12),
      itemCount: _plants.length,
      itemBuilder: (context, index) {
        final plant = _plants[index];
        final isUnlocked = plant['unlocked'];
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            if (!isUnlocked) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Complete ${plant['sessions']} sessions to unlock ${plant['name']}'), backgroundColor: _primaryColor),
              );
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: isUnlocked ? Border.all(color: _primaryColor, width: 2) : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(isUnlocked ? plant['icon'] : '🔒', style: TextStyle(fontSize: isUnlocked ? 40 : 32)),
                const SizedBox(height: 8),
                Text(plant['name'], style: TextStyle(fontWeight: FontWeight.w600, color: isUnlocked ? Colors.black87 : Colors.grey)),
                if (!isUnlocked)
                  Text('${plant['sessions']} sessions', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }
}
