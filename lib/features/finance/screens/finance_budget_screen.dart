import 'package:flutter/material.dart';
import '../theme/finance_theme.dart';
import '../widgets/finance_widgets.dart';
import '../widgets/add_budget_dialog.dart';
import '../widgets/add_investment_dialog.dart';
import '../models/finance_models.dart';
import '../services/finance_service.dart';

/// Budget & Investment screen with tabs
class FinanceBudgetScreen extends StatefulWidget {
  const FinanceBudgetScreen({super.key});

  @override
  State<FinanceBudgetScreen> createState() => _FinanceBudgetScreenState();
}

class _FinanceBudgetScreenState extends State<FinanceBudgetScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<FinanceBudget> _budgets = [];
  List<FinanceInvestment> _investments = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await FinanceService.init();
    setState(() {
      _budgets = FinanceService.getBudgets();
      _investments = FinanceService.getInvestments();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinanceTheme.background,
      appBar: AppBar(
        backgroundColor: FinanceTheme.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Budget & Investment',
          style: FinanceTheme.headingL,
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.filter_list,
              color: FinanceTheme.textPrimary,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: FinanceTheme.spacingM),
            decoration: BoxDecoration(
              color: FinanceTheme.surfaceVariant,
              borderRadius: FinanceTheme.borderRadiusM,
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: FinanceTheme.primary,
                borderRadius: FinanceTheme.borderRadiusM,
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: FinanceTheme.textSecondary,
              labelStyle: FinanceTheme.bodyM.copyWith(fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Budget'),
                Tab(text: 'Investment'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBudgetTab(),
          _buildInvestmentTab(),
        ],
      ),
    );
  }

  Widget _buildBudgetTab() {
    if (_budgets.isEmpty) {
      return EmptyBudgetState(
        onCreate: _showCreateBudgetDialog,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(FinanceTheme.spacingM),
        children: [
          // Summary card
          Container(
            padding: const EdgeInsets.all(FinanceTheme.spacingL),
            decoration: BoxDecoration(
              gradient: FinanceTheme.cardGradient,
              borderRadius: FinanceTheme.borderRadiusXL,
              boxShadow: FinanceTheme.shadowStrong,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Household Budget',
                  style: FinanceTheme.labelM.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Available Balance',
                          style: FinanceTheme.bodyS.copyWith(color: Colors.white54),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          FinanceService.formatCurrency(FinanceService.getTotalBalance()),
                          style: FinanceTheme.currency.copyWith(fontSize: 28),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _StatRow(
                          label: 'Spent',
                          value: _budgets.fold(0.0, (s, b) => s + b.spent),
                          color: FinanceTheme.expense,
                        ),
                        const SizedBox(height: 4),
                        _StatRow(
                          label: 'Budget',
                          value: _budgets.fold(0.0, (s, b) => s + b.limit),
                          color: FinanceTheme.income,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: FinanceTheme.spacingL),

          // Budget list
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Household Budget', style: FinanceTheme.headingS),
              TextButton.icon(
                onPressed: _showCreateBudgetDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Category'),
                style: TextButton.styleFrom(
                  foregroundColor: FinanceTheme.primary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: FinanceTheme.spacingS),
          
          ..._budgets.map((budget) => Padding(
            padding: const EdgeInsets.only(bottom: FinanceTheme.spacingS),
            child: BudgetProgressCard(
              budget: budget,
              onTap: () => _showBudgetDetail(budget),
            ),
          )),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildInvestmentTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(FinanceTheme.spacingM),
        children: [
          // Investment summary card
          const InvestmentSummaryCard(),
          
          const SizedBox(height: FinanceTheme.spacingL),

          // Deposits section
          if (_investments.where((i) => i.type == InvestmentType.deposit).isNotEmpty) ...[
            Text('Deposits', style: FinanceTheme.headingS),
            const SizedBox(height: FinanceTheme.spacingS),
            ..._investments
                .where((i) => i.type == InvestmentType.deposit)
                .map((investment) => InvestmentListTile(
                  investment: investment,
                  onTap: () => _showInvestmentDetail(investment),
                )),
          ],
          
          const SizedBox(height: FinanceTheme.spacingM),

          // Stocks section
          if (_investments.where((i) => i.type == InvestmentType.stock).isNotEmpty) ...[
            Text('Stocks', style: FinanceTheme.headingS),
            const SizedBox(height: FinanceTheme.spacingS),
            ..._investments
                .where((i) => i.type == InvestmentType.stock)
                .map((investment) => InvestmentListTile(
                  investment: investment,
                  onTap: () => _showInvestmentDetail(investment),
                )),
          ],

          // Empty state if no investments
          if (_investments.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(FinanceTheme.spacingXL),
                child: Column(
                  children: [
                    Icon(
                      Icons.trending_up,
                      size: 64,
                      color: FinanceTheme.textLight,
                    ),
                    const SizedBox(height: FinanceTheme.spacingM),
                    Text(
                      'No investments yet',
                      style: FinanceTheme.bodyL.copyWith(
                        color: FinanceTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: FinanceTheme.spacingS),
                    ElevatedButton(
                      onPressed: _showAddInvestmentDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FinanceTheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Add Investment'),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  void _showCreateBudgetDialog() {
    AddBudgetDialog.show(
      context,
      onSaved: _loadData,
    );
  }

  void _showBudgetDetail(FinanceBudget budget) {
    AddBudgetDialog.show(
      context,
      existingBudget: budget,
      onSaved: _loadData,
    );
  }

  void _showInvestmentDetail(FinanceInvestment investment) {
    AddInvestmentDialog.show(
      context,
      existingInvestment: investment,
      onSaved: _loadData,
    );
  }

  void _showAddInvestmentDialog() {
    AddInvestmentDialog.show(
      context,
      onSaved: _loadData,
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _StatRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: FinanceTheme.bodyS.copyWith(color: Colors.white70),
        ),
        const SizedBox(width: 8),
        Text(
          FinanceService.formatCurrency(value),
          style: FinanceTheme.bodyM.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
