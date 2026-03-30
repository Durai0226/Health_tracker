import 'package:flutter/material.dart';
import '../theme/finance_theme.dart';
import '../models/finance_models.dart';
import '../services/finance_service.dart';

/// Add transaction screen
class AddTransactionScreen extends StatefulWidget {
  final TransactionType initialType;

  const AddTransactionScreen({
    super.key,
    this.initialType = TransactionType.expense,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  late TransactionType _selectedType;
  String? _selectedCategoryId;
  String? _selectedAccountId;
  DateTime _selectedDate = DateTime.now();

  List<FinanceCategory> _categories = [];
  List<FinanceAccount> _accounts = [];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: _typeToIndex(_selectedType),
    );
    _tabController.addListener(_onTabChanged);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  int _typeToIndex(TransactionType type) {
    switch (type) {
      case TransactionType.income:
        return 0;
      case TransactionType.expense:
        return 1;
      case TransactionType.transfer:
        return 2;
    }
  }

  TransactionType _indexToType(int index) {
    switch (index) {
      case 0:
        return TransactionType.income;
      case 1:
        return TransactionType.expense;
      case 2:
        return TransactionType.transfer;
      default:
        return TransactionType.expense;
    }
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        _selectedType = _indexToType(_tabController.index);
        _selectedCategoryId = null;
        _loadCategories();
      });
    }
  }

  Future<void> _loadData() async {
    await FinanceService.init();
    _loadCategories();
    setState(() {
      _accounts = FinanceService.getAccounts();
      if (_accounts.isNotEmpty) {
        _selectedAccountId = _accounts.first.id;
      }
    });
  }

  void _loadCategories() {
    final isIncome = _selectedType == TransactionType.income;
    _categories = FinanceService.getCategories(isIncome: isIncome);
    if (_categories.isNotEmpty && _selectedCategoryId == null) {
      _selectedCategoryId = _categories.first.id;
    }
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null || _selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select category and account')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    final transaction = FinanceTransaction.create(
      amount: amount,
      type: _selectedType,
      categoryId: _selectedCategoryId!,
      accountId: _selectedAccountId!,
      date: _selectedDate,
      note: _noteController.text.isEmpty ? null : _noteController.text,
    );

    await FinanceService.addTransaction(transaction);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction added successfully')),
      );
      Navigator.pop(context, true);
    }
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
        title: Text('Add ${_selectedType.label}', style: FinanceTheme.headingM),
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
                Tab(text: 'Income'),
                Tab(text: 'Expense'),
                Tab(text: 'Transfer'),
                Tab(text: 'Bills'),
              ],
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(FinanceTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category selector
              Text('CATEGORY', style: FinanceTheme.labelM),
              const SizedBox(height: FinanceTheme.spacingS),
              _buildCategorySelector(),
              
              const SizedBox(height: FinanceTheme.spacingL),
              
              // Amount input
              Text('AMOUNT', style: FinanceTheme.labelM),
              const SizedBox(height: FinanceTheme.spacingS),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: FinanceTheme.currencySmall,
                decoration: InputDecoration(
                  hintText: '${FinanceService.currencySymbol} 0.00',
                  filled: true,
                  fillColor: FinanceTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: FinanceTheme.borderRadiusM,
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(FinanceTheme.spacingM),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: FinanceTheme.spacingL),
              
              // Date picker
              Text('DATE', style: FinanceTheme.labelM),
              const SizedBox(height: FinanceTheme.spacingS),
              InkWell(
                onTap: _selectDate,
                borderRadius: FinanceTheme.borderRadiusM,
                child: Container(
                  padding: const EdgeInsets.all(FinanceTheme.spacingM),
                  decoration: BoxDecoration(
                    color: FinanceTheme.surface,
                    borderRadius: FinanceTheme.borderRadiusM,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formatDate(_selectedDate),
                          style: FinanceTheme.bodyL,
                        ),
                      ),
                      const Icon(Icons.calendar_today, color: FinanceTheme.textSecondary),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: FinanceTheme.spacingL),
              
              // Account selector
              Text('ACCOUNT', style: FinanceTheme.labelM),
              const SizedBox(height: FinanceTheme.spacingS),
              _buildAccountSelector(),
              
              const SizedBox(height: FinanceTheme.spacingL),
              
              // Notes
              Text('NOTES', style: FinanceTheme.labelM),
              const SizedBox(height: FinanceTheme.spacingS),
              TextFormField(
                controller: _noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Add notes (optional)',
                  filled: true,
                  fillColor: FinanceTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: FinanceTheme.borderRadiusM,
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(FinanceTheme.spacingM),
                ),
              ),
              
              const SizedBox(height: FinanceTheme.spacingXL),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: FinanceTheme.textSecondary,
                        padding: const EdgeInsets.symmetric(vertical: FinanceTheme.spacingM),
                        shape: RoundedRectangleBorder(
                          borderRadius: FinanceTheme.borderRadiusM,
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: FinanceTheme.spacingM),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveTransaction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FinanceTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: FinanceTheme.spacingM),
                        shape: RoundedRectangleBorder(
                          borderRadius: FinanceTheme.borderRadiusM,
                        ),
                      ),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Container(
      padding: const EdgeInsets.all(FinanceTheme.spacingS),
      decoration: BoxDecoration(
        color: FinanceTheme.surface,
        borderRadius: FinanceTheme.borderRadiusM,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategoryId,
          isExpanded: true,
          items: _categories.map((category) {
            return DropdownMenuItem(
              value: category.id,
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: category.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(category.icon, color: category.color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(category.name),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) => setState(() => _selectedCategoryId = value),
        ),
      ),
    );
  }

  Widget _buildAccountSelector() {
    return Container(
      padding: const EdgeInsets.all(FinanceTheme.spacingS),
      decoration: BoxDecoration(
        color: FinanceTheme.surface,
        borderRadius: FinanceTheme.borderRadiusM,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedAccountId,
          isExpanded: true,
          items: _accounts.map((account) {
            return DropdownMenuItem(
              value: account.id,
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: account.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(account.icon, color: account.color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(account.name),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) => setState(() => _selectedAccountId = value),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
