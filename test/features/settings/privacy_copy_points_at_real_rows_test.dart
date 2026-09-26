/// Copy that tells the user where to go has to name a place that is there.
///
/// The health-data disclosure sends the user to Settings to delete their data,
/// and it named 'Settings → Clear all data' — a row that has never existed in
/// this app. The row is 'Delete all data', and it is local-only, while the copy
/// also promised it removed the account copy.
///
/// So this is not a spell-check of a string: every 'Settings → …' reference the
/// disclosure renders is matched against the row titles actually declared in
/// `settings_screen.dart`. Renaming a row there without fixing the disclosure
/// fails here, which is the direction the rot travels.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/settings/screens/health_privacy_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Every `title: '…'` declared in the Settings screen.
  Set<String> settingsRowTitles() {
    final src =
        File('lib/features/settings/screens/settings_screen.dart').readAsStringSync();
    return RegExp(r"title: '([^']+)'")
        .allMatches(src)
        .map((m) => m.group(1)!)
        .toSet();
  }

  testWidgets('every "Settings → …" the disclosure prints is a row that exists',
      (tester) async {
    // Tall enough that the whole ListView is built — a row that is not in the
    // tree is a reference this test would never read.
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const HealthPrivacyScreen(),
    ));
    await tester.pumpAndSettle();

    final titles = settingsRowTitles();
    expect(titles.length, greaterThan(10),
        reason: 'the source scan found almost no rows — it is reading nothing '
            'and would pass whatever the disclosure said');

    const marker = 'Settings → ';
    final references = <String>[];
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      final data = text.data;
      if (data == null) continue;
      for (var i = data.indexOf(marker); i >= 0;
          i = data.indexOf(marker, i + 1)) {
        references.add(data.substring(i + marker.length));
      }
    }

    expect(references, isNotEmpty,
        reason: 'the disclosure no longer points anywhere — this test would '
            'pass vacuously');

    for (final reference in references) {
      expect(titles.any(reference.startsWith), isTrue,
          reason: 'the disclosure sends the user to "Settings → '
              '${reference.split(RegExp(r'[;.]')).first.trim()}", and no such '
              'row exists in settings_screen.dart');
    }
  });

  testWidgets('the local wipe is not credited with clearing the cloud copy',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const HealthPrivacyScreen(),
    ));
    await tester.pumpAndSettle();

    final delete = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .firstWhere((s) => s.contains('Settings → '),
            orElse: () => fail('the disclosure points nowhere at all'));

    // 'Delete all data' wipes local Drift rows and nothing else; the account
    // and its backups go only through 'Delete account'. Naming one and
    // describing the other is how the old copy promised an erasure that never
    // happened.
    expect(delete, contains('Delete account'),
        reason: 'the disclosure claims the cloud copy goes too, so it has to '
            'name the row that is actually able to do that');
  });
}
