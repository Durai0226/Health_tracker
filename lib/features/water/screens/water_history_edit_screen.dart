import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../models/beverage_type.dart';
import '../models/enhanced_water_log.dart';
import '../models/water_container.dart';
import '../services/water_service.dart';
import '../../../core/widgets/common_widgets.dart';

/// Screen for editing water history - add/edit/delete entries for any date
class WaterHistoryEditScreen extends StatefulWidget {
  final DateTime date;
  
  const WaterHistoryEditScreen({super.key, required this.date});

  @override
  State<WaterHistoryEditScreen> createState() => _WaterHistoryEditScreenState();
}

class _WaterHistoryEditScreenState extends State<WaterHistoryEditScreen> {
  DailyWaterData? _dayData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await WaterService.init();
    final dateKey = '${widget.date.year}-${widget.date.month.toString().padLeft(2, '0')}-${widget.date.day.toString().padLeft(2, '0')}';
    _dayData = WaterService.getDataForDate(widget.date) ?? DailyWaterData(
      id: dateKey,
      date: widget.date,
      dailyGoalMl: WaterService.getDailyGoal(),
    );
    if (mounted) setState(() => _isLoading = false);
  }

  String _formatDate(DateTime date) {
    final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 
                        'July', 'August', 'September', 'October', 'November', 'December'];
    return '${dayNames[date.weekday - 1]}, ${monthNames[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _showAddEntryDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddEditEntrySheet(
        date: widget.date,
        onSaved: () async {
          await _loadData();
          if (context.mounted) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  void _showEditEntryDialog(EnhancedWaterLog log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddEditEntrySheet(
        date: widget.date,
        existingLog: log,
        onSaved: () async {
          await _loadData();
          if (context.mounted) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final goal = WaterService.getDailyGoal();
    final progress = _dayData != null && goal > 0 
        ? (_dayData!.effectiveHydrationMl / goal).clamp(0.0, 1.5) 
        : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: const Text('Edit History'),
        actions: [
          CommonButton(
            text: 'Add Entry',
            variant: ButtonVariant.secondary,
            onPressed: _showAddEntryDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDateHeader(),
                  const SizedBox(height: 16),
                  _buildProgressCard(progress, goal),
                  const SizedBox(height: 24),
                  _buildEntriesList(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
      floatingActionButton: CommonButton(
        text: 'Add Entry',
        variant: ButtonVariant.primary,
        onPressed: _showAddEntryDialog,
        backgroundColor: AppColors.info,
        icon: Icons.add,
      ),
    );
  }

  Widget _buildDateHeader() {
    final isToday = widget.date.day == DateTime.now().day &&
        widget.date.month == DateTime.now().month &&
        widget.date.year == DateTime.now().year;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.calendar_today, color: AppColors.info),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(widget.date),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isToday)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Today',
                      style: TextStyle(
                        color: AppColors.info,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(double progress, int goal) {
    final currentMl = _dayData?.effectiveHydrationMl ?? 0;
    final rawMl = _dayData?.totalIntakeMl ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: progress >= 1
              ? [AppColors.success, AppColors.success.withOpacity(0.8)]
              : [AppColors.info, AppColors.info.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (progress >= 1 ? AppColors.success : AppColors.info).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${currentMl}ml',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'of ${goal}ml goal',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${(progress * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
              minHeight: 8,
            ),
          ),
          if (rawMl != currentMl) ...[
            const SizedBox(height: 12),
            Text(
              'Raw intake: ${rawMl}ml (Effective: ${currentMl}ml)',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEntriesList() {
    final logs = _dayData?.logs ?? [];

    if (logs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(
              Icons.water_drop_outlined,
              size: 64,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'No entries for this day',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the button below to add an entry',
              style: TextStyle(
                color: AppColors.textSecondary.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Drink Entries',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${logs.length} entries',
                    style: const TextStyle(
                      color: AppColors.info,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...logs.reversed.map((log) => _buildLogItem(log)),
        ],
      ),
    );
  }

  Widget _buildLogItem(EnhancedWaterLog log) {
    final time = '${log.time.hour.toString().padLeft(2, '0')}:${log.time.minute.toString().padLeft(2, '0')}';

    return Dismissible(
      key: Key(log.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Entry'),
            content: Text('Delete ${log.amountMl}ml of ${log.beverageName}?'),
            actions: [
              CommonButton(
                text: 'Cancel',
                variant: ButtonVariant.secondary,
                onPressed: () => Navigator.pop(context, false),
              ),
              CommonButton(
                text: 'Delete',
                variant: ButtonVariant.danger,
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        try {
          await WaterService.removeWaterLogForDate(widget.date, log.id);
          await _loadData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Entry deleted successfully'),
                backgroundColor: AppColors.success,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error deleting entry: $e'),
                backgroundColor: AppColors.error,
              ),
            );
            await _loadData();
          }
        }
      },
      child: InkWell(
        onTap: () => _showEditEntryDialog(log),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade100),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(log.beverageEmoji, style: const TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            log.beverageName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          time,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '+${log.amountMl}ml',
                          style: const TextStyle(
                            color: AppColors.info,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (log.hydrationPercent != 100) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: log.effectiveHydrationMl >= 0
                                  ? AppColors.success.withOpacity(0.1)
                                  : AppColors.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${log.hydrationPercent}% → ${log.effectiveHydrationMl}ml',
                              style: TextStyle(
                                fontSize: 10,
                                color: log.effectiveHydrationMl >= 0
                                    ? AppColors.success
                                    : AppColors.error,
                              ),
                            ),
                          ),
                        ],
                        if (log.caffeineAmount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.brown.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '☕ ${log.caffeineAmount}mg',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.brown.shade700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (log.note != null && log.note!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        log.note!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.edit_outlined,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for adding/editing water entries
class _AddEditEntrySheet extends StatefulWidget {
  final DateTime date;
  final EnhancedWaterLog? existingLog;
  final Future<void> Function() onSaved;

  const _AddEditEntrySheet({
    required this.date,
    this.existingLog,
    required this.onSaved,
  });

  @override
  State<_AddEditEntrySheet> createState() => _AddEditEntrySheetState();
}

class _AddEditEntrySheetState extends State<_AddEditEntrySheet> {
  late BeverageType _selectedBeverage;
  WaterContainer? _selectedContainer;
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isSaving = false;

  List<BeverageType> _beverages = [];
  List<WaterContainer> _containers = [];

  @override
  void initState() {
    super.initState();
    _beverages = WaterService.getAllBeverages();
    _containers = WaterService.getAllContainers();
    
    if (_beverages.isEmpty) {
      _beverages = BeverageType.defaultBeverages;
    }
    
    if (widget.existingLog != null) {
      final log = widget.existingLog!;
      _selectedBeverage = _beverages.firstWhere(
        (b) => b.id == log.beverageId,
        orElse: () => _beverages.first,
      );
      _amountController = TextEditingController(text: log.amountMl.toString());
      _noteController = TextEditingController(text: log.note ?? '');
      _selectedTime = TimeOfDay(hour: log.time.hour, minute: log.time.minute);
      if (log.containerId != null && _containers.isNotEmpty) {
        try {
          _selectedContainer = _containers.firstWhere(
            (c) => c.id == log.containerId,
          );
        } catch (e) {
          _selectedContainer = null;
        }
      }
    } else {
      _selectedBeverage = _beverages.firstWhere(
        (b) => b.id == 'water',
        orElse: () => _beverages.first,
      );
      _amountController = TextEditingController(text: '250');
      _noteController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = int.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid amount'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    if (amount > 5000) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Amount cannot exceed 5000ml'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    try {
      final time = DateTime(
        widget.date.year,
        widget.date.month,
        widget.date.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      if (widget.existingLog != null) {
        await WaterService.updateWaterLogForDate(
          date: widget.date,
          logId: widget.existingLog!.id,
          amountMl: amount,
          beverage: _selectedBeverage,
          container: _selectedContainer,
          time: time,
          note: _noteController.text.isNotEmpty ? _noteController.text : null,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Entry updated successfully'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        await WaterService.addWaterLogForDate(
          date: widget.date,
          amountMl: amount,
          beverage: _selectedBeverage,
          container: _selectedContainer,
          time: time,
          note: _noteController.text.isNotEmpty ? _noteController.text : null,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Entry added successfully'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }

      await widget.onSaved();
    } catch (e) {
      debugPrint('Error saving water entry: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.existingLog != null ? 'Edit Entry' : 'Add Entry',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            
            // Beverage selector
            const Text(
              'Beverage',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _beverages.length,
                itemBuilder: (context, index) {
                  final beverage = _beverages[index];
                  final isSelected = beverage.id == _selectedBeverage.id;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedBeverage = beverage;
                        _amountController.text = beverage.defaultAmountMl.toString();
                      });
                    },
                    child: Container(
                      width: 70,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.info.withOpacity(0.1) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected ? Border.all(color: AppColors.info, width: 2) : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(beverage.emoji, style: const TextStyle(fontSize: 24)),
                          const SizedBox(height: 4),
                          Text(
                            beverage.name,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected ? AppColors.info : AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Amount input
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Amount (ml)',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Enter amount',
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          suffixText: 'ml',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Time',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: _selectedTime,
                          );
                          if (time != null) {
                            setState(() => _selectedTime = time);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time, size: 20),
                              const SizedBox(width: 8),
                              Text(_selectedTime.format(context)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Quick amount buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [100, 150, 250, 350, 500, 750].map((amount) {
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _amountController.text = amount.toString();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${amount}ml',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Note input
            const Text(
              'Note (optional)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                hintText: 'Add a note...',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Hydration info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(_selectedBeverage.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hydration: ${_selectedBeverage.hydrationPercent}%',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Effective: ${(_selectedBeverage.getEffectiveHydration(int.tryParse(_amountController.text) ?? 0))}ml',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_selectedBeverage.hasCaffeine)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.brown.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '☕ ${(_selectedBeverage.caffeinePerMl * (int.tryParse(_amountController.text) ?? 0) / 100).round()}mg',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.brown.shade700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: CommonButton(
                text: widget.existingLog != null ? 'Update Entry' : 'Add Entry',
                variant: ButtonVariant.primary,
                backgroundColor: AppColors.info,
                isLoading: _isSaving,
                onPressed: _isSaving ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
