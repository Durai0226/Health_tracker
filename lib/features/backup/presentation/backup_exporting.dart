import 'package:flutter/material.dart';

import '../services/backup_service.dart';
import 'widgets/passphrase_sheet.dart';

/// "Make a backup and hand it to the share sheet", for the two screens that offer
/// it — Settings' "Export a copy" and Backup & Restore's "Create backup".
///
/// Each had its own copy of the whole flow: ask for a passphrase, make the file,
/// share it, and say one of three things. What differs is the screen's own state
/// and how it speaks, which it supplies; the order of events and the words are here
/// once, so a change to either cannot be made in one place and forgotten in the
/// other.
mixin BackupExporting<T extends StatefulWidget> on State<T> {
  /// The service that makes and shares the file.
  BackupService get exportService;

  /// Whether this screen is busy — with an export, or with whatever else it must not
  /// be interrupted by. Its own buttons show it.
  bool get exportBusy;

  /// Mark this screen busy with an export, or not.
  void setExportBusy(bool busy);

  /// Say how it went, in the screen's own way.
  void reportExport(String message, {required bool isError});

  /// How a failure starts: "Backup failed", "Export failed".
  String get exportFailureLead;

  /// Called when the file is about to be made — before anything slow. A tap's
  /// haptic, say.
  void exportStarted() {}

  bool _askingForPassphrase = false;

  /// Make the backup, share it, and say how it went. With [encrypted], a passphrase
  /// is chosen first and the file is sealed with it.
  Future<void> exportBackup({bool encrypted = false}) async {
    if (exportBusy || _askingForPassphrase) return;
    String? passphrase;
    if (encrypted) {
      // Chosen BEFORE anything is made, with the warning that it cannot be
      // recovered, so nobody finds that out from a file they cannot open. Guarded
      // while the sheet is up: a second tap on the row must not open a second one.
      _askingForPassphrase = true;
      try {
        passphrase = await PassphraseSheet.askNew(context);
      } finally {
        _askingForPassphrase = false;
      }
      if (passphrase == null || !mounted) return;
    }
    setExportBusy(true);
    exportStarted();
    try {
      final file = await exportService.createBackup(passphrase: passphrase);
      if (!mounted) return;
      if (file != null) {
        await exportService.shareBackup(file);
        if (!mounted) return;
        reportExport(
            passphrase == null
                ? 'Backup ready to share.'
                : 'Encrypted backup ready to share. Keep the passphrase safe.',
            isError: false);
      } else {
        reportExport('Could not create the backup file.', isError: true);
      }
    } catch (e) {
      if (mounted) reportExport('$exportFailureLead: $e', isError: true);
    } finally {
      if (mounted) setExportBusy(false);
    }
  }
}
