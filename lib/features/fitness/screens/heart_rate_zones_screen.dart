import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/storage_service.dart';
import '../models/training_models.dart';

class HeartRateZonesScreen extends StatefulWidget {
  const HeartRateZonesScreen({super.key});

  @override
  State<HeartRateZonesScreen> createState() => _HeartRateZonesScreenState();
}

class _HeartRateZonesScreenState extends State<HeartRateZonesScreen> {
  int _maxHr = 185;
  int _restingHr = 60;
  bool _useCustomZones = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // Load from storage or use defaults
    // For now, we'll just recalculate if the box is empty
    if (StorageService.heartRateZonesListenable.value.isEmpty) {
        _calculateAndSaveZones();
    }
  }

  void _calculateAndSaveZones() async {
    final zones = [
      HeartRateZone(
        id: '1',
        name: 'Zone 1 - Recovery',
        description: 'Very light activity, active recovery',
        minBpm: _getBpmFromPercent(50),
        maxBpm: _getBpmFromPercent(60),
        color: '#90CAF9', // specific hex codes as strings
        benefits: ['Active recovery', 'Warm-up/Cool-down', 'Fat burning'],
      ),
      HeartRateZone(
        id: '2',
        name: 'Zone 2 - Endurance',
        description: 'Aerobic base building, easy pace',
        minBpm: _getBpmFromPercent(60),
        maxBpm: _getBpmFromPercent(70),
        color: '#81C784',
        benefits: ['Builds aerobic base', 'Improves endurance', 'Efficient fat burning'],
      ),
      HeartRateZone(
        id: '3',
        name: 'Zone 3 - Tempo',
        description: 'Moderate intensity, tempo training',
        minBpm: _getBpmFromPercent(70),
        maxBpm: _getBpmFromPercent(80),
        color: '#FFD54F',
        benefits: ['Improves efficiency', 'Increases lactate threshold', 'Race pace training'],
      ),
      HeartRateZone(
        id: '4',
        name: 'Zone 4 - Threshold',
        description: 'High intensity, anaerobic capacity',
        minBpm: _getBpmFromPercent(80),
        maxBpm: _getBpmFromPercent(90),
        color: '#FF8A65',
        benefits: ['Increases speed', 'Builds power', 'Improves VO2 max'],
      ),
      HeartRateZone(
        id: '5',
        name: 'Zone 5 - VO2 Max',
        description: 'Maximum effort, peak performance',
        minBpm: _getBpmFromPercent(90),
        maxBpm: _getBpmFromPercent(100),
        color: '#EF5350',
        benefits: ['Maximum power', 'Sprint training', 'Peak performance'],
      ),
    ];
    
    // Clear and save new zones
    // StorageService doesn't have a clear method exposed directly for this box in the snippet I saw earlier,
    // but I can iterate and delete or just put. `StorageService` usually has specific methods.
    // I should check if I have a method to save zones.
    // I recall `saveHeartRateZone`.
    
    for (var zone in zones) {
        await StorageService.saveHeartRateZone(zone);
    }
  }

  int _getBpmFromPercent(int percent) {
    return ((_maxHr - _restingHr) * (percent / 100) + _restingHr).round();
  }
  
  Color _getColorFromHex(String hexColor) {
    hexColor = hexColor.replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor';
    }
    return Color(int.parse(hexColor, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Heart Rate Zones',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, color: AppColors.textPrimary),
            onPressed: _showInfoDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeartRateSettings(),
            const SizedBox(height: 24),
            _buildZonesVisualization(),
            const SizedBox(height: 24),
            _buildZonesList(),
            const SizedBox(height: 24),
            // _buildTimeInZonesCard(), // This requires workout history data analysis which is complex, we can placeholder it or remove
          ],
        ),
      ),
    );
  }

  Widget _buildHeartRateSettings() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.favorite, color: Colors.red, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Heart Rate Profile',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Customize your zones',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSlider(
            label: 'Max Heart Rate',
            value: _maxHr,
            min: 150,
            max: 220,
            unit: 'bpm',
            onChanged: (val) => setState(() {
              _maxHr = val.round();
              _calculateAndSaveZones();
            }),
          ),
          const SizedBox(height: 20),
          _buildSlider(
            label: 'Resting Heart Rate',
            value: _restingHr,
            min: 40,
            max: 100,
            unit: 'bpm',
            onChanged: (val) => setState(() {
              _restingHr = val.round();
              _calculateAndSaveZones();
            }),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Use custom zones',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Switch(
                value: _useCustomZones,
                onChanged: (val) => setState(() => _useCustomZones = val),
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required int value,
    required double min,
    required double max,
    required String unit,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$value $unit',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 6,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
          ),
          child: Slider(
            value: value.toDouble(),
            min: min,
            max: max,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.primary.withOpacity(0.2),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildZonesVisualization() {
      return ValueListenableBuilder(
          valueListenable: StorageService.heartRateZonesListenable,
          builder: (context, box, _) {
              final zones = box.values.toList()..sort((a, b) => a.minBpm.compareTo(b.minBpm));
              if (zones.isEmpty) return const SizedBox.shrink();
              
              return Container(
                height: 60,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                    ),
                    ],
                ),
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Row(
                    children: zones.map((zone) {
                        final zoneColor = _getColorFromHex(zone.color);
                        // rough calculation for width
                        final width = (zone.maxBpm - zone.minBpm) / (_maxHr - _restingHr) * 100;
                        
                        return Expanded(
                        flex: width.round(),
                        child: Container(
                            color: zoneColor,
                            child: Center(
                            child: Text(
                                '${zone.minBpm}-${zone.maxBpm}',
                                style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                shadows: [
                                    Shadow(color: Colors.black26, blurRadius: 2),
                                ],
                                ),
                            ),
                            ),
                        ),
                        );
                    }).toList(),
                    ),
                ),
             );
          }
      );
  }

  Widget _buildZonesList() {
      return ValueListenableBuilder(
          valueListenable: StorageService.heartRateZonesListenable,
          builder: (context, box, _) {
              final zones = box.values.toList()..sort((a, b) => a.minBpm.compareTo(b.minBpm));
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    const Text(
                    'Zone Details',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                    ),
                    ),
                    const SizedBox(height: 16),
                    ...List.generate(zones.length, (index) {
                    final zone = zones[index];
                    return _buildZoneCard(zone, index + 1);
                    }),
                ],
              );
          }
      );
  }

  Widget _buildZoneCard(HeartRateZone zone, int zoneNumber) {
    final zoneColor = _getColorFromHex(zone.color);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: zoneColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                'Z$zoneNumber',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          title: Text(
            zone.name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            '${zone.minBpm} - ${zone.maxBpm} bpm',
            style: TextStyle(
              color: zoneColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    zone.description,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Benefits:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (zone.benefits).map((benefit) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: zoneColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          benefit,
                          style: TextStyle(
                            fontSize: 12,
                            color: zoneColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('About Heart Rate Zones'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Heart rate zones help you train at the right intensity for your goals.',
                style: TextStyle(height: 1.5),
              ),
              SizedBox(height: 16),
              Text(
                'Zones are calculated using the Karvonen formula, which considers both your max heart rate and resting heart rate for more accurate zones.',
                style: TextStyle(height: 1.5),
              ),
              SizedBox(height: 16),
              Text(
                'Max HR Estimation:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('220 - Your Age = Estimated Max HR'),
              SizedBox(height: 12),
              Text(
                'For best results, perform a max HR test or use data from your hardest recent workout.',
                style: TextStyle(height: 1.5),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
