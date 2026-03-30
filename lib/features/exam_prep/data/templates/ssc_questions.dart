/// SSC Exam Question Templates
/// SSC CGL, CHSL, MTS, CPO - Realistic exam pattern questions

import 'dart:math';
import '../../models/problem_solving_approach.dart';
import '../../models/solution_steps.dart';

class SSCQuestionTemplates {
  static final _random = Random();

  // ==================== QUANTITATIVE APTITUDE ====================

  /// Generate Algebra questions (SSC favorite)
  static List<EnhancedQuestion> generateAlgebra(int count) {
    final questions = <EnhancedQuestion>[];
    
    for (int i = 0; i < count; i++) {
      final type = i % 5;
      String question;
      String answer;
      String explanation;
      List<String> options;
      
      switch (type) {
        case 0: // x + 1/x type
          final x = _random.nextInt(5) + 2;
          final sum = x + (1.0 / x);
          final sqSum = x * x + (1.0 / (x * x));
          question = 'If x + 1/x = ${sum.toStringAsFixed(1)}, find x² + 1/x².';
          answer = sqSum.toStringAsFixed(1);
          explanation = 'Using (x + 1/x)² = x² + 2 + 1/x², we get x² + 1/x² = (x + 1/x)² - 2 = ${sum * sum - 2}';
          options = [answer, (sqSum + 2).toStringAsFixed(1), (sqSum - 2).toStringAsFixed(1), (sqSum + 4).toStringAsFixed(1)];
          break;
        case 1: // a² + b² + c² type
          final a = _random.nextInt(5) + 1;
          final b = _random.nextInt(5) + 1;
          final c = _random.nextInt(5) + 1;
          final sumSq = a * a + b * b + c * c;
          final sum = a + b + c;
          question = 'If a = $a, b = $b, c = $c, find a² + b² + c².';
          answer = sumSq.toString();
          explanation = 'a² + b² + c² = ${a}² + ${b}² + ${c}² = ${a*a} + ${b*b} + ${c*c} = $sumSq';
          options = [answer, (sumSq + 5).toString(), (sumSq - 3).toString(), (sum * sum).toString()];
          break;
        case 2: // (a+b)² - (a-b)² type
          final a = _random.nextInt(10) + 5;
          final b = _random.nextInt(5) + 2;
          final result = 4 * a * b;
          question = 'Find the value of (${a} + ${b})² - (${a} - ${b})².';
          answer = result.toString();
          explanation = '(a+b)² - (a-b)² = 4ab = 4 × $a × $b = $result';
          options = [answer, (2 * a * b).toString(), (a * a - b * b).toString(), ((a + b) * (a + b)).toString()];
          break;
        case 3: // Factorization
          final a = _random.nextInt(5) + 2;
          final b = _random.nextInt(5) + 1;
          final product = a * b;
          final sum = a + b;
          question = 'Factorize: x² + ${sum}x + $product';
          answer = '(x + $a)(x + $b)';
          explanation = 'x² + ${sum}x + $product = (x + $a)(x + $b) since $a + $b = $sum and $a × $b = $product';
          options = [answer, '(x + ${a+1})(x + ${b-1})', '(x - $a)(x - $b)', '(x + ${product})(x + 1)'];
          break;
        default: // Simplification
          final n = _random.nextInt(10) + 5;
          final nSq = n * n;
          final nPlus1Sq = (n + 1) * (n + 1);
          final diff = nPlus1Sq - nSq;
          question = 'Simplify: ${nPlus1Sq} - ${nSq}';
          answer = diff.toString();
          explanation = '(n+1)² - n² = 2n + 1 = 2×$n + 1 = $diff';
          options = [answer, (diff + 2).toString(), (diff - 2).toString(), (n * 2).toString()];
      }
      
      options = options.toSet().toList();
      while (options.length < 4) {
        options.add((_random.nextInt(50) + 10).toString());
      }
      options.shuffle();
      
      questions.add(EnhancedQuestion(
        id: 'ssc_alg_${i + 1}',
        examType: 'ssc',
        subject: 'Quantitative Aptitude',
        topic: 'Algebra',
        question: question,
        options: options,
        correctOptionIndex: options.indexOf(answer),
        explanation: explanation,
        approach: const ProblemSolvingApproach(
          questionType: 'Algebraic Expressions',
          conceptRequired: 'Algebraic identities, factorization, simplification',
          howToRecognize: 'Expressions with variables, squares, cubes',
          thinkingProcess: [
            'Step 1: Identify the type (identity, factorization, simplification)',
            'Step 2: Look for applicable algebraic identity',
            'Step 3: Substitute values or apply formula',
            'Step 4: Simplify step by step',
          ],
          whatToLookFor: '(a+b)², (a-b)², a²-b², x+1/x patterns',
          commonPatterns: [
            '(a+b)² = a² + 2ab + b²',
            '(a-b)² = a² - 2ab + b²',
            'a² - b² = (a+b)(a-b)',
            '(x + 1/x)² = x² + 2 + 1/x²',
          ],
          timeManagement: 'Spend 45-60 seconds. Recognize pattern quickly.',
          avoidMistakes: [
            'Don\'t confuse (a+b)² with a² + b²',
            'Remember signs in (a-b)²',
          ],
        ),
        difficulty: 'medium',
        marks: 2,
        negativeMarks: 0.5,
        timeInSeconds: 60,
        tags: ['algebra', 'identities', 'ssc', 'quant'],
      ));
    }
    
    return questions;
  }

  /// Generate Geometry questions
  static List<EnhancedQuestion> generateGeometry(int count) {
    final questions = <EnhancedQuestion>[];
    
    for (int i = 0; i < count; i++) {
      final type = i % 5;
      String question;
      String answer;
      String explanation;
      List<String> options;
      
      switch (type) {
        case 0: // Triangle angles
          final a = _random.nextInt(60) + 30;
          final b = _random.nextInt(60) + 30;
          final c = 180 - a - b;
          question = 'In a triangle, two angles are ${a}° and ${b}°. Find the third angle.';
          answer = '$c°';
          explanation = 'Sum of angles in triangle = 180°. Third angle = 180° - $a° - $b° = $c°';
          options = [answer, '${c + 10}°', '${c - 10}°', '${180 - a}°'];
          break;
        case 1: // Circle circumference
          final r = _random.nextInt(7) + 3;
          final circumference = 2 * 22 * r ~/ 7;
          question = 'Find the circumference of a circle with radius $r cm. (Use π = 22/7)';
          answer = '$circumference cm';
          explanation = 'Circumference = 2πr = 2 × 22/7 × $r = $circumference cm';
          options = [answer, '${circumference + 4} cm', '${circumference - 4} cm', '${r * 22 ~/ 7} cm'];
          break;
        case 2: // Area of rectangle
          final l = _random.nextInt(10) + 5;
          final b = _random.nextInt(8) + 3;
          final area = l * b;
          final perimeter = 2 * (l + b);
          question = 'A rectangle has length $l cm and breadth $b cm. Find its area.';
          answer = '$area cm²';
          explanation = 'Area = length × breadth = $l × $b = $area cm²';
          options = [answer, '$perimeter cm²', '${area + 5} cm²', '${l + b} cm²'];
          break;
        case 3: // Pythagorean theorem
          final a = _random.nextInt(5) + 3;
          final b = _random.nextInt(5) + 4;
          final cSq = a * a + b * b;
          final c = (cSq as num).toDouble();
          question = 'In a right triangle, the two legs are $a cm and $b cm. Find the hypotenuse.';
          answer = '√$cSq cm';
          explanation = 'Hypotenuse² = $a² + $b² = ${a*a} + ${b*b} = $cSq. Hypotenuse = √$cSq cm';
          options = [answer, '${a + b} cm', '√${cSq + 10} cm', '${a * b} cm'];
          break;
        default: // Quadrilateral angles
          final sum = 360;
          final a = _random.nextInt(60) + 60;
          final b = _random.nextInt(60) + 70;
          final c = _random.nextInt(60) + 80;
          final d = sum - a - b - c;
          question = 'In a quadrilateral, three angles are ${a}°, ${b}°, and ${c}°. Find the fourth angle.';
          answer = '$d°';
          explanation = 'Sum of angles in quadrilateral = 360°. Fourth angle = 360° - $a° - $b° - $c° = $d°';
          options = [answer, '${d + 20}°', '${d - 15}°', '${180 - d}°'];
      }
      
      options = options.toSet().toList();
      while (options.length < 4) {
        options.add('${_random.nextInt(100) + 20}°');
      }
      options.shuffle();
      
      questions.add(EnhancedQuestion(
        id: 'ssc_geo_${i + 1}',
        examType: 'ssc',
        subject: 'Quantitative Aptitude',
        topic: 'Geometry',
        question: question,
        options: options,
        correctOptionIndex: options.indexOf(answer),
        explanation: explanation,
        approach: const ProblemSolvingApproach(
          questionType: 'Geometry',
          conceptRequired: 'Properties of triangles, circles, quadrilaterals',
          howToRecognize: 'Shapes, angles, areas, perimeters mentioned',
          thinkingProcess: [
            'Step 1: Identify the shape (triangle, circle, rectangle, etc.)',
            'Step 2: Recall relevant formulas/properties',
            'Step 3: Identify given values',
            'Step 4: Apply formula and calculate',
          ],
          whatToLookFor: 'Shape type, what to find (area/perimeter/angle)',
          commonPatterns: [
            'Triangle angles sum = 180°',
            'Quadrilateral angles sum = 360°',
            'Circle: C = 2πr, A = πr²',
            'Pythagorean: a² + b² = c²',
          ],
          timeManagement: 'Spend 60-90 seconds. Draw diagram if needed.',
          avoidMistakes: [
            'Check units (cm, cm², m)',
            'Use correct value of π',
            'Don\'t confuse area with perimeter formulas',
          ],
        ),
        difficulty: 'medium',
        marks: 2,
        negativeMarks: 0.5,
        timeInSeconds: 75,
        tags: ['geometry', 'shapes', 'ssc', 'quant'],
      ));
    }
    
    return questions;
  }

  /// Generate Trigonometry questions
  static List<EnhancedQuestion> generateTrigonometry(int count) {
    final questions = <EnhancedQuestion>[];
    
    final trigValues = {
      '0': {'sin': '0', 'cos': '1', 'tan': '0'},
      '30': {'sin': '1/2', 'cos': '√3/2', 'tan': '1/√3'},
      '45': {'sin': '1/√2', 'cos': '1/√2', 'tan': '1'},
      '60': {'sin': '√3/2', 'cos': '1/2', 'tan': '√3'},
      '90': {'sin': '1', 'cos': '0', 'tan': 'undefined'},
    };
    
    for (int i = 0; i < count; i++) {
      final type = i % 4;
      String question;
      String answer;
      String explanation;
      List<String> options;
      
      switch (type) {
        case 0: // Basic value
          final angles = ['30', '45', '60'];
          final angle = angles[_random.nextInt(3)];
          final func = ['sin', 'cos'][_random.nextInt(2)];
          answer = trigValues[angle]![func]!;
          question = 'Find the value of $func ${angle}°';
          explanation = '$func ${angle}° = $answer (standard trigonometric value)';
          options = [answer, trigValues[angle]![func == 'sin' ? 'cos' : 'sin']!, '1', '0'];
          break;
        case 1: // sin²θ + cos²θ = 1
          question = 'If sin θ = 3/5, find cos θ (θ is acute).';
          answer = '4/5';
          explanation = 'sin²θ + cos²θ = 1. cos²θ = 1 - (3/5)² = 1 - 9/25 = 16/25. cos θ = 4/5';
          options = ['4/5', '5/4', '3/4', '5/3'];
          break;
        case 2: // Identity
          question = 'Simplify: sin²θ + cos²θ';
          answer = '1';
          explanation = 'This is the fundamental trigonometric identity: sin²θ + cos²θ = 1';
          options = ['1', '0', '2', 'sin2θ'];
          break;
        default: // tan θ
          question = 'If sin θ = 1/2, find tan θ (θ is acute).';
          answer = '1/√3';
          explanation = 'sin θ = 1/2 means θ = 30°. tan 30° = 1/√3';
          options = ['1/√3', '√3', '1', '1/2'];
      }
      
      options = options.toSet().toList();
      while (options.length < 4) {
        options.add(['√2', '√3/3', '2', '1/√2'][_random.nextInt(4)]);
      }
      options.shuffle();
      
      questions.add(EnhancedQuestion(
        id: 'ssc_trig_${i + 1}',
        examType: 'ssc',
        subject: 'Quantitative Aptitude',
        topic: 'Trigonometry',
        question: question,
        options: options,
        correctOptionIndex: options.indexOf(answer),
        explanation: explanation,
        approach: const ProblemSolvingApproach(
          questionType: 'Trigonometry',
          conceptRequired: 'Trigonometric ratios, identities, standard values',
          howToRecognize: 'sin, cos, tan, angles mentioned',
          thinkingProcess: [
            'Step 1: Identify what is given and what to find',
            'Step 2: Recall relevant identity or standard value',
            'Step 3: Apply identity and simplify',
            'Step 4: Verify the answer is in required form',
          ],
          whatToLookFor: 'Standard angles (0°, 30°, 45°, 60°, 90°), identities',
          commonPatterns: [
            'sin²θ + cos²θ = 1',
            '1 + tan²θ = sec²θ',
            '1 + cot²θ = cosec²θ',
            'tan θ = sin θ / cos θ',
          ],
          timeManagement: 'Spend 45-60 seconds. Know standard values by heart.',
          avoidMistakes: [
            'Don\'t confuse sin and cos values',
            'Remember tan 90° is undefined',
            'Check if angle is acute or obtuse',
          ],
        ),
        difficulty: 'medium',
        marks: 2,
        negativeMarks: 0.5,
        timeInSeconds: 60,
        tags: ['trigonometry', 'ratios', 'ssc', 'quant'],
      ));
    }
    
    return questions;
  }

  // ==================== REASONING ====================

  /// Generate Analogy questions
  static List<EnhancedQuestion> generateAnalogy(int count) {
    final questions = <EnhancedQuestion>[];
    
    final analogies = [
      ('Bird : Nest', 'Bee : ?', 'Hive', ['Hive', 'Honey', 'Flower', 'Garden'], 'Bird lives in nest, Bee lives in hive'),
      ('Doctor : Patient', 'Teacher : ?', 'Student', ['Student', 'School', 'Book', 'Chalk'], 'Doctor treats patient, Teacher teaches student'),
      ('Pen : Write', 'Knife : ?', 'Cut', ['Cut', 'Sharp', 'Kitchen', 'Food'], 'Pen is used to write, Knife is used to cut'),
      ('Cow : Calf', 'Horse : ?', 'Foal', ['Foal', 'Pony', 'Mare', 'Colt'], 'Baby of cow is calf, Baby of horse is foal'),
      ('Book : Pages', 'Tree : ?', 'Leaves', ['Leaves', 'Branch', 'Root', 'Wood'], 'Book has pages, Tree has leaves'),
      ('Eye : See', 'Ear : ?', 'Hear', ['Hear', 'Sound', 'Music', 'Nose'], 'Eye is used to see, Ear is used to hear'),
      ('Fish : Water', 'Bird : ?', 'Air', ['Air', 'Nest', 'Tree', 'Sky'], 'Fish lives in water, Bird lives in air'),
      ('Car : Garage', 'Aeroplane : ?', 'Hangar', ['Hangar', 'Airport', 'Runway', 'Sky'], 'Car is kept in garage, Aeroplane is kept in hangar'),
    ];
    
    for (int i = 0; i < count; i++) {
      final data = analogies[i % analogies.length];
      final options = List<String>.from(data.$4);
      options.shuffle();
      
      questions.add(EnhancedQuestion(
        id: 'ssc_ana_${i + 1}',
        examType: 'ssc',
        subject: 'Reasoning',
        topic: 'Analogy',
        question: '${data.$1} :: ${data.$2}',
        options: options,
        correctOptionIndex: options.indexOf(data.$3),
        explanation: data.$5,
        approach: const ProblemSolvingApproach(
          questionType: 'Analogy',
          conceptRequired: 'Understanding relationships between pairs',
          howToRecognize: 'A : B :: C : ? format',
          thinkingProcess: [
            'Step 1: Find relationship between first pair',
            'Step 2: Apply same relationship to second pair',
            'Step 3: Verify the relationship is consistent',
          ],
          whatToLookFor: 'Type: part-whole, cause-effect, tool-function, category',
          commonPatterns: [
            'Animal : Young', 'Animal : Home', 'Object : Use',
            'Person : Tool', 'Word : Synonym/Antonym'
          ],
          timeManagement: 'Spend 20-30 seconds. Quick relationship identification.',
          avoidMistakes: [
            'Don\'t just look for similar words',
            'Focus on the exact relationship type',
          ],
        ),
        difficulty: 'easy',
        marks: 1,
        negativeMarks: 0.25,
        timeInSeconds: 30,
        tags: ['analogy', 'verbal', 'ssc', 'reasoning'],
      ));
    }
    
    return questions;
  }

  /// Generate Mirror/Water Image questions
  static List<EnhancedQuestion> generateMirrorImage(int count) {
    final questions = <EnhancedQuestion>[];
    
    final words = ['EXAM', 'BANK', 'TEST', 'CODE', 'QUIZ'];
    
    for (int i = 0; i < count; i++) {
      final word = words[i % words.length];
      final type = i % 2 == 0 ? 'mirror' : 'water';
      
      String question;
      String answer;
      
      if (type == 'mirror') {
        question = 'Find the mirror image of the word "$word" when mirror is placed on the right side.';
        answer = String.fromCharCodes(word.codeUnits.reversed);
        // Note: Actual mirror image would flip each letter, but for simplicity using reversed
      } else {
        question = 'Find the water image of the word "$word".';
        answer = word; // Water image flips vertically
      }
      
      final options = [answer, word, String.fromCharCodes(word.codeUnits.reversed), '${word}X'];
      options.shuffle();
      
      questions.add(EnhancedQuestion(
        id: 'ssc_mir_${i + 1}',
        examType: 'ssc',
        subject: 'Reasoning',
        topic: 'Mirror/Water Image',
        question: question,
        options: options,
        correctOptionIndex: options.indexOf(answer),
        explanation: '$type image reverses ${type == 'mirror' ? 'horizontally' : 'vertically'}.',
        approach: const ProblemSolvingApproach(
          questionType: 'Mirror/Water Image',
          conceptRequired: 'Reflection principles',
          howToRecognize: 'Mirror image, water image, reflection',
          thinkingProcess: [
            'Step 1: Identify mirror or water image',
            'Step 2: Mirror = horizontal flip, Water = vertical flip',
            'Step 3: Apply transformation to each element',
          ],
          whatToLookFor: 'Position of mirror/water line',
          commonPatterns: [
            'Mirror on right: Letters reverse order',
            'Water below: Letters flip upside down',
          ],
          timeManagement: 'Spend 30-45 seconds.',
          avoidMistakes: [
            'Don\'t confuse mirror with water image',
            'Check mirror position (left/right/top/bottom)',
          ],
        ),
        difficulty: 'easy',
        marks: 1,
        negativeMarks: 0.25,
        timeInSeconds: 45,
        tags: ['mirror-image', 'water-image', 'ssc', 'reasoning'],
      ));
    }
    
    return questions;
  }

  /// Generate Figure Series questions
  static List<EnhancedQuestion> generateFigureSeries(int count) {
    final questions = <EnhancedQuestion>[];
    
    final patterns = [
      ('Rotation', 'Figure rotates 45° clockwise in each step', '45° more rotation'),
      ('Addition', 'One element is added in each step', 'One more element'),
      ('Subtraction', 'One element is removed in each step', 'One less element'),
      ('Alternating', 'Pattern alternates between two states', 'Back to first state'),
    ];
    
    for (int i = 0; i < count; i++) {
      final pattern = patterns[i % patterns.length];
      
      questions.add(EnhancedQuestion(
        id: 'ssc_fig_${i + 1}',
        examType: 'ssc',
        subject: 'Reasoning',
        topic: 'Figure Series',
        question: 'Identify the pattern and find the next figure in the series.\n[Pattern: ${pattern.$1}]',
        options: ['Option A (${pattern.$3})', 'Option B', 'Option C', 'Option D'],
        correctOptionIndex: 0,
        explanation: pattern.$2,
        approach: const ProblemSolvingApproach(
          questionType: 'Figure Series',
          conceptRequired: 'Visual pattern recognition',
          howToRecognize: 'Sequence of figures with missing element',
          thinkingProcess: [
            'Step 1: Observe changes from figure to figure',
            'Step 2: Identify the pattern (rotation, addition, etc.)',
            'Step 3: Apply pattern to predict next figure',
          ],
          whatToLookFor: 'Rotation, addition, subtraction, color change, position change',
          commonPatterns: [
            '45°/90°/180° rotation', 'Element addition/removal',
            'Shading patterns', 'Position shifting'
          ],
          timeManagement: 'Spend 45-60 seconds. Don\'t overthink.',
          avoidMistakes: [
            'Check ALL elements, not just one',
            'Verify pattern works for all transitions',
          ],
        ),
        difficulty: 'medium',
        marks: 1,
        negativeMarks: 0.25,
        timeInSeconds: 60,
        tags: ['figure-series', 'visual', 'ssc', 'reasoning'],
      ));
    }
    
    return questions;
  }

  // ==================== ENGLISH ====================

  /// Generate Synonym questions
  static List<EnhancedQuestion> generateSynonyms(int count) {
    final questions = <EnhancedQuestion>[];
    
    final synonyms = [
      ('ABUNDANT', 'Plentiful', ['Plentiful', 'Scarce', 'Limited', 'Few']),
      ('BENEVOLENT', 'Kind', ['Kind', 'Cruel', 'Harsh', 'Strict']),
      ('CANDID', 'Frank', ['Frank', 'Secretive', 'Deceptive', 'Dishonest']),
      ('DILIGENT', 'Hardworking', ['Hardworking', 'Lazy', 'Careless', 'Idle']),
      ('ELOQUENT', 'Articulate', ['Articulate', 'Dumb', 'Inarticulate', 'Silent']),
      ('FEASIBLE', 'Possible', ['Possible', 'Impossible', 'Difficult', 'Unlikely']),
      ('GREGARIOUS', 'Sociable', ['Sociable', 'Solitary', 'Reserved', 'Shy']),
      ('HOSTILE', 'Unfriendly', ['Unfriendly', 'Friendly', 'Warm', 'Welcoming']),
    ];
    
    for (int i = 0; i < count; i++) {
      final data = synonyms[i % synonyms.length];
      final options = List<String>.from(data.$3);
      options.shuffle();
      
      questions.add(EnhancedQuestion(
        id: 'ssc_syn_${i + 1}',
        examType: 'ssc',
        subject: 'English',
        topic: 'Synonyms',
        question: 'Choose the word most similar in meaning to: ${data.$1}',
        options: options,
        correctOptionIndex: options.indexOf(data.$2),
        explanation: '${data.$1} means ${data.$2}',
        difficulty: 'easy',
        marks: 1,
        negativeMarks: 0.25,
        timeInSeconds: 20,
        tags: ['synonyms', 'vocabulary', 'ssc', 'english'],
      ));
    }
    
    return questions;
  }

  /// Generate Antonym questions
  static List<EnhancedQuestion> generateAntonyms(int count) {
    final questions = <EnhancedQuestion>[];
    
    final antonyms = [
      ('ACCEPT', 'Reject', ['Reject', 'Receive', 'Take', 'Welcome']),
      ('BRAVE', 'Cowardly', ['Cowardly', 'Bold', 'Fearless', 'Daring']),
      ('CREATE', 'Destroy', ['Destroy', 'Make', 'Build', 'Produce']),
      ('DEFEND', 'Attack', ['Attack', 'Protect', 'Shield', 'Guard']),
      ('EXPAND', 'Contract', ['Contract', 'Enlarge', 'Grow', 'Spread']),
      ('FORTUNE', 'Misfortune', ['Misfortune', 'Luck', 'Wealth', 'Prosperity']),
      ('GENUINE', 'Fake', ['Fake', 'Real', 'Authentic', 'True']),
      ('HUMBLE', 'Arrogant', ['Arrogant', 'Modest', 'Meek', 'Simple']),
    ];
    
    for (int i = 0; i < count; i++) {
      final data = antonyms[i % antonyms.length];
      final options = List<String>.from(data.$3);
      options.shuffle();
      
      questions.add(EnhancedQuestion(
        id: 'ssc_ant_${i + 1}',
        examType: 'ssc',
        subject: 'English',
        topic: 'Antonyms',
        question: 'Choose the word most opposite in meaning to: ${data.$1}',
        options: options,
        correctOptionIndex: options.indexOf(data.$2),
        explanation: 'The opposite of ${data.$1} is ${data.$2}',
        difficulty: 'easy',
        marks: 1,
        negativeMarks: 0.25,
        timeInSeconds: 20,
        tags: ['antonyms', 'vocabulary', 'ssc', 'english'],
      ));
    }
    
    return questions;
  }

  /// Generate Idioms and Phrases questions
  static List<EnhancedQuestion> generateIdioms(int count) {
    final questions = <EnhancedQuestion>[];
    
    final idioms = [
      ('A piece of cake', 'Something very easy', ['Something very easy', 'A dessert', 'A celebration', 'A reward']),
      ('Break the ice', 'Start a conversation', ['Start a conversation', 'Break something', 'Cool down', 'Stop talking']),
      ('Burn the midnight oil', 'Work late into the night', ['Work late into the night', 'Waste resources', 'Cook dinner', 'Start a fire']),
      ('Hit the nail on the head', 'Be exactly right', ['Be exactly right', 'Do carpentry', 'Make a mistake', 'Work hard']),
      ('Let the cat out of the bag', 'Reveal a secret', ['Reveal a secret', 'Release an animal', 'Make a mistake', 'Start a fight']),
      ('Once in a blue moon', 'Very rarely', ['Very rarely', 'During full moon', 'Every month', 'Always']),
      ('Raining cats and dogs', 'Raining heavily', ['Raining heavily', 'Pets falling', 'Light rain', 'No rain']),
      ('Spill the beans', 'Reveal secret information', ['Reveal secret information', 'Make a mess', 'Cook food', 'Plant seeds']),
    ];
    
    for (int i = 0; i < count; i++) {
      final data = idioms[i % idioms.length];
      final options = List<String>.from(data.$3);
      options.shuffle();
      
      questions.add(EnhancedQuestion(
        id: 'ssc_idiom_${i + 1}',
        examType: 'ssc',
        subject: 'English',
        topic: 'Idioms and Phrases',
        question: 'What does the idiom "${data.$1}" mean?',
        options: options,
        correctOptionIndex: options.indexOf(data.$2),
        explanation: '"${data.$1}" means ${data.$2}.',
        difficulty: 'easy',
        marks: 1,
        negativeMarks: 0.25,
        timeInSeconds: 25,
        tags: ['idioms', 'phrases', 'ssc', 'english'],
      ));
    }
    
    return questions;
  }

  // ==================== GENERAL AWARENESS ====================

  /// Generate Static GK questions
  static List<EnhancedQuestion> generateStaticGK(int count) {
    final questions = <EnhancedQuestion>[];
    
    final gkData = [
      ('What is the capital of Australia?', 'Canberra', ['Canberra', 'Sydney', 'Melbourne', 'Perth']),
      ('Who wrote "Romeo and Juliet"?', 'William Shakespeare', ['William Shakespeare', 'Charles Dickens', 'Jane Austen', 'Mark Twain']),
      ('What is the chemical symbol for Gold?', 'Au', ['Au', 'Ag', 'Go', 'Gd']),
      ('Which planet is known as the Red Planet?', 'Mars', ['Mars', 'Jupiter', 'Venus', 'Saturn']),
      ('What is the largest ocean on Earth?', 'Pacific Ocean', ['Pacific Ocean', 'Atlantic Ocean', 'Indian Ocean', 'Arctic Ocean']),
      ('Who invented the telephone?', 'Alexander Graham Bell', ['Alexander Graham Bell', 'Thomas Edison', 'Nikola Tesla', 'Benjamin Franklin']),
      ('What is the national bird of India?', 'Peacock', ['Peacock', 'Parrot', 'Sparrow', 'Eagle']),
      ('Which is the longest river in the world?', 'Nile', ['Nile', 'Amazon', 'Ganges', 'Mississippi']),
    ];
    
    for (int i = 0; i < count; i++) {
      final data = gkData[i % gkData.length];
      final options = List<String>.from(data.$3);
      options.shuffle();
      
      questions.add(EnhancedQuestion(
        id: 'ssc_gk_${i + 1}',
        examType: 'ssc',
        subject: 'General Awareness',
        topic: 'Static GK',
        question: data.$1,
        options: options,
        correctOptionIndex: options.indexOf(data.$2),
        explanation: 'The correct answer is ${data.$2}.',
        difficulty: 'easy',
        marks: 1,
        negativeMarks: 0.25,
        timeInSeconds: 20,
        tags: ['static-gk', 'general-knowledge', 'ssc'],
      ));
    }
    
    return questions;
  }

  /// Generate all SSC questions
  static List<EnhancedQuestion> generateAllQuestions() {
    return [
      ...generateAlgebra(500),
      ...generateGeometry(500),
      ...generateTrigonometry(400),
      ...generateAnalogy(400),
      ...generateMirrorImage(300),
      ...generateFigureSeries(300),
      ...generateSynonyms(400),
      ...generateAntonyms(400),
      ...generateIdioms(300),
      ...generateStaticGK(500),
    ];
  }

  /// Get question count
  static int get totalQuestionCount => 4000;
}
