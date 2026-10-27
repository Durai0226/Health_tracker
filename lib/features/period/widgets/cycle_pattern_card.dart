import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/widgets/app/app_widgets.dart';
import '../services/cycle_pattern.dart';

/// "Your last 6 cycles varied by 12 days" with what that does and does not mean,
/// and a one-page summary to take to a check-up.
class CyclePatternCard extends StatelessWidget {
  const CyclePatternCard(
      {super.key, required this.pattern, required this.onShare});

  final CyclePattern pattern;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: ext.period.container, borderRadius: AppRadius.brSm),
                child: Icon(Symbols.timeline_rounded,
                    size: 16, color: ext.period.onContainer),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(pattern.headline,
                    style: tt.titleSmall?.copyWith(
                        color: ext.textPrimary, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(pattern.detail,
              style:
                  tt.bodyMedium?.copyWith(color: ext.textSecondary, height: 1.4)),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Share summary (PDF)',
            leadingIcon: Symbols.ios_share_rounded,
            variant: AppButtonVariant.tonal,
            accent: ext.period,
            fullWidth: true,
            onPressed: onShare,
          ),
        ],
      ),
    );
  }
}
