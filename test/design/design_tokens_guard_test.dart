/// Design-system conformance, as a budget that may only shrink.
///
/// Every deviation below has a token — `Theme.of(context).textTheme.*`,
/// `AppColorsExt.of(context)`, `AppRadius`, `AppInsets`, `showAppToast`,
/// `AppIconButton` — and every one of them is still hand-rolled somewhere in
/// `lib/features/**/{screens,widgets}`. Deleting the offenders in one pass is
/// not possible (they are spread over ~115 files that several people are
/// editing), so this pins them instead: each rule carries a per-file count
/// taken on the day it was written, and the count may only go DOWN. A new
/// screen that hand-rolls type, colour or radius fails immediately; a file
/// being cleaned up passes all the way to zero.
///
/// Per FILE rather than per LINE on purpose — line numbers rot on the first
/// unrelated edit, and the number that matters is "how much of this file is
/// still off-system", not where.
///
/// ## Scope is per rule
///
/// Most rules read `lib/features/**/{screens,widgets}` — the surfaces a user
/// looks at. Four read wider, because their deviation does not live on a
/// screen: the product name turns up in services, the off-scale radii and the
/// hand-rolled shadows turn up in the shared widget kit, and the light-only
/// palette constants live in `lib/features/**/theme/`. A rule declares its own
/// `scope`.
///
/// ## The regexes are themselves tested
///
/// A previous guard in this repo matched `availableIcons.first` with a bare
/// `Icons\.` and had to be fixed after it had already been green for weeks. So
/// every rule here carries a positive and a negative fixture and they are
/// asserted before any file is read: a rule that stops matching what it claims
/// to match fails loudly rather than quietly passing everything.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ─────────────────────────── scanning helpers ───────────────────────────

/// Byte offsets at which each line starts, for offset → line-number lookup.
List<int> _lineStarts(String src) {
  final starts = <int>[0];
  for (var i = 0; i < src.length; i++) {
    if (src.codeUnitAt(i) == 0x0A) starts.add(i + 1);
  }
  return starts;
}

int _lineAt(List<int> starts, int offset) {
  var lo = 0, hi = starts.length - 1;
  while (lo < hi) {
    final mid = (lo + hi + 1) >> 1;
    if (starts[mid] <= offset) {
      lo = mid;
    } else {
      hi = mid - 1;
    }
  }
  return lo + 1; // 1-based
}

/// The argument list of a call whose `(` is at [open], paren-balanced.
///
/// Parentheses inside string literals are not tracked, so an unbalanced scan
/// simply runs to [limit]. That direction is the safe one: a tooltip/fontSize
/// probe over too MUCH text yields a false negative (an offender we miss), not
/// a false positive (a passing file we fail).
String _argsAt(String src, int open, {int limit = 4000}) =>
    src.substring(open + 1, _argEnd(src, open, limit: limit));

/// Offset of the `)` closing the call whose `(` is at [open] — or where the
/// scan gave up, same caveat as [_argsAt].
int _argEnd(String src, int open, {int limit = 4000}) {
  var depth = 0;
  final end = (open + limit).clamp(0, src.length);
  for (var i = open; i < end; i++) {
    final c = src.codeUnitAt(i);
    if (c == 0x28) {
      depth++;
    } else if (c == 0x29) {
      depth--;
      if (depth == 0) return i;
    }
  }
  return end;
}

/// Lines matching [re] whose paren-balanced argument list satisfies [argTest].
List<int> _callsWhere(String src, RegExp re, bool Function(String args) argTest,
    {int limit = 4000}) {
  final starts = _lineStarts(src);
  final hits = <int>[];
  for (final m in re.allMatches(src)) {
    final open = src.indexOf('(', m.start);
    if (open < 0) continue;
    if (argTest(_argsAt(src, open, limit: limit))) {
      hits.add(_lineAt(starts, m.start));
    }
  }
  return hits;
}

List<int> _linesMatching(String src, RegExp re) {
  final starts = _lineStarts(src);
  return [for (final m in re.allMatches(src)) _lineAt(starts, m.start)];
}

// ─────────────────────────────── the rules ───────────────────────────────

typedef _Finder = List<int> Function(String src);

class _Rule {
  final String id;

  /// What to do instead, quoted back in the failure message.
  final String remedy;
  final _Finder find;

  /// Source that MUST be flagged, and source that must NOT be. One entry per
  /// alternative the rule claims to catch, so a rule with two spellings cannot
  /// pass on the strength of one of them.
  final List<String> positives;
  final List<String> negatives;

  /// path → offenders counted on 2026-09-03. May only go down.
  final Map<String, int> budget;

  /// Which files this rule reads. Defaults to the feature surfaces; a rule
  /// whose deviation also lives in a theme file, a service or the shared
  /// widget kit widens it (see [_isFeatureUi]).
  final bool Function(String path) scope;

  const _Rule({
    required this.id,
    required this.remedy,
    required this.find,
    required this.positives,
    required this.negatives,
    required this.budget,
    this.scope = _isFeatureUi,
  });
}

// `\b` before every identifier that is a suffix of a legitimate one:
//   Colors.red   must not match AppColors.red
//   Color(       must not match AppColor(  /  Color.lerp(
//   SnackBar(    must not match showSnackBar(
//   IconButton(  must not match AppIconButton(
//   FloatingActionButton  must not match FloatingActionButtonLocation
final _reTextStyle = RegExp(r'\bTextStyle\(');
final _reMaterialColor = RegExp(
    r'\bColors\.(white|black|grey|red|amber|orange|brown|purple|green|blue|teal|indigo|pink|cyan)\b');
// Broader than the literal `Color(0xFF…`: any raw ARGB literal is the same
// deviation, and a translucent one (`0x1A…`) is not more acceptable.
final _reHexColor = RegExp(r'\bColor\(\s*0x[0-9a-fA-F]{6,8}\b');
// `BorderRadius.circular` as well as `Radius.circular` — same deviation, and
// the Border-prefixed spelling is by far the commoner one.
final _reRadius =
    RegExp(r'\b(?:Border)?Radius\.circular\(\s*([0-9]+(?:\.[0-9]+)?)\s*\)');
final _reMagicBottomPad = RegExp(r'\bSizedBox\(\s*height:\s*100(?:\.0)?\s*\)');
final _reRawMaterial =
    RegExp(r'\b(?:SnackBar|AlertDialog)\(|\bFloatingActionButton\b');
final _reIconButton = RegExp(r'\bIconButton\(');
final _reProductName = RegExp(r'\bDailyMinder\b');
final _reBoxShadow = RegExp(r'\bBoxShadow\(');
// The eyebrow: `labelSmall` widened by POSITIVE tracking. Both spellings the
// app uses (`tt.labelSmall?.copyWith(…)` and
// `Theme.of(context).textTheme.labelSmall?.copyWith(…)`) start the match at
// `labelSmall`, and the `\s*` between the parts covers the line break the
// longer one usually takes.
final _reLabelSmallCopyWith = RegExp(r'labelSmall\s*\??\s*\.\s*copyWith\(');
// Positive only. Negative tracking on `labelSmall` is the opposite gesture —
// tightening a numeral — and has nothing to do with an eyebrow.
final _reTracking = RegExp(r'letterSpacing:\s*(?:0\.[1-9]|[1-9])');
// A `static const` bound to ONE half of a light/dark palette pair. The suffix
// is the whole tell: `AppPalette.surfaceL` is the light value of a pair, so a
// constant called `surface` that holds it is light-mode-only under a name that
// promises otherwise. A constant that says which theme it is (`cardLight`,
// `surfaceDark`) is a legitimate half — the caller picks.
final _rePaletteConst = RegExp(
    r'static\s+const\s+(?:Color\s+)?(\w+)\s*=\s*AppPalette\.\w+[LD]\s*;');

// MED-UI-14: `_reIconButton` above can only see `IconButton`, so an icon-only
// control built out of a `GestureDetector` — which takes no `tooltip:` — was
// invisible to it, and the medication feature sat at an allowance of 0 over a
// rule that could not see its two offenders. These spell the same check for
// the hand-rolled spellings.
final _reTapWrapper = RegExp(r'\b(?:GestureDetector|InkWell)\(');
final _reIconChild = RegExp(r'\bIcon\(|\bSymbols\.|\bIcons\.');
// Text inside the target IS its accessible name — a labelled chip, tile or row
// is not what this rule is after. `label:` counts as text: a child handed one
// (an `AppTextField` behind an `InkWell`, say) draws and announces it.
final _reTextChild = RegExp(r'\b(?:Text|RichText|SelectableText)\(|\blabel:');
// Deliberately NOT `Semantics(`: a bare `Semantics(button: true, child: …)`
// names nothing, and accepting the token would let the offender back in under
// the remedy's own spelling. An inline `Semantics(label: …)` is already
// exempt — `_reTextChild` counts `label:`.
final _reInlineLabel =
    RegExp(r'\bsemanticLabel:|\bsemanticsLabel:|\btooltip:');

/// Wrappers that supply the name from OUTSIDE the tap target's own arguments.
final _reLabelWrapper = RegExp(r'\b(?:Semantics|Tooltip)\(');

/// The argument that actually carries a name: `label:` on `Semantics`,
/// `message:`/`richMessage:` on `Tooltip`.
final _reWrapperName = RegExp(r'\blabel:|\bmessage:|\brichMessage:');

/// Argument spans of the `Semantics(`/`Tooltip(` calls that NAME something.
///
/// A wrapper with no name argument is not a span: wrapping an icon-only target
/// in `Semantics(button: true)` and nothing else leaves it announcing as
/// before, and a guard that accepted it would go green on the non-fix.
///
/// The name is looked for anywhere in the wrapper's arguments rather than only
/// before its `child:`, because Dart takes named arguments in any order. That
/// is the false-negative direction — a sibling's `label:` deep inside the same
/// wrapper would vouch for a target that has none — and matches the caveat on
/// [_argsAt].
List<(int, int)> _labelWrapperSpans(String src) {
  final spans = <(int, int)>[];
  for (final m in _reLabelWrapper.allMatches(src)) {
    final open = src.indexOf('(', m.start);
    if (open < 0) continue;
    final end = _argEnd(src, open, limit: _tapTargetScan);
    if (!_reWrapperName.hasMatch(src.substring(open + 1, end))) continue;
    spans.add((open, end));
  }
  return spans;
}

/// Subtrees here are whole tiles, so the paren scan needs more room than the
/// 4000 a `tooltip:` probe does; running short would report an offender that
/// labels itself further down (the false-positive direction), not miss one.
const _tapTargetScan = 12000;

/// `GestureDetector`/`InkWell` that draws an icon, no text, and carries no
/// accessible name — inline or from an enclosing `Semantics`/`Tooltip`.
List<int> _iconOnlyTapTargets(String src) {
  final starts = _lineStarts(src);
  final wrapped = _labelWrapperSpans(src);
  final hits = <int>[];
  for (final m in _reTapWrapper.allMatches(src)) {
    final open = src.indexOf('(', m.start);
    if (open < 0) continue;
    final args = _argsAt(src, open, limit: _tapTargetScan);
    if (!args.contains('onTap:') && !args.contains('onLongPress:')) continue;
    if (!_reIconChild.hasMatch(args)) continue;
    if (_reTextChild.hasMatch(args)) continue;
    if (_reInlineLabel.hasMatch(args)) continue;
    if (wrapped.any((s) => m.start > s.$1 && m.start < s.$2)) continue;
    hits.add(_lineAt(starts, m.start));
  }
  return hits;
}

/// The radii `AppRadius` actually defines.
// Not `Set<double>` const: doubles have no primitive equality, so a const set
// of them does not compile.
final _radiusScale = <double>{8, 12, 16, 20, 24, 999};

final _rules = <_Rule>[
  _Rule(
    id: 'raw TextStyle with fontSize/fontWeight',
    remedy: "Theme.of(context).textTheme.<role> — add .copyWith(color:) if you "
        'need a colour. The scale is in lib/core/design/app_typography.dart and '
        '11pt is its floor.',
    find: (src) => _callsWhere(src, _reTextStyle,
        (a) => a.contains('fontSize:') || a.contains('fontWeight:')),
    positives: [
      'style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),',
      'style: TextStyle(fontWeight: FontWeight.bold, color: c),',
    ],
    negatives: [
      'style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w500),',
      'final TextStyle? valueStyle;',
      'style: const TextStyle(color: Colors.transparent),',
    ],
    budget: _textStyleBudget,
  ),
  _Rule(
    id: 'Colors.* / raw Color(0x…)',
    remedy: 'AppColorsExt.of(context) — ext.textPrimary, ext.surface, '
        'ext.mark(swatch), or the AA-verified ext.fillBg/fillFg pair.',
    find: (src) => [
      ..._linesMatching(src, _reMaterialColor),
      ..._linesMatching(src, _reHexColor),
    ],
    positives: [
      'color: Colors.grey.shade300,',
      'color: Colors.red.withOpacity(0.1),',
      'color: const Color(0xFF1E1E1E),',
      'color: const Color(0x1AFFFFFF),',
    ],
    negatives: [
      'color: AppColors.white,', // the deleted class — proves the \b
      'color: Colors.transparent,', // deliberate, and not in the list
      'color: Color.lerp(a, b, t),',
      'color: ext.mark(ext.water),',
    ],
    budget: _colorBudget,
  ),
  _Rule(
    id: 'off-scale Radius.circular',
    remedy: 'AppRadius.brSm/brMd/brLg/brCard/brSheet (8/12/16/20/24).',
    find: (src) {
      final starts = _lineStarts(src);
      final hits = <int>[];
      for (final m in _reRadius.allMatches(src)) {
        final n = double.parse(m.group(1)!);
        if (!_radiusScale.contains(n)) hits.add(_lineAt(starts, m.start));
      }
      return hits;
    },
    positives: [
      'borderRadius: BorderRadius.circular(30),',
      'topLeft: Radius.circular(2),',
    ],
    negatives: [
      'borderRadius: BorderRadius.circular(12),',
      'borderRadius: AppRadius.brCard,',
      'const Radius.elliptical(4, 8)',
    ],
    budget: _radiusBudget,
    // Also the shared widget kit: AppRadius is defined there, and the toast —
    // which every feature shows — was drawing 14 and 10 against a scale that
    // has neither.
    scope: (p) => _isFeatureUi(p) || p.startsWith('lib/core/widgets/'),
  ),
  _Rule(
    id: 'magic SizedBox(height: 100) bottom padding',
    remedy: 'AppInsets.underNav(context) on a tab root, AppInsets.pushed(context) '
        'on a pushed screen — both add the gesture-bar inset, which 100 does not.',
    find: (src) => _linesMatching(src, _reMagicBottomPad),
    positives: ['const SizedBox(height: 100),'],
    negatives: [
      'SizedBox(height: AppInsets.underNav(context)),',
      'const SizedBox(height: 100, width: 40),',
      'const SizedBox(height: 10),',
    ],
    budget: _magicPadBudget,
  ),
  _Rule(
    id: 'raw SnackBar / AlertDialog / FloatingActionButton',
    remedy: 'showAppToast / context.toastSuccess for a message, '
        'AppBottomSheet.confirm or ConfirmationBottomSheet for a decision, '
        'AppFab for the button.',
    find: (src) => _linesMatching(src, _reRawMaterial),
    positives: [
      "ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('x')));",
      "showDialog(context: context, builder: (_) => AlertDialog(title: t));",
      'floatingActionButton: FloatingActionButton(onPressed: _add),',
    ],
    negatives: [
      "ScaffoldMessenger.of(context).hideCurrentSnackBar();",
      "context.toastSuccess('Saved');",
      'floatingActionButton: AppFab(icon: Symbols.add, onPressed: _add),',
      'floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,',
    ],
    budget: _rawMaterialBudget,
  ),
  _Rule(
    id: 'IconButton without tooltip',
    remedy: 'AppIconButton(tooltip: …) — an icon-only control with no tooltip '
        'announces as a bare "button" to a screen reader.',
    find: (src) =>
        _callsWhere(src, _reIconButton, (a) => !a.contains('tooltip:')),
    positives: ['IconButton(icon: const Icon(Symbols.add), onPressed: _add),'],
    negatives: [
      "AppIconButton(icon: Symbols.add, tooltip: 'Add', onPressed: _add),",
      "IconButton(icon: const Icon(Symbols.add), tooltip: 'Add', onPressed: _add),",
    ],
    budget: _iconButtonBudget,
  ),
  // const, unlike its neighbours: its finder is a named function rather than a
  // closure, because the scan it does needs more than one expression.
  const _Rule(
    id: 'icon-only GestureDetector/InkWell without a label',
    remedy: 'Semantics(button: true, label: …) around it — or AppIconButton, '
        'which carries the tooltip for you. An icon is not a name: with no '
        'text in the subtree the control announces as nothing at all.',
    find: _iconOnlyTapTargets,
    positives: [
      'GestureDetector(onTap: _add, child: const Icon(Symbols.add)),',
      'InkWell(onTap: _close, child: Container(child: Icon(Symbols.close))),',
      // Symbols, not Icons: the app draws Material Symbols, and a fixture
      // spelling `Icons.` trips the e2e conventions guard that exists to
      // stop finders which can never match.
      'GestureDetector(onLongPress: _peek, child: Icon(Symbols.star)),',
      // The non-fix: the wrapper is there, the name is not.
      'Semantics(button: true, child: GestureDetector(onTap: _add, '
          'child: const Icon(Symbols.add))),',
      'GestureDetector(onTap: _add, child: Semantics(child: '
          'const Icon(Symbols.add))),',
    ],
    negatives: [
      "Semantics(button: true, label: 'Add', child: GestureDetector("
          'onTap: _add, child: const Icon(Symbols.add))),',
      "GestureDetector(onTap: _add, child: Row(children: const ["
          "Icon(Symbols.add), Text('Add')])),",
      "GestureDetector(onTap: _add, child: Icon(Symbols.add, "
          "semanticLabel: 'Add')),",
      "Tooltip(message: 'Add', child: InkWell(onTap: _add, "
          'child: const Icon(Symbols.add))),',
      // No icon in the subtree: labelled by whatever the caller passes in.
      'GestureDetector(onTap: onTap, child: AnimatedContainer(child: child)),',
      // A field behind a tap target — the icon is decoration on a named input.
      "InkWell(onTap: _pickDate, child: IgnorePointer(child: AppTextField("
          "label: 'Date of birth', prefixIcon: Symbols.calendar_today))),",
      // Not a tap target at all.
      'GestureDetector(child: const Icon(Symbols.add)),',
    ],
    budget: _iconOnlyTapBudget,
  ),
  _Rule(
    id: 'hand-rolled neutral card shadow',
    remedy: 'AppShadows.card(context) for a card, .resting for a row, '
        '.elevated for a sheet/FAB — all three already switch on brightness, '
        'which a hand-typed black never does consistently.',
    // Keyed on `Colors.black`, which is what separates a card shadow from the
    // coloured glows this app also draws (an accent halo under the alarm ring,
    // a pill tint, a plant bloom). Those are deliberate and AppShadows has no
    // recipe for them; a neutral drop shadow is exactly what it has three of.
    // The paren scan is capped short because a BoxShadow argument list is one
    // line or two — running long here would let the NEXT shadow's `Colors.black`
    // vouch for a coloured one, the false-positive direction.
    find: (src) => _callsWhere(src, _reBoxShadow,
        (a) => a.contains('Colors.black'),
        limit: 400),
    positives: [
      'BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, '
          'offset: Offset(0, 6)),',
      'BoxShadow(color: Colors.black26, blurRadius: 8),',
    ],
    negatives: [
      'boxShadow: AppShadows.card(context),',
      'BoxShadow(color: accent.base.withOpacity(0.3), blurRadius: 12),',
      'BoxShadow(color: ext.brand.base.withOpacity(0.35), blurRadius: 18, '
          'offset: const Offset(0, 8)),',
    ],
    budget: _cardShadowBudget,
    // Also the shared widget kit and the design layer, for the same reason the
    // radius rule reads them: `AppShadows` is defined there, every card in the
    // app draws through `AppCard`, and a hand-typed black that lands in core
    // ships to every screen at once — the blind spot that matters most, and the
    // one the feature-UI scope could not see. `app_shadows.dart` is exempt
    // because it is the file the three recipes are declared in.
    scope: (p) =>
        _isFeatureUi(p) ||
        ((p.startsWith('lib/core/widgets/') ||
                p.startsWith('lib/core/design/')) &&
            p != _shadowTokenFile),
  ),
  _Rule(
    id: 'hand-rolled uppercase eyebrow',
    remedy: "AppEyebrow('Personal best') — it uppercases for you, sits on the "
        '11pt floor at 0.6 tracking, and defaults to textSecondary. The copies '
        'default to textTertiary, which at 11pt measures 3.50–4.16:1 depending '
        'on theme and surface, under the 4.5:1 AA asks of normal text.',
    // The shape, not the string: `labelSmall` + positive tracking. Keying on
    // `.toUpperCase()` instead would have missed the sites that pass a literal
    // 'LAST 7 DAYS' — half of them — and flagged every unrelated
    // capitalisation in the app.
    find: (src) =>
        _callsWhere(src, _reLabelSmallCopyWith, _reTracking.hasMatch,
            limit: 400),
    positives: [
      'style: tt.labelSmall?.copyWith(color: ext.textTertiary, '
          'letterSpacing: 0.6),',
      // The multi-line spelling, which is the commoner one.
      'style: tt.labelSmall\n'
          '    ?.copyWith(color: ext.textSecondary, letterSpacing: 0.5),',
      'style: Theme.of(context).textTheme.labelSmall?.copyWith(\n'
          '  color: ext.textTertiary,\n  letterSpacing: 0.5,\n),',
    ],
    negatives: [
      "const AppEyebrow('Personal best'),",
      // A small label with no tracking is just a small label.
      'style: tt.labelSmall?.copyWith(color: ext.textTertiary),',
      // Tight numerals — the opposite gesture.
      'style: tt.labelSmall?.copyWith(fontFeatures: kTabular, '
          'letterSpacing: -0.3),',
      // A different rank: section titles are labelLarge and stay hand-set.
      'style: tt.labelLarge?.copyWith(letterSpacing: 0.4),',
    ],
    budget: _eyebrowBudget,
    // Also the shared kit, so a new core widget cannot hand-roll one — minus
    // the file AppEyebrow is declared in, whose two hits are the widget's own
    // `labelSmall?.copyWith(letterSpacing: 0.6)` and the doc comment quoting
    // the deviation it replaces.
    scope: (p) =>
        (_isFeatureUi(p) || p.startsWith('lib/core/widgets/')) &&
        p != _eyebrowWidgetFile,
  ),
  _Rule(
    id: 'light-only palette constant under a theme-neutral name',
    remedy: 'AppColorsExt.of(context).<token> — it resolves per theme. If the '
        'value genuinely must be a const, name it for the theme it is '
        '(`cardLight`/`surfaceDark`) so no caller can mistake it for a token.',
    find: (src) {
      final starts = _lineStarts(src);
      final hits = <int>[];
      for (final m in _rePaletteConst.allMatches(src)) {
        final name = m.group(1)!;
        if (name.endsWith('Light') || name.endsWith('Dark')) continue;
        hits.add(_lineAt(starts, m.start));
      }
      return hits;
    },
    positives: [
      'static const Color textPrimary = AppPalette.textPrimaryL;',
      'static const surface = AppPalette.surfaceL;',
      'static const Color ink = AppPalette.textSecondaryD;',
    ],
    negatives: [
      'static const Color backgroundLight = AppPalette.backgroundL;',
      'static const Color cardDark = AppPalette.surfaceD;',
      // Theme-neutral palette entries (no L/D half) are not this defect.
      'static const Color waterPrimary = AppPalette.water;',
      'static const Color medicineAccent = AppPalette.medicineDark;',
      // The pair itself, where the L/D names are declared.
      'static const textPrimaryL = Color(0xFF1A1D21);',
    ],
    budget: _paletteConstBudget,
    // Theme classes live in `lib/features/**/theme/`, which the feature-UI
    // scope does not reach — and that is precisely where the surviving copy of
    // the deleted `AppColors` sits.
    scope: _allOfLib,
  ),
  _Rule(
    id: "'DailyMinder' — the product ships as Dlyminder",
    remedy: 'AppStrings.productName (lib/core/constants/app_strings.dart). '
        'CFBundleDisplayName and android:label both say Dlyminder; DailyMinder '
        'is a name the stores never saw.',
    find: (src) => _linesMatching(src, _reProductName),
    positives: ["title: 'DailyMinder',"],
    negatives: [
      "title: AppStrings.productName,",
      "text: 'Dlyminder Backup',",
    ],
    budget: _productNameBudget,
    scope: (p) => _allOfLib(p) && p != _productNameExempt,
  ),
];

/// The one file the product-name rule exempts: it defines the replacement, and
/// a doc comment explaining a rename has to be allowed to spell the name being
/// retired.
const _productNameExempt = 'lib/core/constants/app_strings.dart';

/// Likewise for the shadow rule: this is where `AppShadows.resting/card/
/// elevated` are declared, so it is the one file whose `Colors.black` is the
/// remedy rather than the deviation.
const _shadowTokenFile = 'lib/core/design/app_shadows.dart';

/// And for the eyebrow rule: `AppEyebrow` lives here, so its own
/// `labelSmall?.copyWith(letterSpacing: 0.6)` IS the token.
const _eyebrowWidgetFile = 'lib/core/widgets/app/primitives.dart';

// ───────────────────────────── scope + running ─────────────────────────────

/// The default scope: `lib/features/**/{screens,widgets}`, the surfaces a user
/// looks at.
bool _isFeatureUi(String path) =>
    path.startsWith('lib/features/') &&
    path.endsWith('.dart') &&
    (path.contains('/screens/') || path.contains('/widgets/'));

/// Every Dart file under `lib` — for deviations that hide in themes, models and
/// services rather than on a screen.
bool _allOfLib(String path) => path.endsWith('.dart');

List<File> _dartFiles(String root) => [
      for (final e in Directory(root).listSync(recursive: true))
        if (e is File && e.path.endsWith('.dart')) e,
    ];

/// path → offender count, for the files [inScope] accepts.
Map<String, int> _scan(_Rule rule) {
  final out = <String, int>{};
  for (final f in _dartFiles('lib')) {
    final path = f.path.replaceAll(r'\', '/');
    if (!rule.scope(path)) continue;
    final n = rule.find(f.readAsStringSync()).length;
    if (n > 0) out[path] = n;
  }
  return out;
}

void main() {
  group('the regexes match what they claim', () {
    for (final rule in _rules) {
      test(rule.id, () {
        for (final p in rule.positives) {
          expect(rule.find(p), isNotEmpty,
              reason: '${rule.id}: positive fixture was not flagged — the rule '
                  'has stopped catching the thing it exists for.\n$p');
        }
        for (final n in rule.negatives) {
          expect(rule.find(n), isEmpty,
              reason: '${rule.id}: negative fixture was flagged. A rule that '
                  'matches legitimate code gets suppressed, and then it guards '
                  'nothing.\n$n');
        }
      });
    }
  });

  group('deviation budget (may only shrink)', () {
    for (final rule in _rules) {
      test(rule.id, () {
        final found = _scan(rule);
        final over = <String>[];
        found.forEach((path, n) {
          final allowed = rule.budget[path] ?? 0;
          if (n > allowed) over.add('  $path: $n (budget $allowed)');
        });
        expect(over, isEmpty,
            reason: 'New off-system code in this rule\'s scope.\n'
                'Use ${rule.remedy}\n${over.join('\n')}');
      });
    }
  });

  /// Without this the budgets rot: a file gets cleaned up, its entry stays, and
  /// the next person to hand-roll something in that file inherits an allowance
  /// nobody granted them.
  test('no budget entry outlives its deviations', () {
    final stale = <String>[];
    for (final rule in _rules) {
      final found = _scan(rule);
      for (final path in rule.budget.keys) {
        if ((found[path] ?? 0) == 0) {
          stale.add('  [${rule.id}] $path');
        }
      }
    }
    expect(stale, isEmpty,
        reason: 'These files are clean now — delete their budget entries so the '
            'allowance goes with them:\n${stale.join('\n')}');
  });
}

// ───────────────────────── budgets, taken 2026-09-03 ─────────────────────────
// Regenerate after a cleanup pass by deleting the entries you emptied; do not
// raise a number.

// 265 raw type declarations. The water and focus features are where the two
// pre-token design languages ('Aqua', 'Nunito') survive.
const _textStyleBudget = <String, int>{
  'lib/features/focus/screens/app_allow_list_screen.dart': 12,
  'lib/features/focus/screens/custom_tags_screen.dart': 26,
  'lib/features/focus/screens/detailed_stats_screen.dart': 4,
  'lib/features/focus/screens/focus_garden_screen.dart': 7,
  'lib/features/focus/screens/focus_screen.dart': 7,
  'lib/features/focus/screens/plant_real_trees_screen.dart': 29,
  'lib/features/focus/screens/relaxation_screen.dart': 29,
  'lib/features/focus/widgets/ambient_sound_widget.dart': 7,
  'lib/features/focus/widgets/plant_animation_widget.dart': 7,
  'lib/features/medication/widgets/nunito_pill_visual.dart': 1,
  'lib/features/reminders/screens/alarm_screen.dart': 5,
  'lib/features/sleep/screens/sleep_dashboard_screen.dart': 1,
  'lib/features/water/screens/aqua_water_dashboard.dart': 1,
};

// 227 hardcoded colours. `alarm_screen` (31) is a full-screen alarm that
// paints its own palette; the rest is Aqua/Nunito again.
//
// `period_calendar_heatmap` came off this list (PV-15): its two were the two
// arms of `isDark ? Colors.white : Colors.white`, a ternary on the theme that
// returned the same value either way, under a bleeding fill that ran from
// 2.43:1 in light to 3.14:1 in dark. Both arms are now AA-verified swatch
// pairs.
const _colorBudget = <String, int>{
  'lib/features/focus/screens/app_allow_list_screen.dart': 3,
  'lib/features/focus/screens/custom_tags_screen.dart': 9,
  'lib/features/focus/screens/settings/focus_reminders_settings_screen.dart': 2,
  'lib/features/medication/widgets/nunito_pill_visual.dart': 3,
  'lib/features/onboarding/screens/welcome_screen.dart': 1,
  'lib/features/reminders/screens/alarm_screen.dart': 31,
  'lib/features/settings/screens/early_access_screen.dart': 1,
};

// 52 off-scale radii — mostly 4, 6, 10, 14, 30 on chart bars and pills.
//
// The two `lib/core/widgets/toast` entries are painter geometry rather than
// chrome: a `Radius.circular(2)` on a 3pt progress bar and on a confetti fleck
// is half the shape's own height, and any value off AppRadius' scale would be
// larger than the thing it rounds. The toast's own icon tile and action button
// were the real off-scale pair (14 and 10) and are on the scale now.
const _radiusBudget = <String, int>{
  'lib/core/widgets/toast/toast_animations.dart': 2,
  'lib/core/widgets/toast/toast_particles.dart': 1,
  'lib/features/insights/widgets/trend_chart_card.dart': 4,
  'lib/features/medication/screens/analytics/nunito_adherence_report_screen.dart': 2,
  'lib/features/medication/widgets/nunito_pill_visual.dart': 1,
  'lib/features/onboarding/screens/welcome_screen.dart': 1,
  'lib/features/period/widgets/prediction_card.dart': 1,
  'lib/features/reminders/screens/alarm_screen.dart': 4,
  'lib/features/sleep/widgets/sleep_weekly_trend.dart': 1,
  'lib/features/steps/widgets/step_hourly_chart.dart': 1,
};

// The eight `SizedBox(height: 100)` bottom spacers AppInsets was written for.
const _magicPadBudget = <String, int>{
  'lib/features/focus/screens/app_allow_list_screen.dart': 1,
  'lib/features/focus/screens/custom_tags_screen.dart': 1,
  'lib/features/focus/screens/relaxation_screen.dart': 1,
};

// 62 raw SnackBar/AlertDialog/FloatingActionButton uses, i.e. every screen
// that predates showAppToast and AppFab.
const _rawMaterialBudget = <String, int>{
  'lib/features/focus/screens/app_allow_list_screen.dart': 3,
  'lib/features/focus/screens/custom_tags_screen.dart': 2,
  'lib/features/focus/screens/focus_screen.dart': 3,
  'lib/features/focus/screens/relaxation_screen.dart': 1,
  'lib/features/medication/screens/nunito_medication_dashboard.dart': 1,
  'lib/features/steps/widgets/step_manual_entry_sheet.dart': 1,
};

// 21 icon-only controls that announce as a bare "button". Six of them are
// the three copied −/+ steppers AppStepper now replaces.
const _iconButtonBudget = <String, int>{
  'lib/features/period/screens/period_calendar_screen.dart': 2,
};

// The icon-only tap targets the IconButton rule never could see, found the day
// this rule was added (2026-09-14): a colour swatch, a 1-5 star row, a
// mood-face row and an icon picker. They belong to other features, so they are
// recorded rather than fixed — the two medication ones this rule was written
// for are gone, which is why neither is listed, and so is the fifth, the Add
// Reminder form's remove-photo ✕ (R16). The sleep sheet's 1-5 star row is gone
// too (SS-15): every star now carries `Semantics(label: 'Rate n of 5')` and a
// 44pt box, pinned by test/features/sleep/sleep_controls_a11y_test.dart.
const _iconOnlyTapBudget = <String, int>{
  'lib/features/period/widgets/log_today_sheet.dart': 1,
  'lib/features/reminders/screens/category_management_screen.dart': 1,
  'lib/features/water/screens/custom_cup_creator_screen.dart': 1,
};

// DS-20. One survivor in lib/features, and it is the AppShadows.card recipe
// hand-typed: same `Colors.black` at 0.30 dark / 0.06 light, blurRadius 20
// against the token's 16, no negative spread, offset (0, 8) against (0, 6).
// The other raw BoxShadows in lib/features are coloured glows, which no token
// covers.
//
// The five in lib/core/widgets came into view when this rule's scope widened
// to the shared kit. None of them is a card — every actual card, row, sheet
// and toast surface in core already draws AppShadows (`app_card`,
// `app_toast`, `auth_gate_sheet`, `segmented_toggle`, and `app_button`'s
// secondary fill) — so all five are recorded rather than converted:
//
//   app_button (2)     the emphasized button's float: a same-hue teal glow
//                      plus a 4px black contact in light, one black ambient in
//                      dark. A glow is not in AppShadows' vocabulary, and the
//                      dark arm sits at 0.5 because a button should read above
//                      a card, not level with it.
//   app_nav_bar (2)    the docked bar's UPWARD shadow, offset (0, -4) — no
//                      token has a negative Y — and the raised action
//                      DESTINATION, the rounded square that deliberately
//                      avoids the selection orb's language (the orb itself
//                      carries an accent glow, so the rule never sees it).
//   premium_toast (1)  the black half of a coloured-glow pair on the glass
//                      toast; the neutral toast surface is app_toast's, and
//                      that one is already AppShadows.elevated.
//
// Any SIXTH one fails, which is the point of widening the scope: a hand-typed
// black that lands in core ships to every screen at once.
const _cardShadowBudget = <String, int>{
  'lib/core/widgets/app/app_button.dart': 2,
  'lib/core/widgets/app/app_nav_bar.dart': 2,
  'lib/core/widgets/toast/premium_toast.dart': 1,
  'lib/features/onboarding/screens/welcome_screen.dart': 1,
};

// DS-11. The ten eyebrows still composed by hand across nine files, after the
// three in the shared kit adopted `AppEyebrow` (`PersonalBestCard`, `KpiCell`,
// `InsightCard`).
//
// Six of the ten draw `ext.textTertiary` outright — the sub-AA colour the
// widget's default exists to replace — and those are the plain migrations:
// home_dashboard's 'OF 4', trends_dashboard_screen, prediction_card,
// sleep_dashboard_screen, sleep_consistency_card, steps_dashboard_screen.
// The other four each need a `color:` decision rather than the default, which
// is why they are not one sweep:
//   weekly_recap_screen              on an accent fill — wants
//                                    `color: on.withOpacity(0.7)`.
//   home_dashboard                   'OVERDUE · …' / 'UP NEXT · …' in
//                                    `ext.mark(accent)` + w800 + tabular: a
//                                    status line wearing the eyebrow's shape.
//   nunito_medication_detail_screen  already `ext.textSecondary`, i.e. already
//                                    the default colour — tracking only.
//   sleep_score_ring                 `hasData ? band : ext.textTertiary`, so
//                                    the accent arm would need passing through.
//
// They belong to six other features, so they are recorded rather than fixed.
/// Empty: all six hand-rolled eyebrows now use [AppEyebrow]. Migrating them
/// also lifted their contrast — the widget defaults to `textSecondary`
/// (5.98:1 on a light card) where the copies used `textTertiary` (3.78:1),
/// under the 4.5:1 AA floor for 11pt.
const _eyebrowBudget = <String, int>{
  // The one deliberate exception, not a leftover copy.
  //
  // home_dashboard's "UP NEXT · 14:30" is a bolder, accent-coloured label with
  // `fontWeight: w800` and `fontFeatures: kTabular` so the time's digits do not
  // jitter as the minute ticks. AppEyebrow expresses neither, and widening it to
  // carry a weight and a font feature would make it a general Text wrapper —
  // which is how a shared widget stops meaning anything. It already clears AA
  // (`ext.mark(accent)`), so the contrast argument for migrating does not apply.
  'lib/features/home/screens/home_dashboard.dart': 1,
};

// DS-19. The Aqua half of this is gone — `AquaTheme` resolves its text through
// `AppColorsExt.of(context)` now. `NunitoTheme` still declares four: three text
// colours plus `surface`, all bound to the light value, and it bakes them into
// eleven static TextStyles, so anything that adopts one draws near-black text
// in dark mode. Nothing outside the file reads them today (only `pillColors`
// is used externally), which is what keeps this a latent defect rather than a
// visible one — and what makes a guard the right response.
const _paletteConstBudget = <String, int>{
  'lib/features/medication/theme/nunito_theme.dart': 4,
};

/// Empty: every user-visible 'DailyMinder' now interpolates
/// [AppStrings.productName]. The one literal left in lib/ is inside
/// app_strings.dart's own doc comment, which QUOTES the defect to record what
/// was fixed — and that FILE is exempted by this rule's `scope`. (The previous
/// note here said "the rule skips comments"; it does not. No rule in this file
/// strips comments, which is why the exemption is by path.)
const _productNameBudget = <String, int>{
};
