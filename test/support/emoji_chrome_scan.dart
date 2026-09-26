/// Source scan for emoji rendered through a `Text(` widget.
///
/// Lifted out of `test/features/focus/focus_guards_test.dart` when the water
/// feature needed the same rule (DS-17: emoji used as chrome in the quick-add
/// grid, timeline and history). The two features draw the line in different
/// places — Focus legitimately renders a 28pt 🌳 because the plant IS the
/// garden metaphor, water has no such content beyond the cup glyph the user
/// picked themselves — so the POLICY stays with each guard and only the scan
/// is shared. A second copy of the regex is how the two would drift apart.
library;

import 'dart:io';

/// One line that renders an emoji through a `Text(`.
class EmojiTextLine {
  /// Path as [Directory.listSync] reported it, e.g. `lib/features/water/...`.
  final String path;

  /// 1-based, so it pastes straight into an editor.
  final int lineNumber;

  final String source;

  /// The `fontSize:` set on this same line, or null when the size comes from a
  /// theme text style — which is how the water feature writes them, and why a
  /// font-size rule alone cannot police it.
  final int? fontSize;

  const EmojiTextLine({
    required this.path,
    required this.lineNumber,
    required this.source,
    required this.fontSize,
  });

  @override
  String toString() => '$path:$lineNumber  ${source.trim()}';
}

/// Matches the emoji blocks the UI audit was written against: the pictographic
/// planes plus the older Miscellaneous Symbols / Dingbats range that ☕ ☀ ✨
/// live in.
final RegExp _emoji = RegExp(
  r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]',
  unicode: true,
);

/// A `Text(` whose first argument READS an emoji rather than spelling one out:
/// `Text(container.emoji)`, `Text(achievement.tierEmoji)`, `Text(emoji)`,
/// `Text('${b.emoji} ...')`.
///
/// This is the shape the water audit was actually about — the quick-add tile
/// rendered `Text(beverage.emoji)`, with the glyph coming from the model, so a
/// scan that looks only for literal emoji characters passes with the defect
/// fully restored. Bounded by `[^,)]` so it cannot run past the first argument
/// into `style: theme.emojiStyle`.
final RegExp _emojiFieldRead = RegExp(r'\bText\(\s*[^,)]{0,120}[Ee]moji\b');

final RegExp _fontSize = RegExp(r'fontSize:\s*(\d+)');

/// The opt-out marker. Required INLINE on the offending line so it cannot drift
/// away from what it excuses — the same idiom the haptic and notification
/// guards use.
const String kEmojiContentOptOut = 'emoji-content-ok:';

List<File> _dartFilesUnder(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) =>
        f.path.endsWith('.dart') &&
        !f.path.endsWith('.g.dart') &&
        !f.path.endsWith('.freezed.dart'))
    .toList();

/// Whether the opt-out marker covers line [i] of [lines] — either inline on it
/// or somewhere in the unbroken `//` comment block immediately above it.
///
/// Inline-only was the original rule, and it works while every hit is a short
/// literal. A field read is usually a bare `Text(sound.emoji,` buried in a
/// widget tree, where the sentence explaining why the glyph is content does not
/// fit on the line and the reason is written as a block above. The block cannot
/// drift away from what it excuses any more than an inline marker can: put a
/// line of code between them and it stops being the block above.
bool _optedOut(List<String> lines, int i) {
  if (lines[i].contains(kEmojiContentOptOut)) return true;
  for (var j = i - 1; j >= 0 && lines[j].trimLeft().startsWith('//'); j--) {
    if (lines[j].contains(kEmojiContentOptOut)) return true;
  }
  return false;
}

/// Every `Text(` line under [dir] that renders an emoji and is not annotated
/// `// $kEmojiContentOptOut <reason>`.
///
/// With [includeFieldReads] the scan also reports a `Text(` whose argument
/// READS an emoji — `Text(beverage.emoji)` — instead of spelling one out. That
/// is off by default because it is a redesign, not a guard, for a feature whose
/// model is emoji-keyed on purpose: Focus stores one glyph per plant species,
/// ambient sound and tag. Water's catalog glyphs all moved to
/// `AquaTheme.iconFor`, so water can hold the strict line — and has to, because
/// the defect DS-17 names was written as a field read and a literal-only scan
/// passes with it fully restored.
///
/// Reads raw source rather than comment-stripped source on purpose: stripping
/// comment LINES would delete the opt-out annotation before it could be seen.
/// Whole-line comments are skipped by hand instead, so this never fires on
/// prose that merely mentions an emoji.
///
/// Line-based, so a `Text(` whose argument sits on the NEXT line is invisible
/// to it. That is a known hole, not a claim of completeness.
List<EmojiTextLine> unannotatedEmojiTextLines(
  String dir, {
  bool includeFieldReads = false,
}) {
  final out = <EmojiTextLine>[];
  for (final f in _dartFilesUnder(dir)) {
    final lines = f.readAsStringSync().split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trimLeft().startsWith('//')) continue;
      if (!line.contains('Text(')) continue;
      final hit = _emoji.hasMatch(line) ||
          (includeFieldReads && _emojiFieldRead.hasMatch(line));
      if (!hit) continue;
      if (_optedOut(lines, i)) continue;
      final m = _fontSize.firstMatch(line);
      out.add(EmojiTextLine(
        path: f.path,
        lineNumber: i + 1,
        source: line,
        fontSize: m == null ? null : int.parse(m.group(1)!),
      ));
    }
  }
  return out;
}
