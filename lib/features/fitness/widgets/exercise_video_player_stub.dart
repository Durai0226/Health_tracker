import 'package:flutter/material.dart';

/// Stub implementation for non-web platforms
/// Returns a placeholder widget since iframe is web-only
Widget buildYouTubeIframe(String videoId, String embedUrl) {
  return const Center(
    child: Text('Video player not available on this platform'),
  );
}
