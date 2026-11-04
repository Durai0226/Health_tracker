import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../services/medicine_storage_service.dart';

/// "Share with the family" on a doctor or clinic form: off keeps the record with
/// the person it was added for, on shows it under every profile — a family doctor.
///
/// Draws nothing in a household of one, where there is nobody to share with and the
/// switch would only ask a question with no answer. [kind] is "doctor" or "clinic".
class ShareWithFamilyCard extends StatefulWidget {
  const ShareWithFamilyCard({
    super.key,
    required this.value,
    required this.onChanged,
    required this.kind,
    this.accent,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String kind;
  final AccentSwatch? accent;

  @override
  State<ShareWithFamilyCard> createState() => _ShareWithFamilyCardState();
}

class _ShareWithFamilyCardState extends State<ShareWithFamilyCard> {
  bool _hasFamily = false;

  @override
  void initState() {
    super.initState();
    _look();
  }

  Future<void> _look() async {
    try {
      final all = await MedicineCleanStorageService.getAllDependents();
      if (!mounted) return;
      setState(() => _hasFamily = all.any((d) => !d.isSelf));
    } catch (_) {
      // Unreadable: stay hidden rather than offer a switch we cannot explain.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasFamily) return const SizedBox.shrink();
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final accent = widget.accent ?? ext.medicine;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: AppCard(
        onTap: () {
          HapticService().toggle();
          widget.onChanged(!widget.value);
        },
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accent.container,
                borderRadius: AppRadius.brSm,
              ),
              child: Icon(Symbols.group_rounded, color: accent.onContainer, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Share with the family',
                      style: tt.titleLarge?.copyWith(color: ext.textPrimary)),
                  const SizedBox(height: 2),
                  Text(
                    widget.value
                        ? 'Every profile sees this ${widget.kind}.'
                        : 'Only the person it was added for sees this ${widget.kind}.',
                    style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
                  ),
                ],
              ),
            ),
            AppSwitch(
              value: widget.value,
              onChanged: (v) {
                HapticService().toggle();
                widget.onChanged(v);
              },
              accent: accent,
            ),
          ],
        ),
      ),
    );
  }
}
