import 'dart:ui' show FontFeature;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../design/app_design.dart';
import 'app_bottom_sheet.dart';
import 'app_button.dart';

/// Branded time & date pickers — drop-in replacements for the stock Material
/// `showTimePicker` / `showDatePicker` dialogs, so time/date entry stays inside
/// the app's bottom-sheet design language instead of jumping to a grey clock.
class AppTimePicker {
  /// Mirrors `showTimePicker(context: …, initialTime: …)` → returns the picked
  /// [TimeOfDay], or null if cancelled. [minuteInterval] snaps the minute wheel
  /// (e.g. 5 for reminders, 1 for exact dose times).
  static Future<TimeOfDay?> show(
    BuildContext context, {
    TimeOfDay? initial,
    AccentSwatch? accent,
    String title = 'Select time',
    int minuteInterval = 1,
  }) {
    final acc = accent ?? AccentScope.swatchOf(context);
    return AppBottomSheet.show<TimeOfDay>(
      context,
      title: title,
      icon: Symbols.schedule_rounded,
      accent: acc,
      builder: (_) => _TimeBody(
        initial: initial ?? TimeOfDay.now(),
        accent: acc,
        minuteInterval: minuteInterval,
      ),
    );
  }
}

/// Reference-quality wheel (Apple's tuned physics/magnifier) inside our branded
/// sheet, anchored by a large live readout. AM/PM is the picker's own inline
/// third column, so it can never collide with the selection band.
class _TimeBody extends StatefulWidget {
  final TimeOfDay initial;
  final AccentSwatch accent;
  final int minuteInterval;
  const _TimeBody({
    required this.initial,
    required this.accent,
    required this.minuteInterval,
  });

  @override
  State<_TimeBody> createState() => _TimeBodyState();
}

class _TimeBodyState extends State<_TimeBody> {
  late DateTime _seed;
  late TimeOfDay _picked;

  @override
  void initState() {
    super.initState();
    var m = widget.initial.minute;
    if (widget.minuteInterval > 1) m -= m % widget.minuteInterval;
    final now = DateTime.now();
    _seed = DateTime(now.year, now.month, now.day, widget.initial.hour, m);
    _picked = TimeOfDay(hour: widget.initial.hour, minute: m);
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final use24 = MediaQuery.of(context).alwaysUse24HourFormat;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _readout(ext, tt, use24),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: 200,
          child: CupertinoTheme(
            data: CupertinoThemeData(
              brightness: ext.isDark ? Brightness.dark : Brightness.light,
              primaryColor: ext.mark(widget.accent),
              textTheme: CupertinoTextThemeData(
                dateTimePickerTextStyle: (tt.titleLarge ?? const TextStyle())
                    .copyWith(
                  color: ext.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              use24hFormat: use24,
              minuteInterval: widget.minuteInterval,
              initialDateTime: _seed,
              backgroundColor: Colors.transparent,
              onDateTimeChanged: (dt) =>
                  setState(() => _picked = TimeOfDay.fromDateTime(dt)),
              // One continuous brand capsule spanning hour · minute · AM/PM.
              // Translucent tint so the SELECTED (centred) values stay legible
              // on top — an opaque fill would hide them.
              selectionOverlayBuilder: (ctx,
                      {required int columnCount, required int selectedIndex}) =>
                  CupertinoPickerDefaultSelectionOverlay(
                background: widget.accent.base
                    .withValues(alpha: ext.isDark ? 0.24 : 0.15),
                capStartEdge: selectedIndex == 0,
                capEndEdge: selectedIndex == columnCount - 1,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Cancel',
                variant: AppButtonVariant.secondary,
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppButton(
                label: 'Set time',
                accent: widget.accent,
                onPressed: () => Navigator.pop(context, _picked),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _readout(AppColorsExt ext, TextTheme tt, bool use24) {
    final mm = _picked.minute.toString().padLeft(2, '0');
    final hh = use24
        ? _picked.hour.toString().padLeft(2, '0')
        : '${_picked.hourOfPeriod == 0 ? 12 : _picked.hourOfPeriod}';
    final period = _picked.period == DayPeriod.am ? 'AM' : 'PM';
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            '$hh:$mm',
            style: tt.displayMedium?.copyWith(
              color: ext.textPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (!use24) ...[
            const SizedBox(width: 8),
            Text(
              period,
              style: tt.titleMedium?.copyWith(
                color: ext.mark(widget.accent),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AppDatePicker {
  /// Mirrors `showDatePicker(context: …, initialDate: …, firstDate: …, lastDate: …)`.
  static Future<DateTime?> show(
    BuildContext context, {
    DateTime? initial,
    DateTime? first,
    DateTime? last,
    AccentSwatch? accent,
    String title = 'Select date',
  }) {
    final acc = accent ?? AccentScope.swatchOf(context);
    final init = initial ?? DateTime.now();
    final lo = first ?? DateTime(init.year - 5);
    final hi = last ?? DateTime(init.year + 5);
    final clamped = init.isBefore(lo) ? lo : (init.isAfter(hi) ? hi : init);
    return AppBottomSheet.show<DateTime>(
      context,
      title: title,
      icon: Symbols.calendar_month_rounded,
      accent: acc,
      builder: (_) =>
          _DateBody(initial: clamped, first: lo, last: hi, accent: acc),
    );
  }
}

class _DateBody extends StatefulWidget {
  final DateTime initial;
  final DateTime first;
  final DateTime last;
  final AccentSwatch accent;
  const _DateBody({
    required this.initial,
    required this.first,
    required this.last,
    required this.accent,
  });

  @override
  State<_DateBody> createState() => _DateBodyState();
}

class _DateBodyState extends State<_DateBody> {
  late DateTime _selected = widget.initial;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    // Brand the stock calendar grid so its header/selection use the feature
    // accent instead of the default Material primary.
    final themed = base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: widget.accent.base,
        onPrimary: widget.accent.on,
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Theme(
          data: themed,
          child: CalendarDatePicker(
            initialDate: _selected,
            firstDate: widget.first,
            lastDate: widget.last,
            onDateChanged: (d) => setState(() => _selected = d),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Cancel',
                variant: AppButtonVariant.secondary,
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppButton(
                label: 'Set date',
                accent: widget.accent,
                onPressed: () => Navigator.pop(context, _selected),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
