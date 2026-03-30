/// Banking Exam Question Templates
/// IBPS PO/Clerk, SBI PO/Clerk, RBI Grade B - Realistic exam pattern questions

import 'dart:math';
import '../../models/problem_solving_approach.dart';
import '../../models/solution_steps.dart';

class BankingQuestionTemplates {
  static final _random = Random();

  // ==================== QUANTITATIVE APTITUDE ====================
  
  /// Generate Number Series questions (Banking pattern)
  static List<EnhancedQuestion> generateNumberSeries(int count) {
    final questions = <EnhancedQuestion>[];
    
    final seriesPatterns = [
      // Pattern 1: +n, +n+d, +n+2d (Arithmetic progression of differences)
      (List<int> nums) {
        final start = _random.nextInt(10) + 2;
        final increment = _random.nextInt(5) + 2;
        final diff = _random.nextInt(3) + 1;
        var current = start;
        var add = increment;
        final series = <int>[current];
        for (int i = 0; i < 5; i++) {
          current += add;
          series.add(current);
          add += diff;
        }
        return (series, '${diff}', 'Differences increase by $diff each time');
      },
      // Pattern 2: ×2+1, ×2+2, ×2+3...
      (List<int> nums) {
        final start = _random.nextInt(5) + 2;
        var current = start;
        final series = <int>[current];
        for (int i = 1; i <= 5; i++) {
          current = current * 2 + i;
          series.add(current);
        }
        return (series, 'multiply2_add', '×2 + (position)');
      },
      // Pattern 3: Squares pattern n², (n+1)², (n+2)²
      (List<int> nums) {
        final start = _random.nextInt(5) + 3;
        final series = <int>[];
        for (int i = 0; i <= 5; i++) {
          series.add((start + i) * (start + i));
        }
        return (series, 'squares', 'Perfect squares: ${start}², ${start+1}², ${start+2}²...');
      },
      // Pattern 4: ×1.5, ×1.5, ×1.5 (Geometric with fraction)
      (List<int> nums) {
        final start = _random.nextInt(4) + 4;
        var current = start.toDouble();
        final series = <int>[start];
        for (int i = 0; i < 5; i++) {
          current = current * 1.5;
          series.add(current.round());
        }
        return (series, 'multiply1.5', 'Each term × 1.5');
      },
      // Pattern 5: +prime numbers
      (List<int> nums) {
        final primes = [2, 3, 5, 7, 11, 13];
        final start = _random.nextInt(10) + 5;
        var current = start;
        final series = <int>[current];
        for (int i = 0; i < 5; i++) {
          current += primes[i];
          series.add(current);
        }
        return (series, 'primes', 'Adding consecutive primes: +2, +3, +5, +7, +11');
      },
    ];

    for (int i = 0; i < count; i++) {
      final pattern = seriesPatterns[i % seriesPatterns.length];
      final result = pattern([]);
      final series = result.$1 as List<int>;
      final patternType = result.$2 as String;
      final explanation = result.$3 as String;
      
      final missingIndex = _random.nextInt(4) + 1;
      final answer = series[missingIndex];
      series[missingIndex] = -1; // Mark as missing
      
      final seriesStr = series.map((n) => n == -1 ? '?' : n.toString()).join(', ');
      
      final wrongOptions = _generateWrongNumberOptions(answer, 4);
      final options = <String>[answer.toString()];
      for (final opt in wrongOptions) {
        if (options.length < 4 && !options.contains(opt.toString())) {
          options.add(opt.toString());
        }
      }
      while (options.length < 4) {
        options.add((answer + _random.nextInt(10) - 5).toString());
      }
      options.shuffle();
      
      questions.add(EnhancedQuestion(
        id: 'banking_ns_${i + 1}',
        examType: 'banking',
        subject: 'Quantitative Aptitude',
        topic: 'Number Series',
        subtopic: patternType,
        question: 'What should come in place of the question mark (?) in the following number series?\n\n$seriesStr',
        options: options,
        correctOptionIndex: options.indexOf(answer.toString()),
        explanation: explanation,
        solutionSteps: SolutionSteps(
          approach: 'Pattern Recognition - Identify the rule connecting consecutive terms',
          steps: [
            'Step 1: Identify the Pattern - Look at the differences or ratios between consecutive terms',
            'Step 2: Verify Pattern - $explanation',
            'Step 3: Apply Pattern - The missing term is $answer',
          ],
          proTip: 'Write differences below the series. Common patterns: ×2+1, ×2-1, +primes, +squares',
        ),
        approach: const ProblemSolvingApproach(
          questionType: 'Number Series',
          conceptRequired: 'Pattern recognition in number sequences',
          howToRecognize: 'A series of numbers with one missing, typically 5-6 numbers',
          thinkingProcess: [
            'Step 1: Calculate differences between consecutive terms',
            'Step 2: If differences are constant → Arithmetic Progression',
            'Step 3: If differences form a pattern → Second level analysis',
            'Step 4: Check for multiplication patterns if addition doesn\'t work',
            'Step 5: Look for squares, cubes, or prime number patterns',
          ],
          whatToLookFor: 'Patterns in differences, ratios, or special numbers (squares, primes)',
          commonPatterns: [
            '+constant', '×constant', '+increasing', '×increasing',
            'squares', 'cubes', 'prime additions', 'alternating operations'
          ],
          timeManagement: 'Spend 30-45 seconds. If pattern not found in 30 sec, move on and return later.',
          avoidMistakes: [
            'Don\'t assume the first pattern you see is correct',
            'Check the pattern works for ALL terms',
            'Consider two-level patterns (difference of differences)',
          ],
          proTips: [
            'Write differences below the series',
            'Common patterns: ×2+1, ×2-1, +primes, +squares',
            'If stuck, work backwards from options',
          ],
          difficultyLevel: 'medium',
          recommendedTime: 45,
        ),
        difficulty: 'medium',
        marks: 1,
        negativeMarks: 0.25,
        timeInSeconds: 45,
        tags: ['number-series', 'pattern', 'banking', 'quant'],
      ));
    }
    
    return questions;
  }

  /// Generate Simplification/Approximation questions
  static List<EnhancedQuestion> generateSimplification(int count) {
    final questions = <EnhancedQuestion>[];
    
    for (int i = 0; i < count; i++) {
      final type = i % 4;
      String question;
      int answer;
      String explanation;
      
      switch (type) {
        case 0: // Square root based
          final a = (_random.nextInt(10) + 5) * (_random.nextInt(10) + 5);
          final b = _random.nextInt(50) + 10;
          final sqrt = (a as num).toDouble();
          answer = (sqrt * b / 10).round();
          question = '√$a × $b ÷ 10 = ?';
          explanation = '√$a = ${sqrt.toInt().toString()} (approx), ${sqrt.toInt()} × $b ÷ 10 = $answer';
          break;
        case 1: // Percentage based
          final base = (_random.nextInt(20) + 5) * 100;
          final percent = [10, 15, 20, 25, 30][_random.nextInt(5)];
          answer = (base * percent / 100).round();
          question = '$percent% of $base = ?';
          explanation = '$percent% of $base = $base × $percent/100 = $answer';
          break;
        case 2: // Mixed operations
          final a = _random.nextInt(100) + 50;
          final b = _random.nextInt(50) + 10;
          final c = _random.nextInt(30) + 5;
          answer = a + b - c;
          question = '$a + $b - $c = ?';
          explanation = '$a + $b = ${a + b}, ${a + b} - $c = $answer';
          break;
        default: // Decimal approximation
          final a = (_random.nextInt(50) + 10).toDouble() + 0.97;
          final b = (_random.nextInt(30) + 5).toDouble() + 0.02;
          answer = (a * b).round();
          question = '${a.toStringAsFixed(2)} × ${b.toStringAsFixed(2)} = ?';
          explanation = '≈ ${a.round()} × ${b.round()} = $answer (approximation)';
      }
      
      final wrongOptions = _generateWrongNumberOptions(answer, 4);
      final options = <String>[answer.toString()];
      for (final opt in wrongOptions) {
        if (options.length < 4 && !options.contains(opt.toString())) {
          options.add(opt.toString());
        }
      }
      options.shuffle();
      
      questions.add(EnhancedQuestion(
        id: 'banking_simp_${i + 1}',
        examType: 'banking',
        subject: 'Quantitative Aptitude',
        topic: 'Simplification',
        question: 'What is the value of: $question',
        options: options,
        correctOptionIndex: options.indexOf(answer.toString()),
        explanation: explanation,
        difficulty: 'easy',
        marks: 1,
        negativeMarks: 0.25,
        timeInSeconds: 30,
        tags: ['simplification', 'calculation', 'banking', 'quant'],
      ));
    }
    
    return questions;
  }

  /// Generate Data Interpretation questions (Table/Chart based)
  static List<EnhancedQuestion> generateDataInterpretation(int count) {
    final questions = <EnhancedQuestion>[];
    
    // Sample data for DI set
    final years = ['2019', '2020', '2021', '2022', '2023'];
    final companies = ['Company A', 'Company B', 'Company C', 'Company D', 'Company E'];
    
    for (int i = 0; i < count; i++) {
      // Generate random production data
      final data = <String, List<int>>{};
      for (final company in companies) {
        data[company] = List.generate(5, (j) => (_random.nextInt(500) + 100) * 10);
      }
      
      final questionType = i % 5;
      String question;
      int answer;
      String explanation;
      
      switch (questionType) {
        case 0: // Total of a company
          final company = companies[_random.nextInt(5)];
          answer = data[company]!.reduce((a, b) => a + b);
          question = 'What is the total production of $company over all years?';
          explanation = 'Sum of $company: ${data[company]!.join(" + ")} = $answer';
          break;
        case 1: // Average of a year
          final yearIndex = _random.nextInt(5);
          final yearData = companies.map((c) => data[c]![yearIndex]).toList();
          answer = (yearData.reduce((a, b) => a + b) / 5).round();
          question = 'What is the average production in ${years[yearIndex]}?';
          explanation = 'Average = (${yearData.join(" + ")}) / 5 = $answer';
          break;
        case 2: // Percentage increase
          final company = companies[_random.nextInt(5)];
          final val2022 = data[company]![3];
          final val2023 = data[company]![4];
          answer = ((val2023 - val2022) * 100 / val2022).round();
          question = 'What is the percentage change in $company\'s production from 2022 to 2023?';
          explanation = 'Change = ($val2023 - $val2022) × 100 / $val2022 = $answer%';
          break;
        case 3: // Ratio
          final c1 = companies[_random.nextInt(3)];
          final c2 = companies[_random.nextInt(2) + 3];
          final sum1 = data[c1]!.reduce((a, b) => a + b);
          final sum2 = data[c2]!.reduce((a, b) => a + b);
          final gcd = _gcd(sum1, sum2);
          answer = sum1 ~/ gcd;
          question = 'What is the ratio of total production of $c1 to $c2? (First term)';
          explanation = 'Ratio = $sum1 : $sum2 = ${sum1 ~/ gcd} : ${sum2 ~/ gcd}';
          break;
        default: // Difference
          final c1 = companies[_random.nextInt(5)];
          final c2 = companies[(_random.nextInt(5) + 1) % 5];
          final sum1 = data[c1]!.reduce((a, b) => a + b);
          final sum2 = data[c2]!.reduce((a, b) => a + b);
          answer = (sum1 - sum2).abs();
          question = 'What is the difference between total production of $c1 and $c2?';
          explanation = 'Difference = |$sum1 - $sum2| = $answer';
      }
      
      final wrongOptions = _generateWrongNumberOptions(answer, 4);
      final options = <String>[answer.toString()];
      for (final opt in wrongOptions) {
        if (options.length < 4 && !options.contains(opt.toString())) {
          options.add(opt.toString());
        }
      }
      options.shuffle();
      
      questions.add(EnhancedQuestion(
        id: 'banking_di_${i + 1}',
        examType: 'banking',
        subject: 'Quantitative Aptitude',
        topic: 'Data Interpretation',
        question: question,
        options: options,
        correctOptionIndex: options.indexOf(answer.toString()),
        explanation: explanation,
        difficulty: 'medium',
        marks: 1,
        negativeMarks: 0.25,
        timeInSeconds: 90,
        tags: ['data-interpretation', 'table', 'banking', 'quant'],
      ));
    }
    
    return questions;
  }

  // ==================== REASONING ABILITY ====================

  /// Generate Seating Arrangement questions
  static List<EnhancedQuestion> generateSeatingArrangement(int count) {
    final questions = <EnhancedQuestion>[];
    final names = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
    
    for (int i = 0; i < count; i++) {
      // Create a random arrangement
      final arrangement = List<String>.from(names.sublist(0, 8));
      arrangement.shuffle();
      
      // Generate question based on the arrangement
      final pos1 = _random.nextInt(8);
      final pos2 = (pos1 + _random.nextInt(3) + 1) % 8;
      
      final person1 = arrangement[pos1];
      final person2 = arrangement[pos2];
      final personBetween = arrangement[(pos1 + 1) % 8];
      
      final questionType = i % 3;
      String question;
      String answer;
      List<String> options;
      String explanation;
      
      switch (questionType) {
        case 0: // Who sits to the right
          final rightPerson = arrangement[(pos1 + 1) % 8];
          question = 'Eight persons A, B, C, D, E, F, G, and H are sitting in a circle facing the center. '
              '$person1 sits second to the right of $person2. '
              'Who sits immediately to the right of $person1?';
          answer = rightPerson;
          options = [rightPerson, arrangement[(pos1 + 2) % 8], arrangement[(pos1 + 6) % 8], arrangement[(pos1 + 3) % 8]];
          explanation = 'Based on the arrangement, $rightPerson sits immediately to the right of $person1.';
          break;
        case 1: // Position question
          final position = pos1 + 1;
          question = 'Eight persons A, B, C, D, E, F, G, and H are sitting in a row facing north. '
              '$person2 sits at one of the ends. '
              'What is the position of $person1 from the left end?';
          answer = position.toString();
          options = [position.toString(), (position + 1).toString(), (position - 1).toString(), (8 - position + 1).toString()];
          explanation = '$person1 sits at position $position from the left end.';
          break;
        default: // How many between
          final between = ((pos2 - pos1).abs() - 1).clamp(0, 6);
          question = 'Eight persons are sitting in a row. '
              'How many persons are sitting between $person1 and $person2?';
          answer = between.toString();
          options = [between.toString(), (between + 1).toString(), (between - 1).abs().toString(), (between + 2).toString()];
          explanation = 'There are $between persons sitting between $person1 and $person2.';
      }
      
      options = options.toSet().toList();
      while (options.length < 4) {
        options.add(_random.nextInt(7).toString());
      }
      options.shuffle();
      
      questions.add(EnhancedQuestion(
        id: 'banking_seat_${i + 1}',
        examType: 'banking',
        subject: 'Reasoning Ability',
        topic: 'Seating Arrangement',
        question: question,
        options: options,
        correctOptionIndex: options.indexOf(answer),
        explanation: explanation,
        approach: const ProblemSolvingApproach(
          questionType: 'Seating Arrangement',
          conceptRequired: 'Understanding linear and circular arrangements',
          howToRecognize: 'Multiple people, positions, left/right/facing directions',
          thinkingProcess: [
            'Step 1: Draw the arrangement (line for linear, circle for circular)',
            'Step 2: Identify fixed positions first',
            'Step 3: Use relative positions (left of, right of)',
            'Step 4: Place remaining using elimination',
            'Step 5: Verify all conditions',
          ],
          whatToLookFor: 'Fixed positions, relative positions, facing directions',
          commonPatterns: [
            'Linear (row)', 'Circular (facing center/outward)', 'Two rows facing each other'
          ],
          timeManagement: 'Spend 2-3 minutes per set of 5 questions. Draw diagram once, answer all.',
          avoidMistakes: [
            'Verify facing direction affects left/right',
            'In circular: immediate right is clockwise',
            'Count positions carefully',
          ],
        ),
        difficulty: 'medium',
        marks: 1,
        negativeMarks: 0.25,
        timeInSeconds: 120,
        tags: ['seating-arrangement', 'circular', 'linear', 'banking', 'reasoning'],
      ));
    }
    
    return questions;
  }

  /// Generate Syllogism questions
  static List<EnhancedQuestion> generateSyllogism(int count) {
    final questions = <EnhancedQuestion>[];
    final items = ['apples', 'books', 'cars', 'dogs', 'elephants', 'flowers', 'games', 'houses'];
    
    for (int i = 0; i < count; i++) {
      final item1 = items[_random.nextInt(8)];
      final item2 = items[(_random.nextInt(8) + 1) % 8];
      final item3 = items[(_random.nextInt(8) + 2) % 8];
      
      // Generate statements and conclusions
      final stmtType = i % 4;
      String stmt1, stmt2, conclusion1, conclusion2;
      String answer;
      String explanation;
      
      switch (stmtType) {
        case 0: // All-All pattern
          stmt1 = 'All $item1 are $item2.';
          stmt2 = 'All $item2 are $item3.';
          conclusion1 = 'All $item1 are $item3.';
          conclusion2 = 'Some $item3 are $item1.';
          answer = 'Both I and II follow';
          explanation = 'All-All gives All conclusion. Since All $item1 are $item3, Some $item3 are $item1 also follows.';
          break;
        case 1: // Some-All pattern
          stmt1 = 'Some $item1 are $item2.';
          stmt2 = 'All $item2 are $item3.';
          conclusion1 = 'Some $item1 are $item3.';
          conclusion2 = 'All $item3 are $item1.';
          answer = 'Only I follows';
          explanation = 'Some-All gives Some conclusion. "All $item3 are $item1" does not necessarily follow.';
          break;
        case 2: // No-Some pattern
          stmt1 = 'No $item1 is $item2.';
          stmt2 = 'Some $item2 are $item3.';
          conclusion1 = 'Some $item3 are not $item1.';
          conclusion2 = 'All $item3 are $item1.';
          answer = 'Only I follows';
          explanation = 'No-Some gives "Some not" conclusion. "All $item3 are $item1" contradicts statement 1.';
          break;
        default: // All-No pattern
          stmt1 = 'All $item1 are $item2.';
          stmt2 = 'No $item2 is $item3.';
          conclusion1 = 'No $item1 is $item3.';
          conclusion2 = 'Some $item1 are $item3.';
          answer = 'Only I follows';
          explanation = 'All-No gives No conclusion. Conclusion II contradicts conclusion I.';
      }
      
      final options = ['Only I follows', 'Only II follows', 'Both I and II follow', 'Neither I nor II follows'];
      
      questions.add(EnhancedQuestion(
        id: 'banking_syl_${i + 1}',
        examType: 'banking',
        subject: 'Reasoning Ability',
        topic: 'Syllogism',
        question: '''Statements:
1. $stmt1
2. $stmt2

Conclusions:
I. $conclusion1
II. $conclusion2

Which of the following conclusions logically follows?''',
        options: options,
        correctOptionIndex: options.indexOf(answer),
        explanation: explanation,
        approach: const ProblemSolvingApproach(
          questionType: 'Syllogism',
          conceptRequired: 'Venn diagram logic, statement-conclusion relationships',
          howToRecognize: 'Statements with All/Some/No, followed by conclusions to evaluate',
          thinkingProcess: [
            'Step 1: Identify statement types (All/Some/No/Some not)',
            'Step 2: Draw Venn diagrams for statements',
            'Step 3: Check if each conclusion is ALWAYS true',
            'Step 4: A conclusion follows only if true in ALL possible diagrams',
          ],
          whatToLookFor: 'Universal (All/No) vs Particular (Some) statements',
          commonPatterns: [
            'All+All=All', 'All+Some=Some', 'All+No=No', 'Some+All=Some'
          ],
          timeManagement: 'Spend 45-60 seconds per question. Draw Venn diagram quickly.',
          avoidMistakes: [
            '"Some" includes possibility of "All"',
            'Check all possible valid diagrams',
            'Don\'t reverse universal statements',
          ],
        ),
        difficulty: 'medium',
        marks: 1,
        negativeMarks: 0.25,
        timeInSeconds: 60,
        tags: ['syllogism', 'logic', 'banking', 'reasoning'],
      ));
    }
    
    return questions;
  }

  /// Generate Coding-Decoding questions
  static List<EnhancedQuestion> generateCodingDecoding(int count) {
    final questions = <EnhancedQuestion>[];
    
    for (int i = 0; i < count; i++) {
      final patternType = i % 4;
      String question;
      String answer;
      String explanation;
      List<String> options;
      
      switch (patternType) {
        case 0: // +1 shift
          const original = 'BANK';
          const coded = 'CBOL';
          question = 'In a certain code, BANK is written as CBOL. How is LOAN written in that code?';
          answer = 'MPBO';
          explanation = 'Each letter is shifted by +1. L→M, O→P, A→B, N→O';
          options = ['MPBO', 'LPAN', 'MOAN', 'KNZM'];
          break;
        case 1: // -2 shift
          const original = 'MONEY';
          const coded = 'KMLAW';
          question = 'In a certain code, MONEY is written as KMLAW. How is RUPEE written in that code?';
          answer = 'PSRCC';
          explanation = 'Each letter is shifted by -2. R→P, U→S, P→R, E→C, E→C';
          options = ['PSRCC', 'TWRGG', 'PSNCC', 'QTQDD'];
          break;
        case 2: // Reverse alphabet (A=Z, B=Y)
          question = 'In a certain code, EXAM is written as VCVN. How is TEST written in that code?';
          answer = 'GVHG';
          explanation = 'Each letter is replaced by its opposite (A=Z, B=Y... formula: 27-position). T(20)→G(7), E(5)→V(22), S(19)→H(8), T(20)→G(7)';
          options = ['GVHG', 'HVGF', 'FVHG', 'GVFH'];
          break;
        default: // Position-based
          question = 'In a certain code, CAT is written as 3120. How is DOG written in that code?';
          answer = '4157';
          explanation = 'Each letter is replaced by its position (C=3, A=1, T=20). D=4, O=15, G=7';
          options = ['4157', '4175', '4715', '5147'];
      }
      
      options.shuffle();
      
      questions.add(EnhancedQuestion(
        id: 'banking_code_${i + 1}',
        examType: 'banking',
        subject: 'Reasoning Ability',
        topic: 'Coding-Decoding',
        question: question,
        options: options,
        correctOptionIndex: options.indexOf(answer),
        explanation: explanation,
        approach: const ProblemSolvingApproach(
          questionType: 'Coding-Decoding',
          conceptRequired: 'Letter position (A=1 to Z=26), pattern recognition',
          howToRecognize: 'Word coded as another word or numbers',
          thinkingProcess: [
            'Step 1: Write positions of original letters',
            'Step 2: Write positions of coded letters',
            'Step 3: Find difference (coded - original)',
            'Step 4: Check if difference is constant or forms pattern',
            'Step 5: Apply same pattern to question word',
          ],
          whatToLookFor: 'Shift pattern (+1, -2), reverse alphabet, position numbers',
          commonPatterns: [
            '+1 shift', '+2 shift', '-1 shift', 'Reverse alphabet (A↔Z)',
            'Position numbers', 'Vowel/consonant different rules'
          ],
          timeManagement: 'Spend 30-45 seconds. Quick alphabet position recall is key.',
          avoidMistakes: [
            'Remember Z+1 wraps to A',
            'Reverse alphabet: Position + Code = 27',
            'Check if pattern applies to ALL letters',
          ],
        ),
        difficulty: 'easy',
        marks: 1,
        negativeMarks: 0.25,
        timeInSeconds: 45,
        tags: ['coding-decoding', 'pattern', 'banking', 'reasoning'],
      ));
    }
    
    return questions;
  }

  // ==================== ENGLISH LANGUAGE ====================

  /// Generate Reading Comprehension questions
  static List<EnhancedQuestion> generateReadingComprehension(int count) {
    final questions = <EnhancedQuestion>[];
    
    final passages = [
      (
        'The Reserve Bank of India (RBI) recently announced measures to boost digital payments in rural areas. '
        'The initiative aims to increase financial inclusion by providing access to banking services through mobile phones. '
        'Under this scheme, users can transfer up to ₹50,000 per day using basic feature phones. '
        'The RBI expects this to benefit over 100 million people in underserved areas.',
        'RBI Digital Payment Initiative'
      ),
      (
        'Climate change poses significant challenges to agricultural productivity in developing nations. '
        'Rising temperatures and irregular rainfall patterns have led to crop failures and food insecurity. '
        'Experts suggest that sustainable farming practices and drought-resistant crop varieties could mitigate these impacts. '
        'Government subsidies for modern irrigation systems are also recommended.',
        'Climate Change and Agriculture'
      ),
      (
        'The gig economy has transformed the employment landscape globally. '
        'Millions of workers now earn their livelihood through app-based platforms offering flexibility but fewer benefits. '
        'Policymakers are debating whether gig workers should receive social security protections similar to traditional employees. '
        'Recent legislation in several countries has attempted to address this gray area.',
        'Gig Economy Challenges'
      ),
    ];
    
    for (int i = 0; i < count; i++) {
      final passageData = passages[i % passages.length];
      final passage = passageData.$1;
      final topic = passageData.$2;
      
      final qType = i % 3;
      String question;
      String answer;
      List<String> options;
      
      switch (qType) {
        case 0:
          question = 'What is the main focus of the passage?';
          answer = topic;
          options = [topic, 'Banking regulations', 'International trade', 'Stock market trends'];
          break;
        case 1:
          question = 'According to the passage, which of the following is TRUE?';
          answer = 'The passage discusses a contemporary issue';
          options = [
            'The passage discusses a contemporary issue',
            'The topic is irrelevant to current affairs',
            'The information is outdated',
            'The passage is purely fictional'
          ];
          break;
        default:
          question = 'The tone of the passage can best be described as:';
          answer = 'Informative and objective';
          options = [
            'Informative and objective',
            'Highly emotional',
            'Satirical',
            'Completely biased'
          ];
      }
      
      options.shuffle();
      
      questions.add(EnhancedQuestion(
        id: 'banking_rc_${i + 1}',
        examType: 'banking',
        subject: 'English Language',
        topic: 'Reading Comprehension',
        question: 'Read the following passage and answer the question:\n\n"$passage"\n\n$question',
        options: options,
        correctOptionIndex: options.indexOf(answer),
        explanation: 'Based on careful reading of the passage, the correct answer is: $answer',
        difficulty: 'medium',
        marks: 1,
        negativeMarks: 0.25,
        timeInSeconds: 90,
        tags: ['reading-comprehension', 'english', 'banking'],
      ));
    }
    
    return questions;
  }

  /// Generate Cloze Test questions
  static List<EnhancedQuestion> generateClozeTest(int count) {
    final questions = <EnhancedQuestion>[];
    
    final blanks = [
      (
        'The government has _____ several measures to boost economic growth.',
        'implemented',
        ['implemented', 'neglected', 'avoided', 'forgotten']
      ),
      (
        'Banks must _____ strict guidelines while sanctioning loans.',
        'adhere to',
        ['adhere to', 'ignore', 'violate', 'dismiss']
      ),
      (
        'The inflation rate has _____ significantly in the last quarter.',
        'declined',
        ['declined', 'expanded', 'multiplied', 'intensified']
      ),
      (
        'Digital transactions have _____ traditional banking in urban areas.',
        'surpassed',
        ['surpassed', 'followed', 'lagged behind', 'avoided']
      ),
    ];
    
    for (int i = 0; i < count; i++) {
      final data = blanks[i % blanks.length];
      final sentence = data.$1;
      final answer = data.$2;
      final options = List<String>.from(data.$3);
      options.shuffle();
      
      questions.add(EnhancedQuestion(
        id: 'banking_cloze_${i + 1}',
        examType: 'banking',
        subject: 'English Language',
        topic: 'Cloze Test',
        question: 'Fill in the blank with the most appropriate word:\n\n$sentence',
        options: options,
        correctOptionIndex: options.indexOf(answer),
        explanation: 'The correct word is "$answer" as it fits the context grammatically and semantically.',
        difficulty: 'easy',
        marks: 1,
        negativeMarks: 0.25,
        timeInSeconds: 30,
        tags: ['cloze-test', 'vocabulary', 'english', 'banking'],
      ));
    }
    
    return questions;
  }

  // ==================== GENERAL/FINANCIAL AWARENESS ====================

  /// Generate Current Affairs questions
  static List<EnhancedQuestion> generateCurrentAffairs(int count) {
    final questions = <EnhancedQuestion>[];
    
    final qaData = [
      (
        'What is the full form of NEFT?',
        'National Electronic Funds Transfer',
        ['National Electronic Funds Transfer', 'New Electronic File Transfer', 'National E-Finance Technology', 'None of the above']
      ),
      (
        'Which organization regulates the banking sector in India?',
        'Reserve Bank of India',
        ['Reserve Bank of India', 'SEBI', 'Ministry of Finance', 'NABARD']
      ),
      (
        'What is the minimum paid-up capital requirement for Small Finance Banks?',
        '₹200 crore',
        ['₹200 crore', '₹100 crore', '₹500 crore', '₹50 crore']
      ),
      (
        'DICGC provides deposit insurance up to what amount?',
        '₹5 lakh',
        ['₹5 lakh', '₹1 lakh', '₹10 lakh', '₹2 lakh']
      ),
      (
        'What does CRR stand for in banking?',
        'Cash Reserve Ratio',
        ['Cash Reserve Ratio', 'Credit Rating Ratio', 'Capital Reserve Requirement', 'Current Reserve Rate']
      ),
    ];
    
    for (int i = 0; i < count; i++) {
      final data = qaData[i % qaData.length];
      final options = List<String>.from(data.$3);
      options.shuffle();
      
      questions.add(EnhancedQuestion(
        id: 'banking_gk_${i + 1}',
        examType: 'banking',
        subject: 'General Awareness',
        topic: 'Banking Awareness',
        question: data.$1,
        options: options,
        correctOptionIndex: options.indexOf(data.$2),
        explanation: 'The correct answer is "${data.$2}".',
        difficulty: 'easy',
        marks: 1,
        negativeMarks: 0.25,
        timeInSeconds: 30,
        tags: ['banking-awareness', 'gk', 'banking'],
      ));
    }
    
    return questions;
  }

  // ==================== HELPER METHODS ====================

  static List<int> _generateWrongNumberOptions(int correct, int count) {
    final options = <int>[];
    final variations = [
      correct + _random.nextInt(10) + 1,
      correct - _random.nextInt(10) - 1,
      correct + _random.nextInt(20) + 5,
      correct - _random.nextInt(20) - 5,
      (correct * 1.1).round(),
      (correct * 0.9).round(),
    ];
    
    for (final v in variations) {
      if (v != correct && v > 0 && !options.contains(v)) {
        options.add(v);
      }
      if (options.length >= count) break;
    }
    
    return options;
  }

  static int _gcd(int a, int b) {
    while (b != 0) {
      final t = b;
      b = a % b;
      a = t;
    }
    return a;
  }

  /// Generate all banking questions
  static List<EnhancedQuestion> generateAllQuestions() {
    return [
      ...generateNumberSeries(500),
      ...generateSimplification(500),
      ...generateDataInterpretation(500),
      ...generateSeatingArrangement(400),
      ...generateSyllogism(400),
      ...generateCodingDecoding(400),
      ...generateReadingComprehension(300),
      ...generateClozeTest(300),
      ...generateCurrentAffairs(500),
    ];
  }

  /// Get question count
  static int get totalQuestionCount => 3800;
}
