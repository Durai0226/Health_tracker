import 'dart:math';
import '../models/solution_steps.dart';
import 'question_bank_data.dart';

/// Question Templates for generating 30,000+ questions with step-by-step solutions
/// Each template generates parameterized questions across difficulty levels

class QuestionTemplates {
  static final Random _random = Random();

  // ==================== QUANTITATIVE APTITUDE ====================
  
  static List<QuestionBankItem> generateProfitLossQuestions(String category, int count) {
    final questions = <QuestionBankItem>[];
    
    for (int i = 0; i < count; i++) {
      final cp = ((_random.nextInt(20) + 1) * 50); // 50-1000
      final profitPercent = [10, 12, 15, 20, 25][_random.nextInt(5)];
      final sp = (cp * (100 + profitPercent) / 100).round();
      
      final wrongOptions = _generateWrongOptions(sp, 4);
      final options = [sp.toString(), ...wrongOptions.take(3)];
      options.shuffle(_random);
      final correctIndex = options.indexOf(sp.toString());
      
      questions.add(QuestionBankItem(
        id: '${category}_quant_pl_${i.toString().padLeft(5, '0')}',
        question: 'A shopkeeper bought an article for ₹$cp and sold it at $profitPercent% profit. What is the selling price?',
        options: options.map((o) => '₹$o').toList(),
        correctIndex: correctIndex,
        explanation: 'SP = CP × (100 + Profit%) / 100 = $cp × ${100 + profitPercent} / 100 = ₹$sp',
        subjectId: 'quantitative_aptitude',
        topicId: 'profit_loss',
        difficulty: profitPercent > 20 ? 'hard' : (profitPercent > 12 ? 'medium' : 'easy'),
        examCategory: category,
        tags: ['profit-loss', 'basic', category],
        solutionSteps: SolutionSteps(
          approach: 'This is a direct profit percentage problem. When CP and profit% are given, multiply CP by (100 + profit%)/100 to get SP.',
          steps: [
            'Identify given values: CP = ₹$cp, Profit = $profitPercent%',
            'Apply formula: SP = CP × (100 + Profit%) / 100',
            'Substitute: SP = $cp × (100 + $profitPercent) / 100',
            'Simplify: SP = $cp × ${100 + profitPercent} / 100',
            'Calculate: SP = ₹$sp',
          ],
          commonMistake: 'Don\'t add $profitPercent% of SP to CP. Profit% is always calculated on CP.',
          proTip: 'For $profitPercent% profit, multiply CP by ${(100 + profitPercent) / 100}. Memorize common multipliers!',
        ),
        concept: 'Profit & Loss',
        formula: 'SP = CP × (100 + Profit%) / 100',
        shortcut: '$profitPercent% profit → CP × ${(100 + profitPercent) / 100}',
        timeTaken: 45,
      ));
    }
    
    return questions;
  }

  static List<QuestionBankItem> generatePercentageQuestions(String category, int count) {
    final questions = <QuestionBankItem>[];
    
    for (int i = 0; i < count; i++) {
      final total = ((_random.nextInt(10) + 1) * 100); // 100-1000
      final percent = [10, 15, 20, 25, 30, 40, 50][_random.nextInt(7)];
      final answer = (total * percent / 100).round();
      
      final wrongOptions = _generateWrongOptions(answer, 4);
      final optionsList = <String>[answer.toString()];
      optionsList.addAll(wrongOptions.take(3).map((e) => e.toString()));
      optionsList.shuffle(_random);
      final correctIndex = optionsList.indexOf(answer.toString());
      
      questions.add(QuestionBankItem(
        id: '${category}_quant_pct_${i.toString().padLeft(5, '0')}',
        question: 'What is $percent% of $total?',
        options: optionsList,
        correctIndex: correctIndex,
        explanation: '$percent% of $total = $total × $percent / 100 = $answer',
        subjectId: 'quantitative_aptitude',
        topicId: 'percentage',
        difficulty: percent > 30 ? 'medium' : 'easy',
        examCategory: category,
        tags: ['percentage', 'basic', category],
        solutionSteps: SolutionSteps(
          approach: 'To find X% of a number, multiply the number by X/100.',
          steps: [
            'Identify: Find $percent% of $total',
            'Convert percentage to decimal: $percent% = $percent/100 = ${percent / 100}',
            'Multiply: $total × ${percent / 100} = $answer',
          ],
          commonMistake: 'Don\'t confuse "% of" with "% more than". They give different results.',
          proTip: '${percent}% = ${percent / 10}/10. For $total, first find 10% (${total ~/ 10}), then scale.',
        ),
        concept: 'Percentage Calculation',
        formula: 'X% of Y = Y × X / 100',
        shortcut: '$percent% = ${_fractionOf(percent)}',
        timeTaken: 30,
      ));
    }
    
    return questions;
  }

  static List<QuestionBankItem> generateSimpleInterestQuestions(String category, int count) {
    final questions = <QuestionBankItem>[];
    
    for (int i = 0; i < count; i++) {
      final principal = ((_random.nextInt(10) + 1) * 1000); // 1000-10000
      final rate = [5, 6, 8, 10, 12][_random.nextInt(5)];
      final time = [2, 3, 4, 5][_random.nextInt(4)];
      final si = (principal * rate * time / 100).round();
      
      final wrongOptions = _generateWrongOptions(si, 4);
      final options = [si.toString(), ...wrongOptions.take(3)];
      options.shuffle(_random);
      final correctIndex = options.indexOf(si.toString());
      
      questions.add(QuestionBankItem(
        id: '${category}_quant_si_${i.toString().padLeft(5, '0')}',
        question: 'Find the simple interest on ₹$principal at $rate% per annum for $time years.',
        options: options.map((o) => '₹$o').toList(),
        correctIndex: correctIndex,
        explanation: 'SI = P × R × T / 100 = $principal × $rate × $time / 100 = ₹$si',
        subjectId: 'quantitative_aptitude',
        topicId: 'simple_interest',
        difficulty: time > 3 ? 'medium' : 'easy',
        examCategory: category,
        tags: ['simple-interest', 'banking', category],
        solutionSteps: SolutionSteps(
          approach: 'Simple Interest follows the formula SI = PRT/100, where P is principal, R is rate, and T is time.',
          steps: [
            'Identify values: P = ₹$principal, R = $rate%, T = $time years',
            'Apply formula: SI = P × R × T / 100',
            'Substitute: SI = $principal × $rate × $time / 100',
            'Calculate numerator: ${principal * rate * time}',
            'Divide by 100: SI = ₹$si',
          ],
          commonMistake: 'Ensure time is in years. If given in months, divide by 12.',
          proTip: 'For quick calculation: SI for 1 year = P × R / 100. Then multiply by T.',
        ),
        concept: 'Simple Interest',
        formula: 'SI = P × R × T / 100',
        shortcut: 'SI for $rate% per year on ₹$principal = ₹${principal * rate ~/ 100}/year',
        timeTaken: 60,
      ));
    }
    
    return questions;
  }

  static List<QuestionBankItem> generateTimeWorkQuestions(String category, int count) {
    final questions = <QuestionBankItem>[];
    
    for (int i = 0; i < count; i++) {
      final aDays = [10, 12, 15, 20][_random.nextInt(4)];
      final bDays = [15, 20, 24, 30][_random.nextInt(4)];
      // Combined work = 1/aDays + 1/bDays = (aDays + bDays) / (aDays * bDays)
      final lcm = _lcm(aDays, bDays);
      final combined = lcm ~/ (lcm ~/ aDays + lcm ~/ bDays);
      
      final wrongOptions = _generateWrongOptions(combined, 4);
      final options = [combined.toString(), ...wrongOptions.take(3)];
      options.shuffle(_random);
      final correctIndex = options.indexOf(combined.toString());
      
      questions.add(QuestionBankItem(
        id: '${category}_quant_tw_${i.toString().padLeft(5, '0')}',
        question: 'A can complete a work in $aDays days and B can complete the same work in $bDays days. In how many days can they complete it together?',
        options: options.map((o) => '$o days').toList(),
        correctIndex: correctIndex,
        explanation: 'Combined rate = 1/$aDays + 1/$bDays. Time = 1 / Combined rate = $combined days',
        subjectId: 'quantitative_aptitude',
        topicId: 'time_and_work',
        difficulty: 'medium',
        examCategory: category,
        tags: ['time-work', 'work-rate', category],
        solutionSteps: SolutionSteps(
          approach: 'When two people work together, add their individual work rates (work done per day).',
          steps: [
            'A\'s work rate = 1/$aDays work per day',
            'B\'s work rate = 1/$bDays work per day',
            'Combined rate = 1/$aDays + 1/$bDays',
            'Find LCM of $aDays and $bDays = $lcm',
            'Combined rate = ${lcm ~/ aDays}/$lcm + ${lcm ~/ bDays}/$lcm = ${lcm ~/ aDays + lcm ~/ bDays}/$lcm',
            'Time = $lcm / ${lcm ~/ aDays + lcm ~/ bDays} = $combined days',
          ],
          commonMistake: 'Don\'t just average the days. Work rates add, not time.',
          proTip: 'Use LCM method: Take LCM as total work. Calculate each person\'s daily contribution.',
        ),
        concept: 'Time & Work',
        formula: 'Combined Time = (A × B) / (A + B)',
        shortcut: 'LCM method is fastest for this type',
        timeTaken: 90,
      ));
    }
    
    return questions;
  }

  // ==================== REASONING ====================

  static List<QuestionBankItem> generateNumberSeriesQuestions(String category, int count) {
    final questions = <QuestionBankItem>[];
    final patterns = [
      {'name': 'Add constant', 'diff': 3},
      {'name': 'Add constant', 'diff': 5},
      {'name': 'Add constant', 'diff': 7},
      {'name': 'Multiply', 'mult': 2},
      {'name': 'Squares', 'type': 'sq'},
    ];
    
    for (int i = 0; i < count; i++) {
      final pattern = patterns[i % patterns.length];
      List<int> series;
      int answer;
      String explanation;
      SolutionSteps steps;
      
      if (pattern['name'] == 'Add constant') {
        final diff = pattern['diff'] as int;
        final start = _random.nextInt(10) + 1;
        series = List.generate(5, (j) => start + j * diff);
        answer = series.last + diff;
        explanation = 'Each term increases by $diff';
        steps = SolutionSteps(
          approach: 'Find the pattern by checking differences between consecutive terms.',
          steps: [
            'Check differences: ${series[1]} - ${series[0]} = $diff',
            'Verify: ${series[2]} - ${series[1]} = $diff',
            'Pattern: Adding $diff to each term',
            'Next term: ${series.last} + $diff = $answer',
          ],
          commonMistake: 'Always verify the pattern with multiple terms before predicting.',
          proTip: 'For constant difference, answer = last term + difference.',
        );
      } else if (pattern['name'] == 'Multiply') {
        final mult = pattern['mult'] as int;
        final start = _random.nextInt(3) + 1;
        series = List.generate(5, (j) => start * pow(mult, j).toInt());
        answer = series.last * mult;
        explanation = 'Each term is multiplied by $mult';
        steps = SolutionSteps(
          approach: 'Check if each term is a multiple of the previous term.',
          steps: [
            'Check ratio: ${series[1]} / ${series[0]} = $mult',
            'Verify: ${series[2]} / ${series[1]} = $mult',
            'Pattern: Each term × $mult',
            'Next term: ${series.last} × $mult = $answer',
          ],
          commonMistake: 'Distinguish between addition and multiplication patterns.',
          proTip: 'If differences increase rapidly, likely a multiplication pattern.',
        );
      } else {
        final start = _random.nextInt(3) + 1;
        series = List.generate(5, (j) => pow(start + j, 2).toInt());
        answer = pow(start + 5, 2).toInt();
        explanation = 'Series of consecutive squares: ${start}², ${start + 1}²...';
        steps = SolutionSteps(
          approach: 'Check if numbers are perfect squares of consecutive integers.',
          steps: [
            'Check: √${series[0]} = $start, √${series[1]} = ${start + 1}',
            'Pattern: Squares of $start, ${start + 1}, ${start + 2}...',
            'Next: ${start + 5}² = $answer',
          ],
          commonMistake: 'Remember to check for square/cube patterns when differences vary.',
          proTip: 'Know squares 1-20 and cubes 1-10 by heart.',
        );
      }
      
      final wrongOptions = _generateWrongOptions(answer, 4);
      final seriesOptions = <String>[answer.toString()];
      seriesOptions.addAll(wrongOptions.take(3).map((e) => e.toString()));
      seriesOptions.shuffle(_random);
      final correctIndex = seriesOptions.indexOf(answer.toString());
      
      questions.add(QuestionBankItem(
        id: '${category}_reason_ns_${i.toString().padLeft(5, '0')}',
        question: 'Find the next number in the series: ${series.join(", ")}, ?',
        options: seriesOptions,
        correctIndex: correctIndex,
        explanation: explanation,
        subjectId: 'reasoning',
        topicId: 'number_series',
        difficulty: pattern['name'] == 'Squares' ? 'hard' : 'medium',
        examCategory: category,
        tags: ['number-series', 'pattern', category],
        solutionSteps: steps,
        concept: 'Number Series',
        formula: 'Identify pattern → Apply to find next',
        timeTaken: 60,
      ));
    }
    
    return questions;
  }

  // ==================== GENERAL KNOWLEDGE ====================

  static List<QuestionBankItem> generateGKQuestions(String category, int count) {
    final gkData = [
      {
        'q': 'Which planet is known as the Red Planet?',
        'options': ['Mars', 'Venus', 'Jupiter', 'Saturn'],
        'correct': 0,
        'topic': 'astronomy',
        'explanation': 'Mars appears red due to iron oxide (rust) on its surface.',
      },
      {
        'q': 'What is the capital of Australia?',
        'options': ['Sydney', 'Melbourne', 'Canberra', 'Perth'],
        'correct': 2,
        'topic': 'geography',
        'explanation': 'Canberra was purpose-built as the capital, between Sydney and Melbourne.',
      },
      {
        'q': 'Who wrote "Romeo and Juliet"?',
        'options': ['Charles Dickens', 'William Shakespeare', 'Jane Austen', 'Mark Twain'],
        'correct': 1,
        'topic': 'literature',
        'explanation': 'Shakespeare wrote this tragedy around 1594-1596.',
      },
      {
        'q': 'What is the chemical symbol for Gold?',
        'options': ['Go', 'Gd', 'Au', 'Ag'],
        'correct': 2,
        'topic': 'chemistry',
        'explanation': 'Au comes from Latin "Aurum" meaning gold.',
      },
      {
        'q': 'Which is the largest ocean on Earth?',
        'options': ['Atlantic Ocean', 'Indian Ocean', 'Pacific Ocean', 'Arctic Ocean'],
        'correct': 2,
        'topic': 'geography',
        'explanation': 'Pacific Ocean covers about 63 million square miles.',
      },
    ];
    
    final questions = <QuestionBankItem>[];
    
    for (int i = 0; i < count && i < gkData.length; i++) {
      final data = gkData[i];
      questions.add(QuestionBankItem(
        id: '${category}_gk_${i.toString().padLeft(5, '0')}',
        question: data['q'] as String,
        options: List<String>.from(data['options'] as List),
        correctIndex: data['correct'] as int,
        explanation: data['explanation'] as String,
        subjectId: 'general_knowledge',
        topicId: data['topic'] as String,
        difficulty: 'easy',
        examCategory: category,
        tags: ['gk', data['topic'] as String, category],
        solutionSteps: SolutionSteps(
          approach: 'This is a factual recall question. Know the key fact.',
          steps: [
            'Recall: ${data['explanation']}',
            'Answer: ${(data['options'] as List)[data['correct'] as int]}',
          ],
          proTip: 'Create memory associations for better recall.',
        ),
        concept: 'General Knowledge - ${data['topic']}',
        timeTaken: 30,
      ));
    }
    
    return questions;
  }

  // ==================== HELPER METHODS ====================

  static List<int> _generateWrongOptions(int correct, int count) {
    final options = <int>[];
    final variations = [-20, -15, -10, -5, 5, 10, 15, 20];
    variations.shuffle(_random);
    
    for (final v in variations) {
      final wrong = correct + v;
      if (wrong > 0 && wrong != correct && !options.contains(wrong)) {
        options.add(wrong);
        if (options.length >= count) break;
      }
    }
    
    return options;
  }

  static String _fractionOf(int percent) {
    final fractions = {
      10: '1/10',
      15: '3/20',
      20: '1/5',
      25: '1/4',
      30: '3/10',
      40: '2/5',
      50: '1/2',
    };
    return fractions[percent] ?? '$percent/100';
  }

  static int _lcm(int a, int b) {
    return (a * b) ~/ _gcd(a, b);
  }

  static int _gcd(int a, int b) {
    while (b != 0) {
      final t = b;
      b = a % b;
      a = t;
    }
    return a;
  }

  // ==================== ADDITIONAL QUANT TOPICS ====================
  
  static List<QuestionBankItem> generateRatioProportionQuestions(String category, int count) {
    final questions = <QuestionBankItem>[];
    
    for (int i = 0; i < count; i++) {
      final a = _random.nextInt(5) + 2;
      final b = _random.nextInt(5) + 2;
      final total = (a + b) * (_random.nextInt(10) + 5);
      final partA = (total * a / (a + b)).round();
      // partB = total - partA (not needed for this question)
      
      final wrongOptions = _generateWrongOptions(partA, 4);
      final options = <String>[partA.toString()];
      options.addAll(wrongOptions.take(3).map((e) => e.toString()));
      options.shuffle(_random);
      final correctIndex = options.indexOf(partA.toString());
      
      questions.add(QuestionBankItem(
        id: '${category}_quant_ratio_${i.toString().padLeft(5, '0')}',
        question: 'If ₹$total is divided in ratio $a:$b, what is the larger share?',
        options: options.map((o) => '₹$o').toList(),
        correctIndex: correctIndex,
        explanation: 'Total parts = $a + $b = ${a + b}. Larger share = $total × $a / ${a + b} = ₹$partA',
        subjectId: 'quantitative_aptitude',
        topicId: 'ratio_proportion',
        difficulty: total > 100 ? 'medium' : 'easy',
        examCategory: category,
        tags: ['ratio', 'proportion', category],
        solutionSteps: SolutionSteps(
          approach: 'Divide total by sum of ratio parts, then multiply by required part.',
          steps: [
            'Sum of ratio parts = $a + $b = ${a + b}',
            'Value of 1 part = $total ÷ ${a + b} = ${total ~/ (a + b)}',
            'Larger share ($a parts) = ${total ~/ (a + b)} × $a = ₹$partA',
          ],
          commonMistake: 'Don\'t confuse ratio parts with actual values.',
          proTip: 'For ratio a:b with total T, parts are T×a/(a+b) and T×b/(a+b)',
        ),
        concept: 'Ratio & Proportion',
        formula: 'Share = Total × Part / Sum of Parts',
        timeTaken: 40,
      ));
    }
    return questions;
  }

  static List<QuestionBankItem> generateAverageQuestions(String category, int count) {
    final questions = <QuestionBankItem>[];
    
    for (int i = 0; i < count; i++) {
      final n = _random.nextInt(4) + 3;
      final base = (_random.nextInt(10) + 1) * 10;
      final numbers = List.generate(n, (j) => base + _random.nextInt(20) - 10);
      final sum = numbers.reduce((a, b) => a + b);
      final avg = (sum / n).round();
      
      final wrongOptions = _generateWrongOptions(avg, 4);
      final options = <String>[avg.toString()];
      options.addAll(wrongOptions.take(3).map((e) => e.toString()));
      options.shuffle(_random);
      final correctIndex = options.indexOf(avg.toString());
      
      questions.add(QuestionBankItem(
        id: '${category}_quant_avg_${i.toString().padLeft(5, '0')}',
        question: 'Find the average of: ${numbers.join(", ")}',
        options: options,
        correctIndex: correctIndex,
        explanation: 'Sum = $sum, Count = $n, Average = $sum ÷ $n = $avg',
        subjectId: 'quantitative_aptitude',
        topicId: 'average',
        difficulty: n > 4 ? 'medium' : 'easy',
        examCategory: category,
        tags: ['average', 'arithmetic', category],
        solutionSteps: SolutionSteps(
          approach: 'Add all numbers and divide by count.',
          steps: [
            'Sum = ${numbers.join(" + ")} = $sum',
            'Count of numbers = $n',
            'Average = Sum ÷ Count = $sum ÷ $n = $avg',
          ],
          commonMistake: 'Ensure you count all numbers correctly.',
          proTip: 'For quick calculation, estimate from middle value.',
        ),
        concept: 'Averages',
        formula: 'Average = Sum / Count',
        timeTaken: 35,
      ));
    }
    return questions;
  }

  static List<QuestionBankItem> generateSpeedDistanceQuestions(String category, int count) {
    final questions = <QuestionBankItem>[];
    
    for (int i = 0; i < count; i++) {
      final speed = [30, 40, 50, 60, 72, 80, 90][_random.nextInt(7)];
      final time = [2, 3, 4, 5, 6][_random.nextInt(5)];
      final distance = speed * time;
      
      final wrongOptions = _generateWrongOptions(distance, 4);
      final options = <String>[distance.toString()];
      options.addAll(wrongOptions.take(3).map((e) => e.toString()));
      options.shuffle(_random);
      final correctIndex = options.indexOf(distance.toString());
      
      questions.add(QuestionBankItem(
        id: '${category}_quant_spd_${i.toString().padLeft(5, '0')}',
        question: 'A car travels at $speed km/hr for $time hours. What distance does it cover?',
        options: options.map((o) => '$o km').toList(),
        correctIndex: correctIndex,
        explanation: 'Distance = Speed × Time = $speed × $time = $distance km',
        subjectId: 'quantitative_aptitude',
        topicId: 'speed_distance_time',
        difficulty: speed > 60 ? 'medium' : 'easy',
        examCategory: category,
        tags: ['speed', 'distance', 'time', category],
        solutionSteps: SolutionSteps(
          approach: 'Apply the formula Distance = Speed × Time directly.',
          steps: [
            'Given: Speed = $speed km/hr, Time = $time hours',
            'Apply formula: Distance = Speed × Time',
            'Distance = $speed × $time = $distance km',
          ],
          commonMistake: 'Check units - speed in km/hr, time in hours gives distance in km.',
          proTip: 'Remember: D = S × T, S = D/T, T = D/S',
        ),
        concept: 'Speed, Distance & Time',
        formula: 'Distance = Speed × Time',
        timeTaken: 30,
      ));
    }
    return questions;
  }

  static List<QuestionBankItem> generateCompoundInterestQuestions(String category, int count) {
    final questions = <QuestionBankItem>[];
    
    for (int i = 0; i < count; i++) {
      final p = [1000, 2000, 5000, 10000][_random.nextInt(4)];
      final r = [5, 10, 12, 15, 20][_random.nextInt(5)];
      final t = [1, 2][_random.nextInt(2)];
      final amount = (p * pow(1 + r / 100, t)).round();
      final ci = amount - p;
      
      final wrongOptions = _generateWrongOptions(ci, 4);
      final options = <String>[ci.toString()];
      options.addAll(wrongOptions.take(3).map((e) => e.toString()));
      options.shuffle(_random);
      final correctIndex = options.indexOf(ci.toString());
      
      questions.add(QuestionBankItem(
        id: '${category}_quant_ci_${i.toString().padLeft(5, '0')}',
        question: 'Find compound interest on ₹$p at $r% p.a. for $t year${t > 1 ? "s" : ""}, compounded annually.',
        options: options.map((o) => '₹$o').toList(),
        correctIndex: correctIndex,
        explanation: 'A = P(1+R/100)^T = $p(1+$r/100)^$t = ₹$amount. CI = A - P = ₹$ci',
        subjectId: 'quantitative_aptitude',
        topicId: 'compound_interest',
        difficulty: t > 1 ? 'hard' : 'medium',
        examCategory: category,
        tags: ['compound-interest', 'banking', category],
        solutionSteps: SolutionSteps(
          approach: 'Use CI formula: A = P(1 + R/100)^T, then CI = A - P',
          steps: [
            'Given: P = ₹$p, R = $r%, T = $t year${t > 1 ? "s" : ""}',
            'Amount A = P × (1 + R/100)^T',
            'A = $p × (1 + $r/100)^$t = $p × ${(1 + r / 100).toStringAsFixed(2)}^$t',
            'A = ₹$amount',
            'CI = A - P = $amount - $p = ₹$ci',
          ],
          commonMistake: 'Don\'t confuse CI with SI. CI compounds year over year.',
          proTip: 'For 2 years: CI = SI + SI²/100/P',
        ),
        concept: 'Compound Interest',
        formula: 'A = P(1 + R/100)^T, CI = A - P',
        timeTaken: 60,
      ));
    }
    return questions;
  }

  // ==================== ADDITIONAL REASONING TOPICS ====================

  static List<QuestionBankItem> generateCodingDecodingQuestions(String category, int count) {
    final questions = <QuestionBankItem>[];
    for (int i = 0; i < count; i++) {
      final word = ['CAT', 'DOG', 'PEN', 'SUN', 'BOX', 'MAP'][_random.nextInt(6)];
      final shift = _random.nextInt(3) + 1;
      final coded = String.fromCharCodes(word.codeUnits.map((c) => c + shift));
      
      final options = <String>[coded];
      for (int j = 1; j <= 3; j++) {
        options.add(String.fromCharCodes(word.codeUnits.map((c) => c + shift + j)));
      }
      options.shuffle(_random);
      final correctIndex = options.indexOf(coded);
      
      questions.add(QuestionBankItem(
        id: '${category}_reason_cd_${i.toString().padLeft(5, '0')}',
        question: 'If each letter is replaced by the letter $shift position(s) ahead, how is "$word" coded?',
        options: options,
        correctIndex: correctIndex,
        explanation: 'Each letter moves $shift positions: ${word.split("").map((c) => "$c→${String.fromCharCode(c.codeUnitAt(0) + shift)}").join(", ")}',
        subjectId: 'reasoning',
        topicId: 'coding_decoding',
        difficulty: shift > 2 ? 'medium' : 'easy',
        examCategory: category,
        tags: ['coding', 'decoding', 'verbal-reasoning', category],
        solutionSteps: SolutionSteps(
          approach: 'Shift each letter by $shift positions in the alphabet.',
          steps: word.split("").map((c) => '$c + $shift = ${String.fromCharCode(c.codeUnitAt(0) + shift)}').toList(),
          commonMistake: 'Watch out for letters near Z that wrap around.',
          proTip: 'Write A-Z with positions 1-26 for quick reference.',
        ),
        concept: 'Coding-Decoding',
        formula: 'New letter = Old letter + Shift',
        timeTaken: 45,
      ));
    }
    return questions;
  }

  static List<QuestionBankItem> generateBloodRelationQuestions(String category, int count) {
    final questions = <QuestionBankItem>[];
    final relations = [
      {'q': "A's father's son is B. How is B related to A?", 'a': 'Brother', 'opts': ['Brother', 'Father', 'Uncle', 'Cousin']},
      {'q': "A's mother's daughter is B. How is B related to A?", 'a': 'Sister', 'opts': ['Sister', 'Mother', 'Aunt', 'Cousin']},
      {'q': "A's father's father is B. How is B related to A?", 'a': 'Grandfather', 'opts': ['Grandfather', 'Father', 'Uncle', 'Brother']},
      {'q': "A's mother's mother is B. How is B related to A?", 'a': 'Grandmother', 'opts': ['Grandmother', 'Mother', 'Aunt', 'Sister']},
      {'q': "A's father's brother is B. How is B related to A?", 'a': 'Uncle', 'opts': ['Uncle', 'Father', 'Brother', 'Cousin']},
    ];
    
    for (int i = 0; i < count; i++) {
      final rel = relations[i % relations.length];
      final options = List<String>.from(rel['opts'] as List);
      options.shuffle(_random);
      final correctIndex = options.indexOf(rel['a'] as String);
      
      questions.add(QuestionBankItem(
        id: '${category}_reason_br_${i.toString().padLeft(5, '0')}',
        question: rel['q'] as String,
        options: options,
        correctIndex: correctIndex,
        explanation: 'Following the family tree: ${rel['a']}',
        subjectId: 'reasoning',
        topicId: 'blood_relations',
        difficulty: 'easy',
        examCategory: category,
        tags: ['blood-relations', 'family-tree', category],
        solutionSteps: SolutionSteps(
          approach: 'Draw a family tree diagram to trace the relationship.',
          steps: ['Start from A', 'Follow the relationship chain', 'Identify B\'s position', 'Answer: ${rel['a']}'],
          commonMistake: 'Don\'t assume gender - "son" could be brother if same parents.',
          proTip: 'Always draw a family tree for complex problems.',
        ),
        concept: 'Blood Relations',
        timeTaken: 40,
      ));
    }
    return questions;
  }

  static List<QuestionBankItem> generateDirectionQuestions(String category, int count) {
    final questions = <QuestionBankItem>[];
    
    for (int i = 0; i < count; i++) {
      final d1 = _random.nextInt(10) + 5;
      final d2 = _random.nextInt(10) + 5;
      final total = d1 + d2;
      
      final options = <String>['$total km'];
      options.addAll(['${total + 5} km', '${total - 3} km', '${d1 * 2} km']);
      options.shuffle(_random);
      final correctIndex = options.indexOf('$total km');
      
      questions.add(QuestionBankItem(
        id: '${category}_reason_dir_${i.toString().padLeft(5, '0')}',
        question: 'A man walks $d1 km North, then $d2 km more North. How far is he from the starting point?',
        options: options,
        correctIndex: correctIndex,
        explanation: 'Same direction: Total = $d1 + $d2 = $total km',
        subjectId: 'reasoning',
        topicId: 'direction_sense',
        difficulty: 'easy',
        examCategory: category,
        tags: ['direction', 'distance', category],
        solutionSteps: SolutionSteps(
          approach: 'Add distances when moving in same direction.',
          steps: ['First move: $d1 km North', 'Second move: $d2 km North', 'Total from start = $d1 + $d2 = $total km'],
          commonMistake: 'Opposite directions cancel out, same directions add up.',
          proTip: 'Draw a diagram with cardinal directions.',
        ),
        concept: 'Direction Sense',
        formula: 'Same direction: Add distances',
        timeTaken: 35,
      ));
    }
    return questions;
  }

  // ==================== BULK GENERATION ====================

  /// Generate all questions for a category (targeting 3,750+ per category for 30,000+ total)
  static List<QuestionBankItem> generateCategoryQuestions(String category, {int questionsPerTopic = 100}) {
    final questions = <QuestionBankItem>[];
    
    // Quantitative Aptitude (8 topics × questionsPerTopic)
    questions.addAll(generateProfitLossQuestions(category, questionsPerTopic));
    questions.addAll(generatePercentageQuestions(category, questionsPerTopic));
    questions.addAll(generateSimpleInterestQuestions(category, questionsPerTopic));
    questions.addAll(generateTimeWorkQuestions(category, questionsPerTopic));
    questions.addAll(generateRatioProportionQuestions(category, questionsPerTopic));
    questions.addAll(generateAverageQuestions(category, questionsPerTopic));
    questions.addAll(generateSpeedDistanceQuestions(category, questionsPerTopic));
    questions.addAll(generateCompoundInterestQuestions(category, questionsPerTopic));
    
    // Reasoning (4 topics × questionsPerTopic)
    questions.addAll(generateNumberSeriesQuestions(category, questionsPerTopic));
    questions.addAll(generateCodingDecodingQuestions(category, questionsPerTopic));
    questions.addAll(generateBloodRelationQuestions(category, questionsPerTopic));
    questions.addAll(generateDirectionQuestions(category, questionsPerTopic));
    
    // General Knowledge
    questions.addAll(generateGKQuestions(category, 100));
    
    return questions;
  }

  /// Generate all 30,000+ questions across all categories
  static Map<String, List<QuestionBankItem>> generateAllQuestions() {
    final categories = ['banking', 'ssc', 'upsc', 'jee', 'neet', 'cat', 'gate', 'clat'];
    final allQuestions = <String, List<QuestionBankItem>>{};
    
    for (final category in categories) {
      allQuestions[category] = generateCategoryQuestions(category, questionsPerTopic: 470);
    }
    
    return allQuestions;
  }
}
