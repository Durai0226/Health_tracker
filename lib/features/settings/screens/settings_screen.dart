
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/storage_service.dart';
import '../../period_tracking/screens/period_intro_screen.dart';
import '../../period_tracking/screens/period_overview_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isPeriodEnabled = StorageService.isPeriodTrackingEnabled;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text("Settings"),
      ),
      body: ListView(
        padding: EdgeInsets.all(24),
        children: [
          _buildSection(
            context,
            title: "General",
            children: [
              _buildSettingsTile(
                context,
                icon: Icons.medication_outlined,
                iconColor: AppColors.primary,
                title: "Manage Medicines",
                subtitle: "View and edit your medications",
                onTap: () => Navigator.of(context).pop(),
              ),
              _buildSettingsTile(
                context,
                icon: Icons.notifications_outlined,
                iconColor: AppColors.info,
                title: "Notifications",
                subtitle: "Reminder sounds and timing",
                onTap: () {},
              ),
            ],
          ),
          SizedBox(height: 24),
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
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
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
          SizedBox(height: 24),
          _buildSection(
            context,
            title: "Data",
            children: [
              _buildSettingsTile(
                context,
                icon: Icons.cloud_upload_outlined,
                iconColor: AppColors.warning,
                title: "Backup Data",
                subtitle: "Coming soon",
                onTap: () {},
                enabled: false,
              ),
            ],
          ),
          SizedBox(height: 24),
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

  Widget _buildSection(BuildContext context, {required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(children: children),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: enabled ? AppColors.textPrimary : AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              trailing ?? Icon(Icons.chevron_right_rounded, color: AppColors.divider),
            ],
          ),
        ),
      ),
    );
  }
}
