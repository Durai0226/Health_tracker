/// Solution Steps Model - Structured step-by-step problem solving explanations
/// Used for teaching users how to think through and simplify exam problems

class SolutionSteps {
  final String approach;
  final List<String> steps;
  final String? commonMistake;
  final String? proTip;

  const SolutionSteps({
    required this.approach,
    required this.steps,
    this.commonMistake,
    this.proTip,
  });

  factory SolutionSteps.fromJson(Map<String, dynamic> json) {
    return SolutionSteps(
      approach: json['approach'] ?? '',
      steps: List<String>.from(json['steps'] ?? []),
      commonMistake: json['commonMistake'],
      proTip: json['proTip'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'approach': approach,
      'steps': steps,
      if (commonMistake != null) 'commonMistake': commonMistake,
      if (proTip != null) 'proTip': proTip,
    };
  }

  SolutionSteps copyWith({
    String? approach,
    List<String>? steps,
    String? commonMistake,
    String? proTip,
  }) {
    return SolutionSteps(
      approach: approach ?? this.approach,
      steps: steps ?? this.steps,
      commonMistake: commonMistake ?? this.commonMistake,
      proTip: proTip ?? this.proTip,
    );
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('Approach: $approach');
    buffer.writeln('Steps:');
    for (int i = 0; i < steps.length; i++) {
      buffer.writeln('  ${i + 1}. ${steps[i]}');
    }
    if (commonMistake != null) {
      buffer.writeln('Common Mistake: $commonMistake');
    }
    if (proTip != null) {
      buffer.writeln('Pro Tip: $proTip');
    }
    return buffer.toString();
  }
}
