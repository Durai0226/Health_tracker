import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../widgets/nunito_pill_visual.dart';
import '../models/enhanced_medicine.dart';
import '../models/medicine_enums.dart';
import '../models/medicine_log.dart'
    show MedicineLog, moodRatingLabels, effectivenessRatingLabels,
        injectionSites, suggestNextInjectionSite;
import '../services/medicine_storage_service.dart';
import '../services/medication_reminder_service.dart';
import '../services/drug_interaction_service.dart';
import '../../../core/services/haptic_service.dart';

class NunitoTakeMedicationSheet extends StatefulWidget {
  final EnhancedMedicine medicine;
  final DateTime scheduledTime;

  const NunitoTakeMedicationSheet({
    super.key,
    required this.medicine,
    required this.scheduledTime,
  });

  @override
  State<NunitoTakeMedicationSheet> createState() => _NunitoTakeMedicationSheetState();
}

class _NunitoTakeMedicationSheetState extends State<NunitoTakeMedicationSheet> {
  static const List<String> _moodEmojis = ['😄', '🙂', '😐', '😕', '😢'];
  // Labels (and their 1-5 rating direction) are shared with the report's
  // symptom-summary rendering — see medicine_log.dart's moodRatingLabels /
  // effectivenessRatingLabels docs for why the two scales deliberately run
  // in opposite directions.
  static const List<String> _moodLabels = moodRatingLabels;
  static const List<String> _effectivenessLabels = effectivenessRatingLabels;

  // Common side-effects the user can flag on the details expander.
  static const List<String> _sideEffectOptions = [
    'Nausea',
    'Headache',
    'Dizziness',
    'Drowsiness',
    'Fatigue',
    'Upset stomach',
    'Rash',
    'Dry mouth',
  ];

  int _selectedMood = -1;
  int _selectedEffectiveness = -1;
  final Set<String> _selectedSideEffects = {};
  bool _showDetails = false;
  bool _isLoading = false;

  // Injection-site rotation — only meaningful (and only shown) for injectable
  // medicines, see [_isInjectable]. Pre-filled with the rotation's suggested
  // next site once past logs load; the user can tap a different chip instead.
  String? _selectedInjectionSite;

  final HapticService _hapticService = HapticService();
  final TextEditingController _notesController = TextEditingController();

  /// Gate for the injection-site picker: either an explicit injection
  /// [AdministrationRoute], or (for medicines added before that field
  /// existed) a plain [DosageForm.injection].
  bool get _isInjectable {
    switch (widget.medicine.route) {
      case AdministrationRoute.subcutaneousInjection:
      case AdministrationRoute.intramuscularInjection:
      case AdministrationRoute.intravenousInjection:
        return true;
      default:
        return widget.medicine.dosageForm == DosageForm.injection;
    }
  }

  /// The dose amount that actually applies to THIS scheduled slot — the
  /// current titration step's amount for a titrating medicine, or the
  /// medicine's plain [EnhancedMedicine.dosageAmount] unchanged when it isn't
  /// titrating. See [MedicineSchedule.effectiveDosageAmount].
  double get _effectiveDosageAmount => widget.medicine.schedule
      .effectiveDosageAmount(widget.scheduledTime, widget.medicine.dosageAmount);

  /// Mirrors [EnhancedMedicine.displayDosage]'s formatting but over
  /// [_effectiveDosageAmount] instead of the medicine's base amount, so a
  /// titrating medicine's sheet shows the CURRENT step's dose, not the
  /// original one it was created with.
  String get _effectiveDisplayDosage {
    final amount = _effectiveDosageAmount;
    final amountStr =
        amount % 1 == 0 ? amount.toInt().toString() : amount.toString();
    final unit = widget.medicine.dosageUnit ?? widget.medicine.dosageForm.unit;
    return '$amountStr $unit';
  }

  @override
  void initState() {
    super.initState();
    if (_isInjectable) _loadSuggestedInjectionSite();
  }

  /// Best-effort: a lookup failure just leaves no site pre-selected, never
  /// blocks the sheet from opening.
  Future<void> _loadSuggestedInjectionSite() async {
    try {
      final logs = await MedicineCleanStorageService.getLogsForMedicine(
          widget.medicine.id);
      final suggestion = suggestNextInjectionSite(logs);
      if (mounted) setState(() => _selectedInjectionSite = suggestion);
    } catch (e) {
      debugPrint('⚠️ Loading suggested injection site failed: $e');
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _takeMedication() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    if (!await _confirmPrnLimits()) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    if (!mounted) return;

    _hapticService.medicineTaken();

    try {
      // Route through markMedicineTaken so the dose is logged AND stock is
      // reduced (enabling low-stock / refill detection). addLog alone skips
      // the stock decrement.
      final log = await MedicineCleanStorageService.markMedicineTaken(
        medicineId: widget.medicine.id,
        scheduledTime: widget.scheduledTime,
        dosageTaken: _effectiveDosageAmount,
        moodRating: _selectedMood >= 0 ? _selectedMood + 1 : null,
        effectivenessRating:
            _selectedEffectiveness >= 0 ? _selectedEffectiveness + 1 : null,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        sideEffects: _selectedSideEffects.isNotEmpty
            ? _selectedSideEffects.join(', ')
            : null,
        vitals: (_isInjectable && _selectedInjectionSite != null)
            ? {'injectionSite': _selectedInjectionSite}
            : null,
      );

      if (mounted) {
        Navigator.pop(context, {'taken': true, 'log': log});
      }
      // See _skipMedication: no setState after popping, or the buttons re-enable
      // for the duration of the pop animation and the dose can be double-logged.
      return;
    } catch (e) {
      debugPrint('Error taking medication: $e');
      if (mounted) {
        // A raw exception string is not something to show a patient.
        context.toastError('Couldn\'t save this dose. Please try again.');
      }
    }

    // Only reached on failure, where the sheet stays open and must be usable.
    if (mounted) setState(() => _isLoading = false);
  }

  /// For a PRN medicine with configured limits, warns (with a chance to
  /// cancel) if logging this dose now would exceed maxDailyDoses or violate
  /// minHoursBetweenDoses. Both fields are captured by the add/edit form's
  /// PRN steppers but were never actually consulted anywhere — this sheet is
  /// the "log a dose" entry point for PRN medicines, so it's the natural
  /// place to finally read them. Warns rather than hard-blocks, matching
  /// _confirmAllergySafety's UX in the add/edit flow: PRN dosing is
  /// ultimately the user's own call, not something to lock them out of.
  Future<bool> _confirmPrnLimits() async {
    final schedule = widget.medicine.schedule;
    if (!schedule.isPRN) return true;
    final maxDaily = schedule.maxDailyDoses;
    final minHours = schedule.minHoursBetweenDoses;
    if (maxDaily == null && minHours == null) return true;

    List<MedicineLog> takenToday;
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final logs = MedicineCleanStorageService.dedupeByDose(
          await MedicineCleanStorageService.getLogsForMedicine(widget.medicine.id));
      takenToday = logs
          .where((l) =>
              l.isTaken && (l.actionTime ?? l.scheduledTime).isAfter(todayStart))
          .toList();
    } catch (_) {
      return true; // best-effort — never block a dose on a lookup failure.
    }

    final warnings = <String>[];
    if (maxDaily != null && takenToday.length >= maxDaily) {
      warnings.add(
          "You've already logged ${takenToday.length} dose${takenToday.length == 1 ? '' : 's'} today — the configured limit is $maxDaily.");
    }
    if (minHours != null && takenToday.isNotEmpty) {
      final lastTaken = takenToday
          .map((l) => l.actionTime ?? l.scheduledTime)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      final sinceLastHours = DateTime.now().difference(lastTaken).inMinutes / 60.0;
      if (sinceLastHours < minHours) {
        warnings.add(
            'Your last dose was ${sinceLastHours < 1 ? '${(sinceLastHours * 60).round()} min' : '${sinceLastHours.toStringAsFixed(1)} hr'} ago — '
            'the configured minimum gap is $minHours hour${minHours == 1 ? '' : 's'}.');
      }
    }
    if (warnings.isEmpty) return true;
    if (!mounted) return true;

    final ext = AppColorsExt.of(context);
    // A dependent's PRN limit is caregiver-set, not the taker's own call (see
    // the add/edit form's matching caption) — a one-tap "Log anyway" is fine
    // for a self-owned medicine, but overriding a caregiver's safety limit
    // needs deliberate acknowledgment, not a casual tap.
    final isCaregiverManaged = widget.medicine.dependentId != null;
    // Hoisted OUTSIDE the StatefulBuilder below: a `var` declared inside that
    // builder callback would reset to false on every rebuild it triggers via
    // setDialogState, making the checkbox immediately un-check itself.
    var acknowledged = false;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => !isCaregiverManaged
          ? AlertDialog(
              backgroundColor: ext.surface,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.brLg),
              title: Text('PRN limit reached',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: ext.textPrimary)),
              content: Text(warnings.join('\n\n'),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: ext.textSecondary)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Cancel', style: TextStyle(color: ext.textSecondary)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(foregroundColor: ext.warning.strong),
                  child: const Text('Log anyway'),
                ),
              ],
            )
          : StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  backgroundColor: ext.surface,
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.brLg),
                  title: Text('Caregiver safety limit reached',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(color: ext.textPrimary)),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(warnings.join('\n\n'),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: ext.textSecondary)),
                      const SizedBox(height: AppSpacing.md),
                      CheckboxListTile(
                        value: acknowledged,
                        onChanged: (v) =>
                            setDialogState(() => acknowledged = v ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          "I'm the caregiver and I'm overriding this limit.",
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: ext.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text('Cancel', style: TextStyle(color: ext.textSecondary)),
                    ),
                    TextButton(
                      onPressed:
                          acknowledged ? () => Navigator.pop(context, true) : null,
                      style: TextButton.styleFrom(foregroundColor: ext.warning.strong),
                      child: const Text('Log anyway'),
                    ),
                  ],
                );
              },
            ),
    );
    return proceed ?? false;
  }

  /// Lets the user log a dose AHEAD of its real scheduled slot — travel/
  /// timezone changes, or a pre-filled pillbox. Offers the medicine's
  /// upcoming fixed slots over the next few days (not this sheet's own
  /// [widget.scheduledTime], which the primary Take button already covers).
  /// Only meaningful for a fixed-schedule medicine — a PRN medicine has no
  /// enumerable future slots to pre-log against.
  Future<void> _logForDifferentTime() async {
    final schedule = widget.medicine.schedule;
    final now = DateTime.now();
    final upcoming = <DateTime>[];
    for (var dayOffset = 0; dayOffset < 4; dayOffset++) {
      final day = DateTime(now.year, now.month, now.day + dayOffset);
      for (final slot in schedule.getScheduledTimesForDate(day)) {
        if (slot.isAfter(now)) upcoming.add(slot);
      }
    }
    upcoming.sort();
    if (upcoming.isEmpty) {
      if (mounted) context.toastInfo('No upcoming doses to pre-log yet.');
      return;
    }

    final ext = AppColorsExt.of(context);
    final chosen = await AppBottomSheet.show<DateTime>(
      context,
      title: 'Log for a different time',
      icon: Symbols.schedule_rounded,
      accent: ext.medicine,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final slot in upcoming.take(10))
            AppListTile(
              icon: Symbols.schedule_rounded,
              iconColor: ext.mark(ext.medicine),
              title: DateFormat('EEE, MMM d').format(slot),
              subtitle: DateFormat('h:mm a').format(slot),
              onTap: () => Navigator.pop(sheetContext, slot),
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
    if (chosen == null || !mounted) return;

    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await MedicineCleanStorageService.markMedicinePreLogged(
        medicineId: widget.medicine.id,
        scheduledTime: chosen,
        dosageTaken: widget.medicine.schedule
            .effectiveDosageAmount(chosen, widget.medicine.dosageAmount),
        vitals: (_isInjectable && _selectedInjectionSite != null)
            ? {'injectionSite': _selectedInjectionSite}
            : null,
      );
      _hapticService.medicineTaken();
      if (mounted) {
        context.toastSuccess(
            'Pre-logged for ${DateFormat('MMM d, h:mm a').format(chosen)}');
        Navigator.pop(context, {'preLoggedOther': true});
      }
      return;
    } catch (e) {
      debugPrint('Error pre-logging medication: $e');
      if (mounted) context.toastError('Couldn\'t pre-log this dose. Please try again.');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _skipMedication() async {
    _hapticService.medicineSkipped();

    final reason = await _showSkipReasonSheet();
    if (reason == null) return;

    setState(() => _isLoading = true);

    try {
      // The log id is derived from (medicine, slot) — see
      // MedicineCleanStorageService.doseLogId — so skipping the same dose twice
      // replaces the row rather than counting two skips.
      final log = await MedicineCleanStorageService.markMedicineSkipped(
        medicineId: widget.medicine.id,
        scheduledTime: widget.scheduledTime,
        reason: reason,
        skipNote:
            _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      if (mounted) {
        Navigator.pop(context, {'skipped': true, 'log': log});
      }
      // Deliberately no setState here: the sheet is popping, and clearing the
      // loading flag on a route that's being torn down both spins a rebuild for
      // nothing and re-enables the buttons for the length of the pop animation —
      // long enough to double-submit.
      return;
    } catch (e) {
      debugPrint('Error skipping medication: $e');
      if (mounted) {
        context.toastError('Couldn\'t save the skip. Please try again.');
      }
    }

    // Only reached on failure, where the sheet stays open and must be usable.
    if (mounted) setState(() => _isLoading = false);
  }

  Future<SkipReason?> _showSkipReasonSheet() {
    final ext = AppColorsExt.of(context);
    // Render options straight from the enum and return the selected enum value
    // directly — no positional index remapping, so the stored reason always
    // matches the label the user tapped.
    return AppBottomSheet.show<SkipReason>(
      context,
      title: 'Why are you skipping?',
      icon: Symbols.help_rounded,
      accent: ext.medicine,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final reason in SkipReason.values)
            AppListTile(
              icon: Symbols.radio_button_unchecked_rounded,
              title: reason.displayName,
              accent: ext.medicine,
              trailing: const SizedBox.shrink(),
              onTap: () => Navigator.pop(ctx, reason),
            ),
        ],
      ),
    );
  }

  Future<void> _snoozeMedication() async {
    _hapticService.light();

    // Use the medicine's configured snooze duration; fall back to 10 min.
    final minutes = widget.medicine.snoozeMinutes > 0
        ? widget.medicine.snoozeMinutes
        : 10;

    setState(() => _isLoading = true);

    try {
      // Actually reschedule the notification instead of just closing the sheet.
      await MedicationReminderService().snoozeReminderForDose(
        widget.medicine,
        widget.scheduledTime,
        minutes,
      );

      // Snooze only reschedules the reminder — it is NOT an adherence outcome.
      // Do NOT persist a log: the store has no 'snoozed' status, so a snoozed
      // log round-trips to 'pending', shows wrongly in history, and (worse)
      // suppresses missed-dose reconciliation for that slot. The dose stays
      // open and will reconcile to 'missed' if never taken.
      if (mounted) {
        context.toastInfo('Snoozed for $minutes min');
        Navigator.pop(context, {'snoozed': true, 'minutes': minutes});
      }
    } catch (e) {
      debugPrint('Error snoozing medication: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        context.toastError('Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return AccentScope(
      feature: FeatureAccent.medicine,
      child: Container(
        margin: EdgeInsets.only(bottom: bottomPadding),
        decoration: BoxDecoration(
          color: ext.surfaceElevated,
          borderRadius: AppRadius.topSheet,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHandle(ext),
                  const SizedBox(height: AppSpacing.lg),
                  _buildMedicineInfo(ext),
                  const SizedBox(height: AppSpacing.lg),
                  _buildDetailsExpander(ext),
                  const SizedBox(height: AppSpacing.lg),
                  _buildActionButtons(ext),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHandle(AppColorsExt ext) {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: ext.outlineStrong,
        borderRadius: AppRadius.brFull,
      ),
    );
  }

  Widget _buildMedicineInfo(AppColorsExt ext) {
    final tt = Theme.of(context).textTheme;
    // One calm line of context: the user's own "why" if set, else a general
    // reference use from the on-device monograph. Null → shown nothing.
    final purpose = widget.medicine.purpose?.trim();
    final forContext = (purpose != null && purpose.isNotEmpty)
        ? purpose
        : DrugInteractionService().primaryUses(
            name: widget.medicine.name,
            genericName: widget.medicine.genericName);
    return Row(
      children: [
        NunitoPillVisual(
          color: widget.medicine.color,
          shape: widget.medicine.shape,
          size: 64,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.medicine.name,
                style: tt.headlineSmall?.copyWith(color: ext.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                _effectiveDisplayDosage,
                style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
              ),
              if (widget.medicine.instructions != null) ...[
                const SizedBox(height: 4),
                Text(
                  widget.medicine.instructions!,
                  style: tt.bodySmall?.copyWith(color: ext.mark(ext.medicine)),
                ),
              ],
              if (forContext != null && forContext.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'For $forContext',
                  style: tt.bodySmall?.copyWith(color: ext.textTertiary),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Collapsible extras so the default "Take" path stays one-tap. Mood, side
  /// effects and notes only appear once the user taps "Add details".
  Widget _buildDetailsExpander(AppColorsExt ext) {
    final count = (_selectedMood >= 0 ? 1 : 0) +
        (_selectedEffectiveness >= 0 ? 1 : 0) +
        _selectedSideEffects.length +
        (_notesController.text.isNotEmpty ? 1 : 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppListTile(
          icon: Symbols.tune_rounded,
          title: 'Add details',
          subtitle: _showDetails
              ? 'Mood, side effects and notes'
              : (count > 0
                  ? '$count added'
                  : 'Optional — mood, side effects, notes'),
          accent: ext.medicine,
          trailing: Icon(
            _showDetails
                ? Symbols.expand_less_rounded
                : Symbols.expand_more_rounded,
            color: ext.textSecondary,
          ),
          onTap: () {
            _hapticService.selection();
            setState(() => _showDetails = !_showDetails);
          },
        ),
        if (_showDetails) ...[
          const SizedBox(height: AppSpacing.md),
          _buildMoodSelector(ext),
          const SizedBox(height: AppSpacing.lg),
          _buildEffectivenessSelector(ext),
          const SizedBox(height: AppSpacing.lg),
          _buildSideEffectSelector(ext),
          if (_isInjectable) ...[
            const SizedBox(height: AppSpacing.lg),
            _buildInjectionSiteSelector(ext),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _notesController,
            hint: 'Add notes (optional)',
            accent: ext.medicine,
            maxLines: 2,
          ),
        ],
      ],
    );
  }

  Widget _buildMoodSelector(AppColorsExt ext) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How are you feeling?',
          style: tt.labelLarge?.copyWith(color: ext.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: List.generate(5, (index) {
            final isSelected = _selectedMood == index;
            return AppChip(
              label: '${_moodEmojis[index]}  ${_moodLabels[index]}',
              selected: isSelected,
              accent: ext.medicine,
              onTap: () {
                _hapticService.selection();
                setState(() => _selectedMood = index);
              },
            );
          }),
        ),
      ],
    );
  }

  /// Doctor-report input: "how well did this dose work" — feeds
  /// `effectivenessRating`, a field the store has always accepted but no UI
  /// has ever written, so it has never appeared in any report.
  Widget _buildEffectivenessSelector(AppColorsExt ext) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How well did it work?',
          style: tt.labelLarge?.copyWith(color: ext.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: List.generate(5, (index) {
            final isSelected = _selectedEffectiveness == index;
            return AppChip(
              label: _effectivenessLabels[index],
              selected: isSelected,
              accent: ext.medicine,
              onTap: () {
                _hapticService.selection();
                setState(() => _selectedEffectiveness = index);
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSideEffectSelector(AppColorsExt ext) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Any side effects?',
          style: tt.labelLarge?.copyWith(color: ext.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final effect in _sideEffectOptions)
              AppChip(
                label: effect,
                selected: _selectedSideEffects.contains(effect),
                accent: ext.warning,
                onTap: () {
                  _hapticService.selection();
                  setState(() {
                    if (!_selectedSideEffects.add(effect)) {
                      _selectedSideEffects.remove(effect);
                    }
                  });
                },
              ),
          ],
        ),
      ],
    );
  }

  /// Injection-site rotation: suggests the next site so an injectable
  /// medicine isn't repeatedly used on the same spot. Purely a suggestion —
  /// the user can tap any other chip instead, and skipping entirely (leaving
  /// [_selectedInjectionSite] at whatever it loaded to) is fine too.
  Widget _buildInjectionSiteSelector(AppColorsExt ext) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Injection site',
          style: tt.labelLarge?.copyWith(color: ext.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          _selectedInjectionSite != null
              ? 'Suggested: $_selectedInjectionSite — rotate to avoid soreness'
              : "Pick where you're injecting today",
          style: tt.bodySmall?.copyWith(color: ext.textTertiary),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final site in injectionSites)
              AppChip(
                label: site,
                selected: _selectedInjectionSite == site,
                accent: ext.medicine,
                onTap: () {
                  _hapticService.selection();
                  setState(() => _selectedInjectionSite = site);
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons(AppColorsExt ext) {
    return Column(
      children: [
        // Primary action - Take
        AppButton(
          label: 'Take Medication',
          leadingIcon: Symbols.check_rounded,
          variant: AppButtonVariant.primary,
          size: AppButtonSize.lg,
          accent: ext.success,
          fullWidth: true,
          loading: _isLoading,
          onPressed: _isLoading ? null : _takeMedication,
        ),
        const SizedBox(height: AppSpacing.sm),
        // Secondary actions
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Snooze',
                leadingIcon: Symbols.snooze_rounded,
                variant: AppButtonVariant.secondary,
                accent: ext.medicine,
                onPressed: _isLoading ? null : _snoozeMedication,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppButton(
                label: 'Skip',
                leadingIcon: Symbols.close_rounded,
                variant: AppButtonVariant.tonal,
                accent: ext.warning,
                onPressed: _isLoading ? null : _skipMedication,
              ),
            ),
          ],
        ),
        // PRN has no enumerable future slots to pre-log against.
        if (!widget.medicine.schedule.isPRN) ...[
          const SizedBox(height: AppSpacing.xs),
          TextButton.icon(
            onPressed: _isLoading ? null : _logForDifferentTime,
            icon: Icon(Symbols.schedule_rounded, size: 18, color: ext.textSecondary),
            label: Text('Log for a different time',
                style: TextStyle(color: ext.textSecondary)),
          ),
        ],
      ],
    );
  }
}
