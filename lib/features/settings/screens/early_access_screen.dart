import 'package:flutter/material.dart';
import '../../../core/services/feature_flag_service.dart';
import '../../../core/constants/app_colors.dart';

class EarlyAccessScreen extends StatefulWidget {
  const EarlyAccessScreen({super.key});

  @override
  State<EarlyAccessScreen> createState() => _EarlyAccessScreenState();
}

class _EarlyAccessScreenState extends State<EarlyAccessScreen> {
  final _featureService = FeatureFlagService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Early Access', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: _featureService.notifier,
        builder: (context, _, __) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildWarningCard(),
              const SizedBox(height: 24),
              const Text(
                'EXPERIMENTAL FEATURES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF9098B1),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              _buildFeatureToggle(
                key: FeatureFlagService.keyAdvancedRepeat,
                title: 'Advanced Repeat Options',
                description: 'Enable complex recurrence rules (e.g., "Every 2nd Tuesday").',
                icon: Icons.update_rounded,
                color: Colors.blue,
              ),
              const SizedBox(height: 12),
              _buildFeatureToggle(
                key: FeatureFlagService.keyPremiumThemes,
                title: 'Premium Themes',
                description: 'Unlock additional color themes and layouts.',
                icon: Icons.palette_rounded,
                color: Colors.purple,
              ),
              const SizedBox(height: 12),
              _buildFeatureToggle(
                key: FeatureFlagService.keyBetaFeatures,
                title: 'Beta Features',
                description: 'Opt-in to the latest beta features (May be unstable).',
                icon: Icons.science_rounded,
                color: Colors.orange,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWarningCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Heads up!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'These features are in early development and might change, break, or disappear at any time.',
                  style: TextStyle(color: Color(0xFF2D3142), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureToggle({
    required String key,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    final isEnabled = _featureService.isEnabled(key);

    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
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
                      fontSize: 16,
                      color: Color(0xFF2D3142),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9098B1),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: isEnabled,
              onChanged: (value) async {
                await _featureService.setEnabled(key, value);
                setState(() {}); // Rebuild to update UI (notifier handles it too but safe to setState)
              },
              activeColor: color,
            ),
          ],
        ),
      ),
    );
  }
}
