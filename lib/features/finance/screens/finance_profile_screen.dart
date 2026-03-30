import 'package:flutter/material.dart';
import '../theme/finance_theme.dart';
import '../services/finance_sync_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/confirmation_bottom_sheet.dart';
import '../../onboarding/screens/welcome_screen.dart';
import 'accounts_screen.dart';

/// Finance profile/settings screen
class FinanceProfileScreen extends StatelessWidget {
  const FinanceProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinanceTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(FinanceTheme.spacingM),
          child: Column(
            children: [
              const SizedBox(height: FinanceTheme.spacingL),
              
              // Profile header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello ${AuthService().currentUser?.name ?? 'User'}!',
                          style: FinanceTheme.headingL.copyWith(
                            color: FinanceTheme.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Avatar
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: FinanceTheme.primaryGradient,
                      boxShadow: FinanceTheme.shadowMedium,
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: FinanceTheme.spacingXL),
              
              // Menu items
              _buildMenuItem(
                context,
                icon: Icons.person_outline,
                title: 'Profile Information',
                onTap: () {},
              ),
              _buildMenuItem(
                context,
                icon: Icons.credit_card_outlined,
                title: 'Manage Cards & Account',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AccountsScreen()),
                ),
              ),
              _buildMenuItem(
                context,
                icon: Icons.settings_outlined,
                title: 'Settings',
                onTap: () {},
              ),
              _buildMenuItem(
                context,
                icon: Icons.upload_outlined,
                title: 'Export Data',
                onTap: () => _exportData(context),
              ),
              _buildMenuItem(
                context,
                icon: Icons.sync_outlined,
                title: 'Sync to Cloud',
                onTap: () => _syncToCloud(context),
              ),
              _buildMenuItem(
                context,
                icon: Icons.help_outline,
                title: 'Support',
                onTap: () {},
              ),
              _buildMenuItem(
                context,
                icon: Icons.logout,
                title: 'Logout',
                onTap: () => _showLogoutDialog(context),
                isDestructive: true,
              ),
              
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: FinanceTheme.spacingS),
      child: InkWell(
        onTap: onTap,
        borderRadius: FinanceTheme.borderRadiusM,
        child: Container(
          padding: const EdgeInsets.all(FinanceTheme.spacingM),
          decoration: BoxDecoration(
            color: FinanceTheme.surface,
            borderRadius: FinanceTheme.borderRadiusM,
            boxShadow: FinanceTheme.shadowSoft,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (isDestructive ? FinanceTheme.expense : FinanceTheme.primary)
                      .withValues(alpha: 0.1),
                  borderRadius: FinanceTheme.borderRadiusS,
                ),
                child: Icon(
                  icon,
                  color: isDestructive ? FinanceTheme.expense : FinanceTheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: FinanceTheme.spacingM),
              Expanded(
                child: Text(
                  title,
                  style: FinanceTheme.bodyL.copyWith(
                    color: isDestructive ? FinanceTheme.expense : FinanceTheme.textPrimary,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: FinanceTheme.textLight,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _exportData(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export feature coming soon')),
    );
  }

  Future<void> _syncToCloud(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Syncing to cloud...')),
    );
    
    await FinanceSyncService.syncToCloud();
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sync complete!')),
      );
    }
  }

  void _showLogoutDialog(BuildContext context) async {
    final confirmed = await ConfirmationBottomSheet.showSignOut(context: context);
    
    if (confirmed == true && context.mounted) {
      await AuthService().signOut();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false,
        );
      }
    }
  }
}
