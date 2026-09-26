
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/widgets/confirmation_bottom_sheet.dart';
import '../../../core/services/backup_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  /// The two destructive confirmations, hoisted out of the [State] so a widget
  /// test can drive the real sheets: the screen itself cannot be pumped
  /// headlessly, because [BackupService] resolves `FirebaseFirestore.instance`
  /// in its constructor and `flutter test` has no Firebase app.
  ///
  /// Each collapses the sheet's `bool?` exactly as the `AlertDialog` it
  /// replaced did — a dismissed sheet returns null, and null is not consent.
  @visibleForTesting
  static Future<bool> confirmRestore(BuildContext context) async {
    final confirm = await ConfirmationBottomSheet.show(
      context: context,
      title: 'Restore Backup?',
      message:
          'This will OVERWRITE all current data on this device with the backup data. This action cannot be undone. Are you sure?',
      confirmText: 'Restore',
      icon: Symbols.restore_rounded,
      isDangerous: true,
    );
    return confirm == true;
  }

  /// What to show when [BackupService.createBackup] throws.
  ///
  /// Its three refusals — no real account, cloud sync off, and an export over
  /// `maxBackupPayloadBytes` — are `StateError`s written FOR the user, and
  /// `'Failed to create backup: $e'` wrecked all three: `$e` on a `StateError`
  /// renders as "Bad state: ...", so 36 characters of prefix went in front of
  /// a sentence `AppToast` then clipped at two lines and an ellipsis. The
  /// clause telling the user what to do about it was always the part that got
  /// cut. Anything else is a genuinely unexpected failure and keeps the prefix
  /// naming the operation that failed.
  ///
  /// Static for the same reason the two confirmations above are — see the note
  /// on [confirmRestore].
  @visibleForTesting
  static String failureMessage(Object error) =>
      error is StateError ? error.message : 'Failed to create backup: $error';

  @visibleForTesting
  static Future<bool> confirmDelete(BuildContext context) async {
    final confirm = await ConfirmationBottomSheet.showDelete(
      context: context,
      itemName: 'Backup',
      customMessage: 'Are you sure you want to delete this backup?',
    );
    return confirm == true;
  }

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final BackupService _backupService = BackupService();
  bool _isLoading = false;
  List<BackupModel> _backups = [];

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    setState(() => _isLoading = true);
    try {
      final backups = await _backupService.getBackups();
      setState(() => _backups = backups);
    } catch (e) {
      _showError('Failed to load backups: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createBackup() async {
    setState(() => _isLoading = true);
    try {
      await _backupService.createBackup();
      if (!mounted) return;
      context.toastSuccess('Backup created successfully');
      _loadBackups();
    } catch (e) {
      _showError(BackupScreen.failureMessage(e));
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreBackup(BackupModel backup) async {
    if (!await BackupScreen.confirmRestore(context)) return;

    setState(() => _isLoading = true);
    try {
      await _backupService.restoreBackup(backup.id);
      if (!mounted) return;
      context.toastSuccess('Backup restored successfully');
      // Maybe navigate to home or restart app logic?
      // Navigator.pop(context); // Optional
    } catch (e) {
      _showError('Failed to restore backup: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteBackup(BackupModel backup) async {
    if (!await BackupScreen.confirmDelete(context)) return;

    setState(() => _isLoading = true);
    try {
      await _backupService.deleteBackup(backup.id);
      if (!mounted) return;
      context.toastSuccess('Backup deleted successfully');
      _loadBackups();
    } catch (e) {
      _showError('Failed to delete backup: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    context.toastError(message);
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
              child: _isLoading ? _buildLoading(ext) : _buildContent(ext),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading(AppColorsExt ext) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, 40),
      children: const [
        LoadingSkeleton.card(),
        SizedBox(height: AppSpacing.lg),
        LoadingSkeleton.card(),
        SizedBox(height: AppSpacing.md),
        LoadingSkeleton.card(),
      ],
    );
  }

  Widget _buildContent(AppColorsExt ext) {
    final tt = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, 40),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create backups of your data (Reminders, Health, etc.) to the cloud. Restoring will overwrite current local data.',
                style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Create New Backup',
                leadingIcon: Symbols.cloud_upload_rounded,
                accent: ext.brand,
                fullWidth: true,
                onPressed: _createBackup,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_backups.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxl),
            child: EmptyState(
              icon: Symbols.cloud_off_rounded,
              title: 'No backups found',
              message: 'Create your first cloud backup to keep your data safe.',
              accent: ext.brand,
            ),
          )
        else
          ..._backups.map((backup) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                  child: AppListTile(
                    icon: Symbols.history_rounded,
                    iconColor: ext.mark(ext.brand),
                    title: DateFormat('MMM d, y • h:mm a')
                        .format(backup.createdAt),
                    subtitle:
                        '${(backup.sizeBytes / 1024).toStringAsFixed(1)} KB • ${backup.deviceName}',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Symbols.restore_rounded,
                              color: ext.textPrimary),
                          onPressed: () => _restoreBackup(backup),
                          tooltip: 'Restore',
                        ),
                        IconButton(
                          icon: Icon(Symbols.delete_rounded,
                              color: ext.mark(ext.error)),
                          onPressed: () => _deleteBackup(backup),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  ),
                ),
              )),
      ],
    );
  }
}
