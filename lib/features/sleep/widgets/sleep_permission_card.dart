import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import 'package:tablet_remainder/core/services/health_data_service.dart';

/// Shown when the device health store can't be read (Simulator, unsupported
/// platform, not-yet-granted, or refused). Explains the state honestly and
/// always offers the manual path — the feature is fully usable without any
/// health permission.
class SleepPermissionCard extends StatelessWidget {
  /// Opens the manual-log sheet.
  final VoidCallback onLogManually;

  /// Requests health permissions. Null when connecting isn't possible
  /// (Simulator / unsupported platform) — then only the manual CTA shows.
  final VoidCallback? onConnect;

  /// Drives the copy + CTA label so "declined" and "never asked" don't look
  /// identical (previously both read "Connect", which is why re-granting in the
  /// system settings appeared to do nothing).
  final HealthAvailability availability;

  const SleepPermissionCard({
    super.key,
    required this.onLogManually,
    this.onConnect,
    this.availability = HealthAvailability.notDetermined,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final sleep = ext.sleep;
    final store = Platform.isIOS ? 'Apple Health' : 'Health Connect';
    final denied = availability == HealthAvailability.denied;
    final needsUpdate = availability == HealthAvailability.needsProviderUpdate;

    final title = onConnect == null
        ? 'Track your sleep'
        : needsUpdate
            ? '$store needs an update'
            : denied
                ? '$store access is off'
                : 'Connect $store';

    final body = onConnect == null
        ? "Automatic sleep sync isn't available here. Log your nights by hand to "
            'see your score, stages and trends.'
        : needsUpdate
            ? 'Android keeps sleep data in $store. Install or update it to import '
                'your nights — or keep logging them by hand.'
            : denied
                ? 'Sleep permission was declined. Turn it on to import measured '
                    'stages, or keep logging nights by hand.'
                : 'Import measured sleep stages from $store, or log your nights by '
                    'hand — either works.';

    final connectLabel = needsUpdate
        ? 'Get $store'
        : denied
            ? 'Try again'
            : 'Connect';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: sleep.container,
                  borderRadius: AppRadius.brMd,
                ),
                child: Icon(Symbols.nights_stay_rounded,
                    size: 22, color: sleep.onContainer),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: tt.titleLarge)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            body,
            style: tt.bodyMedium?.copyWith(color: ext.textSecondary, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Log manually',
                  leadingIcon: Symbols.edit_rounded,
                  variant: onConnect != null
                      ? AppButtonVariant.secondary
                      : AppButtonVariant.primary,
                  accent: sleep,
                  onPressed: onLogManually,
                ),
              ),
              if (onConnect != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: connectLabel,
                    leadingIcon: Symbols.link_rounded,
                    accent: sleep,
                    onPressed: onConnect,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
