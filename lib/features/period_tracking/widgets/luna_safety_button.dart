import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../theme/luna_theme.dart';

/// Emergency SOS button for Luna Cycle safety feature
class LunaSafetySOSButton extends StatefulWidget {
  final VoidCallback onSOS;
  final bool countdownEnabled;
  final int countdownSeconds;
  final VoidCallback? onCountdownCancel;

  const LunaSafetySOSButton({
    super.key,
    required this.onSOS,
    this.countdownEnabled = true,
    this.countdownSeconds = 5,
    this.onCountdownCancel,
  });

  @override
  State<LunaSafetySOSButton> createState() => _LunaSafetySOSButtonState();
}

class _LunaSafetySOSButtonState extends State<LunaSafetySOSButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  bool _isCountingDown = false;
  int _countdown = 0;
  Timer? _countdownTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    HapticFeedback.heavyImpact();
    
    if (!widget.countdownEnabled) {
      widget.onSOS();
      return;
    }

    setState(() {
      _isCountingDown = true;
      _countdown = widget.countdownSeconds;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() => _countdown--);
        HapticFeedback.mediumImpact();
      } else {
        timer.cancel();
        setState(() => _isCountingDown = false);
        widget.onSOS();
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _isCountingDown = false;
      _countdown = 0;
    });
    widget.onCountdownCancel?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_isCountingDown) {
      return _buildCountdownView();
    }

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _isPressed ? 0.95 : _pulseAnimation.value,
          child: GestureDetector(
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) {
              setState(() => _isPressed = false);
              _startCountdown();
            },
            onTapCancel: () => setState(() => _isPressed = false),
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LunaTheme.safetyGradient,
                boxShadow: [
                  BoxShadow(
                    color: LunaTheme.safetyRed.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.sos,
                    color: Colors.white,
                    size: 40,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'SOS',
                    style: LunaTheme.titleLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCountdownView() {
    return GestureDetector(
      onTap: _cancelCountdown,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: LunaTheme.safetyRed.withOpacity(0.1),
          border: Border.all(
            color: LunaTheme.safetyRed,
            width: 3,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$_countdown',
              style: LunaTheme.displayLarge.copyWith(
                color: LunaTheme.safetyRed,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Tap to cancel',
              style: LunaTheme.labelSmall.copyWith(
                color: LunaTheme.safetyRed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick safety action button
class LunaSafetyQuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const LunaSafetyQuickAction({
    super.key,
    required this.icon,
    required this.label,
    this.color = LunaTheme.safetyRed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: LunaTheme.spacingLg,
          vertical: LunaTheme.spacingMd,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(LunaTheme.radiusLg),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: LunaTheme.spacingSm),
            Text(
              label,
              style: LunaTheme.titleMedium.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Emergency contact card
class LunaEmergencyContactCard extends StatelessWidget {
  final String name;
  final String phone;
  final String? relationship;
  final bool isPrimary;
  final VoidCallback? onCall;
  final VoidCallback? onMessage;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const LunaEmergencyContactCard({
    super.key,
    required this.name,
    required this.phone,
    this.relationship,
    this.isPrimary = false,
    this.onCall,
    this.onMessage,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(LunaTheme.spacingLg),
      decoration: BoxDecoration(
        color: LunaTheme.getSurface(context),
        borderRadius: BorderRadius.circular(LunaTheme.radiusLg),
        border: Border.all(
          color: isPrimary
              ? LunaTheme.primaryPink
              : LunaTheme.getDivider(context),
          width: isPrimary ? 2 : 1,
        ),
        boxShadow: LunaTheme.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: LunaTheme.primaryPink.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    name[0].toUpperCase(),
                    style: LunaTheme.headlineMedium.copyWith(
                      color: LunaTheme.primaryPink,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: LunaTheme.spacingMd),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: LunaTheme.titleLarge.copyWith(
                            color: LunaTheme.getTextPrimary(context),
                          ),
                        ),
                        if (isPrimary) ...[
                          const SizedBox(width: LunaTheme.spacingSm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: LunaTheme.spacingSm,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: LunaTheme.primaryPink,
                              borderRadius: BorderRadius.circular(LunaTheme.radiusSm),
                            ),
                            child: Text(
                              'PRIMARY',
                              style: LunaTheme.labelSmall.copyWith(
                                color: Colors.white,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      phone,
                      style: LunaTheme.bodyMedium.copyWith(
                        color: LunaTheme.getTextSecondary(context),
                      ),
                    ),
                    if (relationship != null)
                      Text(
                        relationship!,
                        style: LunaTheme.bodySmall.copyWith(
                          color: LunaTheme.getTextTertiary(context),
                        ),
                      ),
                  ],
                ),
              ),
              // Menu
              if (onEdit != null || onDelete != null)
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: LunaTheme.getTextSecondary(context),
                  ),
                  onSelected: (value) {
                    if (value == 'edit') onEdit?.call();
                    if (value == 'delete') onDelete?.call();
                  },
                  itemBuilder: (context) => [
                    if (onEdit != null)
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 20),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                    if (onDelete != null)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                  ],
                ),
            ],
          ),
          // Action buttons
          if (onCall != null || onMessage != null) ...[
            const SizedBox(height: LunaTheme.spacingMd),
            Row(
              children: [
                if (onCall != null)
                  Expanded(
                    child: _ContactActionButton(
                      icon: Icons.call,
                      label: 'Call',
                      color: LunaTheme.success,
                      onTap: onCall!,
                    ),
                  ),
                if (onCall != null && onMessage != null)
                  const SizedBox(width: LunaTheme.spacingMd),
                if (onMessage != null)
                  Expanded(
                    child: _ContactActionButton(
                      icon: Icons.message,
                      label: 'Message',
                      color: LunaTheme.primaryPink,
                      onTap: onMessage!,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ContactActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: LunaTheme.spacingMd,
          vertical: LunaTheme.spacingSm,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(LunaTheme.radiusMd),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: LunaTheme.spacingXs),
            Text(
              label,
              style: LunaTheme.labelMedium.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Location sharing status card
class LunaLocationShareCard extends StatelessWidget {
  final String sharedWithName;
  final String? address;
  final DateTime startedAt;
  final DateTime? expiresAt;
  final VoidCallback onStop;

  const LunaLocationShareCard({
    super.key,
    required this.sharedWithName,
    this.address,
    required this.startedAt,
    this.expiresAt,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = expiresAt?.difference(DateTime.now());
    
    return Container(
      padding: const EdgeInsets.all(LunaTheme.spacingLg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            LunaTheme.communityTeal.withOpacity(0.1),
            LunaTheme.communityTeal.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(LunaTheme.radiusLg),
        border: Border.all(
          color: LunaTheme.communityTeal.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(LunaTheme.spacingSm),
                decoration: BoxDecoration(
                  color: LunaTheme.communityTeal.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.location_on,
                  color: LunaTheme.communityTeal,
                  size: 20,
                ),
              ),
              const SizedBox(width: LunaTheme.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sharing with $sharedWithName',
                      style: LunaTheme.titleMedium.copyWith(
                        color: LunaTheme.getTextPrimary(context),
                      ),
                    ),
                    if (remaining != null && remaining.inMinutes > 0)
                      Text(
                        '${remaining.inMinutes} min remaining',
                        style: LunaTheme.bodySmall.copyWith(
                          color: LunaTheme.getTextSecondary(context),
                        ),
                      ),
                  ],
                ),
              ),
              // Live indicator
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: LunaTheme.spacingSm,
                  vertical: LunaTheme.spacingXs,
                ),
                decoration: BoxDecoration(
                  color: LunaTheme.safetyRed,
                  borderRadius: BorderRadius.circular(LunaTheme.radiusSm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'LIVE',
                      style: LunaTheme.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (address != null) ...[
            const SizedBox(height: LunaTheme.spacingMd),
            Text(
              address!,
              style: LunaTheme.bodyMedium.copyWith(
                color: LunaTheme.getTextSecondary(context),
              ),
            ),
          ],
          const SizedBox(height: LunaTheme.spacingMd),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                onStop();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: LunaTheme.safetyRed,
                side: const BorderSide(color: LunaTheme.safetyRed),
              ),
              child: const Text('Stop Sharing'),
            ),
          ),
        ],
      ),
    );
  }
}
