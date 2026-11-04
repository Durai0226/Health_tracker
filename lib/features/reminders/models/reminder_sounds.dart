/// The alarm sounds that ship inside the app, by the key a reminder stores.
///
/// A key is what travels in an alarm's payload: the full-screen alarm loops
/// `assets/sounds/<key>.wav`, which is why a bundled sound is only heard when
/// that screen opens (the notification itself plays the channel's own sound).
///
/// Shared by the Reminders editor and a medicine's reminder, so a sound added
/// here is offered in both.
abstract final class ReminderSounds {
  /// Key -> label, category, icon name and asset. Order is display order.
  static const Map<String, Map<String, String>> options = {
    'default': {'label': 'Default', 'category': 'Classic', 'icon': 'notifications', 'asset': 'assets/sounds/chime.wav'},
    'gentle_chime': {'label': 'Gentle Chime', 'category': 'Gentle', 'icon': 'music_note', 'asset': 'assets/sounds/gentle_chime.wav'},
    'soft_bells': {'label': 'Soft Bells', 'category': 'Gentle', 'icon': 'notifications_active', 'asset': 'assets/sounds/soft_bells.wav'},
    'marimba': {'label': 'Marimba', 'category': 'Melodic', 'icon': 'music_note', 'asset': 'assets/sounds/marimba.wav'},
    'sunrise': {'label': 'Sunrise', 'category': 'Melodic', 'icon': 'wb_sunny', 'asset': 'assets/sounds/sunrise.wav'},
    'pulse': {'label': 'Pulse', 'category': 'Classic', 'icon': 'graphic_eq', 'asset': 'assets/sounds/pulse.wav'},
    'calm': {'label': 'Calm', 'category': 'Gentle', 'icon': 'self_improvement', 'asset': 'assets/sounds/calm.wav'},
    'digital_alarm': {'label': 'Digital Alarm', 'category': 'Alert', 'icon': 'alarm', 'asset': 'assets/sounds/digital_alarm.wav'},
    'urgent_alert': {'label': 'Urgent Alert', 'category': 'Alert', 'icon': 'warning', 'asset': 'assets/sounds/urgent_alert.wav'},
  };

  /// Whether [key] names a bundled sound. A stored key that no longer does
  /// (a sound removed in a later version, a hand-edited backup) must fall back
  /// to the default rather than ring silently.
  static bool isKnown(String? key) => key != null && options.containsKey(key);

  /// What to show for [key]: its label, or "Default" for none or unknown.
  static String labelFor(String? key) =>
      isKnown(key) ? options[key]!['label']! : 'Default';
}
