import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The DailyMinder brand mark — always sourced from the real assets so the logo
/// is consistent everywhere it appears.
///
/// - [AppLogo.mark]  → the icon mark (`logo_icon.svg`), natural or tinted.
/// - [AppLogo.full]  → icon + wordmark art (`logo.svg`).
/// - [AppLogo.raster]→ PNG fallback (`logo.png`) for contexts where SVG isn't ideal.
class AppLogo extends StatelessWidget {
  final double size;
  final Color? color;
  final double radius;
  final String _asset;
  final bool _raster;

  const AppLogo.mark({super.key, this.size = 48, this.color, this.radius = 0})
      : _asset = 'assets/images/logo_icon.svg',
        _raster = false;

  const AppLogo.full({super.key, this.size = 96, this.color, this.radius = 0})
      : _asset = 'assets/images/logo.svg',
        _raster = false;

  const AppLogo.raster({super.key, this.size = 96, this.radius = 0})
      : _asset = 'assets/images/logo.png',
        color = null,
        _raster = true;

  @override
  Widget build(BuildContext context) {
    final Widget logo = _raster
        ? Image.asset(_asset, width: size, height: size, fit: BoxFit.contain)
        : SvgPicture.asset(
            _asset,
            width: size,
            height: size,
            colorFilter:
                color != null ? ColorFilter.mode(color!, BlendMode.srcIn) : null,
          );
    if (radius > 0) {
      return ClipRRect(borderRadius: BorderRadius.circular(radius), child: logo);
    }
    return logo;
  }
}
