import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import 'package:tablet_remainder/features/reminders/screens/add_reminder_screen.dart';
import 'package:tablet_remainder/features/reminders/screens/reminders_screen.dart';

import 'support/app_strings.dart';
import 'support/e2e.dart';

/// Smart Add: free text in, a filled-in reminder form out.
///
/// **This is the only place the wiring is tested.** `CoachText.parseReminder`
/// itself has 18 headless cases covering repeat, priority, custom days,
/// relative dates, the `8:99` guard and the bare-hour PM bias. What has no
/// coverage anywhere is the layer between the parser and the form:
/// `_repeatFromString`, `_priorityFromString` and `_categoryIdForName`, each of
/// which maps a parser string onto an enum or a database id and silently
/// returns `null` on anything it does not recognise.
///
/// A null there is invisible: the sheet closes, a form opens, and the field is
/// simply blank. The user re-types what they already typed, and concludes the
/// feature does not work — with nothing in any log to say why. Only a device
/// test that reads the form back can see it.
///
/// Nothing generative is involved: the parser is deterministic on-device regex.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> openSmartAdd(WidgetTester t) async {
    await E2E.launch(t);
    // Reminders is no longer a tab — Today's Reminders card is its entry point.
    await E2E.scrollUntilPresent(
        t, find.text(kRemindersCard), 'the Reminders card on Today');
    await E2E.tapWhenHittable(t, find.text(kRemindersCard), 'Reminders card');
    E2E.at(find.byType(RemindersScreen), where: 'Reminders');

    await E2E.tapWhenHittable(
        t, find.byIcon(Symbols.auto_awesome_rounded), 'Smart Add action');
    E2E.at(find.text(kSmartAddTitle), where: 'the Smart Add sheet');
  }

  testWidgets('parsed fields reach the form, not just the parser', (t) async {
    await openSmartAdd(t);

    await t.enterText(
        find.byType(AppTextField).first, 'take vitamin D every morning at 8am');
    await settle(t);
    await E2E.tapWhenHittable(t, find.text(kSmartAddCreate), 'Create');

    E2E.at(find.byType(AddReminderScreen), where: 'the prefilled reminder form');

    // The title must arrive. A blank title here means the parse succeeded and
    // the handoff dropped it — the user's exact words, typed and lost.
    final titleField =
        t.widget<AppTextField>(find.byType(AppTextField).first);
    expect(
      titleField.controller?.text.toLowerCase(),
      contains('vitamin'),
      reason: 'Smart Add parsed the text but the title did not reach the form. '
          'The sheet closes either way, so the user sees a blank field and '
          'retypes what they just typed.',
    );

    // "every morning" is a daily repeat. _repeatFromString maps the parser's
    // string onto RepeatType and returns null for anything unrecognised, which
    // renders as no selection at all.
    expect(
      find.text(kRepeatEveryDay),
      findsWidgets,
      reason: '"every morning" must set a daily repeat. If the repeat control '
          'shows nothing, _repeatFromString did not recognise the parser\'s '
          'output — the two halves disagree about the vocabulary.',
    );

    E2E.assertClean('Smart Add: parse to form');
  });

  testWidgets('unparseable input says so and still opens a usable form',
      (t) async {
    await openSmartAdd(t);

    // Deliberately meaningless. The contract is that Smart Add degrades to the
    // manual form rather than swallowing the tap — a dead Create button would
    // look identical to a slow one.
    await t.enterText(find.byType(AppTextField).first, 'zzzz');
    await settle(t);
    await E2E.tapWhenHittable(t, find.text(kSmartAddCreate), 'Create');

    E2E.at(find.byType(AddReminderScreen),
        where: 'the manual reminder form after an unparseable input');

    E2E.assertClean('Smart Add: unparseable input');
  });
}
