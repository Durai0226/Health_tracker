import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/beverage_type.dart';
import '../models/enhanced_water_log.dart';
import '../models/water_container.dart';
import '../services/water_service.dart';
import '../../../core/widgets/app/app_widgets.dart';

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
    final ext = AppColorsExt.of(context);
    AppBottomSheet.show(
      context,
      title: 'Add Entry',
      icon: Icons.local_drink_rounded,
      accent: ext.water,
      builder: (sheetCtx) => _AddEditEntrySheet(
        date: widget.date,
        onSaved: () async {
          await _loadData();
          if (sheetCtx.mounted) {
            Navigator.pop(sheetCtx);
          }
        },
      ),
    );
  }

  void _showEditEntryDialog(EnhancedWaterLog log) {
    final ext = AppColorsExt.of(context);
    AppBottomSheet.show(
      context,
      title: 'Edit Entry',
      icon: Icons.edit_rounded,
      accent: ext.water,
      builder: (sheetCtx) => _AddEditEntrySheet(
        date: widget.date,
        existingLog: log,
        onSaved: () async {
          await _loadData();
          if (sheetCtx.mounted) {
            Navigator.pop(sheetCtx);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final goal = WaterService.getDailyGoal();
    final progress = _dayData != null && goal > 0
        ? (_dayData!.effectiveHydrationMl / goal).clamp(0.0, 1.5)
        : 0.0;

    return AppScaffold(
      floatingActionButton: AppFab(
        icon: Icons.add_rounded,
        label: 'Add Entry',
        accent: ext.water,
        onPressed: _showAddEntryDialog,
      ),
      body: Column(
        children: [
          AppHeader(
            title: 'Edit History',
            accent: ext.water,
            leading: AppIconButton(
              icon: Icons.arrow_back_rounded,
              filled: false,
              accent: ext.water,
              onPressed: () => Navigator.pop(context, true),
            ),
            actions: [
              AppButton(
                label: 'Add',
                variant: AppButtonVariant.tonal,
                size: AppButtonSize.sm,
                accent: ext.water,
                leadingIcon: Icons.add_rounded,
                onPressed: _showAddEntryDialog,
              ),
            ],
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDateHeader(),
                        const SizedBox(height: AppSpacing.lg),
                        _buildProgressCard(progress, goal),
                        const SizedBox(height: AppSpacing.xl),
                        _buildEntriesList(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader() {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final isToday = widget.date.day == DateTime.now().day &&
        widget.date.month == DateTime.now().month &&
        widget.date.year == DateTime.now().year;

    return AppCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ext.water.container,
              borderRadius: AppRadius.brMd,
            ),
            child: Icon(Icons.calendar_today_rounded, color: ext.water.onContainer),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(widget.date),
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (isToday) ...[
                  const SizedBox(height: 6),
                  AppChip(
                    label: 'Today',
                    selected: true,
                    accent: ext.water,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(double progress, int goal) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final currentMl = _dayData?.effectiveHydrationMl ?? 0;
    final rawMl = _dayData?.totalIntakeMl ?? 0;
    final reached = progress >= 1;
    final accent = reached ? ext.success : ext.water;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProgressRing(
                progress: progress.clamp(0.0, 1.0),
                size: 84,
                stroke: 9,
                accent: accent,
                center: Text(
                  '${(progress * 100).toInt()}%',
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: ext.mark(accent),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${currentMl}ml',
                      style: tt.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: ext.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'of ${goal}ml goal',
                      style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ClipRRect(
            borderRadius: AppRadius.brFull,
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: accent.container,
              valueColor: AlwaysStoppedAnimation(ext.mark(accent)),
              minHeight: 8,
            ),
          ),
          if (rawMl != currentMl) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Raw intake: ${rawMl}ml (Effective: ${currentMl}ml)',
              style: tt.bodySmall?.copyWith(color: ext.textTertiary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEntriesList() {
    final ext = AppColorsExt.of(context);
    final logs = _dayData?.logs ?? [];

    if (logs.isEmpty) {
      return AppCard(
        child: EmptyState(
          icon: Icons.water_drop_outlined,
          title: 'No entries for this day',
          message: 'Tap the button below to add an entry',
          accent: ext.water,
        ),
      );
    }

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter, AppSpacing.gutter, AppSpacing.gutter, AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: SectionHeader(
                    title: 'Drink Entries',
                    icon: Icons.local_drink_rounded,
                    accent: ext.water,
                  ),
                ),
                CountBadge(count: logs.length, accent: ext.water),
              ],
            ),
          ),
          Divider(height: 1, color: ext.outline),
          ...logs.reversed.map((log) => _buildLogItem(log)),
        ],
      ),
    );
  }

  Widget _buildLogItem(EnhancedWaterLog log) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final time = '${log.time.hour.toString().padLeft(2, '0')}:${log.time.minute.toString().padLeft(2, '0')}';

    return Dismissible(
      key: Key(log.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.gutter),
        color: ext.error.base,
        child: Icon(Icons.delete_rounded, color: ext.error.on),
      ),
      confirmDismiss: (direction) async {
        return await AppBottomSheet.confirm(
          context,
          title: 'Delete Entry',
          message: 'Delete ${log.amountMl}ml of ${log.beverageName}?',
          confirmLabel: 'Delete',
          danger: true,
          icon: Icons.delete_outline_rounded,
        );
      },
      onDismissed: (direction) async {
        try {
          await WaterService.removeWaterLogForDate(widget.date, log.id);
          await _loadData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Entry deleted successfully'),
                backgroundColor: ext.success.base,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error deleting entry: $e'),
                backgroundColor: ext.error.base,
              ),
            );
            await _loadData();
          }
        }
      },
      child: InkWell(
        onTap: () => _showEditEntryDialog(log),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: ext.outline),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: ext.water.container,
                  borderRadius: AppRadius.brMd,
                ),
                child: Center(
                  child: Text(log.beverageEmoji, style: const TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            log.beverageName,
                            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          time,
                          style: tt.bodySmall?.copyWith(color: ext.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '+${log.amountMl}ml',
                          style: tt.bodyMedium?.copyWith(
                            color: ext.mark(ext.water),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (log.hydrationPercent != 100)
                          _miniBadge(
                            '${log.hydrationPercent}% → ${log.effectiveHydrationMl}ml',
                            log.effectiveHydrationMl >= 0 ? ext.success : ext.error,
                          ),
                        if (log.caffeineAmount > 0)
                          _miniBadge('☕ ${log.caffeineAmount}mg', ext.warning),
                      ],
                    ),
                    if (log.note != null && log.note!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        log.note!,
                        style: tt.bodySmall?.copyWith(
                          color: ext.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.edit_outlined,
                size: 18,
                color: ext.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniBadge(String text, AccentSwatch swatch) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: swatch.container,
        borderRadius: AppRadius.brSm,
      ),
      child: Text(
        text,
        style: tt.labelSmall?.copyWith(fontSize: 10, color: swatch.onContainer),
      ),
    );
  }
}

/// Bottom sheet content for adding/editing water entries.
/// Chrome (handle, title, surface) is supplied by [AppBottomSheet].
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
    final ext = AppColorsExt.of(context);
    final amount = int.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please enter a valid amount'),
            backgroundColor: ext.error.base,
          ),
        );
      }
      return;
    }

    if (amount > 5000) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Amount cannot exceed 5000ml'),
            backgroundColor: ext.error.base,
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
            SnackBar(
              content: const Text('Entry updated successfully'),
              backgroundColor: ext.success.base,
              duration: const Duration(seconds: 2),
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
            SnackBar(
              content: const Text('Entry added successfully'),
              backgroundColor: ext.success.base,
              duration: const Duration(seconds: 2),
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
            backgroundColor: ext.error.base,
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
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Beverage selector
        Text('Beverage', style: tt.labelLarge?.copyWith(color: ext.textSecondary)),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 82,
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
                  width: 72,
                  margin: const EdgeInsets.only(right: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: isSelected ? ext.water.container : ext.surfaceVariant,
                    borderRadius: AppRadius.brMd,
                    border: Border.all(
                      color: isSelected ? ext.mark(ext.water) : ext.outline,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(beverage.emoji, style: const TextStyle(fontSize: 24)),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          beverage.name,
                          style: tt.labelSmall?.copyWith(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? ext.water.onContainer : ext.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // Amount + time
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                controller: _amountController,
                label: 'Amount (ml)',
                hint: 'Enter amount',
                keyboardType: TextInputType.number,
                accent: ext.water,
                suffix: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Text(
                    'ml',
                    style: tt.bodyMedium?.copyWith(color: ext.textTertiary),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Time',
                      style: tt.labelLarge?.copyWith(color: ext.textSecondary)),
                  const SizedBox(height: AppSpacing.sm),
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
                        color: ext.surfaceVariant,
                        borderRadius: AppRadius.brMd,
                        border: Border.all(color: ext.outline),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 20, color: ext.textTertiary),
                          const SizedBox(width: AppSpacing.sm),
                          Text(_selectedTime.format(context),
                              style: tt.bodyLarge?.copyWith(color: ext.textPrimary)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        // Quick amount buttons
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [100, 150, 250, 350, 500, 750].map((amount) {
            return AppChip(
              label: '${amount}ml',
              accent: ext.water,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _amountController.text = amount.toString());
              },
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.xl),

        // Note input
        AppTextField(
          controller: _noteController,
          label: 'Note (optional)',
          hint: 'Add a note...',
          accent: ext.water,
        ),
        const SizedBox(height: AppSpacing.xl),

        // Hydration info
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: ext.water.container,
            borderRadius: AppRadius.brMd,
          ),
          child: Row(
            children: [
              Text(_selectedBeverage.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hydration: ${_selectedBeverage.hydrationPercent}%',
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: ext.water.onContainer,
                      ),
                    ),
                    Text(
                      'Effective: ${(_selectedBeverage.getEffectiveHydration(int.tryParse(_amountController.text) ?? 0))}ml',
                      style: tt.bodySmall?.copyWith(
                        color: ext.water.onContainer.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              if (_selectedBeverage.hasCaffeine)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ext.warning.container,
                    borderRadius: AppRadius.brSm,
                  ),
                  child: Text(
                    '☕ ${(_selectedBeverage.caffeinePerMl * (int.tryParse(_amountController.text) ?? 0) / 100).round()}mg',
                    style: tt.labelMedium?.copyWith(color: ext.warning.onContainer),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // Save button
        AppButton(
          label: widget.existingLog != null ? 'Update Entry' : 'Add Entry',
          accent: ext.water,
          size: AppButtonSize.lg,
          fullWidth: true,
          loading: _isSaving,
          onPressed: _isSaving ? null : _save,
        ),
      ],
    );
  }
}
