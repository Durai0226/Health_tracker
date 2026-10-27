import 'dart:convert';

/// The reminder an `alarm:{json}` notification payload belongs to.
///
/// A reminder made in the Reminders feature carries its id in the payload, so a
/// button tapped on its notification — Done, Later — knows what it is about. A
/// water, medicine, vitals or focus alert has none, and so no such buttons.
///
/// Null for anything that is not an alarm payload, is not JSON (the legacy
/// `alarm:$id` form), or names no reminder. Pure Dart, because the background
/// isolate that handles the tap reads it too.
String? reminderIdFromAlarmPayload(String? payload) {
  const prefix = 'alarm:';
  if (payload == null || !payload.startsWith(prefix)) return null;
  try {
    final decoded = jsonDecode(payload.substring(prefix.length));
    if (decoded is! Map) return null;
    final id = decoded['reminderId'];
    return id is String && id.isNotEmpty ? id : null;
  } catch (_) {
    return null;
  }
}
