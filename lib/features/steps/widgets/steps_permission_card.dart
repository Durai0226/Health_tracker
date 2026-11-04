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

  /// Asks for this phone's own step sensor, which needs no health app at all.
  /// Null leaves the offer out.
  final Future<void> Function()? onUseSensor;

  /// Whether the sensor is already allowed: the offer is for when it is not.
  final bool sensorGranted;

  const StepsPermissionCard({
    super.key,
    required this.availability,
    required this.onEnable,
    required this.onLogManually,
    this.onUseSensor,
    this.sensorGranted = true,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final s = ext.steps;
    final tt = Theme.of(context).textTheme;

    final unavailable = availability == HealthAvailability.unavailable;
    final denied = availability == HealthAvailability.denied;
    final needsUpdate = availability == HealthAvailability.needsProviderUpdate;

    // Said as it is: with the sensor on offer below, "no step sensor" would be said
    // directly above the button that counts with it.
    final sensorOffered = onUseSensor != null && !sensorGranted;

    final (title, body) = unavailable
        ? (
            'Health data unavailable',
            sensorOffered
                ? 'This device has no health provider to read steps from, but this '
                    'phone can count them itself with its step sensor — or you can '
                    'log steps manually.'
                : 'This device has no step sensor or health provider. You can still '
                    'track everything by logging steps manually.'
          )
        : needsUpdate
            ? (
                'Health Connect needs an update',
                'Android stores step data in Health Connect. Install or update it '
                    'to sync automatically — or log steps manually to start now.'
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
    final enableLabel = needsUpdate
        ? 'Get Health Connect'
        : (denied ? 'Try again' : 'Enable');

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
                    label: enableLabel,
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
          // The way that needs no health app: this phone counts steps itself, once
          // it is allowed to. Shown only while it is not allowed — and in the
          // "unavailable" state too, where it is the only thing on offer besides
          // typing them in.
          if (sensorOffered) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Count with this phone\'s sensor',
              variant: AppButtonVariant.tonal,
              accent: s,
              leadingIcon: Symbols.directions_walk_rounded,
              fullWidth: true,
              onPressed: onUseSensor,
            ),
          ],
        ],
      ),
    );
  }
}
