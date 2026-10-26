import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/insights/screens/proactive_nudge.dart';

/// INS-06 — the nudge used to `Navigator.push` a second TrendsDashboardScreen
/// over the Trends TAB the user already had, so Back returned to Trends again.
///
/// The shell owns the tab index, so it supplies the switch; the nudge only has
/// to prefer it over pushing. This pins that preference, which is the whole of
/// the fix — the banner itself only renders once an insight exists, and that
/// path is covered by the nudge's own suite.
void main() {
  test('the nudge carries an optional tab-switch callback', () {
    // A nudge given a tab-switch carries it...
    var switched = 0;
    final wired = ProactiveNudge(onOpenTrends: () => switched++);
    expect(wired.onOpenTrends, isNotNull);
    wired.onOpenTrends!();
    expect(switched, 1);

    // ...and one rendered outside the shell still works, falling back to a push.
    const bare = ProactiveNudge();
    expect(bare.onOpenTrends, isNull,
        reason: 'the parameter must stay optional so the widget is usable '
            'anywhere, not only inside AppShell');
  });

  test('the shell actually supplies it, and Home passes it down', () {
    // Not a mount test, and the reason is NOT a pending timer — mounting
    // ProactiveNudge headlessly is clean (initState only registers a
    // post-frame callback). The real blocker is that `build` returns
    // SizedBox.shrink until `InsightService.gatherAll()` yields an insight of
    // at least `attention` severity, and on a fresh in-memory database that
    // list is empty — measured: COUNT=0, zero ProactiveNudgeBanner. A mount
    // test would therefore have to seed enough real data to fire an insight
    // and would then be pinned to whichever insight happened to rank first,
    // so it would go red when an unrelated engine changed. Until the tap has a
    // seam that does not run the whole insight pipeline, the wiring is pinned
    // by source. The test above is the widget's half; this is the wiring's
    // half, and without it the callback could silently stop being passed while
    // the test above still passed.
    final shell =
        File('lib/features/home/screens/app_shell.dart').readAsStringSync();

    // Bounded to the HomeDashboard( call, NOT a bare contains(). The shell also
    // wires HealthBrowseScreen with the byte-identical
    // `onOpenTrends: () => _onTap(4)`, so a whole-file contains() passed with
    // Home's wiring deleted — this guard was vacuous on its first draft, which
    // is the exact failure it exists to prevent elsewhere.
    final from = shell.indexOf('HomeDashboard(');
    expect(from, greaterThan(-1), reason: 'HomeDashboard call not found');
    // Bounded by the NEXT entry in the tab list, not by a ')' — `_onTap(4),`
    // contains one, so searching for it truncated the window mid-argument.
    final to = shell.indexOf('NunitoMedicationDashboard', from);
    expect(to, greaterThan(from),
        reason: 'the tab list changed shape; re-anchor this window');
    final homeCall = shell.substring(from, to);
    expect(homeCall, contains('onOpenTrends: () => _onTap(4)'),
        reason: 'the shell is the only layer that knows the Trends tab index; '
            'if this goes, the nudge falls back to pushing a duplicate.\n'
            'HomeDashboard call was:\n$homeCall');

    final home =
        File('lib/features/home/screens/home_dashboard.dart').readAsStringSync();
    // Bounded to the ProactiveNudge( call — a bare contains() would also match
    // the unrelated `onOpenTrends: widget.onOpenTrends` elsewhere in the file.
    final nudgeAt = home.indexOf('ProactiveNudge(');
    expect(nudgeAt, greaterThan(-1), reason: 'ProactiveNudge call not found');
    final nudgeCall = home.substring(nudgeAt, home.indexOf(');', nudgeAt));
    expect(nudgeCall, contains('onOpenTrends: widget.onOpenTrends'),
        reason: 'Home must hand the shell callback to the nudge');

    final nudge = File('lib/features/insights/screens/proactive_nudge.dart')
        .readAsStringSync();
    expect(nudge, contains('widget.onOpenTrends ??'),
        reason: 'the tap must PREFER the tab switch, with the push only as a '
            'fallback for use outside the shell');
  });
}
