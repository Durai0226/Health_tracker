/// The geometry every settings-style row is built from.
///
/// Lives in the design layer rather than beside either row widget, because
/// **both** consume it and neither owns it. It was `AppListTileMetrics` inside
/// `list_group.dart`, which was fine while only one widget used it and became
/// the reason the two disagreed once two did.
///
/// The hand-written dividers used `indent: 52, endIndent: 8`. Neither number
/// matches the tile:
///
/// * **Left.** The tile pads 12, then draws a 36pt icon chip (a 20pt glyph with
///   8pt of padding on each side), then a 14pt gap — so its TEXT starts at 62.
///   A divider indented 52 begins 10pt to the left of the text it is supposed to
///   align with, which is what makes those lists read as slightly crooked.
/// * **Right.** The tile pads 12, but the divider stopped 8 short — so it
///   overshot the content by 4pt at the other end.
///
/// Deriving the inset here means a change to the tile's padding cannot silently
/// leave every divider in the app misaligned again.
///
/// ## One geometry for BOTH row widgets
///
/// This started as `AppListTile`'s numbers alone. `SettingsTile` had its own
/// set, and they disagreed on four of them — icon box 32 vs 36, glyph 18 vs 20,
/// chevron 22 vs 24 (the latter inherited from the theme by omission), and ink
/// radius none vs 12. The visible consequence was the divider inset:
/// `SettingsTile` hardcoded 58 while this class derived 62, so
/// `health_privacy_screen.dart` — which puts `AppListTile`s inside
/// `SettingsSection`s — drew eight rules 4pt to the left of the text they align
/// to.
///
/// Resolved toward this class's numbers, because they are the derived ones. The
/// exception is the chevron: 22 was `SettingsTile`'s explicit choice and 24 was
/// Material's default that `AppListTile` picked up by not saying anything, and
/// a decision beats an omission.
class AppRowMetrics {
  const AppRowMetrics._();

  /// A row's own horizontal padding.
  static const double horizontalPadding = 12;

  /// The icon chip: a 20pt glyph inside 8pt of padding on each side.
  static const double iconBox = 20 + 8 * 2;

  /// Between the icon chip and the text column.
  static const double iconGap = 14;

  /// Between the text column and whatever trails it.
  static const double trailingGap = 12;

  static const double glyphSize = 20;

  static const double chevronSize = 22;

  /// A floor, never a fixed height. Android's guidance is explicit that a
  /// container holding scalable text must be free to grow, and a row whose
  /// title is allowed two lines at 2.0x is exactly such a container.
  static const double minHeight = 56;

  /// The widest a trailing widget may be, as a share of the row.
  ///
  /// This is the fix for the defect that prompted the redesign. `SettingsTile`
  /// gave the text `Expanded(flex: 3)` and the trailing `Flexible(flex: 2)` — a
  /// TIGHT 60% for the text against a LOOSE 40% for the trailing, so whatever
  /// the trailing did not use was never handed back. At 393pt that reserved
  /// 108.4pt beside a 60pt switch and left 48.4pt of the row permanently blank
  /// while the title wrapped in 162.6pt.
  ///
  /// The row now puts the text in `Expanded` and the trailing outside the flex,
  /// so the trailing takes its intrinsic width up to this cap and the text
  /// takes the rest.
  ///
  /// **0.30, and it was 0.45 for one measurement.** At 0.45 the sweep showed
  /// `haptics` titles cut at 79pt — worse than the 116.4pt the old flex split
  /// gave them. Switch and chevron trailings are fixed-width so "intrinsic"
  /// helps them, but a `value:` row's trailing is TEXT and takes everything it
  /// is allowed. 0.30 is sized on the one trailing that genuinely cannot
  /// shrink, the 60pt switch; a value text shrinks into the same budget through
  /// the `FittedBox(scaleDown)` it already carries, which is what that
  /// `FittedBox` was added for.
  ///
  /// | row | title @320 before | after |
  /// |---|---|---|
  /// | chevron | 118.8 | 172.0 |
  /// | switch | 118.8 | 134.0 |
  /// | value | 116.4 | 117.2 |
  static const double trailingShare = 0.30;

  /// The cap never goes below this. A Material switch lays out at a fixed
  /// 60x48 and cannot be squeezed — constraining it narrower does not shrink
  /// it, it overflows.
  static const double trailingFloor = 60;

  /// Where a row's text column starts, and therefore where a separator between
  /// two rows must start. 12 + 36 + 14 = 62.
  static const double textInset = horizontalPadding + iconBox + iconGap;
}


