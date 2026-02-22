import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/bill.dart';
import '../models/bill_enums.dart';
import '../services/bill_storage_service.dart';
import '../services/bill_reminder_service.dart';
import '../widgets/bill_widgets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import 'add_bill_screen.dart';
import 'bill_list_screen.dart';
import 'bill_detail_screen.dart';

class BillDashboardScreen extends StatefulWidget {
  const BillDashboardScreen({super.key});

  @override
  State<BillDashboardScreen> createState() => _BillDashboardScreenState();
}

class _BillDashboardScreenState extends State<BillDashboardScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeBillService();
  }

  Future<void> _initializeBillService() async {
    try {
      await BillStorageService.init();
      await BillReminderService.init();

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint('❌ Error initializing bill service: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load bills. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: const Text('Bills & Payments'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.getTextPrimary(context),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => _navigateToBillList(filter: 'paid'),
            tooltip: 'Payment History',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _showSettings,
            tooltip: 'Settings',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorState()
              : _buildDashboard(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNewBill,
        icon: const Icon(Icons.add),
        label: const Text('Add Bill'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.getTextSecondary(context)),
            ),
            const SizedBox(height: 24),
            CommonButton(
              text: 'Retry',
              variant: ButtonVariant.primary,
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _initializeBillService();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    return ValueListenableBuilder<Box<Bill>>(
      valueListenable: BillStorageService.billsListenable!,
      builder: (context, box, _) {
        final overdueBills = BillStorageService.getOverdueBills();
        final dueTodayBills = BillStorageService.getDueTodayBills();
        final upcomingBills = BillStorageService.getUpcomingBills(days: 30);
        final totalUpcoming = BillStorageService.getTotalUpcoming(days: 30);
        final totalOverdue = BillStorageService.getTotalOverdue();
        final paidThisMonth = BillStorageService.getPaidThisMonth();

        return RefreshIndicator(
          onRefresh: _initializeBillService,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Overdue Banner
                OverdueBanner(
                  overdueBills: overdueBills,
                  onTap: () => _navigateToBillList(filter: 'overdue'),
                ),

                // Due Today Banner
                DueTodayBanner(
                  dueTodayBills: dueTodayBills,
                  onTap: () => _navigateToBillList(filter: 'due_today'),
                ),

                // Summary Cards
                SizedBox(
                  height: 140,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      SizedBox(
                        width: 160,
                        child: BillSummaryCard(
                          title: 'Upcoming',
                          amount: '₹${NumberFormat.compact().format(totalUpcoming)}',
                          icon: Icons.upcoming,
                          color: const Color(0xFF3B82F6),
                          count: upcomingBills.length,
                          onTap: () => _navigateToBillList(filter: 'upcoming'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 160,
                        child: BillSummaryCard(
                          title: 'Overdue',
                          amount: '₹${NumberFormat.compact().format(totalOverdue)}',
                          icon: Icons.warning_amber_rounded,
                          color: const Color(0xFFEF4444),
                          count: overdueBills.length,
                          onTap: () => _navigateToBillList(filter: 'overdue'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 160,
                        child: BillSummaryCard(
                          title: 'Paid This Month',
                          amount: '₹${NumberFormat.compact().format(paidThisMonth)}',
                          icon: Icons.check_circle,
                          color: const Color(0xFF22C55E),
                          count: BillStorageService.getPaidBills(
                            fromDate: DateTime(DateTime.now().year, DateTime.now().month, 1),
                          ).length,
                          onTap: () => _navigateToBillList(filter: 'paid'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Quick Actions
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
                    Expanded(
                      child: _buildQuickAction(
                        icon: Icons.calendar_month,
                        label: 'Calendar',
                        color: Colors.purple,
                        onTap: _showCalendarView,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickAction(
                        icon: Icons.analytics_outlined,
                        label: 'Analytics',
                        color: Colors.orange,
                        onTap: _showAnalytics,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickAction(
                        icon: Icons.category_outlined,
                        label: 'Categories',
                        color: Colors.teal,
                        onTap: _showCategories,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Upcoming Bills Preview
                UpcomingBillsPreview(
                  bills: upcomingBills.take(5).toList(),
                  onSeeAll: () => _navigateToBillList(filter: 'upcoming'),
                ),

                if (upcomingBills.isNotEmpty)
                  ...upcomingBills.take(5).map((bill) => BillCard(
                        bill: bill,
                        onTap: () => _navigateToBillDetail(bill),
                        onMarkPaid: () => _markAsPaid(bill),
                        onSnooze: () => _snoozeBill(bill),
                      )),

                const SizedBox(height: 80),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: CommonCard(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.getTextPrimary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addNewBill() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddBillScreen()),
    );
  }

  void _navigateToBillList({String? filter}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BillListScreen(initialFilter: filter),
      ),
    );
  }

  void _navigateToBillDetail(Bill bill) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BillDetailScreen(bill: bill),
      ),
    );
  }

  Future<void> _markAsPaid(Bill bill) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Paid'),
        content: Text('Mark "${bill.name}" as fully paid?'),
        actions: [
          CommonButton(
            text: 'Cancel',
            variant: ButtonVariant.secondary,
            onPressed: () => Navigator.pop(context, false),
          ),
          CommonButton(
            text: 'Mark Paid',
            variant: ButtonVariant.success,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await BillStorageService.markBillAsPaid(bill.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${bill.name} marked as paid'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _snoozeBill(Bill bill) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Snooze Reminder',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('1 Hour'),
                onTap: () => Navigator.pop(context, '1h'),
              ),
              ListTile(
                leading: const Icon(Icons.today),
                title: const Text('Tomorrow'),
                onTap: () => Navigator.pop(context, 'tomorrow'),
              ),
              ListTile(
                leading: const Icon(Icons.next_week),
                title: const Text('Next Week'),
                onTap: () => Navigator.pop(context, 'week'),
              ),
            ],
          ),
        ),
      ),
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reminder snoozed for ${bill.name}')),
      );
    }
  }

  void _showCalendarView() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppColors.getBackground(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: _BillCalendarView(scrollController: scrollController),
        ),
      ),
    );
  }

  void _showAnalytics() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppColors.getBackground(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: _BillAnalyticsView(scrollController: scrollController),
        ),
      ),
    );
  }

  void _showCategories() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _BillCategoriesScreen()),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _BillSettingsSheet(),
    );
  }
}

class _BillCalendarView extends StatefulWidget {
  final ScrollController scrollController;

  const _BillCalendarView({required this.scrollController});

  @override
  State<_BillCalendarView> createState() => _BillCalendarViewState();
}

class _BillCalendarViewState extends State<_BillCalendarView> {
  DateTime _selectedMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final bills = BillStorageService.filterByDateRange(
      DateTime(_selectedMonth.year, _selectedMonth.month, 1),
      DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0),
    );

    final billsByDate = <int, List<Bill>>{};
    for (final bill in bills) {
      final day = bill.dueDate.day;
      billsByDate[day] = [...(billsByDate[day] ?? []), bill];
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                  });
                },
              ),
              Text(
                DateFormat('MMMM yyyy').format(_selectedMonth),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                  });
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            controller: widget.scrollController,
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day + 
                       DateTime(_selectedMonth.year, _selectedMonth.month, 1).weekday - 1,
            itemBuilder: (context, index) {
              final firstWeekday = DateTime(_selectedMonth.year, _selectedMonth.month, 1).weekday - 1;
              
              if (index < firstWeekday) {
                return const SizedBox();
              }

              final day = index - firstWeekday + 1;
              final dayBills = billsByDate[day] ?? [];
              final hasOverdue = dayBills.any((b) => b.isOverdue);
              final hasDueToday = dayBills.any((b) => b.isDueToday);

              return GestureDetector(
                onTap: dayBills.isNotEmpty ? () => _showDayBills(day, dayBills) : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: dayBills.isNotEmpty
                        ? (hasOverdue
                            ? Colors.red.withValues(alpha: 0.2)
                            : hasDueToday
                                ? Colors.orange.withValues(alpha: 0.2)
                                : Colors.blue.withValues(alpha: 0.2))
                        : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          fontWeight: dayBills.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                          color: AppColors.getTextPrimary(context),
                        ),
                      ),
                      if (dayBills.isNotEmpty)
                        Text(
                          '${dayBills.length}',
                          style: TextStyle(
                            fontSize: 10,
                            color: hasOverdue ? Colors.red : Colors.blue,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showDayBills(int day, List<Bill> bills) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bills on ${DateFormat('MMMM d').format(DateTime(_selectedMonth.year, _selectedMonth.month, day))}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: 16),
              ...bills.map((bill) => BillCard(bill: bill)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BillAnalyticsView extends StatelessWidget {
  final ScrollController scrollController;

  const _BillAnalyticsView({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    final monthlyTotal = BillStorageService.getMonthlyTotal();
    final yearlyTotal = BillStorageService.getYearlyTotal();
    final onTimePercentage = BillStorageService.getOnTimePaymentPercentage();
    final largestBill = BillStorageService.getLargestBill();
    final mostFrequent = BillStorageService.getMostFrequentBillName();

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Text(
          'Bill Analytics',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.getTextPrimary(context),
          ),
        ),
        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                'This Month',
                '₹${NumberFormat('#,##,###').format(monthlyTotal)}',
                Icons.calendar_today,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                context,
                'This Year',
                '₹${NumberFormat('#,##,###').format(yearlyTotal)}',
                Icons.calendar_month,
                Colors.purple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                'On-Time Rate',
                '${onTimePercentage.toStringAsFixed(0)}%',
                Icons.timer,
                onTimePercentage >= 80 ? Colors.green : Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                context,
                'Largest Bill',
                largestBill != null
                    ? '₹${NumberFormat('#,##,###').format(largestBill.amount)}'
                    : 'N/A',
                Icons.trending_up,
                Colors.red,
              ),
            ),
          ],
        ),

        if (mostFrequent != null) ...[
          const SizedBox(height: 24),
          CommonCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.repeat, color: Colors.teal, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Most Frequent Bill',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                      Text(
                        mostFrequent,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getTextPrimary(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return CommonCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.getTextSecondary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextPrimary(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _BillCategoriesScreen extends StatelessWidget {
  const _BillCategoriesScreen();

  @override
  Widget build(BuildContext context) {
    final categories = BillStorageService.getAllCategories();

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: const Text('Bill Categories'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.getTextPrimary(context),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final billCount = BillStorageService.filterByCategory(category.id).length;

          return CommonCard(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: category.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(category.icon, color: category.color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextPrimary(context),
                        ),
                      ),
                      Text(
                        '$billCount bills',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                if (category.isCustom)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await BillStorageService.deleteCategory(category.id);
                    },
                    color: Colors.red,
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addCategory(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _addCategory(BuildContext context) {
    final nameController = TextEditingController();
    Color selectedColor = Colors.blue;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Category Name',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final category = BillCategory(
                  name: nameController.text,
                  colorValue: selectedColor.value,
                  iconCodePoint: Icons.category.codePoint,
                  isCustom: true,
                );
                await BillStorageService.saveCategory(category);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _BillSettingsSheet extends StatefulWidget {
  @override
  State<_BillSettingsSheet> createState() => _BillSettingsSheetState();
}

class _BillSettingsSheetState extends State<_BillSettingsSheet> {
  late int _defaultReminderDays;
  late int _defaultReminderHour;
  late int _autoArchiveDays;

  @override
  void initState() {
    super.initState();
    _defaultReminderDays = BillStorageService.defaultReminderDays;
    _defaultReminderHour = BillStorageService.defaultReminderHour;
    _autoArchiveDays = BillStorageService.autoArchivePaidDays;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bill Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 24),

            CommonCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Default Reminder',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextPrimary(context),
                        ),
                      ),
                      Text(
                        '$_defaultReminderDays days before',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: _defaultReminderDays > 1
                            ? () {
                                setState(() => _defaultReminderDays--);
                                BillStorageService.setDefaultReminderDays(_defaultReminderDays);
                              }
                            : null,
                      ),
                      Text('$_defaultReminderDays'),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: _defaultReminderDays < 30
                            ? () {
                                setState(() => _defaultReminderDays++);
                                BillStorageService.setDefaultReminderDays(_defaultReminderDays);
                              }
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            CommonCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reminder Time',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextPrimary(context),
                        ),
                      ),
                      Text(
                        '${_defaultReminderHour > 12 ? _defaultReminderHour - 12 : _defaultReminderHour}:00 ${_defaultReminderHour >= 12 ? 'PM' : 'AM'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(hour: _defaultReminderHour, minute: 0),
                      );
                      if (time != null) {
                        setState(() => _defaultReminderHour = time.hour);
                        BillStorageService.setDefaultReminderTime(time.hour, 0);
                      }
                    },
                    child: const Text('Change'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            CommonCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Auto Archive Paid Bills',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextPrimary(context),
                        ),
                      ),
                      Text(
                        'After $_autoArchiveDays days',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                  DropdownButton<int>(
                    value: _autoArchiveDays,
                    items: [7, 14, 30, 60, 90]
                        .map((d) => DropdownMenuItem(
                              value: d,
                              child: Text('$d days'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _autoArchiveDays = value);
                        BillStorageService.setAutoArchivePaidDays(value);
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
