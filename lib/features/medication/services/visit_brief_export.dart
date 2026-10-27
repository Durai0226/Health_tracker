import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';

/// Hands the brief to the share sheet. The app uploads nothing: the OS decides
/// where it goes.
class VisitBriefExport {
  const VisitBriefExport._();

  /// Test seam: a widget test has no share sheet.
  @visibleForTesting
  static Future<void> Function(Uint8List bytes, String filename)? shareOverride;

  static Future<void> sharePdf(Uint8List bytes, String filename) async {
    final override = shareOverride;
    if (override != null) return override(bytes, filename);
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  /// `visit-brief-dr-anand-2026-06-25.pdf`
  static String filenameFor(String doctorName, DateTime visit) {
    final slug = doctorName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    String two(int n) => n.toString().padLeft(2, '0');
    final day = '${visit.year}-${two(visit.month)}-${two(visit.day)}';
    return slug.isEmpty ? 'visit-brief-$day.pdf' : 'visit-brief-$slug-$day.pdf';
  }
}
