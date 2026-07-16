
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app/app_logo.dart';
import '../../../core/services/clean_storage_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/confirmation_bottom_sheet.dart';
import 'notification_settings_screen.dart';
import 'haptic_settings_screen.dart';
import 'vitavibe_settings_screen.dart';
import '../../../core/services/vitavibe_service.dart';
import 'backup_screen.dart';
import '../../backup/presentation/screens/backup_settings_screen.dart';
import '../../../main.dart';
import '../../../widgets/smart_ad_widgets.dart';
import '../../onboarding/screens/welcome_screen.dart';

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
    final confirm = await ConfirmationBottomSheet.showSignOut(context: context);

    if (confirm == true && mounted) {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _authService,
      builder: (context, _) {
        final isGuest = _authService.isGuest;
        final currentUser = _authService.currentUser;
        
        return _buildSettingsScaffold(context, isGuest, currentUser);
      },
    );
  }

  Widget _buildSettingsScaffold(BuildContext context, bool isGuest, currentUser) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Settings",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          // App is 100% Free - Ad Supported
          const AdFreeMessage(),
          const SizedBox(height: 24),
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
                _buildSettingsTile(
                  context,
                  icon: Icons.logout_rounded,
                  iconColor: AppColors.error,
                  title: "Sign Out",
                  subtitle: "Return to welcome screen",
                  onTap: _handleSignOut,
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
              _buildThemeToggleTile(),
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
              _buildHapticSettingsTile(),
              _buildVitaVibeSettingsTile(),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            context,
            title: "Data",
            children: [
              _buildSettingsTile(
                context,
                icon: Icons.save_alt_rounded,
                iconColor: AppColors.warning,
                title: "Backup & Restore",
                subtitle: "Export or import your data as a file",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BackupSettingsScreen()),
                  );
                },
                enabled: true,
              ),
              _buildSettingsTile(
                context,
                icon: Icons.cloud_upload_outlined,
                iconColor: AppColors.info,
                title: "Cloud Backup",
                subtitle: _authService.isAuthenticated
                    ? "Manage your cloud backups"
                    : "Sign in to enable cloud backup",
                onTap: () {
                  if (_authService.isAuthenticated) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BackupScreen()),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sign in with Google to enable cloud backup.'),
                      ),
                    );
                  }
                },
                enabled: true,
                trailing: _authService.isAuthenticated
                    ? null
                    : Icon(Icons.lock_outline_rounded,
                        color: AppColors.getDivider(context)),
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
                title: "About DailyMinder",
                subtitle: "Version 1.0.0",
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: "DailyMinder",
                    applicationVersion: "1.0.0",
                    applicationIcon: const AppLogo.mark(size: 44),
                    applicationLegalese: "© 2026 DailyMinder",
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }


  List<Widget> _buildChildrenWithDividers(List<Widget> children) {
    final result = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      result.add(children[i]);
      if (i < children.length - 1) {
        result.add(Divider(
          height: 1,
          indent: 68,
          color: AppColors.getDivider(context).withOpacity(0.4),
        ));
      }
    }
    return result;
  }

  Widget _buildSection(BuildContext context, {required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.getTextSecondary(context),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.getCardBg(context),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: _buildChildrenWithDividers(children),
          ),
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
    final isDark = AppColors.isDark(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
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
                        color: enabled ? AppColors.getTextPrimary(context) : AppColors.getTextSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              trailing ?? Icon(Icons.chevron_right_rounded, color: AppColors.getDivider(context)),
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
        final isDark = AppColors.isDark(context);
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
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.vibration_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Haptic Feedback",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _hapticService.isEnabled 
                              ? "Enabled • ${_getIntensityLabel(_hapticService.globalIntensity)}"
                              : "Disabled",
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _hapticService.isEnabled,
                    onChanged: (value) async {
                      await _hapticService.setEnabled(value);
                      setState(() {});
                    },
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
        final isDark = AppColors.isDark(context);
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
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.getCardBg(context),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.vibration_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              "Haptix",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppColors.getTextPrimary(context),
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
                              ? "Advanced haptic patterns enabled"
                              : "Advanced vibration patterns",
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _vitaVibeService.isEnabled,
                    onChanged: (value) async {
                      await _vitaVibeService.setEnabled(value);
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemeToggleTile() {
    final settings = CleanStorageService.getUserSettings();
    final isDarkMode = settings.darkModeEnabled;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          _hapticService.tap();
          final newDarkMode = !isDarkMode;
          final updated = settings.copyWith(darkModeEnabled: newDarkMode);
          await CleanStorageService.saveUserSettings(updated);
          
          // Update app theme
          MyApp.of(context)?.setThemeMode(
            newDarkMode ? ThemeMode.dark : ThemeMode.light,
          );
          
          setState(() {});
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isDarkMode ? Colors.indigo : AppColors.warning).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: isDarkMode ? Colors.indigo : AppColors.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Appearance",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isDarkMode ? "Dark mode enabled" : "Light mode enabled",
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isDarkMode,
                onChanged: (value) async {
                  _hapticService.tap();
                  final updated = settings.copyWith(darkModeEnabled: value);
                  await CleanStorageService.saveUserSettings(updated);
                  
                  MyApp.of(context)?.setThemeMode(
                    value ? ThemeMode.dark : ThemeMode.light,
                  );
                  
                  setState(() {});
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRemoveAdsTile() {
    final settings = CleanStorageService.getUserSettings();
    final isAdsDisabled = settings.isAdsDisabled;

    return _buildSettingsTile(
      context,
      icon: isAdsDisabled ? Icons.verified_rounded : Icons.ad_units_rounded,
      iconColor: isAdsDisabled ? AppColors.success : AppColors.primary,
      title: isAdsDisabled ? "Ads Disabled" : "Ad Settings",
      subtitle: isAdsDisabled ? "Ads are currently disabled" : "Manage ad preferences",
      onTap: () async {
        if (isAdsDisabled) return;

        // Simulate purchase
        setState(() => _isLoading = true);
        await Future.delayed(const Duration(seconds: 1)); // Simulate network
        
        final updated = settings.copyWith(isAdsDisabled: true);
        await CleanStorageService.saveUserSettings(updated);
        
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
