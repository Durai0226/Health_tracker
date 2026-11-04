import 'beverage_type.dart';

/// The rules for a drink the person makes up themselves — "my protein shake",
/// "oat milk latte", "the ginger tea from the corner shop".
///
/// `WaterService.addCustomBeverage` and the table behind it have been there for
/// a long time, and nothing could reach them: a drink the catalogue did not
/// list could not be logged as itself, so it went in as water (too much credit
/// for a shake) or as the nearest thing (the wrong caffeine). This is the part
/// of making one that is not a screen, so it can be tested without one.
///
/// Alcohol is deliberately not offered. An alcoholic drink's effect on hydration
/// is worked out from its strength (see [BeverageType.hydrationPercentForAbv]),
/// which the catalogue's own alcoholic entries are logged through; a flat
/// percentage typed in here would be a guess presented as a measurement.
class CustomDrink {
  CustomDrink._();

  /// Long enough for "Iced oat milk flat white"; short enough for a grid tile.
  static const int maxNameLength = 24;

  /// How much of the amount counts toward the goal. The catalogue counts every
  /// non-alcoholic drink in full — that is what the evidence says — so 100 is
  /// the default, and the lower steps exist for things that are part water, part
  /// something else (a smoothie, a broth).
  static const List<int> countsAsChoices = [100, 75, 50];

  /// Caffeine in mg per 100 ml, the unit [BeverageType.caffeinePerMl] already
  /// holds. Drip coffee is about 40; espresso about 210, so a ceiling above that
  /// leaves room without allowing a typo to log a lethal-looking number.
  static const int defaultCaffeineMg = 40;
  static const int maxCaffeineMg = 250;

  /// The prefix every custom id carries, so a custom drink can never share an id
  /// with a catalogue entry (the catalogue's ids are plain words: `tea`, `milk`).
  ///
  /// Not how a drink is told to be the person's own: that is membership of
  /// `WaterService.getCustomBeverages`, which also holds any made before ids
  /// carried a prefix. This is only what [newId] hands out, and what the drinks
  /// strip uses to pick a glyph.
  static const String idPrefix = 'custom_';

  /// What is wrong with [raw] as a drink's name, or null when it is fine.
  ///
  /// Two drinks with the same name in the picker are indistinguishable, so the
  /// check runs against every drink — the catalogue's included — case-blind. When
  /// editing, [editingId] is the drink being edited, which may keep its own name.
  static String? nameError(
    String raw,
    Iterable<BeverageType> existing, {
    String? editingId,
  }) {
    final name = normalise(raw);
    if (name.isEmpty) return 'Give the drink a name';
    if (name.runes.length > maxNameLength) {
      return 'Keep it to $maxNameLength characters or fewer';
    }
    final key = name.toLowerCase();
    final clash = existing.any(
        (b) => b.id != editingId && normalise(b.name).toLowerCase() == key);
    if (clash) return 'You already have a drink called "$name"';
    return null;
  }

  /// [raw] with the whitespace that does not show collapsed: leading, trailing
  /// and doubled spaces are all the same name to a person.
  static String normalise(String raw) =>
      raw.trim().replaceAll(RegExp(r'\s+'), ' ');

  /// An id for a new drink called [name] that is not in [taken].
  ///
  /// Readable on purpose (`custom_protein_shake`): it is what the log rows carry,
  /// and a person reading an export can tell what it was. A name with no letters
  /// or digits in it (all emoji, say) falls back to `drink`.
  static String newId(String name, Iterable<String> taken) {
    var slug = normalise(name)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (slug.isEmpty) slug = 'drink';
    final used = taken.toSet();
    var id = '$idPrefix$slug';
    for (var n = 2; used.contains(id); n++) {
      id = '$idPrefix${slug}_$n';
    }
    return id;
  }

  /// The drink the form describes. [caffeineMg] of 0 or less means none.
  ///
  /// Out-of-range values are clamped rather than rejected: the form offers fixed
  /// steps, so a value outside them can only be a stale one, and the nearest
  /// valid drink is a better answer than refusing to save.
  static BeverageType build({
    required String id,
    required String name,
    required String colorHex,
    int countsAsPercent = 100,
    int caffeineMg = 0,
  }) {
    final caffeine = caffeineMg.clamp(0, maxCaffeineMg);
    return BeverageType(
      id: id,
      name: normalise(name),
      emoji: '🥤',
      hydrationPercent: countsAsPercent.clamp(1, 100),
      colorHex: colorHex,
      hasCaffeine: caffeine > 0,
      caffeinePerMl: caffeine,
    );
  }

  /// [b] as the person's own drink would be if it had been made on the screen:
  /// the name tidied and cut to length, the percentage inside 1–100, the caffeine
  /// inside its range, the default amount sensible. Null when it cannot be one: no
  /// name left, no id, or an alcoholic drink — whose effect is worked out from its
  /// strength, not typed in, so it is not re-scored here as if it were water.
  ///
  /// For a drink that did not come from the screen — one read out of a backup file,
  /// which anyone may have edited. Without it a figure like `hydrationPercent: 5000`
  /// restores as it is and inflates every total the drink is logged against.
  ///
  /// Lengths are counted in code points, not UTF-16 units, so a name ending in an
  /// emoji is not cut through the middle of one.
  static BeverageType? sanitized(BeverageType b) {
    if (b.isAlcoholic || b.id.isEmpty) return null;
    final name = _cut(normalise(b.name), maxNameLength);
    if (name.isEmpty) return null;
    final caffeine = (b.hasCaffeine ? b.caffeinePerMl : 0).clamp(0, maxCaffeineMg);
    return b.copyWith(
      name: name,
      emoji: b.emoji.isEmpty ? '🥤' : _cut(b.emoji, 8),
      hydrationPercent: b.hydrationPercent.clamp(1, 100),
      hasCaffeine: caffeine > 0,
      caffeinePerMl: caffeine,
      isAlcoholic: false,
      defaultAmountMl: b.defaultAmountMl.clamp(10, 5000),
    );
  }

  /// [existing] with what the form says changed: the name, the colour, how much it
  /// counts and the caffeine. Everything else it has — the glyph, the default
  /// amount, anything an earlier version gave it — is kept, which building a new
  /// drink from the form's fields would silently reset.
  ///
  /// How much it counts is kept exactly when the form was not touched: a drink with
  /// a value the form's steps do not offer must not be rounded to one just by being
  /// opened and saved.
  static BeverageType edited(
    BeverageType existing, {
    required String name,
    required String colorHex,
    required int countsAsPercent,
    required int caffeineMg,
  }) {
    final caffeine = caffeineMg.clamp(0, maxCaffeineMg);
    return existing.copyWith(
      name: normalise(name),
      colorHex: colorHex,
      hydrationPercent: countsAsPercent == existing.hydrationPercent
          ? existing.hydrationPercent
          : countsAsPercent.clamp(1, 100),
      hasCaffeine: caffeine > 0,
      caffeinePerMl: caffeine,
    );
  }

  /// The first [max] code points of [s].
  static String _cut(String s, int max) {
    final runes = s.runes;
    if (runes.length <= max) return s;
    return String.fromCharCodes(runes.take(max)).trimRight();
  }

  /// One line for a list row: what the drink counts for and what it carries.
  static String summary(BeverageType b) {
    final counts = b.hydrationPercent >= 100
        ? 'Counts in full'
        : 'Counts ${b.hydrationPercent}%';
    return b.hasCaffeine
        ? '$counts · ${b.caffeinePerMl} mg caffeine per 100 ml'
        : '$counts · no caffeine';
  }
}
