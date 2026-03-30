import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

/// Track registered view types to avoid duplicate registration
final Set<String> _registeredViewTypes = {};

/// Web implementation using HtmlElementView with iframe
Widget buildYouTubeIframe(String videoId, String embedUrl) {
  final String viewType = 'youtube-player-$videoId';
  
  // Register the view factory only once per video ID
  if (!_registeredViewTypes.contains(viewType)) {
    _registeredViewTypes.add(viewType);
    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) {
        final iframe = html.IFrameElement()
          ..src = embedUrl
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share'
          ..allowFullscreen = true;
        return iframe;
      },
    );
  }

  return HtmlElementView(viewType: viewType);
}
