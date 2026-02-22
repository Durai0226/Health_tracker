

import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../models/beverage_type.dart';
import '../models/enhanced_water_log.dart';
import '../services/water_service.dart';
import '../../../../core/services/vitavibe_service.dart';
import 'water_reminder_settings_screen.dart';

class WaterTrackingScreen extends StatefulWidget {
  const WaterTrackingScreen({super.key});

  @override
  State<WaterTrackingScreen> createState() => _WaterTrackingScreenState();
}

class _WaterTrackingScreenState extends State<WaterTrackingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;
  final VitaVibeService _vitaVibeService = VitaVibeService();
  
  DailyWaterData? _todayData;
  int _dailyGoal = 2500;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _loadData();
  }

  Future<void> _loadData() async {
    // Ensure WaterService is initialized (safe to call multiple times)
    await WaterService.init();
    
    if (mounted) {
      setState(() {
        _todayData = WaterService.getTodayData();
        _dailyGoal = WaterService.getDailyGoal();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  void _addWater(int amount) async {
    // Trigger haptic feedback for water add
    _vitaVibeService.waterAdd();
    
    // Default to water for quick add
    final waterBeverage = WaterService.getBeverage('water') ?? BeverageType.defaultBeverages.first;
    
    final newData = await WaterService.addWaterLog(
      amountMl: amount,
      beverage: waterBeverage,
    );
    
    if (mounted) {
      final progress = newData.progress;
      final effectiveHydration = newData.effectiveHydrationMl;
      
      // Celebrate goal reached with special haptic
      if (progress >= 1 && (effectiveHydration - amount) < _dailyGoal) {
        _vitaVibeService.waterGoalReached();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.water_drop, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text('+${amount}ml added${progress >= 1 ? ' 🎉 Goal reached!' : ''}'),
            ],
          ),
          backgroundColor: progress >= 1 ? AppColors.success : AppColors.info,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _editGoal() {
    int newGoal = _dailyGoal;
    final isDark = AppColors.isDark(context);
    final waterAccent = AppColors.getWaterAccent(context);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: AppColors.getModalBackground(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.getGrey300(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Set Daily Goal',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      _vitaVibeService.tap();
                      setModalState(() {
                        newGoal = (newGoal - 250).clamp(500, 5000);
                      });
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: waterAccent.withOpacity(isDark ? 0.2 : 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.remove, color: waterAccent),
                    ),
                    iconSize: 36,
                  ),
                  const SizedBox(width: 32),
                  Column(
                    children: [
                      Text(
                        '${newGoal}ml',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: waterAccent,
                        ),
                      ),
                      Text(
                        '${(newGoal / 250).round()} glasses',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 32),
                  IconButton(
                    onPressed: () {
                      _vitaVibeService.tap();
                      setModalState(() {
                        newGoal = (newGoal + 250).clamp(500, 5000);
                      });
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: waterAccent.withOpacity(isDark ? 0.2 : 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.add, color: waterAccent),
                    ),
                    iconSize: 36,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              CommonButton(
                text: 'Save Goal',
                icon: Icons.save,
                variant: ButtonVariant.primary,
                backgroundColor: waterAccent,
                onPressed: () async {
                  _vitaVibeService.playPattern(VibePattern.success);
                  
                  // Update header in HydrationProfile via WaterService
                  final profile = WaterService.getProfile();
                  final updatedProfile = profile.copyWith(
                    customGoalMl: newGoal,
                    useCustomGoal: true,
                  );
                  await WaterService.saveProfile(updatedProfile);
                  
                  // Also update today's data goal
                  final todayData = WaterService.getTodayData();
                  final updatedData = todayData.copyWith(dailyGoalMl: newGoal);
                  await WaterService.saveDailyData(updatedData);

                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
  
    return ValueListenableBuilder(
      valueListenable: WaterService.listenToDailyData()!,
      builder: (context, box, _) {
        final water = WaterService.getTodayData();
        final progress = water.progress.clamp(0.0, 1.0);

        final isDark = AppColors.isDark(context);
        final waterAccent = AppColors.getWaterAccent(context);

        return Scaffold(
          backgroundColor: AppColors.getBackground(context),
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.getCardBg(context),
                  shape: BoxShape.circle,
                  border: isDark ? Border.all(color: AppColors.darkBorder.withOpacity(0.5)) : null,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.getSubtleShadow(context),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(Icons.arrow_back_ios_rounded, color: AppColors.getTextPrimary(context), size: 18),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.getCardBg(context),
                    shape: BoxShape.circle,
                    border: isDark ? Border.all(color: AppColors.darkBorder.withOpacity(0.5)) : null,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.getSubtleShadow(context),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(Icons.notifications_rounded, color: waterAccent, size: 20),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const WaterReminderSettingsScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
            ],
          ),
          body: Stack(
            children: [
              // Gradient background
              Container(
                height: MediaQuery.of(context).size.height * 0.4,
                decoration: BoxDecoration(
                  gradient: AppColors.getFeatureGradient(context, waterAccent),
                ),
              ),
              // Content
              SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 16),
                        // Title
                        Text(
                          'Water Intake',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Stay hydrated, stay healthy',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Water Tank
                        _buildWaterTank(water, progress),
                        const SizedBox(height: 32),
                        // Quick Add
                        SizedBox(
                          width: double.infinity,
                          child: Text(
                            'Quick Add',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.getTextPrimary(context),
                              ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildQuickAddButtons(),
                        const SizedBox(height: 32),
                        // Today's Log
                        if (water.logs.isNotEmpty) ...[
                          SizedBox(
                            width: double.infinity,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Today\'s Log',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.getTextPrimary(context),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: waterAccent.withOpacity(isDark ? 0.2 : 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${water.drinksCount} drinks',
                                    style: TextStyle(
                                      color: waterAccent,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildLogList(water.logs),
                        ] else ...[
                          Center(
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 20),
                              padding: const EdgeInsets.all(24),
                              decoration: AppColors.getCardDecoration(context),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.water_drop_outlined,
                                    size: 48,
                                    color: AppColors.getTextSecondary(context).withOpacity(0.5),
                                    ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No drinks logged yet',
                                    style: TextStyle(
                                      color: AppColors.getTextSecondary(context),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWaterTank(DailyWaterData water, double progress) {
    final isDark = AppColors.isDark(context);
    final waterAccent = AppColors.getWaterAccent(context);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppColors.getLuxuryCardDecoration(context, accentColor: waterAccent),
      child: Column(
        children: [
          // Animated Water Tank
          SizedBox(
            height: 260,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Tank container
                Container(
                  width: 200,
                  height: 240,
                  decoration: BoxDecoration(
                    color: AppColors.getGrey100(context),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: AppColors.getGrey300(context), width: 3),
                  ),
                ),
                // Water fill with wave
                ClipRRect(
                  borderRadius: BorderRadius.circular(27),
                  child: SizedBox(
                    width: 194,
                    height: 234,
                    child: Stack(
                      children: [
                        // Water fill
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 800),
                            curve: Curves.easeInOut,
                            height: 234 * progress,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  waterAccent.withOpacity(0.6),
                                  waterAccent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Wave animation
                        if (progress > 0.05)
                          Positioned(
                            bottom: 234 * progress - 8,
                            left: 0,
                            right: 0,
                            child: AnimatedBuilder(
                              animation: _waveController,
                              builder: (context, child) {
                                return CustomPaint(
                                  size: const Size(194, 16),
                                  painter: _WavePainter(
                                    animationValue: _waveController.value,
                                    color: waterAccent.withOpacity(0.4),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Center content
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${water.effectiveHydrationMl}ml',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: progress > 0.5 ? Colors.white : AppColors.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: _editGoal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'of ${water.dailyGoalMl}ml',
                            style: TextStyle(
                              fontSize: 14,
                              color: progress > 0.5 ? Colors.white70 : AppColors.getTextSecondary(context),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.edit,
                            size: 14,
                            color: progress > 0.5 ? Colors.white70 : AppColors.getTextSecondary(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: progress > 0.5 ? Colors.white : waterAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Progress badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: progress >= 1.0
                  ? AppColors.success.withOpacity(isDark ? 0.2 : 0.1)
                  : waterAccent.withOpacity(isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  progress >= 1.0 ? Icons.check_circle : Icons.water_drop,
                  color: progress >= 1.0 ? AppColors.success : waterAccent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  progress >= 1.0
                      ? 'Goal Achieved! 🎉'
                      : 'Keep going! ${(water.dailyGoalMl - water.effectiveHydrationMl).clamp(0, water.dailyGoalMl)}ml to go',
                  style: TextStyle(
                    color: progress >= 1.0 ? AppColors.success : waterAccent,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAddButtons() {
    final isDark = AppColors.isDark(context);
    final waterAccent = AppColors.getWaterAccent(context);
    
    final amounts = [
      {'ml': 150, 'label': 'Cup', 'icon': '☕'},
      {'ml': 250, 'label': 'Glass', 'icon': '🥛'},
      {'ml': 500, 'label': 'Bottle', 'icon': '🧃'},
      {'ml': 750, 'label': 'Large', 'icon': '🧴'},
    ];

    return Row(
      children: amounts.map((item) {
        return Expanded(
          child: GestureDetector(
            onTap: () => _addWater(item['ml'] as int),
            child: Container(
              margin: EdgeInsets.only(
                right: item != amounts.last ? 12 : 0,
              ),
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark 
                      ? [AppColors.darkCard, AppColors.darkElevatedCard]
                      : [Colors.white, Colors.grey[50]!],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: waterAccent.withOpacity(isDark ? 0.15 : 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: waterAccent.withOpacity(isDark ? 0.2 : 0.1),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    item['icon'] as String,
                    style: const TextStyle(fontSize: 32),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '+${item['ml']}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: waterAccent,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ml',
                    style: TextStyle(
                      color: AppColors.getTextSecondary(context),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLogList(List<EnhancedWaterLog> logs) {
    final isDark = AppColors.isDark(context);
    final waterAccent = AppColors.getWaterAccent(context);
    final reversedLogs = logs.reversed.toList();
    
    return Container(
      decoration: AppColors.getCardDecoration(context),
      child: Column(
        children: reversedLogs.take(8).map((log) {
          final timeStr = '${log.time.hour.toString().padLeft(2, '0')}:${log.time.minute.toString().padLeft(2, '0')}';
          final isLast = log == reversedLogs.take(8).last;
          
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isLast ? Colors.transparent : AppColors.getDivider(context),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        waterAccent.withOpacity(isDark ? 0.25 : 0.2),
                        waterAccent.withOpacity(isDark ? 0.15 : 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.water_drop,
                    color: waterAccent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '+${log.amountMl} ml',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextPrimary(context),
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$timeStr • ${log.beverageName}',
                        style: TextStyle(
                          color: AppColors.getTextSecondary(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, color: AppColors.success, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Logged',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double animationValue;
  final Color color;

  _WavePainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);

    for (double i = 0; i <= size.width; i++) {
      path.lineTo(
        i,
        size.height / 2 +
            math.sin((i / size.width * 2 * math.pi) +
                    (animationValue * 2 * math.pi)) *
                6,
      );
    }

    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
