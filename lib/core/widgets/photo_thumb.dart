import 'dart:io';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../services/photo_store.dart';
import 'app/app_widgets.dart';

/// A kept photo as a small rounded square — or, when the file is not there, a plain
/// "not on this phone" square, never an error.
///
/// A photo is not part of a backup, so after a restore on another phone every path
/// points at nothing; and a file can be deleted from outside the app. Both are
/// ordinary, and both must read as "no photo here" rather than as a red box.
class PhotoThumb extends StatelessWidget {
  const PhotoThumb({
    super.key,
    required this.path,
    this.size = 72,
    this.onTap,
    this.label = 'Photo',
  });

  final String? path;
  final double size;

  /// Called on a tap, when there is a photo to open.
  final VoidCallback? onTap;

  /// What a screen reader says for it.
  final String label;

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final file = PhotoStore.resolve(path);
    final present = file != null;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    final Widget child = present
        ? Image.file(
            File(file),
            width: size,
            height: size,
            fit: BoxFit.cover,
            // Decoded at the size it is shown: a 1600 px photo in a 72 px square
            // would otherwise sit in memory at full size.
            cacheWidth: (size * dpr).round(),
            errorBuilder: (_, _, _) => _missing(ext),
          )
        : _missing(ext);

    final tappable = present && onTap != null;
    Widget thumb = ClipRRect(
      borderRadius: AppRadius.brMd,
      child: SizedBox(width: size, height: size, child: child),
    );
    // A small thumbnail that opens something still gets the touch-target floor.
    if (tappable && size < _minTarget) {
      thumb = SizedBox(
          width: _minTarget, height: _minTarget, child: Center(child: thumb));
    }

    return Semantics(
      button: tappable,
      image: true,
      label: present ? label : '$label — not on this phone',
      // The child's own tap is dropped by excludeSemantics, so a screen reader's
      // double-tap needs its own.
      onTap: tappable ? onTap : null,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tappable ? onTap : null,
        child: thumb,
      ),
    );
  }

  static const double _minTarget = 44;

  Widget _missing(AppColorsExt ext) => ColoredBox(
        color: ext.surfaceVariant,
        child: Icon(Symbols.image_not_supported_rounded,
            color: ext.textTertiary, size: size * 0.4),
      );
}

/// Show the photo at [path] full screen, to pinch and look at.
Future<void> showPhotoViewer(BuildContext context, String path,
    {String label = 'Photo'}) {
  final file = PhotoStore.resolve(path);
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              maxScale: 5,
              child: Center(
                child: file != null
                    ? Image.file(File(file), semanticLabel: label)
                    : const Icon(Symbols.image_not_supported_rounded,
                        color: Colors.white54, size: 64),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: AppIconButton(
                icon: Symbols.close_rounded,
                filled: false,
                tooltip: 'Close',
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// What the person chose to do about a photo.
enum PhotoAction { camera, gallery, remove }

/// Ask what to do about a photo: take one, choose one, or — when there is one — remove
/// it. Null when the sheet was dismissed.
Future<PhotoAction?> choosePhotoAction(
  BuildContext context, {
  required bool hasPhoto,
  required AccentSwatch accent,
  String title = 'Photo',
}) {
  final ext = AppColorsExt.of(context);
  return AppBottomSheet.show<PhotoAction>(
    context,
    title: title,
    icon: Symbols.photo_camera_rounded,
    accent: accent,
    builder: (sheetCtx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppListTile(
          icon: Symbols.photo_camera_rounded,
          title: 'Take a photo',
          accent: accent,
          onTap: () => Navigator.of(sheetCtx).pop(PhotoAction.camera),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppListTile(
          icon: Symbols.photo_library_rounded,
          title: 'Choose from gallery',
          accent: accent,
          onTap: () => Navigator.of(sheetCtx).pop(PhotoAction.gallery),
        ),
        if (hasPhoto) ...[
          const SizedBox(height: AppSpacing.sm),
          AppListTile(
            icon: Symbols.delete_rounded,
            title: 'Remove photo',
            accent: ext.error,
            onTap: () => Navigator.of(sheetCtx).pop(PhotoAction.remove),
          ),
        ],
      ],
    ),
  );
}

