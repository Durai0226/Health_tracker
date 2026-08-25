/// One search field, so three screens stop disagreeing about what search is.
///
/// The three existing call sites had drifted in five ways, and the drift was
/// not cosmetic:
///
/// | | clear control | glyph | accessible name | keyboard action |
/// |---|---|---|---|---|
/// | Condition Library | **none** | — | — | **none** |
/// | Medication list | yes | `clear_rounded` | none | search |
/// | Reminders | yes | `close_rounded` | 'Clear search' | search |
///
/// So on the Condition Library you had to backspace a whole query to get back
/// to the full list, and its keyboard offered a newline key instead of a search
/// key. Two screens drew a different glyph for the same act, and two of the
/// three shipped an icon-only button with nothing to announce.
///
/// This is a wrapper over [AppTextField], not a replacement for it. The text
/// field already owns focus colours, the accent, the error slot and the
/// semantics of an input; search is a *configuration* of that, and forking it
/// would double the surface that has to stay in step.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../design/app_design.dart';
import 'primitives.dart';

class AppSearchField extends StatefulWidget {
  final TextEditingController controller;

  /// "Search conditions", "Search reminders". Names what is searched — a bare
  /// "Search" leaves a screen reader announcing an unlabelled box.
  final String hint;

  /// Fired with the current text. With [debounce] set, fired on the trailing
  /// edge only.
  final ValueChanged<String> onChanged;

  final AccentSwatch? accent;

  /// Called when the clear control is used, after the controller is emptied.
  /// Most screens need nothing beyond [onChanged], which also fires with ''.
  final VoidCallback? onCleared;

  /// Trailing-edge debounce. Off by default, deliberately: two of the three
  /// screens adopting this widget filter in-memory lists where per-keystroke
  /// work is imperceptible, and silently adding latency to them would be a
  /// behaviour change smuggled in under a refactor. Screens that do real work
  /// per keystroke opt in.
  final Duration? debounce;

  final FocusNode? focusNode;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  const AppSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.accent,
    this.onCleared,
    this.debounce,
    this.focusNode,
    this.autofocus = false,
    this.onSubmitted,
  });

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // The clear control's presence depends on whether there is text, so this
    // has to rebuild on controller changes it did not itself cause — a
    // programmatic `controller.text = ...` from the parent, or an IME
    // autocorrect commit.
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _timer?.cancel();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _emit(String v) {
    final d = widget.debounce;
    if (d == null) {
      widget.onChanged(v);
      return;
    }
    _timer?.cancel();
    _timer = Timer(d, () {
      if (mounted) widget.onChanged(v);
    });
  }

  void _clear() {
    widget.controller.clear();
    // Cancel any in-flight debounce: emptying the box must take effect at once,
    // or the list keeps showing stale results after the field is visibly empty.
    _timer?.cancel();
    widget.onChanged('');
    widget.onCleared?.call();
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final hasText = widget.controller.text.isNotEmpty;

    return AppTextField(
      controller: widget.controller,
      hint: widget.hint,
      prefixIcon: Symbols.search_rounded,
      accent: widget.accent,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      // A search box's Enter key should say "search", not "newline".
      textInputAction: TextInputAction.search,
      onChanged: _emit,
      onSubmitted: widget.onSubmitted,
      suffix: hasText
          ? IconButton(
              icon: Icon(Symbols.close_rounded,
                  size: 18, color: ext.textTertiary),
              // Not decoration: an icon-only control with no name announces as
              // "button" and nothing else. Two of the three call sites shipped
              // exactly that.
              tooltip: 'Clear search',
              onPressed: _clear,
            )
          : null,
    );
  }
}
