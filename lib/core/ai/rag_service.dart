import '../database/app_database.dart';

/// One retrieved knowledge-base chunk plus its provenance, ready to render as a
/// verbatim answer + "Source" citation.
class RetrievedChunk {
  final String id;
  final String topic;
  final String title;
  final String body;
  final String? source;

  /// Count of distinct query content-tokens that appear in this chunk — used
  /// for the abstention gate and as a light re-rank signal on top of bm25.
  final int overlap;

  /// Count of query tokens that appear in the TITLE — a strong on-topic signal
  /// (a "How much water to drink" title beats "Can you drink too much?" for
  /// "how much water should I drink").
  final int titleOverlap;

  const RetrievedChunk({
    required this.id,
    required this.topic,
    required this.title,
    required this.body,
    required this.source,
    required this.overlap,
    this.titleOverlap = 0,
  });

  /// A short citation label for the Source chip (e.g. "Sleep hygiene basics").
  String get citation => source == null ? title : '$title · $source';
}

/// Deterministic retrieval-augmented lookup over the curated on-device knowledge
/// base (SQLite FTS5 + bm25). PURE over the DAO + the local DB — no network, no
/// model, no user data leaves the device.
///
/// The core rule is **abstention**: when nothing relevant is retrieved it
/// returns an empty list, and the caller falls back to an honest "I don't have
/// that yet" — it NEVER guesses. This is the single retrieval seam an on-device
/// LLM tail (Phase 2) plugs into unchanged.
class RagService {
  const RagService();

  /// Lightweight "semantic-lite" aliasing: everyday words → the vocabulary the
  /// curated KB actually uses, so paraphrases retrieve without an embedding
  /// model ("workout" → activity, "meds" → medication, "stressed" → wellbeing).
  static const Map<String, List<String>> _synonyms = {
    'menstrual': ['period', 'cycle'],
    'menstruation': ['period', 'cycle'],
    'periods': ['period', 'cycle'],
    'workout': ['activity', 'exercise'],
    'workouts': ['activity', 'exercise'],
    'exercise': ['activity', 'exercise'],
    'exercising': ['activity', 'exercise'],
    'gym': ['activity', 'exercise'],
    'run': ['activity', 'exercise'],
    'running': ['activity', 'exercise'],
    'rest': ['sleep'],
    'nap': ['sleep'],
    'tired': ['sleep', 'fatigue'],
    'hydrate': ['water', 'hydration'],
    'hydrated': ['water', 'hydration'],
    'fluids': ['water', 'hydration'],
    'bp': ['blood', 'pressure'],
    'sugar': ['glucose', 'blood'],
    'meds': ['medication', 'medicine'],
    'med': ['medication', 'medicine'],
    'pills': ['medication', 'medicine'],
    'medicine': ['medication'],
    'diet': ['nutrition', 'food'],
    'eating': ['nutrition', 'food'],
    'food': ['nutrition', 'food'],
    'stress': ['stress', 'wellbeing'],
    'stressed': ['stress', 'wellbeing'],
    'anxiety': ['stress', 'wellbeing'],
    'anxious': ['stress', 'wellbeing'],
    'mood': ['mood', 'wellbeing'],
    'walking': ['activity', 'steps'],
    'walk': ['activity', 'steps'],
    'weight': ['nutrition', 'activity'],
  };

  /// Query tokens plus their KB-vocabulary aliases (order-preserving, deduped).
  static List<String> _expand(List<String> tokens) {
    final out = <String>[];
    final seen = <String>{};
    for (final t in tokens) {
      if (seen.add(t)) out.add(t);
      for (final syn in _synonyms[t] ?? const <String>[]) {
        if (seen.add(syn)) out.add(syn);
      }
    }
    return out;
  }

  /// Words too common to carry meaning — dropped before building the FTS query
  /// so a match on a real content word (e.g. "follicular") is what counts.
  static const Set<String> _stopwords = {
    'the', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
    'do', 'does', 'did', 'have', 'has', 'had', 'can', 'could', 'should',
    'would', 'will', 'shall', 'may', 'might', 'must', 'to', 'of', 'in', 'on',
    'at', 'by', 'for', 'with', 'about', 'from', 'and', 'or', 'but', 'if',
    'my', 'me', 'i', 'you', 'your', 'it', 'its', 'this', 'that', 'these',
    'those', 'what', 'when', 'how', 'why', 'who', 'which', 'whom', 'where',
    'am', 'so', 'as', 'get', 'got', 'tell', 'know', 'much', 'many',
    'good', 'bad', 'ok', 'okay', 'some', 'any', 'more', 'most', 'now', 'day',
    'days', 'time', 'help', 'please', 'thanks', 'thank',
  };

  /// Light morphological relatedness for the overlap gate — matches the FTS5
  /// `porter` stemmer's forgiveness so a query variant ("sleeping", "hydration")
  /// isn't rejected against a base-form chunk ("sleep", "hydrate"). Cheap: exact,
  /// prefix, or a shared 4-char stem.
  static bool _related(String a, String b) {
    if (a == b || b.startsWith(a) || a.startsWith(b)) return true;
    if (a.length >= 4 && b.length >= 4 && a.substring(0, 4) == b.substring(0, 4)) {
      return true;
    }
    return false;
  }

  /// Extracts lowercase content tokens (letters/digits, length ≥ 3, non-stop).
  static List<String> tokenize(String text) {
    final matches = RegExp(r'[a-z0-9]+').allMatches(text.toLowerCase());
    final out = <String>[];
    for (final m in matches) {
      final w = m.group(0)!;
      if (w.length < 3) continue;
      if (_stopwords.contains(w)) continue;
      out.add(w);
    }
    return out;
  }

  /// Builds a safe FTS5 MATCH expression from a natural-language question:
  /// prefix-OR over the content tokens (`follicular* OR phase*`). Returns null
  /// when the question has no usable content token (→ abstain immediately).
  static String? buildFtsQuery(String question) {
    final tokens = _expand(tokenize(question));
    if (tokens.isEmpty) return null;
    // Prefix-OR over content tokens + aliases; cap to keep the query bounded.
    final terms = tokens.take(16).map((t) => '$t*').toList();
    return terms.join(' OR ');
  }

  /// Retrieves up to [k] curated chunks relevant to [question], best-first.
  /// Empty ⇒ ABSTAIN (nothing relevant / no content tokens / DB error).
  Future<List<RetrievedChunk>> retrieve(String question, {int k = 3}) async {
    final ftsQuery = buildFtsQuery(question);
    if (ftsQuery == null) return const [];

    final dao = AppDatabase.instance.aiDao;
    // Pull a few extra candidates so the Dart-side overlap gate has room to work.
    final rows = await dao.searchKb(ftsQuery, k + 5);
    if (rows.isEmpty) return const [];

    final qTokens = _expand(tokenize(question)).toSet();
    final wordRe = RegExp(r'[a-z0-9]+');
    final scored = <RetrievedChunk>[];
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final titleWords =
          wordRe.allMatches(r.title.toLowerCase()).map((m) => m.group(0)!).toSet();
      final bodyWords = wordRe
          .allMatches('${r.body} ${r.topic}'.toLowerCase())
          .map((m) => m.group(0)!)
          .toSet();
      var overlap = 0;
      var titleOverlap = 0;
      for (final t in qTokens) {
        final inTitle = titleWords.any((w) => _related(t, w));
        if (inTitle) titleOverlap++;
        if (inTitle || bodyWords.any((w) => _related(t, w))) overlap++;
      }
      if (overlap == 0) continue; // no meaningful content token present
      scored.add(RetrievedChunk(
        id: r.id,
        topic: r.topic,
        title: r.title,
        body: r.body,
        source: r.source,
        overlap: overlap,
        titleOverlap: titleOverlap,
      ));
    }
    if (scored.isEmpty) return const [];
    // Rank: title match (most on-topic) → total overlap → bm25 order (the input
    // order from the DAO, preserved for ties). indexOf keeps the sort stable
    // across engines that don't guarantee List.sort stability.
    final order = {for (var i = 0; i < scored.length; i++) scored[i].id: i};
    scored.sort((a, b) {
      final t = b.titleOverlap.compareTo(a.titleOverlap);
      if (t != 0) return t;
      final o = b.overlap.compareTo(a.overlap);
      if (o != 0) return o;
      return order[a.id]!.compareTo(order[b.id]!);
    });
    return scored.take(k).toList();
  }
}
