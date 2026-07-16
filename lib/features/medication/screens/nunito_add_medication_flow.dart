import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../widgets/nunito_pill_visual.dart';
import '../models/enhanced_medicine.dart';
import '../models/medicine_enums.dart';
import '../models/medicine_schedule.dart';
import '../services/medicine_storage_service.dart';
import '../services/medication_reminder_service.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/app/app_widgets.dart';

/// How the end of a medication course is expressed in the wizard.
enum _DurationMode { ongoing, endDate, duration }

class NunitoAddMedicationFlow extends StatefulWidget {
  final EnhancedMedicine? editMedicine;

  const NunitoAddMedicationFlow({super.key, this.editMedicine});

  @override
  State<NunitoAddMedicationFlow> createState() => _NunitoAddMedicationFlowState();
}

class _NunitoAddMedicationFlowState extends State<NunitoAddMedicationFlow>
    with TickerProviderStateMixin {
  int _currentStep = 0;
  final int _totalSteps = 5;
  bool _isLoading = false;

  // Step 1: Basic Info
  final _nameController = TextEditingController();
  DosageForm _selectedForm = DosageForm.tablet;

  // Step 2: Dosage
  final _dosageController = TextEditingController(text: '1');
  final _strengthController = TextEditingController();
  String _dosageUnit = 'pill(s)';

  // Step 2: Stock & refill (optional — blank quantity means untracked)
  final _stockController = TextEditingController();
  int _lowStockThreshold = 7;
  bool _refillReminderEnabled = false;

  // Step 3: Schedule
  FrequencyType _frequencyType = FrequencyType.onceDaily;
  List<TimeOfDay> _scheduleTimes = [const TimeOfDay(hour: 8, minute: 0)];
  List<int> _selectedDays = [1, 2, 3, 4, 5, 6, 7]; // All days
  int _intervalHours = 8; // everyXHours
  int _intervalDays = 2; // everyXDays
  int _cycleDaysOn = 21; // cyclical on-days
  int _cycleDaysOff = 7; // cyclical off-days
  int _maxDailyDoses = 4; // PRN
  int _minHoursBetweenDoses = 4; // PRN
  MealTiming _mealTiming = MealTiming.anytime;
  DateTime _startDate = DateTime.now();
  // Duration mode: ongoing (no end), until an end date, or a fixed # of days.
  _DurationMode _durationMode = _DurationMode.ongoing;
  DateTime? _endDate;
  int _durationDays = 30;

  bool get _isPRN => _frequencyType == FrequencyType.asNeeded;

  // Step 4: Appearance
  MedicineColor? _selectedColor;
  MedicineShape? _selectedShape;

  // Step 5: Additional
  final _instructionsController = TextEditingController();
  final _purposeController = TextEditingController();
  bool _reminderEnabled = true;

  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  final HapticService _hapticService = HapticService();
  final MedicationReminderService _reminderService = MedicationReminderService();
  final PageController _pageController = PageController();

  bool get _isEditing => widget.editMedicine != null;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOut),
    );

    if (_isEditing) {
      _loadExistingMedicine();
    }
    _updateProgress();
  }

  void _loadExistingMedicine() {
    final m = widget.editMedicine!;
    _nameController.text = m.name;
    _selectedForm = m.dosageForm;
    _dosageController.text = m.dosageAmount.toString();
    _strengthController.text = m.strength ?? '';
    _dosageUnit = m.dosageUnit ?? m.dosageForm.unit;
    // Stock: treat a stored 0 as "untracked" so the field starts blank rather
    // than pre-filling a meaningless zero (the mapper defaults untracked to 0).
    _stockController.text =
        (m.currentStock != null && m.currentStock! > 0) ? '${m.currentStock}' : '';
    _lowStockThreshold = m.lowStockThreshold ?? 7;
    _refillReminderEnabled = m.refillReminderEnabled;
    final sched = m.schedule;
    _frequencyType = sched.frequencyType;
    _scheduleTimes = sched.times.map((t) => TimeOfDay(hour: t.hour, minute: t.minute)).toList();
    if (_scheduleTimes.isEmpty && !_isPRN) {
      _scheduleTimes = [const TimeOfDay(hour: 8, minute: 0)];
    }
    _selectedDays = sched.specificDays ?? [1, 2, 3, 4, 5, 6, 7];
    _intervalHours = sched.intervalHours ?? 8;
    _intervalDays = sched.intervalDays ?? 2;
    _cycleDaysOn = sched.cycleDaysOn ?? 21;
    _cycleDaysOff = sched.cycleDaysOff ?? 7;
    _maxDailyDoses = sched.maxDailyDoses ?? 4;
    _minHoursBetweenDoses = sched.minHoursBetweenDoses ?? 4;
    _mealTiming = sched.mealTiming;
    _startDate = sched.startDate ?? DateTime.now();
    _endDate = sched.endDate;
    if (sched.durationDays != null) {
      _durationMode = _DurationMode.duration;
      _durationDays = sched.durationDays!;
    } else if (sched.endDate != null) {
      _durationMode = _DurationMode.endDate;
    } else {
      _durationMode = _DurationMode.ongoing;
    }
    _selectedColor = m.color;
    _selectedShape = m.shape;
    _instructionsController.text = m.instructions ?? '';
    _purposeController.text = m.purpose ?? '';
    _reminderEnabled = m.reminderEnabled;
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pageController.dispose();
    _nameController.dispose();
    _dosageController.dispose();
    _strengthController.dispose();
    _stockController.dispose();
    _instructionsController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  void _updateProgress() {
    _progressController.animateTo((_currentStep + 1) / _totalSteps);
  }

  void _nextStep() {
    if (!_validateCurrentStep()) return;

    _hapticService.light();
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: AppMotion.base,
        curve: Curves.easeOutCubic,
      );
      _updateProgress();
    } else {
      _saveMedicine();
    }
  }

  void _previousStep() {
    _hapticService.light();
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: AppMotion.base,
        curve: Curves.easeOutCubic,
      );
      _updateProgress();
    } else {
      Navigator.pop(context);
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_nameController.text.trim().isEmpty) {
          _showError('Please enter a medication name');
          return false;
        }
        return true;
      case 1:
        if (_dosageController.text.isEmpty || double.tryParse(_dosageController.text) == null) {
          _showError('Please enter a valid dosage');
          return false;
        }
        return true;
      case 2:
        if (_frequencyType == FrequencyType.asNeeded) {
          return true; // PRN needs no fixed times
        }
        if (_frequencyType == FrequencyType.specificDays &&
            _selectedDays.isEmpty) {
          _showError('Please select at least one day');
          return false;
        }
        if (_scheduleTimes.isEmpty) {
          _showError('Please add at least one time');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _showError(String message) {
    _hapticService.error();
    final ext = AppColorsExt.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ext.fillBg(ext.error),
      ),
    );
  }

  Future<void> _saveMedicine() async {
    setState(() => _isLoading = true);

    try {
      final scheduleTimesList = _isPRN
          ? <ScheduledTime>[]
          : _scheduleTimes
              .map((t) => ScheduledTime(hour: t.hour, minute: t.minute))
              .toList();

      final schedule = MedicineSchedule(
        frequencyType: _frequencyType,
        times: scheduleTimesList,
        intervalHours:
            _frequencyType == FrequencyType.everyXHours ? _intervalHours : null,
        intervalDays:
            _frequencyType == FrequencyType.everyXDays ? _intervalDays : null,
        specificDays: _frequencyType == FrequencyType.specificDays
            ? _selectedDays
            : null,
        cycleDaysOn:
            _frequencyType == FrequencyType.cyclical ? _cycleDaysOn : null,
        cycleDaysOff:
            _frequencyType == FrequencyType.cyclical ? _cycleDaysOff : null,
        startDate: _startDate,
        endDate: _durationMode == _DurationMode.endDate ? _endDate : null,
        durationDays:
            _durationMode == _DurationMode.duration ? _durationDays : null,
        mealTiming: _mealTiming,
        isPRN: _isPRN,
        maxDailyDoses: _isPRN ? _maxDailyDoses : null,
        minHoursBetweenDoses: _isPRN ? _minHoursBetweenDoses : null,
      );

      final medicine = EnhancedMedicine(
        id: _isEditing ? widget.editMedicine!.id : const Uuid().v4(),
        name: _nameController.text.trim(),
        dosageForm: _selectedForm,
        dosageAmount: double.parse(_dosageController.text),
        dosageUnit: _dosageUnit,
        strength: _strengthController.text.isNotEmpty ? _strengthController.text : null,
        currentStock: _stockController.text.trim().isNotEmpty
            ? int.tryParse(_stockController.text.trim())
            : null,
        lowStockThreshold: _lowStockThreshold,
        refillReminderEnabled: _refillReminderEnabled,
        schedule: schedule,
        color: _selectedColor,
        shape: _selectedShape,
        instructions: _instructionsController.text.isNotEmpty ? _instructionsController.text : null,
        purpose: _purposeController.text.isNotEmpty ? _purposeController.text : null,
        reminderEnabled: _reminderEnabled,
        isActive: true,
        isArchived: false,
        createdAt: _isEditing ? widget.editMedicine!.createdAt : DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await MedicineCleanStorageService.saveMedicine(medicine);

      if (_reminderEnabled) {
        await _reminderService.scheduleReminders(medicine);
      } else {
        await _reminderService.cancelReminders(medicine);
      }

      _hapticService.success();

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error saving medicine: $e');
      _showError('Failed to save medication');
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AccentScope(
      feature: FeatureAccent.medicine,
      child: AppScaffold(
        body: Column(
          children: [
            _buildHeader(context),
            _buildProgressIndicator(context),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1BasicInfo(context),
                  _buildStep2Dosage(context),
                  _buildStep3Schedule(context),
                  _buildStep4Appearance(context),
                  _buildStep5Additional(context),
                ],
              ),
            ),
            _buildBottomButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final ext = AppColorsExt.of(context);
    return AppHeader(
      title: _isEditing ? 'Edit Medication' : 'Add Medication',
      accent: ext.medicine,
      leading: AppIconButton(
        icon: Icons.close_rounded,
        filled: false,
        accent: ext.medicine,
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildProgressIndicator(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final med = ext.medicine;
    final tt = Theme.of(context).textTheme;
    final steps = ['Info', 'Dosage', 'Schedule', 'Look', 'More'];

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.gutter, vertical: AppSpacing.sm),
      child: Column(
        children: [
          Row(
            children: List.generate(_totalSteps, (index) {
              final isActive = index <= _currentStep;
              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: AnimatedContainer(
                        duration: AppMotion.fast,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isActive ? ext.mark(med) : ext.outline,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    if (index < _totalSteps - 1) const SizedBox(width: 4),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_totalSteps, (index) {
              final isCurrent = index == _currentStep;
              return Text(
                steps[index],
                style: tt.bodySmall?.copyWith(
                  color: isCurrent ? ext.mark(med) : ext.textTertiary,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1BasicInfo(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final med = ext.medicine;
    final tt = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What medication are you adding?', style: tt.headlineMedium),
          const SizedBox(height: AppSpacing.xl),
          AppTextField(
            controller: _nameController,
            label: 'Medication Name',
            hint: 'e.g., Aspirin, Vitamin D',
            accent: med,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Type',
              style: tt.labelLarge?.copyWith(color: ext.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: DosageForm.values.take(8).map((form) {
              final isSelected = _selectedForm == form;
              return _buildSelectablePill(
                context: context,
                selected: isSelected,
                onTap: () {
                  _hapticService.selection();
                  setState(() {
                    _selectedForm = form;
                    _dosageUnit = form.unit;
                  });
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(form.icon, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      form.displayName,
                      style: tt.labelMedium?.copyWith(
                        color: isSelected ? med.onContainer : ext.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Dosage(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final med = ext.medicine;
    final tt = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How much do you take?', style: tt.headlineMedium),
          const SizedBox(height: AppSpacing.xl),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: AppTextField(
                  controller: _dosageController,
                  keyboardType: TextInputType.number,
                  hint: 'Amount',
                  accent: med,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Container(
                  height: 52,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: ext.surfaceVariant,
                    borderRadius: AppRadius.brMd,
                    border: Border.all(color: ext.outline),
                  ),
                  child: Text(
                    _dosageUnit,
                    style: tt.bodyLarge?.copyWith(color: ext.textSecondary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          AppTextField(
            controller: _strengthController,
            label: 'Strength (optional)',
            hint: 'e.g., 500mg, 10mg/5ml',
            accent: med,
          ),
          const SizedBox(height: AppSpacing.xl),
          _buildStockSection(context),
        ],
      ),
    );
  }

  /// Optional stock & refill tracking. Leaving the quantity blank keeps the
  /// medicine untracked (no low-stock alerts). When a quantity is entered, the
  /// low-stock threshold and refill-reminder toggle drive the refill pipeline.
  Widget _buildStockSection(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final med = ext.medicine;
    final tt = Theme.of(context).textTheme;
    final tracked = _stockController.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Stock & refill',
            style: tt.labelLarge?.copyWith(color: ext.textSecondary)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Track your supply to get refill reminders (optional)',
          style: tt.bodySmall?.copyWith(color: ext.textTertiary),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _stockController,
          keyboardType: TextInputType.number,
          label: 'Current quantity',
          hint: 'e.g., 30 (leave blank to skip)',
          accent: med,
          onChanged: (_) => setState(() {}),
        ),
        if (tracked) ...[
          _buildStepperRow(
            context: context,
            label: 'Low-stock alert at',
            value: _lowStockThreshold,
            suffix: 'left',
            min: 1,
            max: 180,
            onChanged: (v) => setState(() => _lowStockThreshold = v),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            onTap: () {
              _hapticService.toggle();
              setState(() => _refillReminderEnabled = !_refillReminderEnabled);
            },
            child: Row(
              children: [
                Icon(
                  _refillReminderEnabled
                      ? Icons.inventory_2_rounded
                      : Icons.inventory_2_outlined,
                  color:
                      _refillReminderEnabled ? ext.mark(med) : ext.textTertiary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Refill reminders', style: tt.titleLarge),
                      Text(
                        _refillReminderEnabled
                            ? 'Alert me when stock runs low'
                            : 'No refill alerts',
                        style:
                            tt.bodySmall?.copyWith(color: ext.textSecondary),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _refillReminderEnabled,
                  onChanged: (v) {
                    _hapticService.toggle();
                    setState(() => _refillReminderEnabled = v);
                  },
                  activeColor: ext.mark(med),
                  activeTrackColor: med.container,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStep3Schedule(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('When do you take it?', style: tt.headlineMedium),
          const SizedBox(height: AppSpacing.xl),
          _buildFrequencySelector(context),
          _buildFrequencyConfig(context),
          if (!_isPRN) ...[
            const SizedBox(height: AppSpacing.xl),
            _buildTimesSection(context),
          ],
          const SizedBox(height: AppSpacing.xl),
          _buildMealTimingSelector(context),
          const SizedBox(height: AppSpacing.xl),
          _buildDurationSection(context),
        ],
      ),
    );
  }

  Widget _buildFrequencySelector(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final med = ext.medicine;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Frequency',
            style: tt.labelLarge?.copyWith(color: ext.textSecondary)),
        const SizedBox(height: AppSpacing.sm),
        ...FrequencyType.values.map((freq) {
          final isSelected = _frequencyType == freq;
          return GestureDetector(
            onTap: () {
              _hapticService.selection();
              setState(() {
                _frequencyType = freq;
                _updateTimesForFrequency();
              });
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? med.container : ext.surface,
                borderRadius: AppRadius.brMd,
                border: Border.all(
                  color: isSelected ? med.base : ext.outline,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: isSelected ? ext.mark(med) : ext.textTertiary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    freq.displayName,
                    style: tt.bodyMedium?.copyWith(
                      color: isSelected ? med.onContainer : ext.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  /// Per-frequency configuration: weekday chips, interval steppers, cycle
  /// steppers, or PRN dose limits.
  Widget _buildFrequencyConfig(BuildContext context) {
    switch (_frequencyType) {
      case FrequencyType.specificDays:
        return _buildDaySelector(context);
      case FrequencyType.everyXHours:
        return _buildStepperRow(
          context: context,
          label: 'Interval',
          value: _intervalHours,
          suffix: _intervalHours == 1 ? 'hour' : 'hours',
          min: 1,
          max: 24,
          onChanged: (v) => setState(() => _intervalHours = v),
        );
      case FrequencyType.everyXDays:
        return _buildStepperRow(
          context: context,
          label: 'Interval',
          value: _intervalDays,
          suffix: _intervalDays == 1 ? 'day' : 'days',
          min: 1,
          max: 90,
          onChanged: (v) => setState(() => _intervalDays = v),
        );
      case FrequencyType.cyclical:
        return Column(
          children: [
            _buildStepperRow(
              context: context,
              label: 'Days on',
              value: _cycleDaysOn,
              suffix: _cycleDaysOn == 1 ? 'day' : 'days',
              min: 1,
              max: 90,
              onChanged: (v) => setState(() => _cycleDaysOn = v),
            ),
            const SizedBox(height: AppSpacing.md),
            _buildStepperRow(
              context: context,
              label: 'Days off',
              value: _cycleDaysOff,
              suffix: _cycleDaysOff == 1 ? 'day' : 'days',
              min: 1,
              max: 90,
              onChanged: (v) => setState(() => _cycleDaysOff = v),
            ),
          ],
        );
      case FrequencyType.asNeeded:
        return Column(
          children: [
            _buildStepperRow(
              context: context,
              label: 'Max doses / day',
              value: _maxDailyDoses,
              suffix: _maxDailyDoses == 1 ? 'dose' : 'doses',
              min: 1,
              max: 24,
              onChanged: (v) => setState(() => _maxDailyDoses = v),
            ),
            const SizedBox(height: AppSpacing.md),
            _buildStepperRow(
              context: context,
              label: 'Min gap between',
              value: _minHoursBetweenDoses,
              suffix: _minHoursBetweenDoses == 1 ? 'hour' : 'hours',
              min: 0,
              max: 24,
              onChanged: (v) => setState(() => _minHoursBetweenDoses = v),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDaySelector(BuildContext context) {
    final med = AppColorsExt.of(context).medicine;
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(7, (index) {
          final dayNum = index + 1;
          final isSelected = _selectedDays.contains(dayNum);
          return AppChip(
            label: dayLabels[index],
            selected: isSelected,
            accent: med,
            onTap: () {
              _hapticService.selection();
              setState(() {
                if (isSelected) {
                  _selectedDays.remove(dayNum);
                } else {
                  _selectedDays.add(dayNum);
                }
                _selectedDays.sort();
              });
            },
          );
        }),
      ),
    );
  }

  /// Compact +/- stepper on a labelled row, styled as a Calm Clarity card.
  Widget _buildStepperRow({
    required BuildContext context,
    required String label,
    required int value,
    required String suffix,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    final ext = AppColorsExt.of(context);
    final med = ext.medicine;
    final tt = Theme.of(context).textTheme;

    Widget stepButton(IconData icon, bool enabled, VoidCallback onTap) {
      return GestureDetector(
        onTap: enabled
            ? () {
                _hapticService.selection();
                onTap();
              }
            : null,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: enabled ? med.container : ext.surfaceVariant,
            borderRadius: AppRadius.brSm,
            border: Border.all(color: enabled ? med.base : ext.outline),
          ),
          child: Icon(
            icon,
            size: 20,
            color: enabled ? med.onContainer : ext.textTertiary,
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: ext.surface,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: ext.outline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: tt.bodyMedium?.copyWith(color: ext.textPrimary)),
          ),
          stepButton(Icons.remove_rounded, value > min,
              () => onChanged((value - 1).clamp(min, max))),
          Container(
            constraints: const BoxConstraints(minWidth: 88),
            alignment: Alignment.center,
            child: Text(
              '$value $suffix',
              style: tt.titleMedium?.copyWith(
                color: ext.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          stepButton(Icons.add_rounded, value < max,
              () => onChanged((value + 1).clamp(min, max))),
        ],
      ),
    );
  }

  Widget _buildTimesSection(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final med = ext.medicine;
    final tt = Theme.of(context).textTheme;
    final timesLabel = _frequencyType == FrequencyType.everyXHours
        ? 'First dose'
        : 'Times';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(timesLabel,
                style: tt.labelLarge?.copyWith(color: ext.textSecondary)),
            if (_frequencyType != FrequencyType.everyXHours)
              AppButton(
                label: 'Add Time',
                leadingIcon: Icons.add_rounded,
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.sm,
                accent: med,
                onPressed: _addTime,
              ),
          ],
        ),
        if (_frequencyType == FrequencyType.everyXHours)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Text(
              'Doses repeat every $_intervalHours '
              '${_intervalHours == 1 ? 'hour' : 'hours'} after this time.',
              style: tt.bodySmall?.copyWith(color: ext.textTertiary),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _scheduleTimes.asMap().entries.map((entry) {
            final index = entry.key;
            final time = entry.value;
            final canRemove = _scheduleTimes.length > 1 &&
                _frequencyType != FrequencyType.everyXHours;
            return GestureDetector(
              onTap: () => _editTime(index),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: med.container,
                  borderRadius: AppRadius.brSm,
                  border: Border.all(color: med.base),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 18, color: med.onContainer),
                    const SizedBox(width: 8),
                    Text(
                      time.format(context),
                      style:
                          tt.labelMedium?.copyWith(color: med.onContainer),
                    ),
                    if (canRemove) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _removeTime(index),
                        child: Icon(Icons.close_rounded,
                            size: 16, color: med.onContainer),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMealTimingSelector(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final med = ext.medicine;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Meal timing',
            style: tt.labelLarge?.copyWith(color: ext.textSecondary)),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: MealTiming.values.map((timing) {
            return AppChip(
              label: timing.displayName,
              selected: _mealTiming == timing,
              accent: med,
              onTap: () {
                _hapticService.selection();
                setState(() => _mealTiming = timing);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDurationSection(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final med = ext.medicine;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Duration',
            style: tt.labelLarge?.copyWith(color: ext.textSecondary)),
        const SizedBox(height: AppSpacing.sm),
        // Start date
        GestureDetector(
          onTap: _pickStartDate,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: ext.surface,
              borderRadius: AppRadius.brMd,
              border: Border.all(color: ext.outline),
            ),
            child: Row(
              children: [
                Icon(Icons.event_rounded, size: 20, color: ext.mark(med)),
                const SizedBox(width: 12),
                Text('Start',
                    style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
                const Spacer(),
                Text(_formatDate(_startDate),
                    style: tt.titleMedium
                        ?.copyWith(color: ext.textPrimary)),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Mode toggle
        Row(
          children: [
            _buildDurationModeChip(context, _DurationMode.ongoing, 'Ongoing'),
            const SizedBox(width: 8),
            _buildDurationModeChip(context, _DurationMode.endDate, 'End date'),
            const SizedBox(width: 8),
            _buildDurationModeChip(
                context, _DurationMode.duration, '# of days'),
          ],
        ),
        if (_durationMode == _DurationMode.endDate) ...[
          const SizedBox(height: AppSpacing.md),
          GestureDetector(
            onTap: _pickEndDate,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              decoration: BoxDecoration(
                color: ext.surface,
                borderRadius: AppRadius.brMd,
                border: Border.all(color: ext.outline),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_available_rounded,
                      size: 20, color: ext.mark(med)),
                  const SizedBox(width: 12),
                  Text('End',
                      style:
                          tt.bodyMedium?.copyWith(color: ext.textSecondary)),
                  const Spacer(),
                  Text(_endDate != null ? _formatDate(_endDate!) : 'Select',
                      style: tt.titleMedium?.copyWith(
                        color: _endDate != null
                            ? ext.textPrimary
                            : ext.textTertiary,
                      )),
                ],
              ),
            ),
          ),
        ],
        if (_durationMode == _DurationMode.duration)
          _buildStepperRow(
            context: context,
            label: 'Take for',
            value: _durationDays,
            suffix: _durationDays == 1 ? 'day' : 'days',
            min: 1,
            max: 365,
            onChanged: (v) => setState(() => _durationDays = v),
          ),
      ],
    );
  }

  Widget _buildDurationModeChip(
      BuildContext context, _DurationMode mode, String label) {
    final med = AppColorsExt.of(context).medicine;
    return Expanded(
      child: Align(
        alignment: Alignment.centerLeft,
        child: AppChip(
          label: label,
          selected: _durationMode == mode,
          accent: med,
          onTap: () {
            _hapticService.selection();
            setState(() => _durationMode = mode);
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(_startDate)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate != null && _endDate!.isAfter(_startDate)
          ? _endDate!
          : _startDate.add(const Duration(days: 7)),
      firstDate: _startDate,
      lastDate: _startDate.add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  void _updateTimesForFrequency() {
    switch (_frequencyType) {
      case FrequencyType.onceDaily:
        _scheduleTimes = [const TimeOfDay(hour: 8, minute: 0)];
        break;
      case FrequencyType.twiceDaily:
        _scheduleTimes = [
          const TimeOfDay(hour: 8, minute: 0),
          const TimeOfDay(hour: 20, minute: 0),
        ];
        break;
      case FrequencyType.thriceDaily:
        _scheduleTimes = [
          const TimeOfDay(hour: 8, minute: 0),
          const TimeOfDay(hour: 14, minute: 0),
          const TimeOfDay(hour: 20, minute: 0),
        ];
        break;
      case FrequencyType.fourTimesDaily:
        _scheduleTimes = [
          const TimeOfDay(hour: 8, minute: 0),
          const TimeOfDay(hour: 12, minute: 0),
          const TimeOfDay(hour: 16, minute: 0),
          const TimeOfDay(hour: 20, minute: 0),
        ];
        break;
      case FrequencyType.everyXHours:
        // A single anchor time; the interval fans it out across the day.
        _scheduleTimes = [
          _scheduleTimes.isNotEmpty
              ? _scheduleTimes.first
              : const TimeOfDay(hour: 8, minute: 0)
        ];
        break;
      case FrequencyType.asNeeded:
        // PRN has no fixed times.
        _scheduleTimes = [];
        break;
      case FrequencyType.everyXDays:
      case FrequencyType.specificDays:
      case FrequencyType.cyclical:
        // Day-based frequencies still need at least one time-of-day slot.
        if (_scheduleTimes.isEmpty) {
          _scheduleTimes = [const TimeOfDay(hour: 8, minute: 0)];
        }
        break;
    }
  }

  Future<void> _addTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) {
      setState(() => _scheduleTimes.add(time));
    }
  }

  Future<void> _editTime(int index) async {
    final time = await showTimePicker(
      context: context,
      initialTime: _scheduleTimes[index],
    );
    if (time != null) {
      setState(() => _scheduleTimes[index] = time);
    }
  }

  void _removeTime(int index) {
    if (_scheduleTimes.length > 1) {
      setState(() => _scheduleTimes.removeAt(index));
    }
  }

  Widget _buildStep4Appearance(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final med = ext.medicine;
    final tt = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What does it look like?', style: tt.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Text('This helps identify your medication',
              style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: NunitoPillVisual(
              color: _selectedColor,
              shape: _selectedShape,
              size: 100,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Color',
              style: tt.labelLarge?.copyWith(color: ext.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: MedicineColor.values.map((color) {
              final isSelected = _selectedColor == color;
              final swatchColor = Color(color.colorValue);
              return GestureDetector(
                onTap: () {
                  _hapticService.selection();
                  setState(() => _selectedColor = color);
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: swatchColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? ext.mark(med) : ext.outlineStrong,
                      width: isSelected ? 3 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: med.base.withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? Icon(Icons.check_rounded,
                          color: _contrastOn(swatchColor), size: 20)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Shape',
              style: tt.labelLarge?.copyWith(color: ext.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: MedicineShape.values.map((shape) {
              final isSelected = _selectedShape == shape;
              return _buildSelectablePill(
                context: context,
                selected: isSelected,
                onTap: () {
                  _hapticService.selection();
                  setState(() => _selectedShape = shape);
                },
                child: Text(
                  shape.displayName,
                  style: tt.labelMedium?.copyWith(
                    color: isSelected ? med.onContainer : ext.textPrimary,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStep5Additional(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final med = ext.medicine;
    final tt = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Additional Details', style: tt.headlineMedium),
          const SizedBox(height: AppSpacing.xl),
          AppTextField(
            controller: _instructionsController,
            maxLines: 2,
            label: 'Instructions (optional)',
            hint: 'e.g., Take with food',
            accent: med,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _purposeController,
            label: 'Purpose (optional)',
            hint: 'e.g., Blood pressure, Pain relief',
            accent: med,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppCard(
            onTap: () {
              _hapticService.toggle();
              setState(() => _reminderEnabled = !_reminderEnabled);
            },
            child: Row(
              children: [
                Icon(
                  _reminderEnabled
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_off_rounded,
                  color: _reminderEnabled ? ext.mark(med) : ext.textTertiary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reminders',
                        style: tt.titleLarge,
                      ),
                      Text(
                        _reminderEnabled
                            ? 'You\'ll receive notifications'
                            : 'No notifications',
                        style: tt.bodySmall
                            ?.copyWith(color: ext.textSecondary),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _reminderEnabled,
                  onChanged: (v) {
                    _hapticService.toggle();
                    setState(() => _reminderEnabled = v);
                  },
                  activeColor: ext.mark(med),
                  activeTrackColor: med.container,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final med = ext.medicine;
    final isLastStep = _currentStep == _totalSteps - 1;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.lg,
        AppSpacing.gutter,
        AppSpacing.lg + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: ext.surface,
        border: Border(top: BorderSide(color: ext.outline)),
      ),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            Expanded(
              child: AppButton(
                label: 'Back',
                variant: AppButtonVariant.secondary,
                accent: med,
                fullWidth: true,
                onPressed: _previousStep,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: AppButton(
              label: isLastStep
                  ? (_isEditing ? 'Save Changes' : 'Add Medication')
                  : 'Continue',
              variant: AppButtonVariant.primary,
              accent: med,
              fullWidth: true,
              loading: _isLoading,
              onPressed: _isLoading ? null : _nextStep,
            ),
          ),
        ],
      ),
    );
  }

  /// Reusable selectable pill for the Type / Shape choosers.
  Widget _buildSelectablePill({
    required BuildContext context,
    required bool selected,
    required VoidCallback onTap,
    required Widget child,
  }) {
    final ext = AppColorsExt.of(context);
    final med = ext.medicine;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? med.container : ext.surfaceVariant,
          borderRadius: AppRadius.brSm,
          border: Border.all(color: selected ? med.base : ext.outline),
        ),
        child: child,
      ),
    );
  }

  /// Contrast foreground for a check mark drawn on an arbitrary medication
  /// swatch color (not a theme token — must be computed against the fill).
  Color _contrastOn(Color color) {
    final luminance =
        (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) / 255;
    return luminance > 0.5 ? const Color(0xDD000000) : const Color(0xFFFFFFFF);
  }
}
