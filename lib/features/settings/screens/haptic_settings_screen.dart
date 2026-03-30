import 'package:flutter/material.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';

class HapticSettingsScreen extends StatefulWidget {
  const HapticSettingsScreen({super.key});

  @override
  State<HapticSettingsScreen> createState() => _HapticSettingsScreenState();
}

class _HapticSettingsScreenState extends State<HapticSettingsScreen> {
  final _hapticService = HapticService();

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.vibration_rounded, size: 24),
            const SizedBox(width: 8),
            const Text(
              'Haptic Feel',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListenableBuilder(
        listenable: _hapticService,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Main Haptic Toggle Card
              CommonCard(
                padding: const EdgeInsets.all(20),
                borderRadius: 20,
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.touch_app_rounded, color: Colors.teal, size: 28),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Haptic Feedback',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.getTextPrimary(context),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Enable premium vibrations',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.getTextSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _hapticService.isEnabled,
                          onChanged: (value) => _hapticService.setEnabled(value),
                          activeColor: Colors.teal,
                        ),
                      ],
                    ),
                    if (_hapticService.isEnabled) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(height: 1),
                      ),
                      Row(
                        children: [
                          Icon(Icons.speed_rounded, color: Colors.orange, size: 24),
                          const SizedBox(width: 16),
                          Text(
                            'Intensity',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.getTextPrimary(context),
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
                          value: _hapticService.globalIntensity.index.toDouble(),
                          min: 0,
                          max: 2,
                          divisions: 2,
                          label: _getIntensityLabel(_hapticService.globalIntensity),
                          onChanged: (value) {
                            final intensity = HapticIntensity.values[value.toInt()];
                            _hapticService.setGlobalIntensity(intensity);
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Soft', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                            Text(
                              _getIntensityLabel(_hapticService.globalIntensity),
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
              
              if (_hapticService.isEnabled) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    'FEATURE HAPTICS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextSecondary(context),
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                CommonCard(
                  padding: EdgeInsets.zero,
                  borderRadius: 20,
                  child: Column(
                    children: [
                      _buildFeatureItem(
                        context: context,
                        feature: HapticFeature.medication,
                        title: 'Medicine Taken',
                        icon: Icons.medication_rounded,
                        iconColor: Colors.teal,
                      ),
                      _buildDivider(),
                      _buildFeatureItem(
                        context: context,
                        feature: HapticFeature.medication,
                        title: 'Medicine Reminder',
                        icon: Icons.alarm_rounded,
                        iconColor: Colors.orange,
                      ),
                      _buildDivider(),
                      _buildFeatureItem(
                        context: context,
                        feature: HapticFeature.water,
                        title: 'Water Added',
                        icon: Icons.water_drop_rounded,
                        iconColor: Colors.blue,
                      ),
                      _buildDivider(),
                      _buildFeatureItem(
                        context: context,
                        feature: HapticFeature.water,
                        title: 'Water Goal',
                        icon: Icons.emoji_events_rounded,
                        iconColor: Colors.green,
                      ),
                      _buildDivider(),
                      _buildFeatureItem(
                        context: context,
                        feature: HapticFeature.focus,
                        title: 'Focus Start',
                        icon: Icons.self_improvement_rounded,
                        iconColor: Colors.teal,
                      ),
                      _buildDivider(),
                      _buildFeatureItem(
                        context: context,
                        feature: HapticFeature.focus,
                        title: 'Focus Complete',
                        icon: Icons.check_circle_rounded,
                        iconColor: Colors.green,
                      ),
                      _buildDivider(),
                      _buildFeatureItem(
                        context: context,
                        feature: HapticFeature.navigation,
                        title: 'Navigation',
                        icon: Icons.touch_app_rounded,
                        iconColor: Colors.indigo,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Pattern Explorer
                CommonCard(
                  padding: EdgeInsets.zero,
                  borderRadius: 20,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.explore_rounded, color: Colors.purple),
                    ),
                    title: Text(
                      'Pattern Explorer',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context)),
                    ),
                    subtitle: Text('Test all vibration patterns', style: TextStyle(color: AppColors.getTextSecondary(context))),
                    trailing: Icon(Icons.chevron_right_rounded, color: AppColors.getTextSecondary(context)),
                    onTap: _showPatternExplorer,
                  ),
                ),
                
                const SizedBox(height: 40),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, indent: 70, endIndent: 20, color: Colors.grey.withOpacity(0.1));
  }

  Widget _buildFeatureItem({
    required BuildContext context,
    required HapticFeature feature,
    required String title,
    required IconData icon,
    required Color iconColor,
  }) {
    final isEnabled = _hapticService.featureEnabled[feature] ?? true;
    final intensity = _hapticService.featureIntensity[feature] ?? HapticIntensity.medium;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showFeatureSettings(context, feature, title),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
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
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEnabled ? _getIntensityLabel(intensity) : 'Disabled',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.getTextSecondary(context)),
            ],
          ),
        ),
      ),
    );
  }

  void _showFeatureSettings(BuildContext context, HapticFeature feature, String title) {
    final isDark = AppColors.isDark(context);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isEnabled = _hapticService.featureEnabled[feature] ?? true;
            final intensity = _hapticService.featureIntensity[feature] ?? HapticIntensity.medium;
            
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.vibration_rounded, color: Colors.teal, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.getTextPrimary(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        // Enable/Disable toggle
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Enable for this feature',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.getTextPrimary(context),
                                ),
                              ),
                              const Spacer(),
                              Switch(
                                value: isEnabled,
                                onChanged: (value) {
                                  _hapticService.setFeatureEnabled(feature, value);
                                  setSheetState(() {});
                                },
                                activeColor: Colors.teal,
                              ),
                            ],
                          ),
                        ),
                        
                        if (isEnabled) ...[
                          const SizedBox(height: 16),
                          // Intensity selector
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Intensity',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.getTextPrimary(context),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    _buildIntensityButton(
                                      context, 
                                      'Light', 
                                      HapticIntensity.light, 
                                      intensity,
                                      () {
                                        _hapticService.setFeatureIntensity(feature, HapticIntensity.light);
                                        _hapticService.light();
                                        setSheetState(() {});
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    _buildIntensityButton(
                                      context, 
                                      'Medium', 
                                      HapticIntensity.medium, 
                                      intensity,
                                      () {
                                        _hapticService.setFeatureIntensity(feature, HapticIntensity.medium);
                                        _hapticService.medium();
                                        setSheetState(() {});
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    _buildIntensityButton(
                                      context, 
                                      'Heavy', 
                                      HapticIntensity.heavy, 
                                      intensity,
                                      () {
                                        _hapticService.setFeatureIntensity(feature, HapticIntensity.heavy);
                                        _hapticService.heavy();
                                        setSheetState(() {});
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 24 + MediaQuery.of(context).padding.bottom),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildIntensityButton(
    BuildContext context,
    String label,
    HapticIntensity intensity,
    HapticIntensity currentIntensity,
    VoidCallback onTap,
  ) {
    final isSelected = intensity == currentIntensity;
    
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.teal : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.teal : Colors.grey.withOpacity(0.3),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.getTextSecondary(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPatternExplorer() {
    final isDark = AppColors.isDark(context);
    
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
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                  Text(
                    'Pattern Explorer',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      itemCount: HapticPattern.allPatterns.length,
                      itemBuilder: (context, index) {
                        final pattern = HapticPattern.allPatterns[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey.withOpacity(0.1)),
                          ),
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.teal.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.vibration_rounded, color: Colors.teal, size: 22),
                            ),
                            title: Text(
                              pattern.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.getTextPrimary(context),
                              ),
                            ),
                            subtitle: Text(
                              pattern.description,
                              style: TextStyle(
                                color: AppColors.getTextSecondary(context),
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.play_circle_fill, color: Colors.teal, size: 32),
                              onPressed: () => _playPattern(pattern),
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

  Future<void> _playPattern(HapticPattern pattern) async {
    for (final step in pattern.steps) {
      if (step.delay > 0) {
        await Future.delayed(Duration(milliseconds: step.delay));
      }
      switch (step.type) {
        case HapticStepType.light:
          _hapticService.light();
          break;
        case HapticStepType.medium:
          _hapticService.medium();
          break;
        case HapticStepType.heavy:
          _hapticService.heavy();
          break;
        case HapticStepType.selection:
          _hapticService.selection();
          break;
      }
    }
  }

  String _getIntensityLabel(HapticIntensity intensity) {
    switch (intensity) {
      case HapticIntensity.light:
        return 'Light';
      case HapticIntensity.medium:
        return 'Medium';
      case HapticIntensity.heavy:
        return 'Heavy';
      case HapticIntensity.custom:
        return 'Custom';
    }
  }
}
