import 'package:flutter/material.dart';
import '../theme/finance_theme.dart';
import '../widgets/finance_widgets.dart';
import '../models/finance_models.dart';
import '../services/finance_service.dart';
import '../../../core/services/auth_service.dart';
import 'transactions_screen.dart';
import 'transaction_detail_screen.dart';
import 'statistics_screen.dart';
import 'savings_goals_screen.dart';

/// Finance home/dashboard screen
class FinanceHomeScreen extends StatefulWidget {
  const FinanceHomeScreen({super.key});

  @override
  State<FinanceHomeScreen> createState() => _FinanceHomeScreenState();
}

class _FinanceHomeScreenState extends State<FinanceHomeScreen> {
  bool _isLoading = true;
  List<FinanceTransaction> _recentTransactions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await FinanceService.init();
    _recentTransactions = FinanceService.getTransactions(limit: 5);
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinanceTheme.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              color: FinanceTheme.primary,
              child: CustomScrollView(
                slivers: [
                  // App Bar
                  SliverAppBar(
                    floating: true,
                    backgroundColor: FinanceTheme.background,
                    elevation: 0,
                    automaticallyImplyLeading: false,
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello ${AuthService().currentUser?.name ?? 'User'}',
                          style: FinanceTheme.bodyS.copyWith(
                            color: FinanceTheme.accent,
                          ),
                        ),
                        Text(
                          'Welcome Back!',
                          style: FinanceTheme.headingL,
                        ),
                      ],
                    ),
                    actions: [
                      IconButton(
                        onPressed: () {},
                        icon: Stack(
                          children: [
                            const Icon(
                              Icons.notifications_outlined,
                              color: FinanceTheme.textPrimary,
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: FinanceTheme.accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),

                  // Content
                  SliverPadding(
                    padding: const EdgeInsets.all(FinanceTheme.spacingM),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Balance Card
                        const BalanceCard(),
                        
                        const SizedBox(height: FinanceTheme.spacingL),

                        // Quick Actions
                        _buildQuickActions(),
                        
                        const SizedBox(height: FinanceTheme.spacingL),

                        // Category Spending Grid
                        CategorySpendingGrid(
                          onViewAll: () => _navigateToStatistics(),
                        ),
                        
                        const SizedBox(height: FinanceTheme.spacingL),

                        // Recent Transactions Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Transactions History',
                              style: FinanceTheme.headingS,
                            ),
                            TextButton(
                              onPressed: () => _navigateToTransactions(),
                              child: Text(
                                'See all',
                                style: FinanceTheme.bodyM.copyWith(
                                  color: FinanceTheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: FinanceTheme.spacingS),

                        // Transactions List
                        if (_recentTransactions.isEmpty)
                          _buildEmptyState()
                        else
                          ..._recentTransactions.map((t) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              decoration: BoxDecoration(
                                color: FinanceTheme.surface,
                                borderRadius: FinanceTheme.borderRadiusM,
                                boxShadow: FinanceTheme.shadowSoft,
                              ),
                              child: TransactionTile(
                                transaction: t,
                                onTap: () => _navigateToTransactionDetail(t),
                              ),
                            ),
                          )),
                        
                        // Bottom padding for FAB
                        const SizedBox(height: 100),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(FinanceTheme.spacingXL),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: FinanceTheme.textLight,
          ),
          const SizedBox(height: FinanceTheme.spacingM),
          Text(
            'No transactions yet',
            style: FinanceTheme.bodyL.copyWith(
              color: FinanceTheme.textSecondary,
            ),
          ),
          const SizedBox(height: FinanceTheme.spacingS),
          Text(
            'Tap + to add your first transaction',
            style: FinanceTheme.bodyS,
          ),
        ],
      ),
    );
  }

  void _navigateToTransactions() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TransactionsScreen()),
    );
  }

  void _navigateToTransactionDetail(FinanceTransaction transaction) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionDetailScreen(transaction: transaction),
      ),
    );
  }

  void _navigateToStatistics() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const StatisticsScreen()),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _QuickActionButton(
            icon: Icons.bar_chart,
            label: 'Statistics',
            color: FinanceTheme.primary,
            onTap: _navigateToStatistics,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.savings,
            label: 'Goals',
            color: Colors.teal,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SavingsGoalsScreen()),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: FinanceTheme.spacingM,
          vertical: FinanceTheme.spacingM,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: FinanceTheme.borderRadiusM,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: FinanceTheme.bodyM.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
