import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Turns the card on screen into a picture to share or to set as a lock screen.
class EmergencyCardExport {
  const EmergencyCardExport._();

  /// Sharper than the screen, so the type is still crisp when it is cropped to
  /// a wallpaper.
  static const double pixelRatio = 3;

  /// Test seam: widget tests have no share sheet. Receives the PNG and the card
  /// as text; always null in a real build.
  @visibleForTesting
  static Future<void> Function(Uint8List png, String text)? shareOverride;

  /// The PNG of what [boundaryKey]'s `RepaintBoundary` is showing, or null when
  /// it is not on screen.
  static Future<Uint8List?> capture(GlobalKey boundaryKey) async {
    final object = boundaryKey.currentContext?.findRenderObject();
    if (object is! RenderRepaintBoundary) return null;
    final image = await object.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  }

  /// Open the share sheet with the picture and the card as text beside it, for
  /// whoever cannot open the picture.
  static Future<void> share(Uint8List png, String text) async {
    final override = shareOverride;
    if (override != null) return override(png, text);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/emergency-card.png');
    await file.writeAsBytes(png, flush: true);
    await Share.shareXFiles([XFile(file.path, mimeType: 'image/png')], text: text);
  }
}
