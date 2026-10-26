import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/health/measurement_plan.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../models/enhanced_medicine.dart';
import '../services/measurement_plan_service.dart';

/// "Check your blood pressure too?" — shown once, right after a new medicine is
/// saved, when that medicine usually comes with a home reading.
///
/// Every reminder starts OFF. Nothing is scheduled until the user taps
/// "Remind me" on a row, and closing the sheet any other way counts as "not
/// now" for what was left, so the same offer isn't repeated for the next pill.
class MeasurementPlanSheet {
  const MeasurementPlanSheet._();

  /// Shows the offer for [medicine] if it has one. Completes when the sheet is
  /// closed, or immediately when there is nothing to offer.
  static Future<void> maybeShow(
      BuildContext context, EnhancedMedicine medicine) async {
    final offers = await MeasurementPlanService.offerFor(medicine);
    if (offers.isEmpty || !context.mounted) return;

    final accepted = <MeasurementKind>{};
    await AppBottomSheet.show<void>(
      context,
      title: 'Track what ${medicine.name} affects?',
      icon: Symbols.monitor_heart_rounded,
      accent: AppColorsExt.of(context).medicine,
      builder: (ctx) => MeasurementPlanBody(
        offers: offers,
        onAccept: (s) async {
          await MeasurementPlanService.accept(s);
          accepted.add(s.kind);
        },
        onDone: () => Navigator.of(ctx).pop(),
      ),
    );

    // Whatever was not switched on is a "not now", however the sheet closed.
    await MeasurementPlanService.decline(
        offers.map((o) => o.kind).where((k) => !accepted.contains(k)));
  }
}

/// The sheet's content, separate so a test can drive it without the flow.
class MeasurementPlanBody extends StatefulWidget {
  const MeasurementPlanBody({
    super.key,
    required this.offers,
    required this.onAccept,
    required this.onDone,
  });

  final List<MeasurementSuggestion> offers;
  final Future<void> Function(MeasurementSuggestion) onAccept;
  final VoidCallback onDone;

  @override
  State<MeasurementPlanBody> createState() => _MeasurementPlanBodyState();
}

class _MeasurementPlanBodyState extends State<MeasurementPlanBody> {
  final Set<MeasurementKind> _on = {};
  MeasurementKind? _busy;

  Future<void> _accept(MeasurementSuggestion s) async {
    if (_busy != null) return;
    setState(() => _busy = s.kind);
    try {
      await widget.onAccept(s);
      if (mounted) setState(() => _on.add(s.kind));
    } catch (_) {
      // Left off, and the button stays tappable: a failed schedule must not
      // read as "On".
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  IconData _icon(MeasurementKind k) => switch (k) {
        MeasurementKind.bloodPressure => Symbols.favorite_rounded,
        MeasurementKind.bloodGlucose => Symbols.bloodtype_rounded,
        MeasurementKind.weight => Symbols.monitor_weight_rounded,
      };

  String _times(BuildContext context, MeasurementSuggestion s) => s.slots
      .map((t) => TimeOfDay(hour: t.hour, minute: t.minute).format(context))
      .join(' and ');

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('A daily reminder to take and log the reading. Optional, and '
            'you can change it any time in Vitals reminders.',
            style: tt.bodySmall?.copyWith(color: ext.textSecondary, height: 1.35)),
        const SizedBox(height: AppSpacing.md),
        for (final o in widget.offers) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: ext.medicine.container, borderRadius: AppRadius.brSm),
                child: Icon(_icon(o.kind),
                    size: 18, color: ext.medicine.onContainer),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.title,
                        style: tt.titleSmall?.copyWith(
                            color: ext.textPrimary, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(o.reason,
                        style: tt.bodySmall?.copyWith(
                            color: ext.textSecondary, height: 1.35)),
                    const SizedBox(height: 2),
                    Text(_times(context, o),
                        style: tt.bodySmall?.copyWith(color: ext.textTertiary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: _on.contains(o.kind)
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Symbols.check_circle_rounded,
                        size: 18, color: ext.success.onContainer),
                    const SizedBox(width: 6),
                    Text('Reminders on',
                        style: tt.labelLarge?.copyWith(color: ext.textPrimary)),
                  ])
                : AppButton(
                    label: 'Remind me',
                    size: AppButtonSize.sm,
                    variant: AppButtonVariant.tonal,
                    loading: _busy == o.kind,
                    onPressed: _busy == null ? () => _accept(o) : null,
                  ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        AppButton(
          label: _on.length == widget.offers.length ? 'Done' : 'Not now',
          variant: AppButtonVariant.ghost,
          fullWidth: true,
          onPressed: widget.onDone,
        ),
      ],
    );
  }
}
