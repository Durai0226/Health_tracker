import 'package:flutter/material.dart';
import 'package:tablet_remainder/core/design/app_colors_ext.dart';

/// The app's colour tokens on a plain Material theme, with none of the
/// `GoogleFonts` text styles `AppTheme.lightTheme` builds.
///
/// For a widget test that hands part of its body to `tester.runAsync`. The
/// project bundles no fonts, so with `GoogleFonts.config.allowRuntimeFetching`
/// off every missing face throws — asynchronously, which `FakeAsync` never lets
/// happen but the real event loop does, as an unhandled zone error that fails
/// whichever test is running.
ThemeData fontFreeTheme() => ThemeData.light()
    .copyWith(extensions: const <ThemeExtension<dynamic>>[AppColorsExt.light]);
