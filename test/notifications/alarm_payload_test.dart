import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/main.dart' show parseAlarmPayload;

/// The alarm launch payload must round-trip the real reminder title/body/id so
/// the redesigned full-screen AlarmScreen shows the actual reminder (was a
/// generic "Reminder / Time for your task").
void main() {
  group('parseAlarmPayload', () {
    test('rich JSON payload → title/body/id extracted', () {
      final payload = 'alarm:${jsonEncode({
            'id': 42,
            'title': 'Time for your Metformin',
            'body': '500 mg · with breakfast',
            'snoozeDuration': 10,
          })}';
      final m = parseAlarmPayload(payload, 99);
      expect(m['id'], 42);
      expect(m['title'], 'Time for your Metformin');
      expect(m['body'], '500 mg · with breakfast');
      expect(m['snoozeDuration'], 10);
      expect(m['payload'], payload); // original preserved
    });

    test('legacy "alarm:\$id" payload falls back to the notification id', () {
      final m = parseAlarmPayload('alarm:1234', 1234);
      expect(m['id'], 1234);
      // no title/body in the legacy format — AlarmScreen shows its defaults
      expect(m['title'], isNull);
    });

    test('malformed JSON does not throw', () {
      final m = parseAlarmPayload('alarm:{not json', 7);
      expect(m['id'], 7);
    });
  });
}
