# Widgets in this folder — where to look

This file used to be a guide to `PremiumCategorySelector`, `CompactCategorySelector`
and `CategoryDetailCard`. All three are gone, along with
`lib/core/widgets/premium_category_selector.dart`,
`lib/core/services/category_manager.dart` and
`lib/features/onboarding/screens/category_selection_screen.dart` — the whole
category-selection concept was removed with the slim-to-core-features cut. The
guide also taught `AppColors` (deleted), "glassmorphism" (removed with the flat
Calm Clarity pass) and `TextStyle(fontSize: 20)` / `EdgeInsets.all(24)` as the
recommended idiom, which is now the exact opposite of the house rules. It is the
first file a new contributor opens in this folder, so it is a pointer instead.

## Tokens — `lib/core/design/`

One import, `app_design.dart`, re-exports all of them.

| Need | Use |
| --- | --- |
| Type | `Theme.of(context).textTheme.*` — the scale lives in `app_typography.dart`. **11pt is the floor**; never a raw `TextStyle` with a `fontSize`. |
| Colour | `AppColorsExt.of(context)` → `ext.textPrimary`, `ext.surface`, `ext.mark(swatch)`, and the AA-verified `ext.fillBg(swatch)` / `ext.fillFg(swatch)` pair. Never `Colors.*` or `Color(0xFF…)` in a feature file. |
| Radius | `AppRadius.brSm/brMd/brLg/brCard/brSheet` — not `Radius.circular(n)`. |
| Spacing | `AppSpacing.xs…huge`, `AppSpacing.gutter` for the screen edge. |
| Bottom padding of a scrollable | `AppInsets.pushed(context)` or `AppInsets.underNav(context)` — not a magic `SizedBox(height: 100)`. |
| Shadow | `AppShadows.resting/card/elevated(context)`. |
| Feature accent | wrap the feature body in `AccentScope(feature: FeatureAccent.water, …)`; components then resolve it themselves. |

## Components — `lib/core/widgets/app/`

`app_widgets.dart` is the single import, and it re-exports `app_design.dart` too.

- **Page frame:** `AppScaffold`, `AppHeader` (`AppHeader.backButton(context)` is the
  only back arrow in the app), `SectionHeader`, `AppEyebrow`.
- **Surfaces:** `AppCard`, `AppListGroup`, `AppBottomSheet` (`AppBottomSheet.confirm`
  for a yes/no; `ConfirmationBottomSheet` is the destructive-flow adapter over it).
- **Controls:** `AppButton`, `AppIconButton`, `AppFab`, `AppSwitch`, `AppChip`,
  `AppTextField`, `AppSearchField`, `SegmentedToggle`, `AppStepper`, the
  `app_pickers.dart` date/time pickers.
- **Feedback:** `showAppToast` / `context.toast*` (never a raw `SnackBar`),
  `EmptyState`, `AsyncSection`, `PageSkeleton` / `LoadingSkeleton`.
- **Data display:** `StatTile`, `ProgressRing`, `insight_kit.dart`, `TipCard`,
  `CountBadge`, `PersonalBestCard`.

Every one of these carries something a hand-rolled `Container` will not: the AA
contrast pair, the 44pt tap floor, the `Tooltip`, the `Semantics(header: true)`,
the dark-mode surface. Prefer the component; if it genuinely does not fit, extend
it rather than opening a fourth copy.

## Guards

`test/design/design_tokens_guard_test.dart` scans `lib/features/**/{screens,widgets}`
for the deviations above with a per-file allow-list of the offenders that existed
when it was written. The counts may only go down, so a new file that hand-rolls
type, colour or radius fails the suite. `test/responsive/responsive_overflow_test.dart`
(320–428pt × 1.0/1.3/2.0× text) and `test/responsive/touch_target_audit_test.dart`
are the other two that must stay green.
