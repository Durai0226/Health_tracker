import 'package:flutter/material.dart';
import '../theme/finance_theme.dart';
import '../models/finance_models.dart';
import '../services/finance_service.dart';

/// Screen for managing financial accounts
class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  List<FinanceAccount> _accounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await FinanceService.init();
    setState(() {
      _accounts = FinanceService.getAccounts(includeArchived: true);
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinanceTheme.background,
      appBar: AppBar(
        backgroundColor: FinanceTheme.background,
        elevation: 0,
        title: Text('Accounts', style: FinanceTheme.headingL),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: FinanceTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _accounts.isEmpty
              ? _buildEmptyState()
              : _buildAccountsList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddAccountDialog,
        backgroundColor: FinanceTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: FinanceTheme.textLight,
          ),
          const SizedBox(height: FinanceTheme.spacingM),
          Text(
            'No accounts yet',
            style: FinanceTheme.bodyL.copyWith(color: FinanceTheme.textSecondary),
          ),
          const SizedBox(height: FinanceTheme.spacingS),
          ElevatedButton(
            onPressed: _showAddAccountDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: FinanceTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add Account'),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsList() {
    final activeAccounts = _accounts.where((a) => !a.isArchived).toList();
    final archivedAccounts = _accounts.where((a) => a.isArchived).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(FinanceTheme.spacingM),
        children: [
          // Total balance card
          _buildTotalBalanceCard(),
          const SizedBox(height: FinanceTheme.spacingL),

          // Active accounts
          if (activeAccounts.isNotEmpty) ...[
            Text('Active Accounts', style: FinanceTheme.headingS),
            const SizedBox(height: FinanceTheme.spacingS),
            ...activeAccounts.map((account) => _AccountTile(
              account: account,
              onTap: () => _showEditAccountDialog(account),
              onArchive: () => _archiveAccount(account),
            )),
          ],

          // Archived accounts
          if (archivedAccounts.isNotEmpty) ...[
            const SizedBox(height: FinanceTheme.spacingL),
            Text('Archived', style: FinanceTheme.headingS),
            const SizedBox(height: FinanceTheme.spacingS),
            ...archivedAccounts.map((account) => _AccountTile(
              account: account,
              onTap: () => _showEditAccountDialog(account),
              onRestore: () => _restoreAccount(account),
            )),
          ],

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildTotalBalanceCard() {
    final totalBalance = _accounts
        .where((a) => !a.isArchived)
        .fold(0.0, (sum, a) => sum + a.balance);

    return Container(
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
            'Total Balance',
            style: FinanceTheme.labelM.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            FinanceService.formatCurrency(totalBalance),
            style: FinanceTheme.currency.copyWith(fontSize: 32),
          ),
          const SizedBox(height: 8),
          Text(
            '${_accounts.where((a) => !a.isArchived).length} active accounts',
            style: FinanceTheme.bodyS.copyWith(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  void _showAddAccountDialog() {
    _showAccountDialog();
  }

  void _showEditAccountDialog(FinanceAccount account) {
    _showAccountDialog(existingAccount: account);
  }

  void _showAccountDialog({FinanceAccount? existingAccount}) {
    final isEditing = existingAccount != null;
    final nameController = TextEditingController(text: existingAccount?.name ?? '');
    final balanceController = TextEditingController(
      text: existingAccount?.balance.toStringAsFixed(2) ?? '',
    );
    var selectedType = existingAccount?.type ?? AccountType.bank;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: BoxDecoration(
            color: FinanceTheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: FinanceTheme.spacingL,
            right: FinanceTheme.spacingL,
            top: FinanceTheme.spacingL,
            bottom: MediaQuery.of(context).viewInsets.bottom + FinanceTheme.spacingL,
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
                    color: FinanceTheme.textLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: FinanceTheme.spacingL),
              Text(
                isEditing ? 'Edit Account' : 'Add Account',
                style: FinanceTheme.headingM,
              ),
              const SizedBox(height: FinanceTheme.spacingL),
              
              // Account type
              Text('Account Type', style: FinanceTheme.labelM),
              const SizedBox(height: FinanceTheme.spacingS),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AccountType.values.map((type) {
                  final isSelected = type == selectedType;
                  return ChoiceChip(
                    label: Text(type.label),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setSheetState(() => selectedType = type);
                      }
                    },
                    selectedColor: FinanceTheme.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : FinanceTheme.textPrimary,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: FinanceTheme.spacingM),
              
              // Name
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Account Name',
                  hintText: 'e.g., Main Checking',
                  filled: true,
                  fillColor: FinanceTheme.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: FinanceTheme.borderRadiusM,
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: FinanceTheme.spacingM),
              
              // Balance
              TextFormField(
                controller: balanceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Current Balance',
                  prefixText: '\$ ',
                  filled: true,
                  fillColor: FinanceTheme.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: FinanceTheme.borderRadiusM,
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: FinanceTheme.spacingXL),
              
              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final balance = double.tryParse(balanceController.text) ?? 0;
                    
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter account name')),
                      );
                      return;
                    }
                    
                    if (isEditing) {
                      final updated = existingAccount.copyWith(
                        name: name,
                        type: selectedType,
                        balance: balance,
                      );
                      await FinanceService.updateAccount(updated);
                    } else {
                      final account = FinanceAccount.create(
                        name: name,
                        type: selectedType,
                        balance: balance,
                      );
                      await FinanceService.addAccount(account);
                    }
                    
                    Navigator.pop(context);
                    _loadData();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FinanceTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: FinanceTheme.borderRadiusM,
                    ),
                  ),
                  child: Text(
                    isEditing ? 'Update Account' : 'Add Account',
                    style: FinanceTheme.bodyL.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _archiveAccount(FinanceAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Account?'),
        content: Text('Archive "${account.name}"? You can restore it later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: FinanceTheme.expense,
              foregroundColor: Colors.white,
            ),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FinanceService.updateAccount(account.copyWith(isArchived: true));
      _loadData();
    }
  }

  Future<void> _restoreAccount(FinanceAccount account) async {
    await FinanceService.updateAccount(account.copyWith(isArchived: false));
    _loadData();
  }
}

class _AccountTile extends StatelessWidget {
  final FinanceAccount account;
  final VoidCallback onTap;
  final VoidCallback? onArchive;
  final VoidCallback? onRestore;

  const _AccountTile({
    required this.account,
    required this.onTap,
    this.onArchive,
    this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: FinanceTheme.surface,
          borderRadius: FinanceTheme.borderRadiusM,
          boxShadow: FinanceTheme.shadowSoft,
        ),
        child: ListTile(
          onTap: onTap,
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: account.color.withValues(alpha: 0.1),
              borderRadius: FinanceTheme.borderRadiusS,
            ),
            child: Icon(account.icon, color: account.color),
          ),
          title: Text(
            account.name,
            style: FinanceTheme.bodyL.copyWith(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            account.type.label,
            style: FinanceTheme.bodyS.copyWith(color: FinanceTheme.textSecondary),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                FinanceService.formatCurrency(account.balance),
                style: FinanceTheme.bodyL.copyWith(
                  fontWeight: FontWeight.w600,
                  color: account.balance >= 0 ? FinanceTheme.income : FinanceTheme.expense,
                ),
              ),
              if (onArchive != null || onRestore != null)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: FinanceTheme.textSecondary),
                  onSelected: (value) {
                    if (value == 'archive') onArchive?.call();
                    if (value == 'restore') onRestore?.call();
                  },
                  itemBuilder: (context) => [
                    if (onArchive != null)
                      const PopupMenuItem(value: 'archive', child: Text('Archive')),
                    if (onRestore != null)
                      const PopupMenuItem(value: 'restore', child: Text('Restore')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
