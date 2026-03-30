import 'package:flutter/material.dart';
import '../theme/finance_theme.dart';
import '../widgets/finance_widgets.dart';
import '../models/finance_models.dart';
import '../services/finance_service.dart';
import 'add_bill_screen.dart';

/// Bills management screen with tabs
class FinanceBillsScreen extends StatefulWidget {
  const FinanceBillsScreen({super.key});

  @override
  State<FinanceBillsScreen> createState() => _FinanceBillsScreenState();
}

class _FinanceBillsScreenState extends State<FinanceBillsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<FinanceBill> _allBills = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
      _allBills = FinanceService.getBills(includeArchived: true);
    });
  }

  List<FinanceBill> get _upcomingBills => _allBills
      .where((b) => b.status == BillStatus.upcoming && !b.isOverdue)
      .toList();

  List<FinanceBill> get _overdueBills => _allBills
      .where((b) => b.isOverdue && b.status != BillStatus.paid)
      .toList();

  List<FinanceBill> get _recurringBills => _allBills
      .where((b) => b.isRecurring && !b.isArchived)
      .toList();

  List<FinanceBill> get _paidBills => _allBills
      .where((b) => b.status == BillStatus.paid)
      .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinanceTheme.background,
      appBar: AppBar(
        backgroundColor: FinanceTheme.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('Bills', style: FinanceTheme.headingL),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.filter_list, color: FinanceTheme.textPrimary),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: FinanceTheme.primary,
            labelColor: FinanceTheme.primary,
            unselectedLabelColor: FinanceTheme.textSecondary,
            labelStyle: FinanceTheme.bodyM.copyWith(fontWeight: FontWeight.w600),
            tabs: [
              Tab(text: 'Upcoming (${_upcomingBills.length})'),
              Tab(text: 'Overdue (${_overdueBills.length})'),
              Tab(text: 'Recurring (${_recurringBills.length})'),
              Tab(text: 'Paid (${_paidBills.length})'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBillList(_upcomingBills, 'No upcoming bills'),
          _buildBillList(_overdueBills, 'No overdue bills'),
          _buildBillList(_recurringBills, 'No recurring bills'),
          _buildBillList(_paidBills, 'No paid bills'),
        ],
      ),
    );
  }

  Widget _buildBillList(List<FinanceBill> bills, String emptyMessage) {
    if (bills.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: FinanceTheme.textLight),
            const SizedBox(height: FinanceTheme.spacingM),
            Text(emptyMessage, style: FinanceTheme.bodyL.copyWith(color: FinanceTheme.textSecondary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(FinanceTheme.spacingM),
        itemCount: bills.length,
        itemBuilder: (context, index) {
          final bill = bills[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: FinanceTheme.spacingS),
            child: BillCard(
              bill: bill,
              onTap: () => _showBillDetail(bill),
              onPay: () => _payBill(bill),
            ),
          );
        },
      ),
    );
  }

  void _showBillDetail(FinanceBill bill) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddBillScreen(existingBill: bill),
      ),
    ).then((_) => _loadData());
  }

  Future<void> _payBill(FinanceBill bill) async {
    final accounts = FinanceService.getAccounts();
    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add an account first')),
      );
      return;
    }

    // Show payment confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pay ${bill.name}?'),
        content: Text('Amount: ${FinanceService.formatCurrency(bill.amount)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: FinanceTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Pay'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FinanceService.markBillAsPaid(
        bill.id,
        accountId: accounts.first.id,
      );
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${bill.name} marked as paid')),
        );
      }
    }
  }
}
