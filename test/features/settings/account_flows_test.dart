/// Signing out stays in the app, and deleting an account on a stale sign-in asks
/// the person to confirm it is them right there.
///
/// Sign-out used to push the first-run onboarding over someone who had been using
/// the app for months. Deleting an account on a session Firebase thought too old
/// told them to sign out, sign in and find their way back — with no way to do the
/// sign-in from the screen that had just refused.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/auth_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/widgets/app/app_switch.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart' show AppListTile;
import 'package:tablet_remainder/features/onboarding/screens/welcome_screen.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';
import 'package:tablet_remainder/features/settings/screens/settings_screen.dart';

import '../../support/font_free_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  final signedIn = UserModel(id: 'u1', name: 'Sam', email: 'sam@example.com');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    ActiveProfileService().resetForTesting();
  });

  tearDown(() async {
    final auth = AuthService();
    auth.setUserForTesting(null);
    auth.accountDeleterForTesting = null;
    auth.reauthenticatorForTesting = null;
    await db.close();
  });

  group('the account check', () {
    test('the same account, in any case, is fine', () {
      expect(
          AuthService.reauthAccountMismatch(
              signedInEmail: 'sam@example.com', chosenEmail: 'sam@example.com'),
          isNull);
      expect(
          AuthService.reauthAccountMismatch(
              signedInEmail: 'Sam@Example.com', chosenEmail: 'sam@example.COM'),
          isNull);
    });

    test('another account is refused, with a message that says which to pick', () {
      final m = AuthService.reauthAccountMismatch(
          signedInEmail: 'sam@example.com', chosenEmail: 'alex@example.com');
      expect(m, AuthService.reauthWrongAccountMessage);
      expect(m, contains('different Google account'));
    });

    test('with no email to compare against there is nothing to refuse', () {
      expect(
          AuthService.reauthAccountMismatch(chosenEmail: 'alex@example.com'), isNull);
      expect(
          AuthService.reauthAccountMismatch(
              signedInEmail: '', chosenEmail: 'alex@example.com'),
          isNull);
    });
  });

  group('who can be confirmed', () {
    test('an account made with Google', () {
      expect(AuthService.canReauthenticateWithGoogle(const ['google.com']), isTrue);
      expect(AuthService.canReauthenticateWithGoogle(const ['password', 'google.com']), isTrue);
    });

    test('nothing else: not a password account, not an anonymous one with no provider', () {
      expect(AuthService.canReauthenticateWithGoogle(const ['password']), isFalse);
      expect(AuthService.canReauthenticateWithGoogle(const ['apple.com', 'phone']), isFalse);
      expect(AuthService.canReauthenticateWithGoogle(const []), isFalse);
    });

    test('and it says so plainly, not "a different Google account"', () {
      expect(AuthService.reauthNotGoogleMessage, contains('not made with Google'));
      expect(AuthService.reauthNotGoogleMessage, isNot(contains('different')));
    });
  });

  group('how old the sign-in is, judged before anything is deleted', () {
    final now = DateTime(2026, 9, 30, 12);
    final old = now.subtract(const Duration(hours: 6));
    final justNow = now.subtract(const Duration(seconds: 20));

    late List<String> calls;

    Future<String?> run({
      required DateTime? signedInAt,
      required Future<DateTime?> Function() tokenAuthTime,
      List<String> cloudFailures = const [],
    }) {
      calls = [];
      return AuthService.deleteSignedInAccount(
        signedInAt: signedInAt,
        tokenAuthTime: tokenAuthTime,
        now: now,
        deleteCloudData: () async {
          calls.add('cloud');
          return cloudFailures;
        },
        deleteAuthUser: () async => calls.add('user'),
      );
    }

    test('a recent sign-in goes straight through', () async {
      final message = await run(signedInAt: justNow, tokenAuthTime: () async => justNow);

      expect(message, isNull);
      expect(calls, ['cloud', 'user']);
    });

    test('a stale one is refused with nothing deleted', () async {
      final message = await run(signedInAt: old, tokenAuthTime: () async => old);

      expect(message, AuthService.reauthRequiredMessage);
      expect(calls, isEmpty, reason: 'the refusal comes before the first document goes');
    });

    test('a confirmation just given counts, though the account\'s own sign-in time did not move',
        () async {
      // The SDK does not promise `lastSignInTime` moves on a re-authentication;
      // the token's auth time is what does.
      final message = await run(signedInAt: old, tokenAuthTime: () async => justNow);

      expect(message, isNull);
      expect(calls, ['cloud', 'user']);
    });

    test('and one that has NOT reached the token is refused — on trust it would not be',
        () async {
      // Re-authentication reported success but the token Firebase will judge the
      // deletion by is still the old one. Taken on trust, this deleted the cloud
      // data first and found out from `user.delete()` afterwards.
      final message = await run(signedInAt: old, tokenAuthTime: () async => old);

      expect(message, AuthService.reauthRequiredMessage);
      expect(calls, isEmpty);
    });

    test('the later of the two times is the one used, whichever it is', () async {
      expect(await run(signedInAt: justNow, tokenAuthTime: () async => old), isNull,
          reason: 'a recent account sign-in is not undone by an older token');
      expect(calls, ['cloud', 'user']);
    });

    test('a token that cannot be read leaves the account\'s sign-in time to decide', () async {
      final fresh = await run(
          signedInAt: justNow, tokenAuthTime: () async => throw StateError('offline'));
      expect(fresh, isNull);
      expect(calls, ['cloud', 'user']);

      final stale = await run(
          signedInAt: old, tokenAuthTime: () async => throw StateError('offline'));
      expect(stale, AuthService.reauthRequiredMessage);
      expect(calls, isEmpty);
    });

    test('a token with no time on it, and no sign-in time either, is stale', () async {
      final message = await run(signedInAt: null, tokenAuthTime: () async => null);

      expect(message, AuthService.reauthRequiredMessage);
      expect(calls, isEmpty);
    });

    test('a token time with no sign-in time to compare it with is used', () async {
      final message = await run(signedInAt: null, tokenAuthTime: () async => justNow);

      expect(message, isNull);
      expect(calls, ['cloud', 'user']);
    });

    test('cloud data that could not all be deleted still keeps the account', () async {
      final message = await run(
          signedInAt: justNow,
          tokenAuthTime: () async => justNow,
          cloudFailures: ['backups']);

      expect(message, contains('backups'));
      expect(calls, ['cloud'], reason: 'the account is not deleted over what is left');
    });
  });

  group('in Settings', () {
    Future<void> openSettings(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(430, 3000);
      addTearDown(tester.view.reset);
      final prev = FlutterError.onError;
      FlutterError.onError = (d) {
        if (!'${d.exception}'.contains('overflowed')) prev?.call(d);
      };
      addTearDown(() => FlutterError.onError = prev);
      await tester.pumpWidget(
          MaterialApp(theme: fontFreeTheme(), home: const SettingsScreen()));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> pumpFor(WidgetTester tester, {int steps = 8}) async {
      for (var i = 0; i < steps; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)));
      await pumpFor(tester);
      await tester.pump(const Duration(seconds: 8));
    }

    Future<void> seedReminder(WidgetTester tester) async {
      await tester.runAsync(() => CleanStorageService.saveReminder(Reminder(
            id: 'r1',
            title: 'Stretch',
            body: '',
            scheduledTime: DateTime(2030, 1, 1, 9),
          )));
    }

    Future<int> reminderCount(WidgetTester tester) async =>
        (await tester.runAsync(() => CleanStorageService.getAllReminders()))!.length;

    Future<void> tapRow(WidgetTester tester, String text) async {
      await tester.ensureVisible(find.text(text).first);
      await tester.pump();
      await tester.tap(find.text(text).first);
      await pumpFor(tester, steps: 6);
    }

    group('sign out', () {
      testWidgets('confirms, then stays on Settings and says what happened',
          (tester) async {
        await tester.runAsync(() => CleanStorageService.setCloudSyncEnabled(true));
        AuthService().setUserForTesting(signedIn);
        await openSettings(tester);
        AppSwitch syncSwitch() => tester.widget<AppSwitch>(find.descendant(
            of: find.ancestor(of: find.text('Cloud sync'), matching: find.byType(AppListTile)),
            matching: find.byType(AppSwitch)));
        await tester.ensureVisible(find.text('Cloud sync'));
        expect(syncSwitch().value, isTrue, reason: 'the premise: sync was on');

        await tapRow(tester, 'Sign Out');
        expect(find.text('Are you sure you want to sign out? Your local data will be preserved.'),
            findsOneWidget);
        await tester.tap(find.text('Sign Out').last);
        await settle(tester);

        expect(find.byType(WelcomeScreen), findsNothing,
            reason: 'the first-run onboarding is not what follows signing out');
        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(find.textContaining('Your data stays on this phone, and cloud sync is off'),
            findsOneWidget);
        expect(AuthService().isAuthenticated, isFalse);

        // Signing out switched sync off underneath a screen that read the switch once
        // when it was built. The screen used to be replaced, which hid that; it stays
        // now, and went on showing sync ON.
        expect(CleanStorageService.cloudSyncEnabled, isFalse);
        await tester.ensureVisible(find.text('Cloud sync'));
        expect(syncSwitch().value, isFalse,
            reason: 'it read ON until something else rebuilt the screen');
      });

      testWidgets('cancelling stays signed in', (tester) async {
        AuthService().setUserForTesting(signedIn);
        await openSettings(tester);

        await tapRow(tester, 'Sign Out');
        await tester.tap(find.text('Cancel'));
        await settle(tester);

        expect(AuthService().isAuthenticated, isTrue);
        expect(find.textContaining('Signed out'), findsNothing);
      });

      testWidgets('the row no longer promises the welcome screen, signed in or as a guest',
          (tester) async {
        AuthService().setUserForTesting(signedIn);
        await openSettings(tester);
        await tester.ensureVisible(find.text('Sign Out').first);
        expect(find.text('Return to welcome screen'), findsNothing);
        expect(find.text("You'll continue as a guest"), findsOneWidget);
      });

      testWidgets('a guest\'s row says the data stays', (tester) async {
        AuthService().setUserForTesting(signedIn, guest: true);
        await openSettings(tester);
        await tester.ensureVisible(find.text('Sign Out').first);

        expect(find.text('Return to welcome screen'), findsNothing);
        expect(find.text('Your data stays on this phone'), findsOneWidget);
      });
    });

    group('deleting the account', () {
      late int deletions;
      late int reauths;

      /// The sign-in is too old until the person confirms it is them — unless
      /// [stillStaleAfter], where Firebase goes on calling it stale regardless.
      void arrange({
        required bool stale,
        String? reauthResult,
        bool stillStaleAfter = false,
      }) {
        deletions = 0;
        reauths = 0;
        var fresh = !stale;
        AuthService().accountDeleterForTesting = () async {
          deletions++;
          if (!fresh) return AuthService.reauthRequiredMessage;
          return null;
        };
        AuthService().reauthenticatorForTesting = () async {
          reauths++;
          if (reauthResult == null && !stillStaleAfter) fresh = true;
          return reauthResult;
        };
      }

      Future<void> startDelete(WidgetTester tester) async {
        await tapRow(tester, 'Delete account');
        await tester.tap(find.text('Delete my account'));
        await pumpFor(tester, steps: 6);
      }

      testWidgets('a fresh sign-in deletes at once, with no extra question',
          (tester) async {
        arrange(stale: false);
        AuthService().setUserForTesting(signedIn);
        await openSettings(tester);
        await seedReminder(tester);

        await startDelete(tester);
        await settle(tester);

        expect(find.text('Confirm it is you'), findsNothing);
        expect(reauths, 0);
        expect(deletions, 1);
        expect(await reminderCount(tester), 0, reason: 'and the device is wiped');
        expect(find.text('Account and all data deleted.'), findsOneWidget);
      });

      testWidgets('a stale one asks to sign in again, here, and carries on',
          (tester) async {
        arrange(stale: true);
        AuthService().setUserForTesting(signedIn);
        await openSettings(tester);
        await seedReminder(tester);

        await startDelete(tester);
        expect(find.text('Confirm it is you'), findsOneWidget);
        expect(find.textContaining('Nothing has been deleted yet'), findsOneWidget);
        expect(await reminderCount(tester), 1, reason: 'nothing happens until asked');

        await tester.tap(find.text('Sign in again'));
        await settle(tester);

        expect(reauths, 1);
        expect(deletions, 2, reason: 'refused, then tried once more after the confirmation');
        expect(await reminderCount(tester), 0);
        expect(find.text('Account and all data deleted.'), findsOneWidget);
      });

      testWidgets('declining the question deletes nothing and says why it stopped',
          (tester) async {
        arrange(stale: true);
        AuthService().setUserForTesting(signedIn);
        await openSettings(tester);
        await seedReminder(tester);

        await startDelete(tester);
        await tester.tap(find.text('Cancel'));
        await settle(tester);

        expect(reauths, 0);
        expect(deletions, 1);
        expect(await reminderCount(tester), 1);
        expect(find.text(AuthService.reauthRequiredMessage), findsOneWidget);
        expect(find.byIcon(Symbols.error_rounded), findsNothing,
            reason: 'declining is a choice, not something that went wrong');
        expect(find.byIcon(Symbols.info_rounded), findsWidgets);
      });

      testWidgets('closing the Google sheet is the same as declining', (tester) async {
        arrange(stale: true, reauthResult: 'cancelled');
        AuthService().setUserForTesting(signedIn);
        await openSettings(tester);
        await seedReminder(tester);

        await startDelete(tester);
        await tester.tap(find.text('Sign in again'));
        await settle(tester);

        expect(reauths, 1);
        expect(deletions, 1, reason: 'no second attempt');
        expect(await reminderCount(tester), 1);
        expect(find.text(AuthService.reauthRequiredMessage), findsOneWidget);
      });

      testWidgets('a failed confirmation shows its own message and deletes nothing',
          (tester) async {
        arrange(stale: true, reauthResult: AuthService.reauthWrongAccountMessage);
        AuthService().setUserForTesting(signedIn);
        await openSettings(tester);
        await seedReminder(tester);

        await startDelete(tester);
        await tester.tap(find.text('Sign in again'));
        await settle(tester);

        expect(deletions, 1);
        expect(await reminderCount(tester), 1);
        expect(find.textContaining('different Google account'), findsOneWidget);
      });

      testWidgets('a session Firebase still calls stale gets one retry, not a loop',
          (tester) async {
        arrange(stale: true, stillStaleAfter: true);
        AuthService().setUserForTesting(signedIn);
        await openSettings(tester);
        await seedReminder(tester);

        await startDelete(tester);
        await tester.tap(find.text('Sign in again'));
        await settle(tester);

        expect(reauths, 1);
        expect(deletions, 2);
        expect(await reminderCount(tester), 1);
        expect(find.text(AuthService.reauthRequiredMessage), findsOneWidget);
      });
    });
  });
}
