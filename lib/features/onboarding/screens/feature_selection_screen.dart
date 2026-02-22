import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/services/feature_manager.dart';
import '../../navigation/screens/main_navigation_screen.dart';

class FeatureSelectionScreen extends StatefulWidget {
  final bool isOnboarding;
  
  const FeatureSelectionScreen({
    super.key,
    this.isOnboarding = true,
  });

  @override
  State<FeatureSelectionScreen> createState() => _FeatureSelectionScreenState();
}

class _FeatureSelectionScreenState extends State<FeatureSelectionScreen> {
  final FeatureManager _featureManager = FeatureManager();
  final Set<String> _selectedFeatures = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeSelection();
  }

  void _initializeSelection() {
    // Start with currently enabled features
    for (final feature in _featureManager.enabledFeatures) {
      _selectedFeatures.add(feature.id);
    }
    // Ensure core features are selected
    for (final feature in FeatureManager.coreFeatures) {
      _selectedFeatures.add(feature.id);
    }
  }

  Future<void> _saveAndContinue() async {
    setState(() => _isLoading = true);
    
    await _featureManager.setEnabledFeatures(_selectedFeatures);
    
    if (!mounted) return;
    
    if (widget.isOnboarding) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!widget.isOnboarding)
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                    ),
                  const SizedBox(height: 8),
                  Text(
                    widget.isOnboarding 
                        ? 'Customize Your Experience'
                        : 'Manage Features',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.isOnboarding
                        ? 'Select the features you want to use. You can change this later in Settings.'
                        : 'Enable or disable features based on your needs.',
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            
            // Features List
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Core Features Section
                    _buildSectionHeader('Core Features', 'Always enabled'),
                    const SizedBox(height: 12),
                    ...FeatureManager.coreFeatures.map(
                      (f) => _buildFeatureCard(f, isCore: true),
                    ),
                    
                    const SizedBox(height: 28),
                    
                    // Optional Features Section
                    _buildSectionHeader('Optional Features', 'Tap to toggle'),
                    const SizedBox(height: 12),
                    ...FeatureManager.optionalFeatures.map(
                      (f) => _buildFeatureCard(f, isCore: false),
                    ),
                  ],
                ),
              ),
            ),
            
            // Bottom Action
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    Text(
                      '${_selectedFeatures.length} features selected',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: CommonButton(
                        text: widget.isOnboarding ? 'Get Started' : 'Save Changes',
                        variant: ButtonVariant.primary,
                        isLoading: _isLoading,
                        onPressed: _isLoading ? null : _saveAndContinue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
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
    );
  }

  Widget _buildFeatureCard(FeatureConfig feature, {required bool isCore}) {
    final isSelected = _selectedFeatures.contains(feature.id);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: isCore
            ? null
            : () {
                setState(() {
                  if (isSelected) {
                    _selectedFeatures.remove(feature.id);
                  } else {
                    _selectedFeatures.add(feature.id);
                  }
                });
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? feature.color.withOpacity(0.5)
                  : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? feature.color.withOpacity(0.15)
                    : Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      feature.color,
                      feature.color.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: feature.color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  feature.icon,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              
              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          feature.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (isCore) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'CORE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      feature.description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Selection Indicator
              if (isCore)
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: AppColors.success,
                    size: 16,
                  ),
                )
              else
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? feature.color
                        : Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSelected ? Icons.check_rounded : Icons.add_rounded,
                    color: isSelected ? Colors.white : Colors.grey.shade500,
                    size: 18,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
