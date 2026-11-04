import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/services/clean_storage_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/delete_all_data.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/confirmation_bottom_sheet.dart';
import 'notification_settings_screen.dart';
import 'haptic_settings_screen.dart';
import 'backup_screen.dart';
import '../../backup/presentation/screens/backup_settings_screen.dart';
import '../../backup/presentation/backup_exporting.dart';
import '../../sleep/screens/sleep_schedule_settings_screen.dart';
import '../../steps/screens/steps_goal_settings_screen.dart';
import '../../water/screens/water_reminder_settings_screen.dart';
import '../../period/screens/period_reminder_settings_screen.dart';
import '../../medication/screens/vitals/vitals_reminder_settings_screen.dart';
import '../../medication/screens/conditions/condition_library_screen.dart';
import 'reminders_hub_screen.dart';
import '../../medication/screens/dependents/dependent_list_screen.dart';
import '../../home/screens/emergency_card_screen.dart';
import 'security_settings_screen.dart';
import 'health_privacy_screen.dart';
import '../../backup/services/backup_service.dart' as local_backup;
import '../../../main.dart';
import '../../../widgets/smart_ad_widgets.dart';
import '../widgets/delete_all_choice_sheet.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/cloud_sync_runner.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.backupService});

  /// Replaces the real file-backup service, which writes to a temp directory and
  /// opens the share sheet. A test hands its own.
  final local_backup.BackupService? backupService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with BackupExporting<SettingsScreen> {
  final _authService = AuthService();
  bool _cloudSyncEnabled = CleanStorageService.cloudSyncEnabled;
  final _hapticService = HapticService();
  late final local_backup.BackupService _localBackupService =
      widget.backupService ?? const local_backup.BackupService();
  bool _isLoading = false;
  bool _isExporting = false;
  bool _isClearing = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    final result = await _authService.signInWithGoogle();
    // Before the setState, not after it. Sign-in takes seconds and leaves the
    // app for the account picker; a user who backs out of Settings meanwhile
    // disposes this State, and setState() on a defunct State throws.
    if (!mounted) return;
    setState(() => _isLoading = false);

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
      if (!mounted) return;
      // Signing out switched cloud sync off underneath this screen, which read the
      // switch once when it was built. It used to be hidden by the screen being
      // replaced; now it stays, and would go on showing sync ON — and, signed back in,
      // nothing would sync until it was turned off and on.
      setState(() => _cloudSyncEnabled = CleanStorageService.cloudSyncEnabled);
      // Stay where they are. This used to push the WelcomeScreen — the first-run
      // onboarding, with "Get started" and "Turn on reminders" — over someone who
      // had been using the app for months. Signing out ends the cloud account and
      // switches sync off; the data on this phone stays, and so does the app, and
      // this screen shows the signed-out state (with Sign in) on its own.
      context.toastSuccess(
          'Signed out. Your data stays on this phone, and cloud sync is off.');
    }
  }

  // "Export a copy": builds the local ZIP backup and opens the system share sheet
  // so the user can save it anywhere. The flow itself is [BackupExporting]'s; this
  // screen says how it is busy and how it speaks.
  @override
  local_backup.BackupService get exportService => _localBackupService;

  @override
  bool get exportBusy => _isExporting;

  @override
  void setExportBusy(bool busy) => setState(() => _isExporting = busy);

  @override
  void reportExport(String message, {required bool isError}) =>
      _showResultSnack(message, isError: isError);

  @override
  String get exportFailureLead => 'Export failed';

  @override
  void exportStarted() => _hapticService.tap();

  /// Destructive "Delete all data": confirmation-guarded wipe of the four core
  /// features. Deletes the kept Drift rows and focus preferences, then routes
  /// the UI back to a clean state.
  /// Deletes the cloud account AND everything on this device.
  ///
  /// Distinct from [_deleteAllData], which only ever wiped local Drift rows —
  /// it left `users/{uid}`, the backups subcollection (each holding a full
  /// health export) and the Firebase Auth account itself alive. Google Play
  /// has required a real in-app deletion path since 2024.
  Future<void> _deleteAccountAndData() async {
    final confirm = await ConfirmationBottomSheet.show(
      context: context,
      title: 'Delete your account?',
      message:
          'This deletes your account and every copy of your health data — on '
          'this device and in the cloud, including any backups. It cannot be '
          'undone and it cannot be recovered by support. Export a copy first '
          'if you want to keep your records.',
      confirmText: 'Delete my account',
      icon: Symbols.person_remove_rounded,
      isDangerous: true,
    );
    if (confirm != true || !mounted) return;

    setState(() => _isClearing = true);
    try {
      // Cloud first: if the local wipe ran first and the cloud step then
      // failed, the user would be left believing everything was gone while a
      // full copy of their health record survived on Google's servers.
      final error = await _deleteAccountConfirmingIdentity();
      if (error != null) {
        // The account is intact, and the message says why. A person who declined to
        // sign in again, or closed the Google sheet, stopped it themselves: that is
        // said plainly, not in the red of something that went wrong.
        if (mounted) {
          _showResultSnack(error, isError: error != AuthService.reauthRequiredMessage);
        }
        return;
      }
      await CleanStorageService.clearAllData();
      await CleanStorageService.clearAllPersistentData();
      if (!mounted) return;
      _showResultSnack('Account and all data deleted.', isError: false);
    } catch (e) {
      if (mounted) _showResultSnack('Delete failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  /// [AuthService.deleteAccount] — and when the sign-in is too old for Firebase to
  /// accept a deletion, ask the person to confirm it is them right here and carry
  /// on, instead of telling them to sign out, sign in and find their way back.
  ///
  /// Asking now costs nothing: the refusal is decided before anything is deleted,
  /// so nothing has happened yet. Declining, closing the Google sheet or failing
  /// to confirm all end with the account intact and a message saying why. After a
  /// successful confirmation it tries once more and no more — a loop on a session
  /// Firebase keeps calling stale would be worse than the message.
  Future<String?> _deleteAccountConfirmingIdentity() async {
    final first = await AuthService().deleteAccount();
    if (first != AuthService.reauthRequiredMessage || !mounted) return first;

    final signInAgain = await ConfirmationBottomSheet.show(
      context: context,
      title: 'Confirm it is you',
      message: 'For your security, sign in with Google again before your account '
          'is deleted. Nothing has been deleted yet.',
      confirmText: 'Sign in again',
      icon: Symbols.verified_user_rounded,
    );
    if (signInAgain != true) return first;

    final confirmed = await AuthService().reauthenticate();
    if (confirmed == 'cancelled') return first;
    if (confirmed != null) return confirmed;
    return AuthService().deleteAccount();
  }

  Future<void> _deleteAllData() async {
    // With cloud sync on, a wipe that leaves the sync switched on is undone at the
    // next start: the sync brings the cloud copy straight back. So the question
    // is how far to go, not just whether.
    final cloudAtStake = DeleteAllData.cloudCopyAtStake(
      syncOn: CleanStorageService.cloudSyncEnabled,
      signedIn: _authService.isAuthenticated,
    );
    final scope = cloudAtStake
        ? await DeleteAllChoiceSheet.show(context)
        : await _confirmDeviceOnlyDelete();
    if (scope == null || !mounted) return;

    setState(() => _isClearing = true);
    try {
      final error = await DeleteAllData.run(
        scope: scope,
        cloudCopyAtStake: cloudAtStake,
        deleteCloudCopy: _authService.deleteCloudCopy,
        turnSyncOff: () => CleanStorageService.setCloudSyncEnabled(false),
        wipeLocal: _wipeLocal,
      );
      if (!mounted) return;
      if (error != null) {
        _showResultSnack(error, isError: true);
        return;
      }
      _showResultSnack(
          DeleteAllData.doneMessage(scope: scope, cloudCopyAtStake: cloudAtStake),
          isError: false);
    } catch (e) {
      if (mounted) _showResultSnack('Delete failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  /// The plain confirmation, for a device with no cloud copy to deal with.
  Future<DeleteAllScope?> _confirmDeviceOnlyDelete() async {
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
    return confirm == true ? DeleteAllScope.deviceOnly : null;
  }

  /// Clears the in-memory caches, then the persistent Drift rows / focus prefs.
  Future<void> _wipeLocal() async {
    await CleanStorageService.clearAllData();
    await CleanStorageService.clearAllPersistentData();
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
            AppHeader(title: 'Settings'),
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
                          subtitle: 'Your data stays on this phone',
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
                          // No `trailing: SizedBox.shrink()` any more. It was
                          // there only to suppress a chevron the row got by
                          // default; the chevron is now gated on `onTap`, and
                          // this row has none. The three remaining uses of the
                          // workaround are radio-style rows that ARE
                          // interactive and deliberately arrow-free, so theirs
                          // is still doing real work.
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

                  // ---- Family & caregivers ----
                  _section(
                    title: 'Family & caregivers',
                    icon: Symbols.group_rounded,
                    tiles: [
                      AppListTile(
                        icon: Symbols.group_rounded,
                        iconColor: ext.mark(ext.medicine),
                        title: 'Family & caregivers',
                        subtitle: 'Track medicines for the people you care for',
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const DependentListScreen())),
                      ),
                      AppListTile(
                        icon: Symbols.medical_information_rounded,
                        iconColor: ext.mark(ext.error),
                        title: 'Emergency card',
                        subtitle: 'Allergies, medicines and who to call',
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const EmergencyCardScreen())),
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
                        icon: Symbols.notifications_active_rounded,
                        iconColor: ext.mark(ext.reminders),
                        title: 'All reminders',
                        subtitle: 'Every feature\'s nudges in one place',
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const RemindersHubScreen())),
                      ),
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
                      AppListTile(
                        icon: Symbols.calendar_month_rounded,
                        iconColor: ext.mark(ext.period),
                        title: 'Period reminders',
                        subtitle: 'Cycle heads-ups & log nudges',
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const PeriodReminderSettingsScreen())),
                      ),
                      AppListTile(
                        icon: Symbols.favorite_rounded,
                        iconColor: ext.mark(ext.medicine),
                        title: 'Vitals reminders',
                        subtitle: 'Blood pressure, blood sugar, weight & mood checks',
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const VitalsReminderSettingsScreen())),
                      ),
                      AppListTile(
                        icon: Symbols.menu_book_rounded,
                        iconColor: ext.mark(ext.medicine),
                        title: 'Condition library',
                        subtitle: 'General reference for common conditions',
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ConditionLibraryScreen())),
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
                        onTap: _isExporting ? null : () => exportBackup(),
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
                        icon: Symbols.lock_rounded,
                        iconColor: ext.mark(ext.success),
                        title: 'Export an encrypted copy',
                        subtitle: 'Protected with a passphrase you choose',
                        onTap: _isExporting ? null : () => exportBackup(encrypted: true),
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
                      // The single gate on health data leaving the device.
                      // Default OFF: the app tells users their data stays on
                      // their phone, so nothing uploads until they say so here.
                      AppListTile(
                        icon: Symbols.sync_rounded,
                        iconColor: ext.mark(ext.info),
                        title: 'Cloud sync',
                        subtitle: _cloudSyncEnabled
                            ? 'Medicines, water and health data sync to your account'
                            : 'Off — your data stays on this device',
                        switchValue: _cloudSyncEnabled,
                        onSwitchChanged: (v) async {
                          if (v && !_authService.isAuthenticated) {
                            context.toastInfo(
                                'Sign in with Google to turn on cloud sync.');
                            return;
                          }
                          await CleanStorageService.setCloudSyncEnabled(v);
                          if (!mounted) return;
                          setState(() => _cloudSyncEnabled = v);
                          // Switching it on used to do nothing until the app was
                          // next started. Start now, in the background.
                          if (v) unawaited(CloudSyncRunner.maybeSync(force: true));
                          context.toastSuccess(v
                              ? 'Cloud sync on — syncing now'
                              : 'Cloud sync off — data stays on this device');
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
                      // Play requires an in-app account-deletion path, and
                      // "Delete all data" is not one — it only ever wiped local
                      // rows, leaving the cloud copy and the Auth account.
                      if (_authService.isAuthenticated)
                        AppListTile(
                          icon: Symbols.person_remove_rounded,
                          iconColor: ext.mark(ext.error),
                          title: 'Delete account',
                          subtitle:
                              'Erase your account and all cloud copies, including backups',
                          onTap: _isClearing ? null : _deleteAccountAndData,
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

                  // ---- Security ----
                  _section(
                    title: 'Security',
                    icon: Symbols.lock_rounded,
                    tiles: [
                      AppListTile(
                        icon: Symbols.lock_rounded,
                        iconColor: ext.mark(ext.brand),
                        title: 'App lock',
                        subtitle: 'PIN & biometric lock for ${AppStrings.productName}',
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SecuritySettingsScreen())),
                      ),
                    ],
                  ),

                  // ---- About ----
                  _section(
                    title: 'About',
                    icon: Symbols.info_rounded,
                    tiles: [
                      // Play requires a reachable in-app health disclosure, and
                      // this is also where the Health Connect rationale deep
                      // link lands. See HealthPrivacyScreen.
                      AppListTile(
                        icon: Symbols.health_and_safety_rounded,
                        iconColor: ext.mark(ext.brand),
                        title: 'Health data & privacy',
                        subtitle: 'What we read, where it goes, how to revoke',
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const HealthPrivacyScreen())),
                      ),
                      AppListTile(
                        icon: Symbols.info_rounded,
                        iconColor: ext.mark(ext.brand),
                        title: 'About ${AppStrings.productName}',
                        subtitle: 'Version 1.0.0',
                        onTap: () {
                          showAboutDialog(
                            context: context,
                            applicationName: AppStrings.productName,
                            applicationVersion: '1.0.0',
                            applicationIcon: const AppLogo.mark(size: 44),
                            applicationLegalese: '© 2026 ${AppStrings.productName}',
                            children: const [
                              SizedBox(height: 12),
                              Text(
                                '${AppStrings.productName} is a general wellness and reminder '
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
        AppListGroup(children: tiles),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
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
                    Text('Choose how ${AppStrings.productName} looks',
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
          // Navigational only. This row used to push HapticSettingsScreen AND
          // carry a switch, with one InkWell spanning the full width — so a tap
          // aimed at the switch that landed a few points off navigated, and a
          // tap aimed at the row that landed on the switch silently disabled
          // the feature. A row is one affordance.
          //
          // Nothing is lost: HapticSettingsScreen's first row IS this master
          // toggle (`haptic_settings_screen.dart:55`), and the subtitle above
          // already states the status, which is where a status belongs.
          onTap: () {
            _hapticService.tap();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HapticSettingsScreen()),
            );
          },
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

}
