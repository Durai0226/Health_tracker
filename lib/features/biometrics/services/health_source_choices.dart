import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart' as db;
import '../models/health_source.dart';

/// What the user said on Connected devices — which sources to ignore and which
/// one to prefer — as the sleep and step imports need it.
///
/// Kept apart from [HealthSourceRegistry] on purpose: that class is pure
/// functions over injected data, and this is the one place that reads the
/// table.
abstract final class HealthSourceChoices {
  /// Replaces the table read. A closed in-memory test database reopens empty
  /// instead of throwing, so the unreadable case needs a reader that does.
  @visibleForTesting
  static Future<List<db.HealthSourceRow>> Function()? readerForTesting;

  /// Every registered source by id. Empty when the table cannot be read: an
  /// import must never stop because a preference is unavailable, and with no
  /// choices known the old rule (the device that recorded most) still applies.
  static Future<Map<String, HealthSource>> load() async {
    try {
      final rows = await (readerForTesting?.call() ??
          db.AppDatabase.instance.biometricsDao.getSources());
      return {for (final r in rows) r.id: HealthSource.fromRow(r)};
    } catch (e) {
      debugPrint('⚠️ Source choices unreadable, using the default rule: $e');
      return const {};
    }
  }
}
