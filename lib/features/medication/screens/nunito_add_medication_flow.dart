import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:uuid/uuid.dart';
import '../widgets/nunito_pill_visual.dart';
import '../models/enhanced_medicine.dart';
import '../models/medicine_enums.dart';
import '../models/medicine_schedule.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../services/medicine_storage_service.dart';
import '../services/medication_reminder_service.dart';
import '../services/drug_name_catalog.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/ai/ai_assistant.dart';
import '../../../core/widgets/app/app_widgets.dart';

/// How the end of a medication course is expressed in the wizard.
enum _DurationMode { ongoing, endDate, duration }

class NunitoAddMedicationFlow extends StatefulWidget {
  final EnhancedMedicine? editMedicine;

  /// QA/debug only: start the wizard on a given step (0-based). Lets the visual
  /// harness screenshot a specific step (e.g. Schedule) without tapping through.
  final int? debugInitialStep;

  const NunitoAddMedicationFlow(
      {super.key, this.editMedicine, this.debugInitialStep});

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
  // Generic (active-ingredient) name — powers the disclaimed interaction/allergy
  // reference checks, which key off the generic, not the brand.
  final _genericNameController = TextEditingController();
  DosageForm _selectedForm = DosageForm.tablet;

  // Optional expiry date → drives the "expiring soon / expired" surfacing.
  DateTime? _expiryDate;

  // Offline drug-name typeahead suggestions for the name field.
  List<DrugNameEntry> _nameSuggestions = const [];
  bool _suppressNameSuggest = false;

  // Step 1: Smart add (AI) — describe a medicine in plain language and let the
  // assistant pre-fill the wizard fields. Purely optional; the manual flow is
  // untouched when there's no AI key.
  final _aiDescController = TextEditingController();
  bool _aiFilling = false;

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
  late final PageController _pageController;

  bool get _isEditing => widget.editMedicine != null;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.debugInitialStep ?? 0;
    _pageController = PageController(initialPage: _currentStep);
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
    // Offline drug-name typeahead (privacy-first, bundled asset).
    DrugNameCatalog.ensureLoaded();
    _nameController.addListener(_onNameChanged);
    _updateProgress();
  }

  void _onNameChanged() {
    if (_suppressNameSuggest) return;
    final next = DrugNameCatalog.suggest(_nameController.text);
    if (next.length != _nameSuggestions.length ||
        (next.isNotEmpty &&
            _nameSuggestions.isNotEmpty &&
            next.first.name != _nameSuggestions.first.name)) {
      setState(() => _nameSuggestions = next);
    } else if (next.isEmpty && _nameSuggestions.isNotEmpty) {
      setState(() => _nameSuggestions = const []);
    }
  }

  void _loadExistingMedicine() {
    final m = widget.editMedicine!;
    _nameController.text = m.name;
    _genericNameController.text = m.genericName ?? '';
    _expiryDate = m.expiryDate;
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
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _genericNameController.dispose();
    _dosageController.dispose();
    _strengthController.dispose();
    _stockController.dispose();
    _instructionsController.dispose();
    _purposeController.dispose();
    _aiDescController.dispose();
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

    final EnhancedMedicine medicine;
    // STEP 1 — persistence (the only thing that can legitimately fail a "save").
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

      medicine = EnhancedMedicine(
        id: _isEditing ? widget.editMedicine!.id : const Uuid().v4(),
        name: _nameController.text.trim(),
        dosageForm: _selectedForm,
        dosageAmount: double.tryParse(_dosageController.text.trim()) ?? 1.0,
        dosageUnit: _dosageUnit,
        strength: _strengthController.text.isNotEmpty ? _strengthController.text : null,
        genericName: _genericNameController.text.trim().isNotEmpty
            ? _genericNameController.text.trim()
            : null,
        expiryDate: _expiryDate,
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
    } catch (e, st) {
      // Surface the REAL cause: the old generic toast masked every failure
      // behind "Failed to save medication", making the root cause invisible.
      debugPrint('Error saving medicine: $e\n$st');
      _showError(kDebugMode
          ? 'Failed to save medication: $e'
          : "Couldn't save this medication. Please check the details and try again.");
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // STEP 2 — post-save side-effects. The medicine is ALREADY persisted, so a
    // failure here must NOT report "failed to save" (the old bug: a reminder /
    // haptic error surfaced as a save failure even though the row was written,
    // leaving the user thinking creation failed when it actually succeeded).
    try {
      if (_reminderEnabled) {
        await _reminderService.scheduleReminders(medicine);
      } else {
        await _reminderService.cancelReminders(medicine);
      }
    } catch (e) {
      debugPrint('⚠️ Post-save reminder scheduling failed (medicine saved): $e');
    }
    try {
      _hapticService.success();
    } catch (_) {}

    if (mounted) Navigator.pop(context, true);
    // Guard: the success path pops this screen, so it may be unmounted here.
    if (mounted) setState(() => _isLoading = false);
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
        icon: Symbols.close_rounded,
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
          _buildSmartAddSection(context),
          const SizedBox(height: AppSpacing.xl),
          AppTextField(
            controller: _nameController,
            label: 'Medication Name',
            hint: 'e.g., Aspirin, Vitamin D',
            accent: med,
            textCapitalization: TextCapitalization.words,
          ),
          if (_nameSuggestions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in _nameSuggestions)
                  AppChip(
                    label: s.name,
                    accent: med,
                    onTap: () {
                      _hapticService.selection();
                      _suppressNameSuggest = true;
                      _nameController.text = s.name;
                      _nameController.selection = TextSelection.collapsed(
                          offset: s.name.length);
                      if (_genericNameController.text.trim().isEmpty) {
                        _genericNameController.text = s.generic;
                      }
                      _suppressNameSuggest = false;
                      setState(() => _nameSuggestions = const []);
                    },
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _genericNameController,
            label: 'Generic name (optional)',
            hint: 'Active ingredient, e.g., Acetaminophen',
            accent: med,
            textCapitalization: TextCapitalization.words,
            helperText:
                'Helps flag general interactions — always confirm with your pharmacist.',
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

  /// Smart add: a plain-language description + "Fill with AI" button. Extracts
  /// medicine details via the AI assistant and pre-fills the wizard state so the
  /// user can review and continue. Always available (free on-device engine).
  Widget _buildSmartAddSection(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final med = ext.medicine;
    final tt = Theme.of(context).textTheme;

    return AppCard(
      color: med.container,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Symbols.auto_awesome_rounded,
                  color: med.onContainer, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Describe it (AI)',
                  style: tt.titleMedium?.copyWith(color: med.onContainer),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'e.g. "Amoxicillin 500mg capsule, one three times a day"',
            style: tt.bodySmall?.copyWith(color: med.onContainer.withOpacity(0.8)),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _aiDescController,
            hint: 'Describe your medication…',
            accent: med,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _fillWithAi(),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Fill with AI',
                  leadingIcon: Symbols.auto_awesome_rounded,
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.sm,
                  accent: med,
                  loading: _aiFilling,
                  onPressed: _aiFilling ? null : _fillWithAi,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppButton(
                label: 'Scan',
                leadingIcon: Symbols.document_scanner_rounded,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.sm,
                accent: med,
                onPressed: _aiFilling ? null : _scanLabel,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Scan a printed Rx label with the camera and pipe the recognised text
  /// through the same offline parser as "Fill with AI". On-device OCR (Google
  /// ML Kit) — no image or text leaves the phone. Degrades gracefully to the
  /// manual flow if the camera / recognizer is unavailable.
  Future<void> _scanLabel() async {
    try {
      final shot = await ImagePicker()
          .pickImage(source: ImageSource.camera, imageQuality: 85);
      if (shot == null) return;
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      setState(() => _aiFilling = true);

      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      String text = '';
      try {
        final result =
            await recognizer.processImage(InputImage.fromFilePath(shot.path));
        text = result.text.trim();
      } finally {
        await recognizer.close();
      }

      if (text.isEmpty) {
        if (mounted) {
          setState(() => _aiFilling = false);
          _showError("Couldn't read the label. Try better lighting or type it in.");
        }
        return;
      }

      // Show what was read, then parse it with the offline engine.
      _aiDescController.text = text;
      final parsed = await AiAssistant().parseMedicine(text);
      if (!mounted) return;
      setState(() => _aiFilling = false);
      if (parsed != null) {
        setState(() => _applyAiExtraction(parsed));
        _hapticService.success();
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(parsed != null
            ? 'Scanned — please review each step'
            : 'Scanned text added — review and adjust'),
      ));
    } catch (e) {
      if (mounted) {
        setState(() => _aiFilling = false);
        _showError('Scan unavailable. You can type the details instead.');
      }
    }
  }

  Future<void> _fillWithAi() async {
    final desc = _aiDescController.text.trim();
    if (desc.isEmpty) {
      _showError('Describe the medication first');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _aiFilling = true);

    final result = await AiAssistant().parseMedicine(desc);

    if (!mounted) return;
    setState(() => _aiFilling = false);

    if (result == null) {
      _showError('Couldn\'t read that. Try rephrasing or fill it in manually.');
      return;
    }

    setState(() => _applyAiExtraction(result));
    _hapticService.success();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Filled from AI — please review each step')),
      );
    }
  }

  /// Map a loosely-typed AI JSON payload onto the wizard's existing state.
  /// Every field is defensive: anything missing/unrecognized is left as-is so
  /// the manual defaults survive.
  void _applyAiExtraction(Map<String, dynamic> data) {
    final name = data['name'];
    if (name is String && name.trim().isNotEmpty) {
      _nameController.text = name.trim();
    }

    final form = _parseForm(data['form']);
    if (form != null) {
      _selectedForm = form;
      _dosageUnit = form.unit;
    }

    // The parser returns a concentration like "500 mg" as dosageAmount+dosageUnit.
    // For a COUNT form (tablet/capsule/lozenge, taken as "1 pill"), that value is
    // the STRENGTH, not the dose count — route it to the strength field and keep
    // the dose count at its default. For liquid/injection/drops, ml/units really
    // are the dose amount, so keep the existing behavior.
    final rawAmt = data['dosageAmount'];
    final num? amt = rawAmt is num
        ? rawAmt
        : (rawAmt is String ? double.tryParse(rawAmt.trim()) : null);
    final unitRaw = data['dosageUnit'];
    final unitStr =
        unitRaw is String && unitRaw.trim().isNotEmpty ? unitRaw.trim() : null;
    String fmt(num n) => n == n.roundToDouble() ? '${n.toInt()}' : '$n';
    const strengthUnits = {'mg', 'mcg', 'g', 'iu', 'unit', 'units'};
    final isCountForm = _selectedForm == DosageForm.tablet ||
        _selectedForm == DosageForm.capsule ||
        _selectedForm == DosageForm.lozenge;

    if (amt != null &&
        isCountForm &&
        unitStr != null &&
        strengthUnits.contains(unitStr.toLowerCase())) {
      _strengthController.text = '${fmt(amt)}$unitStr'; // e.g. "500mg"
      // leave _dosageController ('1') and _dosageUnit (form.unit) as-is
    } else {
      if (amt != null) _dosageController.text = fmt(amt);
      if (unitStr != null) _dosageUnit = unitStr;
    }

    // A bare, unit-less strength the parser pulled from the name ("Dolo 650" →
    // "650"). Fill the strength field only if nothing already populated it.
    final strengthRaw = data['strength'];
    if (strengthRaw != null &&
        '$strengthRaw'.trim().isNotEmpty &&
        _strengthController.text.trim().isEmpty) {
      _strengthController.text = '$strengthRaw'.trim();
    }

    // Meal timing FIRST — it anchors the auto-generated times below, so
    // "twice daily after meals" lands on breakfast + dinner rather than a flat
    // 8am/8pm. Also powers the habit-anchor reminder text.
    final meal = _parseMealTiming(data);
    if (meal != null) _mealTiming = meal;

    final freq = _parseFrequency(data['frequency']);
    if (freq != null) {
      _frequencyType = freq;
      // Carry the interval for every-X-hours schedules (was silently dropped).
      if (freq == FrequencyType.everyXHours) {
        final iv = data['intervalHours'];
        final ivNum = iv is num ? iv.toInt() : int.tryParse('${iv ?? ''}');
        if (ivNum != null && ivNum > 0) _intervalHours = ivNum;
      }
      // Auto-spaces the reminder times (meal-aligned) — so AI fills the
      // medicine AND its times, not just the frequency.
      _updateTimesForFrequency();
    }

    // If the user literally typed clock times ("8am and 8pm"), honor those.
    final times = _parseTimes(data['times']);
    if (times.isNotEmpty && !_isPRN) {
      _scheduleTimes = times;
    }
  }

  /// Map the parser's meal-timing / with-food output to a [MealTiming].
  MealTiming? _parseMealTiming(Map<String, dynamic> data) {
    final raw = (data['mealTiming'] ?? data['withFood'])?.toString().toLowerCase();
    if (raw == null || raw.isEmpty) return null;
    if (raw == 'true' || raw.contains('with')) return MealTiming.withMeal;
    if (raw.contains('before') && raw.contains('bed')) return MealTiming.beforeBed;
    if (raw.contains('before')) return MealTiming.beforeMeal;
    if (raw.contains('after')) return MealTiming.afterMeal;
    if (raw.contains('empty')) return MealTiming.emptyStomach;
    if (raw.contains('wake') || raw.contains('morning')) return MealTiming.wakeUp;
    return null;
  }

  DosageForm? _parseForm(dynamic raw) {
    if (raw is! String) return null;
    final v = raw.trim().toLowerCase();
    if (v.isEmpty) return null;
    switch (v) {
      case 'tablet':
      case 'pill':
        return DosageForm.tablet;
      case 'capsule':
        return DosageForm.capsule;
      case 'liquid':
      case 'syrup':
      case 'suspension':
      case 'solution':
        return DosageForm.syrup;
      case 'injection':
      case 'shot':
        return DosageForm.injection;
    }
    // Fall back to an exact enum-name match, else leave unchanged.
    for (final f in DosageForm.values) {
      if (f.name == v) return f;
    }
    return null;
  }

  FrequencyType? _parseFrequency(dynamic raw) {
    if (raw is! String) return null;
    final v = raw.trim().toLowerCase();
    if (v.isEmpty) return null;
    if (v.contains('asneeded') || v.contains('as needed') || v.contains('prn')) {
      return FrequencyType.asNeeded;
    }
    if (v.contains('once') || v == '1' || v.startsWith('one')) {
      return FrequencyType.onceDaily;
    }
    if (v.contains('twice') || v == '2' || v.startsWith('two')) {
      return FrequencyType.twiceDaily;
    }
    if (v.contains('thrice') || v.contains('three') || v == '3') {
      return FrequencyType.thriceDaily;
    }
    if (v.contains('four') || v == '4') {
      return FrequencyType.fourTimesDaily;
    }
    if (v.contains('everyxhours') ||
        v.contains('every x hours') ||
        RegExp(r'every\s*\d+\s*hour').hasMatch(v) ||
        v.contains('hour')) {
      return FrequencyType.everyXHours;
    }
    return null;
  }

  List<TimeOfDay> _parseTimes(dynamic raw) {
    if (raw is! List) return const [];
    final out = <TimeOfDay>[];
    for (final item in raw) {
      if (item is! String) continue;
      final parts = item.trim().split(':');
      if (parts.length < 2) continue;
      final h = int.tryParse(parts[0].trim());
      final m = int.tryParse(parts[1].trim());
      if (h == null || m == null) continue;
      if (h < 0 || h > 23 || m < 0 || m > 59) continue;
      out.add(TimeOfDay(hour: h, minute: m));
    }
    return out;
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
                      ? Symbols.inventory_2_rounded
                      : Symbols.inventory_2_rounded,
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
                AppSwitch(
                  value: _refillReminderEnabled,
                  onChanged: (v) {
                    _hapticService.toggle();
                    setState(() => _refillReminderEnabled = v);
                  },
                  accent: med,
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

  // The four everyday regimens people pick 90% of the time — shown up front as a
  // compact "times per day" row instead of a 9-item radio list.
  static const List<FrequencyType> _dailyCounts = [
    FrequencyType.onceDaily,
    FrequencyType.twiceDaily,
    FrequencyType.thriceDaily,
    FrequencyType.fourTimesDaily,
  ];

  // The rarer patterns, tucked behind "More schedule options" (progressive
  // disclosure — Apple Health / Medisafe pattern).
  static const List<FrequencyType> _advancedFreqs = [
    FrequencyType.everyXHours,
    FrequencyType.everyXDays,
    FrequencyType.specificDays,
    FrequencyType.cyclical,
    FrequencyType.asNeeded,
  ];

  Widget _buildFrequencySelector(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final med = ext.medicine;
    final tt = Theme.of(context).textTheme;
    final isAdvanced = _advancedFreqs.contains(_frequencyType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How often?',
            style: tt.labelLarge?.copyWith(color: ext.textSecondary)),
        const SizedBox(height: AppSpacing.sm),
        // Primary path: pick a count in one glance (Once → 4× a day).
        Row(
          children: [
            for (var i = 0; i < _dailyCounts.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _buildCountOption(
                  context,
                  i + 1,
                  _dailyCounts[i],
                  selected: !isAdvanced && _frequencyType == _dailyCounts[i],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (isAdvanced)
          _buildAdvancedSummary(context)
        else
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: 'More schedule options',
              leadingIcon: Symbols.tune_rounded,
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.sm,
              accent: med,
              onPressed: _showMoreScheduleOptions,
            ),
          ),
      ],
    );
  }

  /// One big, two-line "N× a day" tile in the count row.
  Widget _buildCountOption(BuildContext context, int count, FrequencyType freq,
      {required bool selected}) {
    final ext = AppColorsExt.of(context);
    final med = ext.medicine;
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: () {
        _hapticService.selection();
        setState(() {
          _frequencyType = freq;
          _updateTimesForFrequency();
        });
      },
      child: Container(
        height: 68,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? med.container : ext.surface,
          borderRadius: AppRadius.brMd,
          border: Border.all(
            color: selected ? med.base : ext.outline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$count×',
                style: tt.titleLarge?.copyWith(
                  color: selected ? med.onContainer : ext.textPrimary,
                  fontWeight: FontWeight.w700,
                )),
            Text('a day',
                style: tt.bodySmall?.copyWith(
                  color: selected ? med.onContainer : ext.textTertiary,
                )),
          ],
        ),
      ),
    );
  }

  /// When an advanced pattern is active, show it as a summary card with a
  /// "Change" affordance (instead of the count row) so it's clearly selected.
  Widget _buildAdvancedSummary(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final med = ext.medicine;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: med.container,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: med.base),
      ),
      child: Row(
        children: [
          Icon(_freqIcon(_frequencyType), color: med.onContainer, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_frequencyType.displayName,
                    style: tt.titleMedium?.copyWith(color: med.onContainer)),
                Text(_freqDescription(_frequencyType),
                    style: tt.bodySmall?.copyWith(
                        color: med.onContainer.withOpacity(0.75))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AppButton(
            label: 'Change',
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.sm,
            accent: med,
            onPressed: _showMoreScheduleOptions,
          ),
        ],
      ),
    );
  }

  void _showMoreScheduleOptions() {
    final med = AppColorsExt.of(context).medicine;
    AppBottomSheet.show(
      context,
      title: 'More schedule options',
      icon: Symbols.tune_rounded,
      accent: med,
      builder: (ctx) {
        final ext = AppColorsExt.of(ctx);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final f in _advancedFreqs)
              AppListTile(
                icon: _freqIcon(f),
                title: f.displayName,
                subtitle: _freqDescription(f),
                accent: med,
                trailing: _frequencyType == f
                    ? Icon(Symbols.check_circle_rounded, color: ext.mark(med))
                    : null,
                onTap: () {
                  _hapticService.selection();
                  setState(() {
                    _frequencyType = f;
                    _updateTimesForFrequency();
                  });
                  Navigator.pop(ctx);
                },
              ),
          ],
        );
      },
    );
  }

  IconData _freqIcon(FrequencyType f) {
    switch (f) {
      case FrequencyType.everyXHours:
        return Symbols.timer_rounded;
      case FrequencyType.everyXDays:
        return Symbols.calendar_month_rounded;
      case FrequencyType.specificDays:
        return Symbols.event_repeat_rounded;
      case FrequencyType.cyclical:
        return Symbols.autorenew_rounded;
      case FrequencyType.asNeeded:
        return Symbols.touch_app_rounded;
      default:
        return Symbols.schedule_rounded;
    }
  }

  String _freqDescription(FrequencyType f) {
    switch (f) {
      case FrequencyType.everyXHours:
        return 'Fixed interval, e.g. every 8 hours';
      case FrequencyType.everyXDays:
        return 'Skip days, e.g. every 2 days';
      case FrequencyType.specificDays:
        return 'Only on chosen weekdays';
      case FrequencyType.cyclical:
        return 'On for a while, then off (e.g. 21 on / 7 off)';
      case FrequencyType.asNeeded:
        return 'Take only when you need it (PRN)';
      default:
        return '';
    }
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
          stepButton(Symbols.remove_rounded, value > min,
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
          stepButton(Symbols.add_rounded, value < max,
              () => onChanged((value + 1).clamp(min, max))),
        ],
      ),
    );
  }

  Widget _buildTimesSection(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final med = ext.medicine;
    final tt = Theme.of(context).textTheme;
    final isInterval = _frequencyType == FrequencyType.everyXHours;
    final timesLabel = isInterval ? 'First dose' : 'Reminder times';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(timesLabel,
            style: tt.labelLarge?.copyWith(color: ext.textSecondary)),
        if (isInterval)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Text(
              'Doses repeat every $_intervalHours '
              '${_intervalHours == 1 ? 'hour' : 'hours'} after this time.',
              style: tt.bodySmall?.copyWith(color: ext.textTertiary),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        // Full-width, tappable rows — clearer than small chips, and each carries
        // a proper 44px remove target (older-adult accessibility).
        ..._scheduleTimes.asMap().entries.map((entry) {
          final index = entry.key;
          final time = entry.value;
          final canRemove = _scheduleTimes.length > 1 && !isInterval;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildTimeRow(context, index, time, canRemove),
          );
        }),
        if (!isInterval) ...[
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'Add another time',
              leadingIcon: Symbols.add_rounded,
              variant: AppButtonVariant.secondary,
              accent: med,
              onPressed: _addTime,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTimeRow(
      BuildContext context, int index, TimeOfDay time, bool canRemove) {
    final ext = AppColorsExt.of(context);
    final med = ext.medicine;
    final tt = Theme.of(context).textTheme;
    final label =
        _scheduleTimes.length > 1 ? 'Dose ${index + 1}' : 'Reminder';
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _editTime(index),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: med.container,
                borderRadius: AppRadius.brMd,
                border: Border.all(color: med.base),
              ),
              child: Row(
                children: [
                  Icon(Symbols.access_time_rounded,
                      size: 20, color: med.onContainer),
                  const SizedBox(width: 12),
                  Text(label,
                      style: tt.bodyMedium?.copyWith(color: med.onContainer)),
                  const Spacer(),
                  Text(
                    time.format(context),
                    style: tt.titleMedium?.copyWith(
                        color: med.onContainer, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 6),
                  Icon(Symbols.edit_rounded, size: 16, color: med.onContainer),
                ],
              ),
            ),
          ),
        ),
        if (canRemove) ...[
          const SizedBox(width: 8),
          AppIconButton(
            icon: Symbols.close_rounded,
            accent: med,
            size: 44,
            filled: false,
            tooltip: 'Remove time',
            onPressed: () => _removeTime(index),
          ),
        ],
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
                Icon(Symbols.event_rounded, size: 20, color: ext.mark(med)),
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
                  Icon(Symbols.event_available_rounded,
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
    final picked = await AppDatePicker.show(
      context,
      initial: _startDate,
      first: DateTime.now().subtract(const Duration(days: 365)),
      last: DateTime.now().add(const Duration(days: 365 * 5)),
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
    final picked = await AppDatePicker.show(
      context,
      initial: _endDate != null && _endDate!.isAfter(_startDate)
          ? _endDate!
          : _startDate.add(const Duration(days: 7)),
      first: _startDate,
      last: _startDate.add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  void _updateTimesForFrequency() {
    switch (_frequencyType) {
      case FrequencyType.onceDaily:
      case FrequencyType.twiceDaily:
      case FrequencyType.thriceDaily:
      case FrequencyType.fourTimesDaily:
        _scheduleTimes = _defaultTimesFor(_frequencyType, _mealTiming);
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

  /// Evenly-spaced default reminder times for a daily [freq] count, anchored to
  /// meals / waking / bedtime when the [meal] timing implies them (so AI-filled
  /// or count-picked schedules land near when the dose is actually taken).
  /// `anytime` keeps the original flat spacing — no behavior change there.
  List<TimeOfDay> _defaultTimesFor(FrequencyType freq, MealTiming meal) {
    TimeOfDay t(int h) => TimeOfDay(hour: h, minute: 0);
    final count = switch (freq) {
      FrequencyType.onceDaily => 1,
      FrequencyType.twiceDaily => 2,
      FrequencyType.thriceDaily => 3,
      FrequencyType.fourTimesDaily => 4,
      _ => 1,
    };
    late final List<int> hours;
    switch (meal) {
      case MealTiming.beforeMeal:
      case MealTiming.withMeal:
      case MealTiming.afterMeal:
        // Around meals: breakfast / lunch / dinner (+ a late dose for 4×).
        hours = const [
          [8],
          [8, 20],
          [8, 13, 20],
          [8, 13, 18, 22],
        ][count - 1];
        break;
      case MealTiming.beforeBed:
        hours = const [
          [22],
          [8, 22],
          [8, 14, 22],
          [8, 13, 18, 22],
        ][count - 1];
        break;
      case MealTiming.wakeUp:
      case MealTiming.emptyStomach:
        // Early / empty-stomach: start at waking.
        hours = const [
          [7],
          [7, 19],
          [7, 13, 19],
          [7, 12, 17, 22],
        ][count - 1];
        break;
      case MealTiming.anytime:
        // Original even spacing — unchanged for the common case.
        hours = const [
          [8],
          [8, 20],
          [8, 14, 20],
          [8, 12, 16, 20],
        ][count - 1];
        break;
    }
    return hours.map(t).toList();
  }

  Future<void> _addTime() async {
    final time = await AppTimePicker.show(context, initial: TimeOfDay.now());
    if (time != null) {
      setState(() => _scheduleTimes.add(time));
    }
  }

  Future<void> _editTime(int index) async {
    final time = await AppTimePicker.show(
      context,
      initial: _scheduleTimes[index],
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
                      ? Icon(Symbols.check_rounded,
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
          const SizedBox(height: AppSpacing.md),
          AppCard(
            onTap: () async {
              _hapticService.selection();
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate:
                    _expiryDate ?? now.add(const Duration(days: 180)),
                firstDate: now.subtract(const Duration(days: 365)),
                lastDate: now.add(const Duration(days: 3650)),
              );
              if (picked != null) setState(() => _expiryDate = picked);
            },
            child: Row(
              children: [
                Icon(Symbols.event_busy_rounded,
                    color: _expiryDate != null ? ext.mark(med) : ext.textTertiary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Expiry date (optional)', style: tt.titleLarge),
                      Text(
                        _expiryDate != null
                            ? '${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}'
                            : 'Not set',
                        style: tt.bodySmall?.copyWith(color: ext.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (_expiryDate != null)
                  AppIconButton(
                    icon: Symbols.close_rounded,
                    filled: false,
                    tooltip: 'Clear',
                    onPressed: () => setState(() => _expiryDate = null),
                  )
                else
                  Icon(Symbols.chevron_right_rounded, color: ext.textTertiary),
              ],
            ),
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
                      ? Symbols.notifications_active_rounded
                      : Symbols.notifications_off_rounded,
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
                AppSwitch(
                  value: _reminderEnabled,
                  onChanged: (v) {
                    _hapticService.toggle();
                    setState(() => _reminderEnabled = v);
                  },
                  accent: med,
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
