/// JEE & NEET Exam Question Templates
/// JEE Main/Advanced, NEET - Realistic exam pattern questions

import 'dart:math';
import '../../models/problem_solving_approach.dart';
import '../../models/solution_steps.dart';

class JEEQuestionTemplates {
  static final _random = Random();

  // ==================== PHYSICS ====================

  /// Generate Mechanics questions
  static List<EnhancedQuestion> generateMechanics(int count) {
    final questions = <EnhancedQuestion>[];
    
    for (int i = 0; i < count; i++) {
      final type = i % 6;
      String question;
      String answer;
      String explanation;
      List<String> options;
      
      switch (type) {
        case 0: // Kinematics - projectile
          final u = (_random.nextInt(5) + 2) * 10;
          final angle = 30;
          final range = (u * u * 0.866 / 10).round(); // R = u²sin2θ/g
          question = 'A projectile is thrown with velocity $u m/s at angle 30° to horizontal. Find its range. (g = 10 m/s²)';
          answer = '$range m';
          explanation = 'Range R = u²sin2θ/g = $u² × sin60° / 10 = $range m';
          options = [answer, '${range + 10} m', '${range - 5} m', '${range * 2} m'];
          break;
        case 1: // Newton's Laws
          final m = _random.nextInt(5) + 2;
          final a = _random.nextInt(5) + 2;
          final f = m * a;
          question = 'A body of mass $m kg is accelerating at $a m/s². Find the net force acting on it.';
          answer = '$f N';
          explanation = 'F = ma = $m × $a = $f N';
          options = [answer, '${f + 5} N', '${f - 3} N', '${m + a} N'];
          break;
        case 2: // Work-Energy
          final m = _random.nextInt(4) + 2;
          final v = (_random.nextInt(5) + 2) * 2;
          final ke = (m * v * v / 2).round();
          question = 'A body of mass $m kg is moving with velocity $v m/s. Find its kinetic energy.';
          answer = '$ke J';
          explanation = 'KE = ½mv² = ½ × $m × $v² = $ke J';
          options = [answer, '${ke * 2} J', '${ke ~/ 2} J', '${m * v} J'];
          break;
        case 3: // Circular Motion
          final v = (_random.nextInt(5) + 2) * 2;
          final r = _random.nextInt(5) + 2;
          final ac = (v * v / r).round();
          question = 'A particle moves in a circle of radius $r m with speed $v m/s. Find centripetal acceleration.';
          answer = '$ac m/s²';
          explanation = 'ac = v²/r = $v²/$r = $ac m/s²';
          options = [answer, '${ac + 5} m/s²', '${v * r} m/s²', '${v + r} m/s²'];
          break;
        case 4: // Gravitation
          final h = _random.nextInt(3) + 1;
          final gRatio = 1 / ((1 + h) * (1 + h));
          question = 'At height equal to ${h}R from Earth\'s surface, the acceleration due to gravity is (R = Earth\'s radius):';
          answer = 'g/${(1 + h) * (1 + h)}';
          explanation = 'g\' = g/(1 + h/R)² = g/${(1 + h) * (1 + h)} when h = ${h}R';
          options = [answer, 'g/${1 + h}', 'g × ${1 + h}', 'g/${h * h}'];
          break;
        default: // Momentum
          final m1 = _random.nextInt(5) + 2;
          final m2 = _random.nextInt(5) + 2;
          final v1 = _random.nextInt(10) + 5;
          final vFinal = (m1 * v1) ~/ (m1 + m2);
          question = 'A body of mass $m1 kg moving at $v1 m/s collides with a stationary body of mass $m2 kg. If they stick together, find their common velocity.';
          answer = '$vFinal m/s';
          explanation = 'By conservation of momentum: m₁v₁ = (m₁+m₂)v. v = $m1 × $v1 / ($m1 + $m2) = $vFinal m/s';
          options = [answer, '${vFinal + 2} m/s', '${v1} m/s', '${vFinal * 2} m/s'];
      }
      
      options = options.toSet().toList();
      while (options.length < 4) {
        options.add('${_random.nextInt(50) + 10} units');
      }
      options.shuffle();
      
      questions.add(EnhancedQuestion(
        id: 'jee_mech_${i + 1}',
        examType: 'jee',
        subject: 'Physics',
        topic: 'Mechanics',
        question: question,
        options: options,
        correctOptionIndex: options.indexOf(answer),
        explanation: explanation,
        approach: const ProblemSolvingApproach(
          questionType: 'Mechanics',
          conceptRequired: 'Newton\'s Laws, Energy, Momentum, Circular Motion',
          howToRecognize: 'Motion, force, velocity, acceleration keywords',
          thinkingProcess: [
            'Step 1: Identify the physical situation',
            'Step 2: Draw free body diagram if needed',
            'Step 3: Apply relevant principle (F=ma, energy conservation, momentum)',
            'Step 4: Solve the equation',
          ],
          whatToLookFor: 'Given quantities, what to find, constraints',
          commonPatterns: [
            'F = ma', 'KE = ½mv²', 'PE = mgh',
            'p = mv', 'ac = v²/r'
          ],
          timeManagement: 'Spend 2-3 minutes. Draw diagrams.',
          avoidMistakes: [
            'Check units consistency',
            'Don\'t forget negative signs for directions',
            'Use correct formula for the situation',
          ],
        ),
        difficulty: 'medium',
        marks: 4,
        negativeMarks: 1,
        timeInSeconds: 180,
        tags: ['mechanics', 'physics', 'jee', 'kinematics'],
      ));
    }
    
    return questions;
  }

  /// Generate Electromagnetism questions
  static List<EnhancedQuestion> generateElectromagnetism(int count) {
    final questions = <EnhancedQuestion>[];
    
    for (int i = 0; i < count; i++) {
      final type = i % 5;
      String question;
      String answer;
      String explanation;
      List<String> options;
      
      switch (type) {
        case 0: // Coulomb's Law
          final q1 = _random.nextInt(3) + 1;
          final q2 = _random.nextInt(3) + 1;
          final r = _random.nextInt(3) + 1;
          final f = (9 * q1 * q2) ~/ (r * r);
          question = 'Two charges ${q1}μC and ${q2}μC are $r m apart. Find the force between them. (k = 9×10⁹)';
          answer = '${f} × 10⁻³ N';
          explanation = 'F = kq₁q₂/r² = 9×10⁹ × ${q1}×10⁻⁶ × ${q2}×10⁻⁶ / $r² = ${f}×10⁻³ N';
          options = [answer, '${f * 2} × 10⁻³ N', '${f} × 10⁻⁶ N', '${f ~/ 2} × 10⁻³ N'];
          break;
        case 1: // Ohm's Law
          final v = (_random.nextInt(10) + 1) * 10;
          final r = _random.nextInt(10) + 2;
          final i = v ~/ r;
          question = 'A resistor of $r Ω is connected to $v V supply. Find the current.';
          answer = '$i A';
          explanation = 'I = V/R = $v/$r = $i A';
          options = [answer, '${i + 2} A', '${v * r} A', '${i ~/ 2} A'];
          break;
        case 2: // Capacitance
          final c1 = _random.nextInt(5) + 2;
          final c2 = _random.nextInt(5) + 2;
          final cSeries = (c1 * c2) / (c1 + c2);
          question = 'Two capacitors ${c1}μF and ${c2}μF are in series. Find equivalent capacitance.';
          answer = '${cSeries.toStringAsFixed(2)} μF';
          explanation = '1/C = 1/$c1 + 1/$c2 = ${c1 + c2}/${c1 * c2}. C = ${cSeries.toStringAsFixed(2)} μF';
          options = [answer, '${c1 + c2} μF', '${c1 * c2} μF', '${(c1 + c2) / 2} μF'];
          break;
        case 3: // Magnetic Field
          final i = _random.nextInt(5) + 1;
          final r = _random.nextInt(10) + 5;
          question = 'A current of $i A flows through a circular coil of radius $r cm. Find magnetic field at center. (μ₀ = 4π×10⁻⁷)';
          answer = '2π × $i / $r × 10⁻⁵ T';
          explanation = 'B = μ₀I/2r = 4π×10⁻⁷ × $i / (2 × ${r/100}) T';
          options = [answer, 'π × $i / $r × 10⁻⁵ T', '4π × $i / $r × 10⁻⁵ T', '$i × $r × 10⁻⁵ T'];
          break;
        default: // EMF
          final n = (_random.nextInt(5) + 1) * 100;
          final dPhi = _random.nextInt(5) + 1;
          final dt = _random.nextInt(5) + 1;
          final emf = (n * dPhi) ~/ dt;
          question = 'A coil of $n turns experiences change in flux of $dPhi Wb in $dt seconds. Find induced EMF.';
          answer = '$emf V';
          explanation = 'EMF = -N(dΦ/dt) = $n × $dPhi / $dt = $emf V';
          options = [answer, '${emf * 2} V', '${emf ~/ n} V', '${n + dPhi} V'];
      }
      
      options = options.toSet().toList();
      while (options.length < 4) {
        options.add('${_random.nextInt(20) + 1} units');
      }
      options.shuffle();
      
      questions.add(EnhancedQuestion(
        id: 'jee_em_${i + 1}',
        examType: 'jee',
        subject: 'Physics',
        topic: 'Electromagnetism',
        question: question,
        options: options,
        correctOptionIndex: options.indexOf(answer),
        explanation: explanation,
        difficulty: 'medium',
        marks: 4,
        negativeMarks: 1,
        timeInSeconds: 180,
        tags: ['electromagnetism', 'physics', 'jee'],
      ));
    }
    
    return questions;
  }

  // ==================== CHEMISTRY ====================

  /// Generate Organic Chemistry questions
  static List<EnhancedQuestion> generateOrganicChemistry(int count) {
    final questions = <EnhancedQuestion>[];
    
    final reactions = [
      ('Ethene + HBr →', 'Ethyl bromide', ['Ethyl bromide', 'Methyl bromide', 'Vinyl bromide', 'Propyl bromide'], 'Markovnikov addition'),
      ('Ethanol + Na →', 'Sodium ethoxide + H₂', ['Sodium ethoxide + H₂', 'Ethene + H₂O', 'Acetaldehyde', 'Acetic acid'], 'Reaction with active metal'),
      ('CH₃CHO + HCN →', 'Cyanohydrin', ['Cyanohydrin', 'Alcohol', 'Aldol', 'Acetal'], 'Nucleophilic addition'),
      ('Phenol + Br₂/H₂O →', '2,4,6-tribromophenol', ['2,4,6-tribromophenol', 'Bromobenzene', 'o-bromophenol', 'Benzene'], 'Electrophilic substitution'),
      ('Benzene + CH₃Cl/AlCl₃ →', 'Toluene', ['Toluene', 'Chlorobenzene', 'Benzyl chloride', 'Xylene'], 'Friedel-Crafts alkylation'),
    ];
    
    for (int i = 0; i < count; i++) {
      final data = reactions[i % reactions.length];
      final options = List<String>.from(data.$3);
      options.shuffle();
      
      questions.add(EnhancedQuestion(
        id: 'jee_org_${i + 1}',
        examType: 'jee',
        subject: 'Chemistry',
        topic: 'Organic Chemistry',
        question: 'What is the product of: ${data.$1}',
        options: options,
        correctOptionIndex: options.indexOf(data.$2),
        explanation: '${data.$4}: ${data.$1} gives ${data.$2}',
        approach: const ProblemSolvingApproach(
          questionType: 'Organic Reactions',
          conceptRequired: 'Reaction mechanisms, functional groups',
          howToRecognize: 'Organic compounds, arrows, reagents',
          thinkingProcess: [
            'Step 1: Identify the functional group',
            'Step 2: Identify the reagent and conditions',
            'Step 3: Apply the appropriate mechanism',
            'Step 4: Predict the product',
          ],
          whatToLookFor: 'Functional group, reagent, conditions',
          commonPatterns: [
            'Addition reactions (alkenes)',
            'Substitution (benzene, haloalkanes)',
            'Elimination reactions',
            'Oxidation/Reduction',
          ],
          timeManagement: 'Spend 1-2 minutes. Know named reactions.',
          avoidMistakes: [
            'Check for Markovnikov/Anti-Markovnikov',
            'Remember stereochemistry when applicable',
            'Don\'t confuse similar reagents',
          ],
        ),
        difficulty: 'medium',
        marks: 4,
        negativeMarks: 1,
        timeInSeconds: 120,
        tags: ['organic', 'chemistry', 'jee', 'reactions'],
      ));
    }
    
    return questions;
  }

  /// Generate Physical Chemistry questions
  static List<EnhancedQuestion> generatePhysicalChemistry(int count) {
    final questions = <EnhancedQuestion>[];
    
    for (int i = 0; i < count; i++) {
      final type = i % 4;
      String question;
      String answer;
      String explanation;
      List<String> options;
      
      switch (type) {
        case 0: // Mole concept
          final mass = (_random.nextInt(5) + 1) * 10;
          final molMass = 44; // CO2
          final moles = mass / molMass;
          question = 'Calculate the number of moles in $mass g of CO₂. (Molar mass = 44 g/mol)';
          answer = '${moles.toStringAsFixed(2)} mol';
          explanation = 'n = mass/M = $mass/44 = ${moles.toStringAsFixed(2)} mol';
          options = [answer, '${(moles * 2).toStringAsFixed(2)} mol', '${(moles / 2).toStringAsFixed(2)} mol', '$mass mol'];
          break;
        case 1: // Gas Laws
          final v1 = (_random.nextInt(5) + 1) * 2;
          final t1 = 273;
          final t2 = 546;
          final v2 = v1 * t2 ~/ t1;
          question = 'A gas occupies $v1 L at 273 K. What is its volume at 546 K at constant pressure?';
          answer = '$v2 L';
          explanation = 'V₁/T₁ = V₂/T₂. V₂ = $v1 × 546/273 = $v2 L';
          options = [answer, '${v1} L', '${v2 ~/ 2} L', '${v2 * 2} L'];
          break;
        case 2: // Electrochemistry
          final n = _random.nextInt(3) + 1;
          final current = _random.nextInt(5) + 1;
          final time = 1930; // approx 1 Faraday
          question = 'How much metal is deposited when $current A current flows for 1930 seconds? (Equivalent weight = 32)';
          answer = '${(32 * current * time / 96500).toStringAsFixed(2)} g';
          explanation = 'W = EIt/96500 = 32 × $current × $time / 96500 g';
          options = [answer, '32 g', '${current * 32} g', '${current} g'];
          break;
        default: // Thermodynamics
          final q = (_random.nextInt(5) + 1) * 100;
          final w = (_random.nextInt(3) + 1) * 50;
          final deltaU = q - w;
          question = 'A system absorbs $q J of heat and does $w J of work. Find ΔU.';
          answer = '$deltaU J';
          explanation = 'ΔU = q - w = $q - $w = $deltaU J';
          options = [answer, '${q + w} J', '${q} J', '${w} J'];
      }
      
      options = options.toSet().toList();
      while (options.length < 4) {
        options.add('${_random.nextInt(100)} units');
      }
      options.shuffle();
      
      questions.add(EnhancedQuestion(
        id: 'jee_pc_${i + 1}',
        examType: 'jee',
        subject: 'Chemistry',
        topic: 'Physical Chemistry',
        question: question,
        options: options,
        correctOptionIndex: options.indexOf(answer),
        explanation: explanation,
        difficulty: 'medium',
        marks: 4,
        negativeMarks: 1,
        timeInSeconds: 150,
        tags: ['physical-chemistry', 'chemistry', 'jee'],
      ));
    }
    
    return questions;
  }

  // ==================== MATHEMATICS ====================

  /// Generate Calculus questions
  static List<EnhancedQuestion> generateCalculus(int count) {
    final questions = <EnhancedQuestion>[];
    
    for (int i = 0; i < count; i++) {
      final type = i % 5;
      String question;
      String answer;
      String explanation;
      List<String> options;
      
      switch (type) {
        case 0: // Differentiation
          final n = _random.nextInt(5) + 2;
          question = 'Find dy/dx if y = x^$n';
          answer = '${n}x^${n - 1}';
          explanation = 'd/dx(xⁿ) = nxⁿ⁻¹. So d/dx(x^$n) = ${n}x^${n - 1}';
          options = [answer, 'x^${n - 1}', '${n}x^$n', '${n - 1}x^${n - 2}'];
          break;
        case 1: // Integration
          final n = _random.nextInt(4) + 1;
          final coeff = n + 1;
          question = '∫x^$n dx = ?';
          answer = 'x^$coeff/$coeff + C';
          explanation = '∫xⁿdx = xⁿ⁺¹/(n+1) + C = x^$coeff/$coeff + C';
          options = [answer, 'x^$n/$n + C', '$coeff × x^$coeff + C', 'x^${n - 1}/${n - 1} + C'];
          break;
        case 2: // Limits
          question = 'lim(x→0) sin(x)/x = ?';
          answer = '1';
          explanation = 'This is a standard limit. lim(x→0) sin(x)/x = 1';
          options = ['1', '0', '∞', '-1'];
          break;
        case 3: // Maxima/Minima
          final a = _random.nextInt(3) + 1;
          final b = _random.nextInt(5) + 2;
          question = 'Find the minimum value of f(x) = x² - ${2 * a}x + $b';
          answer = '${b - a * a}';
          explanation = 'f\'(x) = 2x - ${2 * a} = 0 at x = $a. f($a) = ${a * a} - ${2 * a * a} + $b = ${b - a * a}';
          options = [answer, '$a', '$b', '${b + a * a}'];
          break;
        default: // Definite integral
          question = '∫₀^(π/2) cos(x) dx = ?';
          answer = '1';
          explanation = '∫cos(x)dx = sin(x). [sin(x)]₀^(π/2) = sin(π/2) - sin(0) = 1 - 0 = 1';
          options = ['1', '0', 'π/2', '-1'];
      }
      
      options = options.toSet().toList();
      while (options.length < 4) {
        options.add('${_random.nextInt(10)}');
      }
      options.shuffle();
      
      questions.add(EnhancedQuestion(
        id: 'jee_calc_${i + 1}',
        examType: 'jee',
        subject: 'Mathematics',
        topic: 'Calculus',
        question: question,
        options: options,
        correctOptionIndex: options.indexOf(answer),
        explanation: explanation,
        approach: const ProblemSolvingApproach(
          questionType: 'Calculus',
          conceptRequired: 'Differentiation, Integration, Limits',
          howToRecognize: 'd/dx, ∫, lim, derivative, integral',
          thinkingProcess: [
            'Step 1: Identify operation (diff/int/limit)',
            'Step 2: Recall the appropriate formula',
            'Step 3: Apply step by step',
            'Step 4: Simplify and verify',
          ],
          whatToLookFor: 'Function type, operation type, limits if any',
          commonPatterns: [
            'd/dx(xⁿ) = nxⁿ⁻¹',
            '∫xⁿdx = xⁿ⁺¹/(n+1) + C',
            'd/dx(sin x) = cos x',
            '∫cos x dx = sin x + C',
          ],
          timeManagement: 'Spend 2-3 minutes. Know standard results.',
          avoidMistakes: [
            'Don\'t forget +C in indefinite integrals',
            'Apply chain rule correctly',
            'Check limits of integration',
          ],
        ),
        difficulty: 'medium',
        marks: 4,
        negativeMarks: 1,
        timeInSeconds: 180,
        tags: ['calculus', 'mathematics', 'jee'],
      ));
    }
    
    return questions;
  }

  /// Generate all JEE questions
  static List<EnhancedQuestion> generateAllQuestions() {
    return [
      ...generateMechanics(600),
      ...generateElectromagnetism(500),
      ...generateOrganicChemistry(500),
      ...generatePhysicalChemistry(500),
      ...generateCalculus(600),
    ];
  }

  static int get totalQuestionCount => 2700;
}

// ==================== NEET SPECIFIC ====================

class NEETQuestionTemplates {
  static final _random = Random();

  /// Generate Biology questions
  static List<EnhancedQuestion> generateBiology(int count) {
    final questions = <EnhancedQuestion>[];
    
    final biologyQA = [
      ('What is the powerhouse of the cell?', 'Mitochondria', ['Mitochondria', 'Nucleus', 'Ribosome', 'Golgi body'], 'Mitochondria produces ATP through cellular respiration'),
      ('Which blood cells are involved in immunity?', 'White Blood Cells', ['White Blood Cells', 'Red Blood Cells', 'Platelets', 'Plasma'], 'WBCs (Leukocytes) are part of the immune system'),
      ('DNA replication occurs in which phase?', 'S phase', ['S phase', 'G1 phase', 'G2 phase', 'M phase'], 'S (Synthesis) phase is when DNA replicates'),
      ('Which hormone regulates blood sugar?', 'Insulin', ['Insulin', 'Glucagon', 'Thyroxine', 'Adrenaline'], 'Insulin lowers blood glucose by promoting uptake'),
      ('Photosynthesis occurs in which organelle?', 'Chloroplast', ['Chloroplast', 'Mitochondria', 'Nucleus', 'Vacuole'], 'Chloroplasts contain chlorophyll for photosynthesis'),
      ('What is the functional unit of kidney?', 'Nephron', ['Nephron', 'Neuron', 'Glomerulus', 'Bowman\'s capsule'], 'Nephron filters blood and produces urine'),
      ('Which vitamin deficiency causes scurvy?', 'Vitamin C', ['Vitamin C', 'Vitamin D', 'Vitamin B12', 'Vitamin A'], 'Scurvy is caused by lack of ascorbic acid (Vit C)'),
      ('Mendel\'s law of segregation is also known as?', 'Law of purity of gametes', ['Law of purity of gametes', 'Law of dominance', 'Law of independent assortment', 'Law of inheritance'], 'Alleles segregate during gamete formation'),
    ];
    
    for (int i = 0; i < count; i++) {
      final data = biologyQA[i % biologyQA.length];
      final options = List<String>.from(data.$3);
      options.shuffle();
      
      questions.add(EnhancedQuestion(
        id: 'neet_bio_${i + 1}',
        examType: 'neet',
        subject: 'Biology',
        topic: 'General Biology',
        question: data.$1,
        options: options,
        correctOptionIndex: options.indexOf(data.$2),
        explanation: data.$4,
        approach: const ProblemSolvingApproach(
          questionType: 'Biology Concepts',
          conceptRequired: 'Cell biology, Physiology, Genetics',
          howToRecognize: 'Questions about living organisms, body functions',
          thinkingProcess: [
            'Step 1: Identify the topic area',
            'Step 2: Recall the relevant concept',
            'Step 3: Eliminate obviously wrong options',
            'Step 4: Choose the most accurate answer',
          ],
          whatToLookFor: 'Key biological terms, organ systems, processes',
          commonPatterns: [
            'Cell organelles and functions',
            'Body systems and hormones',
            'Genetics and inheritance',
            'Plant and animal physiology',
          ],
          timeManagement: 'Spend 40-60 seconds. Most are recall-based.',
          avoidMistakes: [
            'Read all options before answering',
            'Don\'t confuse similar terms',
            'Check for "NOT" or "EXCEPT" in question',
          ],
        ),
        difficulty: 'medium',
        marks: 4,
        negativeMarks: 1,
        timeInSeconds: 60,
        tags: ['biology', 'neet', 'ncert'],
      ));
    }
    
    return questions;
  }

  /// Generate Botany specific questions
  static List<EnhancedQuestion> generateBotany(int count) {
    final questions = <EnhancedQuestion>[];
    
    final botanyQA = [
      ('Xylem is responsible for?', 'Water transport', ['Water transport', 'Food transport', 'Hormone transport', 'Gas exchange'], 'Xylem transports water and minerals from roots'),
      ('Which tissue provides mechanical support?', 'Sclerenchyma', ['Sclerenchyma', 'Parenchyma', 'Collenchyma', 'Meristem'], 'Sclerenchyma has thick, lignified walls'),
      ('C4 pathway is also called?', 'Hatch-Slack pathway', ['Hatch-Slack pathway', 'Calvin cycle', 'Krebs cycle', 'EMP pathway'], 'C4 plants use Hatch-Slack pathway for CO₂ fixation'),
      ('Nitrogen fixation is done by?', 'Rhizobium', ['Rhizobium', 'E. coli', 'Lactobacillus', 'Yeast'], 'Rhizobium fixes atmospheric N₂ in legume root nodules'),
      ('Stomata open due to?', 'Turgidity of guard cells', ['Turgidity of guard cells', 'Flaccidity', 'High CO₂', 'Darkness'], 'K⁺ influx causes guard cells to become turgid'),
    ];
    
    for (int i = 0; i < count; i++) {
      final data = botanyQA[i % botanyQA.length];
      final options = List<String>.from(data.$3);
      options.shuffle();
      
      questions.add(EnhancedQuestion(
        id: 'neet_bot_${i + 1}',
        examType: 'neet',
        subject: 'Biology',
        topic: 'Botany',
        question: data.$1,
        options: options,
        correctOptionIndex: options.indexOf(data.$2),
        explanation: data.$4,
        difficulty: 'medium',
        marks: 4,
        negativeMarks: 1,
        timeInSeconds: 60,
        tags: ['botany', 'biology', 'neet', 'plants'],
      ));
    }
    
    return questions;
  }

  /// Generate Zoology specific questions
  static List<EnhancedQuestion> generateZoology(int count) {
    final questions = <EnhancedQuestion>[];
    
    final zoologyQA = [
      ('What type of circulation do humans have?', 'Double circulation', ['Double circulation', 'Single circulation', 'Open circulation', 'Incomplete circulation'], 'Blood passes through heart twice in one circuit'),
      ('Which chamber of heart has thickest wall?', 'Left ventricle', ['Left ventricle', 'Right ventricle', 'Left atrium', 'Right atrium'], 'Left ventricle pumps blood to entire body'),
      ('Rods and cones are found in?', 'Retina', ['Retina', 'Cornea', 'Iris', 'Lens'], 'Photoreceptors in retina detect light'),
      ('What connects muscles to bones?', 'Tendons', ['Tendons', 'Ligaments', 'Cartilage', 'Fascia'], 'Tendons are tough fibrous connective tissue'),
      ('Thymus gland is associated with?', 'T-cell maturation', ['T-cell maturation', 'Insulin secretion', 'Growth hormone', 'Thyroxine production'], 'T-lymphocytes mature in thymus'),
    ];
    
    for (int i = 0; i < count; i++) {
      final data = zoologyQA[i % zoologyQA.length];
      final options = List<String>.from(data.$3);
      options.shuffle();
      
      questions.add(EnhancedQuestion(
        id: 'neet_zoo_${i + 1}',
        examType: 'neet',
        subject: 'Biology',
        topic: 'Zoology',
        question: data.$1,
        options: options,
        correctOptionIndex: options.indexOf(data.$2),
        explanation: data.$4,
        difficulty: 'medium',
        marks: 4,
        negativeMarks: 1,
        timeInSeconds: 60,
        tags: ['zoology', 'biology', 'neet', 'human-body'],
      ));
    }
    
    return questions;
  }

  /// Generate all NEET questions
  static List<EnhancedQuestion> generateAllQuestions() {
    return [
      ...generateBiology(800),
      ...generateBotany(500),
      ...generateZoology(500),
    ];
  }

  static int get totalQuestionCount => 1800;
}
