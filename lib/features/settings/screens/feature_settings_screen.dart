import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/feature_manager.dart';

class FeatureSettingsScreen extends StatefulWidget {
  const FeatureSettingsScreen({super.key});

  @override
  State<FeatureSettingsScreen> createState() => _FeatureSettingsScreenState();
}

class _FeatureSettingsScreenState extends State<FeatureSettingsScreen> {
  final FeatureManager _featureManager = FeatureManager();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Manage Features'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListenableBuilder(
        listenable: _featureManager,
        builder: (context, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.1),
                        AppColors.primaryLight.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Customize Your App',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Enable only the features you need for a cleaner, faster experience.',
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
                ),
                
                const SizedBox(height: 28),
                
                // Core Features
                _buildSectionHeader(
                  'Core Features',
                  subtitle: 'Always enabled',
                  icon: Icons.lock_rounded,
                ),
                const SizedBox(height: 12),
                ...FeatureManager.coreFeatures.map(
                  (f) => _buildFeatureTile(f, isCore: true),
                ),
                
                const SizedBox(height: 28),
                
                // Optional Features
                _buildSectionHeader(
                  'Optional Features',
                  subtitle: '${_featureManager.enabledFeatures.length - FeatureManager.coreFeatures.length} enabled',
                  icon: Icons.tune_rounded,
                ),
                const SizedBox(height: 12),
                ...FeatureManager.optionalFeatures.map(
                  (f) => _buildFeatureTile(f, isCore: false),
                ),
                
                const SizedBox(height: 28),
                
                // Reset Button
                Center(
                  child: TextButton.icon(
                    onPressed: () => _showResetDialog(),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Reset to Defaults'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, {String? subtitle, IconData? icon}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
        ],
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        if (subtitle != null) ...[
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFeatureTile(FeatureConfig feature, {required bool isCore}) {
    final isEnabled = _featureManager.isEnabled(feature.id);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isCore
              ? null
              : () async {
                  await _featureManager.toggleFeature(feature.id, !isEnabled);
                },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isEnabled
                        ? feature.color.withOpacity(0.12)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    feature.icon,
                    color: isEnabled ? feature.color : Colors.grey.shade400,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                
                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feature.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isEnabled
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        feature.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: isEnabled
                              ? AppColors.textSecondary
                              : Colors.grey.shade400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Toggle
                if (isCore)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: AppColors.success,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Required',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Switch.adaptive(
                    value: isEnabled,
                    onChanged: (value) async {
                      await _featureManager.toggleFeature(feature.id, value);
                    },
                    activeColor: feature.color,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Features?'),
        content: const Text(
          'This will reset your feature selection to the default settings. Core features will remain enabled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _featureManager.resetToDefaults();
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Features reset to defaults'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    margin: const EdgeInsets.all(16),
                  ),
                );
              }
            },
            child: const Text(
              'Reset',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
