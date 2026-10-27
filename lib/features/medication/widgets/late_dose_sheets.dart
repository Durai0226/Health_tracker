import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/utils/date_formats.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/widgets/app/segmented_toggle.dart';
import '../services/late_dose_recovery.dart';
import 'tell_contact_button.dart';

/// Sheet for one dose the app wrote down as missed: it was perhaps taken on
/// time and never tapped, perhaps taken late, perhaps forgotten.
class LateDoseSheet {
  const LateDoseSheet._();

  /// Resolves the person's choice, or null when they leave it as missed.
  static Future<LateChoice?> show(BuildContext context, MissedDose dose) {
    return AppBottomSheet.show<LateChoice>(
      context,
      title: 'Missed dose',
      icon: Symbols.pill_rounded,
      accent: AppColorsExt.of(context).medicine,
      builder: (ctx) => LateDoseForm(
        dose: dose,
        onChoice: (c) => Navigator.of(ctx).pop(c),
      ),
    );
  }
}

/// The sheet's content, separate so a test can drive it without a route.
class LateDoseForm extends StatefulWidget {
  const LateDoseForm({super.key, required this.dose, required this.onChoice});

  final MissedDose dose;
  final ValueChanged<LateChoice?> onChoice;

  @override
  State<LateDoseForm> createState() => _LateDoseFormState();
}

class _LateDoseFormState extends State<LateDoseForm> {
  bool _futureTime = false;

  Future<void> _pickTime() async {
    final slot = widget.dose.scheduledTime;
    final picked = await AppTimePicker.show(
      context,
      initial: TimeOfDay(hour: slot.hour, minute: slot.minute),
      accent: AppColorsExt.of(context).medicine,
      title: 'Taken at',
    );
    if (picked == null) return;
    final at = LateDoseRecovery.takenAtFor(
        scheduled: slot, hour: picked.hour, minute: picked.minute);
    if (at == null) {
      setState(() => _futureTime = true);
      return;
    }
    widget.onChoice(LateChoice(LateOutcome.tookAt, at: at));
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final slot = widget.dose.scheduledTime;
    final when = '${DateFormats.dayLabel(slot)} · ${DateFormats.time.format(slot)}';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.dose.medicine.name,
            style: tt.titleLarge?.copyWith(color: ext.textPrimary)),
        const SizedBox(height: 2),
        Text('Due $when',
            style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Take now',
          fullWidth: true,
          accent: ext.medicine,
          onPressed: () => widget.onChoice(const LateChoice(LateOutcome.takeNow)),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Took it at ${DateFormats.time.format(slot)}',
          variant: AppButtonVariant.tonal,
          fullWidth: true,
          accent: ext.medicine,
          onPressed: () =>
              widget.onChoice(const LateChoice(LateOutcome.tookOnTime)),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Took it at another time…',
          variant: AppButtonVariant.tonal,
          fullWidth: true,
          accent: ext.medicine,
          onPressed: _pickTime,
        ),
        if (_futureTime) ...[
          const SizedBox(height: AppSpacing.xs),
          Text("That time hasn't happened yet.",
              style: tt.bodySmall?.copyWith(color: ext.error.strong)),
        ],
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Skip it',
          variant: AppButtonVariant.ghost,
          fullWidth: true,
          accent: ext.medicine,
          onPressed: () => widget.onChoice(const LateChoice(LateOutcome.skipped)),
        ),
        // Only when the person has asked for it, and only to open a message.
        const TellContactButton(),
      ],
    );
  }
}

/// "Yesterday: N doses weren't logged." — the next-morning way in.
class YesterdayTidyBanner extends StatelessWidget {
  const YesterdayTidyBanner({
    super.key,
    required this.count,
    required this.onTidy,
    required this.onDismiss,
  });

  final int count;
  final VoidCallback onTidy;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return AppCard(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, 0),
      color: ext.warning.container,
      onTap: onTidy,
      child: Row(
        children: [
          Icon(Symbols.fact_check_rounded,
              color: ext.warning.onContainer, size: 24),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count == 1
                      ? "1 dose from yesterday wasn't logged"
                      : "$count doses from yesterday weren't logged",
                  style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: ext.warning.onContainer),
                ),
                const SizedBox(height: 2),
                Text('Tell us which you took, so your record is right.',
                    style: tt.bodySmall?.copyWith(
                        color: ext.warning.onContainer.withValues(alpha: 0.85))),
              ],
            ),
          ),
          // Not `close_rounded`: the pillbox view reserves that glyph for its
          // skipped-pill overlay and a test counts it.
          AppIconButton(
            icon: Symbols.snooze_rounded,
            filled: false,
            tooltip: 'Not now',
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

/// Sheet listing yesterday's unlogged doses, each defaulting to "Missed" (no
/// change). Nothing is written until Save.
class YesterdayTidySheet {
  const YesterdayTidySheet._();

  /// Resolves the doses the person changed, keyed by log id.
  static Future<Map<String, TidyChoice>?> show(
      BuildContext context, List<MissedDose> doses) {
    return AppBottomSheet.show<Map<String, TidyChoice>>(
      context,
      title: 'Yesterday',
      icon: Symbols.fact_check_rounded,
      accent: AppColorsExt.of(context).medicine,
      builder: (ctx) => YesterdayTidyForm(
        doses: doses,
        onSave: (m) => Navigator.of(ctx).pop(m),
      ),
    );
  }
}

class YesterdayTidyForm extends StatefulWidget {
  const YesterdayTidyForm({super.key, required this.doses, required this.onSave});

  final List<MissedDose> doses;
  final ValueChanged<Map<String, TidyChoice>> onSave;

  @override
  State<YesterdayTidyForm> createState() => _YesterdayTidyFormState();
}

class _YesterdayTidyFormState extends State<YesterdayTidyForm> {
  late final Map<String, TidyChoice> _choice = {
    for (final d in widget.doses) d.log.id: TidyChoice.missed,
  };

  bool get _changed => _choice.values.any((c) => c != TidyChoice.missed);

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final allTaken = _choice.values.every((c) => c == TidyChoice.taken);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '"Took it" records the dose at its scheduled time. Anything you leave '
          'as Missed still counts against your adherence.',
          style: tt.bodyMedium?.copyWith(color: ext.textSecondary, height: 1.4),
        ),
        const SizedBox(height: AppSpacing.md),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final d in widget.doses) ...[
                  Text(
                    '${d.medicine.name} · ${DateFormats.time.format(d.scheduledTime)}',
                    style: tt.titleSmall?.copyWith(
                        color: ext.textPrimary, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SegmentedToggle(
                    accent: ext.medicine,
                    items: const [
                      SegmentItem(label: 'Took it'),
                      SegmentItem(label: 'Skipped'),
                      SegmentItem(label: 'Missed'),
                    ],
                    index: _choice[d.log.id]!.index,
                    onChanged: (i) =>
                        setState(() => _choice[d.log.id] = TidyChoice.values[i]),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
          ),
        ),
        if (widget.doses.length > 1 && !allTaken)
          AppButton(
            label: 'I took all of them',
            variant: AppButtonVariant.tonal,
            fullWidth: true,
            accent: ext.medicine,
            onPressed: () => setState(() {
              for (final k in _choice.keys.toList()) {
                _choice[k] = TidyChoice.taken;
              }
            }),
          ),
        if (widget.doses.length > 1 && !allTaken)
          const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Save',
          fullWidth: true,
          accent: ext.medicine,
          onPressed: _changed
              ? () => widget.onSave({
                    for (final e in _choice.entries)
                      if (e.value != TidyChoice.missed) e.key: e.value,
                  })
              : null,
        ),
      ],
    );
  }
}
