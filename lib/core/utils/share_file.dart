import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

/// Hand [file] to the system share sheet — the one place this app calls the
/// sharing package.
///
/// Five exports — the backup, the emergency card, the medicine log, the water
/// statistics and the reminder history — each wrote a temp file and then called
/// `Share.shareXFiles`, which the package has deprecated for
/// `SharePlus.instance.share`. Five copies are five migrations, and the next
/// change to the package (or to how the sheet is positioned on an iPad) would have
/// been made in some of them.
///
/// Writing the file stays with each export: what is in it, and how it is encoded,
/// is theirs. [mimeType] names it for the apps in the sheet, [text] is the message
/// beside it, and [subject] is the subject line of a mail. Nothing here is awaited
/// for an answer: whether the person completed the share is the sheet's business.
Future<void> shareFile(File file, {String? mimeType, String? text, String? subject}) async {
  final params = ShareParams(
    files: [XFile(file.path, mimeType: mimeType)],
    text: text,
    subject: subject,
  );
  final seam = shareParamsForTesting;
  if (seam != null) return seam(params);
  await SharePlus.instance.share(params);
}

/// Stands in for the share sheet, which cannot be opened headless: receives what
/// [shareFile] would have handed to it.
@visibleForTesting
Future<void> Function(ShareParams params)? shareParamsForTesting;
