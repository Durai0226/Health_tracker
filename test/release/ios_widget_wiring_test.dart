import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The iOS widget's App Group identifier appears in FOUR places that must agree
/// exactly, and a mismatch fails in the worst possible way: the extension
/// compiles, signs, installs and runs, reading an empty container forever. No
/// error, no crash, just a widget that always says 0 ml.
///
/// The same goes for the WidgetKit `kind` string and the quick-add queue key,
/// which are the other two cross-language contracts here.
void main() {
  String read(String p) => File(p).readAsStringSync();

  late String swift, runnerEnt, widgetEnt, dart;

  setUpAll(() {
    swift = read('ios/WaterWidget/WaterWidget.swift');
    runnerEnt = read('ios/Runner/Runner.entitlements');
    widgetEnt = read('ios/WaterWidget/WaterWidget.entitlements');
    dart = read('lib/core/services/home_widget_service.dart');
  });

  const appGroup = 'group.com.implementation.tabletremainder.tabletRemainder';

  test('all four places agree on the App Group id', () {
    for (final entry in {
      'WaterWidget.swift': () => swift,
      'Runner.entitlements': () => runnerEnt,
      'WaterWidget.entitlements': () => widgetEnt,
      'home_widget_service.dart': () => dart,
    }.entries) {
      expect(entry.value(), contains(appGroup),
          reason: '${entry.key} does not declare the shared App Group — the '
              'widget would read an empty container, silently');
    }
  });

  test('the WidgetKit kind matches on both sides', () {
    // Dart passes this as iOSName; a mismatch means updateWidget reloads
    // nothing and the widget shows stale data until iOS refreshes it itself.
    expect(swift, contains('let kind = "WaterWidget"'));
    expect(dart, contains("_iosWidgetName = 'WaterWidget'"));
  });

  test('the quick-add queue key matches on both sides', () {
    expect(swift, contains('queueKey = "widgetWaterQueue"'));
    expect(dart, contains("_iosQueueKey = 'widgetWaterQueue'"));
  });

  test('the widget does NOT write to the shared_preferences key', () {
    // On iOS shared_preferences reads UserDefaults.standard, not the App Group
    // suite. Writing `flutter.pending_water_actions` from the extension would
    // land somewhere the app never looks.
    // Checks actual USE, not mentions — the file documents at length why it
    // avoids that key, so a plain `contains` would match the explanation.
    expect(swift, isNot(contains('forKey: "flutter.')),
        reason: 'the extension cannot reach shared_preferences storage');
    expect(swift, isNot(contains('stringArray(forKey:')),
        reason: 'home_widget bridges scalars, not arrays');
  });

  test('the extension is registered as a target and embedded', () {
    final pbx = read('ios/Runner.xcodeproj/project.pbxproj');
    expect(pbx, contains('WaterWidget.appex'));
    expect(pbx, contains('com.apple.product-type.app-extension'));
    expect(pbx, contains('Embed Foundation Extensions'));
    // The embed must precede Thin Binary, which rewrites the binary — an
    // extension copied in afterwards is not re-signed and the app is rejected.
    expect(pbx.indexOf('Embed Foundation Extensions */,'),
        lessThan(pbx.indexOf('Thin Binary */,')));
  });

  test('a fluid-restricted user is never offered one-tap "+250" on iOS', () {
    expect(swift, contains('!entry.restricted'));
  });
}
