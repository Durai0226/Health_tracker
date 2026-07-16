import 'package:flutter/material.dart';
import '../../../../core/widgets/app/app_widgets.dart';
import '../../../../core/widgets/confirmation_bottom_sheet.dart';
import '../../services/backup_service.dart';

/// Calm Clarity, dark-aware Backup & Restore screen.
///
/// Backup: builds a ZIP snapshot and opens the system share sheet.
/// Restore: picks a ZIP and merges it (destructive-overwrite warning shown).
/// Every action reports a success OR error SnackBar; a user-canceled restore
/// reports a neutral "canceled" message rather than silently doing nothing.
class BackupSettingsScreen extends StatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  final _backupService = BackupService();
  bool _isBackingUp = false;
  bool _isRestoring = false;

  bool get _busy => _isBackingUp || _isRestoring;

  void _snack(String message, {required bool isError, bool neutral = false}) {
    if (!mounted) return;
    final ext = AppColorsExt.of(context);
    final swatch = neutral ? ext.info : (isError ? ext.error : ext.success);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ext.fillBg(swatch),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _createBackup() async {
    if (_busy) return;
    setState(() => _isBackingUp = true);
    try {
      final file = await _backupService.createBackup();
      if (!mounted) return;
      if (file != null) {
        await _backupService.shareBackup(file);
        if (!mounted) return;
        _snack('Backup ready to share.', isError: false);
      } else {
        _snack('Could not create the backup file.', isError: true);
      }
    } catch (e) {
      if (mounted) _snack('Backup failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  Future<void> _restoreBackup() async {
    if (_busy) return;

    final confirmed = await ConfirmationBottomSheet.show(
      context: context,
      title: 'Restore backup?',
      message:
          'This overwrites current data with the backup file. Any changes not '
          'in the backup will be lost. Locked notes need the encryption key '
          'from the device that created them to be readable.',
      confirmText: 'Restore & overwrite',
      icon: Icons.restore_page_rounded,
      isDangerous: true,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isRestoring = true);
    try {
      final restored = await _backupService.restoreBackup();
      if (!mounted) return;
      if (restored) {
        _snack('Data restored. Please restart the app.', isError: false);
      } else {
        // false == user canceled the file picker (not an error).
        _snack('Restore canceled.', isError: false, neutral: true);
      }
    } catch (e) {
      if (mounted) _snack('Restore failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    return AccentScope(
      feature: FeatureAccent.brand,
      child: AppScaffold(
        body: Column(
          children: [
            AppHeader(
              title: 'Backup & Restore',
              accent: ext.brand,
              leading: AppIconButton(
                icon: Icons.arrow_back_rounded,
                filled: false,
                accent: ext.brand,
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, 40),
                children: [
                  SectionHeader(
                    title: 'Backup',
                    icon: Icons.cloud_upload_outlined,
                    accent: ext.success,
                  ),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _rowHeader(
                          icon: Icons.cloud_upload_outlined,
                          title: 'Create backup',
                          subtitle:
                              'Export your data to a file and share it anywhere.',
                          swatch: ext.success,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppButton(
                          label: 'Create backup',
                          leadingIcon: Icons.ios_share_rounded,
                          accent: ext.success,
                          fullWidth: true,
                          loading: _isBackingUp,
                          onPressed: _busy ? null : _createBackup,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SectionHeader(
                    title: 'Restore',
                    icon: Icons.restore_page_outlined,
                    accent: ext.warning,
                  ),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _rowHeader(
                          icon: Icons.restore_page_outlined,
                          title: 'Restore data',
                          subtitle:
                              'Import data from a backup file. This overwrites '
                              'current data.',
                          swatch: ext.warning,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppButton(
                          label: 'Restore from file',
                          leadingIcon: Icons.folder_open_rounded,
                          accent: ext.warning,
                          variant: AppButtonVariant.tonal,
                          fullWidth: true,
                          loading: _isRestoring,
                          onPressed: _busy ? null : _restoreBackup,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _infoBanner(ext),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required AccentSwatch swatch,
  }) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: swatch.container,
            borderRadius: AppRadius.brMd,
          ),
          child: Icon(icon, size: 22, color: swatch.onContainer),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: tt.titleMedium),
              const SizedBox(height: 3),
              Text(subtitle,
                  style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoBanner(AppColorsExt ext) {
    final tt = Theme.of(context).textTheme;
    return AppCard(
      color: ext.warning.container,
      pressEffect: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 20, color: ext.warning.onContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Locked notes are encrypted. To read them after restoring on a '
              'new device, use the same security setup (biometrics/PIN) or they '
              'may remain inaccessible.',
              style: tt.bodySmall?.copyWith(color: ext.warning.onContainer),
            ),
          ),
        ],
      ),
    );
  }
}
