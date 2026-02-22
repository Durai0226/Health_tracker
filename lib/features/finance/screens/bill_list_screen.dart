import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/bill.dart';
import '../models/bill_enums.dart';
import '../services/bill_storage_service.dart';
import '../widgets/bill_widgets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/common_tab_widgets.dart';
import 'add_bill_screen.dart';
import 'bill_detail_screen.dart';

class BillListScreen extends StatefulWidget {
  final String? initialFilter;

  const BillListScreen({super.key, this.initialFilter});

  @override
  State<BillListScreen> createState() => _BillListScreenState();
}

class _BillListScreenState extends State<BillListScreen> {
  String _currentFilter = 'all';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialFilter != null) {
      _currentFilter = widget.initialFilter!;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Bill> _getFilteredBills() {
    List<Bill> bills;

    switch (_currentFilter) {
      case 'upcoming':
        bills = BillStorageService.getUpcomingBills(days: 30);
        break;
      case 'due_today':
        bills = BillStorageService.getDueTodayBills();
        break;
      case 'overdue':
        bills = BillStorageService.getOverdueBills();
        break;
      case 'paid':
        bills = BillStorageService.getPaidBills();
        break;
      case 'archived':
        bills = BillStorageService.getArchivedBills();
        break;
      default:
        bills = BillStorageService.getActiveBills();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      bills = bills.where((b) {
        return b.name.toLowerCase().contains(query) ||
            (b.note?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    return bills;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: const Text('All Bills'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.getTextPrimary(context),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: CommonCard(
              padding: EdgeInsets.zero,
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search bills...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'All'),
                  _buildFilterChip('upcoming', 'Upcoming'),
                  _buildFilterChip('due_today', 'Due Today'),
                  _buildFilterChip('overdue', 'Overdue'),
                  _buildFilterChip('paid', 'Paid'),
                  _buildFilterChip('archived', 'Archived'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: ValueListenableBuilder<Box<Bill>>(
              valueListenable: BillStorageService.billsListenable!,
              builder: (context, box, _) {
                final bills = _getFilteredBills();

                if (bills.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: bills.length,
                  itemBuilder: (context, index) {
                    final bill = bills[index];
                    return BillCard(
                      bill: bill,
                      onTap: () => _navigateToBillDetail(bill),
                      onMarkPaid: () => _markAsPaid(bill),
                      onSnooze: () => _snoozeBill(bill),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddBillScreen()),
        ),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildFilterChip(String filter, String label) {
    final isSelected = _currentFilter == filter;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _currentFilter = filter),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.getCardBg(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.getTextPrimary(context),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;

    switch (_currentFilter) {
      case 'upcoming':
        message = 'No upcoming bills';
        icon = Icons.event_available;
        break;
      case 'due_today':
        message = 'No bills due today';
        icon = Icons.today;
        break;
      case 'overdue':
        message = 'No overdue bills';
        icon = Icons.check_circle;
        break;
      case 'paid':
        message = 'No paid bills yet';
        icon = Icons.payment;
        break;
      case 'archived':
        message = 'No archived bills';
        icon = Icons.archive;
        break;
      default:
        message = _searchQuery.isNotEmpty
            ? 'No bills match your search'
            : 'No bills yet';
        icon = Icons.receipt_long;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.getTextSecondary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add a new bill',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.getTextSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.sort),
              title: const Text('Sort by Due Date'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.sort_by_alpha),
              title: const Text('Sort by Name'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.attach_money),
              title: const Text('Sort by Amount'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.date_range),
              title: const Text('Filter by Date Range'),
              onTap: () {
                Navigator.pop(context);
                _showDateRangeFilter();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDateRangeFilter() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (range != null) {
      final bills = BillStorageService.filterByDateRange(range.start, range.end);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Found ${bills.length} bills in range')),
        );
      }
    }
  }

  void _navigateToBillDetail(Bill bill) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BillDetailScreen(bill: bill)),
    );
  }

  Future<void> _markAsPaid(Bill bill) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Paid'),
        content: Text('Mark "${bill.name}" as fully paid?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Mark Paid'),
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

  void _snoozeBill(Bill bill) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Reminder snoozed for ${bill.name}')),
    );
  }
}
