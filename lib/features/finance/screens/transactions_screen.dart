import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../models/transaction.dart';
import '../models/finance_enums.dart';
import '../services/finance_storage_service.dart';
import '../widgets/finance_widgets.dart';
import 'add_transaction_screen.dart';

class TransactionsScreen extends StatefulWidget {
  final String? accountId;
  final bool showSearch;

  const TransactionsScreen({
    super.key,
    this.accountId,
    this.showSearch = false,
  });

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String _searchQuery = '';
  TransactionType? _filterType;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  List<FinanceTransaction> get _filteredTransactions {
    var transactions = widget.accountId != null
        ? FinanceStorageService.getTransactionsForAccount(widget.accountId!)
        : FinanceStorageService.getAllTransactions();

    if (_searchQuery.isNotEmpty) {
      transactions = transactions.where((t) {
        final note = t.note?.toLowerCase() ?? '';
        final category = FinanceStorageService.getCategory(t.categoryId)?.name.toLowerCase() ?? '';
        return note.contains(_searchQuery.toLowerCase()) ||
            category.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    if (_filterType != null) {
      transactions = transactions.where((t) => t.type == _filterType).toList();
    }

    if (_filterStartDate != null && _filterEndDate != null) {
      transactions = transactions.where((t) =>
          t.date.isAfter(_filterStartDate!) && t.date.isBefore(_filterEndDate!)).toList();
    }

    return transactions;
  }

  Map<String, List<FinanceTransaction>> get _groupedTransactions {
    final grouped = <String, List<FinanceTransaction>>{};
    for (var t in _filteredTransactions) {
      final key = DateFormat('MMMM d, yyyy').format(t.date);
      grouped.putIfAbsent(key, () => []).add(t);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.getTextPrimary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Transactions',
          style: TextStyle(
            color: AppColors.getTextPrimary(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list, color: AppColors.getTextSecondary(context)),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: CommonCard(
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search transactions...',
                  hintStyle: TextStyle(color: AppColors.getTextSecondary(context)),
                  prefixIcon: Icon(Icons.search, color: AppColors.getTextSecondary(context)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ),
          if (_filterType != null || _filterStartDate != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  if (_filterType != null)
                    _buildFilterChip(
                      _filterType!.displayName,
                      () => setState(() => _filterType = null),
                    ),
                  if (_filterStartDate != null)
                    _buildFilterChip(
                      '${DateFormat('MMM d').format(_filterStartDate!)} - ${DateFormat('MMM d').format(_filterEndDate!)}',
                      () => setState(() {
                        _filterStartDate = null;
                        _filterEndDate = null;
                      }),
                    ),
                ],
              ),
            ),
          Expanded(
            child: _filteredTransactions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 64,
                          color: AppColors.getTextSecondary(context),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No transactions found',
                          style: TextStyle(
                            color: AppColors.getTextSecondary(context),
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _groupedTransactions.length,
                    itemBuilder: (context, index) {
                      final entry = _groupedTransactions.entries.elementAt(index);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              entry.key,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.getTextSecondary(context),
                              ),
                            ),
                          ),
                          ...entry.value.map((t) => TransactionTile(
                            transaction: t,
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddTransactionScreen(editTransaction: t),
                                ),
                              );
                              if (result == true) setState(() {});
                            },
                            onDelete: () async {
                              await FinanceStorageService.deleteTransaction(t.id);
                              setState(() {});
                            },
                          )),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 16, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.getCardBg(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.getDivider(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Filter by Type',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                _buildTypeFilterChip(null, 'All'),
                ...TransactionType.values.map((t) => _buildTypeFilterChip(t, t.displayName)),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Filter by Date',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDateFilterButton('This Week', () {
                    final now = DateTime.now();
                    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
                    setState(() {
                      _filterStartDate = startOfWeek;
                      _filterEndDate = now;
                    });
                    Navigator.pop(context);
                  }),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDateFilterButton('This Month', () {
                    final now = DateTime.now();
                    setState(() {
                      _filterStartDate = DateTime(now.year, now.month, 1);
                      _filterEndDate = now;
                    });
                    Navigator.pop(context);
                  }),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeFilterChip(TransactionType? type, String label) {
    final isSelected = _filterType == type;
    return GestureDetector(
      onTap: () {
        setState(() => _filterType = type);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.getTextSecondary(context).withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.getTextPrimary(context),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildDateFilterButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.getBackground(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.getTextPrimary(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
