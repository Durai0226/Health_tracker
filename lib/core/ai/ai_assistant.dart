import '../services/clean_storage_service.dart';
import 'ai_types.dart';
import 'llm_engine.dart';
import 'cloud_engine.dart';
import 'rule_based_engine.dart';
import 'drug_info_catalog.dart';
import 'safety_guard.dart';
import 'ai_merge.dart';
import 'on_device_llm_engine.dart';
import 'openfda_grounding.dart';
import 'package:flutter/foundation.dart';
import 'rag_service.dart';
import 'memory_service.dart';

/// A grounded answer from the curated knowledge base: the (verbatim or, later,
/// LLM-phrased) answer text plus the retrieved chunks that back it, so the UI
/// can render Source citations. Null is never returned here — the caller gets
/// null from [AiAssistant.groundedAnswer] when retrieval abstains.
class GroundedAnswer {
  final String text;
  final List<RetrievedChunk> sources;

  /// The engine that produced [text]: ruleBased for the v1 verbatim path, or the
  /// active LLM tier when it phrased the answer.
  final AiEngineKind engine;
  const GroundedAnswer(this.text, this.sources,
      {this.engine = AiEngineKind.ruleBased});
}

/// Single entry point for all AI in the app. Features call intent methods here
/// and never touch a specific provider.
///
/// Routing: on-device by default. A generative [LlmEngine] (cloud now;
/// on-device LLM in Phase B) is used only when it's available AND the user's
/// preference/consent allow it. The pure-Dart [RuleBasedEngine] is always the
/// guaranteed fallback, so every feature works free, offline, and privately.
class AiAssistant {
  AiAssistant._();
  static final AiAssistant _instance = AiAssistant._();
  factory AiAssistant() => _instance;

  final RuleBasedEngine _rule = const RuleBasedEngine();
  final CloudEngine _cloud = CloudEngine();

  /// The on-device LLM tier. Defaults to a build-safe, inert engine
  /// (isAvailable == false) so the app stays on the rule engine until a model
  /// runtime is attached (see [OnDeviceLlmEngine]); replaceable for tests.
  LlmEngine? onDeviceEngine = OnDeviceLlmEngine();

  // ---- Policy (persisted via app preferences) --------------------------------
  static const _kConsent = 'aiCloudConsent';
  static const _kPref = 'aiEnginePref';

  bool get cloudConsent =>
      CleanStorageService.getAppPreference(_kConsent, false) == true;

  Future<void> setCloudConsent(bool v) async {
    await CleanStorageService.setAppPreference(_kConsent, v);
  }

  AiEnginePreference get preference => aiEnginePreferenceFromString(
      CleanStorageService.getAppPreference(_kPref, 'auto')?.toString());

  Future<void> setPreference(AiEnginePreference p) async {
    await CleanStorageService.setAppPreference(_kPref, p.name);
  }

  // ---- On-device LLM (opt-in, phased) ---------------------------------------
  static const _kOnDeviceEnabled = 'aiOnDeviceEnabled';
  static const _kOnDeviceModelUrl = 'aiOnDeviceModelUrl';

  bool get onDeviceSupported => OnDeviceLlmEngine.isSupportedPlatform;

  bool get onDeviceEnabled =>
      CleanStorageService.getAppPreference(_kOnDeviceEnabled, false) == true;

  Future<void> setOnDeviceEnabled(bool v) async {
    await CleanStorageService.setAppPreference(_kOnDeviceEnabled, v);
    if (!v) {
      final e = onDeviceEngine;
      if (e is OnDeviceLlmEngine) await e.dispose();
    }
  }

  String get onDeviceModelUrl =>
      CleanStorageService.getAppPreference(_kOnDeviceModelUrl, '')?.toString() ??
      '';

  Future<void> setOnDeviceModelUrl(String url) =>
      CleanStorageService.setAppPreference(_kOnDeviceModelUrl, url.trim());

  Future<bool> onDeviceModelInstalled() async {
    final e = onDeviceEngine;
    return e is OnDeviceLlmEngine ? e.isModelInstalled() : false;
  }

  /// Streams download progress (0–100) for the configured model.
  Stream<int> downloadOnDeviceModel(String url) {
    final e = onDeviceEngine;
    return e is OnDeviceLlmEngine ? e.downloadModel(url) : const Stream.empty();
  }

  /// Attaches the downloaded model so [activeKind] can start using it.
  Future<bool> activateOnDevice() async {
    final e = onDeviceEngine;
    return e is OnDeviceLlmEngine ? e.init() : false;
  }

  Future<void> removeOnDeviceModel() async {
    final e = onDeviceEngine;
    if (e is OnDeviceLlmEngine) await e.deleteModel();
  }

  /// Called from deferred startup: if the user enabled on-device AI and a model
  /// is present, attach it (best-effort, never blocks or throws).
  Future<void> maybeActivateOnDeviceAtStartup() async {
    if (!onDeviceEnabled || !onDeviceSupported) return;
    try {
      if (await onDeviceModelInstalled()) await activateOnDevice();
    } catch (e) {
      debugPrint('⚠️ On-device startup activation skipped: $e');
    }
  }

  /// Which engine will serve requests right now (for Settings display).
  AiEngineKind get activeKind {
    final e = _activeLlm();
    if (e == null) return AiEngineKind.ruleBased;
    return e.id == 'cloud' ? AiEngineKind.cloud : AiEngineKind.onDevice;
  }

  /// Pick the preferred available generative engine, or null → rule-based.
  LlmEngine? _activeLlm() {
    final pref = preference;
    if (pref == AiEnginePreference.localOnly) return null;

    final onDevice =
        (onDeviceEngine != null && onDeviceEngine!.isAvailable) ? onDeviceEngine : null;
    // Cloud requires explicit consent (health data leaves the device).
    final cloud = (cloudConsent && _cloud.isAvailable) ? _cloud : null;

    switch (pref) {
      case AiEnginePreference.cloud:
        return cloud ?? onDevice;
      case AiEnginePreference.onDevice:
        // Do NOT fall back to cloud — the user explicitly chose on-device
        // (privacy). If unavailable, null → the local rule engine handles it.
        return onDevice;
      case AiEnginePreference.auto:
      default:
        // Prefer on-device (private, free) over cloud when both exist.
        return onDevice ?? cloud;
    }
  }

  // ---- Intents ---------------------------------------------------------------

  Future<ParsedReminder?> parseReminder(String text) async {
    if (text.trim().isEmpty) return null;
    // Deterministic baseline first — always valid, and the safety net the LLM
    // output is merged onto (never replaced wholesale).
    final base = _rule.parseReminder(text);
    final llm = _activeLlm();
    if (llm != null) {
      final json = await llm.completeJson(
        system:
            'You extract a reminder from the user text. Today is ${DateTime.now().toIso8601String()}. '
            'Keys: title (string), datetimeIso (ISO-8601 for the next occurrence), '
            'repeat (one of none|daily|weekly|weekdays|weekends), category (string or empty), '
            'priority (low|medium|high).',
        user: _redact(text, llm),
      );
      if (json != null) {
        // Validate + overlay onto the rule baseline (schema-enforced).
        return AiMerge.mergeReminder(base: base, llm: json);
      }
    }
    return base; // guaranteed
  }

  Future<Map<String, dynamic>?> parseMedicine(String text) async {
    if (text.trim().isEmpty) return null;
    final base = _rule.parseMedicine(text);
    final llm = _activeLlm();
    if (llm != null) {
      final json = await llm.completeJson(
        system:
            'Extract medication details from the user text. Keys: name (string), '
            'dosageAmount (number), dosageUnit (mg|ml|g|mcg|iu|tablet), '
            'form (tablet|capsule|liquid|injection|drops|other), '
            'frequency (once daily|twice daily|thrice daily|four times daily|asNeeded|everyXHours), '
            'times (array of HH:mm strings if implied).',
        user: _redact(text, llm),
      );
      if (json != null) {
        // Validate + merge onto the rule baseline (schema-enforced, safe).
        return AiMerge.mergeMedicine(base: base, llm: json);
      }
    }
    return base;
  }

  Future<String?> hydrationTip({
    required int intakeMl,
    required int goalMl,
    required int streakDays,
    required int hour,
  }) async {
    final llm = _activeLlm();
    if (llm != null) {
      final t = await llm.completeText(
        system:
            'You are a friendly hydration coach. Reply with ONE short, specific, '
            'encouraging tip (max 2 sentences).',
        user:
            'Intake ${intakeMl}ml of ${goalMl}ml goal; streak $streakDays days; hour $hour.',
      );
      if (t != null) return t;
    }
    return _rule.hydrationTip(
        intakeMl: intakeMl, goalMl: goalMl, streakDays: streakDays, hour: hour);
  }

  Future<String?> focusCoach({
    required int todayMinutes,
    required int streakDays,
    required int totalSessions,
  }) async {
    final llm = _activeLlm();
    if (llm != null) {
      final t = await llm.completeText(
        system:
            'You are a supportive focus coach. Reply with ONE short, actionable '
            'suggestion (max 2 sentences).',
        user:
            'Today $todayMinutes min; streak $streakDays days; total sessions $totalSessions.',
      );
      if (t != null) return t;
    }
    return _rule.focusCoach(
        todayMinutes: todayMinutes,
        streakDays: streakDays,
        totalSessions: totalSessions);
  }

  Future<String?> stepsTip({
    required int steps,
    required int goal,
    required int streakDays,
    required int hour,
  }) async {
    final llm = _activeLlm();
    if (llm != null) {
      final t = await llm.completeText(
        system:
            'You are an encouraging activity coach. Reply with ONE short, specific '
            'tip (max 2 sentences).',
        user: 'Steps $steps of $goal goal; streak $streakDays days; hour $hour.',
      );
      if (t != null) return t;
    }
    return _rule.stepsTip(
        steps: steps, goal: goal, streakDays: streakDays, hour: hour);
  }

  Future<String?> sleepTip({
    required int lastNightMinutes,
    required int targetMinutes,
    required int debtMinutes,
    required double regularity,
  }) async {
    final llm = _activeLlm();
    if (llm != null) {
      final t = await llm.completeText(
        system:
            'You are a calm sleep coach. Reply with ONE short, actionable '
            'suggestion (max 2 sentences). Never give a diagnosis.',
        user:
            'Last night ${lastNightMinutes}m of ${targetMinutes}m target; weekly '
            'debt ${debtMinutes}m; regularity ${regularity.toStringAsFixed(2)}.',
      );
      if (t != null) return t;
    }
    return _rule.sleepTip(
        lastNightMinutes: lastNightMinutes,
        targetMinutes: targetMinutes,
        debtMinutes: debtMinutes,
        regularity: regularity);
  }

  /// Honest cycle companion. Fertility is an estimate (never contraception),
  /// never a diagnosis — the LLM output is disclaimer-wrapped.
  Future<String?> cycleInsight({
    int? daysUntilNextPeriod,
    bool inFertileWindow = false,
    bool isLate = false,
    int lateDays = 0,
    bool irregular = false,
    bool learning = false,
    bool pregnancy = false,
    int? cycleDay,
  }) async {
    final llm = _activeLlm();
    if (llm != null) {
      final t = await llm.completeText(
        system:
            'You are a supportive, non-judgmental menstrual-cycle companion. Reply '
            'with ONE short, honest sentence (max 2). Any fertility info is an '
            'estimate and NOT reliable for contraception. Never give a diagnosis.',
        user:
            'daysUntilNext ${daysUntilNextPeriod ?? 'unknown'}, fertileWindow '
            '$inFertileWindow, late $isLate ($lateDays d), irregular $irregular, '
            'learning $learning, pregnancy $pregnancy, cycleDay ${cycleDay ?? 'unknown'}.',
      );
      if (t != null) return SafetyGuard.ensureDisclaimer(t);
    }
    return _rule.cycleInsight(
      daysUntilNextPeriod: daysUntilNextPeriod,
      inFertileWindow: inFertileWindow,
      isLate: isLate,
      lateDays: lateDays,
      irregular: irregular,
      learning: learning,
      pregnancy: pregnancy,
      cycleDay: cycleDay,
    );
  }

  Future<String?> dailyBriefing({
    required int medsTaken,
    required int medsTotal,
    required int waterPct,
    required int focusMinutes,
    required int remindersLeft,
    required int hour,
    int steps = 0,
    int stepGoal = 0,
    int sleepMinutes = 0,
  }) async {
    final llm = _activeLlm();
    if (llm != null) {
      final t = await llm.completeText(
        system:
            'Give a short, warm daily briefing (max 2 sentences) from the status.',
        user:
            'meds $medsTaken/$medsTotal, water $waterPct%, steps $steps/$stepGoal, '
            'sleep ${sleepMinutes}m, focus ${focusMinutes}m, '
            'reminders left $remindersLeft, hour $hour.',
      );
      if (t != null) return t;
    }
    return _rule.dailyBriefing(
      medsTaken: medsTaken,
      medsTotal: medsTotal,
      waterPct: waterPct,
      focusMinutes: focusMinutes,
      remindersLeft: remindersLeft,
      hour: hour,
      steps: steps,
      stepGoal: stepGoal,
      sleepMinutes: sleepMinutes,
    );
  }

  Future<int?> suggestWaterGoal({
    double? weightKg,
    String? activity,
    String? climate,
  }) async {
    final llm = _activeLlm();
    if (llm != null) {
      final json = await llm.completeJson(
        system:
            'Suggest a daily water goal in ml. Key: goalMl (integer, 1500-4000).',
        user:
            'weight ${weightKg ?? 'unknown'} kg, activity ${activity ?? 'unknown'}, '
            'climate ${climate ?? 'unknown'}.',
      );
      final g = json?['goalMl'];
      if (g is num) return g.round().clamp(1500, 4000);
    }
    return _rule.suggestWaterGoal(
        weightKg: weightKg, activity: activity, climate: climate);
  }

  Future<String?> medicineAnswer({
    required String name,
    String? dose,
    String? generic,
    required String question,
    String? instructions,
    String? locale,
  }) async {
    // Safety first — runs offline BEFORE any engine so it can't be bypassed or
    // prompt-injected: a red-flag question short-circuits to an emergency card.
    final emergency = SafetyGuard.emergencyResponse(question, locale: locale);
    if (emergency != null) return emergency;

    // Tier 3: if the user opted into network use, prefer the AUTHORITATIVE FDA
    // label over any generative answer for medical facts (only the drug name
    // leaves the device). Falls through to on-device engines on any failure.
    if (cloudConsent) {
      final grounded = await OpenFdaGrounding.fetch(name, question);
      if (grounded != null) {
        final body =
            '**${grounded.section}** (${grounded.source}):\n\n${grounded.text}';
        return SafetyGuard.ensureDisclaimer(body);
      }
    }

    final llm = _activeLlm();
    if (llm != null) {
      final t = await llm.completeText(
        system:
            'You are a careful medication information assistant. The medicine is '
            '$name${dose != null ? ', dose $dose' : ''}. Answer concisely, add a '
            'one-line safety note, and never give a diagnosis.',
        user: _redact(question, llm),
      );
      if (t != null) return SafetyGuard.ensureDisclaimer(t);
    }

    // Curated OFFLINE drug-info KB: a real, well-established, drug-specific
    // answer (uses / side-effects / food / precautions) instead of a generic
    // "ask your pharmacist" deflection. Resolves brand → generic first.
    await DrugInfoCatalog.ensureLoaded();
    final grounded = DrugInfoCatalog.answer(
      question: question,
      generic: generic,
      displayName: name,
    );
    if (grounded != null) {
      final withNote =
          instructions != null && instructions.trim().isNotEmpty
              ? '$grounded\n\n_Your saved note: "${instructions.trim()}"._'
              : grounded;
      return SafetyGuard.ensureDisclaimer(withNote);
    }

    final answer = _rule.medicineAnswer(
        name: name, dose: dose, question: question, instructions: instructions);
    // Guarantee the not-a-diagnosis note on every medical answer.
    return SafetyGuard.ensureDisclaimer(answer);
  }

  Future<String?> explainInteractions(List<String> descriptions) async {
    final llm = _activeLlm();
    if (llm != null) {
      final t = await llm.completeText(
        system:
            'Explain these medication interactions simply for a patient in 2-3 '
            'short bullets, then add "talk to your pharmacist".',
        user: _redact(descriptions.join('\n'), llm),
      );
      if (t != null) return SafetyGuard.ensureDisclaimer(t);
    }
    return SafetyGuard.ensureDisclaimer(_rule.explainInteractions(descriptions));
  }

  /// Grounded knowledge-base answer — the single retrieval seam every AI tier
  /// shares. Retrieves curated chunks (FTS5/BM25) + the user's active memory,
  /// and:
  ///  • v1 (no LLM active) → returns the top chunk VERBATIM (+ disclaimer).
  ///  • Phase 2 (on-device Gemma active) → the LLM answers ONLY from the
  ///    retrieved context and MUST refuse if it isn't there — so even the LLM
  ///    tail stays cited, disclaimered, and abstaining.
  /// Returns null when nothing relevant is retrieved (the caller then abstains).
  Future<GroundedAnswer?> groundedAnswer(String question) async {
    final chunks = await const RagService().retrieve(question, k: 3);
    if (chunks.isEmpty) return null; // abstain — never guess

    final top = chunks.first;
    final llm = _activeLlm();
    if (llm != null) {
      final context =
          chunks.map((c) => '- ${c.title}: ${c.body}').join('\n');
      // Memory is device-only: it grounds the on-device LLM but is NEVER put in
      // a prompt bound for the cloud engine (the system prompt isn't redacted,
      // and free-text memories like "trying to conceive" must not leave the
      // device). Cloud answers stay grounded on the curated KB alone.
      final memory =
          llm.id == 'cloud' ? null : await const MemoryService().contextBlock();
      final t = await llm.completeText(
        system: 'Answer the user ONLY from the CONTEXT below. If the context '
            'does not contain the answer, say you don\'t know — do not use '
            'outside knowledge. Cite the source title. Never give a diagnosis.\n\n'
            'CONTEXT:\n$context'
            '${memory != null ? '\n\nUSER NOTES:\n$memory' : ''}',
        user: _redact(question, llm),
      );
      if (t != null && t.trim().isNotEmpty) {
        final kind = llm.id == 'cloud'
            ? AiEngineKind.cloud
            : AiEngineKind.onDevice;
        return GroundedAnswer(SafetyGuard.ensureDisclaimer(t), chunks,
            engine: kind);
      }
      // LLM produced nothing usable → fall through to the deterministic answer.
    }

    // v1 deterministic: verbatim curated text. 'app' snippets carry their own
    // framing; medical topics get the not-a-diagnosis note appended.
    final text =
        top.topic == 'app' ? top.body : SafetyGuard.ensureDisclaimer(top.body);
    return GroundedAnswer(text, chunks, engine: AiEngineKind.ruleBased);
  }

  /// Light-touch PII scrub before an off-device (cloud) call (defense-in-depth;
  /// cloud use is already consent-gated). Only redacts when the payload will
  /// actually leave the device — decided from the engine that will receive it.
  String _redact(String s, LlmEngine engine) {
    if (engine.id != 'cloud') return s; // on-device stays on device
    var out = s.replaceAll(RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+'), '[email]');
    out = out.replaceAll(RegExp(r'\+?\d[\d ()-]{7,}\d'), '[number]');
    return out;
  }
}
