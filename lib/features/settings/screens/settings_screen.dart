
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/services/clean_storage_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/confirmation_bottom_sheet.dart';
import 'notification_settings_screen.dart';
import 'premium_screen.dart';
import '../../../core/services/premium_service.dart';
import '../../insights/screens/ai_assistant_screen.dart';
import 'haptic_settings_screen.dart';
import 'vitavibe_settings_screen.dart';
import '../../../core/services/vitavibe_service.dart';
import 'backup_screen.dart';
import '../../backup/presentation/screens/backup_settings_screen.dart';
import '../../sleep/screens/sleep_schedule_settings_screen.dart';
import '../../steps/screens/steps_goal_settings_screen.dart';
import '../../water/screens/water_reminder_settings_screen.dart';
import '../../backup/services/backup_service.dart' as local_backup;
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
  final _localBackupService = local_backup.BackupService();
  bool _isLoading = false;
  bool _isExporting = false;
  bool _isClearing = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    final result = await _authService.signInWithGoogle();
    setState(() => _isLoading = false);

    if (!mounted) return;
    if (result == null) {
      context.toastSuccess('Successfully signed in with Google!');
    } else if (result != 'cancelled') {
      context.toastError(result);
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

  /// One-tap "Export a copy": builds the local ZIP backup and opens the system
  /// share sheet so the user can save it anywhere.
  Future<void> _exportCopy() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    _hapticService.tap();
    try {
      final file = await _localBackupService.createBackup();
      if (!mounted) return;
      if (file != null) {
        await _localBackupService.shareBackup(file);
        if (!mounted) return;
        _showResultSnack('Backup ready to share.', isError: false);
      } else {
        _showResultSnack('Could not create the backup file.', isError: true);
      }
    } catch (e) {
      if (mounted) _showResultSnack('Export failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  /// Destructive "Delete all data": confirmation-guarded wipe of the four core
  /// features. Deletes the kept Drift rows and focus preferences, then routes
  /// the UI back to a clean state.
  Future<void> _deleteAllData() async {
    final confirm = await ConfirmationBottomSheet.show(
      context: context,
      title: 'Delete all data?',
      message:
          'This permanently removes your medicines, water history, focus data '
          'and reminders from this device. This cannot be undone. Consider '
          'exporting a copy first.',
      confirmText: 'Delete everything',
      icon: Symbols.delete_forever_rounded,
      isDangerous: true,
    );
    if (confirm != true || !mounted) return;

    setState(() => _isClearing = true);
    try {
      // Clears the in-memory caches, then the persistent Drift rows / focus prefs.
      await CleanStorageService.clearAllData();
      await CleanStorageService.clearAllPersistentData();
      if (!mounted) return;
      _showResultSnack('All data deleted.', isError: false);
    } catch (e) {
      if (mounted) _showResultSnack('Delete failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  void _showResultSnack(String message, {required bool isError}) {
    if (!mounted) return;
    if (isError) {
      context.toastError(message);
    } else {
      context.toastSuccess(message);
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
    final ext = AppColorsExt.of(context);
    return AccentScope(
      feature: FeatureAccent.brand,
      child: AppScaffold(
        body: Column(
          children: [
            AppHeader(title: 'Settings', accent: ext.brand),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter, AppSpacing.xs, AppSpacing.gutter, 100),
                children: [
                  // App is 100% Free - Ad Supported
                  const AdFreeMessage(),
                  const SizedBox(height: AppSpacing.lg),

                  // ---- Account ----
                  if (isGuest)
                    _section(
                      title: 'Account',
                      icon: Symbols.account_circle_rounded,
                      tiles: [
                        AppListTile(
                          icon: Symbols.person_add_rounded,
                          iconColor: ext.mark(ext.brand),
                          title: 'Sign in with Google',
                          subtitle: 'Sync your data and access from anywhere',
                          onTap: _isLoading ? null : _handleGoogleSignIn,
                          trailing: _isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        ext.mark(ext.brand)),
                                  ),
                                )
                              : null,
                        ),
                        AppListTile(
                          icon: Symbols.logout_rounded,
                          iconColor: ext.mark(ext.error),
                          title: 'Sign Out',
                          subtitle: 'Return to welcome screen',
                          onTap: _handleSignOut,
                        ),
                      ],
                    )
                  else
                    _section(
                      title: 'Account',
                      icon: Symbols.account_circle_rounded,
                      tiles: [
                        AppListTile(
                          icon: Symbols.person_rounded,
                          iconColor: ext.mark(ext.brand),
                          title: currentUser?.name ?? 'User',
                          subtitle: currentUser?.email ?? '',
                          trailing: const SizedBox.shrink(),
                        ),
                        AppListTile(
                          icon: Symbols.logout_rounded,
                          iconColor: ext.mark(ext.error),
                          title: 'Sign Out',
                          subtitle: "You'll continue as a guest",
                          onTap: _handleSignOut,
                        ),
                      ],
                    ),

                  // ---- Appearance (ONB-5: System / Light / Dark) ----
                  SectionHeader(
                    title: 'Appearance',
                    icon: Symbols.palette_rounded,
                    accent: ext.brand,
                  ),
                  _buildAppearanceCard(),
                  const SizedBox(height: AppSpacing.lg),

                  // ---- DailyMinder Plus ----
                  _section(
                    title: 'Upgrade',
                    icon: Symbols.workspace_premium_rounded,
                    tiles: [
                      AppListTile(
                        icon: Symbols.workspace_premium_rounded,
                        iconColor: ext.mark(ext.brand),
                        title: 'DailyMinder Plus',
                        subtitle: PremiumService.isActive
                            ? 'Active ✓ — thanks for your support'
                            : 'Unlimited meds, reports, caregiver sharing, ad-free',
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const PremiumScreen())),
                      ),
                    ],
                  ),

                  // ---- General ----
                  _section(
                    title: 'General',
                    icon: Symbols.tune_rounded,
                    tiles: [
                      AppListTile(
                        icon: Symbols.notifications_rounded,
                        iconColor: ext.mark(ext.info),
                        title: 'Notifications',
                        subtitle: 'Reminder sounds and timing',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const NotificationSettingsScreen()),
                          );
                        },
                      ),
                      _buildHapticSettingsTile(),
                      _buildVitaVibeSettingsTile(),
                    ],
                  ),

                  // ---- Feature settings ----
                  // One place to reach the per-feature reminder/goal settings
                  // that were previously only reachable from inside each feature.
                  _section(
                    title: 'Feature settings',
                    icon: Symbols.tune_rounded,
                    tiles: [
                      AppListTile(
                        icon: Symbols.water_drop_rounded,
                        iconColor: ext.mark(ext.info),
                        title: 'Water reminders',
                        subtitle: 'Hydration reminder schedule',
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const WaterReminderSettingsScreen())),
                      ),
                      AppListTile(
                        icon: Symbols.bedtime_rounded,
                        iconColor: ext.mark(ext.focus),
                        title: 'Sleep schedule',
                        subtitle: 'Bedtime & wake-up goals',
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const SleepScheduleSettingsScreen())),
                      ),
                      AppListTile(
                        icon: Symbols.directions_walk_rounded,
                        iconColor: ext.mark(ext.success),
                        title: 'Step goal',
                        subtitle: 'Daily step target',
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const StepsGoalSettingsScreen())),
                      ),
                    ],
                  ),

                  // ---- AI Assistant ----
                  // One clear entry. Everything AI — the explainer, Memory, and
                  // Privacy — lives inside AiAssistantScreen; engine/online-AI/key
                  // are hidden developer controls unlocked there (tap version 7×).
                  _section(
                    title: 'Assistant',
                    icon: Symbols.auto_awesome_rounded,
                    tiles: [
                      AppListTile(
                        icon: Symbols.auto_awesome_rounded,
                        iconColor: ext.mark(ext.focus),
                        title: 'AI Assistant',
                        subtitle: 'Private, on-device · memory & data',
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AiAssistantScreen())),
                      ),
                    ],
                  ),

                  // ---- Data ----
                  _section(
                    title: 'Data',
                    icon: Symbols.storage_rounded,
                    tiles: [
                      AppListTile(
                        icon: Symbols.ios_share_rounded,
                        iconColor: ext.mark(ext.success),
                        title: 'Export a copy',
                        subtitle: 'Save a backup file and share it',
                        onTap: _isExporting ? null : _exportCopy,
                        trailing: _isExporting
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      ext.mark(ext.success)),
                                ),
                              )
                            : null,
                      ),
                      AppListTile(
                        icon: Symbols.save_alt_rounded,
                        iconColor: ext.mark(ext.warning),
                        title: 'Backup & Restore',
                        subtitle: 'Export or import your data as a file',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const BackupSettingsScreen()),
                          );
                        },
                      ),
                      AppListTile(
                        icon: Symbols.cloud_upload_rounded,
                        iconColor: ext.mark(ext.info),
                        title: 'Cloud Backup',
                        subtitle: _authService.isAuthenticated
                            ? 'Manage your cloud backups'
                            : 'Sign in to enable cloud backup',
                        onTap: () {
                          if (_authService.isAuthenticated) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const BackupScreen()),
                            );
                          } else {
                            context.toastInfo(
                                'Sign in with Google to enable cloud backup.');
                          }
                        },
                        trailing: _authService.isAuthenticated
                            ? null
                            : Icon(Symbols.lock_rounded,
                                color: ext.textTertiary),
                      ),
                      AppListTile(
                        icon: Symbols.delete_forever_rounded,
                        iconColor: ext.mark(ext.error),
                        title: 'Delete all data',
                        subtitle: 'Permanently erase everything on this device',
                        onTap: _isClearing ? null : _deleteAllData,
                        trailing: _isClearing
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      ext.mark(ext.error)),
                                ),
                              )
                            : null,
                      ),
                    ],
                  ),

                  // ---- About ----
                  _section(
                    title: 'About',
                    icon: Symbols.info_rounded,
                    tiles: [
                      AppListTile(
                        icon: Symbols.info_rounded,
                        iconColor: ext.mark(ext.brand),
                        title: 'About DailyMinder',
                        subtitle: 'Version 1.0.0',
                        onTap: () {
                          showAboutDialog(
                            context: context,
                            applicationName: 'DailyMinder',
                            applicationVersion: '1.0.0',
                            applicationIcon: const AppLogo.mark(size: 44),
                            applicationLegalese: '© 2026 DailyMinder',
                            children: const [
                              SizedBox(height: 12),
                              Text(
                                'DailyMinder is a general wellness and reminder '
                                'tool — not a medical device, and not a source of '
                                'diagnosis or treatment. Always confirm health '
                                'decisions with a qualified clinician or '
                                'pharmacist. In an emergency, contact your local '
                                'emergency services.',
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A titled group: [SectionHeader] + an [AppCard] of divider-separated tiles.
  Widget _section({
    required String title,
    IconData? icon,
    required List<Widget> tiles,
  }) {
    final ext = AppColorsExt.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, icon: icon, accent: ext.brand),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(children: _withDividers(tiles)),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  List<Widget> _withDividers(List<Widget> tiles) {
    final ext = AppColorsExt.of(context);
    final out = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      out.add(tiles[i]);
      if (i < tiles.length - 1) {
        out.add(Divider(
          height: 1,
          indent: 52,
          endIndent: 8,
          color: ext.outline,
        ));
      }
    }
    return out;
  }

  Widget _buildAppearanceCard() {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final settings = CleanStorageService.getUserSettings();
    final pref = settings.themeModePreference;
    final index = pref == 'light' ? 1 : (pref == 'dark' ? 2 : 0);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ext.brand.base.withOpacity(0.12),
                  borderRadius: AppRadius.brSm,
                ),
                child: Icon(Symbols.palette_rounded,
                    size: 20, color: ext.mark(ext.brand)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Theme', style: tt.titleLarge),
                    const SizedBox(height: 2),
                    Text('Choose how DailyMinder looks',
                        style: tt.bodyMedium
                            ?.copyWith(color: ext.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SegmentedToggle(
            index: index,
            accent: ext.brand,
            items: const [
              SegmentItem(icon: Symbols.brightness_auto_rounded, label: 'System'),
              SegmentItem(icon: Symbols.light_mode_rounded, label: 'Light'),
              SegmentItem(icon: Symbols.dark_mode_rounded, label: 'Dark'),
            ],
            onChanged: (i) async {
              _hapticService.tap();
              final newPref = i == 1 ? 'light' : (i == 2 ? 'dark' : 'system');
              final updated = settings.copyWith(
                themeModePreference: newPref,
                darkModeEnabled: newPref == 'dark',
              );
              await CleanStorageService.saveUserSettings(updated);
              // Instantly rebuild MaterialApp with the new mode.
              themeModeNotifier.value = themeModeFromPreference(newPref);
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHapticSettingsTile() {
    return ListenableBuilder(
      listenable: _hapticService,
      builder: (context, _) {
        final ext = AppColorsExt.of(context);
        return AppListTile(
          icon: Symbols.vibration_rounded,
          iconColor: ext.mark(ext.brand),
          title: 'Haptic Feedback',
          subtitle: _hapticService.isEnabled
              ? 'Enabled • ${_getIntensityLabel(_hapticService.globalIntensity)}'
              : 'Disabled',
          onTap: () {
            _hapticService.tap();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HapticSettingsScreen()),
            );
          },
          trailing: AppSwitch(
            value: _hapticService.isEnabled,
            onChanged: (value) async {
              await _hapticService.setEnabled(value);
              setState(() {});
            },
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
        final ext = AppColorsExt.of(context);
        final tt = Theme.of(context).textTheme;
        return AppListTile(
          icon: Symbols.vibration_rounded,
          iconColor: ext.mark(ext.success),
          title: 'Haptix',
          subtitle: _vitaVibeService.isEnabled
              ? 'Advanced haptic patterns enabled'
              : 'Advanced vibration patterns',
          onTap: () {
            _vitaVibeService.tap();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VitaVibeSettingsScreen()),
            );
          },
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: ext.success.container,
                  borderRadius: AppRadius.brFull,
                ),
                child: Text(
                  'FREE',
                  style: tt.labelSmall?.copyWith(
                    color: ext.success.onContainer,
                    fontWeight: FontWeight.w800,
                    fontSize: 9,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AppSwitch(
                value: _vitaVibeService.isEnabled,
                onChanged: (value) async {
                  await _vitaVibeService.setEnabled(value);
                  setState(() {});
                },
              ),
            ],
          ),
        );
      },
    );
  }

}
