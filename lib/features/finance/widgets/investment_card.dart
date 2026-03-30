import 'package:flutter/material.dart';
import '../theme/finance_theme.dart';
import '../models/finance_models.dart';
import '../services/finance_service.dart';

/// Investment summary card - shows total investment value
class InvestmentSummaryCard extends StatelessWidget {
  final VoidCallback? onTap;

  const InvestmentSummaryCard({
    super.key,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final totalValue = FinanceService.getTotalInvestmentValue();
    final totalReturn = FinanceService.getTotalInvestmentReturn();
    final isProfit = totalReturn >= 0;
    final investments = FinanceService.getInvestments();

    // Calculate breakdown by type
    final deposits = investments.where((i) => i.type == InvestmentType.deposit).fold(0.0, (s, i) => s + i.currentValue);
    final stocks = investments.where((i) => i.type == InvestmentType.stock).fold(0.0, (s, i) => s + i.currentValue);
    final insurance = investments.where((i) => i.type == InvestmentType.insurance).fold(0.0, (s, i) => s + i.currentValue);
    final bonds = investments.where((i) => i.type == InvestmentType.bond).fold(0.0, (s, i) => s + i.currentValue);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(FinanceTheme.spacingL),
        decoration: BoxDecoration(
          gradient: FinanceTheme.cardGradient,
          borderRadius: FinanceTheme.borderRadiusXL,
          boxShadow: FinanceTheme.shadowStrong,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Investment',
                      style: FinanceTheme.labelM.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Amount',
                          style: FinanceTheme.bodyS.copyWith(
                            color: Colors.white54,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.white54,
                          size: 16,
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.more_horiz,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: FinanceTheme.spacingM),
            
            // Total value
            Text(
              FinanceService.formatCurrency(totalValue),
              style: FinanceTheme.currency.copyWith(fontSize: 28),
            ),
            
            const SizedBox(height: FinanceTheme.spacingS),
            
            // Return indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (isProfit ? FinanceTheme.income : FinanceTheme.expense).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isProfit ? Icons.trending_up : Icons.trending_down,
                    color: isProfit ? FinanceTheme.income : FinanceTheme.expense,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${isProfit ? '+' : ''}${FinanceService.formatCurrency(totalReturn)}',
                    style: FinanceTheme.labelS.copyWith(
                      color: isProfit ? FinanceTheme.income : FinanceTheme.expense,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: FinanceTheme.spacingL),
            
            // Breakdown
            Row(
              children: [
                _BreakdownItem(label: 'Deposits', value: deposits),
                _BreakdownItem(label: 'Insurance', value: insurance),
              ],
            ),
            const SizedBox(height: FinanceTheme.spacingS),
            Row(
              children: [
                _BreakdownItem(label: 'Stocks', value: stocks),
                _BreakdownItem(label: 'Bonds', value: bonds),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakdownItem extends StatelessWidget {
  final String label;
  final double value;

  const _BreakdownItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: FinanceTheme.labelS.copyWith(color: Colors.white54),
          ),
          const SizedBox(height: 2),
          Text(
            FinanceService.formatCurrency(value),
            style: FinanceTheme.bodyM.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual investment list tile
class InvestmentListTile extends StatelessWidget {
  final FinanceInvestment investment;
  final VoidCallback? onTap;

  const InvestmentListTile({
    super.key,
    required this.investment,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: investment.color.withValues(alpha: 0.15),
          borderRadius: FinanceTheme.borderRadiusS,
        ),
        child: Icon(
          investment.icon,
          color: investment.color,
          size: 20,
        ),
      ),
      title: Text(
        investment.name,
        style: FinanceTheme.bodyM.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        investment.institution ?? investment.type.label,
        style: FinanceTheme.bodyS,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '+ ${FinanceService.formatCurrency(investment.currentValue)}',
            style: FinanceTheme.bodyM.copyWith(
              color: FinanceTheme.income,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            investment.type.label,
            style: FinanceTheme.bodyS,
          ),
        ],
      ),
    );
  }
}
