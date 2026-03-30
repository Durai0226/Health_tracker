import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/category_manager.dart';
import '../../../core/services/haptic_service.dart';
import '../../navigation/screens/main_navigation_screen.dart';

class CategorySelectionScreen extends StatefulWidget {
  final bool isOnboarding;
  
  const CategorySelectionScreen({
    super.key,
    this.isOnboarding = true,
  });

  @override
  State<CategorySelectionScreen> createState() => _CategorySelectionScreenState();
}

class _CategorySelectionScreenState extends State<CategorySelectionScreen> 
    with TickerProviderStateMixin {
  final CategoryManager _categoryManager = CategoryManager();
  final HapticService _hapticService = HapticService();
  
  AppCategory? _selectedCategory;
  bool _isLoading = false;
  
  late AnimationController _mainController;
  late AnimationController _staggerController;
  late AnimationController _pulseController;
  late AnimationController _buttonController;
  
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _buttonScale;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    _initAnimations();
  }

  void _initAnimations() {
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _staggerController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _mainController,
      curve: Curves.easeOut,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: Curves.easeOutCubic,
    ));
    
    _buttonScale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeInOut),
    );
    
    _mainController.forward();
    _staggerController.forward();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _mainController.dispose();
    _staggerController.dispose();
    _pulseController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  Future<void> _confirmSelection() async {
    if (_selectedCategory == null) return;
    
    _buttonController.forward().then((_) => _buttonController.reverse());
    setState(() => _isLoading = true);
    _hapticService.success();
    
    await _categoryManager.selectCategory(_selectedCategory!);
    
    if (!mounted) return;
    
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MainNavigationScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.02),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFFAFAFC),
      body: Stack(
        children: [
          // Animated background
          _buildAnimatedBackground(size, isDark),
          
          // Main content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  children: [
                    // Header
                    _buildHeader(isDark),
                    
                    // Category Cards
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            const SizedBox(height: 8),
                            ...CategoryManager.allCategories.asMap().entries.map(
                              (entry) => _buildCompactCategoryCard(entry.value, entry.key, isDark),
                            ),
                            const SizedBox(height: 12),
                            _buildFunRelaxCard(isDark),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
                    
                    // Bottom Action
                    _buildBottomAction(isDark),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground(Size size, bool isDark) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = _pulseController.value;
        return Stack(
          children: [
            Positioned(
              top: -size.height * 0.1,
              right: -size.width * 0.2,
              child: Transform.scale(
                scale: 1.0 + pulse * 0.03,
                child: Container(
                  width: size.width * 0.6,
                  height: size.width * 0.6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary.withOpacity(isDark ? 0.15 : 0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: size.height * 0.2,
              left: -size.width * 0.15,
              child: Transform.scale(
                scale: 1.0 + (1 - pulse) * 0.03,
                child: Container(
                  width: size.width * 0.5,
                  height: size.width * 0.5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF8B5CF6).withOpacity(isDark ? 0.12 : 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Premium badge with shimmer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  const Color(0xFF4ECDC4),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 15),
                SizedBox(width: 6),
                Text(
                  'PICK YOUR PATH',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Catchy title
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [
                isDark ? Colors.white : const Color(0xFF1A1D29),
                AppColors.primary,
              ],
            ).createShader(bounds),
            child: const Text(
              "What's Your\nFocus Today?",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -1,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 10),
          
          Text(
            'Select one to personalize your experience',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.getTextSecondary(context),
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactCategoryCard(CategoryConfig config, int index, bool isDark) {
    final isSelected = _selectedCategory == config.category;
    final delay = index * 0.12;
    
    return AnimatedBuilder(
      animation: _staggerController,
      builder: (context, child) {
        final animValue = Curves.easeOutBack.transform(
          ((_staggerController.value - delay) * 1.5).clamp(0.0, 1.0),
        );
        return Transform.translate(
          offset: Offset(0, 30 * (1 - animValue)),
          child: Opacity(
            opacity: animValue.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            _hapticService.selection();
            setState(() => _selectedCategory = config.category);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        config.color.withOpacity(isDark ? 0.25 : 0.15),
                        config.color.withOpacity(isDark ? 0.15 : 0.08),
                      ],
                    )
                  : LinearGradient(
                      colors: isDark
                          ? [AppColors.darkCard, AppColors.darkElevatedCard]
                          : [Colors.white, Colors.white.withOpacity(0.95)],
                    ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? config.color.withOpacity(0.5)
                    : isDark
                        ? AppColors.darkBorder.withOpacity(0.3)
                        : Colors.grey.withOpacity(0.1),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? config.color.withOpacity(0.25)
                      : Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                  blurRadius: isSelected ? 16 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Animated Icon
                AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [config.color, config.color.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: config.color.withOpacity(0.4),
                        blurRadius: isSelected ? 12 : 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(config.icon, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 14),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              config.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.getTextPrimary(context),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        config.tagline,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? config.color : AppColors.getTextSecondary(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Feature icons row
                      _buildFeatureIcons(config, isDark),
                    ],
                  ),
                ),
                
                // Selection indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(colors: [config.color, config.color.withOpacity(0.8)])
                        : null,
                    color: isSelected ? null : (isDark ? AppColors.darkCard : const Color(0xFFF3F4F6)),
                    shape: BoxShape.circle,
                    border: isSelected ? null : Border.all(
                      color: isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB),
                      width: 1.5,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: config.color.withOpacity(0.4), blurRadius: 8)]
                        : null,
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutBack,
                      switchOutCurve: Curves.easeIn,
                      child: Icon(
                        isSelected ? Icons.check_rounded : Icons.chevron_right_rounded,
                        key: ValueKey<bool>(isSelected),
                        color: isSelected ? Colors.white : AppColors.getTextSecondary(context),
                        size: isSelected ? 18 : 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureIcons(CategoryConfig config, bool isDark) {
    final featureIcons = _getFeatureIcons(config.features);
    
    return Row(
      children: [
        ...featureIcons.take(4).map((icon) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: config.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 14, color: config.color),
          ),
        )),
        if (featureIcons.length > 4)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: config.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '+${featureIcons.length - 4}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: config.color,
              ),
            ),
          ),
      ],
    );
  }

  List<IconData> _getFeatureIcons(List<String> features) {
    final iconMap = {
      'medicine': Icons.medication_rounded,
      'water': Icons.water_drop_rounded,
      'reminders': Icons.notifications_rounded,
      'focus': Icons.self_improvement_rounded,
      'notes': Icons.note_alt_rounded,
      'exam_prep': Icons.school_rounded,
      'fitness': Icons.fitness_center_rounded,
      'finance': Icons.account_balance_wallet_rounded,
      'period': Icons.calendar_month_rounded,
      'mood': Icons.mood_rounded,
      'habit': Icons.track_changes_rounded,
    };
    
    return features.map((f) => iconMap[f] ?? Icons.star_rounded).toList();
  }

  Widget _buildFunRelaxCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF9333EA).withOpacity(isDark ? 0.2 : 0.1),
            const Color(0xFFEC4899).withOpacity(isDark ? 0.15 : 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF9333EA).withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF9333EA), Color(0xFFEC4899)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF9333EA).withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.spa_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Fun & Relax',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.success, AppColors.success.withOpacity(0.8)],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'FREE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Games & relaxation always included',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 22),
        ],
      ),
    );
  }

  Widget _buildBottomAction(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            (isDark ? AppColors.darkBackground : const Color(0xFFFAFAFC)).withOpacity(0),
            isDark ? AppColors.darkBackground : const Color(0xFFFAFAFC),
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedOpacity(
              opacity: _selectedCategory != null ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'You can change anytime from settings',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              ),
            ),
            ScaleTransition(
              scale: _buttonScale,
              child: GestureDetector(
                onTapDown: (_) => _buttonController.forward(),
                onTapUp: (_) => _buttonController.reverse(),
                onTapCancel: () => _buttonController.reverse(),
                onTap: _selectedCategory != null && !_isLoading ? _confirmSelection : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: _selectedCategory != null
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppColors.primary, const Color(0xFF4ECDC4)],
                          )
                        : LinearGradient(
                            colors: [
                              isDark ? AppColors.darkCard : const Color(0xFFE5E7EB),
                              isDark ? AppColors.darkElevatedCard : const Color(0xFFD1D5DB),
                            ],
                          ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: _selectedCategory != null
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _selectedCategory != null ? "Let's Go!" : 'Select a Category',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _selectedCategory != null
                                      ? Colors.white
                                      : (isDark ? Colors.white54 : const Color(0xFF374151)),
                                  letterSpacing: -0.2,
                                ),
                              ),
                              if (_selectedCategory != null) ...[
                                const SizedBox(width: 10),
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_forward_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ],
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
