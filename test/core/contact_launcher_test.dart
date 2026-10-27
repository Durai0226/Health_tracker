/// The dialer and the messages app, opened and not pressed.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/services/contact_launcher.dart';

void main() {
  tearDown(() => ContactLauncher.launcherOverride = null);

  Uri? opened;
  void record({bool result = true}) => ContactLauncher.launcherOverride = (uri) async {
        opened = uri;
        return result;
      };

  setUp(() => opened = null);

  test('dialable keeps the digits and a leading plus', () {
    expect(ContactLauncher.dialable('+91 (98765) 43-210'), '+91987654321' '0');
    expect(ContactLauncher.dialable('  0044 20 7946 0958 '), '00442079460958');
    expect(ContactLauncher.dialable('ext. 12'), '12');
    expect(ContactLauncher.dialable(''), '');
  });

  test('call opens the dialer on the number', () async {
    record();
    expect(await ContactLauncher.call('+91 98765 43210'), isTrue);
    expect(opened.toString(), 'tel:+919876543210');
  });

  test('text opens the messages app with the words typed in', () async {
    record();
    await ContactLauncher.text('+91 98765 43210', body: 'I missed a dose. Can you check on me?');
    expect(opened!.scheme, 'sms');
    expect(opened!.path, '+919876543210');
    expect(opened!.toString(),
        'sms:+919876543210?body=I%20missed%20a%20dose.%20Can%20you%20check%20on%20me%3F',
        reason: 'a space is %20, not the + that some apps print as a plus');
  });

  test('text with nothing to say is just the number', () async {
    record();
    await ContactLauncher.text('+91 98765 43210');
    expect(opened.toString(), 'sms:+919876543210');
  });

  test('false when nothing could open it', () async {
    record(result: false);
    expect(await ContactLauncher.call('112'), isFalse);
  });

  test('with no dialer to open it is false, not an error', () async {
    // No override and no plugin behind the channel, as on a device with none.
    TestWidgetsFlutterBinding.ensureInitialized();
    expect(await ContactLauncher.call('112'), isFalse);
    expect(await ContactLauncher.text('112', body: 'hi'), isFalse);
  });
}
