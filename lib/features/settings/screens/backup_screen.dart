
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
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
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createBackup() async {
    setState(() => _isLoading = true);
    try {
      await _backupService.createBackup();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup created successfully')),
      );
      _loadBackups();
    } catch (e) {
      _showError('Failed to create backup: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreBackup(BackupModel backup) async {
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
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup restored successfully')),
      );
      // Maybe navigate to home or restart app logic?
      // Navigator.pop(context); // Optional
    } catch (e) {
      _showError('Failed to restore backup: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
    Future<void> _deleteBackup(BackupModel backup) async {
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
             style: TextButton.styleFrom(foregroundColor: AppColors.error),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup deleted successfully')),
      );
      _loadBackups();
    } catch (e) {
      _showError('Failed to delete backup: $e');
      setState(() => _isLoading = false);
    }
  }


  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Backup & Restore'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: AppColors.surface,
                  child: Column(
                    children: [
                      const Text(
                        'Create backups of your data (Reminders, Health, etc.) to the cloud. Restoring will overwrite current local data.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _createBackup,
                          icon: const Icon(Icons.cloud_upload_outlined),
                          label: const Text('Create New Backup'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _backups.isEmpty
                      ? const Center(child: Text('No backups found'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _backups.length,
                          itemBuilder: (context, index) {
                            final backup = _backups[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                leading: const Icon(Icons.history, color: AppColors.primary),
                                title: Text(
                                  DateFormat('MMM d, y • h:mm a').format(backup.createdAt),
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  '${(backup.sizeBytes / 1024).toStringAsFixed(1)} KB • ${backup.deviceName}',
                                ),
                                trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                        IconButton(
                                            icon: const Icon(Icons.restore, color: AppColors.textPrimary),
                                            onPressed: () => _restoreBackup(backup),
                                            tooltip: 'Restore',
                                        ),
                                        IconButton(
                                            icon: const Icon(Icons.delete_outline, color: AppColors.error),
                                            onPressed: () => _deleteBackup(backup),
                                            tooltip: 'Delete',
                                        ),
                                    ]
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
