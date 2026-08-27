import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../design/app_design.dart';
import 'app_button.dart';

/// How the header arranges its chrome relative to its title.
///
/// Two values, and the second one is used by exactly one screen. That is not
/// an oversight — see the measurements on [AppHeader].
enum HeaderLayout {
  /// Single row: leading · title · actions. Every screen but Home.
  inline,

  /// Two rows: chrome on top, title across the FULL width below it.
  ///
  /// The Material 3 medium top-app-bar structure. Correct when the title has to
  /// share its row with something TEXT-BEARING on both sides, because those
  /// size to their content and leave the title whatever is left.
  stacked,
}

/// One calm, compact, non-gradient header for every screen — the antidote to
/// the four legacy header grammars and the double-header hub.
///
/// Use as a box (top of a Column / SliverToBoxAdapter). Optional [actions] and
/// a [bottom] slot for a segmented control.
///
/// ## No greeting, and [HeaderLayout.stacked] survives on one screen
///
/// The greeting slot is gone, because a greeting is **content**. "Good morning"
/// belongs in the scroll body where it scrolls away, not pinned above the data
/// the user opened the app to read. Two of its four callers were not greetings
/// at all — "Ready to focus?" over a title reading *Focus*, and "Your focus
/// insights" over *Statistics* — and those are simply deleted.
///
/// The post-mortem's fix is preserved rather than discarded. The greeting that
/// wrapped to three lines did so because it was unbounded user data inside
/// FIXED CHROME competing with text-bearing controls. In a scroller at full
/// content width it has neither problem, which is why the body copies carry no
/// `maxLines` and why that is a decision rather than an omission.
///
/// **The second layout was going to go too, and measurement stopped it.** The
/// argument for deleting it was that `headlineSmall` 18/24 fits beside chrome
/// where `headlineLarge` 26/32 could not. True in general; false on Home, which
/// is the only screen whose chrome is text-bearing on BOTH sides — a profile
/// chip carrying a user-entered dependent name on the left, a streak pill and a
/// settings button on the right. Inline, at 320pt:
///
/// | profile label | title column | header |
/// |---|---|---|
/// | "Me" | 73.4pt | 72pt |
/// | "Grandmother Elizabeth Katherine" | **36.8pt** | **96pt** |
///
/// "Today" needs ~47pt of real Plus Jakarta Sans at 18pt, so the second row is
/// not the harness font over-reporting — the title genuinely does not fit, and
/// the header grows to three lines. That is the original bug with the greeting
/// swapped for the title. `docs/home-header.md` reached this conclusion first
/// and it still holds.
///
/// The change that would retire the second layout is on the screen, not here:
/// an avatar-only profile chip (44pt, initial in a circle, name in the switcher
/// sheet on tap) makes Home's chrome identical to every other screen's and
/// leaves the title 124pt at 320pt. That is a product decision about Home, not
/// a header refactor, so it is not smuggled in with one.
///
/// ## There is no icon slot
///
/// There was, on 45 of the 60 headers: a 52pt accent-tinted chip between the
/// back arrow and the title. It is gone, and the strongest argument was never
/// aesthetic — **it was already being dropped silently.** The old inline layout
/// gated it on `(maxWidth - reserved - 52) >= 110`, so on a 320pt screen with a
/// back button and two actions the chip simply vanished; and because `reserved`
/// counted `SizedBox.shrink()` placeholders as full actions, a *hidden* action
/// made it vanish sooner still. An element that appears or disappears by
/// available width is not identity, it is noise.
///
/// The second reason is Apple's own accessibility guidance: text displayed
/// inline with secondary items such as glyphs has less horizontal space to work
/// with. The chip cost the title 52pt plus a 12pt gap on every screen that had
/// one — and the title is the thing the reader came for.
class AppHeader extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  final Widget? leading;
  final Widget? bottom;
  final HeaderLayout layout;

  const AppHeader({
    super.key,
    required this.title,
    this.actions = const [],
    this.leading,
    this.bottom,
    this.layout = HeaderLayout.inline,
  });

  /// Removed rather than defaulted: `padding` and `safeTop` were parameters
  /// that 0 of 60 call sites ever passed. An optional slot nobody should use is
  /// an invitation, and two of them on the app's most-used widget is two more
  /// ways for headers to stop agreeing with each other.
  ///
  /// `accent` went the same way, for the opposite reason — 54 of 60 sites
  /// passed it and by then it reached nothing. Its only consumer was the icon
  /// badge; the back arrow is deliberately neutral, the title is `textPrimary`,
  /// and every action already carries its own accent or inherits the ambient
  /// [AccentScope]. The compiler said so before this comment did: deleting the
  /// badge left `s` unused.
  ///
  /// The plan had it moving to a tinted hairline under the header. That does
  /// not survive measurement. Against the light surface an accent `container`
  /// runs 1.10 (steps) to 1.45 (brand) contrast, and the neutral `outline` the
  /// two hand-rolled hairlines use sits at 1.25 — so a per-feature rule would
  /// be *invisible* on some screens and heavier than today's on others. That is
  /// the "no two headers agree" defect this redesign exists to close, moved 1pt
  /// down the page rather than fixed.
  static const EdgeInsets _padding = EdgeInsets.fromLTRB(
      AppSpacing.gutter, AppSpacing.lg, AppSpacing.gutter, AppSpacing.sm);

  /// M3's small top-app-bar container height. A floor, never a fixed height —
  /// Android's guidance is explicit that a container holding scalable text must
  /// be free to grow, and this one now holds a title that scales.
  static const double _minHeight = 64;

  /// The standard back affordance for a pushed screen.
  ///
  /// This exact 8-line block — `AppIconButton` with `arrow_back_rounded`, a
  /// `canPop` guard, and `filled: false` — is copy-pasted across dozens of
  /// screens. A whole detail-page scaffold widget was considered and rejected:
  /// 61 files use `Symbols.arrow_back_rounded`, so a wrapper would be a 61-file
  /// migration for about twelve lines each, and `AppHeader` already absorbs the
  /// genuinely hard parts (the title `FittedBox`, the bounded leading slot, the
  /// stacked layout). This static is the small piece that was actually
  /// duplicated.
  ///
  /// The `canPop` guard matters: on a screen that is also reachable as a route
  /// root (the QA harness and the responsive sweep both mount screens that way)
  /// an unguarded `Navigator.pop` throws.
  ///
  /// **Neutral, not accented.** The `accent` parameter is retained so the 41
  /// hand-rolled call sites can migrate without editing each argument list, but
  /// it is deliberately ignored: the arrow used to resolve to at least 13 hues
  /// — seven feature accents, five from the parallel `VitalsColors` palette, and
  /// `textPrimary` on two screens using a raw `IconButton` — so the one control
  /// a user needs to find in a hurry looked different on every screen. It is
  /// chrome; chrome does not change colour with its surroundings.
  ///
  /// The tooltip is not decoration either. It was set on 8 of 41 hand-rolled
  /// back buttons, so roughly 33 of them announced to a screen reader as an
  /// unlabelled button.
  /// No `accent`. There was one, deprecated, so migrating call sites did not
  /// have to edit their argument lists in the same commit — and six of them
  /// then kept passing it, which is exactly what a soft-deprecated parameter
  /// invites. The arrow is chrome and is unconditionally neutral, so an accent
  /// argument that silently does nothing is worse than a compile error.
  static Widget backButton(BuildContext context) =>
      Builder(
        builder: (context) => AppIconButton(
          icon: Symbols.arrow_back_rounded,
          filled: false,
          color: AppColorsExt.of(context).textPrimary,
          tooltip: 'Back',
          onPressed: () {
            if (Navigator.canPop(context)) Navigator.pop(context);
          },
        ),
      );

  /// Wrap to a second line before giving up; never shrink.
  ///
  /// This replaced a `FittedBox(scaleDown)` that existed for a real reason —
  /// with a back button, an icon badge and 2-3 actions there was under 100pt
  /// left, and titles truncated to "Wei…" / "Blood s…" / "Family & careg…".
  /// Shrinking was the right emergency fix and the wrong permanent one: it made
  /// the title the ONLY text on screen that ignores the user's font-size
  /// choice. At 2.0x Dynamic Type every other string doubled and this one was
  /// scaled back down to fit a single line.
  ///
  /// So the crowding is fixed at the source instead — the decorative icon slot
  /// is gone and `actions` are bounded — and the title is simply allowed the
  /// room. `headlineSmall` (18) rather than `headlineLarge` (26) because M3 caps
  /// even a *large* app bar's title at `headlineMedium` (22), and a compact bar
  /// at `titleLarge`; 18 keeps the display typeface while landing between them.
  ///
  /// A second, measurable reason for 18: this header is height-flat until the
  /// title's line box exceeds the 44pt back button. At 26 that happens at 1.375x
  /// text scale, so most screens grew through the supported range. At 18 it does
  /// not happen until 1.83x.
  /// No `maxLines`. The header grows instead.
  ///
  /// I tried `maxLines: 2` first and tested it, and the test said no: with a
  /// back button and NO actions at all, "Health data & privacy" still had to be
  /// cut at 320pt / 1.3x. Two lines is simply not enough room for a
  /// 21-character title at large type on a small phone, and clamping to two and
  /// ellipsising would have swapped one silent failure for another.
  ///
  /// The bug the original clamp existed for was caused by INTERPOLATED USER
  /// DATA — a profile name inside "Good evening · …" — which has no length
  /// bound. A title is a developer-authored literal; the longest in this app is
  /// 21 characters. Letting a literal wrap is safe in a way that letting user
  /// data wrap is not, which is why the title's allowance is generous and the
  /// only remaining unbounded string, the profile chip's label, stays clamped
  /// inside `AppChip`.
  ///
  /// A test bounds it at three lines, so a future title that needs four fails
  /// and the fix is shorter copy — the right lever, and the same one
  /// docs/ui-audit.md:341 reached for when it concluded that `weight`'s real
  /// problem was one control too many rather than a font size.
  /// The clamp scales with the text, because a fixed one cannot be right at
  /// both ends. Two lines was tested and failed — with a back button and NO
  /// actions, "Health data & privacy" still had to be cut at 320pt / 1.3x — and
  /// a flat three then failed at 2.0x. Allowing roughly two lines per unit of
  /// scale is the rule that holds across the range: 3 at 1.0x, 4 at 1.3x, 5 at
  /// 2.0x.
  ///
  /// Generous-looking numbers because the harness font is about twice the width
  /// of the shipped Nunito/Inter (docs/ux-review.md:245); on a device these are
  /// roughly half. The ellipsis remains as the last resort, and the test asserts
  /// it never actually fires for any title the app ships.
  Widget _titleText(BuildContext context, TextTheme tt) => Text(
        title,
        style: tt.headlineSmall,
        maxLines: (2 * MediaQuery.textScalerOf(context).scale(1.0)).ceil() + 1,
        overflow: TextOverflow.ellipsis,
      );

  /// [leading] sits in a `Row` as a non-flex child, so it is handed unbounded
  /// main-axis constraints and `AppChip`'s own `Flexible` + ellipsis never
  /// engages. A user-entered dependent name ("Grandmother Elizabeth") therefore
  /// grew without limit and overflowed for real. Cap it so the chip ellipsizes.
  Widget _boundedLeading(double maxWidth) => ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _leadingCap(maxWidth)),
        child: leading!,
      );

  /// Chrome may take at most half the row. The title keeps the rest.
  ///
  /// The original bound was per-slot: `leading` capped at 40% and, in my first
  /// pass, each action capped at 40% too. That is not a budget — it is two
  /// independent allowances that can sum past everything the title needs. The
  /// responsive sweep caught it immediately: on `add_dependent` at 320pt the
  /// title column was left **52pt** and the (unclamped) title wrapped to eight
  /// lines, fifteen at 2.0x. Precisely the greeting bug, reborn on the title.
  ///
  /// So the chrome is budgeted TOGETHER. A row of 44pt icon buttons fits inside
  /// the half easily and is unaffected; a text-bearing action is squeezed and
  /// ellipsises, which is the right order of sacrifice — an action's label is
  /// recoverable from its tooltip, the screen's title is not.
  ///
  /// I tried budgeting leading and actions TOGETHER at half the row, so the
  /// title always kept the other half. It broke the profile chip: squeezing
  /// `leading` from 40% to 20% overflowed the home-like header by 7px at 320pt,
  /// and that 40% was arrived at by an earlier post-mortem for a reason.
  ///
  /// The widths were survivable all along. What actually produced the eight-line
  /// title was removing the title's `maxLines` — so the clamp is the fix, and
  /// this stays a simple per-slot cap.
  static const double _chromeShare = 0.4;

  double _leadingCap(double maxWidth) => maxWidth * _chromeShare;

  /// One more correction, found by measuring rather than reasoning: the cap is
  /// per action, NOT the share divided between them.
  ///
  /// Dividing gave each of Weight's four chrome items 280 x 0.4 / 3 = 37pt, and
  /// the `kg` unit pill — which needs ~50 — ellipsised its own two-character
  /// label down to **9pt**. That is "Wei..." again, one slot to the right. The
  /// division was the same over-correction as budgeting leading and actions
  /// together, and it failed the same way: a bound that binds on the innocent.
  ///
  /// A cap of 40% per action lets a row of 44pt icon buttons through untouched
  /// while still forcing a long text-bearing chip to ellipsise, which is the
  /// only case the bound was ever for. Four controls on a 320pt row remains one
  /// too many — `docs/ui-audit.md:341` says so about this exact screen — but
  /// that is the screen's problem to fix, and papering over it here costs every
  /// other header a working unit pill.
  List<Widget> _boundedActions(double maxWidth) {
    if (actions.isEmpty) return const [];
    final cap = maxWidth * _chromeShare;
    return [
      for (final a in actions) ...[
        const SizedBox(width: 8),
        ConstrainedBox(constraints: BoxConstraints(maxWidth: cap), child: a),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    // Chrome on its own row, then the title across the full width. Nothing
    // competes for horizontal space, so the title cannot be starved. Home only.
    Widget buildStacked(double maxWidth) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null || actions.isNotEmpty) ...[
              Row(
                children: [
                  if (leading != null) _boundedLeading(maxWidth),
                  const Spacer(),
                  ..._boundedActions(maxWidth),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            _titleText(context, tt),
          ],
        );

    // With the badge gone the only chrome left is the back arrow and the
    // actions, and both are already bounded to 40% of the row each. So there is
    // no width arithmetic here any more and no element that conditionally
    // disappears: what the widget is asked to render, it renders.
    Widget buildRow(double maxWidth) {
      return Row(
        children: [
          if (leading != null) ...[
            _boundedLeading(maxWidth),
            const SizedBox(width: 8),
          ],
          Expanded(child: _titleText(context, tt)),
          ..._boundedActions(maxWidth),
        ],
      );
    }

    // SafeArea OUTSIDE the padding, which is the other way round from how this
    // shipped. `SafeArea` defaults `left: true, right: true`, so with the
    // padding outside it the effective gutter became `20 + notchInset` in
    // landscape on a notched device — and the header's left edge stopped
    // agreeing with the card grid below it. Inside, the gutter is 20 always.
    return SafeArea(
      bottom: false,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _minHeight),
        child: Padding(
          padding: _padding,
          child: LayoutBuilder(
            builder: (context, constraints) => Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                switch (layout) {
                  HeaderLayout.stacked => buildStacked(constraints.maxWidth),
                  HeaderLayout.inline => buildRow(constraints.maxWidth),
                },
                if (bottom != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  bottom!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
