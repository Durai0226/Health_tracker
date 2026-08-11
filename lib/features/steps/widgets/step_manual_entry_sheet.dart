import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';

/// Bottom sheet to add or adjust steps by hand — the zero-permission path that
/// always works (Simulator included).
///
/// Composition: one recessed "value well" (surfaceVariant, brCard) makes the
/// tabular numeral the hero — tap it to type an exact figure, or use the two
/// floating ±500 steppers (hold to accelerate). A centered chip Wrap carries the
/// 90%-path presets, the note is progressively disclosed, and the single
/// emphasized CTA echoes the value. Calls [onSubmit] with the (signed) delta.
class StepManualEntrySheet extends StatefulWidget {
  final Future<void> Function(int steps, String? note, DateTime date) onSubmit;

  /// Allow choosing a recent past day (backfill) — the phone-on-the-charger day.
  final bool allowBackdate;

  const StepManualEntrySheet({
    super.key,
    required this.onSubmit,
    this.allowBackdate = true,
  });

  static Future<void> show(
    BuildContext context, {
    required Future<void> Function(int steps, String? note, DateTime date)
        onSubmit,
    bool allowBackdate = true,
  }) {
    return AppBottomSheet.show<void>(
      context,
      title: 'Add steps',
      icon: Symbols.directions_walk_rounded,
      accent: AppColorsExt.of(context).steps,
      builder: (_) =>
          StepManualEntrySheet(onSubmit: onSubmit, allowBackdate: allowBackdate),
    );
  }

  @override
  State<StepManualEntrySheet> createState() => _StepManualEntrySheetState();
}

class _StepManualEntrySheetState extends State<StepManualEntrySheet> {
  int _amount = 1000;
  final _noteController = TextEditingController();
  bool _saving = false;
  bool _noteOpen = false;
  Timer? _repeat;

  /// The day the steps apply to (day-only). Defaults to today.
  late DateTime _date;

  static const _presets = [250, 500, 1000, 2500, 5000];
  static const _maxDaysBack = 7;

  /// Magnitude ceiling for one entry, in either direction.
  static const _maxSteps = 50000;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    // Defensive: if a note is already present, open the field so it is visible.
    _noteOpen = _noteController.text.trim().isNotEmpty;
  }

  @override
  void dispose() {
    _repeat?.cancel();
    _noteController.dispose();
    super.dispose();
  }

  // ── Value math (wiring preserved) ─────────────────────────────────────────
  void _bump(int delta) {
    HapticFeedback.selectionClick();
    setState(() => _amount = (_amount + delta).clamp(-_maxSteps, _maxSteps));
  }

  /// Silent apply used by the long-press repeater (haptic on start only, so a
  /// held stepper does not machine-gun the taptic engine).
  void _applyDelta(int delta) {
    setState(() => _amount = (_amount + delta).clamp(-_maxSteps, _maxSteps));
  }

  void _startRepeat(int delta) {
    _repeat?.cancel();
    _bump(delta); // first tick carries the haptic
    final sw = Stopwatch()..start();
    _repeat = Timer.periodic(const Duration(milliseconds: 90), (_) {
      // Accelerate: double the magnitude after ~1s of holding.
      _applyDelta(sw.elapsedMilliseconds > 1000 ? delta * 2 : delta);
    });
  }

  void _stopRepeat() {
    _repeat?.cancel();
    _repeat = null;
  }

  /// Tap-to-edit: type an exact figure that writes back to the same [_amount]
  /// source of truth, so presets / CTA / disable logic keep working unchanged.
  ///
  /// This is a MAGNITUDE editor — it is seeded with `_amount.abs()` and a typed
  /// figure is always a positive step count. Subtracting stays on the minus
  /// stepper, which is the only signed control the sheet advertises.
  Future<void> _openEditor() async {
    final ext = AppColorsExt.of(context);
    final s = ext.steps;
    final tt = Theme.of(context).textTheme;
    final controller = TextEditingController(text: _amount.abs().toString());

    final result = await showDialog<int>(
      context: context,
      builder: (dialogCtx) {
        // Bare `int.tryParse` accepted '0' and '-5': '0' popped the dialog onto
        // a permanently disabled CTA with no explanation, and a negative
        // silently flipped the whole sheet into subtract mode with a figure the
        // user never chose. An out-of-range value is now refused in place
        // instead of being quietly clamped to a different number.
        String? error;
        return StatefulBuilder(
          builder: (_, setDialogState) {
            void submit() {
              final value = int.tryParse(controller.text.trim());
              final message = value == null
                  ? 'Enter a number of steps'
                  : value <= 0
                      ? 'Enter a number greater than 0'
                      : value > _maxSteps
                          ? 'Enter ${_formatUnsigned(_maxSteps)} or less'
                          : null;
              if (message != null) {
                setDialogState(() => error = message);
                return;
              }
              Navigator.of(dialogCtx).pop(value);
            }

            return AlertDialog(
              backgroundColor: ext.surfaceElevated,
              shape:
                  const RoundedRectangleBorder(borderRadius: AppRadius.brCard),
              title: Text('Enter steps', style: tt.titleLarge),
              content: AppTextField(
                controller: controller,
                accent: s,
                // WCAG 3.3.2 — the field was hint-only, so its one piece of
                // identification vanished as soon as a digit was typed.
                label: 'Steps',
                hint: 'e.g. 3000',
                errorText: error,
                keyboardType: TextInputType.number,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onChanged: error == null
                    ? null
                    : (_) => setDialogState(() => error = null),
                onSubmitted: (_) => submit(),
              ),
              actions: [
                AppButton(
                  label: 'Cancel',
                  variant: AppButtonVariant.ghost,
                  accent: s,
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                ),
                AppButton(label: 'Set', accent: s, onPressed: submit),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    if (result != null) {
      HapticFeedback.selectionClick();
      // Validated to 1.._maxSteps above; the clamp is belt-and-braces.
      setState(() => _amount = result.clamp(-_maxSteps, _maxSteps));
    }
  }

  Future<void> _submit() async {
    // A negative _amount is deliberate here (a correction for steps the sensor
    // over-counted) — see _ctaLabel's "Adjust steps" and
    // StepService.addManualStepsForDate, which stores it as a signed entry.
    // Zero is the only meaningless value, and it is also gated on the CTA.
    if (_amount == 0 || _saving) return;
    setState(() => _saving = true);
    final note = _noteController.text.trim();
    await widget.onSubmit(_amount, note.isEmpty ? null : note, _date);
    if (mounted) Navigator.of(context).pop();
  }

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _pickEarlier() async {
    final today = _today;
    final picked = await AppDatePicker.show(
      context,
      initial: _date.isBefore(today.subtract(const Duration(days: 1)))
          ? _date
          : today.subtract(const Duration(days: 2)),
      first: today.subtract(const Duration(days: _maxDaysBack)),
      last: today,
    );
    if (picked != null) {
      HapticFeedback.selectionClick();
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  /// Short label for the "Earlier" chip, e.g. "Mon 21".
  String _earlierLabel() {
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final isEarlier = _today.difference(_date).inDays >= 2;
    if (!isEarlier) return 'Earlier';
    return '${wd[(_date.weekday - 1) % 7]} ${_date.day}';
  }

  // ── Display helpers (no new dependency) ───────────────────────────────────
  String _formatUnsigned(int value) {
    final digits = value.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  String _formatSigned(int value) {
    if (value > 0) return '+${_formatUnsigned(value)}';
    if (value < 0) return '-${_formatUnsigned(value)}';
    return '0';
  }

  /// K-notation keeps the preset chips a uniform, scannable width.
  String _presetLabel(int p) {
    switch (p) {
      case 1000:
        return '+1K';
      case 2500:
        return '+2.5K';
      case 5000:
        return '+5K';
      default:
        return '+${_formatUnsigned(p)}';
    }
  }

  String get _ctaLabel =>
      _amount < 0 ? 'Adjust steps' : 'Add ${_formatUnsigned(_amount)} steps';

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final s = ext.steps;
    final tt = Theme.of(context).textTheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final today = _today;
    final isToday = _isSameDay(_date, today);
    final isYesterday =
        _isSameDay(_date, today.subtract(const Duration(days: 1)));
    final isEarlier = !isToday && !isYesterday;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 0. DAY — backfill a recent day (default today) ──────────────────
        if (widget.allowBackdate) ...[
          Text('Day', style: tt.labelLarge?.copyWith(color: ext.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppChip(
                label: 'Today',
                accent: s,
                selected: isToday,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _date = today);
                },
              ),
              AppChip(
                label: 'Yesterday',
                accent: s,
                selected: isYesterday,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() =>
                      _date = today.subtract(const Duration(days: 1)));
                },
              ),
              AppChip(
                label: _earlierLabel(),
                icon: Symbols.event_rounded,
                accent: s,
                selected: isEarlier,
                onTap: _pickEarlier,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        // ── 1. VALUE WELL — the ±/numeral read as one premium instrument ────
        Container(
          decoration: BoxDecoration(
            color: ext.surfaceVariant,
            borderRadius: AppRadius.brCard,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.lg,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _stepper(
                icon: Symbols.remove_rounded,
                delta: -500,
                accent: s,
                tooltip: 'Hold to subtract faster',
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Tap the hero numeral → inline numeric entry.
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _openEditor,
                      child: Text(
                        _formatSigned(_amount),
                        textAlign: TextAlign.center,
                        style: tt.displayMedium?.copyWith(
                          color:
                              _amount < 0 ? ext.error.strong : ext.mark(s),
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'steps',
                      style: tt.bodySmall?.copyWith(
                        color: ext.textSecondary,
                        letterSpacing: 0.4,
                      ),
                    ),
                    // TODO: when a daily goal is plumbed into this sheet, add a
                    // quiet ext.textTertiary subline here (e.g. "adds to 8,240
                    // today"). Omitted now — do not invent state.
                  ],
                ),
              ),
              _stepper(
                icon: Symbols.add_rounded,
                delta: 500,
                accent: s,
                tooltip: 'Hold to add faster',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ── 2. QUICK ADD presets — the 90% path, right under the value ──────
        Text(
          'Quick add',
          style: tt.labelLarge?.copyWith(color: ext.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          alignment: WrapAlignment.center,
          children: [
            for (final p in _presets)
              AppChip(
                label: _presetLabel(p),
                accent: s,
                selected: _amount == p,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _amount = p);
                },
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        // ── 3. NOTE — progressively disclosed so the default sheet is short ─
        AnimatedSize(
          duration: reduceMotion ? Duration.zero : AppMotion.base,
          curve: AppMotion.emphasized,
          alignment: Alignment.topLeft,
          child: _noteOpen
              ? AppTextField(
                  controller: _noteController,
                  label: 'Note (optional)',
                  hint: 'e.g. Morning walk',
                  accent: s,
                  prefixIcon: Symbols.edit_note_rounded,
                  textCapitalization: TextCapitalization.sentences,
                  autofocus: true,
                )
              : Align(
                  alignment: Alignment.centerLeft,
                  child: AppButton(
                    label: 'Add note',
                    variant: AppButtonVariant.ghost,
                    accent: s,
                    leadingIcon: Symbols.edit_note_rounded,
                    onPressed: () => setState(() => _noteOpen = true),
                  ),
                ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // ── 4. CTA — emphasized, value-echoing, AA-safe via fillBg gate ─────
        AppButton(
          label: _ctaLabel,
          accent: s,
          emphasized: true,
          fullWidth: true,
          loading: _saving,
          leadingIcon: Symbols.check_rounded,
          onPressed: _amount == 0 ? null : _submit,
        ),
      ],
    );
  }

  /// A ±500 stepper: the kit's floating [AppIconButton] (single-tap) wrapped in
  /// a long-press repeater. We wrap rather than fork so the circle keeps its
  /// resting shadow, accent tint and 44px target.
  Widget _stepper({
    required IconData icon,
    required int delta,
    required AccentSwatch accent,
    required String tooltip,
  }) {
    return GestureDetector(
      onLongPressStart: (_) => _startRepeat(delta),
      onLongPressEnd: (_) => _stopRepeat(),
      onLongPressCancel: _stopRepeat,
      child: AppIconButton(
        icon: icon,
        accent: accent,
        tooltip: tooltip,
        onPressed: () => _bump(delta),
      ),
    );
  }
}
