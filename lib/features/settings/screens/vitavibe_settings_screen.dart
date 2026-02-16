import 'package:flutter/material.dart';
import '../../../core/services/vitavibe_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../settings/screens/early_access_screen.dart';

class VitaVibeSettingsScreen extends StatefulWidget {
  const VitaVibeSettingsScreen({super.key});

  @override
  State<VitaVibeSettingsScreen> createState() => _VitaVibeSettingsScreenState();
}

class _VitaVibeSettingsScreenState extends State<VitaVibeSettingsScreen> {
  final _service = VitaVibeService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Light grey background
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.vibration_rounded, size: 24),
            const SizedBox(width: 8),
            const Text(
              'VitaVibe',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'FREE',
                style: TextStyle(
                  color: Colors.teal,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListenableBuilder(
        listenable: _service,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Intro Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.touch_app_rounded, color: Colors.teal, size: 28),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Haptic Feedback',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D3142),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Enable premium vibrations',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF9098B1),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _service.isEnabled,
                          onChanged: (value) => _service.toggleEnabled(value),
                          activeColor: Colors.teal,
                        ),
                      ],
                    ),
                    if (_service.isEnabled) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(height: 1),
                      ),
                      const Row(
                        children: [
                          Icon(Icons.speed_rounded, color: Colors.orange, size: 24),
                          SizedBox(width: 16),
                          Text(
                            'Intensity',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2D3142),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          activeTrackColor: Colors.teal,
                          inactiveTrackColor: Colors.teal.withOpacity(0.1),
                          thumbColor: Colors.white,
                          overlayColor: Colors.teal.withOpacity(0.1),
                          valueIndicatorColor: Colors.teal,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12, elevation: 2),
                        ),
                        child: Slider(
                          value: _service.intensity.index.toDouble(),
                          min: 0,
                          max: 4,
                          divisions: 4,
                          label: _getIntensityLabel(_service.intensity),
                          onChanged: (value) => _service.setIntensity(VibeIntensity.values[value.toInt()]),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Soft', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                            Text(
                              _getIntensityLabel(_service.intensity),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 12),
                            ),
                            Text('Strong', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              if (_service.isEnabled) ...[
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    'FEATURE HAPTICS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF9098B1),
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildFeatureItem(
                        key: 'medicine',
                        title: 'Medicine Taken',
                        icon: Icons.medication_rounded,
                        iconColor: Colors.teal,
                        bgColor: Colors.teal.withOpacity(0.1),
                      ),
                      _buildDivider(),
                      _buildFeatureItem(
                        key: 'reminder', // Assuming mapped to specific key usage or general notification
                        title: 'Medicine Reminder',
                        icon: Icons.alarm_rounded,
                        iconColor: Colors.orange,
                        bgColor: Colors.orange.withOpacity(0.1),
                        overridePattern: VibePattern.medicineTime, 
                        // Note: 'reminder' might not be a direct key in service map yet, using medicine logic
                      ),
                      _buildDivider(),
                      _buildFeatureItem(
                        key: 'water',
                        title: 'Water Added',
                        icon: Icons.water_drop_rounded,
                        iconColor: Colors.blue,
                        bgColor: Colors.blue.withOpacity(0.1),
                      ),
                      _buildDivider(),
                      _buildFeatureItem(
                        key: 'celebrate',
                        title: 'Water Goal',
                        icon: Icons.emoji_events_rounded,
                        iconColor: Colors.green,
                        bgColor: Colors.green.withOpacity(0.1),
                        overrideKey: 'celebrate', // Use celebrate key for goal
                      ),
                      _buildDivider(),
                      _buildFeatureItem(
                        key: 'focus',
                        title: 'Focus Start',
                        icon: Icons.self_improvement_rounded,
                        iconColor: Colors.teal,
                        bgColor: Colors.teal.withOpacity(0.1),
                      ),
                      _buildDivider(),
                      _buildFeatureItem(
                        key: 'focus_complete',
                        title: 'Focus Complete',
                        icon: Icons.check_circle_rounded,
                        iconColor: Colors.green,
                        bgColor: Colors.green.withOpacity(0.1),
                        overrideKey: 'celebrate', // Use celebrate for focus complete too or new key
                      ),
                      _buildDivider(),
                      _buildFeatureItem(
                        key: 'navigation',
                        title: 'Navigation',
                        icon: Icons.touch_app_rounded,
                        iconColor: Colors.indigo,
                        bgColor: Colors.indigo.withOpacity(0.1),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Pattern Explorer Button
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.explore_rounded, color: Colors.purple),
                    ),
                    title: const Text(
                      'Pattern Explorer',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
                    ),
                    subtitle: const Text('Test all vibration patterns'),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF9098B1)),
                  onTap: _showPatternExplorer,
                  ),
                ),

                const SizedBox(height: 24),

                // Early Access Features
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.science_rounded, color: Colors.orange),
                    ),
                    title: const Text(
                      'Early Access',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
                    ),
                    subtitle: const Text('Try experimental features'),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF9098B1)),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const EarlyAccessScreen()),
                      );
                    },
                  ),
                ),
              ],
               const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 70, endIndent: 20, color: Color(0xFFF0F2F5));
  }

  Widget _buildFeatureItem({
    required String key,
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    String? overrideKey,
    VibePattern? overridePattern,
  }) {
    // Determine the effective key and pattern
    final effectiveKey = overrideKey ?? key;
    // If overridePattern is provided, display it but maybe disable editing if it's not in the map?
    // Actually, we want to allow editing. We should probably stick to keys that are in the map.
    // For specific scenarios like 'Medicine Reminder' vs 'Medicine Taken', 
    // if they share the same key assigned in service, they change together.
    
    // For this UI, let's assume we map 'medicine' key to 'Medicine Taken'
    // and 'medicine_reminder' might simply display the 'medicine' key pattern too 
    // or we'd need to add more keys to the service.
    // For now, let's map 'Medicine Reminder' to 'medicine' key as well, or similar.
    
    // Let's use the actual keys from the service:
    // medicine, water, focus, navigation, relax, celebrate.
    
    // Adjusting input implementation to match service keys:
    late final String actualKey;
    if (title.contains('Water Goal') || title.contains('Focus Complete')) {
      actualKey = 'celebrate';
    } else if (title.contains('Medicine')) {
      actualKey = 'medicine';
    } else if (title.contains('Water')) {
      actualKey = 'water';
    } else if (title.contains('Focus')) {
      actualKey = 'focus';
    } else if (title.contains('Navigation')) {
      actualKey = 'navigation';
    } else {
      actualKey = 'navigation'; 
    }

    final currentPattern = _service.getPatternForFeature(actualKey);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showPatternSelector(context, actualKey, title),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF2D3142),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatPatternName(currentPattern),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF9098B1),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFCFD3D8)),
            ],
          ),
        ),
      ),
    );
  }

  void _showPatternSelector(BuildContext context, String featureKey, String title) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.vibration_rounded, color: Colors.teal, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            'Select Pattern for $title',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D3142),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      itemCount: VibePattern.values.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final pattern = VibePattern.values[index];
                        final isSelected = _service.getPatternForFeature(featureKey) == pattern;
                        final metadata = _getPatternMetadata(pattern);
                        
                        return Container(
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.teal.withOpacity(0.05) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? Colors.teal : Colors.grey.withOpacity(0.1),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                _service.setFeaturePattern(featureKey, pattern);
                                Navigator.pop(context);
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    // Pattern Icon
                                    Text(
                                      metadata['emoji']!,
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _formatPatternName(pattern),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: isSelected ? Colors.teal : const Color(0xFF2D3142),
                                            ),
                                          ),
                                          Text(
                                            metadata['desc']!,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF9098B1),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.play_circle_outline_rounded,
                                        color: isSelected ? Colors.teal : Colors.teal,
                                      ),
                                      onPressed: () => _service.playPattern(pattern),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showPatternExplorer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    'Pattern Explorer',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                   Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      itemCount: VibeCategory.values.length,
                      itemBuilder: (context, index) {
                        final category = VibeCategory.values[index];
                        final patterns = _getPatternsForCategory(category);
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 8, bottom: 8, top: 16),
                              child: Text(
                                _formatCategoryName(category).toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            ...patterns.map((pattern) {
                              final metadata = _getPatternMetadata(pattern);
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey.withOpacity(0.1)),
                                ),
                                child: ListTile(
                                  leading: Text(metadata['emoji']!, style: const TextStyle(fontSize: 24)),
                                  title: Text(
                                    _formatPatternName(pattern),
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text(metadata['desc']!),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.play_circle_fill, color: Colors.teal),
                                    onPressed: () => _service.playPattern(pattern),
                                  ),
                                ),
                              );
                            }),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- Helpers ---

  String _getIntensityLabel(VibeIntensity intensity) {
    switch (intensity) {
      case VibeIntensity.ultraLight: return 'Ultra Light';
      case VibeIntensity.light: return 'Light';
      case VibeIntensity.medium: return 'Medium';
      case VibeIntensity.strong: return 'Strong';
      case VibeIntensity.ultraStrong: return 'Ultra Strong';
    }
  }

  String _formatCategoryName(VibeCategory category) {
    final name = category.toString().split('.').last;
    return name;
  }
  
  String _formatPatternName(VibePattern pattern) {
    final name = pattern.toString().split('.').last;
    final buffer = StringBuffer();
    for (int i = 0; i < name.length; i++) {
      if (i == 0) {
        buffer.write(name[i].toUpperCase());
      } else if (name[i].toUpperCase() == name[i] && i > 0) {
        buffer.write(' ${name[i]}');
      } else {
        buffer.write(name[i]);
      }
    }
    return buffer.toString();
  }

  List<VibePattern> _getPatternsForCategory(VibeCategory category) {
     switch (category) {
      case VibeCategory.basic:
        return [VibePattern.tap, VibePattern.doubleTap, VibePattern.tripleTap, VibePattern.longPress, VibePattern.strongBuzz];
      case VibeCategory.rhythmic:
        return [VibePattern.heartbeat, VibePattern.pulse, VibePattern.sos, VibePattern.drumroll, VibePattern.tickTock];
      case VibeCategory.nature:
        return [VibePattern.raindrops, VibePattern.oceanWave, VibePattern.thunder, VibePattern.birdChirp, VibePattern.catPurr];
      case VibeCategory.alert:
        return [VibePattern.alert, VibePattern.reminder, VibePattern.urgentAlert, VibePattern.medicineTime, VibePattern.waterReminder];
      case VibeCategory.relaxation:
        return [VibePattern.breathingGuide, VibePattern.massage, VibePattern.meditationBell, VibePattern.sleepyWave, VibePattern.calmBreeze];
      case VibeCategory.celebration:
        return [VibePattern.success, VibePattern.celebration, VibePattern.fanfare, VibePattern.fireworks, VibePattern.goalReached];
    }
  }

  Map<String, String> _getPatternMetadata(VibePattern pattern) {
    switch (pattern) {
      // Basic
      case VibePattern.tap: return {'emoji': '👆', 'desc': 'Quick single tap'};
      case VibePattern.doubleTap: return {'emoji': '✌️', 'desc': 'Two quick taps'};
      case VibePattern.tripleTap: return {'emoji': '🤟', 'desc': 'Three quick taps'};
      case VibePattern.longPress: return {'emoji': '✊', 'desc': 'Extended vibration'};
      case VibePattern.strongBuzz: return {'emoji': '💪', 'desc': 'Powerful vibration'};
      
      // Rhythmic
      case VibePattern.heartbeat: return {'emoji': '💓', 'desc': 'Realistic heartbeat rhythm'};
      case VibePattern.pulse: return {'emoji': '🔴', 'desc': 'Steady pulsing rhythm'};
      case VibePattern.sos: return {'emoji': '🆘', 'desc': 'Emergency SOS pattern'};
      case VibePattern.drumroll: return {'emoji': '🥁', 'desc': 'Building excitement'};
      case VibePattern.tickTock: return {'emoji': '⏰', 'desc': 'Clock-like rhythm'};
      
      // Nature
      case VibePattern.raindrops: return {'emoji': '🌧️', 'desc': 'Gentle rain falling'};
      case VibePattern.oceanWave: return {'emoji': '🌊', 'desc': 'Rising and falling wave'};
      case VibePattern.thunder: return {'emoji': '⛈️', 'desc': 'Rumbling thunder'};
      case VibePattern.birdChirp: return {'emoji': '🐦', 'desc': 'Morning bird song'};
      case VibePattern.catPurr: return {'emoji': '🐱', 'desc': 'Soothing purring'};
      
      // Alert
      case VibePattern.alert: return {'emoji': '🚨', 'desc': 'Attention-grabbing alert'};
      case VibePattern.reminder: return {'emoji': '📌', 'desc': 'Gentle reminder nudge'};
      case VibePattern.urgentAlert: return {'emoji': '⚠️', 'desc': 'Critical notification'};
      case VibePattern.medicineTime: return {'emoji': '💊', 'desc': 'Time to take your medicine'};
      case VibePattern.waterReminder: return {'emoji': '💧', 'desc': 'Stay hydrated!'};
      
      // Relaxation
      case VibePattern.breathingGuide: return {'emoji': '🧘', 'desc': 'Inhale... exhale...'};
      case VibePattern.massage: return {'emoji': '💆', 'desc': 'Relaxing massage pattern'};
      case VibePattern.meditationBell: return {'emoji': '🔔', 'desc': 'Zen bell ring'};
      case VibePattern.sleepyWave: return {'emoji': '😴', 'desc': 'Gentle lullaby rhythm'};
      case VibePattern.calmBreeze: return {'emoji': '🍃', 'desc': 'Soft, breezy sensation'};
      
      // Celebration
      case VibePattern.success: return {'emoji': '✅', 'desc': 'Achievement unlocked!'};
      case VibePattern.celebration: return {'emoji': '🎉', 'desc': 'Party time!'};
      case VibePattern.fanfare: return {'emoji': '🎺', 'desc': 'Regal announcement'};
      case VibePattern.fireworks: return {'emoji': '🎆', 'desc': 'Explosive celebration'};
      case VibePattern.goalReached: return {'emoji': '🏆', 'desc': 'Goal completion!'};
    }
  }
}
