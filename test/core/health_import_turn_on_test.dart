/// "Turn it on" for an import from the health store, proved once for every import.
///
/// The vitals import and the water import each had their own copy of this order of
/// events; the choice left on after a failed first read had to be fixed in both.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tablet_remainder/core/services/health_data_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart' show AppToastX;
import 'package:tablet_remainder/core/widgets/health_import_turn_on.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late List<String> events;
  late bool? stored;

  setUp(() {
    events = [];
    stored = null;
  });

  Future<void> settle(WidgetTester tester) async {
    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    try {
      for (var t = 0; t < 600; t += 100) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    } finally {
      FlutterError.onError = prev;
    }
  }

  /// A page with one button that runs [action] with its own context.
  Future<void> show(WidgetTester tester, Future<void> Function(BuildContext) action) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (context) =>
                TextButton(onPressed: () => action(context), child: const Text('go')),
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  /// Runs "turn it on" with fakes that record what was asked, in order.
  Future<bool> turnOn(
    BuildContext context, {
    bool alreadyAllowed = false,
    bool grants = true,
    Future<int> Function()? read,
    Future<void> Function(bool enabled)? setEnabled,
  }) =>
      HealthImportTurnOn.run<int>(
        context,
        name: 'TestImport',
        allowed: () async {
          events.add('allowed?');
          return alreadyAllowed;
        },
        ask: () async {
          events.add('ask');
          return grants;
        },
        setEnabled: setEnabled ??
            (enabled) async {
              events.add('enabled=$enabled');
              stored = enabled;
            },
        read: read ??
            () async {
              events.add('read');
              return 3;
            },
        declinedMessage: 'It did not share, so nothing was counted.',
        silentMessage: 'Switched on, but it did not answer just now.',
        report: (c, n) => c.toastSuccess('Brought in $n'),
      );

  group('when it is allowed', () {
    testWidgets('asks nothing, switches on, reads, and says what came in', (tester) async {
      var on = false;
      await show(tester, (c) async => on = await turnOn(c, alreadyAllowed: true));

      await tester.tap(find.text('go'));
      await settle(tester);

      expect(on, isTrue);
      expect(events, ['allowed?', 'enabled=true', 'read']);
      expect(stored, isTrue);
      expect(find.text('Brought in 3'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('and the choice is written BEFORE the first read', (tester) async {
      // A read that takes a while must not leave the person with a switch that is
      // on and nothing remembered if the app is closed during it.
      await show(tester, (c) => turnOn(c, alreadyAllowed: true));

      await tester.tap(find.text('go'));
      await settle(tester);

      expect(events.indexOf('enabled=true'), lessThan(events.indexOf('read')));
      await tester.pump(const Duration(seconds: 8));
    });
  });

  group('when it has to ask', () {
    testWidgets('granted: asks once, then carries on', (tester) async {
      var on = false;
      await show(tester, (c) async => on = await turnOn(c));

      await tester.tap(find.text('go'));
      await settle(tester);

      expect(on, isTrue);
      expect(events, ['allowed?', 'ask', 'enabled=true', 'read']);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('declined: says so, reads nothing, leaves it off', (tester) async {
      var on = true;
      await show(tester, (c) async => on = await turnOn(c, grants: false));

      await tester.tap(find.text('go'));
      await settle(tester);

      expect(on, isFalse);
      expect(events, ['allowed?', 'ask']);
      expect(stored, isNull, reason: 'it was never switched on');
      expect(find.text('It did not share, so nothing was counted.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });
  });

  group('when the read goes wrong', () {
    testWidgets('a store that did not answer: stays ON, and says it will catch up',
        (tester) async {
      var on = false;
      await show(tester, (c) async {
        on = await turnOn(c,
            alreadyAllowed: true,
            read: () async => throw const HealthReadException('provider busy'));
      });

      await tester.tap(find.text('go'));
      await settle(tester);

      expect(on, isTrue);
      expect(stored, isTrue, reason: 'nothing is wrong with the choice');
      expect(find.text('Switched on, but it did not answer just now.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('anything else: the choice is TAKEN BACK, so the toast and what is stored agree',
        (tester) async {
      var on = true;
      await show(tester, (c) async {
        on = await turnOn(c,
            alreadyAllowed: true, read: () async => throw StateError('disk full'));
      });

      await tester.tap(find.text('go'));
      await settle(tester);

      expect(on, isFalse);
      expect(events, ['allowed?', 'enabled=true', 'enabled=false']);
      expect(stored, isFalse);
      expect(find.text('Could not switch this on. Please try again.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('a failure BEFORE it was switched on has nothing to take back', (tester) async {
      var on = true;
      await show(tester, (c) async {
        on = await HealthImportTurnOn.run<int>(
          c,
          name: 'TestImport',
          allowed: () async => throw StateError('plugin missing'),
          ask: () async => true,
          setEnabled: (enabled) async => events.add('enabled=$enabled'),
          read: () async => 1,
          declinedMessage: 'x',
          silentMessage: 'y',
          report: (c, n) {},
        );
      });

      await tester.tap(find.text('go'));
      await settle(tester);

      expect(on, isFalse);
      expect(events, isEmpty, reason: 'it was never on, so it is not switched off either');
      expect(find.text('Could not switch this on. Please try again.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('a choice that cannot be taken back does not hide the failure', (tester) async {
      var on = true;
      await show(tester, (c) async {
        on = await turnOn(c,
            alreadyAllowed: true,
            read: () async => throw StateError('disk full'),
            setEnabled: (enabled) async {
              events.add('enabled=$enabled');
              if (!enabled) throw StateError('preferences are gone');
            });
      });

      await tester.tap(find.text('go'));
      await settle(tester);

      expect(on, isFalse);
      expect(find.text('Could not switch this on. Please try again.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('a custom failure message is the one said', (tester) async {
      await show(tester, (c) async {
        await HealthImportTurnOn.run<int>(
          c,
          name: 'TestImport',
          allowed: () async => true,
          ask: () async => true,
          setEnabled: (_) async {},
          read: () async => throw StateError('x'),
          declinedMessage: 'x',
          silentMessage: 'y',
          report: (c, n) {},
          failedMessage: 'Something else.',
        );
      });

      await tester.tap(find.text('go'));
      await settle(tester);

      expect(find.text('Something else.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });
  });

  testWidgets('a screen that is gone when the permission sheet closes: still switched on',
      (tester) async {
    // The person tapped the switch and said yes; the screen went away while the
    // sheet was up. The grant is held and remembered — the choice must be saved too,
    // or the next visit finds an off switch with the permission already in place.
    var on = false;
    final sheet = Completer<bool>();
    await show(tester, (c) async {
      on = await HealthImportTurnOn.run<int>(
        c,
        name: 'TestImport',
        allowed: () async => false,
        ask: () => sheet.future,
        setEnabled: (enabled) async {
          events.add('enabled=$enabled');
          stored = enabled;
        },
        read: () async {
          events.add('read');
          return 2;
        },
        declinedMessage: 'It did not share.',
        silentMessage: 'It did not answer.',
        report: (context, result) => events.add('report'),
      );
    });

    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    sheet.complete(true);
    await settle(tester);

    expect(stored, isTrue, reason: 'saved, though nobody is looking');
    expect(events, ['enabled=true', 'read'], reason: 'and read, but not reported to a gone screen');
    expect(on, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('and one that is gone when it is declined is simply left off', (tester) async {
    var on = true;
    final sheet = Completer<bool>();
    await show(tester, (c) async {
      on = await HealthImportTurnOn.run<int>(
        c,
        name: 'TestImport',
        allowed: () async => false,
        ask: () => sheet.future,
        setEnabled: (enabled) async => stored = enabled,
        read: () async => 0,
        declinedMessage: 'It did not share.',
        silentMessage: 'It did not answer.',
        report: (context, result) {},
      );
    });

    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    sheet.complete(false);
    await settle(tester);

    expect(on, isFalse);
    expect(stored, isNull, reason: 'nothing was asked to be switched on');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a screen that is gone by the time it answers is not spoken to', (tester) async {
    var on = false;
    final gate = Completer<int>();
    await show(tester, (c) async {
      on = await turnOn(c, alreadyAllowed: true, read: () => gate.future);
    });

    await tester.tap(find.text('go'));
    await tester.pump();
    expect(stored, isTrue, reason: 'the premise: it is on, and the read is under way');
    // The page is replaced while the read is under way, then the read finishes.
    await tester.pumpWidget(const SizedBox.shrink());
    gate.complete(3);
    await settle(tester);

    expect(on, isTrue, reason: 'it IS on: the read finished');
    expect(stored, isTrue);
    expect(tester.takeException(), isNull);
  });
}
