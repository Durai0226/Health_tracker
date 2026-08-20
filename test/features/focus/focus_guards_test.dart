import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/focus_readiness.dart';
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/mindfulness_channel.dart';
import 'package:tablet_remainder/features/focus/models/focus_session.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/features/focus/models/ambient_sound.dart';
import 'package:tablet_remainder/features/focus/models/focus_achievement.dart';

/// Standing structural guards for the Focus feature.
///
/// Every assertion here failed when it was written, and each one guards a defect
/// class that a behavioural test cannot reach — a service that is never
/// initialised, a singleton somebody else disposes, a theme-blind colour
/// constant, a screen no route pushes, an audio source that is a URL. Source
/// greps are the cheapest possible instrument: milliseconds, no binding, no
/// device, and structurally impossible to flake.
///
/// Idiom copied from `test/health/no_generative_ai_guard_test.dart`, which exists
/// for the same reason: these regressions arrive gradually, one line at a time.
void main() {
  List<File> dartFilesUnder(String dir) => Directory(dir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) =>
          f.path.endsWith('.dart') &&
          !f.path.endsWith('.g.dart') &&
          !f.path.endsWith('.freezed.dart'))
      .toList();

  final libFiles = dartFilesUnder('lib');
  final focusFiles = dartFilesUnder('lib/features/focus');

  String read(File f) => f.readAsStringSync();

  /// Source with `//` and `///` comment lines stripped, so a guard never fires on
  /// prose that merely *mentions* the thing it bans — including this file's own
  /// explanatory comments quoted into a reason string.
  String code(File f) => read(f)
      .split('\n')
      .where((l) {
        final t = l.trimLeft();
        return !t.startsWith('//');
      })
      .join('\n');

  group('perpetual motion is always optional', () {
    /// Lines that start a forever-loop, paired with whether a reduce-motion guard
    /// is in scope just above them.
    ///
    /// A source guard, because a widget test cannot do this job here. The obvious
    /// probe — pump a `PremiumToast` with `disableAnimations: true` and assert the
    /// scheduler is idle — passes for the wrong reason: a toast auto-dismisses
    /// after `ToastTheme.defaultAutoDismiss` (4s), so within any sensible pump
    /// window the widget is gone and there is nothing left to animate. The
    /// assertion would measure its lifetime, not its motion. `focus_a11y_test.dart`
    /// covers `ParticleSystem` directly for that reason; the shimmer and the pulse
    /// live inside the self-dismissing widget and only source can see them.
    List<String> ungatedLoops(File f) {
      // Comment lines are dropped for MATCHING but their original line numbers are
      // kept for REPORTING. Both halves matter: a prose mention of "reduceMotion"
      // in a doc comment must not satisfy the guard, and an offender reported at a
      // stripped-source line number is a finding nobody can navigate to.
      final numbered = <(int, String)>[];
      final raw = f.readAsStringSync().split('\n');
      for (var i = 0; i < raw.length; i++) {
        if (raw[i].trimLeft().startsWith('//')) continue;
        numbered.add((i + 1, raw[i]));
      }

      final offenders = <String>[];
      for (var i = 0; i < numbered.length; i++) {
        final (lineNo, text) = numbered[i];
        if (!text.contains('.repeat(')) continue;
        // Look back over the enclosing block for a guard. 12 lines, not 6: the
        // shape `if (!reduceMotion) x.repeat();` is a same-line hit, but
        // `relaxation_screen.dart` opens `if (MediaQuery.disableAnimationsOf(...))`
        // and reaches its `repeat()` calls ten lines later in the `else`. A
        // 6-line window reported that correct code as an offender.
        final from = i - 12 < 0 ? 0 : i - 12;
        final window =
            numbered.sublist(from, i + 1).map((e) => e.$2).join('\n');
        final guarded = window.contains('reduceMotion') ||
            window.contains('disableAnimations');
        if (!guarded) {
          offenders.add('${f.path.split('/').last}:$lineNo  ${text.trim()}');
        }
      }
      return offenders;
    }

    test('the matcher actually flags an ungated loop', () {
      // Self-verification, the same way this file's other matchers do it. A guard
      // nobody has watched fire is decoration.
      final tmp = File(
          '${Directory.systemTemp.path}/ungated_loop_probe_${pid}.dart')
        ..writeAsStringSync('void f() {\n  _c.repeat();\n}\n');
      addTearDown(() => tmp.existsSync() ? tmp.deleteSync() : null);
      expect(ungatedLoops(tmp), hasLength(1),
          reason: 'a bare repeat() with no guard in scope must be reported');

      final ok = File('${Directory.systemTemp.path}/gated_loop_probe_${pid}.dart')
        ..writeAsStringSync(
            'void f() {\n  if (!reduceMotion) _c.repeat();\n}\n');
      addTearDown(() => ok.existsSync() ? ok.deleteSync() : null);
      expect(ungatedLoops(ok), isEmpty,
          reason: 'and a guarded one must be spared');

      // The false positive this window width exists for: a guard that opens a
      // block and only reaches its repeat() several lines later.
      final distant = File(
          '${Directory.systemTemp.path}/distant_guard_probe_${pid}.dart')
        ..writeAsStringSync('void f() {\n'
            '  if (MediaQuery.disableAnimationsOf(context)) {\n'
            '    _a.stop();\n    _a.value = 0.0;\n'
            '    _b.stop();\n    _b.value = 0.0;\n'
            '  } else {\n'
            '    if (!_a.isAnimating) _a.repeat(reverse: true);\n'
            '    if (!_b.isAnimating) _b.repeat();\n'
            '  }\n}\n');
      addTearDown(() => distant.existsSync() ? distant.deleteSync() : null);
      expect(ungatedLoops(distant), isEmpty,
          reason: 'a guard ten lines above its repeat() is still a guard — a '
              '6-line window reported relaxation_screen.dart as an offender');

      // And prose must NOT satisfy it.
      final prose = File('${Directory.systemTemp.path}/prose_probe_${pid}.dart')
        ..writeAsStringSync('void f() {\n'
            '  // honours reduceMotion and disableAnimations, honestly\n'
            '  _c.repeat();\n}\n');
      addTearDown(() => prose.existsSync() ? prose.deleteSync() : null);
      expect(ungatedLoops(prose), hasLength(1),
          reason: 'a comment claiming the guard is not the guard');
    });

    test('no toast animation loops forever regardless of the user preference',
        () {
      // Wiring `FocusToast.sessionComplete(..., showParticles: true)` in Phase 5
      // pointed a wellbeing feature's celebration at three `repeat()` controllers
      // that consulted nothing: shimmer and pulse in `toast_animations.dart`, and
      // the confetti in `toast_particles.dart`. `disableAnimations` appeared
      // nowhere in the package. Every toast in the app ignored the setting; the
      // Focus celebration is simply what made it matter.
      final offenders = <String>[];
      for (final f in dartFilesUnder('lib/core/widgets/toast')) {
        offenders.addAll(ungatedLoops(f));
      }
      expect(offenders, isEmpty,
          reason: 'these loops run forever with reduce-motion on:\n'
              '${offenders.join('\n')}');
    });

    test('no Focus widget loops forever regardless of the user preference', () {
      final offenders = <String>[];
      for (final f in focusFiles) {
        offenders.addAll(ungatedLoops(f));
      }
      expect(offenders, isEmpty,
          reason: 'these loops run forever with reduce-motion on:\n'
              '${offenders.join('\n')}');
    });
  });

  group('Focus is actually wired into the app', () {
    test('main.dart initialises FocusService', () {
      // Until this passes, `FocusService()` is only ever initialised by
      // FocusScreen.initState. Home reads the same singleton for its Focus KPI
      // and streak chip, so on a cold launch both render 0 until the user
      // happens to open Focus once — the data is on disk the whole time.
      final main = read(File('lib/main.dart'));
      expect(main, contains('FocusService'),
          reason: 'lib/main.dart never initialises FocusService, so every '
              'read of todayMinutes/stats before the user opens the Focus '
              'screen returns an un-hydrated singleton');
      expect(RegExp(r'FocusService\(\)\.init\(\)').hasMatch(main), isTrue,
          reason: 'FocusService is referenced but never init()-ed in main.dart');
    });
  });

  group('the shared AudioPlayer is not destroyed by a bystander', () {
    test('only audio_service.dart may dispose AudioService', () {
      // AudioService is a process-wide singleton wrapping the app's ONLY
      // AudioPlayer. Whoever calls dispose() on it destroys audio for the rest
      // of the process — every later focus ambient sound and relaxation track
      // throws, and every later notifyListeners() throws "used after dispose".
      final pattern = RegExp(r'_?[aA]udioService\s*\.\s*dispose\s*\(');
      final offenders = <String>[];
      for (final f in libFiles) {
        if (f.path.endsWith('core/services/audio_service.dart')) continue;
        if (pattern.hasMatch(code(f))) offenders.add(f.path);
      }
      expect(offenders, isEmpty,
          reason: 'these dispose the app-wide AudioService singleton, killing '
              'all audio for the rest of the process:\n${offenders.join('\n')}\n'
              'Call stop() instead — see focus_service.dart and '
              'relaxation_service.dart, which both get this right.');
    });
  });

  group('Focus renders in dark mode', () {
    // `lib/core/constants/app_colors.dart` exposes light-only `static const`
    // values ALONGSIDE theme-aware `getX(context)` helpers, and five Focus
    // screens reached for the constants. docs/ui-audit.md measured the result at
    // ~1.05:1 contrast — the titles were not "hard to read", they were
    // invisible. The `get*(context)` form is correct; focus_garden_screen.dart
    // already uses it.
    //
    // A light-only const is a *bare* member reference: `AppColors.cardBg`, not
    // `AppColors.getCardBg(context)`. Matching on `\.cardBg\b` would flag the
    // correct form too, so the pattern requires the member name to follow
    // `AppColors.` directly.
    const bannedMembers = [
      'cardBg',
      'background',
      'textPrimary',
      'textSecondary',
      'divider',
      'border',
    ];
    List<String> lightOnlyColorHits(String src) {
      final hits = <String>[];
      for (final member in bannedMembers) {
        final bare = RegExp('AppColors\\.$member\\b');
        for (final _ in bare.allMatches(src)) {
          hits.add('AppColors.$member');
        }
      }
      return hits;
    }

    test('the matcher flags a bare const and spares the themed getter', () {
      // Without this, a matcher that silently matches nothing would let the
      // guard below pass over a screen full of light-only colours. The repo
      // learned this the hard way in test/support/counting_executor.dart, where
      // a matcher for the wrong table name made every count zero and the test
      // passed with the bug deliberately restored.
      expect(lightOnlyColorHits('color: AppColors.cardBg,'),
          equals(['AppColors.cardBg']),
          reason: 'the guard cannot catch what its matcher cannot see');
      expect(lightOnlyColorHits('color: AppColors.getCardBg(context),'), isEmpty,
          reason: 'the theme-aware getter is the CORRECT form and must not be '
              'flagged, or the guard punishes the fix');
      expect(lightOnlyColorHits('color: ext.textPrimary,'), isEmpty,
          reason: 'AppColorsExt is theme-aware — only bare AppColors consts are '
              'the defect');
    });

    test('no Focus file uses the light-only AppColors constants', () {
      final offenders = <String>[];
      for (final f in focusFiles) {
        for (final hit in lightOnlyColorHits(code(f))) {
          offenders.add('${f.path}: $hit');
        }
      }
      expect(offenders, isEmpty,
          reason: 'light-only colour constants render white-on-white in dark '
              'mode. Use the AppColors.getX(context) helpers or AppColorsExt:\n'
              '${offenders.toSet().join('\n')}');
    });
  });

  group('no unreachable Focus code accumulates', () {
    test('every Focus screen is referenced from somewhere in lib/', () {
      // ~7,000 lines of Focus code were unreachable when this guard was
      // written: a whole relaxation-games subtree whose screens had been
      // deleted, a second wellness engine, a leaderboard and a group-focus
      // service that fabricated users with Random(), and a THIRD focus timer
      // writing the same preference keys as the live one. A screen no route
      // pushes is not a feature; it is a maintenance cost that reads like one.
      final screens = focusFiles
          .where((f) => f.path.endsWith('_screen.dart'))
          .toList();
      expect(screens, isNotEmpty, reason: 'no Focus screens found — wrong path?');

      // main_qa.dart is excluded deliberately. It is a QA-only entrypoint that
      // routes to every Focus screen by name, so counting it as a referrer would
      // make this guard unfailable — a screen no user route pushes would still
      // look reachable. Verified at the time of writing: every Focus screen has
      // at least one non-QA referrer, so this exclusion costs no coverage.
      final referrers =
          libFiles.where((f) => !f.path.endsWith('main_qa.dart')).toList();

      final orphans = <String>[];
      for (final screen in screens) {
        final fileName = screen.uri.pathSegments.last;
        final className = RegExp(r'class\s+(\w*Screen)\b')
            .firstMatch(read(screen))
            ?.group(1);
        final referenced = referrers.any((other) {
          if (other.path == screen.path) return false;
          final src = code(other);
          return src.contains(fileName) ||
              (className != null && src.contains(className));
        });
        if (!referenced) orphans.add(screen.path);
      }
      expect(orphans, isEmpty,
          reason: 'no file in lib/ imports or pushes these screens, so no user '
              'can reach them:\n${orphans.join('\n')}');
    });

    test('the deleted Focus clusters stay deleted', () {
      for (final path in [
        // Relaxation games: the screens were deleted; the service, widgets and
        // models survived them by ~2,770 lines, with persistence stubbed to
        // debugPrint so its whole unlock economy reset on every launch.
        'lib/features/focus/services/relaxation_game_service.dart',
        'lib/features/focus/widgets/relaxation_game_widgets.dart',
        'lib/features/focus/models/relaxation_game_models.dart',
        // A second, parallel wellness engine + its own private design system.
        'lib/features/focus/services/manrope_wellness_service.dart',
        'lib/features/focus/models/meditation_activity.dart',
        'lib/features/focus/models/daily_routine.dart',
        'lib/features/focus/models/focus_reminder.dart',
        'lib/features/focus/theme/manrope_theme.dart',
        // Social features the app deliberately does not surface, both of which
        // invented fake people and fake stats with Random().
        'lib/features/focus/services/leaderboard_service.dart',
        'lib/features/focus/services/group_focus_service.dart',
        'lib/features/focus/models/focus_leaderboard.dart',
        'lib/features/focus/models/group_focus.dart',
        // A third focus timer, reading and writing the SAME preference keys as
        // the live FocusService. Inert only because nothing instantiated it.
        'lib/core/services/focus_mode_service.dart',
      ]) {
        expect(FileSystemEntity.typeSync(path), FileSystemEntityType.notFound,
            reason: '$path is back — see docs/focus-audit.md for why it went');
      }
    });

    test('Focus keeps ONE insight path', () {
      // `InsightsGenerator` (models/detailed_stats.dart) was a third generator
      // behind the Statistics screen, and every one of its three outputs was a
      // defect the rest of the feature had already ruled out:
      //
      //  * "Room for Improvement — your focus time decreased by N minutes this
      //    week" is the loss framing `focus_suggestions_test` bans in
      //    `focusCoach`, on the CHI 2020 finding that rigid-streak users are 63%
      //    more likely to quit after one missed day.
      //  * Six hardcoded `Color(0xFF...)` values — the theme-blindness the
      //    `AppColors` guard below exists for.
      //  * "Peak Focus Time" with NO minSessions threshold, so it fired
      //    confidently off a single session. `FocusInsights.bestFocusHour`
      //    returns null under five for exactly that reason.
      //
      // `ProductivityPattern.mostProductiveHourLabel` went with it: a fourth
      // copy of `FocusInsights.hourLabel`. `InsightEngine.focus` is now the one
      // engine, `InsightCard` the one renderer, and both surfaces agree.
      final hits = <String>[];
      for (final f in focusFiles) {
        final src = code(f);
        for (final symbol in const [
          'class InsightsGenerator',
          'class FocusInsight {',
          'mostProductiveHourLabel',
        ]) {
          if (src.contains(symbol)) hits.add('${f.path}: $symbol');
        }
      }
      expect(hits, isEmpty,
          reason: 'a second Focus insight path is back — route it through '
              'InsightEngine.focus + InsightCard instead:\n${hits.join('\n')}');
    });

    test('no fourth parallel haptic system appears', () {
      // The deleted games cluster contained 14 hand-tuned amplitude-ramped
      // vibration patterns — genuinely the best-written code in the feature. The
      // plan was to extract them, and that was the wrong call: the app already
      // has `lib/core/services/haptic_service.dart`, a singleton with
      // per-feature enable/intensity (including a `HapticFeature.focus`) and a
      // settings screen behind it. A second haptic engine would have recreated
      // exactly the disease this phase removes — the feature already carried
      // three sound taxonomies, three focus timers and two design systems.
      //
      // The patterns are preserved in git history; reviving them belongs in
      // HapticService, where the user's preference already lives.
      expect(
          File('lib/features/focus/services/haptic_patterns.dart').existsSync(),
          isFalse,
          reason: 'route haptics through HapticService instead — it is the one '
              'place that honours the haptics settings screen');
    });
  });

  group('Focus honours the user haptics setting', () {
    test('no Focus file calls HapticFeedback directly', () {
      // `HapticService.trigger()` gates on `_isEnabled` and on the per-feature
      // toggle, then applies that feature's intensity. A raw
      // `HapticFeedback.selectionClick()` bypasses all three, so a user who
      // switched haptics OFF still gets buzzed — and breathing_widget.dart fires
      // one every second for the length of the exercise.
      //
      // 133 such calls exist app-wide. This guard is scoped to Focus because
      // that is the feature under repair; the rest is recorded in
      // docs/focus-audit.md as a separate sweep.
      final hits = <String>[];
      for (final f in focusFiles) {
        final lines = read(f).split('\n');
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.trimLeft().startsWith('//')) continue;
          if (!line.contains('HapticFeedback.')) continue;
          if (line.contains('haptic-raw-ok:')) continue;
          hits.add('${f.path}:${i + 1}  ${line.trim()}');
        }
      }
      expect(hits, isEmpty,
          reason: 'these ignore the haptics settings screen — use '
              'HapticService() (HapticFeature.focus), or annotate '
              '`// haptic-raw-ok: <reason>`:\n${hits.join('\n')}');
    });
  });

  group('Focus never rings like a medicine alarm', () {
    // `NotificationService._notificationDetails` accepts a `channelId` and
    // IGNORES it, hardcoding `alarm_channel` with `Importance.max`,
    // `AudioAttributesUsage.alarm`, `AndroidNotificationCategory.alarm`,
    // `fullScreenIntent` (from a setting that defaults true), Snooze/Dismiss
    // actions and `timeoutAfter`. `showImmediateNotification` routes through it.
    //
    // So every Focus notification — break over, round done, session complete,
    // plant unlocked, achievement unlocked, relaxation complete — arrived on the
    // medicine alarm stream, through Do Not Disturb, able to take the lock
    // screen. "New Plant Unlocked! 🌱" was indistinguishable from a missed dose.
    //
    // `scheduleGenericReminder` is the same defect one level deeper: on Android
    // it routes to `BackgroundAlarmService` → `AlarmManager.setAlarmClock()`, and
    // the callback presents on `alarm_channel` with `fullScreenIntent: true`,
    // `ongoing: true` and a `✓ Take` button.
    //
    // Both are banned in Focus. `showFocusNotification` and
    // `scheduleFocusReminder` build `focus_channel` details directly, which is
    // the pattern `showCaregiverAlert` already established for the same reason.
    test('no Focus file uses the alarm-channel notification helpers', () {
      const banned = {
        'showImmediateNotification':
            'hardcodes alarm_channel via _notificationDetails — use '
                'NotificationService.showFocusNotification',
        'scheduleGenericReminder':
            'routes to AlarmManager.setAlarmClock() and presents full-screen '
                'with a Take button — use NotificationService.scheduleFocusReminder',
        'cancelGenericReminder':
            'the counterpart of a call that should not exist here — '
                'scheduleFocusReminder(enabled: false) cancels',
      };
      final hits = <String>[];
      for (final f in focusFiles) {
        final lines = read(f).split('\n');
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.trimLeft().startsWith('//')) continue;
          if (line.contains('notif-raw-ok:')) continue;
          for (final entry in banned.entries) {
            if (line.contains('${entry.key}(')) {
              hits.add('${f.path}:${i + 1}  ${entry.key} — ${entry.value}');
            }
          }
        }
      }
      expect(hits, isEmpty,
          reason: 'these ring on the alarm stream and bypass Do Not Disturb; '
              'annotate `// notif-raw-ok: <reason>` only if that is genuinely '
              'wanted:\n${hits.join('\n')}');
    });

    test('the armed completion never claims the background callback slot', () {
      // `flutter_local_notifications` stores exactly ONE app-wide background
      // callback handle. The main isolate (`notificationTapBackground`) and the
      // medicine alarm isolate (`_backgroundNotificationCallback`) already contend
      // for it — whichever called `initialize()` last wins, which is why both are
      // documented as having to handle the same action set.
      //
      // A third claimant would silently break dose actions: a user taps "Take" on
      // a medicine reminder and nothing happens. So the focus alarm path posts
      // through the already-initialised plugin on the main isolate and carries no
      // action buttons, meaning there is nothing for a background handler to
      // route. Same shape as `background_health_sync_policy_test`, which greps for
      // forbidden imports for the same class of reason.
      const forbidden = {
        'initialize(': 'would steal the single app-wide background callback slot '
            'from the medicine alarm isolate',
        'AndroidAlarmManager':
            'AlarmManager presents on alarm_channel with a full-screen intent',
        'onDidReceiveBackgroundNotificationResponse':
            'a third background handler for one slot',
        'AndroidNotificationAction':
            'action buttons need background routing, which this path must not own',
      };
      final file = File(
          'lib/features/focus/services/focus_session_alarm.dart');
      expect(file.existsSync(), isTrue);
      final src = code(file);
      final hits = <String>[];
      forbidden.forEach((needle, why) {
        if (src.contains(needle)) hits.add('$needle — $why');
      });
      expect(hits, isEmpty, reason: hits.join('\n'));
    });

    test('the Focus id block is contiguous and reserved', () {
      // A notification id is last-write-wins, so an id shared with another
      // feature is ONE notification and cancelling it kills both.
      const ids = [
        NotificationService.focusDailyReminderId,
        NotificationService.focusStreakReminderId,
        NotificationService.focusSessionEndId,
      ];
      expect(ids.toSet().length, ids.length, reason: 'duplicate Focus id');
      for (final id in ids) {
        expect(id >= 918_400 && id < 918_500, isTrue,
            reason: '$id is outside the reserved 918_4xx Focus block');
      }
    });
  });

  group('no unsupported health claims reach the user', () {
    // This is a HEALTH app, so the bar is higher, not lower: Google Play's Health
    // Content policy prohibits claims contradicting medical consensus, and Apple
    // 1.4.1 requires disclosed, validated methodology behind accuracy claims.
    //
    // The relaxation catalogue shipped with '528 Hz Miracle Tone — Emotional
    // balance and DNA repair frequency' and '40 Hz Gamma Focus — Strong mental
    // clarity and cognitive enhancement'. The first is the same category of claim
    // Play's own policy cites as a violation example; the second is contradicted
    // by the evidence (a 2023 n≈1,000 study found 15 Hz binaural beats *worsened*
    // cognitive scores by 4–6%). No peer-reviewed work distinguishes 432 Hz from
    // 440 Hz tuning, and the solfeggio numbers were invented in the 1990s from
    // numerology rather than inherited from any tradition.
    //
    // Endel and Brain.fm — both of which fund their own research — still word
    // claims as mechanism and subjective experience ("creates feelings of",
    // "supports attention"), never as a disease, diagnosis or cure. That is the
    // register this app has to stay in.
    //
    // Scoped to user-facing STRING LITERALS: the enum identifiers
    // (`healing432Hz`) are the persisted wire format and the audio lookup key, so
    // renaming them would reinterpret stored history. They are never displayed.
    test('the mindfulness map has no default case', () {
      // `mindfulnessKindFor` decides what goes into a permanent health record.
      // A `default:` would mean a newly added `FocusActivityType` silently falls
      // into whatever the default is — and if that default were ever "write it",
      // the app would start claiming a coding sprint was meditation.
      //
      // With an exhaustive switch, adding an activity is a COMPILE error here.
      // That is the whole mechanism, so this guard exists to stop someone
      // "fixing" that error by adding a default rather than making the decision.
      final src = code(File('lib/core/services/mindfulness_channel.dart'));
      expect(src.contains('default:'), isFalse,
          reason: 'adding a FocusActivityType must be a compile error in '
              'mindfulnessKindFor, not a silent decision to write it');
    });

    test('only real practice is ever written as mindfulness', () {
      // Forest writes every focus session to Apple Health as Mindful Minutes.
      // That is wrong rather than ambitious, and declining to copy it is a
      // feature: `MindfulnessSessionRecord` means mindfulness PRACTICE, so a
      // fifty-minute coding block filed there is a false claim in a record the
      // user may later show a clinician.
      expect(mindfulnessKindFor(FocusActivityType.meditation),
          MindfulnessKind.meditation);
      for (final concentration in [
        FocusActivityType.work,
        FocusActivityType.study,
        FocusActivityType.reading,
        FocusActivityType.writing,
        FocusActivityType.coding,
        FocusActivityType.creative,
        FocusActivityType.exercise,
        FocusActivityType.other,
      ]) {
        expect(mindfulnessKindFor(concentration), isNull,
            reason: '${concentration.name} is concentration, not practice');
      }
    });

    test('readiness never diagnoses', () {
      // A readiness signal is the one place in this feature that asserts
      // something from ANOTHER feature's biometric data, so it is the one place
      // that can drift into a health claim. The rule it has to stay inside: report
      // the user's own two numbers, offer a smaller number, never explain their
      // brain and never predict their day.
      //
      // Play's Health Content policy prohibits claims contradicting medical
      // consensus and Apple 1.4.1 requires disclosed, validated methodology
      // behind accuracy claims — and consumer wrist HRV supports neither.
      const banned = [
        'brain',
        'cognitive',
        'impair',
        'capacity',
        'readiness score',
        'focus score',
        'you will',
        'predicts',
        'prefrontal',
        'recovery score',
      ];
      final files = [
        File('lib/core/health/focus_readiness.dart'),
        File('lib/core/health/coach_text.dart'),
      ];
      final hits = <String>[];
      for (final f in files) {
        // Comment lines are stripped, so the doc comments above — which discuss
        // "prefrontal" and "cognitive" precisely in order to explain why the UI
        // must not — cannot trip their own guard.
        final lines = code(f).split('\n');
        for (var i = 0; i < lines.length; i++) {
          final lower = lines[i].toLowerCase();
          if (!lower.contains("'") && !lower.contains('"')) continue;
          for (final phrase in banned) {
            if (lower.contains(phrase)) {
              hits.add('${f.path}: "$phrase" in ${lines[i].trim()}');
            }
          }
        }
      }
      expect(hits, isEmpty,
          reason: 'readiness reports the user\'s own numbers and offers a '
              'shorter session — it does not diagnose:\n${hits.join('\n')}');
    });

    test('readiness never suggests a LONGER session', () {
      // The asymmetry is the honesty. Evidence that sleep loss degrades
      // next-day prefrontal function is far stronger than any dose-response claim
      // that extra sleep grants extra capacity, so "you're primed — try 90
      // minutes!" would be over-claiming AND would set the user up to fail a
      // target the app invented.
      for (final usual in [10, 15, 20, 25, 30, 45, 60, 90, 120]) {
        final note = FocusReadiness.assess(
          lastNightMinutes: 300,
          sleepMedianMinutes: 480,
          loggedNights: 10,
          suggestedMinutes: usual,
        );
        final adjusted = note?.adjustedMinutes;
        if (adjusted != null) {
          expect(adjusted, lessThan(usual),
              reason: 'a readiness note may only ever shorten');
          expect(adjusted, greaterThanOrEqualTo(10));
        }
      }
    });

    test('no medical or pseudo-scientific claim in a Focus string literal', () {
      const banned = [
        'dna',
        'miracle tone',
        'healing frequency',
        'cognitive enhancement',
        'brainwave',
        'entrainment',
        'clinically proven',
        'cures',
        'treats anxiety',
        'repairs',
      ];
      final stringLiteral = RegExp(r'''(['"])((?:[^'"\\]|\\.){4,})\1''');
      final offenders = <String>[];
      for (final f in focusFiles) {
        for (final line in code(f).split('\n')) {
          for (final m in stringLiteral.allMatches(line)) {
            final text = m.group(2)!.toLowerCase();
            for (final phrase in banned) {
              if (text.contains(phrase)) {
                offenders.add('${f.path}: "${m.group(2)}"  [$phrase]');
              }
            }
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'unsupported health claims shown to the user:\n'
              '${offenders.join('\n')}\n'
              'Say "designed to help you focus"; never a frequency, a brain '
              'mechanism, or a condition.');
    });

    test('the claim matcher actually matches a claim', () {
      // Same self-verification as the other matchers here: a guard that cannot
      // fire is worse than no guard, because it reads as coverage.
      final probe = RegExp(r'''(['"])((?:[^'"\\]|\\.){4,})\1''')
          .allMatches("return 'Emotional balance and DNA repair frequency';")
          .map((m) => m.group(2)!.toLowerCase())
          .toList();
      expect(probe, isNotEmpty, reason: 'the literal extractor found nothing');
      expect(probe.any((t) => t.contains('dna')), isTrue);
    });
  });

  group('audio is bundled, not hotlinked', () {
    final urlInString = RegExp(r'''['"]https?://[^'"]+['"]''');

    test('the URL matcher actually matches a URL', () {
      // Same reasoning as the colour matcher above: this guard is only worth
      // having if it can fire. The suite it replaces asserted that every audio
      // URL's *hostname* was in an allowlist, which stayed green over 23 dead
      // links for months.
      expect(urlInString.hasMatch("return 'https://cdn.pixabay.com/x.mp3';"),
          isTrue);
      expect(urlInString.hasMatch("await player.setAsset('assets/audio/rain.m4a');"),
          isFalse, reason: 'a bundled asset path is the fix, not the defect');
    });

    test('no audio source is a remote URL', () {
      // Every one of the 29 audio sources used to be a hotlinked third-party
      // URL. 11 of 14 relaxation primaries returned 404 and 12 of 15 ambient
      // URLs returned 403, and the fallback chain ended at an algorithmic-music
      // DEMO endpoint — so "Deep Sleep Delta Waves" played generated techno.
      // Meanwhile the test suite was green, because it asserted the URLs'
      // hostnames rather than whether any audio existed.
      //
      // Local assets make that class of failure impossible rather than merely
      // tested: no CDN can retire them, no hotlink protection can 403 them, and
      // they work on a plane.
      final audioFiles = [
        File('lib/core/services/audio_service.dart'),
      ].where((f) => f.existsSync());
      expect(audioFiles, isNotEmpty, reason: 'audio_service.dart is missing');

      final offenders = <String>[];
      for (final f in audioFiles) {
        for (final line in code(f).split('\n')) {
          final m = urlInString.firstMatch(line);
          if (m != null) offenders.add('${f.path}: ${m.group(0)}');
        }
      }
      expect(offenders, isEmpty,
          reason: 'audio must be a bundled asset, not a URL:\n'
              '${offenders.join('\n')}');
    });

    test('every declared audio asset exists on disk', () {
      // Reads the RESOLVED paths from the service rather than regexing its source.
      // The first version of this guard scraped string literals, which silently
      // stopped matching the moment the catalogue switched to interpolated paths
      // (`'$_dir/rain.m4a'`) — it reported "no assets referenced" while fifteen
      // were. A guard that can be defeated by a refactor is not a guard.
      //
      // `debugAllSources` reads two static const maps, so touching it does not
      // construct a player and needs no binding.
      final declared = AudioService.debugAllSources;
      expect(declared, isNotEmpty,
          reason: 'the catalogue declares no audio at all');

      for (final src in declared) {
        expect(src, startsWith('assets/'),
            reason: 'remote audio silently fails offline, on a plane, and whenever '
                'a free CDN retires a file — which is how 23 of 29 sources ended '
                'up dead while the tests stayed green. Got: $src');
      }

      final missing = declared.where((p) => !File(p).existsSync()).toList()..sort();
      expect(missing, isEmpty,
          reason: '${missing.length} declared asset(s) are not on disk. These are '
              'the CC0 field recordings still to be sourced — see '
              'docs/audio-sourcing.md, and filter Freesound to Creative Commons 0:'
              '\n${missing.join('\n')}');
    });

    test('every playable sound is reachable, and Sound Explorer tracks them', () {
      // Two halves of one contract.
      //
      // The picker must offer exactly what plays: it used to walk
      // `AmbientSoundType.values` unfiltered, so twelve of fifteen chips played
      // silence. And `soundExplorer.requiredValue` was the literal 15 against a
      // three-sound catalogue, which made a visible achievement permanently
      // unreachable — you could try every sound in the app and still be at 3/15.
      //
      // Pinning them together means each wave of sourced audio moves the picker
      // and the achievement in lockstep, and neither can be forgotten.
      expect(AudioService.playableAmbientSounds, isNotEmpty,
          reason: 'the ambient catalogue cannot be empty — the picker would '
              'offer nothing but "none"');
      expect(AchievementType.soundExplorer.requiredValue,
          AudioService.playableAmbientSounds.length,
          reason: 'Sound Explorer must be earnable by trying every sound that '
              'actually plays — derive it, never hardcode it');
      expect(AudioService.hasAmbientAudio(AmbientSoundType.none), isTrue,
          reason: '"no sound" is a real choice and must stay in the picker');
      for (final sound in AudioService.playableAmbientSounds) {
        expect(AmbientSoundType.values, contains(sound));
      }
    });

    test('pubspec bundles the audio directory', () {
      expect(File('pubspec.yaml').readAsStringSync(), contains('assets/audio/'),
          reason: 'assets/audio/ must be declared in pubspec.yaml or the files '
              'are not shipped, and setAsset fails at runtime only');
    });
  });
}
