import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/health/mood_tags.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/widgets/app/vitals_theme.dart';
import '../models/medicine_log.dart' show moodRatingLabels;

/// The mood and tag pickers shared by the Mood log and the Diary editor: the
/// same five faces and the same chips, so a feeling is entered one way
/// everywhere.

/// A glyph for each tag id. Unknown ids (from a later version) get a plain tag.
IconData moodTagIcon(String id) {
  switch (id) {
    case 'walk':
      return Symbols.directions_walk_rounded;
    case 'exercise':
      return Symbols.fitness_center_rounded;
    case 'friends':
      return Symbols.group_rounded;
    case 'family':
      return Symbols.family_restroom_rounded;
    case 'work':
      return Symbols.work_rounded;
    case 'outdoors':
      return Symbols.park_rounded;
    case 'rest':
      return Symbols.weekend_rounded;
    case 'hobby':
      return Symbols.palette_rounded;
    case 'slept_well':
      return Symbols.bedtime_rounded;
    case 'short_night':
      return Symbols.bedtime_off_rounded;
    case 'active_day':
      return Symbols.directions_run_rounded;
    case 'quiet_day':
      return Symbols.chair_rounded;
    case 'period':
      return Symbols.water_drop_rounded;
    case 'took_doses':
      return Symbols.check_circle_rounded;
    case 'missed_dose':
      return Symbols.warning_rounded;
  }
  return Symbols.sell_rounded;
}

/// One tag, a chip: its glyph, its name, a tap to toggle.
class MoodTagChip extends StatelessWidget {
  const MoodTagChip({
    super.key,
    required this.id,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final String id;
  final AccentSwatch accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppChip(
        label: MoodTags.label(id),
        icon: moodTagIcon(id),
        accent: accent,
        selected: selected,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
      );
}

/// Great … Terrible as five faces, one selected (or none).
class MoodFaceRow extends StatelessWidget {
  const MoodFaceRow({super.key, required this.selected, required this.onSelected});

  /// An index into `moodRatingLabels`, or null for none yet.
  final int? selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    return Row(
      children: [
        for (var i = 0; i < moodRatingLabels.length; i++)
          Expanded(
            child: MoodFaceButton(
              selected: selected == i,
              icon: VitalsColors.moodIcon(i),
              label: moodRatingLabels[i],
              color: VitalsColors.moodBand(ext.isDark, i),
              onTap: () => onSelected(i),
            ),
          ),
      ],
    );
  }
}

class MoodFaceButton extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const MoodFaceButton({
    super.key,
    required this.selected,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      container: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? color.withValues(alpha: 0.16) : ext.surfaceVariant,
                shape: BoxShape.circle,
                border:
                    Border.all(color: selected ? color : ext.outline, width: 1.5),
              ),
              child:
                  Icon(icon, color: selected ? color : ext.textTertiary, size: 26),
            ),
            const SizedBox(height: 4),
            // The cell is width / 5 -- about 55pt on a 320pt sheet -- so the
            // label has to shrink into it. scaleDown never enlarges, so at
            // default sizes it renders exactly as before.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label,
                  maxLines: 1,
                  softWrap: false,
                  style: tt.labelSmall?.copyWith(
                      color: selected ? color : ext.textTertiary,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.normal)),
            ),
          ],
        ),
      ),
    );
  }
}
