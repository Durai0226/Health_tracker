import 'package:flutter/foundation.dart';

/// The notification that says a visit brief is ready, and the tap that opens it.
class VisitBriefLink {
  const VisitBriefLink._();

  /// The payload that opens the brief for [appointmentId].
  static String payloadFor(String appointmentId) => 'visit:$appointmentId';

  /// The appointment a [payloadFor] payload names, or null for anything else.
  static String? appointmentIdFromPayload(String? payload) {
    if (payload == null || !payload.startsWith('visit:')) return null;
    final id = payload.substring('visit:'.length);
    return id.isEmpty ? null : id;
  }

  /// Set by a tapped notice (warm or cold start); the app shell opens the brief,
  /// once the app lock allows, and clears it.
  static final ValueNotifier<String?> pendingOpen = ValueNotifier<String?>(null);
}
