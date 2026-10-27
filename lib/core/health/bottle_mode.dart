/// Drinking from one bottle: log "Finished" or "Half" of it, and see how many
/// bottles are left of the day's goal.
///
/// Pure Dart. The bottle is the person's own size, set once.
library;

class BottleMode {
  const BottleMode._();

  static const int minBottleMl = 200;
  static const int maxBottleMl = 2000;
  static const int stepMl = 50;

  /// What a new bottle starts at in the size sheet.
  static const int defaultBottleMl = 500;

  /// A size the sheet could have produced: in range and on a step.
  static bool isValid(int ml) =>
      ml >= minBottleMl && ml <= maxBottleMl && ml % stepMl == 0;

  /// Half of [bottleMl], rounded to 10 ml so "Half" of 750 is 380, not 375 —
  /// nobody can pour to the millilitre, and a tidy number reads better.
  static int halfMl(int bottleMl) => ((bottleMl / 2) / 10).round() * 10;

  /// "About 2 bottles to go": how much of the goal is left, in bottles, or null
  /// when there is none. A few sips, half a bottle, a bottle, a bottle and a
  /// half, and then whole bottles.
  static String? toGo({required int remainingMl, required int bottleMl}) {
    if (remainingMl <= 0 || bottleMl <= 0) return null;
    final bottles = remainingMl / bottleMl;
    if (bottles <= 0.25) return 'Just a few sips to go';
    if (bottles <= 0.75) return 'Half a bottle to go';
    if (bottles <= 1.25) return 'One bottle to go';
    if (bottles <= 1.75) return 'About a bottle and a half to go';
    return 'About ${bottles.round()} bottles to go';
  }
}
