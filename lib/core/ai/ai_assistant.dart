import '../services/clean_storage_service.dart';
import 'ai_types.dart';
import 'llm_engine.dart';
import 'cloud_engine.dart';
import 'rule_based_engine.dart';
import 'safety_guard.dart';
import 'ai_merge.dart';
import 'on_device_llm_engine.dart';

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

  Future<String?> dailyBriefing({
    required int medsTaken,
    required int medsTotal,
    required int waterPct,
    required int focusMinutes,
    required int remindersLeft,
    required int hour,
  }) async {
    final llm = _activeLlm();
    if (llm != null) {
      final t = await llm.completeText(
        system:
            'Give a short, warm daily briefing (max 2 sentences) from the status.',
        user:
            'meds $medsTaken/$medsTotal, water $waterPct%, focus ${focusMinutes}m, '
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
    required String question,
    String? instructions,
    String? locale,
  }) async {
    // Safety first — runs offline BEFORE any engine so it can't be bypassed or
    // prompt-injected: a red-flag question short-circuits to an emergency card.
    final emergency = SafetyGuard.emergencyResponse(question, locale: locale);
    if (emergency != null) return emergency;

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
