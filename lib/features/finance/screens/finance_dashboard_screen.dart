import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/finance_storage_service.dart';
import '../services/bill_storage_service.dart';
import '../models/transaction.dart';
import '../models/finance_enums.dart';
import '../widgets/finance_widgets.dart';
import '../widgets/bill_widgets.dart';
import 'add_transaction_screen.dart';
import 'transactions_screen.dart';
import 'accounts_screen.dart';
import 'budgets_screen.dart';
import 'bill_dashboard_screen.dart';
import '../../../core/constants/app_colors.dart';

class FinanceDashboardScreen extends StatefulWidget {
  const FinanceDashboardScreen({super.key});

  @override
  State<FinanceDashboardScreen> createState() => _FinanceDashboardScreenState();
}

class _FinanceDashboardScreenState extends State<FinanceDashboardScreen> {
  bool _isInitialized = false;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeFinance();
  }

  Future<void> _initializeFinance() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Future.any([
        FinanceStorageService.init(),
        Future.delayed(const Duration(seconds: 10), () {
          throw TimeoutException('Finance initialization timeout');
        }),
      ]);

      if (!FinanceStorageService.isInitialized) {
        throw Exception('Finance service failed to initialize');
      }

      if (!mounted) return;
      setState(() {
        _isInitialized = true;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error initializing finance: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load finance data. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ));

    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => setState(() {}),
          color: AppColors.primary,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(child: _buildBalanceCard()),
              SliverToBoxAdapter(child: _buildQuickStats()),
              SliverToBoxAdapter(child: _buildQuickActions()),
              SliverToBoxAdapter(child: _buildRecentTransactions()),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildLoadingState() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 24),
            Text(
              'Loading finance data...',
              style: TextStyle(
                color: AppColors.getTextSecondary(context),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 24),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.getTextSecondary(context),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _initializeFinance,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      floating: true,
      backgroundColor: AppColors.getBackground(context),
      elevation: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            'Finance',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24,
              color: AppColors.getTextPrimary(context),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.history, color: AppColors.getTextSecondary(context)),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TransactionsScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceCard() {
    if (!_isInitialized) return const SizedBox.shrink();

    final netWorth = FinanceStorageService.getNetWorth();
    final totalBalance = FinanceStorageService.getTotalBalance();
    final isDark = AppColors.isDark(context);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF22C55E).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Balance',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  DateFormat('MMM yyyy').format(DateTime.now()),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₹${NumberFormat('#,##,###.##').format(totalBalance)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'This Month Income',
                    FinanceStorageService.getThisMonthIncome(),
                    Icons.arrow_downward_rounded,
                    true,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withOpacity(0.3),
                ),
                Expanded(
                  child: _buildStatItem(
                    'This Month Expense',
                    FinanceStorageService.getThisMonthExpenses(),
                    Icons.arrow_upward_rounded,
                    false,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, double amount, IconData icon, bool isPositive) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '₹${NumberFormat('#,##,###').format(amount)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStats() {
    if (!_isInitialized) return const SizedBox.shrink();

    final accounts = FinanceStorageService.getAllAccounts();
    final budgets = FinanceStorageService.getAllBudgets();
    final transactions = FinanceStorageService.getAllTransactions();
    final isDark = AppColors.isDark(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildStatCard(
            '${accounts.length}',
            'Accounts',
            Icons.account_balance_wallet_outlined,
            const Color(0xFF3B82F6),
            isDark,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            '${budgets.length}',
            'Budgets',
            Icons.pie_chart_outline,
            const Color(0xFFF59E0B),
            isDark,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            '${transactions.length}',
            'Transactions',
            Icons.receipt_long_outlined,
            const Color(0xFF8B5CF6),
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.getCardBg(context),
          borderRadius: BorderRadius.circular(16),
          border: isDark ? Border.all(color: AppColors.darkBorder.withOpacity(0.5)) : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimary(context),
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.getTextSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final isDark = AppColors.isDark(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextPrimary(context),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildActionButton(
                'Accounts',
                Icons.account_balance_wallet_rounded,
                const Color(0xFF3B82F6),
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountsScreen())),
                isDark,
              ),
              const SizedBox(width: 12),
              _buildActionButton(
                'Budgets',
                Icons.pie_chart_rounded,
                const Color(0xFFF59E0B),
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BudgetsScreen())),
                isDark,
              ),
              const SizedBox(width: 12),
              _buildActionButton(
                'Bills',
                Icons.receipt_long_rounded,
                const Color(0xFFEF4444),
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BillDashboardScreen())),
                isDark,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildActionButton(
                'History',
                Icons.history_rounded,
                const Color(0xFF8B5CF6),
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionsScreen())),
                isDark,
              ),
              const SizedBox(width: 12),
              Expanded(child: Container()),
              const SizedBox(width: 12),
              Expanded(child: Container()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap, bool isDark) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(isDark ? 0.15 : 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentTransactions() {
    if (!_isInitialized) return const SizedBox.shrink();

    final transactions = FinanceStorageService.getRecentTransactions(limit: 5);
    final isDark = AppColors.isDark(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Transactions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TransactionsScreen()),
                ),
                child: Text(
                  'See All',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (transactions.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.getCardBg(context),
                borderRadius: BorderRadius.circular(16),
                border: isDark ? Border.all(color: AppColors.darkBorder.withOpacity(0.5)) : null,
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 48,
                      color: AppColors.getTextSecondary(context),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No transactions yet',
                      style: TextStyle(
                        color: AppColors.getTextSecondary(context),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap + to add your first transaction',
                      style: TextStyle(
                        color: AppColors.getTextSecondary(context).withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...transactions.map((t) => TransactionTile(transaction: t)),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF22C55E).withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
            );
            if (result == true) {
              setState(() {});
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: Colors.white, size: 24),
                SizedBox(width: 8),
                Text(
                  'Add Transaction',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
