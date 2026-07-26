import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/services/premium_service.dart';

/// "DailyMinder Plus" paywall. UI + entitlement scaffold only — real in-app
/// purchases (StoreKit / Play Billing, likely via RevenueCat) are the remaining
/// business step. Until then, "Upgrade" is honestly a coming-soon, and a
/// debug-only "Simulate Plus" toggle lets us build/preview the gated features.
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final accent = ext.brand;
    final active = PremiumService.isActive;

    return AppScaffold(
      safeTop: true,
      body: Column(
        children: [
          AppHeader(
            title: 'DailyMinder Plus',
            accent: accent,
            leading: AppIconButton(
              icon: Symbols.arrow_back_rounded,
              filled: false,
              accent: accent,
              onPressed: () {
                if (Navigator.canPop(context)) Navigator.pop(context);
              },
            ),
            bottom: Container(height: 1, color: ext.outline),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                  AppSpacing.lg, AppSpacing.gutter, AppSpacing.huge),
              children: [
                Row(
                  children: [
                    Icon(Symbols.workspace_premium_rounded,
                        color: ext.mark(accent), size: 30),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                          active
                              ? "You're on Plus ✓"
                              : 'More powerful, still private',
                          style: tt.headlineSmall
                              ?.copyWith(color: ext.textPrimary)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  active
                      ? 'Thanks for supporting DailyMinder. All Plus features are on.'
                      : 'Keep the core reminders free forever. Plus adds depth for '
                          'people managing more.',
                  style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  child: Column(
                    children: [
                      for (final f in PremiumService.features)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.sm),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Symbols.check_circle_rounded,
                                  size: 20, color: ext.mark(ext.success)),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(f.$1,
                                        style: tt.titleSmall?.copyWith(
                                            color: ext.textPrimary,
                                            fontWeight: FontWeight.w700)),
                                    Text(f.$2,
                                        style: tt.bodySmall?.copyWith(
                                            color: ext.textSecondary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (!active) ...[
                  Text('\$3.99 / month · \$29.99 / year',
                      textAlign: TextAlign.center,
                      style: tt.titleMedium?.copyWith(
                          color: ext.textPrimary,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Upgrade to Plus',
                    accent: accent,
                    fullWidth: true,
                    onPressed: () {
                      context.toastInfo(
                          'In-app purchases are coming soon. Thanks for '
                          'your interest!');
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Cancel anytime. Payments will be handled by the app store.',
                      textAlign: TextAlign.center,
                      style: tt.bodySmall?.copyWith(color: ext.textTertiary)),
                ],
                if (kDebugMode) ...[
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: active
                        ? 'Turn off Plus (dev)'
                        : 'Simulate Plus (dev)',
                    variant: AppButtonVariant.ghost,
                    accent: ext.info,
                    fullWidth: true,
                    onPressed: () async {
                      await PremiumService.setActive(!active);
                      if (mounted) setState(() {});
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
