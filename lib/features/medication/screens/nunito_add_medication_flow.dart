import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:uuid/uuid.dart';
import '../widgets/nunito_pill_visual.dart';
import '../models/enhanced_medicine.dart';
import '../models/medicine_enums.dart';
import '../models/medicine_schedule.dart';
import 'package:image_picker/image_picker.dart';
import '../services/medicine_storage_service.dart';
import '../services/medication_reminder_service.dart';
import '../services/drug_name_catalog.dart';
import '../services/drug_interaction_service.dart';
import '../models/drug_interaction.dart';
import '../../../core/services/active_profile_service.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/health/coach_text.dart';
import '../../../core/health/med_safety_checker.dart';
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
  // Only meaningful (and only shown) for forms DosageForm alone leaves
  // ambiguous — injection (IM/SC/IV) and drops (eye/ear/nose). Every other
  // form already unambiguously implies its route, so asking would be
  // redundant clutter for the common case.
  AdministrationRoute? _selectedRoute;

  // Optional expiry date → drives the "expiring soon / expired" surfacing.
  DateTime? _expiryDate;

  // Offline drug-name typeahead suggestions for the name field.
  List<DrugNameEntry> _nameSuggestions = const [];
  bool _suppressNameSuggest = false;

  // Step 1: Smart add (AI) — describe a medicine in plain language and let the
  // assistant pre-fill the wizard fields. Purely optional; the manual flow is
  // untouched when there's no AI key.
  final _descController = TextEditingController();
  bool _filling = false;

  // Step 2: Dosage
  final _dosageController = TextEditingController(text: '1');
  final _strengthController = TextEditingController();
  String _dosageUnit = 'pill(s)';

  /// Upper bound for one dose. The field counts units of the dosage FORM
  /// (pills, ml, drops...), never mg, so anything past this is a slipped
  /// keypad rather than a prescription.
  static const int _maxDoseAmount = 1000;

  /// The dose amount, or null when the field doesn't hold a usable quantity
  /// (unparseable, non-finite, zero/negative, or above [_maxDoseAmount]).
  /// Step-1 validation and the save both read this, so a quantity that fails
  /// validation can't reach [EnhancedMedicine.dosageAmount] by another route
  /// (the AI pre-fill writes straight into the controller).
  double? get _doseAmount {
    final v = double.tryParse(_dosageController.text.trim());
    if (v == null || !v.isFinite || v <= 0 || v > _maxDoseAmount) return null;
    return v;
  }

  // Step 2: Stock & refill (optional — blank quantity means untracked)
  final _stockController = TextEditingController();
  int _lowStockThreshold = 7;
  bool _refillReminderEnabled = false;

  // Step 2: Titration (dose escalation) — opt-in list of "Day N+: X <unit>"
  // steps that override the base dosage above from a given day onward. Off
  // by default; existing medicines are completely unaffected — see
  // MedicineSchedule.effectiveDosageAmount's null/empty-list early return.
  // Each row's day-offset/dose live in parallel controller lists (mirrors
  // _scheduleTimes' index-based approach) rather than a list of TitrationStep
  // directly, since the fields are edited as free text until save time.
  bool _titrationEnabled = false;
  final List<TextEditingController> _titrationDayControllers = [];
  final List<TextEditingController> _titrationDoseControllers = [];

  // Step 3: Schedule
  FrequencyType _frequencyType = FrequencyType.onceDaily;
  List<TimeOfDay> _scheduleTimes = [const TimeOfDay(hour: 8, minute: 0)];
  // Weekend mode: shift every weekday dose time by the same offset on Sat/Sun
  // (e.g. "sleep in" 2 hours later) rather than a fully independent time
  // list — simpler to set up and matches how people actually think about it.
  bool _weekendOverrideEnabled = false;
  TimeOfDay? _weekendAnchorTime;
  // Opt-in reminder window (Phase 4), keyed by minute-of-day (hour*60+minute)
  // rather than list index — _scheduleTimes gets re-sorted whenever a time is
  // added, and a value-keyed map can never desync from that the way a
  // parallel same-index list could. Absent from this map = exact time, the
  // untouched default.
  final Map<int, int> _windowMinutesByTime = {};
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
  final DrugInteractionService _interactionService = DrugInteractionService();
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
    // Full element-wise comparison. The old length+first-item shortcut left
    // stale suggestions on screen when the list changed but kept the same
    // length and first entry (e.g. "Cro" -> "Cra").
    final same = next.length == _nameSuggestions.length &&
        List.generate(next.length, (i) => next[i].name == _nameSuggestions[i].name)
            .every((e) => e);
    if (!same) setState(() => _nameSuggestions = next);
  }

  void _loadExistingMedicine() {
    final m = widget.editMedicine!;
    _nameController.text = m.name;
    _genericNameController.text = m.genericName ?? '';
    _expiryDate = m.expiryDate;
    _selectedForm = m.dosageForm;
    _selectedRoute = m.route;
    _dosageController.text = m.dosageAmount % 1 == 0
        ? m.dosageAmount.toInt().toString()
        : m.dosageAmount.toString();
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
    _windowMinutesByTime.clear();
    for (final t in sched.times) {
      if (t.hasWindow) _windowMinutesByTime[t.hour * 60 + t.minute] = t.windowMinutes!;
    }
    _weekendOverrideEnabled = sched.hasWeekendOverride;
    _weekendAnchorTime = sched.hasWeekendOverride
        ? TimeOfDay(
            hour: sched.weekendTimes!.first.hour,
            minute: sched.weekendTimes!.first.minute)
        : null;
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
    _titrationEnabled = sched.isTitrating;
    if (_titrationEnabled) {
      for (final step in sched.titrationSteps!) {
        _titrationDayControllers
            .add(TextEditingController(text: step.startDayOffset.toString()));
        _titrationDoseControllers.add(TextEditingController(
            text: step.dosageAmount % 1 == 0
                ? step.dosageAmount.toInt().toString()
                : step.dosageAmount.toString()));
      }
    }
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
    _descController.dispose();
    for (final c in _titrationDayControllers) {
      c.dispose();
    }
    for (final c in _titrationDoseControllers) {
      c.dispose();
    }
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

  /// The "Save Changes" / "Add Medication" primary button, available from the
  /// Schedule step onward.
  ///
  /// It used to call [_saveMedicine] directly, which skipped
  /// [_validateCurrentStep] entirely — a medicine could be saved with no
  /// schedule times, no selected days, an "end date" duration with no end date,
  /// or an invalid titration dose, none of which the Continue path allows.
  /// Finishing early may skip the OPTIONAL steps (Look / More), never the
  /// guarded ones, so re-run every guarded step up to where the user is; if an
  /// earlier one fails, jump back to it so the error names a field on screen.
  void _finishAndSave() {
    const lastGuardedStep = 2; // Schedule — steps after it are optional.
    final upTo = _currentStep < lastGuardedStep ? _currentStep : lastGuardedStep;
    for (var step = 0; step <= upTo; step++) {
      if (_validateStep(step)) continue;
      if (step != _currentStep) _goToStep(step);
      return;
    }
    _hapticService.light();
    _saveMedicine();
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: AppMotion.base,
      curve: Curves.easeOutCubic,
    );
    _updateProgress();
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

  bool _validateCurrentStep() => _validateStep(_currentStep);

  /// Guards for a single wizard step. Split out of [_validateCurrentStep] so
  /// the "finish early" path ([_finishAndSave]) can re-run the guards of every
  /// step it is about to skip past, instead of saving unvalidated input.
  /// Shows the relevant error itself and returns false when the step is not
  /// yet valid.
  bool _validateStep(int step) {
    switch (step) {
      case 0:
        if (_nameController.text.trim().isEmpty) {
          _showError('Please enter a medication name');
          return false;
        }
        return true;
      case 1:
        // `double.tryParse != null` alone accepted '0' and '-5', and the value
        // went straight through to dosageAmount — a saved dose of zero silently
        // disables adherence maths, a negative one is nonsense the rest of the
        // app never guards against. Require a real, bounded quantity.
        final dose = double.tryParse(_dosageController.text.trim());
        if (dose == null || !dose.isFinite) {
          _showError('Please enter a valid dosage');
          return false;
        }
        if (dose <= 0) {
          _showError('Dose must be greater than 0');
          return false;
        }
        if (dose > _maxDoseAmount) {
          _showError('Dose must be $_maxDoseAmount or less');
          return false;
        }
        // Stock is optional, but if entered it must be a non-negative whole
        // number — otherwise it was silently dropped (saved as untracked).
        final stockText = _stockController.text.trim();
        if (stockText.isNotEmpty) {
          final stock = int.tryParse(stockText);
          if (stock == null || stock < 0) {
            _showError('Enter a whole number for quantity, or leave it blank');
            return false;
          }
        }
        // Titration rows carry a real dose that REPLACES the one above from a
        // given day onward (MedicineSchedule.effectiveDosageAmount), so each
        // row needs exactly the same guard as the dose field itself. Parsing
        // with `double.tryParse` alone let '0' and '-5' through, and an
        // unparseable row was silently dropped at build time rather than
        // reported — either way the user ended up with a dose they never
        // intended.
        if (_titrationEnabled) {
          if (_titrationDayControllers.isEmpty) {
            _showError('Add a dose step, or turn off "Dose changes over time"');
            return false;
          }
          for (var i = 0; i < _titrationDayControllers.length; i++) {
            final day = _titrationDayAt(i);
            if (day == null) {
              _showError(
                  'Step ${i + 1}: enter the day this dose starts (0 or more)');
              return false;
            }
            final text = _titrationDoseControllers[i].text.trim();
            final stepDose = double.tryParse(text);
            if (stepDose == null || !stepDose.isFinite) {
              _showError('Step ${i + 1}: enter a valid dose');
              return false;
            }
            if (stepDose <= 0) {
              _showError('Step ${i + 1}: dose must be greater than 0');
              return false;
            }
            if (stepDose > _maxDoseAmount) {
              _showError('Step ${i + 1}: dose must be $_maxDoseAmount or less');
              return false;
            }
          }
        }
        return true;
      case 2:
        // "End date" mode must have an end date chosen (applies to PRN too).
        if (_durationMode == _DurationMode.endDate && _endDate == null) {
          _showError('Please pick an end date');
          return false;
        }
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
    context.toastError(message);
  }

  /// Who this medicine will actually belong to once saved. For an edit that's
  /// simply the existing record's owner (this form has no dependent picker of
  /// its own); for a brand-new medicine it's whichever profile is currently
  /// active, since that's what MedicineCleanStorageService.saveMedicine's own
  /// stamping applies — checked here BEFORE saving specifically so the
  /// allergy check below (which needs to know who's actually taking it) sees
  /// the right owner even though the stamp itself hasn't happened yet.
  String? get _effectiveDependentId =>
      _isEditing ? widget.editMedicine!.dependentId : ActiveProfileService().activeDependentId;

  /// Warns (with a chance to cancel) if this medicine plausibly conflicts
  /// with an allergy on file for whoever it belongs to. Returns true to
  /// proceed with the save, false to abort. A self-owned medicine is never
  /// checked — [DependentProfile.allergies] is dependent-only data, matching
  /// the same scope MedSafetyChecker already uses on the detail screen.
  Future<bool> _confirmAllergySafety(EnhancedMedicine medicine) async {
    // NOT medicine.dependentId — a brand-new medicine's dependentId is still
    // null at this point (MedicineCleanStorageService.saveMedicine stamps the
    // active profile onto it AFTER this check runs), so that would only ever
    // fire for edits of an already dependent-owned medicine, missing the far
    // more common "adding a new medicine while a dependent is active" case.
    final dependentId = _effectiveDependentId;
    if (dependentId == null) return true;
    List<String> allergies;
    try {
      final deps = await MedicineCleanStorageService.getAllDependents();
      allergies = deps.where((d) => d.id == dependentId).firstOrNull?.allergies ??
          const [];
    } catch (_) {
      return true; // best-effort — never block a save on a lookup failure.
    }
    if (allergies.isEmpty) return true;
    final warnings = MedSafetyChecker.checkAllergies(
      name: medicine.name,
      genericName: medicine.genericName,
      allergies: allergies,
    );
    if (warnings.isEmpty) return true;
    if (!mounted) return true;

    final ext = AppColorsExt.of(context);
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ext.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brLg),
        title: Text('Possible allergy conflict',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: ext.textPrimary)),
        content: Text(warnings.map((w) => w.message).join('\n\n'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: ext.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: ext.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: ext.warning.strong),
            child: const Text('Save anyway'),
          ),
        ],
      ),
    );
    return proceed ?? false;
  }

  /// Warns (with a chance to cancel) if this medicine plausibly interacts with
  /// another currently-active medicine belonging to the same profile. Returns
  /// true to proceed with the save, false to abort. Mirrors
  /// [_confirmAllergySafety]'s exact shape — including the "own dependentId,
  /// not scoped-active-profile" lookup, so this stays correct regardless of
  /// which profile happens to be active in the UI right now — and, per that
  /// method's lesson, is only ever called AFTER [_saveMedicine]'s re-entrancy
  /// guard is already set (an async DB read before the guard let a double-tap
  /// create duplicates once already).
  Future<bool> _confirmDrugInteractions(EnhancedMedicine medicine) async {
    final dependentId = _effectiveDependentId;
    List<EnhancedMedicine> others;
    try {
      final all =
          await MedicineCleanStorageService.getAllMedicines(scopeToActiveProfile: false);
      others = all
          .where((m) =>
              m.id != medicine.id &&
              m.isActive &&
              !m.isArchived &&
              m.dependentId == dependentId)
          .toList();
    } catch (_) {
      return true; // best-effort — never block a save on a lookup failure.
    }
    if (others.isEmpty) return true;

    // One representative name per medicine (generic when known) — avoids
    // pairing a brand against its own generic, same as the interactions tab.
    String repName(EnhancedMedicine m) =>
        (m.genericName != null && m.genericName!.trim().isNotEmpty)
            ? m.genericName!
            : m.name;
    final candidateName = repName(medicine);
    final interactions = <DrugInteraction>[];
    for (final other in others) {
      interactions.addAll(_interactionService.checkInteraction(candidateName, repName(other)));
    }
    if (interactions.isEmpty) return true;
    if (!mounted) return true;

    interactions.sort((a, b) => b.severity.index.compareTo(a.severity.index));
    final ext = AppColorsExt.of(context);
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ext.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brLg),
        title: Text('Possible drug interaction',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: ext.textPrimary)),
        content: SingleChildScrollView(
          child: Text(
            interactions
                .map((i) => '${i.severity.displayName}: ${i.description}')
                .join('\n\n'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: ext.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: ext.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: ext.warning.strong),
            child: const Text('Save anyway'),
          ),
        ],
      ),
    );
    return proceed ?? false;
  }

  Future<void> _saveMedicine() async {
    // Re-entrancy guard, checked AND set before anything async — including
    // the allergy check below, which does a real DB read
    // (getAllDependents()). A previous version of this method set
    // _isLoading only after that await resolved, leaving the Save/Add button
    // tappable for its whole duration: two fast taps each built their own
    // candidate with their own fresh UUID (id: existing?.id ?? Uuid().v4()
    // in _buildMedicineFromForm) and both went on to create a genuinely
    // duplicate medicine with its own duplicate set of reminders.
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final candidate = _buildMedicineFromForm();
    if (!await _confirmAllergySafety(candidate)) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    if (!mounted) return;
    if (!await _confirmDrugInteractions(candidate)) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    if (!mounted) return;

    final EnhancedMedicine medicine = candidate;
    // STEP 1 — persistence (the only thing that can legitimately fail a "save").
    try {
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

  EnhancedMedicine _buildMedicineFromForm() {
    final scheduleTimesList = _isPRN
          ? <ScheduledTime>[]
          : _scheduleTimes
              .map((t) => ScheduledTime(
                    hour: t.hour,
                    minute: t.minute,
                    windowMinutes: _windowMinutesByTime[t.hour * 60 + t.minute],
                  ))
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
        weekendTimes: _buildWeekendTimes(),
        titrationSteps: _buildTitrationSteps(),
      );

      // On an edit, `existing` carries forward every field this form doesn't
      // itself present a control for — most importantly `dependentId`. The
      // previous version of this constructor call omitted all of these,
      // silently resetting them to null/default on every single edit: a
      // caregiver-managed dependent's medicine reverted to "self" the moment
      // it was edited (undetectable in the UI, and defeating the whole
      // family-profile feature for any medicine ever touched again after
      // creation). copyWith isn't used here instead because several of these
      // (strength, genericName, instructions, purpose, currentStock,
      // expiryDate) are FORM fields the user can legitimately clear, and
      // copyWith's `param ?? this.field` can't tell "not passed" from
      // "explicitly cleared" without a dedicated sentinel per field.
      final existing = _isEditing ? widget.editMedicine! : null;
      final medicine = EnhancedMedicine(
        id: existing?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        dosageForm: _selectedForm,
        route: _selectedRoute,
        dosageAmount: _doseAmount ?? 1.0,
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
        isActive: existing?.isActive ?? true,
        isArchived: existing?.isArchived ?? false,
        createdAt: existing?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        // Fields this form has no control for at all — always carry forward.
        brandName: existing?.brandName,
        imprint: existing?.imprint,
        imagePath: existing?.imagePath,
        condition: existing?.condition,
        lastRefillDate: existing?.lastRefillDate,
        costPerUnit: existing?.costPerUnit,
        prescriptionNumber: existing?.prescriptionNumber,
        doctorId: existing?.doctorId,
        pharmacyId: existing?.pharmacyId,
        prescribedDate: existing?.prescribedDate,
        refillsRemaining: existing?.refillsRemaining,
        reminderSound: existing?.reminderSound,
        criticalAlert: existing?.criticalAlert ?? false,
        snoozeMinutes: existing?.snoozeMinutes ?? 10,
        drugInfo: existing?.drugInfo,
        warnings: existing?.warnings,
        sideEffects: existing?.sideEffects,
        dependentId: existing?.dependentId,
        notes: existing?.notes,
        customFields: existing?.customFields,
        healthCategories: existing?.healthCategories,
        customHealthCategory: existing?.customHealthCategory,
        patientProfileId: existing?.patientProfileId,
        requiresContinuousIntake: existing?.requiresContinuousIntake ?? false,
        minimumConsecutiveDays: existing?.minimumConsecutiveDays,
      );

    return medicine;
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
          // At large Dynamic Type the five labels stop fitting side by side and
          // run together ("InfoDosageScheduleLoo…M") while the last ones get
          // pushed off-screen. Measure them at the CURRENT text scale: while
          // they fit, render exactly as before; once they can't, collapse to the
          // active step only — the five progress bars above still show where we
          // are. No font size is changed either way.
          LayoutBuilder(
            builder: (context, constraints) {
              if (_stepLabelsFit(context, steps, constraints.maxWidth)) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(_totalSteps, (index) {
                    final isCurrent = index == _currentStep;
                    return Text(
                      steps[index],
                      maxLines: 1,
                      style: tt.bodySmall?.copyWith(
                        color: isCurrent ? ext.mark(med) : ext.textTertiary,
                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                      ),
                    );
                  }),
                );
              }
              return SizedBox(
                width: double.infinity,
                child: Text(
                  'Step ${_currentStep + 1} of $_totalSteps · '
                  '${steps[_currentStep]}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodySmall?.copyWith(
                    color: ext.mark(med),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Can all five step labels sit side by side in [maxWidth] at the reader's
  /// current text scale, with a little breathing room between them? Measured
  /// bold (the widest weight any of them takes) so the answer holds whichever
  /// step is active.
  bool _stepLabelsFit(
      BuildContext context, List<String> steps, double maxWidth) {
    if (!maxWidth.isFinite) return true;
    final style = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(fontWeight: FontWeight.w700);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    // Minimum gap between adjacent labels — without it they render as one word.
    var needed = 8.0 * (steps.length - 1);
    for (final label in steps) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      needed += painter.width;
      painter.dispose();
    }
    return needed <= maxWidth;
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
                    // Prefix the form glyph (💊 / 💧 / 🧴 …) so the user can tell
                    // a tablet from drops/cream before tapping.
                    label: s.form != null ? '${s.form!.icon} ${s.name}' : s.name,
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
                      // Auto-select the typical form + its unit so the common
                      // case (pick a suggestion) needs no manual form step.
                      if (s.form != null) {
                        _selectedForm = s.form!;
                        _dosageUnit = s.form!.unit;
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
            children: _formOptions().map((form) {
              final isSelected = _selectedForm == form;
              return _buildSelectablePill(
                context: context,
                selected: isSelected,
                onTap: () {
                  _hapticService.selection();
                  setState(() {
                    _selectedForm = form;
                    _dosageUnit = form.unit;
                    // Stale route from the previous form's option set (e.g.
                    // "Intramuscular" surviving a switch to drops) would be
                    // meaningless once its picker disappears.
                    if (!_routeOptionsForSelectedForm().contains(_selectedRoute)) {
                      _selectedRoute = null;
                    }
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
          if (_routeOptionsForSelectedForm().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            Text('Route (optional)',
                style: tt.labelLarge?.copyWith(color: ext.textSecondary)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _selectedForm == DosageForm.injection
                  ? 'How this injection is given'
                  : 'Where these drops are used',
              style: tt.bodySmall?.copyWith(color: ext.textTertiary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _routeOptionsForSelectedForm().map((route) {
                final isSelected = _selectedRoute == route;
                return _buildSelectablePill(
                  context: context,
                  selected: isSelected,
                  onTap: () {
                    _hapticService.selection();
                    setState(() =>
                        _selectedRoute = isSelected ? null : route);
                  },
                  child: Text(
                    route.displayName,
                    style: tt.labelMedium?.copyWith(
                      color: isSelected ? med.onContainer : ext.textPrimary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  /// Route options relevant to the currently selected [DosageForm] — only
  /// injection and drops are ambiguous enough to ask about; every other form
  /// already unambiguously implies its route (see [_selectedRoute]'s doc).
  List<AdministrationRoute> _routeOptionsForSelectedForm() {
    switch (_selectedForm) {
      case DosageForm.injection:
        return const [
          AdministrationRoute.subcutaneousInjection,
          AdministrationRoute.intramuscularInjection,
          AdministrationRoute.intravenousInjection,
        ];
      case DosageForm.drops:
        return const [
          AdministrationRoute.ophthalmic,
          AdministrationRoute.otic,
          AdministrationRoute.nasal,
        ];
      default:
        return const [];
    }
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
              Icon(Symbols.edit_note_rounded, color: med.onContainer, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Describe it',
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
            controller: _descController,
            hint: 'Describe your medication…',
            accent: med,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _quickFill(),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Quick fill',
                  leadingIcon: Symbols.bolt_rounded,
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.sm,
                  accent: med,
                  loading: _filling,
                  onPressed: _filling ? null : _quickFill,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppButton(
                label: 'Scan',
                leadingIcon: Symbols.document_scanner_rounded,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.sm,
                accent: med,
                onPressed: _filling ? null : _scanLabel,
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
      setState(() => _filling = true);

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
          setState(() => _filling = false);
          _showError("Couldn't read the label. Try better lighting or type it in.");
        }
        return;
      }

      // Show what was read, then parse it with the offline engine.
      _descController.text = text;
      final parsed = text.trim().isEmpty
          ? null
          : const CoachText().parseMedicine(text);
      if (!mounted) return;
      setState(() => _filling = false);
      if (parsed != null) {
        setState(() => _applyExtraction(parsed));
        _hapticService.success();
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(parsed != null
            ? 'Scanned — please review each step'
            : 'Scanned text added — review and adjust'),
      ));
    } catch (e) {
      if (mounted) {
        setState(() => _filling = false);
        _showError('Scan unavailable. You can type the details instead.');
      }
    }
  }

  Future<void> _quickFill() async {
    final desc = _descController.text.trim();
    if (desc.isEmpty) {
      _showError('Describe the medication first');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _filling = true);

    final result = const CoachText().parseMedicine(desc);

    if (!mounted) return;
    setState(() => _filling = false);

    // No null branch: the parser is deterministic and always returns a map
    // (blank input is rejected above), so it cannot fail here.
    setState(() => _applyExtraction(result));
    _hapticService.success();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Filled in — please review each step')),
      );
    }
  }

  /// Map a loosely-typed AI JSON payload onto the wizard's existing state.
  /// Every field is defensive: anything missing/unrecognized is left as-is so
  /// the manual defaults survive.
  void _applyExtraction(Map<String, dynamic> data) {
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
    final raw = data['mealTiming']?.toString().toLowerCase();
    if (raw != null && raw.isNotEmpty) {
      // Specific instructions first, so "before meals" doesn't fall into the
      // meal-name catch-all below.
      if (raw.contains('empty')) return MealTiming.emptyStomach;
      if (raw.contains('bed')) return MealTiming.beforeBed;
      if (raw.contains('wake') || raw.contains('morning')) {
        return MealTiming.wakeUp;
      }
      if (raw.contains('after')) return MealTiming.afterMeal;
      if (raw.contains('before')) return MealTiming.beforeMeal;
      // Meal-name anchors emitted by the rule engine (breakfast/lunch/dinner)
      // and generic "with food" — these were previously dropped, losing the
      // habit anchor for common phrases.
      if (raw.contains('with') ||
          raw.contains('meal') ||
          raw.contains('breakfast') ||
          raw.contains('lunch') ||
          raw.contains('dinner')) {
        return MealTiming.withMeal;
      }
    }
    final wf = data['withFood']?.toString().toLowerCase();
    if (wf == 'true' || wf == 'with') return MealTiming.withMeal;
    return null;
  }

  /// The forms shown as quick-pick pills: the common eight, plus the currently
  /// selected form if a suggestion auto-selected one outside that set (e.g.
  /// inhaler / gel / spray) so it stays visible and highlighted.
  List<DosageForm> _formOptions() {
    final base = DosageForm.values.take(8).toList();
    if (!base.contains(_selectedForm)) base.add(_selectedForm);
    return base;
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
                  // WCAG 3.3.2 — this was the only numeric health input in the
                  // app with no persistent label: the hint 'Amount' was the
                  // field's sole identification and it disappeared the moment
                  // anything was typed (and never reached a screen reader as a
                  // label at all).
                  label: 'Amount',
                  hint: 'e.g. 1',
                  accent: med,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                // The read-only unit box gets a matching label so it stays
                // baseline-aligned with the amount field now that the field
                // carries one. Same style AppTextField uses for its own label.
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Unit',
                      style: tt.labelLarge?.copyWith(color: ext.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      height: 52,
                      alignment: Alignment.centerLeft,
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: ext.surfaceVariant,
                        borderRadius: AppRadius.brMd,
                        border: Border.all(color: ext.outline),
                      ),
                      child: Text(
                        _dosageUnit,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodyLarge?.copyWith(color: ext.textSecondary),
                      ),
                    ),
                  ],
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
          const SizedBox(height: AppSpacing.xl),
          _buildTitrationSection(context),
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

  /// "Dose changes over time" (titration): an opt-in toggle + a simple list
  /// editor of "Day N+: X <unit>" steps, mirroring [_buildWeekendModeSection]'s
  /// AppCard-toggle-then-conditional-editor shape. Deliberately simpler than
  /// the core time-list editor — free-text day-offset + dose fields per row
  /// are enough for a feature this niche.
  Widget _buildTitrationSection(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final med = ext.medicine;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          onTap: () {
            _hapticService.toggle();
            setState(() {
              _titrationEnabled = !_titrationEnabled;
              if (_titrationEnabled && _titrationDayControllers.isEmpty) {
                _addTitrationStep();
              }
            });
          },
          child: Row(
            children: [
              Icon(Symbols.trending_up_rounded,
                  color:
                      _titrationEnabled ? ext.mark(med) : ext.textTertiary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dose changes over time', style: tt.titleLarge),
                    Text(
                      _titrationEnabled
                          ? 'Dose increases in steps (e.g. titration)'
                          : 'Same dose every time',
                      style: tt.bodySmall?.copyWith(color: ext.textSecondary),
                    ),
                  ],
                ),
              ),
              AppSwitch(
                value: _titrationEnabled,
                onChanged: (v) => setState(() {
                  _titrationEnabled = v;
                  if (v && _titrationDayControllers.isEmpty) {
                    _addTitrationStep();
                  }
                }),
                accent: med,
              ),
            ],
          ),
        ),
        if (_titrationEnabled) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            "Starting from the medicine's start date (day 0 = the dose "
            'above), add a step for each later change.',
            style: tt.bodySmall?.copyWith(color: ext.textTertiary),
          ),
          const SizedBox(height: AppSpacing.sm),
          ..._titrationDayControllers.asMap().entries.map((entry) {
            final i = entry.key;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _titrationDayControllers[i],
                      keyboardType: TextInputType.number,
                      label: 'Day N+',
                      hint: 'e.g. 14',
                      accent: med,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      controller: _titrationDoseControllers[i],
                      keyboardType: TextInputType.number,
                      label: 'Dose ($_dosageUnit)',
                      hint: 'e.g. 50',
                      accent: med,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => setState(() => _removeTitrationStep(i)),
                    icon: Icon(Symbols.delete_outline_rounded,
                        color: ext.textTertiary),
                  ),
                ],
              ),
            );
          }),
          AppButton(
            label: 'Add a step',
            leadingIcon: Symbols.add_rounded,
            variant: AppButtonVariant.secondary,
            accent: med,
            onPressed: () => setState(_addTitrationStep),
          ),
        ],
      ],
    );
  }

  void _addTitrationStep() {
    final lastDay = _titrationDayControllers.isNotEmpty
        ? int.tryParse(_titrationDayControllers.last.text.trim()) ?? 0
        : 0;
    _titrationDayControllers
        .add(TextEditingController(text: (lastDay + 7).toString()));
    _titrationDoseControllers
        .add(TextEditingController(text: _dosageController.text));
  }

  void _removeTitrationStep(int index) {
    _titrationDayControllers.removeAt(index).dispose();
    _titrationDoseControllers.removeAt(index).dispose();
  }

  /// The [TitrationStep] list built from the row controllers, or null when
  /// titration is off or every row failed to parse — mirrors
  /// [_buildWeekendTimes]'s null-means-"no override" contract so an empty/
  /// invalid editor never accidentally persists a titration schedule.
  List<TitrationStep>? _buildTitrationSteps() {
    if (!_titrationEnabled) return null;
    final steps = <TitrationStep>[];
    for (var i = 0; i < _titrationDayControllers.length; i++) {
      final day = _titrationDayAt(i);
      final dose = _titrationDoseAt(i);
      // Step-1 validation already rejects these, so reaching here means the
      // save arrived by some other route — never persist an unusable dose.
      if (day == null || dose == null) continue;
      steps.add(TitrationStep(startDayOffset: day, dosageAmount: dose));
    }
    return steps.isEmpty ? null : steps;
  }

  /// Day offset for titration row [i], or null when it isn't a whole number of
  /// days from the start date (negative offsets can never be reached, so they
  /// are as unusable as an unparseable field).
  int? _titrationDayAt(int i) {
    final v = int.tryParse(_titrationDayControllers[i].text.trim());
    if (v == null || v < 0) return null;
    return v;
  }

  /// Dose for titration row [i] under exactly the same rule as [_doseAmount] —
  /// this value REPLACES the base dose from its day onward, so a zero,
  /// negative, or absurd quantity must never reach [TitrationStep].
  double? _titrationDoseAt(int i) {
    final v = double.tryParse(_titrationDoseControllers[i].text.trim());
    if (v == null || !v.isFinite || v <= 0 || v > _maxDoseAmount) return null;
    return v;
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
          if (!_isPRN && _frequencyType != FrequencyType.everyXHours) ...[
            const SizedBox(height: AppSpacing.xl),
            _buildWeekendModeSection(context),
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
        // Re-tapping the already-selected count must NOT regenerate the default
        // times — that would silently discard the user's edited/added times.
        if (_frequencyType == freq) return;
        _hapticService.selection();
        setState(() {
          _frequencyType = freq;
          _updateTimesForFrequency();
        });
      },
      child: Container(
        // 68 is now a FLOOR, not a ceiling: as a fixed height it clipped the
        // two-line label at large Dynamic Type (a "BOTTOM OVERFLOWED" stripe
        // under every chip). The tile grows with the text instead.
        constraints: const BoxConstraints(minHeight: 68),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? med.container : ext.surface,
          borderRadius: AppRadius.brMd,
          border: Border.all(
            color: selected ? med.base : ext.outline,
            width: selected ? 1.5 : 1,
          ),
        ),
        // Four chips share the row width, so "a day" can outgrow its tile
        // sideways too. scaleDown only ever shrinks — at default sizes this
        // renders identically.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$count×',
                  maxLines: 1,
                  style: tt.titleLarge?.copyWith(
                    color: selected ? med.onContainer : ext.textPrimary,
                    fontWeight: FontWeight.w700,
                  )),
              Text('a day',
                  maxLines: 1,
                  style: tt.bodySmall?.copyWith(
                    color: selected ? med.onContainer : ext.textTertiary,
                  )),
            ],
          ),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Framed explicitly as a CAREGIVER safety limit when this medicine
            // belongs to a dependent — the person taking it may not be the one
            // setting it, unlike a self-owned PRN medicine.
            if (_effectiveDependentId != null) ...[
              Text(
                'Caregiver safety limit — the most doses allowed per day, and '
                'the minimum time required between them.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColorsExt.of(context).textSecondary),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
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

  /// "Sleep in on weekends": one toggle + one time picker for the FIRST
  /// dose's Sat/Sun time; every other dose that day shifts by the same
  /// offset, preserving the gaps between doses rather than needing a whole
  /// second time-list editor.
  Widget _buildWeekendModeSection(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final med = ext.medicine;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          onTap: () {
            _hapticService.toggle();
            setState(() {
              _weekendOverrideEnabled = !_weekendOverrideEnabled;
              if (_weekendOverrideEnabled) {
                _weekendAnchorTime ??= _scheduleTimes.first;
              }
            });
          },
          child: Row(
            children: [
              Icon(Symbols.weekend_rounded,
                  color: _weekendOverrideEnabled
                      ? ext.mark(med)
                      : ext.textTertiary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Different times on weekends', style: tt.titleLarge),
                    Text(
                      _weekendOverrideEnabled
                          ? 'Sat/Sun doses shift to start at '
                              '${_weekendAnchorTime?.format(context) ?? ''}'
                          : 'Same times every day',
                      style: tt.bodySmall?.copyWith(color: ext.textSecondary),
                    ),
                  ],
                ),
              ),
              AppSwitch(
                value: _weekendOverrideEnabled,
                onChanged: (v) => setState(() {
                  _weekendOverrideEnabled = v;
                  if (v) _weekendAnchorTime ??= _scheduleTimes.first;
                }),
              ),
            ],
          ),
        ),
        if (_weekendOverrideEnabled) ...[
          const SizedBox(height: AppSpacing.md),
          GestureDetector(
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _weekendAnchorTime ?? _scheduleTimes.first,
              );
              if (picked != null) setState(() => _weekendAnchorTime = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: med.container,
                borderRadius: AppRadius.brMd,
                border: Border.all(color: med.base),
              ),
              child: Row(
                children: [
                  Icon(Symbols.weekend_rounded, size: 20, color: med.onContainer),
                  const SizedBox(width: 12),
                  Text('Weekend start time',
                      style: tt.bodyMedium?.copyWith(color: med.onContainer)),
                  const Spacer(),
                  Text(
                    (_weekendAnchorTime ?? _scheduleTimes.first).format(context),
                    style: tt.titleMedium?.copyWith(
                        color: med.onContainer, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 6),
                  Icon(Symbols.edit_rounded, size: 16, color: med.onContainer),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// The weekend-shifted [ScheduledTime] list, or null when the override is
  /// off — every weekday dose shifted by the same (weekendAnchor - firstDose)
  /// offset, wrapping within a single day.
  List<ScheduledTime>? _buildWeekendTimes() {
    if (!_weekendOverrideEnabled || _weekendAnchorTime == null) return null;
    if (_scheduleTimes.isEmpty) return null;
    final anchor = _scheduleTimes.first;
    final offsetMinutes = (_weekendAnchorTime!.hour * 60 + _weekendAnchorTime!.minute) -
        (anchor.hour * 60 + anchor.minute);
    return _scheduleTimes.map((t) {
      final shifted = (t.hour * 60 + t.minute + offsetMinutes) % (24 * 60);
      final normalized = shifted < 0 ? shifted + 24 * 60 : shifted;
      return ScheduledTime(
        hour: normalized ~/ 60,
        minute: normalized % 60,
      );
    }).toList();
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTimeRow(context, index, time, canRemove),
                // "Every X hours" doses repeat all day by construction — a
                // window doesn't make sense layered on top of that.
                if (!isInterval) _buildWindowToggle(context, time),
              ],
            ),
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
                  // Label and value used to share one unbounded row (label +
                  // Spacer + value), so at large Dynamic Type they collided
                  // ("Reminder8:00 A…") and ran under the edit icon. Each now
                  // owns a bounded share; the value keeps the right edge it
                  // had, so default rendering is unchanged.
                  Expanded(
                    flex: 3,
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodyMedium?.copyWith(color: med.onContainer)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    // The time is the data — shrink it to fit rather than
                    // clipping it to "8:0…".
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        time.format(context),
                        maxLines: 1,
                        style: tt.titleMedium?.copyWith(
                            color: med.onContainer,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
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

  /// Opt-in reminder window (Phase 4) for one dose time — exact time (no
  /// window) stays the untouched default; tapping opens a duration picker.
  /// Off by default and easy to miss at a glance, deliberately: this is an
  /// advanced option, not something every user needs to see.
  Widget _buildWindowToggle(BuildContext context, TimeOfDay time) {
    final ext = AppColorsExt.of(context);
    final med = ext.medicine;
    final tt = Theme.of(context).textTheme;
    final key = time.hour * 60 + time.minute;
    final window = _windowMinutesByTime[key];
    final on = window != null;

    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4),
      child: GestureDetector(
        onTap: () => _selectWindowDuration(key),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              on ? Symbols.hourglass_top_rounded : Symbols.hourglass_empty_rounded,
              size: 15,
              color: on ? ext.mark(med) : ext.textTertiary,
            ),
            const SizedBox(width: 6),
            // This caption is long; unbounded in a min-width Row it shot off
            // the right edge at large Dynamic Type. Flexible lets it wrap
            // inside the row's real width instead.
            Flexible(
              child: Text(
                on
                    ? 'Reminds across a ${_formatWindow(window)} window · 3 nudges'
                    : 'Use a reminder window instead of one exact time',
                style: tt.bodySmall?.copyWith(
                  color: on ? ext.mark(med) : ext.textTertiary,
                  decoration: on ? TextDecoration.underline : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatWindow(int minutes) {
    if (minutes < 60) return '$minutes-min';
    final hours = minutes / 60;
    return hours == hours.roundToDouble()
        ? '${hours.round()}-hour'
        : '${hours.toStringAsFixed(1)}-hour';
  }

  /// [timeKey] is minute-of-day (hour*60+minute) — see [_windowMinutesByTime].
  /// The sheet returns null for BOTH "dismissed without choosing" and would be
  /// ambiguous with "chose exact time" if that used null too, so "explicit
  /// off" is its own sentinel (-1) instead.
  Future<void> _selectWindowDuration(int timeKey) async {
    final ext = AppColorsExt.of(context);
    final med = ext.medicine;
    const offSentinel = -1;

    final result = await AppBottomSheet.show<int>(
      context,
      title: 'Reminder window',
      icon: Symbols.hourglass_top_rounded,
      accent: med,
      builder: (sheetCtx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppListTile(
            icon: Symbols.schedule_rounded,
            title: 'Exact time (default)',
            subtitle: 'One reminder at the exact minute',
            accent: med,
            trailing: const SizedBox.shrink(),
            onTap: () => Navigator.pop(sheetCtx, offSentinel),
          ),
          for (final mins in const [30, 60, 90, 120])
            AppListTile(
              icon: Symbols.hourglass_top_rounded,
              title: '${_formatWindow(mins)} window',
              subtitle: 'Up to 3 nudges spread across the window',
              accent: med,
              trailing: const SizedBox.shrink(),
              onTap: () => Navigator.pop(sheetCtx, mins),
            ),
        ],
      ),
    );

    if (result == null) return; // dismissed — leave the current choice as-is
    setState(() {
      if (result == offSentinel) {
        _windowMinutesByTime.remove(timeKey);
      } else {
        _windowMinutesByTime[timeKey] = result;
      }
    });
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
                setState(() {
                  // If the times are still the auto-generated defaults, re-anchor
                  // them to the newly-picked meal timing; never overwrite times
                  // the user hand-edited.
                  final wasAuto = _timesMatchAuto();
                  _mealTiming = timing;
                  if (wasAuto && !_isPRN) _updateTimesForFrequency();
                });
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

  /// True when the current times still equal the auto-generated defaults for the
  /// current frequency + meal timing (i.e. the user hasn't hand-edited them).
  bool _timesMatchAuto() {
    final auto = _defaultTimesFor(_frequencyType, _mealTiming);
    if (auto.length != _scheduleTimes.length) return false;
    for (var i = 0; i < auto.length; i++) {
      if (auto[i].hour != _scheduleTimes[i].hour ||
          auto[i].minute != _scheduleTimes[i].minute) {
        return false;
      }
    }
    return true;
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
        // The window toggle is hidden for this frequency (a window doesn't
        // make sense layered on interval fan-out — see _buildTimesSection),
        // but a value set for this SAME anchor time under a PRIOR frequency
        // would otherwise survive untouched, since the key (hour*60+minute)
        // doesn't change. Left unremoved, groupRemindersBySlot drops
        // windowMinutes when expanding the interval's fan-out times (so the
        // anchor slot schedules as an ordinary exact-time alarm) while
        // _recomputeWindowNudges reads the raw, un-expanded schedule.times
        // and still sees hasWindow==true on it — scheduling a second, full
        // 3-nudge sequence for the same dose on top of the exact-time alarm.
        //
        // Only removes the SURVIVING anchor's own entry — NOT the whole map.
        // A blanket clear() here also wiped window settings for every OTHER
        // time (e.g. a 3x-daily medicine's 14:00/20:00 doses), which are
        // simply unused while everyXHours is selected (nothing ever reads a
        // _windowMinutesByTime entry for a clock time absent from the
        // current _scheduleTimes) but would otherwise correctly reappear if
        // the user switches back to a frequency whose regenerated default
        // times land on those same clock times again.
        final anchor = _scheduleTimes.first;
        _windowMinutesByTime.remove(anchor.hour * 60 + anchor.minute);
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
    if (time == null) return;
    final key = time.hour * 60 + time.minute;
    // Ignore duplicates, and keep times chronological so the "Dose N" labels
    // (which follow list order) read in the order they'll actually fire.
    if (_scheduleTimes.any((t) => t.hour * 60 + t.minute == key)) return;
    setState(() {
      _scheduleTimes.add(time);
      _scheduleTimes
          .sort((a, b) => (a.hour * 60 + a.minute) - (b.hour * 60 + b.minute));
    });
  }

  Future<void> _editTime(int index) async {
    final time = await AppTimePicker.show(
      context,
      initial: _scheduleTimes[index],
    );
    if (time != null) {
      final oldKey = _scheduleTimes[index].hour * 60 + _scheduleTimes[index].minute;
      final newKey = time.hour * 60 + time.minute;
      setState(() {
        _scheduleTimes[index] = time;
        // A window is keyed by clock time, not list position — moving the
        // dose to a new minute must carry its window along, or the toggle
        // would silently read as "off" at the new time.
        if (oldKey != newKey && _windowMinutesByTime.containsKey(oldKey)) {
          _windowMinutesByTime[newKey] = _windowMinutesByTime.remove(oldKey)!;
        }
      });
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
    // Once Schedule (step 2) is done the medicine has everything it needs — the
    // remaining steps (Look, More) are purely optional. Let the user finish here
    // instead of paging through two optional screens.
    final canFinish = _currentStep >= 2;

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // From Schedule onward, offer the optional Look/More steps as a light
          // secondary rather than forcing users through them.
          if (canFinish && !isLastStep) ...[
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'Add appearance & extras',
                variant: AppButtonVariant.ghost,
                accent: med,
                trailingIcon: Symbols.arrow_forward_rounded,
                onPressed: _isLoading ? null : _nextStep,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
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
                  label: canFinish
                      ? (_isEditing ? 'Save Changes' : 'Add Medication')
                      : 'Continue',
                  variant: AppButtonVariant.primary,
                  accent: med,
                  fullWidth: true,
                  loading: _isLoading,
                  // Schedule reached → validate, then save; earlier → advance.
                  onPressed: _isLoading
                      ? null
                      : (canFinish ? _finishAndSave : _nextStep),
                ),
              ),
            ],
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
