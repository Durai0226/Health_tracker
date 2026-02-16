
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/haptic_service.dart';
import '../../period_tracking/screens/period_intro_screen.dart';
import '../../period_tracking/screens/period_overview_screen.dart';
import 'notification_settings_screen.dart';
import 'haptic_settings_screen.dart';
import 'vitavibe_settings_screen.dart';
import '../../../core/services/vitavibe_service.dart';
import '../../reminders/screens/reminder_analysis_screen.dart';
import 'backup_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _authService = AuthService();
  final _hapticService = HapticService();
  final _vitaVibeService = VitaVibeService();
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    final result = await _authService.signInWithGoogle();
    setState(() => _isLoading = false);
    
    if (result == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Successfully signed in with Google!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } else if (result != null && result != 'cancelled' && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out? You can continue using the app as a guest.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _authService.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Signed out successfully. Continuing as guest.'),
            backgroundColor: AppColors.info,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPeriodEnabled = StorageService.isPeriodTrackingEnabled;

    return ListenableBuilder(
      listenable: _authService,
      builder: (context, _) {
        final isGuest = _authService.isGuest;
        final currentUser = _authService.currentUser;
        
        return _buildSettingsScaffold(context, isPeriodEnabled, isGuest, currentUser);
      },
    );
  }

  Widget _buildSettingsScaffold(BuildContext context, bool isPeriodEnabled, bool isGuest, currentUser) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("Settings"),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
        children: [
          if (isGuest)
            _buildSection(
              context,
              title: "Account",
              children: [
                _buildSettingsTile(
                  context,
                  icon: Icons.person_add_rounded,
                  iconColor: AppColors.primary,
                  title: "Sign in with Google",
                  subtitle: "Sync your data and access from anywhere",
                  onTap: _isLoading ? () {} : _handleGoogleSignIn,
                  trailing: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                          ),
                        )
                      : null,
                ),
              ],
            )
          else
            _buildSection(
              context,
              title: "Account",
              children: [
                _buildSettingsTile(
                  context,
                  icon: Icons.person_rounded,
                  iconColor: AppColors.primary,
                  title: currentUser?.name ?? 'User',
                  subtitle: currentUser?.email ?? '',
                  onTap: () {},
                  enabled: false,
                ),
                _buildSettingsTile(
                  context,
                  icon: Icons.logout_rounded,
                  iconColor: AppColors.error,
                  title: "Sign Out",
                  subtitle: "You'll continue as a guest",
                  onTap: _handleSignOut,
                ),
                // Remove Ads Option
                 _buildRemoveAdsTile(),
              ],
            ),
          if (isGuest || !isGuest) const SizedBox(height: 24),
          _buildSection(
            context,
            title: "General",
            children: [
              _buildSettingsTile(
                context,
                icon: Icons.notifications_outlined,
                iconColor: AppColors.info,
                title: "Notifications",
                subtitle: "Reminder sounds and timing",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
                  );
                },
              ),
              _buildSettingsTile(
                context,
                icon: Icons.analytics_outlined,
                iconColor: AppColors.success,
                title: "Reminder Analysis",
                subtitle: "View your reminder statistics",
                onTap: () {
                  _hapticService.tap();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReminderAnalysisScreen()),
                  );
                },
              ),
              _buildHapticSettingsTile(),
              _buildVitaVibeSettingsTile(),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            context,
            title: "Health Tracking",
            children: [
              _buildSettingsTile(
                context,
                icon: Icons.calendar_month_rounded,
                iconColor: AppColors.periodPrimary,
                title: "Period Tracking",
                subtitle: isPeriodEnabled ? "Enabled • Tap to view" : "Track your cycle",
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => isPeriodEnabled
                          ? const PeriodOverviewScreen()
                          : const PeriodIntroScreen(),
                    ),
                  );
                },
                trailing: isPeriodEnabled
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          "ON",
                          style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            context,
            title: "Data",
            children: [
              _buildSettingsTile(
                context,
                icon: Icons.cloud_upload_outlined,
                iconColor: AppColors.warning,
                title: "Backup Data",
                subtitle: "Manage your cloud backups",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BackupScreen()),
                  );
                },
                enabled: true,
              ),
            ],
          ),
          if (!isGuest) const SizedBox(height: 24),
          _buildSection(
            context,
            title: "About",
            children: [
              _buildSettingsTile(
                context,
                icon: Icons.info_outline_rounded,
                iconColor: AppColors.textSecondary,
                title: "About Tablet Reminder",
                subtitle: "Version 1.0.0",
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: "Tablet Reminder",
                    applicationVersion: "1.0.0",
                    applicationLegalese: "© 2026 Your Health Companion",
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildSection(BuildContext context, {required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
    bool enabled = true,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
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
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: enabled ? AppColors.textPrimary : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              trailing ?? const Icon(Icons.chevron_right_rounded, color: AppColors.divider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHapticSettingsTile() {
    return ListenableBuilder(
      listenable: _hapticService,
      builder: (context, _) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _hapticService.tap();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HapticSettingsScreen()),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.vibration_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Haptic Feedback",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _hapticService.isEnabled 
                              ? "Enabled • ${_getIntensityLabel(_hapticService.globalIntensity)}"
                              : "Disabled",
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _hapticService.isEnabled 
                          ? AppColors.success.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _hapticService.isEnabled ? "ON" : "OFF",
                      style: TextStyle(
                        color: _hapticService.isEnabled ? AppColors.success : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
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

  String _getIntensityLabel(HapticIntensity intensity) {
    switch (intensity) {
      case HapticIntensity.light:
        return 'Light';
      case HapticIntensity.medium:
        return 'Medium';
      case HapticIntensity.heavy:
        return 'Strong';
      case HapticIntensity.custom:
        return 'Custom';
    }
  }

  Widget _buildVitaVibeSettingsTile() {
    return ListenableBuilder(
      listenable: _vitaVibeService,
      builder: (context, _) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _vitaVibeService.tap();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VitaVibeSettingsScreen()),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    AppColors.primary.withOpacity(0.05),
                    AppColors.primaryLight.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.vibration_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              "VitaVibe",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [AppColors.success, AppColors.success.withOpacity(0.8)],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                "FREE",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _vitaVibeService.isEnabled 
                              ? "Premium haptic patterns enabled"
                              : "Advanced vibration patterns",
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _vitaVibeService.isEnabled 
                          ? AppColors.success.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _vitaVibeService.isEnabled ? "ON" : "OFF",
                      style: TextStyle(
                        color: _vitaVibeService.isEnabled ? AppColors.success : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
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

  Widget _buildRemoveAdsTile() {
    final settings = StorageService.getUserSettings();
    final isAdsDisabled = settings.isAdsDisabled;

    return _buildSettingsTile(
      context,
      icon: isAdsDisabled ? Icons.verified_rounded : Icons.ad_units_rounded,
      iconColor: isAdsDisabled ? AppColors.success : AppColors.primary,
      title: isAdsDisabled ? "Premium Active" : "Remove Ads",
      subtitle: isAdsDisabled ? "Thank you for your support!" : "Unlock premium experience",
      onTap: () async {
        if (isAdsDisabled) return;

        // Simulate purchase
        setState(() => _isLoading = true);
        await Future.delayed(const Duration(seconds: 1)); // Simulate network
        
        final updated = settings.copyWith(isAdsDisabled: true);
        await StorageService.saveUserSettings(updated);
        
        setState(() => _isLoading = false);
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ads removed successfully!')),
        );
        // Force rebuild to update UI
        setState(() {});
      },
      trailing: isAdsDisabled 
          ? const Icon(Icons.check_circle_outline, color: AppColors.success)
          : null,
    );
  }
}
