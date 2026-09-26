/// DS-19 — the light-only theme constants, guarded on the side that hurts.
///
/// `design_tokens_guard_test.dart` already budgets the DECLARATIONS: a theme
/// class may not grow a new `static const textPrimary = AppPalette.textPrimaryL`
/// under a name that promises to work in both themes. That rule is per file and
/// counts only declarations, so it says nothing at all about who READS them —
/// and reading one is where the defect becomes visible. `NunitoTheme.textPrimary`
/// is #1A1D21 in dark mode too; a screen that adopts `NunitoTheme.heading1`
/// draws near-black on the dark background and the budget stays at 4.
///
/// So this scans the other direction: nothing outside the declaring file may
/// name a single-theme constant, or any of the static `TextStyle`s built out of
/// one. Today nothing does — `pillColors`, which is theme-neutral, is the only
/// `NunitoTheme` member with an external caller — and that is exactly the state
/// worth pinning, because the cost of keeping it is zero and the cost of
/// noticing later is a dark-mode screen nobody screenshots.
///
/// ## The member list is derived, never typed
///
/// An enumerated list is how a guard comes to cover nine of ten things. Both
/// the constants and the eleven `TextStyle` getters that bake them are read out
/// of the theme file itself, so a twelfth getter added tomorrow is covered the
/// moment it exists.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A `static const` bound to one half of a light/dark palette pair — the same
/// shape `design_tokens_guard_test.dart` budgets, and deliberately the same
/// definition so the two rules cannot disagree about what is poisoned. A
/// constant whose NAME says which theme it is (`cardLight`, `surfaceDark`) is a
/// legitimate half: the caller picks, so the caller can pick right.
final _reSingleThemeConst =
    RegExp(r'static\s+const\s+(?:Color\s+)?(\w+)\s*=\s*AppPalette\.\w+[LD]\s*;');

/// `static TextStyle get x => …` and `static const TextStyle x = …`.
final _reStaticTextStyle =
    RegExp(r'static\s+(?:const\s+)?TextStyle\s+(?:get\s+)?(\w+)\s*(?:=>|=)');

/// The declaring class, so the usage scan knows what prefix to look for.
final _reClass = RegExp(r'^class\s+(\w+)', multiLine: true);

/// Names of the single-theme colour constants in [src].
Set<String> singleThemeConsts(String src) => {
      for (final m in _reSingleThemeConst.allMatches(src))
        if (!m.group(1)!.endsWith('Light') && !m.group(1)!.endsWith('Dark'))
          m.group(1)!,
    };

/// Names of the static `TextStyle` members in [src] whose body bakes in one of
/// [colors].
///
/// The body is taken from the `=>`/`=` to the next `;`, which is safe because a
/// `TextStyle` literal contains no statement terminator. Running long would
/// pull in the NEXT getter's colour and over-report — the direction that fails
/// loudly rather than passing quietly.
Set<String> stylesBaking(String src, Set<String> colors) {
  if (colors.isEmpty) return {};
  final probe = RegExp(r'\b(?:' + colors.join('|') + r')\b');
  final out = <String>{};
  for (final m in _reStaticTextStyle.allMatches(src)) {
    final end = src.indexOf(';', m.end);
    if (end < 0) continue;
    if (probe.hasMatch(src.substring(m.end, end))) out.add(m.group(1)!);
  }
  return out;
}

List<File> _dartFiles(String root) => [
      for (final e in Directory(root).listSync(recursive: true))
        if (e is File && e.path.endsWith('.dart')) e,
    ];

/// `path:line` for every `Class.member` reference outside [declaredIn].
List<String> readersOf(String className, Set<String> members,
    {required String declaredIn, String root = 'lib'}) {
  if (members.isEmpty) return const [];
  // `\b` after the member so `NunitoTheme.surface` does not vouch for — or
  // flag — `NunitoTheme.surfaceDark`, which is a legitimate named half.
  final re =
      RegExp(r'\b' + className + r'\.(?:' + members.join('|') + r')\b');
  final hits = <String>[];
  for (final f in _dartFiles(root)) {
    final path = f.path.replaceAll(r'\', '/');
    if (path == declaredIn) continue;
    final lines = f.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      if (re.hasMatch(lines[i])) hits.add('  $path:${i + 1}  ${lines[i].trim()}');
    }
  }
  return hits;
}

const _nunito = 'lib/features/medication/theme/nunito_theme.dart';
const _aqua = 'lib/features/water/theme/aqua_theme.dart';

void main() {
  // ── the extractors, before anything is read off disk ──
  group('the extractors find what they claim to', () {
    const fixture = '''
class FakeTheme {
  static const Color textPrimary = AppPalette.textPrimaryL;
  static const surface = AppPalette.surfaceL;
  static const Color ink = AppPalette.textSecondaryD;
  static const Color cardLight = AppPalette.surfaceL;
  static const Color surfaceDark = AppPalette.surfaceD;
  static const Color waterTint = AppPalette.water;
  static const Color textPrimaryL = Color(0xFF1A1D21);

  static TextStyle get heading1 => const TextStyle(
    fontSize: 24,
    color: textPrimary,
  );
  static const TextStyle caption = TextStyle(fontSize: 11, color: ink);
  static TextStyle get neutral => const TextStyle(fontSize: 14);
}
''';

    test('single-theme constants — and only those', () {
      expect(singleThemeConsts(fixture), {'textPrimary', 'surface', 'ink'},
          reason: 'cardLight/surfaceDark name their theme; waterTint has no '
              'L/D half; textPrimaryL is the pair itself');
    });

    test('the styles that bake one in — and only those', () {
      final colors = singleThemeConsts(fixture);
      expect(stylesBaking(fixture, colors), {'heading1', 'caption'},
          reason: '`neutral` declares no colour, so it is theme-agnostic');
    });

    test('a theme with no single-theme constants poisons no styles', () {
      // The non-fix that would make everything below vacuous: an empty colour
      // set must not silently mean "every style is fine to call".
      expect(stylesBaking(fixture, {}), isEmpty);
      expect(readersOf('FakeTheme', {}, declaredIn: _nunito), isEmpty);
    });

    test('the usage scan respects the member boundary', () {
      final d = Directory.systemTemp.createTempSync('ds19');
      addTearDown(() => d.deleteSync(recursive: true));
      File('${d.path}/caller.dart').writeAsStringSync('''
final a = FakeTheme.surfaceDark;   // named half — fine
final b = FakeTheme.surfaceTinted; // not a member of the poisoned set
final c = FakeTheme.surface;       // the real thing
''');
      final hits = readersOf('FakeTheme', {'surface', 'textPrimary'},
          declaredIn: _nunito, root: d.path);
      expect(hits, hasLength(1));
      expect(hits.single, contains('FakeTheme.surface;'));
    });
  });

  // ── the tree itself ──
  test('NunitoTheme still declares the constants this guard exists for', () {
    // The anchor. If the four constants are ever deleted — the actual DS-19
    // fix — this fails, and the right response is to delete the NunitoTheme
    // half of this file with them rather than leave a scan that reads nothing.
    final src = File(_nunito).readAsStringSync();
    final colors = singleThemeConsts(src);
    expect(colors, isNotEmpty,
        reason: 'NunitoTheme is clean now — drop it from this guard');
    expect(stylesBaking(src, colors), isNotEmpty,
        reason: 'the TextStyles no longer bake a light-only colour');
  });

  test('nothing outside NunitoTheme reads a light-only member of it', () {
    final src = File(_nunito).readAsStringSync();
    final className = _reClass.firstMatch(src)!.group(1)!;
    final colors = singleThemeConsts(src);
    final poisoned = {...colors, ...stylesBaking(src, colors)};

    expect(readersOf(className, poisoned, declaredIn: _nunito), isEmpty,
        reason: 'These members hold the LIGHT value in both themes, so this '
            'draws near-black text on the dark background. Use '
            'AppColorsExt.of(context) for the colour and '
            'Theme.of(context).textTheme.<role> for the style.\n'
            'Poisoned members: ${(poisoned.toList()..sort()).join(', ')}');
  });

  test('AquaTheme has none left to read', () {
    // The half of DS-19 that is already done: AquaTheme's text constants were
    // deleted and its accessors resolve through AppColorsExt.of(context). This
    // pins that, so the Aqua language cannot grow them back the way Nunito
    // still has them.
    final src = File(_aqua).readAsStringSync();
    final colors = singleThemeConsts(src);
    expect(colors, isEmpty,
        reason: 'AquaTheme grew a single-theme constant back: '
            '${(colors.toList()..sort()).join(', ')}');
    expect(stylesBaking(src, colors), isEmpty);
  });
}
