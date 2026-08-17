import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/services/health_data_service.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';

/// Shown on the Heart and Workouts screens when wearable data cannot be read.
///
/// Two independent axes, unlike [StepsPermissionCard]'s one:
///
/// * [availability] — the BASE health grant (steps/sleep). Without it there is
///   nothing to ask for yet.
/// * [hasBiometricGrant] — the separate wearable-metrics tier. Health Connect
///   is all-or-nothing per request and throttles re-prompting, so biometrics
///   are asked for here rather than in the first-run sheet. A user can have the
///   base grant and not this one.
///
/// There is deliberately no manual-entry escape hatch: unlike steps or sleep,
/// nobody hand-types a day of heart-rate samples. The honest fallback is "this
/// needs a wearable", so the card says that instead of offering a dead end.
class BiometricsPermissionCard extends StatelessWidget {
  final HealthAvailability availability;
  final bool hasBiometricGrant;
  final Future<void> Function() onEnable;

  const BiometricsPermissionCard({
    super.key,
    required this.availability,
    required this.hasBiometricGrant,
    required this.onEnable,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final accent = ext.medicine;
    final tt = Theme.of(context).textTheme;

    final unavailable = availability == HealthAvailability.unavailable;
    final needsUpdate = availability == HealthAvailability.needsProviderUpdate;
    final denied = availability == HealthAvailability.denied;

    final (title, body, cta) = unavailable
        ? (
            'No health provider on this device',
            'Heart data comes from a watch, ring or band that writes to your '
                'phone\'s health app. This device has none, so there is nothing '
                'to read yet.',
            null,
          )
        : needsUpdate
            ? (
                'Health Connect needs an update',
                'Android stores wearable data in Health Connect. Install or '
                    'update it, then come back.',
                'Get Health Connect',
              )
            : denied
                ? (
                    'Health access is off',
                    'Health permission was declined, so nothing can be read. '
                        'You can turn it back on any time.',
                    'Try again',
                  )
                : !hasBiometricGrant
                    ? (
                        'Connect your wearable',
                        'Allow heart data access to see resting heart rate, '
                            'variability, blood oxygen and breathing rate from '
                            'your watch, ring or band. This is separate from '
                            'steps and sleep, so you are asked once here.',
                        'Allow heart data',
                      )
                    : (
                        'Nothing recorded yet',
                        'Your wearable has not written any heart data to your '
                            'phone\'s health app yet. Wear it overnight and '
                            'check back tomorrow.',
                        null,
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
                  color: accent.container,
                  borderRadius: AppRadius.brMd,
                ),
                child: Icon(Symbols.ecg_heart_rounded,
                    size: 22, color: accent.onContainer),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(title,
                    style: tt.titleMedium?.copyWith(
                        color: ext.textPrimary, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(body,
              style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
          if (cta != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: cta,
              leadingIcon: Symbols.check_circle_rounded,
              accent: accent,
              onPressed: onEnable,
            ),
          ],
        ],
      ),
    );
  }
}
