import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Single source of truth for iconography — Material **Symbols** (Rounded).
///
/// Screens reference SEMANTIC names (`AppIcons.water`, `AppIcons.back`, …). The
/// whole app renders Material Symbols; the optical style is Rounded to match the
/// calm teal-green brand, and FILL is driven by the global `IconTheme`
/// (filled by default) with `fill: 0` set explicitly where an outline-at-rest /
/// fill-on-active affordance is wanted (e.g. the nav bar's inactive tabs).
///
/// Reminder-category icons deliberately stay on the classic MaterialIcons font
/// (see `reminder_category_model.dart`): stored user data is keyed by
/// MaterialIcons codepoints, so those must not move to the Symbols font.
class AppIcons {
  AppIcons._();

  // ── Navigation / chrome ──
  static const IconData back = Symbols.arrow_back_rounded;
  static const IconData close = Symbols.close_rounded;
  static const IconData add = Symbols.add_rounded;
  static const IconData remove = Symbols.remove_rounded;
  static const IconData more = Symbols.more_horiz_rounded;
  static const IconData chevronRight = Symbols.chevron_right_rounded;
  static const IconData chevronLeft = Symbols.chevron_left_rounded;
  static const IconData settings = Symbols.settings_rounded;
  static const IconData edit = Symbols.edit_rounded;
  static const IconData search = Symbols.search_rounded;
  static const IconData refresh = Symbols.refresh_rounded;
  static const IconData info = Symbols.info_rounded;
  static const IconData history = Symbols.history_rounded;
  static const IconData person = Symbols.person_rounded;

  // ── Brand / AI ──
  /// The app's hallmark — a filled/weighted Symbols sparkle.
  static const IconData aiSeal = Symbols.auto_awesome_rounded;

  // ── Domains (feature accents) ──
  static const IconData medicine = Symbols.medication_rounded;
  static const IconData water = Symbols.water_drop_rounded;
  static const IconData sleep = Symbols.bedtime_rounded;
  static const IconData steps = Symbols.directions_walk_rounded;
  // Purpose-built medical glyphs (fixes the old bloodtype/favorite mis-mappings).
  static const IconData bloodPressure = Symbols.cardiology_rounded;
  static const IconData glucose = Symbols.glucose_rounded;
  static const IconData period = Symbols.calendar_month_rounded;
  static const IconData focus = Symbols.self_improvement_rounded;
  static const IconData insights = Symbols.insights_rounded;
  static const IconData streak = Symbols.local_fire_department_rounded;

  // ── Stateful glyphs (explicit two-glyph state; fill handled by IconTheme) ──
  static IconData complete({bool done = false}) => done
      ? Symbols.check_circle_rounded
      : Symbols.radio_button_unchecked_rounded;

  static IconData bell({bool active = false}) => active
      ? Symbols.notifications_active_rounded
      : Symbols.notifications_rounded;
}
