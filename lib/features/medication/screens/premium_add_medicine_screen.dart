import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/services/notification_service.dart';
import '../models/medicine_enums.dart';
import '../models/medicine_schedule.dart';
import '../models/enhanced_medicine.dart';
import '../models/doctor_pharmacy.dart';
import '../models/dependent_profile.dart';
import '../services/medicine_storage_service.dart';
import 'doctors/doctor_list_screen.dart';
import 'pharmacies/pharmacy_list_screen.dart';
import 'dependents/dependent_list_screen.dart';

/// Premium Add Medicine Screen - Modern step-by-step wizard
/// Features: Glassmorphism, smooth animations, intuitive flow
class PremiumAddMedicineScreen extends StatefulWidget {
  final EnhancedMedicine? editMedicine;

  const PremiumAddMedicineScreen({super.key, this.editMedicine});

  @override
  State<PremiumAddMedicineScreen> createState() => _PremiumAddMedicineScreenState();
}

class _PremiumAddMedicineScreenState extends State<PremiumAddMedicineScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 6; // Increased from 5
  bool _isSaving = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  final HapticService _hapticService = HapticService();

  // Medication theme colors
  static const Color _medicationPrimary = Color(0xFF00BFA5);
  static const Color _medicationSecondary = Color(0xFF00897B);

  // Step 1: Medicine Details
  final _nameController = TextEditingController();
  final _strengthController = TextEditingController();
  DosageForm _dosageForm = DosageForm.tablet;
  double _dosageAmount = 1;

  // Step 2: Schedule Configuration
  FrequencyType _frequencyType = FrequencyType.onceDaily;
  List<ScheduledTime> _scheduledTimes = [ScheduledTime(hour: 8, minute: 0, label: 'Morning')];
  final List<int> _specificDays = [1, 2, 3, 4, 5]; // Mon-Fri by default
  DateTime _startDate = DateTime.now();

  // Step 3: Meal Timing
  MealTiming _mealTiming = MealTiming.anytime;

  // Step 4: Care Info (Providers & Profile)
  Doctor? _selectedDoctor;
  Pharmacy? _selectedPharmacy;
  DependentProfile? _selectedDependent;

  // Step 5: Visual & Reminders
  MedicineColor? _medicineColor;
  bool _reminderEnabled = true;
  final _instructionsController = TextEditingController();

  // Step 6: Stock Tracking
  bool _trackStock = false;
  int _currentStock = 30;
  int _lowStockThreshold = 7;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    if (widget.editMedicine != null) {
      _loadExistingMedicine();
    }
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();
  }

  void _loadExistingMedicine() {
    final med = widget.editMedicine!;
    _nameController.text = med.name;
    _strengthController.text = med.strength ?? '';
    _dosageForm = med.dosageForm;
    _dosageAmount = med.dosageAmount;
    _frequencyType = med.schedule.frequencyType;
    _scheduledTimes = med.schedule.times.isNotEmpty
        ? med.schedule.times
        : [ScheduledTime(hour: 8, minute: 0)];
    if (med.schedule.specificDays != null) {
      _specificDays.clear();
      _specificDays.addAll(med.schedule.specificDays!);
    }
    _startDate = med.schedule.startDate ?? DateTime.now();
    _mealTiming = med.schedule.mealTiming;
    _medicineColor = med.color;
    _reminderEnabled = med.reminderEnabled;
    _instructionsController.text = med.instructions ?? '';
    _trackStock = med.currentStock != null;
    _currentStock = med.currentStock ?? 30;
    _lowStockThreshold = med.lowStockThreshold ?? 7;

    _loadCareInfo(med);
  }

  Future<void> _loadCareInfo(EnhancedMedicine med) async {
    if (med.doctorId != null) {
      _selectedDoctor = await MedicineCleanStorageService.getDoctor(med.doctorId!);
    }
    if (med.pharmacyId != null) {
      _selectedPharmacy = await MedicineCleanStorageService.getPharmacy(med.pharmacyId!);
    }
    if (med.dependentId != null) {
      // Assuming getDependent exists or we filter
      final dependents = await MedicineCleanStorageService.getAllDependents();
      try {
        _selectedDependent = dependents.firstWhere((d) => d.id == med.dependentId);
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pageController.dispose();
    _nameController.dispose();
    _strengthController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      _hapticService.selection();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _hapticService.selection();
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0:
        return _nameController.text.trim().isNotEmpty;
      default:
        return true;
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
      final schedule = MedicineSchedule(
        frequencyType: _frequencyType,
        times: _scheduledTimes,
        specificDays: _frequencyType == FrequencyType.specificDays ? _specificDays : null,
        startDate: _startDate,
        mealTiming: _mealTiming,
        isPRN: _frequencyType == FrequencyType.asNeeded,
      );

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
        color: _medicineColor,
        instructions: _instructionsController.text.isNotEmpty ? _instructionsController.text : null,
        createdAt: widget.editMedicine?.createdAt,
        doctorId: _selectedDoctor?.id,
        pharmacyId: _selectedPharmacy?.id,
        dependentId: _selectedDependent?.id,
      );

      if (widget.editMedicine != null) {
        await MedicineCleanStorageService.updateMedicine(medicine);
      } else {
        await MedicineCleanStorageService.addMedicine(medicine);
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

      _hapticService.success();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Text(widget.editMedicine != null ? 'Medicine updated!' : 'Medicine added successfully!'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('Error saving medicine: $e');
      _hapticService.error();
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
    final isDark = AppColors.isDark(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF0F4F8),
      body: Stack(
        children: [
          // Background
          _buildBackground(isDark),
          
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  _buildHeader(isDark),
                  _buildProgressIndicator(isDark),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (index) => setState(() => _currentStep = index),
                      children: [
                        _buildStep1MedicineDetails(isDark),
                        _buildStep2Schedule(isDark),
                        _buildStep3MealTiming(isDark),
                        _buildStep4CareInfo(isDark),
                        _buildStep5Reminders(isDark), // Renamed from _buildStep4Reminders
                        _buildStep6StockReview(isDark), // Renamed from _buildStep5StockReview
                      ],
                    ),
                  ),
                  _buildBottomButtons(isDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground(bool isDark) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0A1628), const Color(0xFF0F2027)]
                : [const Color(0xFFF0F4F8), const Color(0xFFE8F5E9)],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (_currentStep > 0) {
                _prevStep();
              } else {
                Navigator.pop(context);
              }
            },
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _currentStep > 0 ? Icons.arrow_back_rounded : Icons.close_rounded,
                size: 20,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
          const Spacer(),
          Text(
            widget.editMedicine != null ? 'Edit Medicine' : 'Add Medicine',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _medicationPrimary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_currentStep + 1}/$_totalSteps',
              style: TextStyle(
                color: _medicationPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: List.generate(_totalSteps, (index) {
          final isActive = index <= _currentStep;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: index < _totalSteps - 1 ? 8 : 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: isActive
                    ? const LinearGradient(
                        colors: [_medicationPrimary, _medicationSecondary],
                      )
                    : null,
                color: isActive ? null : (isDark ? Colors.white12 : AppColors.border),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ============ STEP 1: Medicine Details ============
  Widget _buildStep1MedicineDetails(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepTitle('Medicine Details', 'Enter your medication information', isDark),
          const SizedBox(height: 24),

          // Medicine Name
          _buildTextField(
            controller: _nameController,
            label: 'Medicine Name',
            hint: 'e.g., Metformin, Aspirin',
            icon: Icons.medication_rounded,
            isDark: isDark,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // Strength
          _buildTextField(
            controller: _strengthController,
            label: 'Strength (optional)',
            hint: 'e.g., 500mg, 10mg',
            icon: Icons.science_rounded,
            isDark: isDark,
          ),
          const SizedBox(height: 24),

          // Dosage Form
          Text(
            'Dosage Form',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: DosageForm.values.length - 1, // Exclude 'other'
              itemBuilder: (context, index) {
                final form = DosageForm.values[index];
                final isSelected = _dosageForm == form;
                return GestureDetector(
                  onTap: () {
                    _hapticService.selection();
                    setState(() => _dosageForm = form);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 80,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(colors: [_medicationPrimary, _medicationSecondary])
                          : null,
                      color: isSelected ? null : (isDark ? Colors.white.withOpacity(0.05) : Colors.white),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? _medicationPrimary : (isDark ? Colors.white12 : AppColors.border),
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: _medicationPrimary.withOpacity(0.3), blurRadius: 12)]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(form.icon, style: const TextStyle(fontSize: 28)),
                        const SizedBox(height: 6),
                        Text(
                          form.displayName,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppColors.textPrimary),
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
          Text(
            'Quantity per Dose',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildQuantitySelector(isDark),
        ],
      ),
    );
  }

  Widget _buildQuantitySelector(bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white12 : AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildQuantityButton(Icons.remove_rounded, () {
                if (_dosageAmount > 0.5) {
                  _hapticService.light();
                  setState(() => _dosageAmount -= 0.5);
                }
              }, isDark),
              const SizedBox(width: 32),
              Column(
                children: [
                  Text(
                    _dosageAmount % 1 == 0 ? _dosageAmount.toInt().toString() : _dosageAmount.toString(),
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    _dosageForm.unit,
                    style: TextStyle(color: isDark ? Colors.white60 : AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(width: 32),
              _buildQuantityButton(Icons.add_rounded, () {
                _hapticService.light();
                setState(() => _dosageAmount += 0.5);
              }, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuantityButton(IconData icon, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_medicationPrimary, _medicationSecondary]),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: _medicationPrimary.withOpacity(0.3), blurRadius: 10),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }

  // ============ STEP 2: Schedule ============
  Widget _buildStep2Schedule(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepTitle('Schedule', 'How often do you take this?', isDark),
          const SizedBox(height: 24),

          // Frequency options
          ...FrequencyType.values.take(6).map((freq) => _buildFrequencyOption(freq, isDark)),

          // Time slots
          if (_frequencyType != FrequencyType.asNeeded && _scheduledTimes.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Reminder Times',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ..._scheduledTimes.asMap().entries.map((entry) => _buildTimeSlot(entry.key, entry.value, isDark)),
          ],

          // Specific days selector
          if (_frequencyType == FrequencyType.specificDays) ...[
            const SizedBox(height: 24),
            _buildDaySelector(isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildFrequencyOption(FrequencyType freq, bool isDark) {
    final isSelected = _frequencyType == freq;
    return GestureDetector(
      onTap: () {
        _hapticService.selection();
        setState(() {
          _frequencyType = freq;
          _updateScheduledTimes();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(colors: [_medicationPrimary.withOpacity(0.15), _medicationSecondary.withOpacity(0.1)])
              : null,
          color: isSelected ? null : (isDark ? Colors.white.withOpacity(0.05) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _medicationPrimary : (isDark ? Colors.white12 : AppColors.border),
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
                gradient: isSelected
                    ? const LinearGradient(colors: [_medicationPrimary, _medicationSecondary])
                    : null,
                border: Border.all(
                  color: isSelected ? _medicationPrimary : (isDark ? Colors.white38 : AppColors.textSecondary),
                  width: 2,
                ),
              ),
              child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
            ),
            const SizedBox(width: 14),
            Text(
              freq.displayName,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? _medicationPrimary : (isDark ? Colors.white : AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSlot(int index, ScheduledTime time, bool isDark) {
    return GestureDetector(
      onTap: () => _selectTime(index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white12 : AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _medicationPrimary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.access_time_rounded, color: _medicationPrimary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    time.label ?? 'Dose ${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    time.formattedTime,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.edit_rounded,
              color: isDark ? Colors.white38 : AppColors.textLight,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectTime(int index) async {
    final time = _scheduledTimes[index];
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: time.hour, minute: time.minute),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: _medicationPrimary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _scheduledTimes[index] = time.copyWith(hour: picked.hour, minute: picked.minute);
      });
    }
  }

  Widget _buildDaySelector(bool isDark) {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Days',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(7, (index) {
            final dayNumber = index + 1;
            final isSelected = _specificDays.contains(dayNumber);
            return GestureDetector(
              onTap: () {
                _hapticService.light();
                setState(() {
                  if (isSelected) {
                    _specificDays.remove(dayNumber);
                  } else {
                    _specificDays.add(dayNumber);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(colors: [_medicationPrimary, _medicationSecondary])
                      : null,
                  color: isSelected ? null : (isDark ? Colors.white.withOpacity(0.05) : Colors.white),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? _medicationPrimary : (isDark ? Colors.white24 : AppColors.border),
                  ),
                ),
                child: Center(
                  child: Text(
                    days[index],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppColors.textPrimary),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ============ STEP 3: Meal Timing ============
  Widget _buildStep3MealTiming(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepTitle('Meal Instructions', 'When should you take this medicine?', isDark),
          const SizedBox(height: 24),

          ...MealTiming.values.map((timing) => _buildMealOption(timing, isDark)),
        ],
      ),
    );
  }

  Widget _buildMealOption(MealTiming timing, bool isDark) {
    final isSelected = _mealTiming == timing;
    return GestureDetector(
      onTap: () {
        _hapticService.selection();
        setState(() => _mealTiming = timing);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(colors: [_medicationPrimary.withOpacity(0.15), _medicationSecondary.withOpacity(0.1)])
              : null,
          color: isSelected ? null : (isDark ? Colors.white.withOpacity(0.05) : Colors.white),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? _medicationPrimary : (isDark ? Colors.white12 : AppColors.border),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(timing.icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                timing.displayName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? _medicationPrimary : (isDark ? Colors.white : AppColors.textPrimary),
                ),
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_medicationPrimary, _medicationSecondary]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              ),
          ],
        ),
      ),
    );
  }

  // ============ STEP 4: Care Info ============
  Widget _buildStep4CareInfo(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepTitle('Care Team & Profile', 'Who is this for?', isDark),
          const SizedBox(height: 24),

          // Dependent Selection
          _buildSelectionTile(
            title: _selectedDependent?.name ?? 'Myself',
            subtitle: 'Patient Profile',
            icon: Icons.person_outline_rounded,
            isDark: isDark,
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DependentListScreen(isSelectionMode: true)),
              );
              if (result != null && result is DependentProfile) {
                setState(() => _selectedDependent = result);
              } else if (result == 'self') {
                 setState(() => _selectedDependent = null); // Null means self/default
              }
            },
          ),
          const SizedBox(height: 16),

          // Doctor Selection
          _buildSelectionTile(
            title: _selectedDoctor?.name ?? 'Select Doctor',
            subtitle: 'Prescriber',
            icon: Icons.medical_services_outlined,
            isDark: isDark,
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DoctorListScreen(isSelectionMode: true)),
              );
              if (result != null && result is Doctor) {
                setState(() => _selectedDoctor = result);
              }
            },
            onClear: _selectedDoctor != null ? () => setState(() => _selectedDoctor = null) : null,
          ),
          const SizedBox(height: 16),

          // Pharmacy Selection
          _buildSelectionTile(
            title: _selectedPharmacy?.name ?? 'Select Pharmacy',
            subtitle: 'Pharmacy',
            icon: Icons.local_pharmacy_outlined,
            isDark: isDark,
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PharmacyListScreen(isSelectionMode: true)),
              );
              if (result != null && result is Pharmacy) {
                setState(() => _selectedPharmacy = result);
              }
            },
            onClear: _selectedPharmacy != null ? () => setState(() => _selectedPharmacy = null) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
    VoidCallback? onClear,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : AppColors.border),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _medicationPrimary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _medicationPrimary, size: 24),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: isDark ? Colors.white60 : AppColors.textSecondary,
          ),
        ),
        trailing: onClear != null
            ? IconButton(
                icon: Icon(Icons.close_rounded, size: 20, color: isDark ? Colors.white38 : AppColors.textLight),
                onPressed: onClear,
              )
            : Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white38 : AppColors.textLight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  // ============ STEP 5: Reminders ============
  Widget _buildStep5Reminders(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepTitle('Reminders & Notes', 'Customize your experience', isDark),
          const SizedBox(height: 24),

          // Reminder toggle
          _buildToggleCard(
            icon: Icons.notifications_active_rounded,
            title: 'Enable Reminders',
            subtitle: 'Get notified when it\'s time to take your medicine',
            value: _reminderEnabled,
            onChanged: (val) => setState(() => _reminderEnabled = val),
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          // Color selection
          Text(
            'Medicine Color (optional)',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: MedicineColor.values.map((color) {
              final isSelected = _medicineColor == color;
              return GestureDetector(
                onTap: () {
                  _hapticService.light();
                  setState(() => _medicineColor = isSelected ? null : color);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Color(color.colorValue),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? _medicationPrimary : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: Color(color.colorValue).withOpacity(0.5), blurRadius: 10)]
                        : null,
                  ),
                  child: isSelected
                      ? Icon(Icons.check, color: color == MedicineColor.white ? Colors.black : Colors.white, size: 22)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Instructions
          _buildTextField(
            controller: _instructionsController,
            label: 'Special Instructions (optional)',
            hint: 'e.g., Take with water, Avoid dairy',
            icon: Icons.notes_rounded,
            isDark: isDark,
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  // ============ STEP 6: Stock & Review ============
  Widget _buildStep6StockReview(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepTitle('Stock & Review', 'Track your inventory and confirm', isDark),
          const SizedBox(height: 24),

          // Stock tracking toggle
          _buildToggleCard(
            icon: Icons.inventory_2_rounded,
            title: 'Track Stock',
            subtitle: 'Get alerts when running low',
            value: _trackStock,
            onChanged: (val) => setState(() => _trackStock = val),
            isDark: isDark,
          ),

          if (_trackStock) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildNumberInput(
                    label: 'Current Stock',
                    value: _currentStock,
                    onChanged: (val) => setState(() => _currentStock = val),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildNumberInput(
                    label: 'Low Stock Alert',
                    value: _lowStockThreshold,
                    onChanged: (val) => setState(() => _lowStockThreshold = val),
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 32),

          // Review summary
          Text(
            'Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildReviewCard(isDark),
        ],
      ),
    );
  }

  Widget _buildReviewCard(bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _medicationPrimary.withOpacity(0.1),
                _medicationSecondary.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _medicationPrimary.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_medicationPrimary, _medicationSecondary]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(_dosageForm.icon, style: const TextStyle(fontSize: 30)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _nameController.text.isEmpty ? 'Medicine Name' : _nameController.text,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        if (_strengthController.text.isNotEmpty)
                          Text(
                            _strengthController.text,
                            style: TextStyle(color: isDark ? Colors.white60 : AppColors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildReviewRow('Dosage', '${_dosageAmount % 1 == 0 ? _dosageAmount.toInt() : _dosageAmount} ${_dosageForm.unit}', isDark),
              _buildReviewRow('Frequency', _frequencyType.displayName, isDark),
              _buildReviewRow('Meal Timing', _mealTiming.displayName, isDark),
              _buildReviewRow('Reminders', _reminderEnabled ? 'Enabled' : 'Disabled', isDark),
              if (_trackStock)
                _buildReviewRow('Stock', '$_currentStock (alert at $_lowStockThreshold)', isDark),
              if (_selectedDependent != null)
                _buildReviewRow('For', _selectedDependent!.name, isDark),
              if (_selectedDoctor != null)
                _buildReviewRow('Doctor', _selectedDoctor!.name, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: isDark ? Colors.white60 : AppColors.textSecondary),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ============ COMMON WIDGETS ============
  Widget _buildStepTitle(String title, String subtitle, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white60 : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged,
      style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: isDark ? Colors.white60 : AppColors.textSecondary),
        hintStyle: TextStyle(color: isDark ? Colors.white38 : AppColors.textLight),
        prefixIcon: Icon(icon, color: _medicationPrimary),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? Colors.white12 : AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? Colors.white12 : AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _medicationPrimary, width: 2),
        ),
      ),
    );
  }

  Widget _buildToggleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white12 : AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _medicationPrimary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: _medicationPrimary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: _medicationPrimary,
          ),
        ],
      ),
    );
  }

  Widget _buildNumberInput({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () {
                  if (value > 1) onChanged(value - 1);
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _medicationPrimary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.remove, color: _medicationPrimary, size: 20),
                ),
              ),
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () => onChanged(value + 1),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _medicationPrimary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add, color: _medicationPrimary, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons(bool isDark) {
    final isLastStep = _currentStep == _totalSteps - 1;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _prevStep,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: isDark ? Colors.white38 : AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    'Back',
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: _canProceed()
                    ? (isLastStep ? _saveMedicine : _nextStep)
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: _canProceed()
                        ? const LinearGradient(colors: [_medicationPrimary, _medicationSecondary])
                        : null,
                    color: _canProceed() ? null : (isDark ? Colors.white12 : AppColors.border),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _canProceed()
                        ? [BoxShadow(color: _medicationPrimary.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 5))]
                        : null,
                  ),
                  child: Center(
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            isLastStep ? 'Save Medicine' : 'Continue',
                            style: TextStyle(
                              color: _canProceed() ? Colors.white : (isDark ? Colors.white38 : AppColors.textLight),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
