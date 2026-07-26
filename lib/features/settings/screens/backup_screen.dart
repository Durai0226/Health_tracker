
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/services/backup_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

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
      _showError('Failed to create backup: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreBackup(BackupModel backup) async {
    final ext = AppColorsExt.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Backup?'),
        content: const Text(
          'This will OVERWRITE all current data on this device with the backup data. This action cannot be undone. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: ext.error.strong),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

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
    final ext = AppColorsExt.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Backup?'),
        content: const Text(
          'Are you sure you want to delete this backup?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: ext.error.strong),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

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
              accent: ext.brand,
              leading: AppIconButton(
                icon: Symbols.arrow_back_rounded,
                filled: false,
                accent: ext.brand,
                onPressed: () => Navigator.pop(context),
              ),
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
