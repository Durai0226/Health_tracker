import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../constants/app_spacing.dart';
import '../../design/app_colors_ext.dart';
import 'app_button.dart';
import 'primitives.dart';

/// The four states every data-backed screen has, and one this app kept getting
/// wrong: **loading is not a zero value.**
///
/// Screens here initialise their data to `const []` and then render "nothing
/// yet" on the first frame, flipping to content once a read lands. The user sees
/// a false empty state on every open — and a screen reader *announces* it. The
/// only structural fix is to make loading a state that cannot be confused with
/// an answer, which is what this widget is for.
///
/// ## Why parts, not an `AsyncSnapshot`
///
/// This takes `isLoading` / `error` / `isEmpty` / `data` separately rather than
/// an `AsyncSnapshot`, because the app's dominant reactive primitive is
/// `ValueNotifier` + `ValueListenableBuilder`, not `FutureBuilder`. A controller
/// exposing a state object can drive this directly; so can a `FutureBuilder`, by
/// unpacking its snapshot at the call site. Taking a snapshot would have forced
/// every `ValueNotifier`-based screen to fake one.
///
/// ## Why [banner] exists
///
/// A permission gate is **not** an alternative to content — it sits above it.
/// Connected Devices must show "we can't read your wearable data" *and* the
/// devices it already knows about, simultaneously. A strict
/// loading|empty|error|data switch cannot express that, so that screen would
/// have hand-rolled its own and this widget would have bought nothing. [banner]
/// renders above the resolved branch in every state except the skeleton.
class AsyncSection<T> extends StatelessWidget {
  const AsyncSection({
    super.key,
    required this.isLoading,
    required this.data,
    required this.builder,
    required this.skeleton,
    this.error,
    this.onRetry,
    this.isEmpty,
    this.empty,
    this.banner,
    this.onRefresh,
    this.errorTitle = "Couldn't load this",
    this.errorMessage = 'Your data is safe — please try again.',
    this.loadingSemanticLabel = 'Loading',
  });

  /// True only before the **first** completed read. A refresh must not set this,
  /// or pull-to-refresh flashes the skeleton it exists to avoid — hold the last
  /// good [data] instead.
  final bool isLoading;

  /// Non-null once a read has completed. When [isLoading] is false and this is
  /// still null, that is treated as an error rather than as emptiness — "we
  /// finished and have nothing at all" is not a state a caller should be able
  /// to express by accident.
  final T? data;

  final Widget Function(BuildContext context, T data) builder;

  /// The page-shaped placeholder. Use [PageSkeleton] unless the page has a
  /// genuinely unusual shape.
  final Widget skeleton;

  /// Set when the read failed. Shown only when there is no [data] to fall back
  /// on — a stale list with a toast beats an error page that throws away
  /// content the user was reading.
  final Object? error;
  final VoidCallback? onRetry;

  /// Distinguishes "loaded, and there is genuinely nothing" from "loaded".
  /// Omit and the empty branch is never taken.
  final bool Function(T data)? isEmpty;
  final Widget? empty;

  /// Rendered above the resolved branch in every state except the skeleton.
  /// Permission gates, partial-load warnings, self-disabled-feature notices.
  final Widget? banner;

  /// Supplying this wraps the content in a `RefreshIndicator`, which is how
  /// "this screen has no way to refresh" stops being possible by construction.
  final Future<void> Function()? onRefresh;

  final String errorTitle;
  final String errorMessage;
  final String loadingSemanticLabel;

  @override
  Widget build(BuildContext context) {
    if (isLoading && data == null) {
      // liveRegion so a screen reader says "Loading" instead of silence — today
      // it announces the false empty state instead.
      return Semantics(
        liveRegion: true,
        label: loadingSemanticLabel,
        child: skeleton,
      );
    }

    final resolved = data;
    if (resolved == null) {
      return _error(context);
    }

    final isEmptyNow = isEmpty?.call(resolved) ?? false;
    final content = isEmptyNow && empty != null ? empty! : builder(context, resolved);

    final withBanner = banner == null
        ? content
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Flexible + a scroll view, not a bare Padding.
              //
              // A banner sitting above an Expanded content area is a fixed row
              // in an unscrollable Column, so a tall banner overflows the
              // Column rather than doing anything sensible. Measured on
              // Connected devices: a card with a title, two sentences and two
              // buttons overflowed by 222px at 320pt / 2.0x Dynamic Type, and
              // by 118px at 360pt.
              //
              // Flexible is loose, so at ordinary sizes the banner still takes
              // exactly its natural height and no scrollbar appears. Only when
              // it genuinely cannot fit does it become scrollable — which is
              // the right degradation for something the user is meant to read
              // and act on, and strictly better than clipping the button they
              // need to press.
              Flexible(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                        AppSpacing.md, AppSpacing.gutter, 0),
                    child: banner,
                  ),
                ),
              ),
              Expanded(child: content),
            ],
          );

    if (onRefresh == null) return withBanner;
    return RefreshIndicator(onRefresh: onRefresh!, child: withBanner);
  }

  Widget _error(BuildContext context) {
    final ext = AppColorsExt.of(context);
    return EmptyState(
      icon: Symbols.error_rounded,
      title: errorTitle,
      message: errorMessage,
      accent: ext.warning,
      action: onRetry == null
          ? null
          : AppButton(
              label: 'Try again',
              variant: AppButtonVariant.tonal,
              onPressed: onRetry,
            ),
    );
  }
}
