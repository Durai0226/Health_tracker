import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/widgets/app/vitals_theme.dart';
import '../models/diary_entry.dart';
import '../services/diary_prompts.dart';
import '../services/on_this_day.dart';

/// "On this day": what was written on today's date in earlier years. Each row
/// opens the entry.
class OnThisDayCard extends StatelessWidget {
  const OnThisDayCard({super.key, required this.items, required this.onOpen});

  final List<OnThisDayItem> items;
  final ValueChanged<DiaryEntry> onOpen;

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final accent = ext.brand;
    return AppCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Row(
              children: [
                Icon(Symbols.history_rounded, size: 18, color: ext.mark(accent)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text('On this day',
                      style: tt.titleSmall?.copyWith(
                          color: ext.textPrimary, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          for (final item in items)
            InkWell(
              onTap: () => onOpen(item.entry),
              borderRadius: AppRadius.brSm,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.label,
                                style: tt.labelMedium
                                    ?.copyWith(color: ext.textTertiary)),
                            Text(item.entry.displayTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: tt.bodyMedium
                                    ?.copyWith(color: ext.textPrimary)),
                          ],
                        ),
                      ),
                      if (item.entry.moodIndex != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Icon(VitalsColors.moodIcon(item.entry.moodIndex!),
                            size: 20,
                            color: VitalsColors.moodBand(
                                ext.isDark, item.entry.moodIndex!)),
                      ],
                      const SizedBox(width: AppSpacing.xs),
                      Icon(Symbols.chevron_right_rounded,
                          size: 20, color: ext.textTertiary),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One question to write about, offered — never a nag: "Not today" puts it away
/// until tomorrow.
class DiaryPromptCard extends StatelessWidget {
  const DiaryPromptCard({
    super.key,
    required this.prompt,
    required this.onWrite,
    required this.onDismiss,
  });

  final DiaryPrompt prompt;
  final VoidCallback onWrite;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final accent = ext.brand;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Symbols.edit_note_rounded, size: 18, color: ext.mark(accent)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('A prompt for today',
                    style: tt.labelMedium?.copyWith(color: ext.textTertiary)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(prompt.text,
              style: tt.titleMedium?.copyWith(
                  color: ext.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppButton(
                label: 'Write about it',
                leadingIcon: Symbols.edit_rounded,
                accent: accent,
                onPressed: onWrite,
              ),
              TextButton(
                onPressed: onDismiss,
                style: TextButton.styleFrom(
                    foregroundColor: ext.textSecondary,
                    minimumSize: const Size(0, 44)),
                child: const Text('Not today'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
