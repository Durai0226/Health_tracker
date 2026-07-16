import 'package:flutter/material.dart';
import '../theme/nunito_theme.dart';
import '../widgets/nunito_glass_card.dart';
import '../widgets/nunito_pill_visual.dart';
import '../models/enhanced_medicine.dart';
import '../models/medicine_log.dart';
import '../models/medicine_enums.dart';
import '../services/medicine_storage_service.dart';
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

class _NunitoTakeMedicationSheetState extends State<NunitoTakeMedicationSheet>
    with SingleTickerProviderStateMixin {
  int _selectedMood = -1;
  String? _sideEffects;
  String? _notes;
  bool _isLoading = false;

  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  final HapticService _hapticService = HapticService();
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
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
        sideEffects: _sideEffects,
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
    
    setState(() => _isLoading = false);
  }

  Future<void> _skipMedication() async {
    _hapticService.medicineSkipped();
    
    final reason = await _showSkipReasonDialog();
    if (reason == null) return;

    setState(() => _isLoading = true);

    try {
      final log = MedicineLog(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        medicineId: widget.medicine.id,
        scheduledTime: widget.scheduledTime,
        actionTime: DateTime.now(),
        status: MedicineStatus.skipped,
        skipReason: SkipReason.values[reason],
        skipNote: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      await MedicineCleanStorageService.addLog(log);
      
      if (mounted) {
        Navigator.pop(context, {'skipped': true, 'log': log});
      }
    } catch (e) {
      debugPrint('Error skipping medication: $e');
    }
    
    setState(() => _isLoading = false);
  }

  Future<int?> _showSkipReasonDialog() async {
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NunitoTheme.radiusMedium),
        ),
        title: Text('Why are you skipping?', style: NunitoTheme.heading3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSkipReasonOption(0, 'Side effects'),
            _buildSkipReasonOption(1, 'Forgot to take'),
            _buildSkipReasonOption(2, 'Ran out'),
            _buildSkipReasonOption(3, 'Feeling better'),
            _buildSkipReasonOption(4, 'Doctor advised'),
            _buildSkipReasonOption(5, 'Other'),
          ],
        ),
      ),
    );
  }

  Widget _buildSkipReasonOption(int index, String label) {
    return ListTile(
      title: Text(label),
      onTap: () => Navigator.pop(context, index),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NunitoTheme.radiusSmall),
      ),
    );
  }

  void _snoozeMedication() {
    _hapticService.light();
    Navigator.pop(context, {'snoozed': true, 'minutes': 10});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        margin: EdgeInsets.only(bottom: bottomPadding),
        decoration: BoxDecoration(
          color: isDark ? NunitoTheme.cardDark : Colors.white,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(NunitoTheme.radiusLarge),
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(NunitoTheme.spacingL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHandle(),
                const SizedBox(height: NunitoTheme.spacingL),
                _buildMedicineInfo(isDark),
                const SizedBox(height: NunitoTheme.spacingL),
                _buildMoodSelector(isDark),
                const SizedBox(height: NunitoTheme.spacingM),
                _buildNotesField(isDark),
                const SizedBox(height: NunitoTheme.spacingL),
                _buildActionButtons(isDark),
                const SizedBox(height: NunitoTheme.spacingM),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: NunitoTheme.textTertiary.withOpacity(0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildMedicineInfo(bool isDark) {
    return Row(
      children: [
        NunitoPillVisual(
          color: widget.medicine.color,
          shape: widget.medicine.shape,
          size: 64,
        ),
        const SizedBox(width: NunitoTheme.spacingM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.medicine.name,
                style: NunitoTheme.heading2.copyWith(
                  color: isDark ? Colors.white : NunitoTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.medicine.displayDosage,
                style: NunitoTheme.bodyMedium.copyWith(
                  color: NunitoTheme.textSecondary,
                ),
              ),
              if (widget.medicine.instructions != null) ...[
                const SizedBox(height: 4),
                Text(
                  widget.medicine.instructions!,
                  style: NunitoTheme.bodySmall.copyWith(
                    color: NunitoTheme.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMoodSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How are you feeling?',
          style: NunitoTheme.labelLarge.copyWith(
            color: isDark ? Colors.white70 : NunitoTheme.textSecondary,
          ),
        ),
        const SizedBox(height: NunitoTheme.spacingS),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(5, (index) {
            final isSelected = _selectedMood == index;
            return GestureDetector(
              onTap: () {
                _hapticService.selection();
                setState(() => _selectedMood = index);
              },
              child: AnimatedContainer(
                duration: NunitoTheme.animationFast,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? NunitoTheme.moodColors[index].withOpacity(0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? NunitoTheme.moodColors[index]
                        : NunitoTheme.textTertiary.withOpacity(0.2),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      NunitoTheme.moodEmojis[index],
                      style: const TextStyle(fontSize: 28),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      NunitoTheme.moodLabels[index],
                      style: NunitoTheme.caption.copyWith(
                        color: isSelected
                            ? NunitoTheme.moodColors[index]
                            : NunitoTheme.textTertiary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildNotesField(bool isDark) {
    return TextField(
      controller: _notesController,
      maxLines: 2,
      style: NunitoTheme.bodyMedium.copyWith(
        color: isDark ? Colors.white : NunitoTheme.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: 'Add notes (optional)',
        hintStyle: NunitoTheme.bodyMedium.copyWith(
          color: NunitoTheme.textTertiary,
        ),
        filled: true,
        fillColor: isDark
            ? NunitoTheme.surfaceDark
            : NunitoTheme.backgroundLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NunitoTheme.radiusMedium),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.all(NunitoTheme.spacingM),
      ),
    );
  }

  Widget _buildActionButtons(bool isDark) {
    return Column(
      children: [
        // Primary action - Take
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _takeMedication,
            style: ElevatedButton.styleFrom(
              backgroundColor: NunitoTheme.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(NunitoTheme.radiusMedium),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_rounded, size: 24),
                      const SizedBox(width: 8),
                      Text('Take Medication', style: NunitoTheme.labelLarge.copyWith(color: Colors.white)),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: NunitoTheme.spacingS),
        // Secondary actions
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading ? null : _snoozeMedication,
                style: OutlinedButton.styleFrom(
                  foregroundColor: NunitoTheme.primary,
                  side: BorderSide(color: NunitoTheme.primary.withOpacity(0.3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(NunitoTheme.radiusMedium),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.snooze_rounded, size: 20, color: NunitoTheme.primary),
                    const SizedBox(width: 6),
                    Text('Snooze', style: NunitoTheme.labelMedium.copyWith(color: NunitoTheme.primary)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: NunitoTheme.spacingS),
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading ? null : _skipMedication,
                style: OutlinedButton.styleFrom(
                  foregroundColor: NunitoTheme.warning,
                  side: BorderSide(color: NunitoTheme.warning.withOpacity(0.3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(NunitoTheme.radiusMedium),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.close_rounded, size: 20, color: NunitoTheme.warning),
                    const SizedBox(width: 6),
                    Text('Skip', style: NunitoTheme.labelMedium.copyWith(color: NunitoTheme.warning)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
