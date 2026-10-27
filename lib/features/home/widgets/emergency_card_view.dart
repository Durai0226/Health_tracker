import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/health/emergency_card.dart';
import '../../../core/widgets/app/app_widgets.dart';

/// The card itself: large plain type, one section at a time, readable at a
/// glance. Opaque all the way out to its edge, so a picture of it stands on its
/// own as a lock-screen image.
class EmergencyCardView extends StatelessWidget {
  const EmergencyCardView({super.key, required this.card});

  final EmergencyCard card;

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final who = [
      if (card.age != null) '${card.age} years',
      if (card.bloodType != null) 'Blood type ${card.bloodType}',
    ].join(' · ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: ext.surface,
        borderRadius: AppRadius.brLg,
        border: Border.all(color: ext.mark(ext.error), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Symbols.medical_information_rounded,
                  size: 22, color: ext.mark(ext.error)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('EMERGENCY CARD',
                    style: tt.labelLarge?.copyWith(
                        color: ext.mark(ext.error),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2)),
              ),
            ],
          ),
          if (card.name != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(card.name!,
                style: tt.headlineSmall?.copyWith(
                    color: ext.textPrimary, fontWeight: FontWeight.w800)),
          ],
          if (who.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(who, style: tt.titleMedium?.copyWith(color: ext.textSecondary)),
          ],
          const SizedBox(height: AppSpacing.lg),
          _Section(
            label: 'Allergies',
            lines: card.allergies.isEmpty ? const [EmergencyCard.notRecorded] : card.allergies,
            recorded: card.allergies.isNotEmpty,
            emphasis: true,
          ),
          _Section(
            label: 'Conditions',
            lines: card.conditions.isEmpty ? const [EmergencyCard.notRecorded] : card.conditions,
            recorded: card.conditions.isNotEmpty,
          ),
          _Section(
            label: 'Medicines',
            lines: card.medicines.isEmpty
                ? const [EmergencyCard.notRecorded]
                : [for (final m in card.medicines) m.line],
            recorded: card.medicines.isNotEmpty,
          ),
          _Section(
            label: 'Emergency contact',
            lines: [card.contact?.line ?? EmergencyCard.notRecorded],
            recorded: card.contact != null,
            last: true,
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.lines,
    required this.recorded,
    this.emphasis = false,
    this.last = false,
  });

  final String label;
  final List<String> lines;

  /// False for "Not recorded": said quietly, so it is not read as an answer.
  final bool recorded;

  /// Allergies lead and are set in the warning colour when there are any.
  final bool emphasis;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: tt.labelMedium?.copyWith(
                  color: ext.textTertiary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
          const SizedBox(height: AppSpacing.xs),
          for (final l in lines)
            Text(l,
                style: tt.titleMedium?.copyWith(
                    color: !recorded
                        ? ext.textTertiary
                        : emphasis
                            ? ext.mark(ext.error)
                            : ext.textPrimary,
                    fontWeight: recorded ? FontWeight.w700 : FontWeight.w400)),
        ],
      ),
    );
  }
}
