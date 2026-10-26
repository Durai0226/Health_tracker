/// A diary row must not print the same sentence twice.
///
/// [DiaryEntry.displayTitle] falls back to the body's first line when the entry
/// has no title of its own. The list row rendered that heading and then the
/// whole body underneath it, so on device every card read:
///
///     Felt steady today. Took everything on time.     (bold)
///     Felt steady today. Took everything on time.     (grey)
///     Sep 28, 2026 · 10:26 PM
///
/// A one-line note with no title is the ordinary way to use a diary, so this
/// was the normal case rather than an edge one.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/diary/models/diary_entry.dart';

DiaryEntry entry({String? title, required String body}) => DiaryEntry(
      id: 'd1',
      title: title,
      body: body,
      entryAt: DateTime(2026, 9, 28, 22, 26),
      createdAt: DateTime(2026, 9, 28, 22, 26),
    );

void main() {
  group('an entry with no title of its own', () {
    test('a single line is the heading and nothing else', () {
      // Verbatim from the seeded list.
      final e = entry(body: 'Felt steady today. Took everything on time.');
      expect(e.displayTitle, 'Felt steady today. Took everything on time.');
      expect(e.previewBody, isEmpty,
          reason: 'the heading is already the whole note; anything here is '
              'the same sentence printed a second time');
    });

    test('only the lines the heading did not show are previewed', () {
      final e = entry(body: 'Rough morning.\nBetter after a walk.\nSlept well.');
      expect(e.displayTitle, 'Rough morning.');
      expect(e.previewBody, 'Better after a walk.\nSlept well.');
      expect(e.previewBody, isNot(contains('Rough morning.')));
    });

    test('surrounding whitespace does not defeat the comparison', () {
      final e = entry(body: '   Felt steady today.   ');
      expect(e.displayTitle, 'Felt steady today.');
      expect(e.previewBody, isEmpty);
    });

    test('an empty body previews nothing', () {
      final e = entry(body: '');
      expect(e.displayTitle, 'Untitled entry');
      expect(e.previewBody, isEmpty,
          reason: 'the placeholder heading must not be followed by a blank row');
    });
  });

  group('an entry with its own title', () {
    test('the body is shown in full beneath it', () {
      final e = entry(title: 'Checkup', body: 'BP was 120/80. All fine.');
      expect(e.displayTitle, 'Checkup');
      expect(e.previewBody, 'BP was 120/80. All fine.');
    });

    test('a title that repeats the body is not printed twice', () {
      final e = entry(title: 'Felt steady today.', body: 'Felt steady today.');
      expect(e.previewBody, isEmpty);
    });
  });

  test('the heading and the preview never say the same thing', () {
    for (final e in [
      entry(body: 'One line only.'),
      entry(body: 'First.\nSecond.'),
      entry(body: ''),
      entry(title: 'T', body: 'T'),
      entry(title: 'Checkup', body: 'Different body.'),
    ]) {
      expect(e.previewBody == e.displayTitle && e.previewBody.isNotEmpty, isFalse,
          reason: 'heading "${e.displayTitle}" repeated as its own preview');
    }
  });
}
