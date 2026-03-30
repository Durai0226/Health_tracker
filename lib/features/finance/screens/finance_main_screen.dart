import 'package:flutter/material.dart';
import '../theme/finance_theme.dart';
import '../widgets/finance_widgets.dart';
import 'finance_home_screen.dart';
import 'finance_budget_screen.dart';
import 'finance_bills_screen.dart';
import 'finance_profile_screen.dart';
import 'add_transaction_screen.dart';
import 'add_bill_screen.dart';
import '../models/finance_models.dart';

/// Main finance screen with bottom navigation
class FinanceMainScreen extends StatefulWidget {
  const FinanceMainScreen({super.key});

  @override
  State<FinanceMainScreen> createState() => _FinanceMainScreenState();
}

class _FinanceMainScreenState extends State<FinanceMainScreen> {
  int _currentIndex = 0;
  bool _isFabOpen = false;

  final List<Widget> _screens = const [
    FinanceHomeScreen(),
    FinanceBudgetScreen(),
    FinanceBillsScreen(),
    FinanceProfileScreen(),
  ];

  void _onNavTap(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _toggleFab() {
    setState(() {
      _isFabOpen = !_isFabOpen;
    });
  }

  void _navigateToAddTransaction(TransactionType type) {
    setState(() => _isFabOpen = false);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(initialType: type),
      ),
    ).then((_) {
      // Refresh data after returning
      setState(() {});
    });
  }

  void _navigateToAddBill() {
    setState(() => _isFabOpen = false);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddBillScreen(),
      ),
    ).then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinanceTheme.background,
      body: Stack(
        children: [
          // Main content
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),

          // FAB overlay when open
          if (_isFabOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleFab,
                child: Container(
                  color: Colors.black54,
                ),
              ),
            ),

          // FAB menu options
          if (_isFabOpen)
            Positioned(
              bottom: FinanceTheme.bottomNavHeight + 20,
              left: 0,
              right: 0,
              child: Center(
                child: _buildFabMenu(),
              ),
            ),
        ],
      ),
      bottomNavigationBar: FinanceBottomNav(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
      ),
      floatingActionButton: _buildFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildFab() {
    return GestureDetector(
      onTap: _toggleFab,
      child: AnimatedContainer(
        duration: FinanceTheme.animationFast,
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: FinanceTheme.primaryGradient,
          shape: BoxShape.circle,
          boxShadow: FinanceTheme.shadowMedium,
        ),
        child: AnimatedRotation(
          duration: FinanceTheme.animationFast,
          turns: _isFabOpen ? 0.125 : 0,
          child: const Icon(
            Icons.add,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildFabMenu() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: FinanceTheme.animationNormal,
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(FinanceTheme.spacingM),
        decoration: BoxDecoration(
          color: FinanceTheme.surface,
          borderRadius: FinanceTheme.borderRadiusL,
          boxShadow: FinanceTheme.shadowMedium,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _FabMenuItem(
                  icon: Icons.arrow_downward,
                  label: 'Income',
                  color: FinanceTheme.income,
                  onTap: () => _navigateToAddTransaction(TransactionType.income),
                ),
                const SizedBox(width: FinanceTheme.spacingL),
                _FabMenuItem(
                  icon: Icons.arrow_upward,
                  label: 'Expense',
                  color: FinanceTheme.expense,
                  onTap: () => _navigateToAddTransaction(TransactionType.expense),
                ),
              ],
            ),
            const SizedBox(height: FinanceTheme.spacingM),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _FabMenuItem(
                  icon: Icons.swap_horiz,
                  label: 'Transfer',
                  color: FinanceTheme.transfer,
                  onTap: () => _navigateToAddTransaction(TransactionType.transfer),
                ),
                const SizedBox(width: FinanceTheme.spacingL),
                _FabMenuItem(
                  icon: Icons.receipt_long,
                  label: 'Bill',
                  color: FinanceTheme.warning,
                  onTap: _navigateToAddBill,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FabMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _FabMenuItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: FinanceTheme.labelS.copyWith(
              color: FinanceTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
