import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';

/// Shown when the device health store can't be read (Simulator, unsupported
/// platform, or not-yet-granted). Explains the state honestly and always offers
/// the manual path — the feature is fully usable without any health permission.
class SleepPermissionCard extends StatelessWidget {
  /// Opens the manual-log sheet.
  final VoidCallback onLogManually;

  /// Requests health permissions. Null when connecting isn't possible
  /// (Simulator / unsupported platform) — then only the manual CTA shows.
  final VoidCallback? onConnect;

  const SleepPermissionCard({
    super.key,
    required this.onLogManually,
    this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final sleep = ext.sleep;
    final store = Platform.isIOS ? 'Apple Health' : 'Health Connect';

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
              Expanded(
                child: Text(
                  onConnect != null
                      ? 'Connect $store'
                      : 'Track your sleep',
                  style: tt.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            onConnect != null
                ? 'Import measured sleep stages from $store, or log your nights by hand — either works.'
                : 'Automatic sleep sync isn\'t available here. Log your nights by hand to see your score, stages and trends.',
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
                    label: 'Connect',
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
