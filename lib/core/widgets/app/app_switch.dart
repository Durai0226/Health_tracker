import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../design/app_design.dart';

/// The one on-brand switch. Material Switch (never .adaptive) with an explicit
/// tokened teal palette, so it renders identical teal on iOS + Android and is
/// immune to the CupertinoSwitch systemGreen fallback.
class AppSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged; // null => disabled
  final AccentSwatch? accent;          // defaults to brand teal (NOT AccentScope)
  const AppSwitch({super.key, required this.value, this.onChanged, this.accent});

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final s = accent ?? ext.brand;
    final onTrack = s.base; // opaque teal, not the 0.45 wash from switchTheme
    return Switch(
      value: value,
      onChanged: onChanged == null ? null : (v) {
        HapticFeedback.selectionClick();
        onChanged!(v);
      },
      materialTapTargetSize: MaterialTapTargetSize.padded, // >=48px target
      thumbColor: WidgetStateProperty.resolveWith((st) =>
        st.contains(WidgetState.disabled) ? ext.textDisabled
        : st.contains(WidgetState.selected) ? Colors.white : ext.outlineStrong),
      trackColor: WidgetStateProperty.resolveWith((st) =>
        st.contains(WidgetState.disabled) ? ext.surfaceVariant
        : st.contains(WidgetState.selected) ? onTrack : ext.surfaceVariant),
      trackOutlineColor: WidgetStateProperty.resolveWith((st) =>
        st.contains(WidgetState.selected) ? Colors.transparent : ext.outlineStrong),
      trackOutlineWidth: WidgetStateProperty.all(1),
      overlayColor: WidgetStateProperty.all(onTrack.withOpacity(0.12)),
      thumbIcon: WidgetStateProperty.all(null), // no M3 check glyph
    );
  }
}
