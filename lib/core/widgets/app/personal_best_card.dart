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
                // Wrap, not Row.
                //
                // The eyebrow and the "New best" badge are both fixed strings
                // that grow with Dynamic Type, and neither can yield: this Row
                // overflowed by 75px at 320pt even at 1.0x once a new personal
                // best existed. Ellipsizing either one loses a word the user
                // needs, so the badge drops to a second line instead.
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    // AppEyebrow, not a hand-rolled labelSmall: this was one
                    // of the seven copies of the same style, and the one thing
                    // they all got wrong was the colour — textTertiary at 11pt
                    // measures 3.78:1 on a light card and 3.85:1 on a dark
                    // one, below the 4.5:1 AA asks of normal text. The
                    // widget's default (textSecondary) clears both.
                    const AppEyebrow('Personal best'),
                    if (isNew) ...[
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
