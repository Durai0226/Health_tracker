
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/services/feature_manager.dart';
import '../../../core/services/category_manager.dart';
import '../../period_tracking/screens/period_intro_screen.dart';
import '../../period_tracking/screens/period_overview_screen.dart';
import 'notification_settings_screen.dart';
import 'haptic_settings_screen.dart';
import 'vitavibe_settings_screen.dart';
import 'feature_settings_screen.dart';
import '../../../core/services/vitavibe_service.dart';
import '../../reminders/screens/reminder_analysis_screen.dart';
import 'backup_screen.dart';
import '../../../main.dart';
import '../../../widgets/smart_ad_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _authService = AuthService();
  final _hapticService = HapticService();
  final _vitaVibeService = VitaVibeService();
  final _categoryManager = CategoryManager();
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
    final categoryConfig = _categoryManager.selectedCategoryConfig;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getCardBg(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.logout_rounded, color: AppColors.warning, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Sign Out'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to sign out?',
              style: TextStyle(color: AppColors.getTextPrimary(context)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.info.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.info, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Signing out will allow you to select a different focus category.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (categoryConfig != null) ...[
              const SizedBox(height: 12),
              Text(
                'Current: ${categoryConfig.name}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.getTextSecondary(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.getTextSecondary(context))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.error.withOpacity(0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/welcome',
          (route) => false,
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
          // Category Section
          _buildCategorySection(),
          const SizedBox(height: 24),
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
    final isDark = AppColors.isDark(context);
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
    final settings = StorageService.getUserSettings();
    final isDarkMode = settings.darkModeEnabled;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          _hapticService.tap();
          final newDarkMode = !isDarkMode;
          final updated = settings.copyWith(darkModeEnabled: newDarkMode);
          await StorageService.saveUserSettings(updated);
          
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
                  await StorageService.saveUserSettings(updated);
                  
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

  Widget _buildCategorySection() {
    final categoryConfig = _categoryManager.selectedCategoryConfig;
    final isDark = AppColors.isDark(context);
    
    if (categoryConfig == null) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Your Focus',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.getTextSecondary(context),
            ),
          ),
        ),
        // Compact luxurious category card
        Container(
          decoration: BoxDecoration(
            color: AppColors.getCardBg(context),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // Main category row - compact
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Elegant icon with gradient
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: categoryConfig.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        categoryConfig.icon,
                        color: categoryConfig.color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Category info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  categoryConfig.name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.getTextPrimary(context),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: categoryConfig.color.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'ACTIVE',
                                  style: TextStyle(
                                    color: categoryConfig.color,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            categoryConfig.tagline,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.getTextSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Arrow indicator
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.getDivider(context),
                      size: 20,
                    ),
                  ],
                ),
              ),
              // Divider
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: isDark ? AppColors.darkBorder.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
              ),
              // Features row - compact horizontal pills
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    // Fun & Relax pill
                    _buildFeaturePill(
                      icon: Icons.spa_rounded,
                      label: 'Fun & Relax',
                      color: AppColors.focusPrimary,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    // Features count
                    Expanded(
                      child: Text(
                        '+${categoryConfig.features.length} features',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.getTextSecondary(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    // Info icon with tooltip
                    GestureDetector(
                      onTap: () => _showCategoryInfoSheet(categoryConfig),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isDark 
                              ? Colors.white.withOpacity(0.05)
                              : Colors.grey.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturePill({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '✓',
              style: TextStyle(
                color: AppColors.success,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCategoryInfoSheet(CategoryConfig config) {
    final isDark = AppColors.isDark(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.getCardBg(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Icon and title
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: config.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(config.icon, color: config.color, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              config.name,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              config.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.getTextSecondary(context),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            // Features list
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark 
                    ? Colors.white.withOpacity(0.03)
                    : Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'INCLUDED FEATURES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.getTextSecondary(context),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFeatureChip('Fun & Relax', AppColors.focusPrimary),
                      ...config.features.map((f) => _buildFeatureChip(
                        _formatFeatureName(f),
                        config.color,
                      )),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Change category info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.info.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.swap_horiz_rounded, color: AppColors.info, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Sign out to switch your focus category',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  String _formatFeatureName(String id) {
    return id.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
  }

  Widget _buildRemoveAdsTile() {
    final settings = StorageService.getUserSettings();
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
