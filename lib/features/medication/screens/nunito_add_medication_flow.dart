import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../theme/nunito_theme.dart';
import '../widgets/nunito_glass_card.dart';
import '../widgets/nunito_pill_visual.dart';
import '../models/enhanced_medicine.dart';
import '../models/medicine_enums.dart';
import '../models/medicine_schedule.dart';
import '../services/medicine_storage_service.dart';
import '../services/medication_reminder_service.dart';
import '../../../core/services/haptic_service.dart';

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

  // Step 3: Schedule
  FrequencyType _frequencyType = FrequencyType.onceDaily;
  List<TimeOfDay> _scheduleTimes = [const TimeOfDay(hour: 8, minute: 0)];
  List<int> _selectedDays = [1, 2, 3, 4, 5, 6, 7]; // All days

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
    _frequencyType = m.schedule.frequencyType;
    _scheduleTimes = m.schedule.times.map((t) => TimeOfDay(hour: t.hour, minute: t.minute)).toList();
    _selectedDays = m.schedule.specificDays ?? [1, 2, 3, 4, 5, 6, 7];
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
        duration: NunitoTheme.animationMedium,
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
        duration: NunitoTheme.animationMedium,
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: NunitoTheme.error),
    );
  }

  Future<void> _saveMedicine() async {
    setState(() => _isLoading = true);

    try {
      final scheduleTimesList = _scheduleTimes.map((t) => 
        ScheduledTime(hour: t.hour, minute: t.minute)
      ).toList();

      final schedule = MedicineSchedule(
        frequencyType: _frequencyType,
        times: scheduleTimesList,
        specificDays: _selectedDays,
      );

      final medicine = EnhancedMedicine(
        id: _isEditing ? widget.editMedicine!.id : const Uuid().v4(),
        name: _nameController.text.trim(),
        dosageForm: _selectedForm,
        dosageAmount: double.parse(_dosageController.text),
        dosageUnit: _dosageUnit,
        strength: _strengthController.text.isNotEmpty ? _strengthController.text : null,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? NunitoTheme.backgroundDark : NunitoTheme.backgroundLight,
      appBar: _buildAppBar(isDark),
      body: Column(
        children: [
          _buildProgressIndicator(isDark),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1BasicInfo(isDark),
                _buildStep2Dosage(isDark),
                _buildStep3Schedule(isDark),
                _buildStep4Appearance(isDark),
                _buildStep5Additional(isDark),
              ],
            ),
          ),
          _buildBottomButtons(isDark),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.close_rounded, color: isDark ? Colors.white : NunitoTheme.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        _isEditing ? 'Edit Medication' : 'Add Medication',
        style: NunitoTheme.heading2.copyWith(
          color: isDark ? Colors.white : NunitoTheme.textPrimary,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildProgressIndicator(bool isDark) {
    final steps = ['Info', 'Dosage', 'Schedule', 'Look', 'More'];
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: NunitoTheme.spacingM, vertical: NunitoTheme.spacingS),
      child: Column(
        children: [
          Row(
            children: List.generate(_totalSteps, (index) {
              final isActive = index <= _currentStep;
              final isCurrent = index == _currentStep;
              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: AnimatedContainer(
                        duration: NunitoTheme.animationFast,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isActive ? NunitoTheme.primary : NunitoTheme.textTertiary.withOpacity(0.2),
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
                style: NunitoTheme.caption.copyWith(
                  color: isCurrent ? NunitoTheme.primary : NunitoTheme.textTertiary,
                  fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1BasicInfo(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(NunitoTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What medication are you adding?', style: NunitoTheme.heading2.copyWith(
            color: isDark ? Colors.white : NunitoTheme.textPrimary,
          )),
          const SizedBox(height: NunitoTheme.spacingL),
          TextField(
            controller: _nameController,
            style: NunitoTheme.bodyLarge.copyWith(
              color: isDark ? Colors.white : NunitoTheme.textPrimary,
            ),
            decoration: InputDecoration(
              labelText: 'Medication Name',
              hintText: 'e.g., Aspirin, Vitamin D',
              filled: true,
              fillColor: isDark ? NunitoTheme.cardDark : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(NunitoTheme.radiusMedium),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: NunitoTheme.spacingL),
          Text('Type', style: NunitoTheme.labelLarge.copyWith(
            color: isDark ? Colors.white70 : NunitoTheme.textSecondary,
          )),
          const SizedBox(height: NunitoTheme.spacingS),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: DosageForm.values.take(8).map((form) {
              final isSelected = _selectedForm == form;
              return GestureDetector(
                onTap: () {
                  _hapticService.selection();
                  setState(() {
                    _selectedForm = form;
                    _dosageUnit = form.unit;
                  });
                },
                child: AnimatedContainer(
                  duration: NunitoTheme.animationFast,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? NunitoTheme.primary : (isDark ? NunitoTheme.cardDark : Colors.white),
                    borderRadius: BorderRadius.circular(NunitoTheme.radiusSmall),
                    border: Border.all(
                      color: isSelected ? NunitoTheme.primary : NunitoTheme.textTertiary.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(form.icon, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(
                        form.displayName,
                        style: NunitoTheme.labelMedium.copyWith(
                          color: isSelected ? Colors.white : (isDark ? Colors.white : NunitoTheme.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Dosage(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(NunitoTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How much do you take?', style: NunitoTheme.heading2.copyWith(
            color: isDark ? Colors.white : NunitoTheme.textPrimary,
          )),
          const SizedBox(height: NunitoTheme.spacingL),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _dosageController,
                  keyboardType: TextInputType.number,
                  style: NunitoTheme.displayMedium.copyWith(
                    color: isDark ? Colors.white : NunitoTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDark ? NunitoTheme.cardDark : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(NunitoTheme.radiusMedium),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  decoration: BoxDecoration(
                    color: isDark ? NunitoTheme.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(NunitoTheme.radiusMedium),
                  ),
                  child: Text(
                    _dosageUnit,
                    style: NunitoTheme.bodyLarge.copyWith(
                      color: isDark ? Colors.white70 : NunitoTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: NunitoTheme.spacingL),
          TextField(
            controller: _strengthController,
            style: NunitoTheme.bodyLarge.copyWith(
              color: isDark ? Colors.white : NunitoTheme.textPrimary,
            ),
            decoration: InputDecoration(
              labelText: 'Strength (optional)',
              hintText: 'e.g., 500mg, 10mg/5ml',
              filled: true,
              fillColor: isDark ? NunitoTheme.cardDark : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(NunitoTheme.radiusMedium),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3Schedule(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(NunitoTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('When do you take it?', style: NunitoTheme.heading2.copyWith(
            color: isDark ? Colors.white : NunitoTheme.textPrimary,
          )),
          const SizedBox(height: NunitoTheme.spacingL),
          Text('Frequency', style: NunitoTheme.labelLarge.copyWith(
            color: isDark ? Colors.white70 : NunitoTheme.textSecondary,
          )),
          const SizedBox(height: NunitoTheme.spacingS),
          ...FrequencyType.values.take(5).map((freq) {
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
                  color: isSelected ? NunitoTheme.primary.withOpacity(0.1) : (isDark ? NunitoTheme.cardDark : Colors.white),
                  borderRadius: BorderRadius.circular(NunitoTheme.radiusSmall),
                  border: Border.all(
                    color: isSelected ? NunitoTheme.primary : NunitoTheme.textTertiary.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: isSelected ? NunitoTheme.primary : NunitoTheme.textTertiary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      freq.displayName,
                      style: NunitoTheme.bodyMedium.copyWith(
                        color: isDark ? Colors.white : NunitoTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: NunitoTheme.spacingL),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Times', style: NunitoTheme.labelLarge.copyWith(
                color: isDark ? Colors.white70 : NunitoTheme.textSecondary,
              )),
              TextButton.icon(
                onPressed: _addTime,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Time'),
              ),
            ],
          ),
          const SizedBox(height: NunitoTheme.spacingS),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _scheduleTimes.asMap().entries.map((entry) {
              final index = entry.key;
              final time = entry.value;
              return GestureDetector(
                onTap: () => _editTime(index),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: NunitoTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(NunitoTheme.radiusSmall),
                    border: Border.all(color: NunitoTheme.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time_rounded, size: 18, color: NunitoTheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        time.format(context),
                        style: NunitoTheme.labelMedium.copyWith(color: NunitoTheme.primary),
                      ),
                      if (_scheduleTimes.length > 1) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _removeTime(index),
                          child: Icon(Icons.close_rounded, size: 16, color: NunitoTheme.primary),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
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
      default:
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

  Widget _buildStep4Appearance(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(NunitoTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What does it look like?', style: NunitoTheme.heading2.copyWith(
            color: isDark ? Colors.white : NunitoTheme.textPrimary,
          )),
          const SizedBox(height: NunitoTheme.spacingS),
          Text('This helps identify your medication', style: NunitoTheme.bodyMedium.copyWith(
            color: NunitoTheme.textSecondary,
          )),
          const SizedBox(height: NunitoTheme.spacingL),
          Center(
            child: NunitoPillVisual(
              color: _selectedColor,
              shape: _selectedShape,
              size: 100,
            ),
          ),
          const SizedBox(height: NunitoTheme.spacingL),
          Text('Color', style: NunitoTheme.labelLarge.copyWith(
            color: isDark ? Colors.white70 : NunitoTheme.textSecondary,
          )),
          const SizedBox(height: NunitoTheme.spacingS),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: MedicineColor.values.map((color) {
              final isSelected = _selectedColor == color;
              return GestureDetector(
                onTap: () {
                  _hapticService.selection();
                  setState(() => _selectedColor = color);
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Color(color.colorValue),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? NunitoTheme.primary : Colors.grey.withOpacity(0.3),
                      width: isSelected ? 3 : 1,
                    ),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: NunitoTheme.primary.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ] : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded, color: Colors.black54, size: 20)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: NunitoTheme.spacingL),
          Text('Shape', style: NunitoTheme.labelLarge.copyWith(
            color: isDark ? Colors.white70 : NunitoTheme.textSecondary,
          )),
          const SizedBox(height: NunitoTheme.spacingS),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: MedicineShape.values.map((shape) {
              final isSelected = _selectedShape == shape;
              return GestureDetector(
                onTap: () {
                  _hapticService.selection();
                  setState(() => _selectedShape = shape);
                },
                child: AnimatedContainer(
                  duration: NunitoTheme.animationFast,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? NunitoTheme.primary : (isDark ? NunitoTheme.cardDark : Colors.white),
                    borderRadius: BorderRadius.circular(NunitoTheme.radiusSmall),
                    border: Border.all(
                      color: isSelected ? NunitoTheme.primary : NunitoTheme.textTertiary.withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    shape.displayName,
                    style: NunitoTheme.labelMedium.copyWith(
                      color: isSelected ? Colors.white : (isDark ? Colors.white : NunitoTheme.textPrimary),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStep5Additional(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(NunitoTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Additional Details', style: NunitoTheme.heading2.copyWith(
            color: isDark ? Colors.white : NunitoTheme.textPrimary,
          )),
          const SizedBox(height: NunitoTheme.spacingL),
          TextField(
            controller: _instructionsController,
            maxLines: 2,
            style: NunitoTheme.bodyMedium.copyWith(
              color: isDark ? Colors.white : NunitoTheme.textPrimary,
            ),
            decoration: InputDecoration(
              labelText: 'Instructions (optional)',
              hintText: 'e.g., Take with food',
              filled: true,
              fillColor: isDark ? NunitoTheme.cardDark : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(NunitoTheme.radiusMedium),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: NunitoTheme.spacingM),
          TextField(
            controller: _purposeController,
            style: NunitoTheme.bodyMedium.copyWith(
              color: isDark ? Colors.white : NunitoTheme.textPrimary,
            ),
            decoration: InputDecoration(
              labelText: 'Purpose (optional)',
              hintText: 'e.g., Blood pressure, Pain relief',
              filled: true,
              fillColor: isDark ? NunitoTheme.cardDark : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(NunitoTheme.radiusMedium),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: NunitoTheme.spacingL),
          NunitoCard(
            onTap: () {
              _hapticService.toggle();
              setState(() => _reminderEnabled = !_reminderEnabled);
            },
            child: Row(
              children: [
                Icon(
                  _reminderEnabled ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
                  color: _reminderEnabled ? NunitoTheme.primary : NunitoTheme.textTertiary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reminders',
                        style: NunitoTheme.labelLarge.copyWith(
                          color: isDark ? Colors.white : NunitoTheme.textPrimary,
                        ),
                      ),
                      Text(
                        _reminderEnabled ? 'You\'ll receive notifications' : 'No notifications',
                        style: NunitoTheme.caption,
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
                  activeColor: NunitoTheme.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons(bool isDark) {
    final isLastStep = _currentStep == _totalSteps - 1;
    
    return Container(
      padding: EdgeInsets.fromLTRB(
        NunitoTheme.spacingM,
        NunitoTheme.spacingM,
        NunitoTheme.spacingM,
        NunitoTheme.spacingM + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? NunitoTheme.cardDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  foregroundColor: NunitoTheme.primary,
                  side: BorderSide(color: NunitoTheme.primary.withOpacity(0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(NunitoTheme.radiusMedium),
                  ),
                ),
                child: const Text('Back'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: _currentStep == 0 ? 1 : 1,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: NunitoTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(NunitoTheme.radiusMedium),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(isLastStep ? (_isEditing ? 'Save Changes' : 'Add Medication') : 'Continue'),
            ),
          ),
        ],
      ),
    );
  }
}
