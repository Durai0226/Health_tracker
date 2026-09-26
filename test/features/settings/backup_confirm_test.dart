import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_bottom_sheet.dart';
import 'package:tablet_remainder/features/settings/screens/backup_screen.dart';

/// DS-13 — the two backup confirmations moved from `AlertDialog` to
/// `ConfirmationBottomSheet`, and the one thing that MUST survive that move is
/// the answer they return.
///
/// Restore overwrites every row on the device and delete destroys a cloud
/// backup, so both directions are fatal: a confirmed sheet that reports "no"
/// silently turns the button into a no-op, and a dismissed sheet that reports
/// "yes" runs a destructive action nobody agreed to. The dialogs returned
/// `bool?` and the call sites read `confirm != true`; the sheets return `bool?`
/// too, and [BackupScreen.confirmRestore] / [BackupScreen.confirmDelete] are
/// where that null now collapses.
///
/// The screen itself is not pumped: its state builds a `BackupService`, which
/// resolves `FirebaseFirestore.instance` in its constructor, and `flutter test`
/// has no Firebase app. The confirmations are static for exactly that reason,
/// so what runs below is the shipped code and not a copy of it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  /// Opens one confirmation, lets [answer] respond to it, and returns how many
  /// times the destructive action ran — the call-site branch, verbatim.
  Future<int> run(
    WidgetTester tester,
    Future<bool> Function(BuildContext) confirm, {
    required Future<void> Function() answer,
  }) async {
    var performed = 0;

    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              if (!await confirm(context)) return;
              performed++;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(AppBottomSheet), findsOneWidget,
        reason: 'the confirmation never opened, so nothing below proves '
            'anything about consent');

    await answer();
    await tester.pumpAndSettle();
    expect(find.byType(AppBottomSheet), findsNothing);
    return performed;
  }

  /// Tapping the scrim — the sheet's version of the dismissible barrier both
  /// AlertDialogs left at its default.
  Future<void> dismiss(WidgetTester tester) =>
      tester.tapAt(const Offset(195, 20));

  Future<void> tapLabel(WidgetTester tester, String label) =>
      tester.tap(find.text(label));

  group('restore confirmation', () {
    testWidgets('dismissing it does NOT restore', (tester) async {
      final performed = await run(tester, BackupScreen.confirmRestore,
          answer: () => dismiss(tester));
      expect(performed, 0);
    });

    testWidgets('cancelling it does NOT restore', (tester) async {
      final performed = await run(tester, BackupScreen.confirmRestore,
          answer: () => tapLabel(tester, 'Cancel'));
      expect(performed, 0);
    });

    testWidgets('confirming it DOES restore', (tester) async {
      final performed = await run(tester, BackupScreen.confirmRestore,
          answer: () => tapLabel(tester, 'Restore'));
      expect(performed, 1);
    });

    testWidgets('still says it overwrites everything', (tester) async {
      await run(tester, BackupScreen.confirmRestore, answer: () async {
        // The wording is the warning; it moved verbatim off the AlertDialog.
        expect(find.text('Restore Backup?'), findsOneWidget);
        expect(
            find.textContaining('OVERWRITE all current data'), findsOneWidget);
        await dismiss(tester);
      });
    });
  });

  /// The two groups above prove the ANSWER; this one proves the shipped call
  /// sites still act on it.
  ///
  /// [BackupScreen.confirmRestore] / [confirmDelete] are static precisely
  /// because `_BackupScreenState` cannot be pumped — `BackupService`'s field
  /// initialiser reaches `FirebaseFirestore.instance`, so `pumpWidget` throws
  /// `[core/no-app]` (the same reason `responsive_overflow_test` allow-lists
  /// `backup` in its build-error list). That leaves one line per action
  /// unexecuted by any test: the `!` in front of the await. Dropping it inverts
  /// the action — delete runs when you cancel and does nothing when you
  /// confirm — and every widget test above still passes, so the gate is read
  /// off the source instead.
  group('the shipped call sites gate on it', () {
    final src =
        File('lib/features/settings/screens/backup_screen.dart').readAsStringSync();

    /// The body of one `Future<void> _name(...) async { … }`, up to the next
    /// member at the same indent.
    String bodyOf(String name) {
      final start = src.indexOf('Future<void> $name(');
      expect(start, isNot(-1), reason: '$name is gone — rename or deletion?');
      final end = RegExp(r'\n  (?:@override\n  )?(?:Future|void|Widget|String|bool)[<\s]')
          .firstMatch(src.substring(start + 1));
      return end == null
          ? src.substring(start)
          : src.substring(start, start + 1 + end.start);
    }

    void gates(String method, String confirm, String action) {
      final body = bodyOf(method);
      final gate = RegExp(
          'if\\s*\\(\\s*!\\s*await\\s+BackupScreen\\.$confirm\\(context\\)\\s*\\)\\s*return;');
      final m = gate.firstMatch(body);
      expect(m, isNotNull,
          reason: '$method no longer refuses on a declined $confirm. The gate '
              'must stay `if (!await BackupScreen.$confirm(context)) return;` — '
              'without the `!` the action runs on cancel and is a no-op on '
              'confirm, and nothing else in this file can catch that.');
      final act = body.indexOf(action);
      expect(act, isNot(-1), reason: '$action moved out of $method');
      expect(m!.start, lessThan(act),
          reason: '$action now runs BEFORE the confirmation is read');
    }

    test('_restoreBackup refuses unless confirmRestore says yes', () {
      gates('_restoreBackup', 'confirmRestore', '_backupService.restoreBackup(');
    });

    test('_deleteBackup refuses unless confirmDelete says yes', () {
      gates('_deleteBackup', 'confirmDelete', '_backupService.deleteBackup(');
    });
  });

  group('delete confirmation', () {
    testWidgets('dismissing it does NOT delete', (tester) async {
      final performed = await run(tester, BackupScreen.confirmDelete,
          answer: () => dismiss(tester));
      expect(performed, 0);
    });

    testWidgets('cancelling it does NOT delete', (tester) async {
      final performed = await run(tester, BackupScreen.confirmDelete,
          answer: () => tapLabel(tester, 'Cancel'));
      expect(performed, 0);
    });

    testWidgets('confirming it DOES delete', (tester) async {
      final performed = await run(tester, BackupScreen.confirmDelete,
          answer: () => tapLabel(tester, 'Delete'));
      expect(performed, 1);
    });

    testWidgets('keeps the dialog title and message', (tester) async {
      await run(tester, BackupScreen.confirmDelete, answer: () async {
        expect(find.text('Delete Backup?'), findsOneWidget);
        expect(find.text('Are you sure you want to delete this backup?'),
            findsOneWidget);
        await dismiss(tester);
      });
    });
  });
}
