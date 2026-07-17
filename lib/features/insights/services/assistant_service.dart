import '../../../core/ai/ai_types.dart';
import '../../../core/ai/rule_based_engine.dart';
import '../../../core/ai/safety_guard.dart';
import '../../../core/ai/vitals_analyzer.dart';
import '../../../core/ai/vitals_pattern_detector.dart';
import '../../../core/ai/adherence_analyzer.dart';
import '../../../core/ai/streak_engine.dart';
import '../../../core/ai/hydration_pacer.dart';
import '../../../core/ai/focus_insights.dart';
import '../../medication/services/medicine_storage_service.dart';
import '../../medication/services/vitals_storage_service.dart';
import '../../water/services/water_service.dart';
import '../../focus/services/focus_service.dart';

/// One assistant answer.
class AssistantReply {
  final String text;
  final List<String> followups;
  final bool isEmergency;
  const AssistantReply(this.text,
      {this.followups = const [], this.isEmergency = false});
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
    'Is my blood pressure trending up?',
    'Am I on track with water today?',
    'When do I focus best?',
    'What are my streaks?',
  ];

  static Future<AssistantReply> answer(String question) async {
    final emergency = SafetyGuard.emergencyResponse(question);
    if (emergency != null) return AssistantReply(emergency, isEmergency: true);

    // Natural-language logging command? Recognize + guide to save (no silent write).
    final cmd = const RuleBasedEngine().parseCommand(question);
    if (!cmd.isNone) return _commandReply(cmd);

    final q = question.toLowerCase();
    if (_has(q, ['adherence', 'dose', 'missed', 'medication', 'my meds', 'pills'])) {
      return _medicine();
    }
    if (_has(q, ['refill', 'stock', 'supply', 'run out', 'reorder'])) return _refill();
    if (_has(q, ['water', 'hydrat', 'drink'])) return _water();
    if (_has(q, ['blood pressure', 'bp', 'systolic', 'diastolic'])) return _bp();
    if (_has(q, ['blood sugar', 'glucose', 'sugar', 'a1c'])) return _glucose();
    if (_has(q, ['focus', 'concentrat', 'deep work', 'pomodoro'])) return _focus();
    if (_has(q, ['streak'])) return _streaks();
    return _help();
  }

  static bool _has(String q, List<String> keys) => keys.any(q.contains);

  static AssistantReply _commandReply(ParsedCommand cmd) {
    switch (cmd.kind) {
      case CommandKind.logBloodPressure:
        final s = cmd.data['systolic'] as int;
        final d = cmd.data['diastolic'] as int;
        final cat = VitalsAnalyzer.bpLabel(VitalsAnalyzer.classifyBp(s, d));
        return AssistantReply(
            'That reads as $s/$d mmHg ($cat). Open Blood Pressure to save it.',
            followups: ['Is my blood pressure trending up?']);
      case CommandKind.logGlucose:
        final v = cmd.data['mgdl'] as int;
        return AssistantReply('Noted $v mg/dL. Open Blood Sugar to save it.',
            followups: ['Is my blood sugar okay?']);
      case CommandKind.logWater:
        final ml = cmd.data['ml'] as int;
        return AssistantReply('Noted ${ml}ml of water. Open Water to log it.',
            followups: ['Am I on track with water today?']);
      case CommandKind.takeMedicine:
        return const AssistantReply(
            'Nice — open Medicine to mark your dose as taken.',
            followups: ["What's my medication adherence?"]);
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
      'I can answer from your own data — medication adherence, refills, water, blood pressure, blood sugar, focus, and streaks. Try one of these:',
      followups: starters,
    );
  }
}
