import 'package:flutter/material.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';

/// A calm, self-referential "personal best" record — a mastery cue that
/// compares you only to your own past, never to anyone else. When [isNew] the
/// day the record falls, it wears a quiet "New best" chip (in-app, never a push).
class PersonalBestCard extends StatelessWidget {
  final IconData icon;

  /// Pre-formatted headline, e.g. "12,430 steps" or "Score 92".
  final String value;

  /// Pre-formatted context line, e.g. "Best day · Jul 2".
  final String sublabel;

  final bool isNew;
  final AccentSwatch accent;

  const PersonalBestCard({
    super.key,
    required this.icon,
    required this.value,
    required this.sublabel,
    required this.accent,
    this.isNew = false,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return AppCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.container,
              borderRadius: AppRadius.brMd,
            ),
            child: Icon(icon, size: 20, color: accent.onContainer),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'PERSONAL BEST',
                      style: tt.labelSmall?.copyWith(
                          color: ext.textTertiary, letterSpacing: 0.6),
                    ),
                    if (isNew) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: ext.success.container,
                          borderRadius: AppRadius.brFull,
                        ),
                        child: Text(
                          'New best',
                          style: tt.labelSmall?.copyWith(
                            color: ext.success.onContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  sublabel,
                  style: tt.bodySmall?.copyWith(color: ext.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
