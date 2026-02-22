import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/notification_service.dart';

class AlarmScreen extends StatefulWidget {
  final Map<String, dynamic> payload;

  const AlarmScreen({super.key, required this.payload});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _glowController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;
  late Animation<Offset> _slideAnimation;
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Update time every second
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });

    // Pulsing animation for the alarm icon
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Glow animation
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Slide-in animation for buttons
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // Start slide animation after a delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _slideController.forward();
    });

    // Hide status bar for full immersion
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _glowController.dispose();
    _slideController.dispose();
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _handleDismiss() async {
    // Stop sound/vibration if handled by NotificationService 
    // (Actual stop logic might depend on how sound is played - for now assuming notification sound stops on interacting)
    // If using ringtone player, stop it here. 
    // Since we use native notification sound, cancelling notification stops it.
    final id = widget.payload['id'];
    if (id != null) {
      // Parse ID safely
      int? notificationId;
      if (id is int) {
        notificationId = id;
      } else if (id is String) {
        notificationId = int.tryParse(id);
      }
      
      if (notificationId != null) {
        await NotificationService().cancelNotification(notificationId);
      }
    }
    
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleSnooze() async {
    final id = widget.payload['id'];
    if (id != null) {
      int? notificationId;
        if (id is int) {
          notificationId = id;
        } else if (id is String) {
          notificationId = int.tryParse(id);
        }

      if (notificationId != null) {
        // Trigger snooze logic in NotificationService
        // We might need to expose a direct snooze method or simulating the action
        // For now, let's manually schedule the snooze matching the NotificationService logic
        // Or simpler: The NotificationService could have a public 'snooze' method.
        // Actually the payload might contain 'snoozeDuration'.
        
        final duration = widget.payload['snoozeDuration'];
        int snoozeMinutes = 5;
        if (duration != null) {
           if (duration is int) snoozeMinutes = duration;
           if (duration is String) snoozeMinutes = int.tryParse(duration) ?? 5;
        }
        
        await NotificationService().snoozeReminder(notificationId, snoozeMinutes);
      }
    }
    
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.payload['title'] ?? 'Reminder';
    final body = widget.payload['body'] ?? 'Time for your task!';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.alarmGradient,
        ),
        child: Stack(
          children: [
            // Animated background glow
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _glowAnimation,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.5,
                        colors: [
                          AppColors.primary.withOpacity(_glowAnimation.value * 0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Main content
            SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(height: 60),
                  
                  // Time Display with glassmorphism
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [Colors.white, Color(0xFFB2DFDB)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ).createShader(bounds),
                              child: Text(
                                DateFormat('HH:mm').format(_now),
                                style: const TextStyle(
                                  fontSize: 72,
                                  fontWeight: FontWeight.w200,
                                  color: Colors.white,
                                  height: 1,
                                  letterSpacing: 4,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              DateFormat('EEEE, MMMM d').format(_now),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w300,
                                color: Colors.white.withOpacity(0.7),
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Alarm Content with animated icon
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        // Animated alarm icon with glow
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _pulseAnimation.value,
                              child: Container(
                                padding: const EdgeInsets.all(32),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primary.withOpacity(0.8),
                                      AppColors.primary.withOpacity(0.4),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.5),
                                      blurRadius: 30,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.alarm_rounded,
                                  size: 56,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 40),
                        
                        // Title with gradient
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Colors.white, Color(0xFFE0E0E0)],
                          ).createShader(bounds),
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Body text
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            body,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.85),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Actions with slide animation
                  SlideTransition(
                    position: _slideAnimation,
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          // Snooze button - premium glass style
                          ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                              child: Container(
                                width: double.infinity,
                                height: 60,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withOpacity(0.25),
                                      Colors.white.withOpacity(0.15),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _handleSnooze,
                                    borderRadius: BorderRadius.circular(30),
                                    child: Center(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.snooze_rounded,
                                            color: Colors.white.withOpacity(0.9),
                                            size: 22,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'SNOOZE',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white.withOpacity(0.95),
                                              letterSpacing: 2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Dismiss button - solid primary
                          SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: ElevatedButton(
                              onPressed: _handleDismiss,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 8,
                                shadowColor: AppColors.primary.withOpacity(0.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_rounded, size: 22),
                                  SizedBox(width: 12),
                                  Text(
                                    'DISMISS',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
