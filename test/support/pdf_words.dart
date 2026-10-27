import 'dart:convert';
import 'dart:io';

/// Every word drawn on every page of a PDF made by the `pdf` package, in order.
///
/// That package writes standard fonts as literal strings, one per word, inside
/// Flate-compressed content streams, with parentheses escaped. Enough to assert
/// what a generated report says without a PDF reader.
List<String> pdfWords(List<int> bytes) {
  final raw = latin1.decode(bytes, allowInvalid: true);
  final words = <String>[];
  final show = RegExp(r'\[\(((?:\\.|[^\\)])*)\)\]TJ');
  for (final m in RegExp(r'stream\r?\n').allMatches(raw)) {
    final end = raw.indexOf('endstream', m.end);
    if (end < 0) continue;
    try {
      final inflated = latin1.decode(
          zlib.decode(bytes.sublist(m.end, end).toList()),
          allowInvalid: true);
      for (final w in show.allMatches(inflated)) {
        words.add(w.group(1)!.replaceAll(r'\(', '(').replaceAll(r'\)', ')'));
      }
    } catch (_) {
      // Not every stream is Flate (fonts, images).
    }
  }
  return words;
}
