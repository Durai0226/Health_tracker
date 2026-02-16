import 'dart:async';
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

class _AlarmScreenState extends State<AlarmScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
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
    _controller = AnimationController(
             duration: const Duration(seconds: 1),
             vsync: this,
           )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Hide status bar for full immersion
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
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
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(height: 40),
            // Time Display
            Column(
              children: [
                Text(
                  DateFormat('HH:mm').format(_now),
                  style: const TextStyle(
                    fontSize: 80,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
                Text(
                  DateFormat('EEE, MMM d').format(_now),
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
            
            // Alarm Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.alarm,
                        size: 64,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            
            // Actions
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _handleSnooze,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: const Text(
                        'SNOOZE',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _handleDismiss,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withOpacity(0.7),
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                    ),
                    child: const Text(
                      'Dismiss',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
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
