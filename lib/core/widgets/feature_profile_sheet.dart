import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import '../services/haptic_service.dart';
import '../services/category_manager.dart';
import '../../features/onboarding/screens/welcome_screen.dart';
import '../../features/onboarding/screens/feature_selection_screen.dart';
import '../../main.dart' show navigatorKey;
import 'confirmation_bottom_sheet.dart';

/// Feature-specific setting item configuration
class FeatureSettingItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool isDestructive;

  const FeatureSettingItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.isDestructive = false,
  });
}

/// Reusable profile sheet for all features
/// Shows user info, feature-specific settings, and sign out option
class FeatureProfileSheet extends StatefulWidget {
  final String featureName;
  final Color featureColor;
  final IconData featureIcon;
  final List<FeatureSettingItem> settings;
  final VoidCallback? onSyncTap;
  final VoidCallback onSignOut;

  const FeatureProfileSheet({
    super.key,
    required this.featureName,
    required this.featureColor,
    required this.featureIcon,
    required this.settings,
    this.onSyncTap,
    required this.onSignOut,
  });

  /// Show the profile sheet from the right
  static Future<void> show({
    required BuildContext context,
    required String featureName,
    required Color featureColor,
    required IconData featureIcon,
    required List<FeatureSettingItem> settings,
    VoidCallback? onSyncTap,
    required VoidCallback onSignOut,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Profile',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FeatureProfileSheet(
          featureName: featureName,
          featureColor: featureColor,
          featureIcon: featureIcon,
          settings: settings,
          onSyncTap: onSyncTap,
          onSignOut: onSignOut,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        );
      },
    );
  }

  @override
  State<FeatureProfileSheet> createState() => _FeatureProfileSheetState();
}

class _FeatureProfileSheetState extends State<FeatureProfileSheet> {
  final AuthService _authService = AuthService();
  final HapticService _hapticService = HapticService();
  bool _isSyncing = false;

  Future<void> _handleSync() async {
    if (_isSyncing || widget.onSyncTap == null) return;
    
    setState(() => _isSyncing = true);
    _hapticService.selection();
    
    widget.onSyncTap!();
    
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      setState(() => _isSyncing = false);
      _hapticService.success();
    }
  }

  void _handleSignOut() async {
    _hapticService.warning();
    final isGuest = _authService.isGuest;
    
    final confirmed = await ConfirmationBottomSheet.show(
      context: context,
      title: isGuest ? 'Exit Session' : 'Sign Out',
      message: isGuest 
          ? 'End your guest session and return to start? Guest data will be lost. Sign in to save your data.'
          : 'Sign out and choose a different focus area? Your data is synced and will be preserved.',
      confirmText: isGuest ? 'Exit' : 'Sign Out',
      icon: Icons.logout_rounded,
      isDangerous: isGuest,
    );

    if (confirmed == true && mounted) {
      Navigator.pop(context); // Close profile sheet
      _performSmartSignOut(isGuest);
    }
  }

  void _performSmartSignOut(bool wasGuest) async {
    final categoryManager = CategoryManager();
    
    if (wasGuest) {
      // Guest: Sign out completely and go to welcome screen
      await _authService.signOut();
      await categoryManager.clearCategory();
      
      // Use global navigator key for reliable navigation from deep screens
      navigatorKey.currentState?.pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const WelcomeScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
        (route) => false,
      );
    } else {
      // Logged in user: Clear category selection but keep account, go to feature selection
      await categoryManager.clearCategory();
      
      // Use global navigator key for reliable navigation from deep screens
      navigatorKey.currentState?.pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const FeatureSelectionScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final user = _authService.currentUser;
    final isGuest = _authService.isGuest;
    final screenWidth = MediaQuery.of(context).size.width;
    final sheetWidth = screenWidth * 0.85 > 400 ? 400.0 : screenWidth * 0.85;

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        width: sheetWidth,
        height: double.infinity,
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            bottomLeft: Radius.circular(28),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withOpacity(0.9)
                    : Colors.white.withOpacity(0.98),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  bottomLeft: Radius.circular(28),
                ),
                border: Border(
                  left: BorderSide(
                    color: widget.featureColor.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
              ),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    _buildHeader(isDark),
                    
                    // User info
                    _buildUserInfo(isDark, user, isGuest),
                    
                    const SizedBox(height: 8),
                    
                    // Divider
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        height: 1,
                        color: AppColors.getBorder(context),
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Settings list
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        physics: const BouncingScrollPhysics(),
                        children: [
                          // Feature settings section
                          _buildSectionTitle('${widget.featureName} Settings'),
                          const SizedBox(height: 8),
                          
                          ...widget.settings.map((item) => _buildSettingItem(item, isDark)),
                          
                          const SizedBox(height: 16),
                          
                          // Sync section (if not guest)
                          if (!isGuest && widget.onSyncTap != null) ...[
                            _buildSectionTitle('Cloud'),
                            const SizedBox(height: 8),
                            _buildSyncItem(isDark),
                            const SizedBox(height: 16),
                          ],
                          
                          // Account section
                          _buildSectionTitle('Account'),
                          const SizedBox(height: 8),
                          
                          if (isGuest)
                            _buildUpgradeItem(isDark),
                          
                          _buildSignOutItem(isDark),
                          
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            widget.featureColor.withOpacity(0.15),
            widget.featureColor.withOpacity(0.05),
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [widget.featureColor, widget.featureColor.withOpacity(0.8)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: widget.featureColor.withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(widget.featureIcon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Profile',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.getTextPrimary(context),
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              _hapticService.selection();
              Navigator.pop(context);
            },
            icon: Icon(
              Icons.close_rounded,
              color: AppColors.getTextSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfo(bool isDark, UserModel? user, bool isGuest) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isGuest
                    ? [Colors.grey, Colors.grey.shade600]
                    : [widget.featureColor, widget.featureColor.withOpacity(0.7)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isGuest ? Colors.grey : widget.featureColor).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: user?.photoUrl != null
                ? ClipOval(
                    child: Image.network(
                      user!.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildAvatarText(user.name),
                    ),
                  )
                : _buildAvatarText(user?.name ?? 'G'),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        isGuest ? 'Guest User' : (user?.name ?? 'User'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.getTextPrimary(context),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isGuest) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'GUEST',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isGuest ? 'Data stored locally' : (user?.email ?? ''),
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.getTextSecondary(context),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarText(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.getTextSecondary(context),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingItem(FeatureSettingItem item, bool isDark) {
    final color = item.isDestructive ? AppColors.error : widget.featureColor;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _hapticService.selection();
            item.onTap?.call();
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, color: color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: item.isDestructive
                              ? AppColors.error
                              : AppColors.getTextPrimary(context),
                        ),
                      ),
                      if (item.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                item.trailing ?? Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.getTextSecondary(context),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSyncItem(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleSync,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _isSyncing
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.info,
                          ),
                        )
                      : const Icon(Icons.cloud_sync_rounded, color: AppColors.info, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sync to Cloud',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isSyncing ? 'Syncing...' : 'Backup your data',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.getTextSecondary(context),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpgradeItem(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            _hapticService.selection();
            final result = await _authService.signInWithGoogle();
            if (result == null && mounted) {
              _hapticService.success();
              setState(() {});
            }
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  widget.featureColor.withOpacity(0.15),
                  widget.featureColor.withOpacity(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: widget.featureColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [widget.featureColor, widget.featureColor.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.upgrade_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sign in with Google',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: widget.featureColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sync data & unlock all features',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: widget.featureColor,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignOutItem(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleSignOut,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.error.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Sign Out',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.error.withOpacity(0.6),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
