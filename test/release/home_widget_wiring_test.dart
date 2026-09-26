import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The home-screen widget's "+250" button spans four files that have to agree,
/// and every way they can disagree fails **silently** — the button renders,
/// the tap does nothing, and no error surfaces anywhere:
///
///   1. the layout declares `@+id/water_add`
///   2. the Kotlin provider binds a PendingIntent to that id
///   3. our manifest declares `HomeWidgetBackgroundReceiver` — the plugin's own
///      manifest is bare (`<manifest package="es.antonborri.home_widget" />`)
///      and declares no components at all
///   4. Dart registers an interactivity callback at start-up
///
/// A device is the only way to catch a break at runtime, and there is no
/// emulator in the headless suite. Checking the four files still reference each
/// other is cheap and catches the realistic regression: someone renames an id,
/// or strips a manifest entry they think is unused.
void main() {
  String read(String p) => File(p).readAsStringSync();

  late String layout, provider, manifest, service, main;

  setUpAll(() {
    layout = read('android/app/src/main/res/layout/steps_sleep_widget.xml');
    provider = read(
        'android/app/src/main/kotlin/com/dlyminder/app/StepsSleepWidgetProvider.kt');
    manifest = read('android/app/src/main/AndroidManifest.xml');
    service = read('lib/core/services/home_widget_service.dart');
    main = read('lib/main.dart');
  });

  test('the layout declares the water views the provider binds', () {
    for (final id in ['water_value', 'water_progress', 'water_add']) {
      expect(layout, contains('@+id/$id'), reason: 'layout is missing $id');
      expect(provider, contains('R.id.$id'),
          reason: 'the provider never binds $id');
    }
  });

  test('the quick-add button is wired to a background broadcast', () {
    expect(provider, contains('HomeWidgetBackgroundIntent.getBroadcast'));
    expect(provider, contains('dlyminder://water/log'));
  });

  test('the manifest declares the plugin receiver and service', () {
    // Without these the broadcast is delivered to nothing.
    expect(manifest,
        contains('es.antonborri.home_widget.HomeWidgetBackgroundReceiver'));
    expect(manifest,
        contains('es.antonborri.home_widget.action.BACKGROUND'));
    expect(manifest,
        contains('es.antonborri.home_widget.HomeWidgetBackgroundService'));
  });

  test('Dart registers a callback that matches the intent URI', () {
    expect(service, contains('registerInteractivityCallback'));
    expect(service, contains("uri.host != 'water'"),
        reason: 'the callback must recognise the host the Kotlin sends');
    expect(service, contains("@pragma('vm:entry-point')"),
        reason: 'a background isolate cannot find an unannotated entry point');
    expect(main, contains('HomeWidgetService.init()'),
        reason: 'registering the callback at start-up is what makes the '
            'button live; without it the isolate starts and finds nothing');
  });

  test('a fluid-restricted user is never offered one-tap "+250"', () {
    // Offering a quick-add to someone told to limit their intake is the exact
    // harm the restriction mode exists to prevent.
    expect(provider, contains('waterRestricted'));
    expect(provider, contains('View.GONE'));
    expect(service, contains('waterRestricted'));
  });

  test('the Quick Settings tile honours the fluid limit too', () {
    // The home-screen widget hid its "+250" button, but the Quick Settings
    // tile — a LOWER-friction surface, one tap from the shade with no dial,
    // no total and no warning in sight — read none of that state and offered
    // the same quick-add unconditionally.
    final tile = File('android/app/src/main/kotlin/com/dlyminder/app/'
            'WaterQuickSettingsTile.kt')
        .readAsStringSync();
    expect(tile, contains('waterRestricted'),
        reason: 'the tile must read the flag the app already publishes');
    expect(tile, contains('STATE_UNAVAILABLE'),
        reason: 'an unavailable tile is the platform way to say "not now"');
    expect(tile, contains('Fluid limit set'),
        reason: 'the label must say why, not just go dead');
    // The click path must bail as well: the tile can be stale if the limit was
    // set while the shade was already open.
    final click = tile.substring(tile.indexOf('override fun onClick'));
    expect(click, contains('if (isFluidRestricted()) return'),
        reason: 'STATE_UNAVAILABLE alone leaves a stale-tile race');
  });
}
