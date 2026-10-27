/// The card on screen: what it says, the call button, the picture, and edits.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/contact_launcher.dart';
import 'package:tablet_remainder/core/services/emergency_contact.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import 'package:tablet_remainder/features/home/screens/emergency_card_screen.dart';
import 'package:tablet_remainder/features/home/services/emergency_card_export.dart';
import 'package:tablet_remainder/features/home/widgets/emergency_card_view.dart';
import 'package:tablet_remainder/features/medication/models/dependent_profile.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

import '../../support/font_free_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  final now = DateTime(2026, 6, 30, 10);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    ActiveProfileService().resetForTesting();
  });

  tearDown(() async {
    ContactLauncher.launcherOverride = null;
    EmergencyCardExport.shareOverride = null;
    await db.close();
  });

  Future<void> me({List<String>? allergies, List<String>? conditions}) =>
      MedicineCleanStorageService.addDependent(DependentProfile(
        id: 'self',
        name: 'Priya Nair',
        relationship: RelationshipType.self,
        dateOfBirth: DateTime(1990, 1, 1),
        bloodType: 'O+',
        allergies: allergies,
        conditions: conditions,
      ));

  Future<void> metformin() => MedicineCleanStorageService.addMedicine(
        EnhancedMedicine(
          id: 'm1',
          name: 'Metformin',
          strength: '500mg',
          dosageForm: DosageForm.tablet,
          dosageAmount: 1,
          dosageUnit: 'tablet',
          createdAt: DateTime(2026, 1, 1),
          schedule: MedicineSchedule.onceDaily(hour: 8, minute: 0),
        ),
        stampActiveProfile: false,
      );

  Future<void> frames(WidgetTester tester, [int n = 8]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pump(WidgetTester tester, {double width = 390, double scale = 1}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, 2400);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
        MaterialApp(theme: fontFreeTheme(), home: const EmergencyCardScreen()));
    await frames(tester);
  }

  Future<R> pinned<R>(Future<R> Function() body) => withClock(Clock.fixed(now), body);

  group('what it says', () {
    testWidgets('everything it knows, large and plain', (tester) async {
      await pinned(() async {
        await me(allergies: ['Penicillin', 'Peanuts'], conditions: ['Asthma']);
        await metformin();
        await EmergencyContact.save(name: 'Arun', phone: '+91 98765 43210');
        await pump(tester);

        expect(find.text('EMERGENCY CARD'), findsOneWidget);
        expect(find.text('Priya Nair'), findsOneWidget);
        expect(find.text('36 years · Blood type O+'), findsOneWidget);
        expect(find.text('Penicillin'), findsOneWidget);
        expect(find.text('Peanuts'), findsOneWidget);
        expect(find.text('Asthma'), findsOneWidget);
        expect(find.text('Metformin 500mg · 1 tablet'), findsOneWidget);
        expect(find.text('Arun · +91 98765 43210'), findsOneWidget);
        expect(find.text('Not recorded'), findsNothing);
      });
    });

    testWidgets('what nobody wrote down says "Not recorded", never "None"',
        (tester) async {
      await pinned(() async {
        await me();
        await pump(tester);
        // Allergies, conditions, medicines, contact.
        expect(find.text('Not recorded'), findsNWidgets(4));
        expect(find.text('None'), findsNothing);
      });
    });
  });

  group('the call', () {
    testWidgets('opens the dialer on the contact, and does not ring', (tester) async {
      await pinned(() async {
        await me();
        await EmergencyContact.save(name: 'Arun', phone: '+91 98765 43210');
        Uri? opened;
        ContactLauncher.launcherOverride = (uri) async {
          opened = uri;
          return true;
        };
        await pump(tester);

        await tester.tap(find.text('Call Arun'));
        await frames(tester, 3);
        expect(opened.toString(), 'tel:+919876543210');
      });
    });

    testWidgets('a contact with no name is called by number', (tester) async {
      await pinned(() async {
        await me();
        await EmergencyContact.save(name: '', phone: '+91 98765 43210');
        await pump(tester);
        expect(find.text('Call +91 98765 43210'), findsOneWidget);
      });
    });

    testWidgets('no dialer: it says the number', (tester) async {
      await pinned(() async {
        await me();
        await EmergencyContact.save(name: 'Arun', phone: '+91 98765 43210');
        ContactLauncher.launcherOverride = (_) async => false;
        await pump(tester);

        await tester.tap(find.text('Call Arun'));
        await frames(tester, 4);
        expect(find.text('Could not call'), findsOneWidget);
        expect(find.textContaining('The number is +91 98765 43210'), findsOneWidget);
      });
    });

    testWidgets('with no contact, it offers to add one; the sheet puts it on the card',
        (tester) async {
      await pinned(() async {
        await me();
        await pump(tester);
        expect(find.textContaining('Call '), findsNothing);

        await tester.tap(find.text('Add an emergency contact'));
        await frames(tester, 6);
        await tester.enterText(find.byType(TextField).first, 'Arun');
        await tester.enterText(find.byType(TextField).last, '+91 98765 43210');
        await tester.pump();
        await tester.runAsync(() async {
          await tester.tap(find.widgetWithText(AppButton, 'Save'));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await frames(tester, 10);

        expect(find.text('Call Arun'), findsOneWidget);
        expect(find.text('Arun · +91 98765 43210'), findsOneWidget);
      });
    });
  });

  group('the picture', () {
    testWidgets('a PNG of the card, and the card as text beside it', (tester) async {
      await pinned(() async {
        await me(allergies: ['Penicillin']);
        await EmergencyContact.save(name: 'Arun', phone: '+91 98765 43210');
        List<int>? png;
        String? text;
        EmergencyCardExport.shareOverride = (bytes, t) async {
          png = bytes;
          text = t;
        };
        await pump(tester);

        await tester.runAsync(() async {
          await tester.tap(find.text('Share as a picture'));
          await Future<void>.delayed(const Duration(milliseconds: 600));
        });
        await frames(tester, 3);

        expect(png, isNotNull, reason: 'the share sheet got a picture');
        expect(png!.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10],
            reason: 'a PNG');
        expect(png!.length, greaterThan(2000));
        expect(text, startsWith('EMERGENCY CARD'));
        expect(text, contains('Allergies: Penicillin'));
        expect(text, contains('Emergency contact: Arun · +91 98765 43210'));
      });
    });

    testWidgets('the picture is the card at 3x, without the buttons', (tester) async {
      await pinned(() async {
        await me();
        await EmergencyContact.save(name: 'Arun', phone: '+91 98765 43210');
        List<int>? png;
        EmergencyCardExport.shareOverride = (bytes, t) async => png = bytes;
        await pump(tester);
        final card = tester.getSize(find.byType(EmergencyCardView));

        await tester.runAsync(() async {
          await tester.tap(find.text('Share as a picture'));
          await Future<void>.delayed(const Duration(milliseconds: 600));
        });
        await frames(tester, 3);

        // IHDR: width then height, big-endian, from byte 16.
        int at(int i) =>
            (png![i] << 24) | (png![i + 1] << 16) | (png![i + 2] << 8) | png![i + 3];
        expect(at(16), card.width * 3, reason: 'three pixels to a point');
        expect(at(20), card.height * 3,
            reason: 'the card and nothing under it: no buttons in the picture');
      });
    });

    testWidgets('a share that fails says so and leaves the button usable',
        (tester) async {
      await pinned(() async {
        await me();
        EmergencyCardExport.shareOverride = (_, _) async => throw StateError('no share');
        await pump(tester);
        await tester.runAsync(() async {
          await tester.tap(find.text('Share as a picture'));
          await Future<void>.delayed(const Duration(milliseconds: 600));
        });
        await frames(tester, 4);
        expect(find.text('Could not share the card.'), findsOneWidget);
        expect(
            tester.widget<AppButton>(find.widgetWithText(AppButton, 'Share as a picture'))
                .loading,
            isFalse);
      });
    });
  });

  group('editing', () {
    testWidgets('Edit details opens the profile; what is saved is on the card',
        (tester) async {
      await pinned(() async {
        await me();
        await pump(tester);
        expect(find.text('Penicillin'), findsNothing);

        await tester.tap(find.text('Edit details'));
        await frames(tester, 8);
        expect(find.text('Edit profile'), findsOneWidget);

        await tester.enterText(
            find.descendant(
                of: find.widgetWithText(AppTextField, 'Allergies'),
                matching: find.byType(TextField)),
            'Penicillin');
        await tester.pump();
        await tester.runAsync(() async {
          await tester.tap(find.widgetWithText(AppButton, 'Save'));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await frames(tester, 12);

        expect(find.text('Edit profile'), findsNothing);
        expect(find.text('Penicillin'), findsOneWidget);
      });
    });

    testWidgets("someone you look after: their card, and adding a contact goes to their profile",
        (tester) async {
      await pinned(() async {
        await me(allergies: ['Latex']);
        await MedicineCleanStorageService.addDependent(DependentProfile(
          id: 'kid',
          name: 'Aarav',
          relationship: RelationshipType.child,
          allergies: ['Peanuts'],
        ));
        await ActiveProfileService().setActiveDependent('kid');
        await pump(tester);

        expect(find.text('Aarav'), findsOneWidget);
        expect(find.text('Peanuts'), findsOneWidget);
        expect(find.text('Latex'), findsNothing);

        await tester.tap(find.text('Add an emergency contact'));
        await frames(tester, 8);
        expect(find.text('Edit profile'), findsOneWidget,
            reason: 'their contact lives on their profile');
      });
    });
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('fits at 320pt and ${scale}x text, with a long card', (tester) async {
      await pinned(() async {
        await me(
          allergies: ['Penicillin', 'Peanuts', 'Latex', 'Shellfish and other seafood'],
          conditions: ['Type 2 diabetes mellitus', 'Chronic obstructive pulmonary disease'],
        );
        for (var i = 0; i < 6; i++) {
          await MedicineCleanStorageService.addMedicine(
            EnhancedMedicine(
              id: 'm$i',
              name: 'Metformin hydrochloride extended release $i',
              strength: '500mg',
              dosageForm: DosageForm.tablet,
              dosageAmount: 1,
              dosageUnit: 'tablet',
              createdAt: DateTime(2026, 1, 1),
              schedule: MedicineSchedule.onceDaily(hour: 8, minute: 0),
            ),
            stampActiveProfile: false,
          );
        }
        await EmergencyContact.save(
            name: 'Arun Kumar Venkataraghavan', phone: '+91 98765 43210');

        final reports = <String>[];
        final prev = FlutterError.onError;
        FlutterError.onError = (d) => reports.add(d.toString());
        try {
          await pump(tester, width: 320, scale: scale);
        } finally {
          FlutterError.onError = prev;
        }
        expect(find.text('EMERGENCY CARD'), findsOneWidget);
        expect(
            reports.where((r) =>
                r.contains('emergency_card_view.dart') ||
                r.contains('emergency_card_screen.dart')),
            isEmpty,
            reason: reports.join('\n').split('\n').take(6).join('\n'));
      });
    });
  }
}
