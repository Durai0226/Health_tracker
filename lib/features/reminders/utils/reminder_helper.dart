import '../models/reminder_model.dart';

class ReminderHelper {
  static DateTime getNextOccurrence(Reminder reminder) {
    // If not repeating, just return the same time (logic elsewhere handles this)
    if (reminder.repeatType == RepeatType.none) {
      return reminder.scheduledTime;
    }

    final current = reminder.scheduledTime;
    final now = DateTime.now();
    
    // If the scheduled time is in the past, we might want to calculate from NOW
    // or from the scheduled time to keep the exact cycle.
    // For smart reminders, usually we want the NEXT occurrence from NOW if it was overdue,
    // or from the scheduled time if we want to be strict.
    // Let's assume we want to maintain the specific time of day.
    
    // Base calculation date: usually current scheduled time.
    // However, if the user missed it by 3 days, should it move to yesterday (still overdue) or tomorrow?
    // Let's stick to "Next valid slot after current scheduled time".
    // If that slot is still in the past (e.g. daily reminder from 5 days ago), 
    // we should probably jump to the next future slot.
    
    DateTime nextDate = _calculateNext(current, reminder.repeatType, reminder.customDays);
    
    // If the calculcated next date is still in the past (e.g. user checks off a task from 1 week ago),
    // keep advancing until it's in the future.
    while (nextDate.isBefore(now)) {
      nextDate = _calculateNext(nextDate, reminder.repeatType, reminder.customDays);
    }
    
    return nextDate;
  }

  static DateTime _calculateNext(DateTime current, RepeatType type, List<int>? customDays) {
    switch (type) {
      case RepeatType.daily:
        return current.add(const Duration(days: 1));
        
      case RepeatType.weekly:
        return current.add(const Duration(days: 7));
        
      case RepeatType.weekdays:
        // Mon(1) .. Fri(5), Sat(6), Sun(7)
        // If Fri(5) -> Mon(plus 3)
        // If Sat(6) -> Mon(plus 2)
        // If Sun(7) -> Mon(plus 1)
        // Else -> Next day
        if (current.weekday >= 5) {
          // Fri -> Mon (+3)
          // Sat -> Mon (+2)
          // Sun -> Mon (+1)
          return current.add(Duration(days: 8 - current.weekday));
        }
        return current.add(const Duration(days: 1));
        
      case RepeatType.weekends:
        // Sat(6), Sun(7)
        if (current.weekday == DateTime.saturday) {
          return current.add(const Duration(days: 1)); // Sat -> Sun
        }
        if (current.weekday == DateTime.sunday) {
          return current.add(const Duration(days: 6)); // Sun -> Sat
        }
        // If weekday, find next Saturday
        final daysUntilSat = DateTime.saturday - current.weekday;
        final jump = daysUntilSat > 0 ? daysUntilSat : daysUntilSat + 7;
        return current.add(Duration(days: jump));
        
      case RepeatType.custom:
        if (customDays == null || customDays.isEmpty) {
          return current.add(const Duration(days: 1)); // Fallback
        }
        
        // Find next matching day
        // Current weekday: 1-7
        var tempDate = current;
        // Limit loop to avoid infinite loop
        for (int i = 0; i < 14; i++) {
          tempDate = tempDate.add(const Duration(days: 1));
          if (customDays.contains(tempDate.weekday)) {
            return tempDate;
          }
        }
        return current.add(const Duration(days: 1)); // Fallback
        
      default:
        return current;
    }
  }
}
