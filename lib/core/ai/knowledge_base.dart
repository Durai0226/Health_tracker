import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../database/app_database.dart';

/// Seeds the on-device RAG knowledge base from the bundled, versioned asset
/// `assets/ai/knowledge_base.json` into the Drift `KnowledgeChunks` table + its
/// companion FTS5 index. Idempotent + versioned: re-seeds only when the asset's
/// `version` is newer than what's stored (or the table is empty), so a KB
/// content update ships by bumping the asset version — no migration, no retrain.
///
/// The KB is curated GENERAL-WELLNESS text (non-diagnostic). It never contains
/// user data and stays entirely on-device.
class KnowledgeBaseSeeder {
  const KnowledgeBaseSeeder._();

  static const String _assetPath = 'assets/ai/knowledge_base.json';

  /// Loads the asset and re-seeds the KB when needed. Safe to call on every
  /// launch — a no-op when the stored KB is already current. Never throws:
  /// on any failure the assistant simply has an empty KB and abstains.
  static Future<void> ensureSeeded([AppDatabase? database]) async {
    final db = database ?? AppDatabase.instance;
    final dao = db.aiDao;
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final Map<String, dynamic> json =
          jsonDecode(raw) as Map<String, dynamic>;
      final int assetVersion = (json['version'] as num?)?.toInt() ?? 1;
      final List chunks = (json['chunks'] as List?) ?? const [];

      final storedVersion = await dao.kbVersionStored();
      final count = await dao.kbCount();
      if (count > 0 && storedVersion >= assetVersion) {
        return; // already current
      }

      await db.transaction(() async {
        await dao.clearKb();
        final now = DateTime.now();
        for (final c in chunks) {
          if (c is! Map) continue;
          final id = c['id']?.toString();
          final topic = c['topic']?.toString();
          final title = c['title']?.toString();
          final body = c['body']?.toString();
          if (id == null || topic == null || title == null || body == null) {
            continue;
          }
          final source = c['source']?.toString();
          await dao.insertChunk(KnowledgeChunksCompanion.insert(
            id: id,
            topic: topic,
            title: title,
            body: body,
            source: Value(source),
            kbVersion: Value(assetVersion),
            createdAt: now,
          ));
          await dao.insertFts(id, title, body, topic);
        }
      });
      final seeded = await dao.kbCount();
      debugPrint('✓ Knowledge base seeded (v$assetVersion, $seeded chunks)');
    } catch (e) {
      // Non-fatal: an empty KB just means the assistant abstains on KB
      // questions. Never log KB content — only the failure reason.
      debugPrint('Knowledge base seeding skipped: $e');
    }
  }
}
