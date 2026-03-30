/// CAT & GATE Exam Question Templates
/// CAT (MBA), GATE (Engineering) - Realistic exam pattern questions

import 'dart:math';
import '../../models/problem_solving_approach.dart';
import '../../models/solution_steps.dart';

class CATQuestionTemplates {
  static final _random = Random();

  // ==================== QUANTITATIVE APTITUDE ====================

  /// Generate Number System questions
  static List<EnhancedQuestion> generateNumberSystem(int count) {
    final questions = <EnhancedQuestion>[];
    
    for (int i = 0; i < count; i++) {
      final type = i % 5;
      String question;
      String answer;
      String explanation;
      List<String> options;
      
      switch (type) {
        case 0: // HCF/LCM
          final a = (_random.nextInt(5) + 2) * 6;
          final b = (_random.nextInt(5) + 2) * 4;
          final hcf = _gcd(a, b);
          question = 'Find the HCF of $a and $b.';
          answer = '$hcf';
          explanation = 'Using prime factorization or Euclidean algorithm, HCF($a, $b) = $hcf';
          options = [answer, '${hcf * 2}', '${hcf ~/ 2 + 1}', '${a * b ~/ hcf}'];
          break;
        case 1: // Divisibility
          final n = _random.nextInt(900) + 100;
          final remainder = n % 7;
          question = 'What is the remainder when $n is divided by 7?';
          answer = '$remainder';
          explanation = '$n = 7 × ${n ~/ 7} + $remainder';
          options = [answer, '${(remainder + 1) % 7}', '${(remainder + 2) % 7}', '${(remainder + 3) % 7}'];
          break;
        case 2: // Last digit
          final base = _random.nextInt(9) + 2;
          final power = _random.nextInt(50) + 20;
          final cycle = _getLastDigitCycle(base);
          final lastDigit = cycle[(power - 1) % cycle.length];
          question = 'Find the last digit of $base^$power.';
          answer = '$lastDigit';
          explanation = 'Last digits of powers of $base follow a cycle. $base^$power ends in $lastDigit';
          options = [answer, '${(lastDigit + 2) % 10}', '${(lastDigit + 4) % 10}', '${(lastDigit + 6) % 10}'];
          break;
        case 3: // Factorial trailing zeros
          final n = (_random.nextInt(10) + 5) * 5;
          final zeros = n ~/ 5 + n ~/ 25 + n ~/ 125;
          question = 'How many trailing zeros are in $n! (factorial)?';
          answer = '$zeros';
          explanation = 'Trailing zeros = [n/5] + [n/25] + [n/125]... = $zeros';
          options = [answer, '${zeros + 1}', '${zeros - 1}', '${n ~/ 5}'];
          break;
        default: // Unit digit sum
          final n = _random.nextInt(50) + 10;
          final unitSum = (n * (n + 1) ~/ 2) % 10;
          question = 'Find the unit digit of 1 + 2 + 3 + ... + $n.';
          answer = '$unitSum';
          explanation = 'Sum = $n($n+1)/2 = ${n * (n + 1) ~/ 2}. Unit digit = $unitSum';
          options = [answer, '${(unitSum + 2) % 10}', '${(unitSum + 5) % 10}', '${(unitSum + 7) % 10}'];
      }
      
      options = options.toSet().toList();
      while (options.length < 4) {
        options.add('${_random.nextInt(10)}');
      }
      options.shuffle();
      
      questions.add(EnhancedQuestion(
        id: 'cat_num_${i + 1}',
        examType: 'cat',
        subject: 'Quantitative Aptitude',
        topic: 'Number System',
        question: question,
        options: options,
        correctOptionIndex: options.indexOf(answer),
        explanation: explanation,
        approach: const ProblemSolvingApproach(
          questionType: 'Number System',
          conceptRequired: 'Divisibility, HCF/LCM, remainders, digit patterns',
          howToRecognize: 'Questions about digits, factors, remainders',
          thinkingProcess: [
            'Step 1: Identify the concept (HCF, LCM, remainder, etc.)',
            'Step 2: Apply appropriate technique',
            'Step 3: Look for patterns or shortcuts',
            'Step 4: Verify with substitution if possible',
          ],
          whatToLookFor: 'Numbers, operations, what to find',
          commonPatterns: [
            'Last digit cycles', 'Trailing zeros = floor(n/5)+...',
            'HCF × LCM = product', 'Remainder patterns',
          ],
          timeManagement: 'Spend 1-2 minutes. Use shortcuts.',
          avoidMistakes: [
            'Remember cyclicity of last digits',
            'Don\'t confuse HCF with LCM formulas',
          ],
        ),
        difficulty: 'hard',
        marks: 3,
        negativeMarks: 1,
        timeInSeconds: 120,
        tags: ['number-system', 'cat', 'quant'],
      ));
    }
    
    return questions;
  }

  /// Generate Logical Reasoning questions (CAT style)
  static List<EnhancedQuestion> generateLogicalReasoning(int count) {
    final questions = <EnhancedQuestion>[];
    
    for (int i = 0; i < count; i++) {
      final type = i % 4;
      String question;
      String answer;
      String explanation;
      List<String> options;
      
      switch (type) {
        case 0: // Arrangements
          question = 'In how many ways can 5 people be seated in a row?';
          answer = '120';
          explanation = '5! = 5 × 4 × 3 × 2 × 1 = 120';
          options = ['120', '60', '24', '720'];
          break;
        case 1: // Logical deduction
          question = 'All managers are leaders. Some leaders are visionaries. Which conclusion is definitely true?';
          answer = 'Some leaders are managers';
          explanation = 'If all managers are leaders, then some leaders must be managers (converse of universal)';
          options = ['Some leaders are managers', 'All leaders are managers', 'No visionary is a manager', 'All visionaries are leaders'];
          break;
        case 2: // Sets
          final a = _random.nextInt(30) + 20;
          final b = _random.nextInt(30) + 20;
          final both = _random.nextInt(10) + 5;
          final union = a + b - both;
          question = 'In a class of students, $a play cricket, $b play football, and $both play both. How many play at least one sport?';
          answer = '$union';
          explanation = 'n(A∪B) = n(A) + n(B) - n(A∩B) = $a + $b - $both = $union';
          options = [answer, '${a + b}', '${a + b - 2 * both}', '${both}'];
          break;
        default: // Probability
          final total = 52;
          final favorable = 4;
          question = 'What is the probability of drawing an Ace from a standard deck of 52 cards?';
          answer = '1/13';
          explanation = 'P(Ace) = 4/52 = 1/13';
          options = ['1/13', '1/52', '4/13', '1/4'];
      }
      
      options.shuffle();
      
      questions.add(EnhancedQuestion(
        id: 'cat_lr_${i + 1}',
        examType: 'cat',
        subject: 'Logical Reasoning',
        topic: 'Logic',
        question: question,
        options: options,
        correctOptionIndex: options.indexOf(answer),
        explanation: explanation,
        difficulty: 'hard',
        marks: 3,
        negativeMarks: 1,
        timeInSeconds: 150,
        tags: ['logical-reasoning', 'cat', 'sets', 'probability'],
      ));
    }
    
    return questions;
  }

  /// Generate Reading Comprehension (CAT style)
  static List<EnhancedQuestion> generateReadingComprehension(int count) {
    final questions = <EnhancedQuestion>[];
    
    final passages = [
      (
        '''The emergence of artificial intelligence has fundamentally altered the landscape of modern business. 
Companies that once relied solely on human intuition for decision-making are now leveraging sophisticated 
algorithms to analyze vast datasets and predict market trends with unprecedented accuracy. This shift 
has not only improved operational efficiency but has also raised important questions about the future 
role of human workers in an increasingly automated world.''',
        'AI in Business',
        [
          ('What is the main argument of the passage?', 'AI is transforming business decision-making', 
           ['AI is transforming business decision-making', 'Humans are becoming obsolete', 'Algorithms are perfect', 'Markets are unpredictable']),
          ('According to the passage, what has AI improved?', 'Operational efficiency',
           ['Operational efficiency', 'Human intuition', 'Market volatility', 'Worker satisfaction']),
        ],
      ),
      (
        '''Climate change represents one of the most significant challenges facing humanity today. 
Rising global temperatures have led to more frequent extreme weather events, threatening food 
security and displacing millions of people. While international agreements have set ambitious 
targets for reducing carbon emissions, the pace of implementation has been criticized as 
insufficient to avert the worst consequences of environmental degradation.''',
        'Climate Change',
        [
          ('The tone of the passage can best be described as:', 'Concerned and critical',
           ['Concerned and critical', 'Optimistic', 'Indifferent', 'Celebratory']),
          ('What criticism is mentioned in the passage?', 'Implementation pace is too slow',
           ['Implementation pace is too slow', 'Targets are too low', 'Agreements are unnecessary', 'Weather is unpredictable']),
        ],
      ),
    ];
    
    for (int i = 0; i < count; i++) {
      final passageData = passages[i % passages.length];
      final qaPair = passageData.$3[i % passageData.$3.length];
      final options = List<String>.from(qaPair.$3);
      options.shuffle();
      
      questions.add(EnhancedQuestion(
        id: 'cat_rc_${i + 1}',
        examType: 'cat',
        subject: 'Verbal Ability',
        topic: 'Reading Comprehension',
        question: 'Read the passage and answer:\n\n"${passageData.$1}"\n\n${qaPair.$1}',
        options: options,
        correctOptionIndex: options.indexOf(qaPair.$2),
        explanation: 'Based on the passage: ${qaPair.$2}',
        approach: const ProblemSolvingApproach(
          questionType: 'Reading Comprehension',
          conceptRequired: 'Critical reading, inference, tone analysis',
          howToRecognize: 'Long passage followed by questions',
          thinkingProcess: [
            'Step 1: Skim the passage for main idea',
            'Step 2: Read questions to know what to look for',
            'Step 3: Read passage carefully, noting key points',
            'Step 4: Answer based on passage, not general knowledge',
          ],
          whatToLookFor: 'Main idea, tone, specific details, inferences',
          commonPatterns: [
            'Main idea questions', 'Inference questions',
            'Tone/attitude questions', 'Detail questions',
          ],
          timeManagement: 'Spend 8-10 minutes per passage set.',
          avoidMistakes: [
            'Don\'t use outside knowledge',
            'Stick to what passage says',
            'Watch for extreme words in options',
          ],
        ),
        difficulty: 'hard',
        marks: 3,
        negativeMarks: 1,
        timeInSeconds: 180,
        tags: ['reading-comprehension', 'cat', 'verbal'],
      ));
    }
    
    return questions;
  }

  /// Generate Data Interpretation (CAT style)
  static List<EnhancedQuestion> generateDataInterpretation(int count) {
    final questions = <EnhancedQuestion>[];
    
    for (int i = 0; i < count; i++) {
      final sales = List.generate(5, (j) => (_random.nextInt(50) + 30) * 10);
      final total = sales.reduce((a, b) => a + b);
      final avg = total ~/ 5;
      final maxIndex = sales.indexOf(sales.reduce((a, b) => a > b ? a : b));
      
      final qType = i % 3;
      String question;
      String answer;
      
      switch (qType) {
        case 0:
          question = 'Given sales data: ${sales.join(", ")}. What is the average?';
          answer = '$avg';
          break;
        case 1:
          question = 'Given sales: ${sales.join(", ")}. What is the total?';
          answer = '$total';
          break;
        default:
          question = 'Given sales: ${sales.join(", ")}. Which position has maximum?';
          answer = '${maxIndex + 1}';
      }
      
      final options = [answer, '${int.parse(answer) + 10}', '${int.parse(answer) - 5}', '${int.parse(answer) + 20}'];
      options.shuffle();
      
      questions.add(EnhancedQuestion(
        id: 'cat_di_${i + 1}',
        examType: 'cat',
        subject: 'Data Interpretation',
        topic: 'Tables and Charts',
        question: question,
        options: options,
        correctOptionIndex: options.indexOf(answer),
        explanation: 'Calculation from given data gives $answer',
        difficulty: 'hard',
        marks: 3,
        negativeMarks: 1,
        timeInSeconds: 120,
        tags: ['data-interpretation', 'cat', 'calculation'],
      ));
    }
    
    return questions;
  }

  static int _gcd(int a, int b) {
    while (b != 0) {
      final t = b;
      b = a % b;
      a = t;
    }
    return a;
  }

  static List<int> _getLastDigitCycle(int n) {
    final lastDigit = n % 10;
    switch (lastDigit) {
      case 0: return [0];
      case 1: return [1];
      case 2: return [2, 4, 8, 6];
      case 3: return [3, 9, 7, 1];
      case 4: return [4, 6];
      case 5: return [5];
      case 6: return [6];
      case 7: return [7, 9, 3, 1];
      case 8: return [8, 4, 2, 6];
      case 9: return [9, 1];
      default: return [0];
    }
  }

  /// Generate all CAT questions
  static List<EnhancedQuestion> generateAllQuestions() {
    return [
      ...generateNumberSystem(500),
      ...generateLogicalReasoning(500),
      ...generateReadingComprehension(400),
      ...generateDataInterpretation(400),
    ];
  }

  static int get totalQuestionCount => 1800;
}

// ==================== GATE ====================

class GATEQuestionTemplates {
  static final _random = Random();

  /// Generate Engineering Mathematics questions
  static List<EnhancedQuestion> generateEngineeringMath(int count) {
    final questions = <EnhancedQuestion>[];
    
    for (int i = 0; i < count; i++) {
      final type = i % 5;
      String question;
      String answer;
      String explanation;
      List<String> options;
      
      switch (type) {
        case 0: // Linear Algebra - Eigenvalues
          final a = _random.nextInt(5) + 1;
          final d = _random.nextInt(5) + 1;
          question = 'Find the eigenvalues of matrix [[${a}, 0], [0, ${d}]]';
          answer = '$a and $d';
          explanation = 'For a diagonal matrix, eigenvalues are the diagonal elements';
          options = [answer, '${a + d} and 0', '${a * d} and 1', '${a - d} and ${a + d}'];
          break;
        case 1: // Calculus - Integration
          question = '∫₀^∞ e^(-x) dx = ?';
          answer = '1';
          explanation = '∫e^(-x)dx = -e^(-x). [−e^(-x)]₀^∞ = 0 - (-1) = 1';
          options = ['1', '0', '∞', 'e'];
          break;
        case 2: // Probability
          question = 'For a Poisson distribution with λ = 2, P(X = 0) = ?';
          answer = 'e^(-2)';
          explanation = 'P(X=k) = e^(-λ)λ^k/k!. P(X=0) = e^(-2) × 2^0 / 0! = e^(-2)';
          options = ['e^(-2)', '2e^(-2)', '1/e', '2/e'];
          break;
        case 3: // Differential Equations
          question = 'The general solution of dy/dx = y is:';
          answer = 'y = Ce^x';
          explanation = 'Separating variables: dy/y = dx. Integrating: ln|y| = x + C₁, y = Ce^x';
          options = ['y = Ce^x', 'y = Cx', 'y = C/x', 'y = Ce^(-x)'];
          break;
        default: // Complex Numbers
          question = 'The modulus of (3 + 4i) is:';
          answer = '5';
          explanation = '|z| = √(3² + 4²) = √(9 + 16) = √25 = 5';
          options = ['5', '7', '12', '25'];
      }
      
      options.shuffle();
      
      questions.add(EnhancedQuestion(
        id: 'gate_math_${i + 1}',
        examType: 'gate',
        subject: 'Engineering Mathematics',
        topic: 'Mathematics',
        question: question,
        options: options,
        correctOptionIndex: options.indexOf(answer),
        explanation: explanation,
        approach: const ProblemSolvingApproach(
          questionType: 'Engineering Mathematics',
          conceptRequired: 'Linear Algebra, Calculus, Probability, Differential Equations',
          howToRecognize: 'Mathematical expressions, matrices, integrals',
          thinkingProcess: [
            'Step 1: Identify the topic',
            'Step 2: Recall relevant theorems/formulas',
            'Step 3: Apply standard methods',
            'Step 4: Verify dimensions/units',
          ],
          whatToLookFor: 'Matrix type, function type, distribution type',
          commonPatterns: [
            'Eigenvalues of diagonal matrix = diagonal elements',
            'Standard integrals', 'Probability distributions',
          ],
          timeManagement: 'Spend 2-3 minutes. Know standard results.',
          avoidMistakes: [
            'Check matrix dimensions',
            'Don\'t forget constants of integration',
          ],
        ),
        difficulty: 'hard',
        marks: 2,
        negativeMarks: 0.67,
        timeInSeconds: 180,
        tags: ['engineering-math', 'gate', 'linear-algebra'],
      ));
    }
    
    return questions;
  }

  /// Generate Computer Science questions
  static List<EnhancedQuestion> generateComputerScience(int count) {
    final questions = <EnhancedQuestion>[];
    
    final csQA = [
      ('Time complexity of binary search is:', 'O(log n)', ['O(log n)', 'O(n)', 'O(n²)', 'O(1)'], 'Binary search halves search space each iteration'),
      ('Which data structure uses LIFO?', 'Stack', ['Stack', 'Queue', 'Array', 'Linked List'], 'Stack: Last In First Out'),
      ('Worst case of quicksort is:', 'O(n²)', ['O(n²)', 'O(n log n)', 'O(n)', 'O(log n)'], 'When pivot is always min/max element'),
      ('In a binary tree with n nodes, max edges:', 'n-1', ['n-1', 'n', 'n+1', '2n'], 'Tree with n nodes has n-1 edges'),
      ('BFS uses which data structure?', 'Queue', ['Queue', 'Stack', 'Heap', 'Array'], 'BFS explores level by level using queue'),
      ('Hash table average lookup:', 'O(1)', ['O(1)', 'O(n)', 'O(log n)', 'O(n²)'], 'With good hash function, constant time'),
      ('Deadlock requires how many conditions?', '4', ['4', '3', '2', '5'], 'Mutual exclusion, hold & wait, no preemption, circular wait'),
      ('Page replacement using LRU means:', 'Least Recently Used', ['Least Recently Used', 'Last Recently Used', 'Least Required Used', 'Latest Recently Used'], 'Replace page not used for longest time'),
    ];
    
    for (int i = 0; i < count; i++) {
      final data = csQA[i % csQA.length];
      final options = List<String>.from(data.$3);
      options.shuffle();
      
      questions.add(EnhancedQuestion(
        id: 'gate_cs_${i + 1}',
        examType: 'gate',
        subject: 'Computer Science',
        topic: 'Data Structures & Algorithms',
        question: data.$1,
        options: options,
        correctOptionIndex: options.indexOf(data.$2),
        explanation: data.$4,
        difficulty: 'medium',
        marks: 1,
        negativeMarks: 0.33,
        timeInSeconds: 90,
        tags: ['computer-science', 'gate', 'dsa', 'os'],
      ));
    }
    
    return questions;
  }

  /// Generate Digital Logic questions
  static List<EnhancedQuestion> generateDigitalLogic(int count) {
    final questions = <EnhancedQuestion>[];
    
    final dlQA = [
      ('A NAND gate is a universal gate because:', 'Any logic gate can be made using NAND', ['Any logic gate can be made using NAND', 'It is fastest', 'It uses least power', 'It is cheapest'], 'NAND can implement AND, OR, NOT'),
      ('The decimal equivalent of binary 1011 is:', '11', ['11', '13', '10', '12'], '1×8 + 0×4 + 1×2 + 1×1 = 11'),
      ('A flip-flop stores how many bits?', '1', ['1', '2', '4', '8'], 'Basic flip-flop stores single bit'),
      ('For a 3-bit counter, max count is:', '7', ['7', '8', '6', '3'], '2³ - 1 = 7 (counts 0 to 7)'),
      ('XOR of A and A is:', '0', ['0', '1', 'A', 'A\''], 'A ⊕ A = 0 (same inputs give 0)'),
    ];
    
    for (int i = 0; i < count; i++) {
      final data = dlQA[i % dlQA.length];
      final options = List<String>.from(data.$3);
      options.shuffle();
      
      questions.add(EnhancedQuestion(
        id: 'gate_dl_${i + 1}',
        examType: 'gate',
        subject: 'Digital Logic',
        topic: 'Logic Gates',
        question: data.$1,
        options: options,
        correctOptionIndex: options.indexOf(data.$2),
        explanation: data.$4,
        difficulty: 'medium',
        marks: 1,
        negativeMarks: 0.33,
        timeInSeconds: 60,
        tags: ['digital-logic', 'gate', 'boolean'],
      ));
    }
    
    return questions;
  }

  /// Generate all GATE questions
  static List<EnhancedQuestion> generateAllQuestions() {
    return [
      ...generateEngineeringMath(600),
      ...generateComputerScience(600),
      ...generateDigitalLogic(400),
    ];
  }

  static int get totalQuestionCount => 1600;
}
