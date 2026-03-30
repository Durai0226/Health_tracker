/// Quantitative Aptitude Thinking Guides
/// Complete problem-solving methodology for all quant question types

import '../../models/problem_solving_approach.dart';

class QuantThinkingGuides {
  // ==================== PERCENTAGE ====================
  static const percentage = ThinkingGuide(
    questionType: 'Percentage',
    subject: 'Quantitative Aptitude',
    description: 'Problems involving percent calculations, increase/decrease, successive changes',
    recognitionPatterns: [
      RecognitionPattern(
        pattern: 'Basic percentage calculation',
        indicator: 'Find X% of Y or Y is what % of X',
        keywords: ['% of', 'what percent', 'percentage', 'out of 100'],
      ),
      RecognitionPattern(
        pattern: 'Percentage increase/decrease',
        indicator: 'Value changes by some percent',
        keywords: ['increased by', 'decreased by', 'more than', 'less than', 'rise', 'fall'],
      ),
      RecognitionPattern(
        pattern: 'Successive percentage change',
        indicator: 'Multiple percentage changes one after another',
        keywords: ['first increased then decreased', 'successive', 'two increases', 'compound'],
      ),
    ],
    mentalFramework: [
      '1. Identify what is the base (100%)',
      '2. Convert percentage to fraction for quick calculation',
      '3. For successive changes, use net effect formula',
      '4. Remember: X% increase then X% decrease ≠ original',
      '5. Use fraction equivalents for speed',
    ],
    keyObservations: [
      'Base value is crucial - percentage is always OF something',
      '10% = 1/10, 20% = 1/5, 25% = 1/4, 50% = 1/2',
      'Increase of X% means multiply by (1 + X/100)',
      'Decrease of X% means multiply by (1 - X/100)',
      'Successive changes: Net = a + b + ab/100',
    ],
    strategies: [
      StrategyOption(
        name: 'Fraction Method',
        description: 'Convert percentages to fractions',
        whenToUse: 'For quick mental calculation',
        steps: [
          '10% = 1/10 (divide by 10)',
          '25% = 1/4 (divide by 4)',
          '33.33% = 1/3 (divide by 3)',
          '12.5% = 1/8 (divide by 8)',
          'Combine fractions for complex %',
        ],
      ),
      StrategyOption(
        name: 'Base 100 Method',
        description: 'Assume base value as 100',
        whenToUse: 'When actual values not given',
        steps: [
          'Let original = 100',
          'Apply percentage change',
          'Calculate new value',
          'Find required percentage from new value',
        ],
      ),
      StrategyOption(
        name: 'Successive Change Formula',
        description: 'Net effect of multiple changes',
        whenToUse: 'When value changes multiple times',
        steps: [
          'Net change = a + b + (ab/100)',
          'Where a and b are percentage changes',
          'Use negative sign for decrease',
          'Example: +10% then -10% = 10 - 10 - 1 = -1%',
        ],
      ),
    ],
    executionSteps: [
      'Step 1: Identify the base value (what is 100%)',
      'Step 2: Identify what percentage change or calculation needed',
      'Step 3: Convert to fraction if possible',
      'Step 4: Apply calculation',
      'Step 5: For successive changes, use formula',
      'Step 6: Convert back to percentage if needed',
    ],
    verificationMethods: [
      'Reverse calculate to verify',
      'Check if percentage makes sense (can\'t exceed 100% in many cases)',
      'Use approximation to verify range',
    ],
    commonMistakes: [
      CommonMistake(
        mistake: 'Wrong base for percentage',
        why: '20% of 50 is different from 50% of 20 (though equal mathematically)',
        howToAvoid: 'Always identify what is the BASE before calculating',
      ),
      CommonMistake(
        mistake: 'Assuming successive % cancels out',
        why: '10% increase then 10% decrease ≠ original (it\'s 1% less)',
        howToAvoid: 'Use successive change formula: a + b + ab/100',
      ),
      CommonMistake(
        mistake: 'Confusing percentage OF vs percentage MORE',
        why: 'A is 20% of B vs A is 20% more than B are different',
        howToAvoid: '20% more = 120% of original',
      ),
    ],
    shortcuts: [
      '10% = ÷10, 1% = ÷100, 5% = ÷20',
      '15% = 10% + 5% = 10% + half of 10%',
      '12.5% = 1/8 = half of 25%',
      '33.33% = 1/3, 66.67% = 2/3',
      'To find what % A is of B: (A/B) × 100',
    ],
    averageTime: 45,
  );

  // ==================== PROFIT & LOSS ====================
  static const profitLoss = ThinkingGuide(
    questionType: 'Profit & Loss',
    subject: 'Quantitative Aptitude',
    description: 'Problems involving cost price, selling price, profit/loss percentage',
    recognitionPatterns: [
      RecognitionPattern(
        pattern: 'Basic profit/loss',
        indicator: 'Find profit/loss amount or percentage',
        keywords: ['cost price', 'selling price', 'profit', 'loss', 'CP', 'SP'],
      ),
      RecognitionPattern(
        pattern: 'Marked price and discount',
        indicator: 'Involves marked price, discount, and final SP',
        keywords: ['marked price', 'discount', 'MP', 'list price'],
      ),
      RecognitionPattern(
        pattern: 'Successive profit/loss',
        indicator: 'Multiple transactions or middlemen',
        keywords: ['sells to', 'buys from', 'overall profit'],
      ),
    ],
    mentalFramework: [
      '1. Identify CP, SP, MP clearly',
      '2. Profit% and Loss% always on CP',
      '3. Discount% always on MP',
      '4. SP = MP - Discount',
      '5. Profit = SP - CP',
    ],
    keyObservations: [
      'Profit% = (Profit/CP) × 100',
      'Loss% = (Loss/CP) × 100',
      'SP = CP × (100 + Profit%)/100',
      'SP = CP × (100 - Loss%)/100',
      'Discount% = (Discount/MP) × 100',
    ],
    strategies: [
      StrategyOption(
        name: 'Ratio Method',
        description: 'Use CP:SP ratio for quick calculation',
        whenToUse: 'When percentage is given',
        steps: [
          '20% profit: CP:SP = 100:120 = 5:6',
          '25% profit: CP:SP = 100:125 = 4:5',
          '20% loss: CP:SP = 100:80 = 5:4',
          'Use ratio to find unknown value',
        ],
      ),
      StrategyOption(
        name: 'Assume CP = 100',
        description: 'Let CP be 100 for easy calculation',
        whenToUse: 'When actual values not given',
        steps: [
          'Let CP = 100',
          'Calculate SP based on profit/loss%',
          'For discount, let MP be a suitable value',
          'Find required percentage or value',
        ],
      ),
    ],
    executionSteps: [
      'Step 1: Identify what is given (CP, SP, MP, profit%, discount%)',
      'Step 2: Write down formulas needed',
      'Step 3: If % given, use ratio or assume CP = 100',
      'Step 4: Calculate required value',
      'Step 5: Verify by reverse calculation',
    ],
    verificationMethods: [
      'Check: SP > CP means profit, SP < CP means loss',
      'Verify: Profit% on CP, Discount% on MP',
      'Cross-verify with given values',
    ],
    commonMistakes: [
      CommonMistake(
        mistake: 'Calculating profit% on SP',
        why: 'Profit% must always be calculated on Cost Price',
        howToAvoid: 'Remember: Profit% = (Profit/CP) × 100, NOT Profit/SP',
      ),
      CommonMistake(
        mistake: 'Confusing MP with SP',
        why: 'SP = MP - Discount, not equal to MP',
        howToAvoid: 'SP comes AFTER applying discount on MP',
      ),
      CommonMistake(
        mistake: 'Wrong overall profit in chain selling',
        why: 'Cannot simply add individual profits',
        howToAvoid: 'Calculate final SP/initial CP for overall profit',
      ),
    ],
    shortcuts: [
      'CP:SP for common %: 10%=10:11, 20%=5:6, 25%=4:5, 50%=2:3',
      'For loss: 10%=10:9, 20%=5:4, 25%=4:3',
      'If SP is same for profit & loss: Net = Loss (always)',
      'False weight profit% = (True-False)/False × 100',
    ],
    averageTime: 60,
  );

  // ==================== SIMPLE & COMPOUND INTEREST ====================
  static const interest = ThinkingGuide(
    questionType: 'Interest',
    subject: 'Quantitative Aptitude',
    description: 'Problems involving simple and compound interest calculations',
    recognitionPatterns: [
      RecognitionPattern(
        pattern: 'Simple Interest',
        indicator: 'Interest calculated on principal only',
        keywords: ['simple interest', 'SI', 'per annum'],
      ),
      RecognitionPattern(
        pattern: 'Compound Interest',
        indicator: 'Interest on interest',
        keywords: ['compound interest', 'CI', 'compounded annually', 'compounded half-yearly'],
      ),
      RecognitionPattern(
        pattern: 'Difference between CI and SI',
        indicator: 'Find difference for same principal and time',
        keywords: ['difference', 'CI - SI', 'CI exceeds SI'],
      ),
    ],
    mentalFramework: [
      '1. Identify SI or CI problem',
      '2. Note the compounding frequency',
      '3. SI = PRT/100, CI = P(1+R/100)^T - P',
      '4. For 2 years: CI - SI = P(R/100)²',
      '5. Use compound ratio for CI',
    ],
    keyObservations: [
      'SI is same every year',
      'CI increases each year',
      'CI - SI for 2 years = SI for 1 year × R/100',
      'Amount = Principal + Interest',
      'Half-yearly: Rate = R/2, Time = 2T',
    ],
    strategies: [
      StrategyOption(
        name: 'Formula Method',
        description: 'Direct formula application',
        whenToUse: 'For straightforward problems',
        steps: [
          'SI = (P × R × T)/100',
          'CI = P(1 + R/100)^T - P',
          'Amount = P + Interest',
          'Use correct time and rate units',
        ],
      ),
      StrategyOption(
        name: 'Ratio Method for CI',
        description: 'Use ratio of amounts in successive years',
        whenToUse: 'When finding rate or comparing years',
        steps: [
          'At R%, amount after each year forms GP',
          'A1 : A2 = 100 : (100+R)',
          'A2 : A3 = 100 : (100+R)',
          'Use ratio to find unknowns',
        ],
      ),
      StrategyOption(
        name: 'CI-SI Difference Formula',
        description: 'Quick formula for difference',
        whenToUse: 'When asked about CI-SI difference',
        steps: [
          'For 2 years: CI - SI = P × (R/100)²',
          'For 3 years: CI - SI = P × (R/100)² × (3 + R/100)',
          'Memorize for quick solving',
        ],
      ),
    ],
    executionSteps: [
      'Step 1: Identify SI or CI problem',
      'Step 2: Note P, R, T and units',
      'Step 3: Check compounding frequency',
      'Step 4: Apply appropriate formula',
      'Step 5: Calculate step by step',
      'Step 6: Verify units and answer',
    ],
    verificationMethods: [
      'CI should always be > SI for T > 1',
      'Amount = P + Interest',
      'Check compounding frequency adjustment',
    ],
    commonMistakes: [
      CommonMistake(
        mistake: 'Wrong compounding frequency',
        why: 'Half-yearly means R/2 and 2T',
        howToAvoid: 'Quarterly: R/4, 4T. Monthly: R/12, 12T',
      ),
      CommonMistake(
        mistake: 'Confusing Amount with Interest',
        why: 'Amount = P + Interest',
        howToAvoid: 'Interest = Amount - Principal',
      ),
      CommonMistake(
        mistake: 'Using SI formula for CI',
        why: 'CI formula has exponential, SI is linear',
        howToAvoid: 'Check keywords: "compounded" = CI',
      ),
    ],
    shortcuts: [
      'For 2 years at R%: CI = 2R + R²/100 (as % of P)',
      'CI - SI for 2 years = P(R/100)²',
      'If SI = CI for 1 year (always true)',
      'Amount doubles: T = 72/R years (approx)',
      'Rule of 72 for doubling time',
    ],
    averageTime: 60,
  );

  // ==================== TIME & WORK ====================
  static const timeWork = ThinkingGuide(
    questionType: 'Time & Work',
    subject: 'Quantitative Aptitude',
    description: 'Problems involving work done by people/machines in given time',
    recognitionPatterns: [
      RecognitionPattern(
        pattern: 'Individual work rate',
        indicator: 'A completes work in X days',
        keywords: ['completes in', 'can do in', 'finishes in', 'days', 'hours'],
      ),
      RecognitionPattern(
        pattern: 'Combined work',
        indicator: 'Multiple people working together',
        keywords: ['together', 'working simultaneously', 'A and B', 'combined'],
      ),
      RecognitionPattern(
        pattern: 'Efficiency comparison',
        indicator: 'One is more efficient than another',
        keywords: ['twice as fast', 'more efficient', 'efficiency ratio'],
      ),
    ],
    mentalFramework: [
      '1. Convert time to work rate (work/day)',
      '2. If A does in n days, rate = 1/n per day',
      '3. Combined rate = sum of individual rates',
      '4. Time = Work / Combined Rate',
      '5. Use LCM for easy calculation',
    ],
    keyObservations: [
      'Work done = Rate × Time',
      'If A does in 10 days, A\'s rate = 1/10 per day',
      'A+B rate = 1/a + 1/b per day',
      'LCM method: Total work = LCM of days',
      'More people = Less time (inverse proportion)',
    ],
    strategies: [
      StrategyOption(
        name: 'LCM Method',
        description: 'Assume total work as LCM of given days',
        whenToUse: 'When multiple workers with different days',
        steps: [
          'Find LCM of all given days',
          'Total work = LCM units',
          'Each person\'s rate = LCM/their days',
          'Combined rate = sum of rates',
          'Time = Total work / Combined rate',
        ],
      ),
      StrategyOption(
        name: 'Fraction Method',
        description: 'Work with fractions directly',
        whenToUse: 'When LCM is not convenient',
        steps: [
          'A\'s 1 day work = 1/a',
          'B\'s 1 day work = 1/b',
          'Together = 1/a + 1/b = (a+b)/ab per day',
          'Days to complete = ab/(a+b)',
        ],
      ),
      StrategyOption(
        name: 'Efficiency Ratio',
        description: 'Compare efficiencies as ratio',
        whenToUse: 'When efficiency comparison given',
        steps: [
          'Efficiency ∝ 1/Time',
          'A twice as efficient: A:B = 2:1',
          'If B takes 20 days, A takes 10 days',
          'Convert to work rates and solve',
        ],
      ),
    ],
    executionSteps: [
      'Step 1: Identify all workers and their individual times',
      'Step 2: Find LCM of all times (= total work units)',
      'Step 3: Calculate each worker\'s rate (units/day)',
      'Step 4: Find combined rate if working together',
      'Step 5: Time = Total work / Rate',
      'Step 6: Handle partial work if needed',
    ],
    verificationMethods: [
      'Combined time should be less than individual times',
      'Verify: Work = Rate × Time = 1 (complete work)',
      'Check units consistency',
    ],
    commonMistakes: [
      CommonMistake(
        mistake: 'Adding days instead of rates',
        why: 'A in 10 days + B in 20 days ≠ 30 days together',
        howToAvoid: 'Add RATES (1/10 + 1/20), not days',
      ),
      CommonMistake(
        mistake: 'Wrong efficiency interpretation',
        why: 'Twice efficient = half the time, not double',
        howToAvoid: 'Efficiency ∝ 1/Time',
      ),
      CommonMistake(
        mistake: 'Ignoring partial work',
        why: 'When someone leaves midway',
        howToAvoid: 'Calculate work done before leaving, then remaining',
      ),
    ],
    shortcuts: [
      'A in a days, B in b days: Together = ab/(a+b) days',
      'If efficiency A:B = m:n, Time A:B = n:m',
      '1 man = 2 women (if given), convert to same unit',
      'Pipes: Filling = positive rate, Emptying = negative',
    ],
    averageTime: 75,
  );

  // ==================== RATIO & PROPORTION ====================
  static const ratioProportion = ThinkingGuide(
    questionType: 'Ratio & Proportion',
    subject: 'Quantitative Aptitude',
    description: 'Problems involving ratios, proportions, and partnerships',
    recognitionPatterns: [
      RecognitionPattern(
        pattern: 'Basic ratio',
        indicator: 'Divide in a given ratio',
        keywords: ['ratio', 'divide', 'share', 'in the ratio', ':'],
      ),
      RecognitionPattern(
        pattern: 'Proportion',
        indicator: 'Equality of ratios',
        keywords: ['proportion', 'varies as', 'directly', 'inversely'],
      ),
      RecognitionPattern(
        pattern: 'Partnership',
        indicator: 'Profit sharing based on investment',
        keywords: ['partnership', 'investment', 'profit share', 'capital'],
      ),
    ],
    mentalFramework: [
      '1. Convert ratio to parts (a:b = a parts : b parts)',
      '2. Total parts = sum of ratio terms',
      '3. Value of 1 part = Total / Total parts',
      '4. For proportion: a/b = c/d → ad = bc',
      '5. Partnership: Share ∝ Capital × Time',
    ],
    keyObservations: [
      'Ratio a:b means a parts and b parts',
      'If A:B = 2:3, A = 2/(2+3) of total = 2/5',
      'a:b = c:d means a×d = b×c (cross multiply)',
      'Duplicate ratio of a:b = a²:b²',
      'Partnership profit ∝ (Investment × Time)',
    ],
    strategies: [
      StrategyOption(
        name: 'Part Method',
        description: 'Convert ratio to parts and solve',
        whenToUse: 'For dividing amounts',
        steps: [
          'Ratio a:b means a parts and b parts',
          'Total parts = a + b',
          'Each part = Total amount / Total parts',
          'A\'s share = a × value of each part',
        ],
      ),
      StrategyOption(
        name: 'Cross Multiplication',
        description: 'For proportions a:b = c:d',
        whenToUse: 'When finding unknown in proportion',
        steps: [
          'a/b = c/d',
          'Cross multiply: a×d = b×c',
          'Solve for unknown',
        ],
      ),
      StrategyOption(
        name: 'Capital-Time Product',
        description: 'For partnership problems',
        whenToUse: 'When investment times differ',
        steps: [
          'Profit ratio = (C1×T1) : (C2×T2)',
          'C = Capital, T = Time of investment',
          'Apply ratio to total profit',
        ],
      ),
    ],
    executionSteps: [
      'Step 1: Identify the ratio or proportion',
      'Step 2: Convert to simplest form if needed',
      'Step 3: Calculate total parts',
      'Step 4: Find value of one part',
      'Step 5: Calculate required share or value',
    ],
    verificationMethods: [
      'Sum of parts = Total amount',
      'Ratio of calculated values = Given ratio',
      'Cross-check with proportion equality',
    ],
    commonMistakes: [
      CommonMistake(
        mistake: 'Confusing ratio with fraction',
        why: '2:3 ratio means 2/5 and 3/5, not 2/3',
        howToAvoid: 'Ratio a:b → A = a/(a+b), B = b/(a+b)',
      ),
      CommonMistake(
        mistake: 'Ignoring time in partnership',
        why: 'Different investment durations affect profit share',
        howToAvoid: 'Profit ∝ Capital × Time, not just Capital',
      ),
      CommonMistake(
        mistake: 'Wrong compounding of ratios',
        why: 'A:B = 2:3 and B:C = 4:5 needs B to be same',
        howToAvoid: 'Make common term equal: A:B:C = 8:12:15',
      ),
    ],
    shortcuts: [
      'If A:B = 2:3 and total = 100, A = 40, B = 60',
      'a:b = c:d is same as a×d = b×c',
      'Triplicate ratio of a:b = a³:b³',
      'Mean proportion of a and b = √(ab)',
      'If incomes ratio = a:b and expenses ratio = c:d, savings ratio ≠ (a-c):(b-d)',
    ],
    averageTime: 60,
  );

  // ==================== SPEED, TIME & DISTANCE ====================
  static const speedTimeDistance = ThinkingGuide(
    questionType: 'Speed, Time & Distance',
    subject: 'Quantitative Aptitude',
    description: 'Problems involving motion, speed, time, and distance',
    recognitionPatterns: [
      RecognitionPattern(
        pattern: 'Basic STD',
        indicator: 'Find speed, time, or distance',
        keywords: ['speed', 'km/hr', 'time', 'distance', 'covers', 'travels'],
      ),
      RecognitionPattern(
        pattern: 'Relative motion',
        indicator: 'Two objects moving',
        keywords: ['towards each other', 'same direction', 'opposite', 'train passing'],
      ),
      RecognitionPattern(
        pattern: 'Average speed',
        indicator: 'Different speeds for different parts',
        keywords: ['average speed', 'goes at', 'returns at', 'half distance'],
      ),
    ],
    mentalFramework: [
      '1. Distance = Speed × Time (D = S × T)',
      '2. Keep units consistent (km-hr or m-sec)',
      '3. For conversion: km/hr × 5/18 = m/s',
      '4. Relative speed: Same direction = difference, Opposite = sum',
      '5. Average speed = Total Distance / Total Time',
    ],
    keyObservations: [
      'D = S × T, S = D/T, T = D/S',
      '1 km/hr = 5/18 m/s, 1 m/s = 18/5 km/hr',
      'Average speed ≠ average of speeds',
      'Train problems: Add lengths for total distance',
      'Upstream speed = Boat - Stream, Downstream = Boat + Stream',
    ],
    strategies: [
      StrategyOption(
        name: 'Unit Conversion First',
        description: 'Convert all to same units',
        whenToUse: 'When mixed units given',
        steps: [
          'km/hr to m/s: multiply by 5/18',
          'm/s to km/hr: multiply by 18/5',
          'km to m: multiply by 1000',
          'hr to min: multiply by 60',
        ],
      ),
      StrategyOption(
        name: 'Relative Speed Method',
        description: 'Calculate relative speed for two objects',
        whenToUse: 'Train problems, meeting problems',
        steps: [
          'Same direction: Relative speed = |S1 - S2|',
          'Opposite direction: Relative speed = S1 + S2',
          'Time to meet/pass = Distance / Relative speed',
        ],
      ),
      StrategyOption(
        name: 'Average Speed Formula',
        description: 'For equal distance at different speeds',
        whenToUse: 'Going and returning at different speeds',
        steps: [
          'Average speed = 2×S1×S2/(S1+S2)',
          'This applies for equal DISTANCES',
          'For equal times: Average = (S1+S2)/2',
        ],
      ),
    ],
    executionSteps: [
      'Step 1: Read and identify what\'s given and what\'s asked',
      'Step 2: Convert to consistent units',
      'Step 3: Apply D = S × T formula',
      'Step 4: For relative motion, find relative speed',
      'Step 5: Calculate required value',
      'Step 6: Convert back to required unit',
    ],
    verificationMethods: [
      'Check: Distance = Speed × Time',
      'Verify units match',
      'Estimate to check if answer is reasonable',
    ],
    commonMistakes: [
      CommonMistake(
        mistake: 'Wrong unit conversion',
        why: 'km/hr and m/s conversion factor mixed up',
        howToAvoid: 'km/hr × 5/18 = m/s (5/18 makes number smaller)',
      ),
      CommonMistake(
        mistake: 'Simple average for average speed',
        why: 'Average speed = Total D / Total T, not mean of speeds',
        howToAvoid: 'For equal distance: 2ab/(a+b), not (a+b)/2',
      ),
      CommonMistake(
        mistake: 'Forgetting train length',
        why: 'Train passes = Train moves its own length past the point',
        howToAvoid: 'Passing a pole: D = Train length. Passing platform: D = Train + Platform',
      ),
    ],
    shortcuts: [
      '36 km/hr = 10 m/s, 72 km/hr = 20 m/s',
      'Equal distance avg speed: 2S1S2/(S1+S2)',
      'Train A passes B (same dir): Time = (L1+L2)/(S1-S2)',
      'Stream problems: Speed in still water = (Up + Down)/2',
    ],
    averageTime: 60,
  );

  // ==================== DATA INTERPRETATION ====================
  static const dataInterpretation = ThinkingGuide(
    questionType: 'Data Interpretation',
    subject: 'Quantitative Aptitude',
    description: 'Problems involving charts, tables, and data analysis',
    recognitionPatterns: [
      RecognitionPattern(
        pattern: 'Table-based DI',
        indicator: 'Data presented in rows and columns',
        keywords: ['table', 'data', 'following table', 'given below'],
      ),
      RecognitionPattern(
        pattern: 'Pie Chart',
        indicator: 'Circular diagram with sectors',
        keywords: ['pie chart', 'pie diagram', 'percentage distribution', 'degree'],
      ),
      RecognitionPattern(
        pattern: 'Bar Graph',
        indicator: 'Rectangular bars representing data',
        keywords: ['bar graph', 'bar chart', 'histogram'],
      ),
      RecognitionPattern(
        pattern: 'Line Graph',
        indicator: 'Points connected by lines showing trends',
        keywords: ['line graph', 'trend', 'over the years'],
      ),
    ],
    mentalFramework: [
      '1. First understand what data represents',
      '2. Read axes/legends carefully',
      '3. For pie chart: 1% = 3.6°',
      '4. Use approximation for speed',
      '5. Calculate only what\'s asked',
    ],
    keyObservations: [
      'Pie chart: Total = 100% = 360°',
      '10% in pie chart = 36°',
      'Bar height = value represented',
      'Line graph shows trend over time',
      'Always check units and scale',
    ],
    strategies: [
      StrategyOption(
        name: 'Approximation Method',
        description: 'Round off for quick calculation',
        whenToUse: 'When options are well-separated',
        steps: [
          'Round values to nearest convenient number',
          '347 → 350, 1987 → 2000',
          'Calculate with rounded values',
          'Check which option is closest',
        ],
      ),
      StrategyOption(
        name: 'Ratio Method',
        description: 'Compare ratios instead of absolute values',
        whenToUse: 'When comparing percentages or ratios',
        steps: [
          'Convert to simple ratios',
          'Compare numerators if denominators are same',
          'Use proportion for complex comparisons',
        ],
      ),
      StrategyOption(
        name: 'Percentage Change',
        description: 'Calculate growth or decline',
        whenToUse: 'For trend analysis questions',
        steps: [
          'Change = New - Old',
          '% Change = (Change/Old) × 100',
          'Positive = increase, Negative = decrease',
        ],
      ),
    ],
    executionSteps: [
      'Step 1: Read the question first (know what to find)',
      'Step 2: Understand the chart/table structure',
      'Step 3: Identify relevant data points',
      'Step 4: Use approximation if possible',
      'Step 5: Calculate step by step',
      'Step 6: Check units and verify',
    ],
    verificationMethods: [
      'Check if answer is in reasonable range',
      'Verify pie chart sectors sum to 100%',
      'Check calculations with reverse method',
    ],
    commonMistakes: [
      CommonMistake(
        mistake: 'Reading wrong data',
        why: 'Multiple similar categories confuse',
        howToAvoid: 'Mark/highlight the data you need before calculating',
      ),
      CommonMistake(
        mistake: 'Wrong scale reading',
        why: 'Each unit on bar might represent more than 1',
        howToAvoid: 'Always check the scale/legend before reading values',
      ),
      CommonMistake(
        mistake: 'Percentage of wrong base',
        why: 'Using total instead of specific category',
        howToAvoid: 'Read question carefully for what is the base',
      ),
    ],
    shortcuts: [
      'Pie: 25% = 90°, 50% = 180°, 10% = 36°',
      '% change shortcut: (diff/base) × 100',
      'For comparison: Convert to same base first',
      'CAGR: (Final/Initial)^(1/n) - 1',
    ],
    averageTime: 120,
  );

  /// Get all thinking guides
  static List<ThinkingGuide> get all => [
    percentage,
    profitLoss,
    interest,
    timeWork,
    ratioProportion,
    speedTimeDistance,
    dataInterpretation,
  ];

  /// Get thinking guide by topic
  static ThinkingGuide? getByTopic(String topic) {
    final t = topic.toLowerCase();
    if (t.contains('percent')) return percentage;
    if (t.contains('profit') || t.contains('loss')) return profitLoss;
    if (t.contains('interest') || t.contains('si') || t.contains('ci')) return interest;
    if (t.contains('work') || t.contains('pipe')) return timeWork;
    if (t.contains('ratio') || t.contains('proportion')) return ratioProportion;
    if (t.contains('speed') || t.contains('distance') || t.contains('train')) return speedTimeDistance;
    if (t.contains('data') || t.contains('chart') || t.contains('graph')) return dataInterpretation;
    return null;
  }
}
