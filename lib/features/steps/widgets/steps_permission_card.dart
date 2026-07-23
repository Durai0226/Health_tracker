import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import 'package:tablet_remainder/core/services/health_data_service.dart';

/// Shown when device health data can't be read (unavailable / not-determined /
/// denied). Explains the state and always offers the manual path — logging steps
/// by hand needs no permissions and is the only route on the Simulator.
class StepsPermissionCard extends StatelessWidget {
  final HealthAvailability availability;
  final Future<void> Function() onEnable;
  final VoidCallback onLogManually;

  const StepsPermissionCard({
    super.key,
    required this.availability,
    required this.onEnable,
    required this.onLogManually,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final s = ext.steps;
    final tt = Theme.of(context).textTheme;

    final unavailable = availability == HealthAvailability.unavailable;
    final denied = availability == HealthAvailability.denied;

    final (title, body) = unavailable
        ? (
            'Health data unavailable',
            'This device has no step sensor or health provider. You can still '
                'track everything by logging steps manually.'
          )
        : denied
            ? (
                'Health access is off',
                'Step permission was declined. Turn it on to sync automatically, '
                    'or keep logging steps manually.'
              )
            : (
                'Connect your step data',
                'Allow health access to sync steps, distance and calories '
                    'automatically — or log them manually to start now.'
              );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: s.container,
                  borderRadius: AppRadius.brMd,
                ),
                child: Icon(Symbols.health_and_safety_rounded,
                    size: 22, color: s.onContainer),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(title, style: tt.titleLarge)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            body,
            style: tt.bodyMedium
                ?.copyWith(color: ext.textSecondary, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              if (!unavailable) ...[
                Expanded(
                  child: AppButton(
                    label: denied ? 'Try again' : 'Enable',
                    accent: s,
                    leadingIcon: Symbols.favorite_rounded,
                    onPressed: onEnable,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: AppButton(
                  label: 'Log manually',
                  variant: unavailable
                      ? AppButtonVariant.primary
                      : AppButtonVariant.secondary,
                  accent: s,
                  leadingIcon: Symbols.edit_rounded,
                  onPressed: onLogManually,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
