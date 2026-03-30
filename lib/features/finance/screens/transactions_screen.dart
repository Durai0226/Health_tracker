import 'package:flutter/material.dart';
import '../theme/finance_theme.dart';
import '../widgets/finance_widgets.dart';
import '../models/finance_models.dart';
import '../services/finance_service.dart';
import 'transaction_detail_screen.dart';

/// Transactions list screen with filters
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<FinanceTransaction> _transactions = [];
  TransactionType? _selectedType;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        switch (_tabController.index) {
          case 0:
            _selectedType = null;
            break;
          case 1:
            _selectedType = TransactionType.income;
            break;
          case 2:
            _selectedType = TransactionType.expense;
            break;
          case 3:
            _selectedType = TransactionType.transfer;
            break;
        }
        _loadData();
      });
    }
  }

  Future<void> _loadData() async {
    await FinanceService.init();
    setState(() {
      _transactions = FinanceService.getTransactions(type: _selectedType);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinanceTheme.background,
      appBar: AppBar(
        backgroundColor: FinanceTheme.background,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: FinanceTheme.textPrimary),
        ),
        title: Text('Transactions', style: FinanceTheme.headingL),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.filter_list, color: FinanceTheme.textPrimary),
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
              labelStyle: FinanceTheme.labelM,
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Income'),
                Tab(text: 'Expense'),
                Tab(text: 'Transfer'),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _transactions.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(FinanceTheme.spacingM),
                itemCount: _transactions.length,
                itemBuilder: (context, index) {
                  final transaction = _transactions[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: FinanceTheme.spacingS),
                    child: Container(
                      decoration: BoxDecoration(
                        color: FinanceTheme.surface,
                        borderRadius: FinanceTheme.borderRadiusM,
                        boxShadow: FinanceTheme.shadowSoft,
                      ),
                      child: TransactionTile(
                        transaction: transaction,
                        onTap: () => _navigateToDetail(transaction),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: FinanceTheme.textLight,
          ),
          const SizedBox(height: FinanceTheme.spacingM),
          Text(
            'No transactions found',
            style: FinanceTheme.bodyL.copyWith(
              color: FinanceTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToDetail(FinanceTransaction transaction) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionDetailScreen(transaction: transaction),
      ),
    );
  }
}
