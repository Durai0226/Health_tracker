import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/health/mood_tags.dart';
import '../../../core/utils/calendar_day.dart';
import '../../../core/utils/date_formats.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../medication/widgets/mood_pickers.dart';

/// What an entry carries besides its words: when it is dated, how the writer
/// felt (optional) and what it was about (optional).
class DiaryDetails {
  const DiaryDetails({required this.at, this.mood, this.tags = const []});

  final DateTime at;

  /// 0 (Great) … 4 (Terrible), or null.
  final int? mood;

  final List<String> tags;

  /// "Today, 9:41 AM", "Yesterday, 9:41 AM", "Mar 4, 9:41 AM": the day in words
  /// when it is a near one, as the date field in the sheet itself reads.
  static String whenLabel(DateTime at, {DateTime? now}) {
    final ref = now ?? clock.now();
    final today = DateTime(ref.year, ref.month, ref.day);
    final day = DateTime(at.year, at.month, at.day);
    final diff = calendarDaysBetween(day, today);
    final time = DateFormats.time.format(at);
    if (diff == 0) return 'Today, $time';
    if (diff == 1) return 'Yesterday, $time';
    return '${DateFormats.dayLabel(day, reference: today)}, $time';
  }

  @override
  bool operator ==(Object other) =>
      other is DiaryDetails &&
      other.at == at &&
      other.mood == mood &&
      _sameTags(other.tags, tags);

  @override
  int get hashCode => Object.hash(at, mood, Object.hashAll(tags));

  static bool _sameTags(List<String> a, List<String> b) =>
      a.length == b.length && a.toSet().containsAll(b);
}

/// "Entry details": the date and time (it can be set back — people write about
/// yesterday), the mood and the tags. One sheet, so the editor keeps its room
/// for the words.
class DiaryDetailsSheet extends StatefulWidget {
  const DiaryDetailsSheet(
      {super.key, required this.initial, required this.accent});

  final DiaryDetails initial;
  final AccentSwatch accent;

  static Future<DiaryDetails?> show(
    BuildContext context, {
    required DiaryDetails initial,
    required AccentSwatch accent,
  }) =>
      AppBottomSheet.show<DiaryDetails>(
        context,
        title: 'Entry details',
        icon: Symbols.tune_rounded,
        accent: accent,
        builder: (_) => DiaryDetailsSheet(initial: initial, accent: accent),
      );

  @override
  State<DiaryDetailsSheet> createState() => _DiaryDetailsSheetState();
}

class _DiaryDetailsSheetState extends State<DiaryDetailsSheet> {
  late DateTime _at = widget.initial.at;
  late int? _mood = widget.initial.mood;
  late final Set<String> _tags = {...widget.initial.tags};

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppDateTimeField(
          value: _at,
          accent: widget.accent,
          noun: 'Entry',
          onChanged: (v) => setState(() => _at = v),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('How were you feeling?',
            style: tt.labelMedium?.copyWith(color: ext.textSecondary)),
        const SizedBox(height: AppSpacing.sm),
        MoodFaceRow(
          selected: _mood,
          // The same face again takes it back: a mood is optional here.
          onSelected: (i) => setState(() => _mood = _mood == i ? null : i),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('What was it about?',
            style: tt.labelMedium?.copyWith(color: ext.textSecondary)),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final id in MoodTags.manual)
              MoodTagChip(
                id: id,
                accent: widget.accent,
                selected: _tags.contains(id),
                onTap: () => setState(() {
                  if (!_tags.remove(id)) _tags.add(id);
                }),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Done',
          leadingIcon: Symbols.check_rounded,
          accent: widget.accent,
          fullWidth: true,
          size: AppButtonSize.lg,
          onPressed: () => Navigator.pop(
            context,
            DiaryDetails(
              at: _at,
              mood: _mood,
              // The order they were listed in, not the order they were tapped.
              tags: [
                for (final id in MoodTags.manual)
                  if (_tags.contains(id)) id,
                // An id from a later version stays on the entry.
                ..._tags.where((t) => !MoodTags.manual.contains(t)),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}
