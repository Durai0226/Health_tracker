import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../database/daos/ai_dao.dart';
import '../services/clean_storage_service.dart';

/// The two conversational tones the user can pick for the assistant.
enum AssistantTone { conversational, direct }

/// Outcome of a "forget …" request.
enum ForgetResult { removed, notFound, ambiguous }

/// Durable, user-curated assistant memory (the ChatGPT/Oura "Memories" pattern).
///
/// Privacy contract (enforced here):
///  • Written ONLY from explicit, confirmed user statements — never auto-
///    extracted from health data. The caller must have parsed a clear
///    "remember …" / "my goal is …" intent before calling [remember].
///  • Gated by a master [enabled] switch; when off, reads/writes are no-ops.
///  • Never leaves the device: the `AssistantMemories` table is deliberately
///    NOT registered with cloud sync/backup, and "Delete all data" wipes it.
///
/// New goal/preference memories SUPERSEDE the prior same-kind one so
/// contradictory facts can't accumulate; plain facts dedup by content.
class MemoryService {
  const MemoryService();

  static const String kKindGoal = 'goal';
  static const String kKindPreference = 'preference';
  static const String kKindFact = 'fact';

  static const String _enabledPref = 'aiMemoryEnabled';
  static const String _tonePref = 'aiAssistantTone';

  static const _uuid = Uuid();

  AiDao get _dao => AppDatabase.instance.aiDao;

  // ---- master switch (consent) ----
  /// Whether memory is on. Default ON, but every read/write checks it, so
  /// turning it off immediately stops the assistant using or storing memory.
  bool get enabled =>
      CleanStorageService.getAppPreference(_enabledPref, true) == true;

  Future<void> setEnabled(bool value) =>
      CleanStorageService.setAppPreference(_enabledPref, value);

  // ---- tone ----
  AssistantTone get tone =>
      CleanStorageService.getAppPreference(_tonePref, 'conversational') ==
              'direct'
          ? AssistantTone.direct
          : AssistantTone.conversational;

  Future<void> setTone(AssistantTone t) => CleanStorageService.setAppPreference(
      _tonePref, t == AssistantTone.direct ? 'direct' : 'conversational');

  // ---- reads ----
  /// Active memories, newest first. Empty when memory is disabled.
  Future<List<AssistantMemoryRow>> active() async {
    if (!enabled) return const [];
    return _dao.activeMemories();
  }

  /// Every memory (active + superseded) for the management screen.
  Future<List<AssistantMemoryRow>> all() => _dao.allMemories();

  /// A compact, plain-language recap of active memories for the "what do you
  /// remember about me?" answer and (Phase 2) for grounding the on-device LLM.
  /// Returns null when memory is off or empty.
  Future<String?> contextBlock() async {
    final rows = await active();
    if (rows.isEmpty) return null;
    return rows.map((m) => '• ${m.content}').join('\n');
  }

  // ---- writes ----
  /// Stores an explicit user fact. No-op (returns null) when memory is disabled
  /// or the content is empty. Dedups identical active content; goal/preference
  /// kinds supersede the prior same-kind memory.
  Future<AssistantMemoryRow?> remember(String content,
      {String kind = kKindFact}) async {
    if (!enabled) return null;
    final display = _display(content); // keeps the user's casing
    if (display.isEmpty) return null;
    final key = display.toLowerCase(); // dedup/match key

    final existing = await _dao.activeMemories();

    // Dedup: identical (case-insensitive) active content already stored.
    for (final m in existing) {
      if (m.content.toLowerCase() == key) return m;
    }

    // Supersede the prior goal/preference so contradictions can't pile up.
    if (kind == kKindGoal || kind == kKindPreference) {
      await _dao.deactivateKind(kind);
    }

    final now = DateTime.now();
    final id = _uuid.v4();
    await _dao.upsertMemory(AssistantMemoriesCompanion.insert(
      id: id,
      content: display,
      kind: Value(kind),
      createdAt: now,
      updatedAt: now,
    ));
    debugPrint('✓ Memory saved ($kind, id=$id)'); // id/kind only — never content
    return AssistantMemoryRow(
      id: id,
      content: display,
      kind: kind,
      active: true,
      createdAt: now,
      updatedAt: now,
      source: 'user',
    );
  }

  Future<void> forget(String id) => _dao.deleteMemory(id);

  /// Deletes the active memory that best matches free-text like "forget that I'm
  /// trying to conceive". Uses word-set (Jaccard) similarity so a vague single
  /// word ("steps") can't silently nuke an unrelated memory ("8000 steps"). When
  /// several notes match comparably it returns [ForgetResult.ambiguous] rather
  /// than guessing, so the assistant can ask which one.
  Future<ForgetResult> forgetByText(String text) async {
    final needle = _words(text);
    if (needle.isEmpty) return ForgetResult.notFound;
    final rows = await _dao.activeMemories();

    // Exact (normalized) content match always wins outright.
    final key = _display(text).toLowerCase();
    for (final m in rows) {
      if (m.content.toLowerCase() == key) {
        await _dao.deleteMemory(m.id);
        return ForgetResult.removed;
      }
    }

    // Candidates: the user's words are all in the memory, or the memory's words
    // are all in the phrase (either-direction subset). A single candidate is
    // safe to delete; MULTIPLE means "forget steps" is ambiguous → ask, never
    // silently delete the wrong one.
    final matches = <AssistantMemoryRow>[];
    for (final m in rows) {
      final content = _words(m.content);
      if (content.isEmpty) continue;
      if (needle.difference(content).isEmpty ||
          content.difference(needle).isEmpty) {
        matches.add(m);
      }
    }
    if (matches.isEmpty) return ForgetResult.notFound;
    if (matches.length > 1) return ForgetResult.ambiguous;
    await _dao.deleteMemory(matches.first.id);
    return ForgetResult.removed;
  }

  /// Content words (length ≥ 3, alphanumeric) as a set, for similarity matching.
  static Set<String> _words(String s) => RegExp(r'[a-z0-9]+')
      .allMatches(s.toLowerCase())
      .map((m) => m.group(0)!)
      .where((w) => w.length >= 3)
      .toSet();

  Future<void> clear() => _dao.clearMemories();

  /// Whitespace-collapsed, trailing-punctuation-stripped form for storage +
  /// display. Preserves the casing the user typed; matching lowercases on use.
  static String _display(String s) => s
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[.!?,;:]+$'), '');
}

/// What kind of explicit memory instruction (if any) a message carries.
enum MemoryCommandType { none, remember, forget, forgetLast, recall }

/// Pure parser that classifies whether a user message is an EXPLICIT memory
/// instruction — the guard that keeps a data question ("what is the luteal
/// phase?") from ever being mistaken for a memory write. Deterministic + DB-free
/// so it's fully unit-testable.
class MemoryCommand {
  final MemoryCommandType type;
  final String? content; // for remember / forget-by-text
  final String kind; // for remember
  const MemoryCommand(this.type,
      {this.content, this.kind = MemoryService.kKindFact});

  static const none = MemoryCommand(MemoryCommandType.none);

  static final _forget = RegExp(
      r'^(?:please\s+)?(?:forget|stop remembering|delete)(?:\s+that|\s+about)?\s+(.+)$',
      caseSensitive: false);
  static final _goal =
      RegExp(r'^(?:my|the)\s+goal\s+is\s+(.+)$', caseSensitive: false);
  static final _remember = RegExp(
      r'^(?:please\s+)?(?:remember|note|keep in mind)(?:\s+that)?\s+(.+)$',
      caseSensitive: false);
  static final _preferenceHint =
      RegExp(r'\b(prefer|like|hate)\b', caseSensitive: false);

  static MemoryCommand parse(String question) {
    final q = question.trim();
    final lower = q.toLowerCase();

    // Recall — "what do you remember/know about me", "my memories".
    final isRecall = ((lower.contains('remember') || lower.contains('know')) &&
            lower.contains('about me')) ||
        lower.contains('my memories') ||
        lower.contains('what have you saved') ||
        lower == 'what do you remember' ||
        lower == 'what do you remember?';
    if (isRecall) return const MemoryCommand(MemoryCommandType.recall);

    // Forget the last thing — exact phrases, checked before the forget regex.
    if (lower == 'forget that' || lower == 'forget it') {
      return const MemoryCommand(MemoryCommandType.forgetLast);
    }

    // Forget by text — "forget that I'm TTC", "stop remembering my goal".
    final forget = _forget.firstMatch(q);
    if (forget != null) {
      return MemoryCommand(MemoryCommandType.forget,
          content: forget.group(1)!.trim());
    }

    // Goal — "my goal is 8000 steps" (supersedes the prior goal).
    final goal = _goal.firstMatch(q);
    if (goal != null) {
      return MemoryCommand(MemoryCommandType.remember,
          content: goal.group(1)!.trim(), kind: MemoryService.kKindGoal);
    }

    // Remember — "remember I prefer evening reminders", "note that …".
    final remember = _remember.firstMatch(q);
    if (remember != null) {
      final content = remember.group(1)!.trim();
      final kind = _preferenceHint.hasMatch(content)
          ? MemoryService.kKindPreference
          : MemoryService.kKindFact;
      return MemoryCommand(MemoryCommandType.remember,
          content: content, kind: kind);
    }

    return none;
  }
}
