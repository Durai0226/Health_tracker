import 'package:flutter/material.dart';

/// Helper class to get IconData from codePoint without breaking tree-shaking.
/// Uses a static method that the tree-shaker can analyze.
class IconHelper {
  /// Get an Icon widget directly from a codePoint
  static Icon getIcon(int codePoint, {Color? color, double? size}) {
    return Icon(
      IconData(codePoint, fontFamily: 'MaterialIcons'),
      color: color,
      size: size,
    );
  }
}
