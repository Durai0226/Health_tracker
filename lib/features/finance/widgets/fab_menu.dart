import 'package:flutter/material.dart';
import '../theme/finance_theme.dart';

/// Expandable FAB menu for adding transactions
class FinanceFabMenu extends StatefulWidget {
  final VoidCallback? onAddIncome;
  final VoidCallback? onAddExpense;
  final VoidCallback? onAddTransfer;
  final VoidCallback? onAddBill;

  const FinanceFabMenu({
    super.key,
    this.onAddIncome,
    this.onAddExpense,
    this.onAddTransfer,
    this.onAddBill,
  });

  @override
  State<FinanceFabMenu> createState() => _FinanceFabMenuState();
}

class _FinanceFabMenuState extends State<FinanceFabMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: FinanceTheme.animationNormal,
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        // Background overlay
        if (_isOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggle,
              child: AnimatedBuilder(
                animation: _expandAnimation,
                builder: (context, child) {
                  return Container(
                    color: Colors.black.withValues(alpha: 0.3 * _expandAnimation.value),
                  );
                },
              ),
            ),
          ),

        // FAB options
        Positioned(
          bottom: 80,
          child: AnimatedBuilder(
            animation: _expandAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _expandAnimation.value,
                child: Opacity(
                  opacity: _expandAnimation.value,
                  child: child,
                ),
              );
            },
            child: _buildFabOptions(),
          ),
        ),

        // Main FAB
        Positioned(
          bottom: 0,
          child: GestureDetector(
            onTap: _toggle,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _controller.value * 0.785, // 45 degrees
                  child: Container(
                    width: FinanceTheme.fabSize,
                    height: FinanceTheme.fabSize,
                    decoration: BoxDecoration(
                      gradient: FinanceTheme.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: FinanceTheme.shadowMedium,
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFabOptions() {
    return Container(
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
              _FabOption(
                icon: Icons.arrow_downward,
                label: 'Income',
                color: FinanceTheme.income,
                onTap: () {
                  _toggle();
                  widget.onAddIncome?.call();
                },
              ),
              const SizedBox(width: FinanceTheme.spacingM),
              _FabOption(
                icon: Icons.arrow_upward,
                label: 'Expense',
                color: FinanceTheme.expense,
                onTap: () {
                  _toggle();
                  widget.onAddExpense?.call();
                },
              ),
            ],
          ),
          const SizedBox(height: FinanceTheme.spacingM),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FabOption(
                icon: Icons.swap_horiz,
                label: 'Transfer',
                color: FinanceTheme.transfer,
                onTap: () {
                  _toggle();
                  widget.onAddTransfer?.call();
                },
              ),
              const SizedBox(width: FinanceTheme.spacingM),
              _FabOption(
                icon: Icons.receipt_long,
                label: 'Bill',
                color: FinanceTheme.warning,
                onTap: () {
                  _toggle();
                  widget.onAddBill?.call();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FabOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _FabOption({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
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
