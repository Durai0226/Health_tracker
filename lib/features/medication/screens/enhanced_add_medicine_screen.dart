import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/widgets/common_widgets.dart';
import '../models/medicine_enums.dart';
import '../models/medicine_schedule.dart';
import '../models/enhanced_medicine.dart';
import '../services/medicine_storage_service.dart';
import '../services/drug_interaction_service.dart';

/// Premium Add Medicine Flow with all Medisafe/Apple Health features
class EnhancedAddMedicineScreen extends StatefulWidget {
  final EnhancedMedicine? editMedicine; // For editing existing medicine

  const EnhancedAddMedicineScreen({super.key, this.editMedicine});

  @override
  State<EnhancedAddMedicineScreen> createState() => _EnhancedAddMedicineScreenState();
}

class _EnhancedAddMedicineScreenState extends State<EnhancedAddMedicineScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 8;
  bool _isSaving = false;

  // Basic Info
  final _nameController = TextEditingController();
  final _strengthController = TextEditingController();
  DosageForm _dosageForm = DosageForm.tablet;
  double _dosageAmount = 1;
  String? _purpose;

  // Schedule
  FrequencyType _frequencyType = FrequencyType.onceDaily;
  List<ScheduledTime> _scheduledTimes = [ScheduledTime(hour: 8, minute: 0)];
  MealTiming _mealTiming = MealTiming.anytime;
  int? _durationDays;
  DateTime _startDate = DateTime.now();
  final List<int> _specificDays = [];
  int _intervalHours = 8;
  bool _isPRN = false;

  // Stock & Refill
  bool _trackStock = false;
  int _currentStock = 30;
  int _lowStockThreshold = 7;
  bool _refillReminder = false;

  // Reminders
  bool _reminderEnabled = true;
  bool _criticalAlert = false;
  int _snoozeMinutes = 10;

  // Pill Identification
  MedicineColor? _medicineColor;
  MedicineShape? _medicineShape;
  String? _imprint;

  // Additional Info
  final _instructionsController = TextEditingController();
  final _notesController = TextEditingController();
  String? _selectedDoctorId;
  String? _selectedDependentId;

  // Drug Interactions
  List<String> _warnings = [];

  // Health & Tracking
  List<HealthCategory> _selectedHealthCategories = [];
  final _customCategoryController = TextEditingController();
  bool _requiresContinuousIntake = false;
  int _minimumConsecutiveDays = 7;

  @override
  void initState() {
    super.initState();
    if (widget.editMedicine != null) {
      _loadExistingMedicine();
    }
  }

  void _loadExistingMedicine() {
    final med = widget.editMedicine!;
    _nameController.text = med.name;
    _strengthController.text = med.strength ?? '';
    _dosageForm = med.dosageForm;
    _dosageAmount = med.dosageAmount;
    _purpose = med.purpose;
    _frequencyType = med.schedule.frequencyType;
    _scheduledTimes = med.schedule.times;
    _mealTiming = med.schedule.mealTiming;
    _durationDays = med.schedule.durationDays;
    _startDate = med.schedule.startDate ?? DateTime.now();
    _trackStock = med.currentStock != null;
    _currentStock = med.currentStock ?? 30;
    _lowStockThreshold = med.lowStockThreshold ?? 7;
    _refillReminder = med.refillReminderEnabled;
    _reminderEnabled = med.reminderEnabled;
    _criticalAlert = med.criticalAlert;
    _snoozeMinutes = med.snoozeMinutes;
    _medicineColor = med.color;
    _medicineShape = med.shape;
    _imprint = med.imprint;
    _instructionsController.text = med.instructions ?? '';
    _notesController.text = med.notes ?? '';
    _selectedDoctorId = med.doctorId;
    _selectedDependentId = med.dependentId;
    _selectedHealthCategories = med.healthCategories ?? [];
    _customCategoryController.text = med.customHealthCategory ?? '';
    _requiresContinuousIntake = med.requiresContinuousIntake;
    _minimumConsecutiveDays = med.minimumConsecutiveDays ?? 7;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _strengthController.dispose();
    _instructionsController.dispose();
    _notesController.dispose();
    _customCategoryController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
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

  Future<void> _saveMedicine() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final schedule = MedicineSchedule(
        frequencyType: _frequencyType,
        times: _scheduledTimes,
        intervalHours: _frequencyType == FrequencyType.everyXHours ? _intervalHours : null,
        specificDays: _frequencyType == FrequencyType.specificDays ? _specificDays : null,
        startDate: _startDate,
        durationDays: _durationDays,
        mealTiming: _mealTiming,
        isPRN: _isPRN,
      );

      final medicine = EnhancedMedicine(
        id: widget.editMedicine?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        strength: _strengthController.text.isNotEmpty ? _strengthController.text : null,
        dosageForm: _dosageForm,
        dosageAmount: _dosageAmount,
        schedule: schedule,
        purpose: _purpose,
        currentStock: _trackStock ? _currentStock : null,
        lowStockThreshold: _trackStock ? _lowStockThreshold : null,
        refillReminderEnabled: _refillReminder,
        reminderEnabled: _reminderEnabled,
        criticalAlert: _criticalAlert,
        snoozeMinutes: _snoozeMinutes,
        color: _medicineColor,
        shape: _medicineShape,
        imprint: _imprint,
        instructions: _instructionsController.text.isNotEmpty ? _instructionsController.text : null,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        doctorId: _selectedDoctorId,
        dependentId: _selectedDependentId,
        warnings: _warnings.isNotEmpty ? _warnings : null,
        createdAt: widget.editMedicine?.createdAt,
        healthCategories: _selectedHealthCategories.isNotEmpty ? _selectedHealthCategories : null,
        customHealthCategory: _customCategoryController.text.isNotEmpty ? _customCategoryController.text : null,
        requiresContinuousIntake: _requiresContinuousIntake,
        minimumConsecutiveDays: _requiresContinuousIntake ? _minimumConsecutiveDays : null,
      );

      if (widget.editMedicine != null) {
        await MedicineStorageService.updateMedicine(medicine);
      } else {
        await MedicineStorageService.addMedicine(medicine);
      }

      // Schedule notifications
      if (_reminderEnabled && !_isPRN) {
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
        String errorMessage = 'Failed to save medicine. Please try again.';
        if (e.toString().contains('Box not found')) {
          errorMessage = 'Storage error: Database not initialized. Please restart the app.';
        } else {
          errorMessage = 'Error: ${e.toString()}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
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
            if (_currentPage > 0) {
              _prevPage();
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
          if (_currentPage == _totalPages - 1)
            TextButton(
              onPressed: _isSaving ? null : _saveMedicine,
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildProgressIndicator(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) => setState(() => _currentPage = index),
              children: [
                _buildBasicInfoPage(),
                _buildDosagePage(),
                _buildSchedulePage(),
                _buildTimingPage(),
                _buildStockPage(),
                _buildIdentificationPage(),
                _buildHealthAndTrackingPage(),
                _buildReviewPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(_totalPages, (index) {
          final isComplete = index < _currentPage;
          final isCurrent = index == _currentPage;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: isComplete || isCurrent ? AppColors.primary : AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (index < _totalPages - 1) const SizedBox(width: 4),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContainer({
    required String title,
    required String subtitle,
    required Widget child,
    bool showNext = true,
    bool canProceed = true,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(fontSize: 16, color: AppColors.textSecondary)),
          const SizedBox(height: 32),
          child,
          const SizedBox(height: 32),
          if (showNext)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: canProceed ? _nextPage : null,
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

  Widget _buildBasicInfoPage() {
    return _buildStepContainer(
      title: 'Medicine Name',
      subtitle: 'What medication are you adding?',
      canProceed: _nameController.text.isNotEmpty,
      child: Column(
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
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
          const SizedBox(height: 16),
          TextField(
            controller: _strengthController,
            decoration: const InputDecoration(
              hintText: 'Strength (e.g., 500mg)',
              prefixIcon: Icon(Icons.science_rounded, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 24),
          _buildPurposeSelector(),
          if (_warnings.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildInteractionWarnings(),
          ],
        ],
      ),
    );
  }

  Widget _buildPurposeSelector() {
    final purposes = [
      'Pain Relief', 'Blood Pressure', 'Diabetes', 'Cholesterol',
      'Thyroid', 'Vitamins', 'Antibiotics', 'Mental Health',
      'Heart', 'Allergy', 'Digestive', 'Other',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('What is it for?', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: purposes.map((purpose) {
            final isSelected = _purpose == purpose;
            return GestureDetector(
              onTap: () => setState(() => _purpose = isSelected ? null : purpose),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
                ),
                child: Text(
                  purpose,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildInteractionWarnings() {
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

  Widget _buildDosagePage() {
    return _buildStepContainer(
      title: 'Dosage',
      subtitle: 'How much do you take each time?',
      child: Column(
        children: [
          // Dosage Amount
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildAmountButton(Icons.remove_rounded, () {
                  if (_dosageAmount > 0.5) setState(() => _dosageAmount -= 0.5);
                }),
                const SizedBox(width: 32),
                Column(
                  children: [
                    Text(
                      _dosageAmount % 1 == 0 ? _dosageAmount.toInt().toString() : _dosageAmount.toString(),
                      style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                    ),
                    Text(_dosageForm.unit, style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(width: 32),
                _buildAmountButton(Icons.add_rounded, () => setState(() => _dosageAmount += 0.5)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Dosage Form
          const Text('Form', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.9,
            children: DosageForm.values.take(8).map((form) {
              final isSelected = _dosageForm == form;
              return GestureDetector(
                onTap: () => setState(() => _dosageForm = form),
                child: CommonCard(
                  backgroundColor: isSelected ? AppColors.primary.withOpacity(0.1) : null,
                  border: isSelected ? Border.all(color: AppColors.primary) : null,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          form.icon,
                          style: TextStyle(
                            fontSize: 32,
                            color: isSelected ? AppColors.primary : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          form.displayName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? AppColors.primary : AppColors.textPrimary,
                          ),
                        ),
                      ],
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

  Widget _buildAmountButton(IconData icon, VoidCallback onTap) {
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

  Widget _buildSchedulePage() {
    return _buildStepContainer(
      title: 'Frequency',
      subtitle: 'How often do you take this medicine?',
      child: Column(
        children: [
          ...FrequencyType.values.map((freq) {
            final isSelected = _frequencyType == freq;
            return GestureDetector(
              onTap: () => setState(() {
                _frequencyType = freq;
                _isPRN = freq == FrequencyType.asNeeded;
                _updateScheduledTimes();
              }),
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
                    const SizedBox(width: 16),
                    Text(
                      freq.displayName,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          if (_frequencyType == FrequencyType.everyXHours) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Every '),
                SizedBox(
                  width: 80,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(hintText: '8'),
                    onChanged: (v) => _intervalHours = int.tryParse(v) ?? 8,
                  ),
                ),
                const Text(' hours'),
              ],
            ),
          ],
          if (_frequencyType == FrequencyType.specificDays) ...[
            const SizedBox(height: 16),
            _buildDaySelector(),
          ],
        ],
      ),
    );
  }

  Widget _buildDaySelector() {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Row(
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
    );
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

  Widget _buildTimingPage() {
    return _buildStepContainer(
      title: 'Reminder Times',
      subtitle: 'When should we remind you?',
      child: Column(
        children: [
          if (!_isPRN) ...[
            ...List.generate(_scheduledTimes.length, (index) {
              final time = _scheduledTimes[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  tileColor: Colors.white,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.access_time_rounded, color: AppColors.primary),
                  ),
                  title: Text(time.formattedTime, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: time.label != null ? Text(time.label!) : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_rounded),
                    onPressed: () => _editTime(index),
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
          ],
          // Meal timing
          const Text('Take with food?', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: MealTiming.values.map((timing) {
              final isSelected = _mealTiming == timing;
              return GestureDetector(
                onTap: () => setState(() => _mealTiming = timing),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(timing.icon),
                      const SizedBox(width: 6),
                      Text(
                        timing.displayName,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          // Duration
          const Text('Duration', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [7, 14, 30, 90, -1].map((days) {
              final isSelected = _durationDays == days || (days == -1 && _durationDays == null);
              return GestureDetector(
                onTap: () => setState(() => _durationDays = days == -1 ? null : days),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
                  ),
                  child: Text(
                    days == -1 ? 'Ongoing' : '$days days',
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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

  Widget _buildStockPage() {
    return _buildStepContainer(
      title: 'Stock & Refill',
      subtitle: 'Track your medicine supply',
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Track Stock'),
            subtitle: const Text('Get notified when running low'),
            value: _trackStock,
            onChanged: (v) => setState(() => _trackStock = v),
            activeThumbColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            tileColor: Colors.white,
          ),
          if (_trackStock) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Current Stock'),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () {
                              if (_currentStock > 0) setState(() => _currentStock--);
                            },
                          ),
                          Text('$_currentStock', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () => setState(() => _currentStock++),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Low Stock Alert'),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () {
                              if (_lowStockThreshold > 1) setState(() => _lowStockThreshold--);
                            },
                          ),
                          Text('$_lowStockThreshold', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () => setState(() => _lowStockThreshold++),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Reminder Notifications'),
            subtitle: const Text('Get reminded to take your medicine'),
            value: _reminderEnabled,
            onChanged: (v) => setState(() => _reminderEnabled = v),
            activeThumbColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            tileColor: Colors.white,
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Critical Alert'),
            subtitle: const Text('Bypass Do Not Disturb for important meds'),
            value: _criticalAlert,
            onChanged: (v) => setState(() => _criticalAlert = v),
            activeThumbColor: AppColors.error,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            tileColor: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildIdentificationPage() {
    return _buildStepContainer(
      title: 'Pill Identification',
      subtitle: 'Help identify your medicine (optional)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Color', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: MedicineColor.values.map((color) {
              final isSelected = _medicineColor == color;
              return GestureDetector(
                onTap: () => setState(() => _medicineColor = isSelected ? null : color),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Color(color.colorValue),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: isSelected ? 3 : 1,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8)]
                        : null,
                  ),
                  child: isSelected
                      ? Icon(Icons.check, color: color == MedicineColor.white ? Colors.black : Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
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
          TextField(
            decoration: const InputDecoration(
              hintText: 'Imprint (text on pill)',
              prefixIcon: Icon(Icons.text_fields_rounded, color: AppColors.primary),
            ),
            onChanged: (v) => _imprint = v,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _instructionsController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Special instructions',
              prefixIcon: Icon(Icons.notes_rounded, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthAndTrackingPage() {
    return _buildStepContainer(
      title: 'Health & Tracking',
      subtitle: 'Organize and track your health goals',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Health Categories', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: HealthCategory.values.where((c) => c != HealthCategory.custom).map((category) {
              final isSelected = _selectedHealthCategories.contains(category);
              return FilterChip(
                label: Text('${category.icon} ${category.displayName}'),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedHealthCategories.add(category);
                    } else {
                      _selectedHealthCategories.remove(category);
                    }
                  });
                },
                selectedColor: AppColors.primary.withOpacity(0.2),
                checkmarkColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : AppColors.border,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _customCategoryController,
            decoration: const InputDecoration(
              hintText: 'Custom Category (optional)',
              prefixIcon: Icon(Icons.category_rounded, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 32),
          const Text('Tracking Requirements', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Require Continuous Intake'),
                  subtitle: const Text('Prevent skipping after consecutive days'),
                  value: _requiresContinuousIntake,
                  onChanged: (v) => setState(() => _requiresContinuousIntake = v),
                  activeThumbColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                ),
                if (_requiresContinuousIntake) ...[
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Minimum consecutive days before skip is prevented'),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$_minimumConsecutiveDays days',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _minimumConsecutiveDays.toDouble(),
                    min: 3,
                    max: 30,
                    divisions: 27,
                    activeColor: AppColors.primary,
                    label: '$_minimumConsecutiveDays days',
                    onChanged: (v) => setState(() => _minimumConsecutiveDays = v.toInt()),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Review', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Confirm your medicine details', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          _buildReviewCard(),
          if (_warnings.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildInteractionWarnings(),
          ],
          const SizedBox(height: 32),
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
                  : Text(
                      widget.editMedicine != null ? 'Update Medicine' : 'Add Medicine',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
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
          _buildReviewRow('Dosage', '$_dosageAmount ${_dosageForm.unit}'),
          _buildReviewRow('Frequency', _frequencyType.displayName),
          if (!_isPRN && _scheduledTimes.isNotEmpty)
            _buildReviewRow('Times', _scheduledTimes.map((t) => t.formattedTime).join(', ')),
          _buildReviewRow('Meal Timing', _mealTiming.displayName),
          _buildReviewRow('Duration', _durationDays == null ? 'Ongoing' : '$_durationDays days'),
          if (_trackStock) _buildReviewRow('Stock', '$_currentStock (alert at $_lowStockThreshold)'),
          _buildReviewRow('Reminders', _reminderEnabled ? 'Enabled' : 'Disabled'),
          if (_purpose != null) _buildReviewRow('Purpose', _purpose!),
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
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
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
                onChanged: (query) {
                  // Search functionality
                },
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
}
