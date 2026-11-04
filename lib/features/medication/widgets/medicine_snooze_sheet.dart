import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/widgets/app/app_widgets.dart';
import '../models/medicine_snooze.dart';

/// Ask how long this medicine's Snooze should wait.
///
/// The answer is a record so that "Follow the Notifications setting" (a null
/// length) is distinguishable from the sheet being dismissed (a null record):
/// the first clears a stored choice, the second changes nothing.
Future<({int? minutes})?> chooseMedicineSnooze(
  BuildContext context, {
  required int? current,
  required int phoneWide,
  required AccentSwatch accent,
}) =>
    AppBottomSheet.show<({int? minutes})>(
      context,
      title: 'Snooze length',
      icon: Symbols.snooze_rounded,
      accent: accent,
      builder: (sheetCtx) {
        final selected = MedicineSnooze.isKnown(current) ? current : null;
        void pick(int? minutes) =>
            Navigator.of(sheetCtx).pop((minutes: minutes));

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppListTile(
              icon: selected == null
                  ? Symbols.check_circle_rounded
                  : Symbols.snooze_rounded,
              title: 'Same as Notifications',
              subtitle: 'Currently $phoneWide min for every medicine',
              accent: accent,
              onTap: () => pick(null),
              trailing: const SizedBox.shrink(),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final minutes in MedicineSnooze.options) ...[
              AppListTile(
                icon: selected == minutes
                    ? Symbols.check_circle_rounded
                    : Symbols.snooze_rounded,
                title: '$minutes min',
                accent: accent,
                onTap: () => pick(minutes),
                trailing: const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        );
      },
    );
