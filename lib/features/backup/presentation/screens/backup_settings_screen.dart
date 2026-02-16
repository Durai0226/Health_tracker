import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../services/backup_service.dart';
import 'package:share_plus/share_plus.dart';

class BackupSettingsScreen extends StatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  final _backupService = BackupService();
  bool _isLoading = false;

  Future<void> _createBackup() async {
    setState(() => _isLoading = true);
    
    try {
      final file = await _backupService.createBackup();
      if (file != null) {
        if (mounted) {
          // Offer to share immediately
          await _backupService.shareBackup(file);
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Backup created successfully!')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to create backup')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreBackup() async {
    // Confirm first - this is destructive
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Backup?'),
        content: const Text(
          'WARNING: This will overwrite ALL current data with the backup file. '
          'Any changes not in the backup will be lost forever.\n\n'
          'Locked notes will require the encryption key from the device that created them to be readable.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore & Overwrite'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    
    try {
      final success = await _backupService.restoreBackup();
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Data restored successfully! Please restart the app.')),
          );
        }
      } 
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Backup & Recovery'),
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionHeader('Backup'),
              _buildCard(
                icon: Icons.cloud_upload_outlined,
                title: 'Create Backup',
                subtitle: 'Export your notes, folders, and tags to a file.',
                onTap: _createBackup,
              ),
              const SizedBox(height: 24),
              _buildSectionHeader('Restore'),
              _buildCard(
                icon: Icons.restore_page_outlined,
                title: 'Restore Data',
                subtitle: 'Import data from a backup file. Warning: Overwrites current data.',
                isDestructive: true,
                onTap: _restoreBackup,
              ),
              const SizedBox(height: 24),
              const Card(
                color: Color(0xFFFFF3E0), // Warning orange tint
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          "Important: Locked notes are encrypted. To read them after restoring on a new device, ensures you have the same security setup (biometrics/pin) or they may remain inaccessible.",
                          style: TextStyle(fontSize: 12, color: Colors.brown),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
        ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDestructive ? AppColors.error.withOpacity(0.1) : AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isDestructive ? AppColors.error : AppColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDestructive ? AppColors.error : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
