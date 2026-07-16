import 'package:flutter/material.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../widgets/nunito_pill_visual.dart';
import '../models/enhanced_medicine.dart';
import '../models/medicine_log.dart';
import '../models/medicine_enums.dart';
import '../services/medicine_storage_service.dart';
import '../services/medication_reminder_service.dart';
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
  static const List<String> _moodLabels = ['Great', 'Good', 'Okay', 'Bad', 'Terrible'];

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
  final Set<String> _selectedSideEffects = {};
  bool _showDetails = false;
  bool _isLoading = false;

  final HapticService _hapticService = HapticService();
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _takeMedication() async {
    setState(() => _isLoading = true);
    _hapticService.medicineTaken();

    try {
      // Route through markMedicineTaken so the dose is logged AND stock is
      // reduced (enabling low-stock / refill detection). addLog alone skips
      // the stock decrement.
      final log = await MedicineCleanStorageService.markMedicineTaken(
        medicineId: widget.medicine.id,
        scheduledTime: widget.scheduledTime,
        dosageTaken: widget.medicine.dosageAmount,
        moodRating: _selectedMood >= 0 ? _selectedMood + 1 : null,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        sideEffects: _selectedSideEffects.isNotEmpty
            ? _selectedSideEffects.join(', ')
            : null,
      );

      if (mounted) {
        Navigator.pop(context, {'taken': true, 'log': log});
      }
    } catch (e) {
      debugPrint('Error taking medication: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _skipMedication() async {
    _hapticService.medicineSkipped();

    final reason = await _showSkipReasonSheet();
    if (reason == null) return;

    setState(() => _isLoading = true);

    try {
      final log = MedicineLog(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        medicineId: widget.medicine.id,
        scheduledTime: widget.scheduledTime,
        actionTime: DateTime.now(),
        status: MedicineStatus.skipped,
        skipReason: reason,
        skipNote: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      await MedicineCleanStorageService.addLog(log);

      if (mounted) {
        Navigator.pop(context, {'skipped': true, 'log': log});
      }
    } catch (e) {
      debugPrint('Error skipping medication: $e');
    }

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
      icon: Icons.help_outline_rounded,
      accent: ext.medicine,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final reason in SkipReason.values)
            AppListTile(
              icon: Icons.radio_button_unchecked_rounded,
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

      // Record a snooze log so history reflects the deferred dose.
      final log = MedicineLog(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        medicineId: widget.medicine.id,
        scheduledTime: widget.scheduledTime,
        actionTime: DateTime.now(),
        status: MedicineStatus.snoozed,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );
      await MedicineCleanStorageService.addLog(log);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Snoozed for $minutes min')),
        );
        Navigator.pop(context, {'snoozed': true, 'minutes': minutes, 'log': log});
      }
    } catch (e) {
      debugPrint('Error snoozing medication: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
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
                widget.medicine.displayDosage,
                style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
              ),
              if (widget.medicine.instructions != null) ...[
                const SizedBox(height: 4),
                Text(
                  widget.medicine.instructions!,
                  style: tt.bodySmall?.copyWith(color: ext.mark(ext.medicine)),
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
        _selectedSideEffects.length +
        (_notesController.text.isNotEmpty ? 1 : 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppListTile(
          icon: Icons.tune_rounded,
          title: 'Add details',
          subtitle: _showDetails
              ? 'Mood, side effects and notes'
              : (count > 0
                  ? '$count added'
                  : 'Optional — mood, side effects, notes'),
          accent: ext.medicine,
          trailing: Icon(
            _showDetails
                ? Icons.expand_less_rounded
                : Icons.expand_more_rounded,
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
          _buildSideEffectSelector(ext),
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

  Widget _buildActionButtons(AppColorsExt ext) {
    return Column(
      children: [
        // Primary action - Take
        AppButton(
          label: 'Take Medication',
          leadingIcon: Icons.check_rounded,
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
                leadingIcon: Icons.snooze_rounded,
                variant: AppButtonVariant.secondary,
                accent: ext.medicine,
                onPressed: _isLoading ? null : _snoozeMedication,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppButton(
                label: 'Skip',
                leadingIcon: Icons.close_rounded,
                variant: AppButtonVariant.tonal,
                accent: ext.warning,
                onPressed: _isLoading ? null : _skipMedication,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
