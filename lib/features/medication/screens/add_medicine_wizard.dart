import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/notification_service.dart';
import '../models/medicine_enums.dart';
import '../models/medicine_schedule.dart';
import '../models/enhanced_medicine.dart';
import '../services/medicine_storage_service.dart';
import '../services/drug_interaction_service.dart';

/// New Step-by-Step Add Medicine Flow
/// Flow: Health Category → Medicine Details → Schedule → Meal Timing → Visual ID → Review
class AddMedicineWizard extends StatefulWidget {
  final EnhancedMedicine? editMedicine;

  const AddMedicineWizard({super.key, this.editMedicine});

  @override
  State<AddMedicineWizard> createState() => _AddMedicineWizardState();
}

class _AddMedicineWizardState extends State<AddMedicineWizard> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 6;
  bool _isSaving = false;

  // Step 1: Health Category
  HealthCategory? _selectedCategory;
  String _customCategoryName = '';
  final _customCategoryController = TextEditingController();

  // Step 2: Medicine Details
  final _nameController = TextEditingController();
  final _strengthController = TextEditingController();
  DosageForm _dosageForm = DosageForm.tablet;
  double _dosageAmount = 1;

  // Step 3: Schedule Configuration
  FrequencyType _frequencyType = FrequencyType.onceDaily;
  List<ScheduledTime> _scheduledTimes = [ScheduledTime(hour: 8, minute: 0, label: 'Morning')];
  int _intervalHours = 8;
  final List<int> _specificDays = [];
  int _cycleDaysOn = 21;
  int _cycleDaysOff = 7;
  int? _durationDays;
  DateTime _startDate = DateTime.now();

  // Step 4: Meal Timing
  MealTiming _mealTiming = MealTiming.anytime;

  // Step 5: Visual Identification
  MedicineColor? _medicineColor;
  MedicineShape? _medicineShape;
  final _instructionsController = TextEditingController();
  final _notesController = TextEditingController();

  // Additional settings
  bool _trackStock = false;
  int _currentStock = 30;
  int _lowStockThreshold = 7;
  bool _reminderEnabled = true;
  bool _criticalAlert = false;

  // Warnings
  List<String> _warnings = [];

  @override
  void initState() {
    super.initState();
    if (widget.editMedicine != null) {
      _loadExistingMedicine();
    }
  }

  void _loadExistingMedicine() {
    final med = widget.editMedicine!;
    // Step 1: Category
    if (med.healthCategories != null && med.healthCategories!.isNotEmpty) {
      _selectedCategory = med.healthCategories!.first;
    }
    _customCategoryController.text = med.customHealthCategory ?? '';
    _customCategoryName = med.customHealthCategory ?? '';

    // Step 2: Details
    _nameController.text = med.name;
    _strengthController.text = med.strength ?? '';
    _dosageForm = med.dosageForm;
    _dosageAmount = med.dosageAmount;

    // Step 3: Schedule
    _frequencyType = med.schedule.frequencyType;
    _scheduledTimes = med.schedule.times.isNotEmpty 
        ? med.schedule.times 
        : [ScheduledTime(hour: 8, minute: 0)];
    _intervalHours = med.schedule.intervalHours ?? 8;
    if (med.schedule.specificDays != null) {
      _specificDays.addAll(med.schedule.specificDays!);
    }
    _cycleDaysOn = med.schedule.cycleDaysOn ?? 21;
    _cycleDaysOff = med.schedule.cycleDaysOff ?? 7;
    _durationDays = med.schedule.durationDays;
    _startDate = med.schedule.startDate ?? DateTime.now();

    // Step 4: Meal Timing
    _mealTiming = med.schedule.mealTiming;

    // Step 5: Visual ID
    _medicineColor = med.color;
    _medicineShape = med.shape;
    _instructionsController.text = med.instructions ?? '';
    _notesController.text = med.notes ?? '';

    // Additional
    _trackStock = med.currentStock != null;
    _currentStock = med.currentStock ?? 30;
    _lowStockThreshold = med.lowStockThreshold ?? 7;
    _reminderEnabled = med.reminderEnabled;
    _criticalAlert = med.criticalAlert;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _strengthController.dispose();
    _customCategoryController.dispose();
    _instructionsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  bool _canProceedFromCurrentStep() {
    switch (_currentStep) {
      case 0: // Health Category
        return _selectedCategory != null || _customCategoryName.isNotEmpty;
      case 1: // Medicine Details
        return _nameController.text.trim().isNotEmpty;
      case 2: // Schedule
        return true;
      case 3: // Meal Timing
        return true;
      case 4: // Visual ID (optional)
        return true;
      case 5: // Review
        return true;
      default:
        return true;
    }
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return 'Health Issue';
      case 1:
        return 'Medicine Details';
      case 2:
        return 'Schedule';
      case 3:
        return 'Meal Timing';
      case 4:
        return 'Identification';
      case 5:
        return 'Review';
      default:
        return '';
    }
  }

  Future<void> _checkInteractions() async {
    if (_nameController.text.isEmpty) return;

    final existingMedicines = MedicineStorageService.getAllMedicines();
    final drugNames = existingMedicines.map((m) => m.name).toList();
    drugNames.add(_nameController.text);

    final interactions = DrugInteractionService().checkAllInteractions(drugNames);
    if (interactions.isNotEmpty) {
      setState(() {
        _warnings = interactions.map((i) => 
          '⚠️ ${i.drug1Name} + ${i.drug2Name}: ${i.description}'
        ).toList();
      });
    }
  }

  void _updateScheduledTimes() {
    switch (_frequencyType) {
      case FrequencyType.onceDaily:
        _scheduledTimes = [ScheduledTime(hour: 8, minute: 0, label: 'Morning')];
        break;
      case FrequencyType.twiceDaily:
        _scheduledTimes = [
          ScheduledTime(hour: 8, minute: 0, label: 'Morning'),
          ScheduledTime(hour: 20, minute: 0, label: 'Evening'),
        ];
        break;
      case FrequencyType.thriceDaily:
        _scheduledTimes = [
          ScheduledTime(hour: 8, minute: 0, label: 'Morning'),
          ScheduledTime(hour: 14, minute: 0, label: 'Afternoon'),
          ScheduledTime(hour: 20, minute: 0, label: 'Evening'),
        ];
        break;
      case FrequencyType.fourTimesDaily:
        _scheduledTimes = [
          ScheduledTime(hour: 8, minute: 0, label: 'Morning'),
          ScheduledTime(hour: 12, minute: 0, label: 'Noon'),
          ScheduledTime(hour: 18, minute: 0, label: 'Evening'),
          ScheduledTime(hour: 22, minute: 0, label: 'Bedtime'),
        ];
        break;
      case FrequencyType.asNeeded:
        _scheduledTimes = [];
        break;
      default:
        break;
    }
  }

  Future<void> _saveMedicine() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      // Build schedule
      final schedule = MedicineSchedule(
        frequencyType: _frequencyType,
        times: _scheduledTimes,
        intervalHours: _frequencyType == FrequencyType.everyXHours ? _intervalHours : null,
        specificDays: _frequencyType == FrequencyType.specificDays ? _specificDays : null,
        cycleDaysOn: _frequencyType == FrequencyType.cyclical ? _cycleDaysOn : null,
        cycleDaysOff: _frequencyType == FrequencyType.cyclical ? _cycleDaysOff : null,
        startDate: _startDate,
        durationDays: _durationDays,
        mealTiming: _mealTiming,
        isPRN: _frequencyType == FrequencyType.asNeeded,
      );

      // Build health categories
      List<HealthCategory>? healthCategories;
      if (_selectedCategory != null) {
        healthCategories = [_selectedCategory!];
      }

      final medicine = EnhancedMedicine(
        id: widget.editMedicine?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        strength: _strengthController.text.isNotEmpty ? _strengthController.text : null,
        dosageForm: _dosageForm,
        dosageAmount: _dosageAmount,
        schedule: schedule,
        currentStock: _trackStock ? _currentStock : null,
        lowStockThreshold: _trackStock ? _lowStockThreshold : null,
        reminderEnabled: _reminderEnabled,
        criticalAlert: _criticalAlert,
        color: _medicineColor,
        shape: _medicineShape,
        instructions: _instructionsController.text.isNotEmpty ? _instructionsController.text : null,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        warnings: _warnings.isNotEmpty ? _warnings : null,
        createdAt: widget.editMedicine?.createdAt,
        healthCategories: healthCategories,
        customHealthCategory: _customCategoryName.isNotEmpty ? _customCategoryName : null,
      );

      if (widget.editMedicine != null) {
        await MedicineStorageService.updateMedicine(medicine);
      } else {
        await MedicineStorageService.addMedicine(medicine);
      }

      // Schedule notifications
      if (_reminderEnabled && _frequencyType != FrequencyType.asNeeded) {
        final notificationService = NotificationService();
        for (int i = 0; i < _scheduledTimes.length; i++) {
          final time = _scheduledTimes[i];
          await notificationService.scheduleMedicineReminder(
            id: medicine.id.hashCode + i,
            medicineName: medicine.name,
            hour: time.hour,
            minute: time.minute,
            frequency: schedule.frequencyDescription,
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text(widget.editMedicine != null ? 'Medicine updated!' : 'Medicine added!'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('Error saving medicine: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () {
            if (_currentStep > 0) {
              _prevStep();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Text(
          widget.editMedicine != null ? 'Edit Medicine' : 'Add Medicine',
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Step ${_currentStep + 1}/$_totalSteps',
                style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildProgressBar(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) => setState(() => _currentStep = index),
              children: [
                _buildStep1HealthCategory(),
                _buildStep2MedicineDetails(),
                _buildStep3Schedule(),
                _buildStep4MealTiming(),
                _buildStep5VisualIdentification(),
                _buildStep6Review(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _getStepTitle(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              Text(
                '${((_currentStep + 1) / _totalSteps * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / _totalSteps,
              backgroundColor: AppColors.divider,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // STEP 1: Health Category Selection (Mandatory)
  // ============================================
  Widget _buildStep1HealthCategory() {
    return _buildStepContainer(
      title: 'Select Health Issue',
      subtitle: 'What health condition is this medicine for?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main categories grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.only(bottom: 100),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.6,
              ),
              itemCount: HealthCategory.values.length,
              itemBuilder: (context, index) {
                final category = HealthCategory.values[index];
                final isSelected = _selectedCategory == category;
                final isCustom = category == HealthCategory.custom;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = category;
                      if (!isCustom) {
                        _customCategoryName = '';
                        _customCategoryController.clear();
                      }
                    });
                    if (isCustom) {
                      _showCustomCategoryDialog();
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 8)]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          category.icon,
                          style: const TextStyle(fontSize: 28),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isCustom && _customCategoryName.isNotEmpty 
                              ? _customCategoryName 
                              : category.displayName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? AppColors.primary : AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      canProceed: _canProceedFromCurrentStep(),
    );
  }

  void _showCustomCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom Category'),
        content: TextField(
          controller: _customCategoryController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g., Migraine, PCOS, Arthritis',
            prefixIcon: Icon(Icons.category_rounded),
          ),
          onChanged: (value) {
            _customCategoryName = value;
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _customCategoryName = _customCategoryController.text;
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ============================================
  // STEP 2: Medicine Details
  // ============================================
  Widget _buildStep2MedicineDetails() {
    return _buildStepContainer(
      title: 'Medicine Details',
      subtitle: 'Enter your medication information',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Medicine Name
            TextField(
              controller: _nameController,
              autofocus: widget.editMedicine == null,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Medicine Name *',
                hintText: 'e.g., Metformin, Aspirin',
                prefixIcon: const Icon(Icons.medication_rounded, color: AppColors.primary),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search_rounded),
                  onPressed: _showDrugSearch,
                ),
              ),
              onChanged: (_) {
                setState(() {});
                _checkInteractions();
              },
            ),
            const SizedBox(height: 20),

            // Strength
            TextField(
              controller: _strengthController,
              decoration: const InputDecoration(
                labelText: 'Strength',
                hintText: 'e.g., 500mg, 10mg/5ml',
                prefixIcon: Icon(Icons.science_rounded, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 24),

            // Dosage Form
            const Text(
              'Dosage Form',
              style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: DosageForm.values.length,
                itemBuilder: (context, index) {
                  final form = DosageForm.values[index];
                  final isSelected = _dosageForm == form;
                  return GestureDetector(
                    onTap: () => setState(() => _dosageForm = form),
                    child: Container(
                      width: 80,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.border,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(form.icon, style: const TextStyle(fontSize: 28)),
                          const SizedBox(height: 4),
                          Text(
                            form.displayName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected ? AppColors.primary : AppColors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Quantity per dose
            const Text(
              'Quantity per Dose',
              style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildQuantityButton(Icons.remove_rounded, () {
                    if (_dosageAmount > 0.5) setState(() => _dosageAmount -= 0.5);
                  }),
                  const SizedBox(width: 32),
                  Column(
                    children: [
                      Text(
                        _dosageAmount % 1 == 0 
                            ? _dosageAmount.toInt().toString() 
                            : _dosageAmount.toString(),
                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _dosageForm.unit,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(width: 32),
                  _buildQuantityButton(Icons.add_rounded, () {
                    setState(() => _dosageAmount += 0.5);
                  }),
                ],
              ),
            ),

            if (_warnings.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildWarningsCard(),
            ],
            const SizedBox(height: 100),
          ],
        ),
      ),
      canProceed: _canProceedFromCurrentStep(),
    );
  }

  Widget _buildQuantityButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
    );
  }

  Widget _buildWarningsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.warning),
              SizedBox(width: 8),
              Text('Drug Interactions Detected', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ..._warnings.map((w) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(w, style: const TextStyle(fontSize: 13)),
          )),
        ],
      ),
    );
  }

  void _showDrugSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Search Medicines', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search by name...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: DrugInteractionService().getAllDrugNames().map((name) {
                    return ListTile(
                      title: Text(name),
                      onTap: () {
                        _nameController.text = name;
                        Navigator.pop(context);
                        _checkInteractions();
                        setState(() {});
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================
  // STEP 3: Schedule Configuration
  // ============================================
  Widget _buildStep3Schedule() {
    return _buildStepContainer(
      title: 'Schedule',
      subtitle: 'How often do you take this medicine?',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Frequency options
            ...FrequencyType.values.map((freq) {
              final isSelected = _frequencyType == freq;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _frequencyType = freq;
                    _updateScheduledTimes();
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? AppColors.primary : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.textSecondary,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          freq.displayName,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected ? AppColors.primary : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            // Conditional fields based on frequency
            if (_frequencyType == FrequencyType.everyXHours) ...[
              const SizedBox(height: 16),
              _buildHourIntervalPicker(),
            ],

            if (_frequencyType == FrequencyType.specificDays) ...[
              const SizedBox(height: 16),
              _buildDaySelector(),
            ],

            if (_frequencyType == FrequencyType.cyclical) ...[
              const SizedBox(height: 16),
              _buildCyclicalPicker(),
            ],

            // Time slots (if not PRN)
            if (_frequencyType != FrequencyType.asNeeded && _scheduledTimes.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Reminder Times',
                style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              ..._scheduledTimes.asMap().entries.map((entry) {
                final index = entry.key;
                final time = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    tileColor: Colors.white,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.access_time_rounded, color: AppColors.primary),
                    ),
                    title: Text(time.formattedTime, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: time.label != null ? Text(time.label!) : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
                      onPressed: () => _editTime(index),
                    ),
                  ),
                );
              }),
            ],

            // Duration
            const SizedBox(height: 24),
            const Text(
              'Duration',
              style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [7, 14, 30, 90, null].map((days) {
                final isSelected = _durationDays == days;
                return GestureDetector(
                  onTap: () => setState(() => _durationDays = days),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
                    ),
                    child: Text(
                      days == null ? 'Ongoing' : '$days days',
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
      canProceed: true,
    );
  }

  Widget _buildHourIntervalPicker() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Text('Every ', style: TextStyle(fontSize: 16)),
          Container(
            width: 80,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: TextField(
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              controller: TextEditingController(text: '$_intervalHours'),
              onChanged: (v) => _intervalHours = int.tryParse(v) ?? 8,
            ),
          ),
          const Text(' hours', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildDaySelector() {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select Days', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(7, (index) {
              final dayNum = index + 1;
              final isSelected = _specificDays.contains(dayNum);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _specificDays.remove(dayNum);
                    } else {
                      _specificDays.add(dayNum);
                    }
                  });
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
                  ),
                  child: Center(
                    child: Text(
                      days[index][0],
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildCyclicalPicker() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cycle Duration', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Text('Days On', style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () {
                            if (_cycleDaysOn > 1) setState(() => _cycleDaysOn--);
                          },
                        ),
                        Text('$_cycleDaysOn', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => setState(() => _cycleDaysOn++),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    const Text('Days Off', style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () {
                            if (_cycleDaysOff > 1) setState(() => _cycleDaysOff--);
                          },
                        ),
                        Text('$_cycleDaysOff', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => setState(() => _cycleDaysOff++),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editTime(int index) async {
    final time = _scheduledTimes[index];
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: time.hour, minute: time.minute),
    );
    if (picked != null) {
      setState(() {
        _scheduledTimes[index] = time.copyWith(hour: picked.hour, minute: picked.minute);
      });
    }
  }

  // ============================================
  // STEP 4: Meal Timing
  // ============================================
  Widget _buildStep4MealTiming() {
    return _buildStepContainer(
      title: 'Meal Timing',
      subtitle: 'When should you take this medicine relative to meals?',
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: MealTiming.values.length,
              itemBuilder: (context, index) {
                final timing = MealTiming.values[index];
                final isSelected = _mealTiming == timing;
                return GestureDetector(
                  onTap: () => setState(() => _mealTiming = timing),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? AppColors.primary.withOpacity(0.2) 
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(timing.icon, style: const TextStyle(fontSize: 24)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                timing.displayName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                _getMealTimingDescription(timing),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded, color: AppColors.primary),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      canProceed: true,
    );
  }

  String _getMealTimingDescription(MealTiming timing) {
    switch (timing) {
      case MealTiming.anytime:
        return 'No specific timing required';
      case MealTiming.beforeMeal:
        return '30-60 minutes before eating';
      case MealTiming.withMeal:
        return 'Take while eating';
      case MealTiming.afterMeal:
        return '30 minutes after eating';
      case MealTiming.emptyStomach:
        return '2+ hours after last meal';
      case MealTiming.beforeBed:
        return 'Take before going to sleep';
      case MealTiming.wakeUp:
        return 'Take immediately after waking up';
    }
  }

  // ============================================
  // STEP 5: Visual Identification (Optional)
  // ============================================
  Widget _buildStep5VisualIdentification() {
    return _buildStepContainer(
      title: 'Visual Identification',
      subtitle: 'Help identify your medicine easily (optional)',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Color selection
            const Text('Color', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: MedicineColor.values.map((color) {
                final isSelected = _medicineColor == color;
                return GestureDetector(
                  onTap: () => setState(() => _medicineColor = isSelected ? null : color),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Color(color.colorValue),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border,
                        width: isSelected ? 3 : 1,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 8)]
                          : null,
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check,
                            color: color == MedicineColor.white || color == MedicineColor.yellow
                                ? Colors.black
                                : Colors.white,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Shape selection
            const Text('Shape', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: MedicineShape.values.map((shape) {
                final isSelected = _medicineShape == shape;
                return GestureDetector(
                  onTap: () => setState(() => _medicineShape = isSelected ? null : shape),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
                    ),
                    child: Text(
                      shape.displayName,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Additional options
            const Text('Additional Settings', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 12),

            // Stock tracking
            SwitchListTile(
              title: const Text('Track Stock'),
              subtitle: const Text('Get alerts when running low'),
              value: _trackStock,
              onChanged: (v) => setState(() => _trackStock = v),
              activeThumbColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: Colors.white,
            ),

            if (_trackStock) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Text('Current Stock: '),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () {
                        if (_currentStock > 0) setState(() => _currentStock -= 5);
                      },
                    ),
                    Text('$_currentStock', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => setState(() => _currentStock += 5),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Reminders
            SwitchListTile(
              title: const Text('Reminder Notifications'),
              subtitle: const Text('Get reminded to take your medicine'),
              value: _reminderEnabled,
              onChanged: (v) => setState(() => _reminderEnabled = v),
              activeThumbColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: Colors.white,
            ),

            const SizedBox(height: 12),

            // Special Instructions
            TextField(
              controller: _instructionsController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Special Instructions',
                hintText: 'e.g., Take with plenty of water',
                prefixIcon: Icon(Icons.notes_rounded, color: AppColors.primary),
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
      canProceed: true,
    );
  }

  // ============================================
  // STEP 6: Review & Save
  // ============================================
  Widget _buildStep6Review() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Review & Save',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Confirm your medicine details',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),

          // Medicine Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _medicineColor != null
                            ? Color(_medicineColor!.colorValue).withOpacity(0.2)
                            : AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(_dosageForm.icon, style: const TextStyle(fontSize: 32)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _nameController.text.isEmpty ? 'Medicine Name' : _nameController.text,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          if (_strengthController.text.isNotEmpty)
                            Text(_strengthController.text, style: const TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),

                // Details
                _buildReviewRow('Health Category', _selectedCategory?.displayName ?? _customCategoryName),
                _buildReviewRow('Dosage Form', _dosageForm.displayName),
                _buildReviewRow('Quantity', '${_dosageAmount % 1 == 0 ? _dosageAmount.toInt() : _dosageAmount} ${_dosageForm.unit}'),
                _buildReviewRow('Frequency', _frequencyType.displayName),
                if (_scheduledTimes.isNotEmpty)
                  _buildReviewRow('Times', _scheduledTimes.map((t) => t.formattedTime).join(', ')),
                _buildReviewRow('Meal Timing', _mealTiming.displayName),
                _buildReviewRow('Duration', _durationDays == null ? 'Ongoing' : '$_durationDays days'),
                if (_trackStock) _buildReviewRow('Stock', '$_currentStock units'),
                _buildReviewRow('Reminders', _reminderEnabled ? 'Enabled' : 'Disabled'),
                if (_medicineColor != null) _buildReviewRow('Color', _medicineColor!.displayName),
                if (_medicineShape != null) _buildReviewRow('Shape', _medicineShape!.displayName),
              ],
            ),
          ),

          if (_warnings.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildWarningsCard(),
          ],

          const SizedBox(height: 32),

          // Save Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveMedicine,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_rounded),
                        const SizedBox(width: 8),
                        Text(
                          widget.editMedicine != null ? 'Update Medicine' : 'Save & Activate Reminder',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // Helper: Step Container
  // ============================================
  Widget _buildStepContainer({
    required String title,
    required String subtitle,
    required Widget child,
    bool canProceed = true,
  }) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(fontSize: 16, color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          Expanded(child: child),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: canProceed ? _nextStep : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
