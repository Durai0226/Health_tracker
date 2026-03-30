import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/fitness_theme.dart';

/// Fitness Custom Workouts Screen
class FitnessCustomWorkoutsScreen extends StatefulWidget {
  const FitnessCustomWorkoutsScreen({super.key});

  @override
  State<FitnessCustomWorkoutsScreen> createState() => _FitnessCustomWorkoutsScreenState();
}

class _FitnessCustomWorkoutsScreenState extends State<FitnessCustomWorkoutsScreen> {
  final List<Map<String, dynamic>> _customWorkouts = [
    {'name': 'Morning Cardio', 'duration': 30, 'exercises': 8, 'icon': Icons.directions_run},
    {'name': 'Upper Body', 'duration': 45, 'exercises': 12, 'icon': Icons.fitness_center},
    {'name': 'HIIT Session', 'duration': 20, 'exercises': 6, 'icon': Icons.flash_on},
  ];

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: FitnessTheme.themeData,
      child: Scaffold(
        backgroundColor: FitnessTheme.background,
        appBar: AppBar(
          backgroundColor: FitnessTheme.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Custom Workouts', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(Icons.add_circle_outline, color: FitnessTheme.primary),
              onPressed: _showCreateWorkoutSheet,
            ),
          ],
        ),
        body: _customWorkouts.isEmpty ? _buildEmptyState() : _buildWorkoutsList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: FitnessTheme.primary.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: Icon(Icons.fitness_center, color: FitnessTheme.primary, size: 40),
          ),
          const SizedBox(height: 24),
          const Text('No Custom Workouts', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Create your first custom workout routine', style: TextStyle(color: Colors.grey[400])),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showCreateWorkoutSheet,
            icon: const Icon(Icons.add),
            label: const Text('Create Workout'),
            style: ElevatedButton.styleFrom(
              backgroundColor: FitnessTheme.primary,
              foregroundColor: FitnessTheme.background,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(FitnessTheme.spacingMd),
      itemCount: _customWorkouts.length,
      itemBuilder: (context, index) => _buildWorkoutCard(_customWorkouts[index], index),
    );
  }

  Widget _buildWorkoutCard(Map<String, dynamic> workout, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: FitnessTheme.cardBackground, borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 52, height: 52,
          decoration: BoxDecoration(color: FitnessTheme.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14)),
          child: Icon(workout['icon'], color: FitnessTheme.primary),
        ),
        title: Text(workout['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Icon(Icons.timer_outlined, color: Colors.grey[500], size: 14),
              const SizedBox(width: 4),
              Text('${workout['duration']} min', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              const SizedBox(width: 16),
              Icon(Icons.fitness_center, color: Colors.grey[500], size: 14),
              const SizedBox(width: 4),
              Text('${workout['exercises']} exercises', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: Colors.grey[500]),
          color: FitnessTheme.cardBackground,
          onSelected: (value) {
            if (value == 'edit') _editWorkout(index);
            if (value == 'delete') _deleteWorkout(index);
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit', style: TextStyle(color: Colors.white))),
            const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
          ],
        ),
      ),
    );
  }

  void _showCreateWorkoutSheet() {
    final nameController = TextEditingController();
    final durationController = TextEditingController(text: '30');
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
        decoration: BoxDecoration(color: FitnessTheme.cardBackground, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            const Text('Create Workout', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Workout Name',
                labelStyle: TextStyle(color: Colors.grey[500]),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[700]!)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: FitnessTheme.primary)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: durationController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Duration (minutes)',
                labelStyle: TextStyle(color: Colors.grey[500]),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[700]!)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: FitnessTheme.primary)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  if (nameController.text.isNotEmpty) {
                    HapticFeedback.mediumImpact();
                    setState(() {
                      _customWorkouts.add({
                        'name': nameController.text,
                        'duration': int.tryParse(durationController.text) ?? 30,
                        'exercises': 0,
                        'icon': Icons.fitness_center,
                      });
                    });
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: FitnessTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text('Create', style: TextStyle(color: FitnessTheme.background, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editWorkout(int index) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Edit ${_customWorkouts[index]['name']}'), backgroundColor: FitnessTheme.primary),
    );
  }

  void _deleteWorkout(int index) {
    HapticFeedback.mediumImpact();
    setState(() => _customWorkouts.removeAt(index));
  }
}
