import '../../../core/ai/ai_types.dart';
import '../../../core/ai/rule_based_engine.dart';
import '../../../core/ai/safety_guard.dart';
import '../../../core/ai/ai_assistant.dart';
import '../../../core/ai/memory_service.dart';
import '../../../core/ai/vitals_analyzer.dart';
import '../../../core/ai/vitals_pattern_detector.dart';
import '../../../core/ai/adherence_analyzer.dart';
import '../../../core/ai/streak_engine.dart';
import '../../../core/ai/hydration_pacer.dart';
import '../../../core/ai/focus_insights.dart';
import '../../medication/services/medicine_storage_service.dart';
import '../../medication/services/vitals_storage_service.dart';
import '../../medication/services/today_schedule_service.dart';
import '../../medication/models/blood_pressure_reading.dart';
import '../../medication/models/glucose_reading.dart';
import '../../water/services/water_service.dart';
import '../../water/models/beverage_type.dart';
import '../../focus/services/focus_service.dart';
import '../../period/services/period_service.dart';
import '../../period/models/cycle_prediction.dart';
import '../../steps/services/step_service.dart';
import '../../sleep/services/sleep_service.dart';

/// A verbatim knowledge-base citation shown under a grounded answer (the
/// "Source" chip). Carries the quoted [body] so tapping the chip can reveal the
/// exact curated text the answer came from — provenance the user can inspect.
class Citation {
  final String id;
  final String title;
  final String? source;
  final String body;
  const Citation(
      {required this.id, required this.title, this.source, required this.body});

  String get label => source == null ? title : '$title · $source';

  Map<String, dynamic> toJson() =>
      {'id': id, 'title': title, 'source': source, 'body': body};

  factory Citation.fromJson(Map<String, dynamic> j) => Citation(
        id: j['id']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        source: j['source']?.toString(),
        body: j['body']?.toString() ?? '',
      );
}

/// One assistant answer.
class AssistantReply {
  final String text;
  final List<String> followups;
  final bool isEmergency;

  /// Grounding citations for a RAG answer (empty for own-data / memory replies).
  final List<Citation> sources;

  /// Which engine produced this answer — drives the honest EngineBadge. Almost
  /// always on-device/ruleBased today; reflects the LLM tier when it phrases.
  final AiEngineKind engine;

  /// The topic this answer was about (hydration/sleep/period/…), so a follow-up
  /// like "why?" or "is that bad?" can be resolved against it next turn.
  final String? topic;

  const AssistantReply(this.text,
      {this.followups = const [],
      this.isEmergency = false,
      this.sources = const [],
      this.engine = AiEngineKind.ruleBased,
      this.topic});

  AssistantReply withTopic(String? t) => AssistantReply(text,
      followups: followups,
      isEmergency: isEmergency,
      sources: sources,
      engine: engine,
      topic: t);
}

/// Deterministic-first "Ask about my data" assistant. Answers natural-language
/// questions from the user's OWN logs on-device (free, private, offline). Safety
/// red-flags short-circuit to an emergency card before anything else. When an
/// on-device/cloud LLM tier is later enabled it can phrase the long tail — the
/// deterministic handlers here remain the guaranteed baseline.
class AssistantService {
  const AssistantService._();

  /// Starter prompts for the empty state.
  static const List<String> starters = [
    "What's my medication adherence?",
    'When is my next period?',
    'Am I hitting my step goal?',
    'How did I sleep?',
    'Am I on track with water today?',
    'What are my streaks?',
  ];

  /// Answers [question]. [contextTopic] is the topic of the previous answer, so
  /// a bare follow-up ("why?", "tell me more", "is that bad?") is resolved
  /// against it — a lightweight, deterministic multi-turn.
  static Future<AssistantReply> answer(String question,
      {String? contextTopic}) async {
    // Safety red-flags short-circuit FIRST, in pure Dart, before any routing —
    // un-bypassable. Crisis (self-harm) gets its own resources card.
    final emergency = SafetyGuard.emergencyResponse(question);
    if (emergency != null) return AssistantReply(emergency, isEmergency: true);

    final expanded = _expandFollowUp(question, contextTopic);
    // Resolve the reply, then apply the user's tone preference at one exit.
    return _applyTone(await _resolve(expanded));
  }

  /// Bare conversational follow-ups that only make sense against the prior turn.
  static final RegExp _followUpCue = RegExp(
    r"^(why|why (is|are|does|do|would) (that|this|it)?|how so|how come|"
    r"tell me more|more( info| about (it|that|this))?|explain( more)?|go on|"
    r"and\??|really\??|is (it|that|this) (bad|ok|okay|normal|safe|good|healthy)|"
    r"what about (it|that|this)|so\??)\??$",
    caseSensitive: false,
  );

  /// Turns a bare follow-up into a general-knowledge question about the prior
  /// topic, so "why?" / "tell me more" after a hydration answer retrieves more
  /// hydration info from the KB (rather than a new own-data status check).
  static String _expandFollowUp(String question, String? contextTopic) {
    if (contextTopic == null) return question;
    if (_followUpCue.hasMatch(question.trim())) {
      return 'tell me about $contextTopic';
    }
    return question;
  }

  static Future<AssistantReply> _resolve(String question) async {
    // Explicit memory command? ("remember …" / "forget …" / recall). Handled
    // before data routing so a clear instruction is never mistaken for a
    // question. Memory is written ONLY here, from an explicit statement.
    final mem = await _memoryReply(question);
    if (mem != null) return mem;

    // Natural-language logging command? ("drank 500ml", "took my pill",
    // "BP 150/95") — actually LOG it (with a ✓ confirmation), not just redirect.
    final cmd = const RuleBasedEngine().parseCommand(question);
    if (!cmd.isNone) return await _commandReply(cmd);

    return _route(question);
  }

  static Future<AssistantReply> _route(String question) async {
    final q = question.toLowerCase();

    // General-knowledge question ("what is the luteal phase?", "how much water
    // should I drink?") → answer from the curated KB, not the user's logs. We
    // only PREFER RAG when it actually retrieves; otherwise fall through to
    // own-data routing. This unshadows the knowledge base.
    if (_looksGeneral(q)) {
      final rag = await _rag(question);
      if (rag.sources.isNotEmpty) return rag;
    }

    // Own-data routing, tagged with its topic so follow-ups can resolve to it.
    final topic = _topicOf(q);
    if (topic != null) return (await _ownData(topic)).withTopic(topic);

    // Nothing matched the user's own data → curated knowledge base (or abstain).
    return _rag(question);
  }

  static bool _has(String q, List<String> keys) => keys.any(q.contains);

  /// The own-data topic a question is about, or null.
  static String? _topicOf(String q) {
    if (_has(q, ['adherence', 'dose', 'missed', 'medication', 'my meds', 'pills'])) {
      return 'medication';
    }
    if (_has(q, ['refill', 'stock', 'supply', 'run out', 'reorder'])) return 'refill';
    if (_has(q, ['water', 'hydrat', 'drink'])) return 'hydration';
    if (_has(q, ['blood pressure', 'bp', 'systolic', 'diastolic'])) return 'vitals';
    if (_has(q, ['blood sugar', 'glucose', 'sugar', 'a1c'])) return 'glucose';
    if (_has(q, ['focus', 'concentrat', 'deep work', 'pomodoro'])) return 'focus';
    if (_has(q, ['period', 'cycle', 'menstrua', 'ovulat', 'fertile', 'pms'])) {
      return 'cycle';
    }
    if (_has(q, ['step', 'walk', 'activity', 'distance', 'calorie'])) return 'activity';
    if (_has(q, ['sleep', 'slept', 'bedtime', 'rest', 'nap'])) return 'sleep';
    if (_has(q, ['streak'])) return 'streaks';
    return null;
  }

  static Future<AssistantReply> _ownData(String topic) async {
    switch (topic) {
      case 'medication':
        return _medicine();
      case 'refill':
        return _refill();
      case 'hydration':
        return _water();
      case 'vitals':
        return _bp();
      case 'glucose':
        return _glucose();
      case 'focus':
        return _focus();
      case 'cycle':
        return _period();
      case 'activity':
        return _steps();
      case 'sleep':
        return _sleep();
      case 'streaks':
        return _streaks();
      default:
        return _help();
    }
  }

  /// A question phrased as general/definitional knowledge (norms, "how much
  /// should I…", "what is…") rather than a status check on the user's own data.
  /// Excludes clearly-personal phrasings ("my …") so "what's MY adherence" still
  /// routes to own data.
  static final RegExp _generalCue = RegExp(
    r"(what('?s| is| are| does)|how (much|many|long|do|does|can|should)|"
    r"why (do|does|is|are)|when (do|does|should)|tell me about|explain|"
    r"is it (normal|ok|okay|safe|bad|good|healthy)|what happens)",
    caseSensitive: false,
  );

  static bool _looksGeneral(String q) =>
      !q.contains('my ') && _generalCue.hasMatch(q);

  /// Applies the user's reply-tone preference. Never touches emergency cards or
  /// cited/verbatim KB answers (their wording is authoritative) — only softens
  /// or sharpens the app's own conversational replies.
  static AssistantReply _applyTone(AssistantReply r) {
    if (r.isEmergency || r.sources.isNotEmpty) return r;
    if (_memory.tone != AssistantTone.direct) return r; // conversational default
    var t = r.text
        .replaceFirst(
            RegExp(r'^(nice|got it|excellent|great|sure|okay|ok|noted|awesome)\s*[—\-,:]\s*',
                caseSensitive: false),
            '')
        .replaceAll('!', '.');
    if (t.isNotEmpty) t = t[0].toUpperCase() + t.substring(1);
    return AssistantReply(t,
        followups: r.followups, isEmergency: r.isEmergency, sources: r.sources);
  }

  // ===================== MEMORY COMMANDS =====================
  static const _memory = MemoryService();

  /// Recognizes explicit memory instructions and returns an inline reply, or
  /// null when [question] isn't a memory command (so normal routing continues).
  static Future<AssistantReply?> _memoryReply(String question) async {
    final cmd = MemoryCommand.parse(question);
    switch (cmd.type) {
      case MemoryCommandType.none:
        return null;

      case MemoryCommandType.recall:
        if (!_memory.enabled) {
          return const AssistantReply(
              "Memory is off right now, so I'm not keeping any notes. You can turn on “Use memory” in AI settings.");
        }
        final block = await _memory.contextBlock();
        if (block == null) {
          return const AssistantReply(
              "I haven't saved anything about you yet. Tell me something like “remember I prefer evening reminders” and I'll keep it.");
        }
        return AssistantReply("Here's what I remember about you:\n\n$block",
            followups: const ['Forget that', 'What can you do?']);

      case MemoryCommandType.forget:
        if (!_memory.enabled) {
          return const AssistantReply(
              "Memory is off, so there's nothing saved to forget.");
        }
        final result = await _memory.forgetByText(cmd.content!);
        switch (result) {
          case ForgetResult.removed:
            return const AssistantReply('Done — I\'ve forgotten that.');
          case ForgetResult.ambiguous:
            return const AssistantReply(
                'A few saved notes match that. Open Memory to remove the exact one, or tell me more specifically.',
                followups: ['What do you remember about me?']);
          case ForgetResult.notFound:
            return const AssistantReply(
                "I couldn't find a saved note matching that.");
        }

      case MemoryCommandType.forgetLast:
        final rows = await _memory.active();
        if (rows.isEmpty) {
          return const AssistantReply("There's nothing saved to forget.");
        }
        await _memory.forget(rows.first.id); // most recent
        return const AssistantReply('Done — I\'ve forgotten the last thing.');

      case MemoryCommandType.remember:
        if (!_memory.enabled) {
          return const AssistantReply(
              "I can't save that yet — memory is off. Turn on “Use memory” in AI settings and I'll remember things you tell me.");
        }
        final saved = await _memory.remember(cmd.content!, kind: cmd.kind);
        if (saved == null) return null;
        return AssistantReply(
            'Saved: “${saved.content}”. I\'ll keep that in mind.',
            followups: const ['What do you remember about me?']);
    }
  }

  // ===================== RAG (curated knowledge base) =====================
  /// Grounded answer from the on-device knowledge base: verbatim curated text +
  /// a Source citation + disclaimer. ABSTAINS to [_help] when nothing relevant
  /// is retrieved — it never guesses.
  static Future<AssistantReply> _rag(String question) async {
    try {
      final grounded = await AiAssistant().groundedAnswer(question);
      if (grounded == null || grounded.sources.isEmpty) return _help();
      final top = grounded.sources.first;
      return AssistantReply(
        grounded.text,
        followups: _ragFollowups(top.topic),
        engine: grounded.engine,
        topic: top.topic,
        sources: grounded.sources
            .map((c) => Citation(
                id: c.id, title: c.title, source: c.source, body: c.body))
            .toList(),
      );
    } catch (_) {
      return _help();
    }
  }

  static List<String> _ragFollowups(String topic) {
    switch (topic) {
      case 'cycle':
        return const ['When is my next period?', 'Am I in my fertile window?'];
      case 'hydration':
        return const ['Am I on track with water today?'];
      case 'sleep':
        return const ['How did I sleep?'];
      case 'activity':
        return const ['Am I hitting my step goal?'];
      case 'medication':
        return const ["What's my medication adherence?"];
      case 'vitals':
        return const [
          'Is my blood pressure trending up?',
          'Is my blood sugar okay?'
        ];
      default:
        return starters;
    }
  }

  /// Execute a natural-language logging command — actually WRITE the entry and
  /// confirm ("✓"), rather than telling the user to go do it themselves. The
  /// fully-specified captures (water/steps/BP/glucose/dose) are written directly;
  /// sleep/period still need extra input (exact times / flow), so those guide to
  /// the Log sheet. Every write goes through the same services the UI uses, so
  /// dashboards/Today refresh automatically via their notifiers.
  static Future<AssistantReply> _commandReply(ParsedCommand cmd) async {
    final now = DateTime.now();
    switch (cmd.kind) {
      case CommandKind.logBloodPressure:
        final s = cmd.data['systolic'] as int;
        final d = cmd.data['diastolic'] as int;
        final cat = VitalsAnalyzer.bpLabel(VitalsAnalyzer.classifyBp(s, d));
        await VitalsStorageService.saveBp(BloodPressureReading(
          id: 'bp_${now.microsecondsSinceEpoch}',
          systolic: s,
          diastolic: d,
          takenAt: now,
          createdAt: now,
        ));
        return AssistantReply('Logged BP $s/$d mmHg ($cat) ✓',
            followups: ['Is my blood pressure trending up?']);
      case CommandKind.logGlucose:
        final v = cmd.data['mgdl'] as int;
        await VitalsStorageService.saveGlucose(GlucoseReading(
          id: 'gl_${now.microsecondsSinceEpoch}',
          valueMgdl: v,
          takenAt: now,
          createdAt: now,
        ));
        return AssistantReply('Logged $v mg/dL ✓',
            followups: ['Is my blood sugar okay?']);
      case CommandKind.logWater:
        final ml = cmd.data['ml'] as int;
        final bev = WaterService.getBeverage('water') ??
            BeverageType.defaultBeverages.first;
        await WaterService.addWaterLog(amountMl: ml, beverage: bev);
        return AssistantReply('Logged ${ml}ml of water ✓',
            followups: ['Am I on track with water today?']);
      case CommandKind.takeMedicine:
        final doses = await TodayScheduleService.getTodaysDoses(now);
        final next = TodayScheduleService.nextDose(doses, now);
        if (next == null) {
          return const AssistantReply('You have no dose due right now.',
              followups: ["What's my medication adherence?"]);
        }
        await MedicineCleanStorageService.markMedicineTaken(
          medicineId: next.medicine.id,
          scheduledTime: next.scheduledTime,
        );
        return AssistantReply('Marked ${next.medicine.name} as taken ✓',
            followups: ["What's my medication adherence?"]);
      case CommandKind.logSteps:
        final s = cmd.data['steps'] as int;
        await StepService.addManualSteps(s);
        return AssistantReply('Logged $s steps ✓',
            followups: ['Am I hitting my step goal?']);
      case CommandKind.logSleep:
        final m = cmd.data['minutes'] as int?;
        // Sleep needs bed + wake times → guide to the Log sheet rather than guess.
        return AssistantReply(
            m != null
                ? 'Got it — about ${m ~/ 60}h ${m % 60}m. Tap ➕ Log → Sleep to save the exact times.'
                : 'Tap ➕ Log → Sleep to record last night.',
            followups: ['How did I sleep?']);
      case CommandKind.logPeriod:
        return const AssistantReply(
            "Tap ➕ Log → Period to record today's flow and symptoms.",
            followups: ['When is my next period?']);
      case CommandKind.none:
        return _help();
    }
  }

  static Future<AssistantReply> _medicine() async {
    try {
      final logs = await MedicineCleanStorageService.getAllLogs();
      final hist = logs
          .where((l) => l.isTaken || l.isMissed || l.isSkipped)
          .map((l) => DoseEvent(
              l.scheduledTime,
              l.isTaken
                  ? DoseOutcome.taken
                  : (l.isMissed ? DoseOutcome.missed : DoseOutcome.skipped)))
          .toList();
      if (hist.isEmpty) {
        return const AssistantReply(
            'I don\'t see any dose history yet. Once you start logging doses I can track your adherence.',
            followups: ['Am I on track with water today?']);
      }
      final adherence = (AdherenceAnalyzer.adherence(hist) * 100).round();
      final takenDays = logs
          .where((l) => l.isTaken)
          .map((l) =>
              DateTime(l.scheduledTime.year, l.scheduledTime.month, l.scheduledTime.day))
          .toSet();
      final streak = StreakEngine.compute(completedDays: takenDays, today: DateTime.now());
      final line = adherence >= 90
          ? 'Excellent — you\'ve taken about $adherence% of your scheduled doses.'
          : adherence >= 70
              ? 'You\'ve taken about $adherence% of your scheduled doses recently.'
              : 'Your adherence is around $adherence% lately — small routines (pairing doses with a meal) can help.';
      final streakLine =
          streak.current > 0 ? ' You\'re on a ${streak.current}-day streak.' : '';
      return AssistantReply(SafetyGuard.ensureDisclaimer('$line$streakLine'),
          followups: ['When will I run out of medicine?', 'What are my streaks?']);
    } catch (_) {
      return _help();
    }
  }

  static Future<AssistantReply> _refill() async {
    try {
      final meds = await MedicineCleanStorageService.getAllMedicines();
      final low = <String>[];
      for (final m in meds) {
        if (m.currentStock != null && m.isLowStock) low.add(m.name);
      }
      if (low.isEmpty) {
        return const AssistantReply(
            'No medicines are low on stock right now. I\'ll flag one when it\'s running out.',
            followups: ["What's my medication adherence?"]);
      }
      return AssistantReply(
          'Running low: ${low.join(', ')}. Reorder soon to avoid a gap.',
          followups: ["What's my medication adherence?"]);
    } catch (_) {
      return _help();
    }
  }

  static Future<AssistantReply> _water() async {
    try {
      final t = WaterService.getTodayData();
      final now = DateTime.now();
      final pace = HydrationPacer.compute(
          intakeMl: t.effectiveHydrationMl,
          goalMl: t.dailyGoalMl,
          nowMinutes: now.hour * 60 + now.minute);
      final pct = t.dailyGoalMl > 0
          ? (t.effectiveHydrationMl / t.dailyGoalMl * 100).round()
          : 0;
      final line = t.effectiveHydrationMl >= t.dailyGoalMl
          ? 'You\'ve hit your ${t.dailyGoalMl}ml goal today — nice.'
          : pace.behind
              ? 'You\'re about ${pace.deficitMl}ml behind pace ($pct% of your ${t.dailyGoalMl}ml goal). A drink now catches you up.'
              : 'You\'re on pace — $pct% of your ${t.dailyGoalMl}ml goal so far.';
      return AssistantReply(line,
          followups: ['What are my streaks?', 'When do I focus best?']);
    } catch (_) {
      return _help();
    }
  }

  static Future<AssistantReply> _bp() async {
    try {
      final bp = await VitalsStorageService.getAllBp();
      if (bp.isEmpty) {
        return const AssistantReply(
            'You haven\'t logged any blood-pressure readings yet.',
            followups: ['Is my blood sugar okay?']);
      }
      final latest = bp.first;
      final cat = VitalsAnalyzer.bpLabel(latest.category);
      final patterns = VitalsPatternDetector.analyzeBp(bp
          .map((r) => BpPoint(at: r.takenAt, systolic: r.systolic, diastolic: r.diastolic))
          .toList());
      final trend = patterns.isNotEmpty ? ' ${patterns.first.detail}' : '';
      return AssistantReply(
          SafetyGuard.ensureDisclaimer(
              'Your latest reading was ${latest.systolic}/${latest.diastolic} ($cat).$trend'),
          followups: ["What's my medication adherence?", 'Is my blood sugar okay?']);
    } catch (_) {
      return _help();
    }
  }

  static Future<AssistantReply> _glucose() async {
    try {
      final gl = await VitalsStorageService.getAllGlucose();
      if (gl.isEmpty) {
        return const AssistantReply(
            'You haven\'t logged any blood-sugar readings yet.',
            followups: ['Is my blood pressure trending up?']);
      }
      final vals = gl.map((r) => r.valueMgdl).toList();
      final eA1c = VitalsAnalyzer.estimatedA1c(vals);
      final inRange = VitalsAnalyzer.inRangePercent(
          gl.map((r) => (mgdl: r.valueMgdl, ctx: r.context)).toList());
      final parts = <String>[];
      if (inRange != null) parts.add('${(inRange * 100).round()}% of readings are in range');
      if (eA1c != null) parts.add('estimated A1C about ${eA1c.toStringAsFixed(1)}% (an estimate, not a lab result)');
      final body = parts.isEmpty
          ? 'Your latest reading was ${gl.first.valueMgdl} mg/dL.'
          : 'Recently, ${parts.join(', and ')}.';
      return AssistantReply(SafetyGuard.ensureDisclaimer(body),
          followups: ['Is my blood pressure trending up?', "What's my medication adherence?"]);
    } catch (_) {
      return _help();
    }
  }

  static Future<AssistantReply> _focus() async {
    try {
      final fs = FocusService();
      final refs = fs.sessions
          .map((s) => FocusSessionRef(
              startHour: s.startedAt.hour, minutes: s.actualMinutes, completed: s.wasCompleted))
          .toList();
      final best = FocusInsights.bestFocusHour(refs);
      if (best == null) {
        return AssistantReply(
            'Log a few more focus sessions and I\'ll tell you your best focus window. Today: ${fs.todayMinutes} min.',
            followups: ['What are my streaks?']);
      }
      return AssistantReply(
          'You focus most around ${FocusInsights.hourLabel(best)}. Protect that window for deep work. Today: ${fs.todayMinutes} min.',
          followups: ['What are my streaks?', 'Am I on track with water today?']);
    } catch (_) {
      return _help();
    }
  }

  static Future<AssistantReply> _period() async {
    try {
      final p = PeriodService.getPrediction();
      final stats = PeriodService.getStats();
      final avg = stats.medianCycleLength ?? stats.avgCycleLength?.round();
      final avgLine = avg != null ? ' Your average cycle is about $avg days.' : '';
      String body;
      switch (p.state) {
        case CycleState.onboarding:
          body =
              'You haven\'t logged a period yet. Log your first period start and I\'ll learn your rhythm and predict the next one.';
          break;
        case CycleState.learning:
          body =
              'I\'m still learning your cycle — log a couple more periods and I can predict your next one with confidence.';
          break;
        case CycleState.pregnancy:
          body =
              'Pregnancy mode is on, so cycle predictions are paused. You can still log symptoms.';
          break;
        case CycleState.late:
          body =
              'Your period is past its estimated date. Cycles naturally vary — log any flow to update the prediction. (This is not a diagnosis.)';
          break;
        case CycleState.ready:
        case CycleState.irregular:
          final d = p.daysUntilNextPeriod;
          if (d != null && d >= 0) {
            body = d == 0
                ? 'Your period is estimated to start today.$avgLine'
                : 'Your next period is estimated in about $d day${d == 1 ? '' : 's'}.$avgLine';
          } else {
            body = 'I have your cycle history.$avgLine';
          }
          if (p.state == CycleState.irregular) {
            body += ' Your cycles vary a lot, so treat this as a rough estimate.';
          }
          break;
      }
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (p.fertileStart != null &&
          p.fertileEnd != null &&
          !today.isBefore(p.fertileStart!) &&
          !today.isAfter(p.fertileEnd!)) {
        body +=
            ' You may be in your estimated fertile window — a calendar estimate, not reliable for contraception.';
      }
      return AssistantReply(SafetyGuard.ensureDisclaimer(body),
          followups: ['Am I in my fertile window?', 'What are my streaks?']);
    } catch (_) {
      return _help();
    }
  }

  static Future<AssistantReply> _steps() async {
    try {
      final t = StepService.getTodayData();
      final streak = StepService.getCurrentStreak();
      final pct =
          t.goalSteps > 0 ? (t.effectiveSteps / t.goalSteps * 100).round() : 0;
      final streakLine = streak > 0 ? ' You\'re on a $streak-day goal streak.' : '';
      final body = (t.goalSteps > 0 && t.effectiveSteps >= t.goalSteps)
          ? 'You\'ve hit your ${t.goalSteps}-step goal today (${t.effectiveSteps} steps).$streakLine'
          : t.effectiveSteps == 0
              ? 'No steps logged yet today. Your goal is ${t.goalSteps} steps.'
              : 'You\'re at $pct% of your ${t.goalSteps}-step goal (${t.effectiveSteps} steps so far).$streakLine';
      return AssistantReply(body,
          followups: ['How did I sleep?', 'What are my streaks?']);
    } catch (_) {
      return _help();
    }
  }

  static Future<AssistantReply> _sleep() async {
    try {
      final last = SleepService.getLastNight();
      if (last == null) {
        return const AssistantReply(
            'You haven\'t logged any sleep yet. Log last night and I\'ll show your duration, score and consistency.',
            followups: ['Am I hitting my step goal?']);
      }
      final target = SleepService.getSchedule().targetMinutes;
      final debt = SleepService.sleepDebtMinutes();
      final dur = '${last.asleepMinutes ~/ 60}h ${last.asleepMinutes % 60}m';
      final parts = <String>['Last night you slept $dur (score ${last.sleepScore})'];
      if (last.asleepMinutes >= target) {
        parts.add('you hit your target');
      } else {
        parts.add(
            'about ${((target - last.asleepMinutes) / 60).toStringAsFixed(1)}h under target');
      }
      if (debt >= 120) {
        parts.add('~${(debt / 60).round()}h under your sleep target this week');
      } else if (debt <= -120) {
        parts.add('~${(-debt / 60).round()}h over your target this week');
      }
      return AssistantReply('${parts.join(' — ')}.',
          followups: ['Am I hitting my step goal?', 'What are my streaks?']);
    } catch (_) {
      return _help();
    }
  }

  static Future<AssistantReply> _streaks() async {
    final parts = <String>[];
    try {
      final f = FocusService().stats.currentStreak;
      if (f > 0) parts.add('$f-day focus streak');
    } catch (_) {}
    try {
      final w = WaterService.getCurrentStreak();
      if (w > 0) parts.add('$w-day hydration streak');
    } catch (_) {}
    try {
      final s = StepService.getCurrentStreak();
      if (s > 0) parts.add('$s-day step streak');
    } catch (_) {}
    try {
      final logs = await MedicineCleanStorageService.getAllLogs();
      final days = logs
          .where((l) => l.isTaken)
          .map((l) => DateTime(l.scheduledTime.year, l.scheduledTime.month, l.scheduledTime.day))
          .toSet();
      final s = StreakEngine.compute(completedDays: days, today: DateTime.now()).current;
      if (s > 0) parts.add('$s-day medication streak');
    } catch (_) {}
    if (parts.isEmpty) {
      return const AssistantReply(
          'No active streaks yet — complete a dose, a focus session, or hit your water goal to start one.');
    }
    return AssistantReply('You\'ve got a ${parts.join(', a ')}. Keep it going!');
  }

  static AssistantReply _help() {
    return const AssistantReply(
      'I can answer from your own data — medication, refills, water, blood pressure, blood sugar, your cycle, steps, sleep, focus, and streaks. Try one of these:',
      followups: starters,
    );
  }
}
