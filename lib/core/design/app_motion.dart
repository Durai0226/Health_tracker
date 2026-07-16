import 'package:flutter/animation.dart';

/// One motion scale. Calm Clarity = restraint: no elastic/bounce in general UI,
/// no infinite idle loops.
class AppMotion {
  AppMotion._();

  static const Duration fast = Duration(milliseconds: 180); // taps, toggles
  static const Duration base = Duration(milliseconds: 260); // tab/segment/expand
  static const Duration slow = Duration(milliseconds: 400); // page/sheet
  static const Duration fill = Duration(milliseconds: 700); // ring/progress sweep

  static const Curve standard = Curves.easeOutCubic; // enter / default
  static const Curve emphasized = Curves.easeInOutCubic; // move / expand
  static const Curve exit = Curves.easeInCubic;
}
