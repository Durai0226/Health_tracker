
import 'package:flutter/material.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/services/llm_service.dart';
import '../../../core/ai/ai_assistant.dart';
import '../../../core/ai/ai_types.dart';
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
    final ext = AppColorsExt.of(context);
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Successfully signed in with Google!'),
          backgroundColor: ext.fillBg(ext.success),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
          margin: const EdgeInsets.all(16),
        ),
      );
    } else if (result != 'cancelled') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result),
          backgroundColor: ext.fillBg(ext.error),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
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
      icon: Icons.delete_forever_rounded,
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
    final ext = AppColorsExt.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ext.fillBg(isError ? ext.error : ext.success),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
        margin: const EdgeInsets.all(16),
      ),
    );
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
                      icon: Icons.account_circle_outlined,
                      tiles: [
                        AppListTile(
                          icon: Icons.person_add_rounded,
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
                          icon: Icons.logout_rounded,
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
                      icon: Icons.account_circle_outlined,
                      tiles: [
                        AppListTile(
                          icon: Icons.person_rounded,
                          iconColor: ext.mark(ext.brand),
                          title: currentUser?.name ?? 'User',
                          subtitle: currentUser?.email ?? '',
                          trailing: const SizedBox.shrink(),
                        ),
                        AppListTile(
                          icon: Icons.logout_rounded,
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
                    icon: Icons.palette_outlined,
                    accent: ext.brand,
                  ),
                  _buildAppearanceCard(),
                  const SizedBox(height: AppSpacing.lg),

                  // ---- General ----
                  _section(
                    title: 'General',
                    icon: Icons.tune_rounded,
                    tiles: [
                      AppListTile(
                        icon: Icons.notifications_outlined,
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

                  // ---- AI Assistant ----
                  _section(
                    title: 'AI Assistant',
                    icon: Icons.auto_awesome_rounded,
                    tiles: [
                      AppListTile(
                        icon: Icons.auto_awesome_rounded,
                        iconColor: ext.mark(ext.focus),
                        title: 'AI Assistant',
                        subtitle:
                            'On-device AI is on (free). Tap to manage cloud AI.\n'
                            'Active: ${_activeEngineLabel()}',
                        onTap: _manageAiKey,
                      ),
                      AppListTile(
                        icon: Icons.cloud_outlined,
                        iconColor: ext.mark(ext.info),
                        title: 'Use cloud AI (optional)',
                        subtitle:
                            'Off by default. Uses a cloud model for richer answers '
                            '— sends data off-device; needs a key (dev/beta).',
                        trailing: Switch(
                          value: AiAssistant().cloudConsent,
                          onChanged: (value) async {
                            await AiAssistant().setCloudConsent(value);
                            if (mounted) setState(() {});
                          },
                        ),
                      ),
                    ],
                  ),

                  // ---- Data ----
                  _section(
                    title: 'Data',
                    icon: Icons.storage_rounded,
                    tiles: [
                      AppListTile(
                        icon: Icons.ios_share_rounded,
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
                        icon: Icons.save_alt_rounded,
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
                        icon: Icons.cloud_upload_outlined,
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Sign in with Google to enable cloud backup.'),
                              ),
                            );
                          }
                        },
                        trailing: _authService.isAuthenticated
                            ? null
                            : Icon(Icons.lock_outline_rounded,
                                color: ext.textTertiary),
                      ),
                      AppListTile(
                        icon: Icons.delete_forever_rounded,
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
                    icon: Icons.info_outline_rounded,
                    tiles: [
                      AppListTile(
                        icon: Icons.info_outline_rounded,
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

  /// Human-readable label for the engine that will serve AI requests now.
  String _activeEngineLabel() {
    switch (AiAssistant().activeKind) {
      case AiEngineKind.cloud:
        return 'Cloud';
      case AiEngineKind.onDevice:
        return 'On-device';
      case AiEngineKind.ruleBased:
        return 'On-device';
    }
  }

  /// Manage the AI (LLM) API key — paste/remove, stored on-device only.
  Future<void> _manageAiKey() async {
    final ext = AppColorsExt.of(context);
    final controller = TextEditingController();
    await AppBottomSheet.show<void>(
      context,
      title: 'AI Assistant',
      icon: Icons.auto_awesome_rounded,
      accent: ext.focus,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Enable AI to smart-add reminders, explain medicines, and get '
            'hydration & focus tips. Paste a free NVIDIA API key from '
            'build.nvidia.com to turn it on.',
            style: Theme.of(ctx)
                .textTheme
                .bodyMedium
                ?.copyWith(color: ext.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: controller,
            label: 'API key',
            hint: 'nvapi-…',
            accent: ext.focus,
            obscureText: true,
            prefixIcon: Icons.key_rounded,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Save key',
            accent: ext.focus,
            fullWidth: true,
            onPressed: () async {
              await LlmService().setApiKey(controller.text);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) setState(() {});
            },
          ),
          if (LlmService().isConfigured) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Remove key',
              variant: AppButtonVariant.ghost,
              accent: ext.error,
              fullWidth: true,
              onPressed: () async {
                await LlmService().clearApiKey();
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) setState(() {});
              },
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            'Beta: the key is stored on this device only, for development/testing. '
            'The free NVIDIA tier is not licensed for production use.',
            style: Theme.of(ctx)
                .textTheme
                .bodySmall
                ?.copyWith(color: ext.textTertiary),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
    controller.dispose();
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
                child: Icon(Icons.palette_rounded,
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
              SegmentItem(icon: Icons.brightness_auto_rounded, label: 'System'),
              SegmentItem(icon: Icons.light_mode_rounded, label: 'Light'),
              SegmentItem(icon: Icons.dark_mode_rounded, label: 'Dark'),
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
          icon: Icons.vibration_rounded,
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
          trailing: Switch(
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
          icon: Icons.vibration_rounded,
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
              Switch(
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
