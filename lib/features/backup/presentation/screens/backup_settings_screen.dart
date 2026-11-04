import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../../core/widgets/app/app_widgets.dart';
import '../../../../core/widgets/confirmation_bottom_sheet.dart';
import '../../services/backup_service.dart';
import '../backup_exporting.dart';
import '../widgets/passphrase_sheet.dart';

/// Calm Clarity, dark-aware Backup & Restore screen.
///
/// Backup: builds a ZIP snapshot and opens the system share sheet.
/// Restore: picks a ZIP and merges it (destructive-overwrite warning shown).
/// Every action reports a success OR error toast; a user-canceled restore
/// reports a neutral "canceled" message rather than silently doing nothing.
class BackupSettingsScreen extends StatefulWidget {
  const BackupSettingsScreen({super.key, this.service});

  /// Replaces the real backup service. A test hands its own: the real one writes
  /// to a temp directory and opens the share sheet.
  final BackupService? service;

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen>
    with BackupExporting<BackupSettingsScreen> {
  late final BackupService _backupService = widget.service ?? const BackupService();
  bool _isBackingUp = false;
  bool _isRestoring = false;

  bool get _busy => _isBackingUp || _isRestoring;

  void _snack(String message, {required bool isError, bool neutral = false}) {
    if (!mounted) return;
    if (neutral) {
      context.toastInfo(message);
    } else if (isError) {
      context.toastError(message);
    } else {
      context.toastSuccess(message);
    }
  }

  // The backup flow itself is [BackupExporting]'s; this screen says how it is busy
  // and how it speaks.
  @override
  BackupService get exportService => _backupService;

  @override
  bool get exportBusy => _busy;

  @override
  void setExportBusy(bool busy) => setState(() => _isBackingUp = busy);

  @override
  void reportExport(String message, {required bool isError}) =>
      _snack(message, isError: isError);

  @override
  String get exportFailureLead => 'Backup failed';

  Future<void> _restoreBackup() async {
    if (_busy) return;

    // Describes a MERGE, because that is what happens.
    //
    // `BackupService.restoreBackup` calls
    // `CleanStorageService.restoreBackup(decoded)` and leaves `clearExisting`
    // at its default of false — the service's own comment calls it
    // "Restore (merge)". Nothing already on the device is deleted.
    //
    // The old copy said "This overwrites current data... Any changes not in
    // the backup will be lost", labelled the button "Restore & overwrite" and
    // marked it `isDangerous`. That is a warning about data loss that cannot
    // happen, on the one screen a user reaches when they are already anxious
    // about their data — and the kind of warning that stops someone restoring
    // at all.
    final confirmed = await ConfirmationBottomSheet.show(
      context: context,
      title: 'Restore backup?',
      message:
          'This merges the backup into what is already on this device. '
          'Nothing here is deleted; where the backup has the same entry, its '
          'copy is used.',
      confirmText: 'Restore',
      icon: Symbols.restore_page_rounded,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isRestoring = true);
    try {
      final restored = await _backupService.restoreBackup(
        // An encrypted backup asks for its passphrase, again for as long as it is
        // wrong. Closing the sheet gives up: nothing is restored, nothing fails.
        askPassphrase: ({required bool wrong}) async =>
            mounted ? PassphraseSheet.askExisting(context, wrong: wrong) : null,
      );
      if (!mounted) return;
      if (restored) {
        _snack('Data restored.', isError: false);
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
              leading: AppHeader.backButton(context),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, 40),
                children: [
                  // SB-14 — a file flow must not wear cloud iconography.
                  //
                  // This screen exports to a FILE the user shares themselves;
                  // the cloud one is settings/screens/backup_screen.dart. Both
                  // showed a cloud-upload glyph, so the two entry points were
                  // indistinguishable at a glance — and here the icon
                  // contradicted the subtitle beside it, which already said
                  // "Export your data to a file".
                  SectionHeader(
                    title: 'Backup to a file',
                    icon: Symbols.save_alt_rounded,
                    accent: ext.success,
                  ),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _rowHeader(
                          icon: Symbols.save_alt_rounded,
                          title: 'Create backup',
                          subtitle:
                              'Export your data to a file and share it anywhere.',
                          swatch: ext.success,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppButton(
                          label: 'Create backup',
                          leadingIcon: Symbols.ios_share_rounded,
                          accent: ext.success,
                          fullWidth: true,
                          loading: _isBackingUp,
                          onPressed: _busy ? null : exportBackup,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        // The file holds every record there is, and goes to a share
                        // sheet — an email, a chat, a drive. This is the way to make
                        // that not readable by whoever ends up with it.
                        AppButton(
                          label: 'Create encrypted backup',
                          leadingIcon: Symbols.lock_rounded,
                          accent: ext.success,
                          variant: AppButtonVariant.tonal,
                          fullWidth: true,
                          onPressed: _busy ? null : () => exportBackup(encrypted: true),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Protected with a passphrase you choose. Without it nobody '
                          'can open the file — including you.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: ext.textTertiary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SectionHeader(
                    title: 'Restore',
                    icon: Symbols.restore_page_rounded,
                    accent: ext.warning,
                  ),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _rowHeader(
                          icon: Symbols.restore_page_rounded,
                          title: 'Restore data',
                          subtitle:
                              'Import data from a backup file, encrypted or '
                              'not. Merges with what is already here — nothing '
                              'is deleted.',
                          swatch: ext.warning,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppButton(
                          label: 'Restore from file',
                          leadingIcon: Symbols.folder_open_rounded,
                          accent: ext.warning,
                          variant: AppButtonVariant.tonal,
                          fullWidth: true,
                          loading: _isRestoring,
                          onPressed: _busy ? null : _restoreBackup,
                        ),
                      ],
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

}
