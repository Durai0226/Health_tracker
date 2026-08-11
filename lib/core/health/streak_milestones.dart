/// Adherence-streak milestone thresholds, in days, ascending.
const List<int> streakMilestoneDays = [7, 14, 30, 60, 100, 180, 365];

/// The highest milestone [streak] has reached, or null if it hasn't hit the
/// first one yet.
int? highestMilestoneReached(int streak) {
  int? best;
  for (final m in streakMilestoneDays) {
    if (streak >= m) best = m;
  }
  return best;
}

/// A short celebratory label for a milestone day count. Only called with a
/// value from [streakMilestoneDays], so every case is covered.
String milestoneLabel(int days) {
  switch (days) {
    case 7:
      return '1 week';
    case 14:
      return '2 weeks';
    case 30:
      return '1 month';
    case 60:
      return '2 months';
    case 100:
      return '100 days';
    case 180:
      return '6 months';
    case 365:
      return '1 year';
    default:
      return '$days days';
  }
}

/// Whether [streak] just crossed a NEW milestone that [lastCelebratedDays]
/// (the highest one already shown to the user, or null if none yet) hasn't
/// seen. Pure — callers persist [lastCelebratedDays] themselves.
bool isNewMilestone(int streak, int? lastCelebratedDays) {
  final current = highestMilestoneReached(streak);
  if (current == null) return false;
  return lastCelebratedDays == null || current > lastCelebratedDays;
}
