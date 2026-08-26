import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../design/app_design.dart';

/// The one on-brand switch.
///
/// ## Why Cupertino on an Android-first app
///
/// The reported defect was that OFF rows looked DISABLED, and it was exactly
/// true: the Material implementation resolved `ext.surfaceVariant` as the track
/// colour for **both** the off state and the disabled state — a contrast ratio
/// of 1.000:1 between them. The only difference was the thumb, `outlineStrong`
/// against `textDisabled`, which is 1.322:1 in light and 1.187:1 in dark. Two
/// states, no meaningful difference.
///
/// `CupertinoSwitch` fixes that structurally rather than by picking better
/// greys: it renders a disabled switch at
/// [_kDisabledOpacity](flutter/lib/src/cupertino/switch.dart:28) — a flat 50% —
/// so unavailable reads as unavailable at any track colour anyone chooses
/// later. A colour pair can drift back together; an opacity cannot.
///
/// It also gives the thumb 90% of the track height instead of 50% and paints
/// `_kSwitchBoxShadows` under it (`switch.dart:1385`), which is what lets a
/// white thumb stay legible on a pale off-track without a border.
///
/// If this ever reads wrong on device, `Switch.adaptive` is the one-line change
/// to get Cupertino on iOS and Material on Android.
///
/// ## The colours are the app's filled-control pair, not new ones
///
/// A switch's on-track is a filled control, so [AppColorsExt.fillBg] and
/// [AppColorsExt.fillFg] are already the right answer and are already
/// validated. Measured across all eight accents in both themes, the worst case
/// is **5.02:1** for both thumb-against-track and track-against-surface —
/// comfortably past the 3:1 that WCAG 1.4.11 asks of a non-text control.
///
/// The naive choice does not survive the same measurement: a white thumb on
/// `s.base` is 2.44:1 for brand in dark and 2.15:1 for reminders in light, and
/// no single accent field passes in both themes.
///
/// ## The off state
///
/// A pale track cannot itself reach 3:1 against a pale card and stay readable
/// as "off" — iOS's own is about 1.1:1. The control's boundary carries the
/// requirement instead, so the off track is outlined in [AppColorsExt.textTertiary],
/// the only token in the palette clearing 3:1 against both the card and the page
/// in both themes (3.78 / 3.50 light, 3.85 / 4.16 dark). `outlineStrong`, which
/// the Material version used, manages 1.45.
///
/// ## Size
///
/// Cupertino lays out at 59x39 against Material's 60x48, so the box is pinned
/// to 60x48 to keep 47 rendered switches from shifting and to hold the row
/// height. The switch's own gesture area is the 39pt one — the 44pt target
/// comes from the row, which toggles on tap.
class AppSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged; // null => disabled
  final AccentSwatch? accent;          // defaults to brand teal (NOT AccentScope)
  const AppSwitch({super.key, required this.value, this.onChanged, this.accent});

  /// Material's padded switch size. Kept so the swap is layout-neutral.
  static const Size size = Size(60, 48);

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final s = accent ?? ext.brand;

    return SizedBox(
      width: size.width,
      height: size.height,
      child: Center(
        child: CupertinoSwitch(
          value: value,
          onChanged: onChanged == null
              ? null
              : (v) {
                  HapticFeedback.selectionClick();
                  onChanged!(v);
                },
          activeTrackColor: ext.fillBg(s),
          inactiveTrackColor: ext.surfaceVariant,
          thumbColor: ext.fillFg(s),
          inactiveThumbColor: CupertinoColors.white,
          // Only when off: an outline around a filled track reads as a seam.
          trackOutlineColor: WidgetStateProperty.resolveWith((st) =>
              st.contains(WidgetState.selected)
                  ? const Color(0x00000000)
                  : ext.textTertiary),
          trackOutlineWidth: const WidgetStatePropertyAll(1),
        ),
      ),
    );
  }
}
