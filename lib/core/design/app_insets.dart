import 'package:flutter/widgets.dart';

import '../constants/app_spacing.dart';

/// How much room a scrollable has to leave below its last row.
///
/// Three conventions coexisted, none of which accounted for the gesture bar:
///
///  * `AppSpacing.huge` (48) on pushed screens,
///  * a magic `100` on two tab roots, and
///  * the real `MediaQuery.padding.bottom` at only five sites in the app.
///
/// The magic 100 turns out to be right and merely undocumented: `AppNavBar` is
/// a `SizedBox(height: 68)` inside a `SafeArea`, the FAB overhangs it by 20, and
/// 12 is the gap — 68 + 20 + 12 = 100. What none of the three did was add the
/// **bottom view padding**, so on a device with a home indicator or a gesture
/// bar the last row of a pushed screen sits partly underneath it.
///
/// That is not usually visible on a tab root, because the nav bar's own
/// `SafeArea` already covers the inset. It is visible on every pushed screen,
/// which is most of the app — and it is invisible to every harness here, since
/// a fixed test viewport reports zero insets. Which is also what makes adopting
/// these safe: with no insets they return exactly the constants they replace, so
/// no baseline moves.
///
/// `viewPadding` rather than `padding` on purpose: `padding` goes to zero while
/// the keyboard is up, and a list's resting bottom inset should not depend on
/// whether a text field happens to be focused.
abstract final class AppInsets {
  /// [AppNavBar]'s own height, before the safe area it sits inside.
  static const double navBar = 68;

  /// How far the centre FAB rises above the nav bar.
  static const double fabOverhang = 20;

  /// Bottom padding for a scrollable on a **pushed** screen — no bottom nav
  /// below it, so only the system inset and a comfort gap.
  static double pushed(BuildContext context) =>
      AppSpacing.huge + MediaQuery.viewPaddingOf(context).bottom;

  /// Bottom padding for a scrollable on a **tab root**, whose content scrolls
  /// behind the nav bar and the FAB that overhangs it.
  static double underNav(BuildContext context) =>
      navBar + fabOverhang + AppSpacing.md +
      MediaQuery.viewPaddingOf(context).bottom;
}
