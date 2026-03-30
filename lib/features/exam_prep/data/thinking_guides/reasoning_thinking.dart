/// Reasoning Thinking Guides
/// Complete problem-solving methodology for all reasoning question types

import '../../models/problem_solving_approach.dart';

class ReasoningThinkingGuides {
  // ==================== SEATING ARRANGEMENT ====================
  static const seatingArrangement = ThinkingGuide(
    questionType: 'Seating Arrangement',
    subject: 'Reasoning',
    description: 'Questions where people/objects are arranged in a specific order (linear/circular)',
    recognitionPatterns: [
      RecognitionPattern(
        pattern: 'People sitting in a row',
        indicator: 'Linear arrangement with left/right positions',
        keywords: ['sitting in a row', 'standing in a line', 'left', 'right', 'facing north/south'],
      ),
      RecognitionPattern(
        pattern: 'People sitting around a table',
        indicator: 'Circular arrangement with clockwise/anticlockwise',
        keywords: ['circular table', 'round table', 'clockwise', 'anticlockwise', 'facing center/outward'],
      ),
      RecognitionPattern(
        pattern: 'Two rows facing each other',
        indicator: 'Parallel arrangement with facing positions',
        keywords: ['two rows', 'facing each other', 'opposite', 'Row 1', 'Row 2'],
      ),
    ],
    mentalFramework: [
      '1. Identify the arrangement type (linear/circular/two-row)',
      '2. Note total number of positions and people',
      '3. Find DEFINITE positions first (fixed clues)',
      '4. Use elimination for remaining positions',
      '5. Cross-verify with all given conditions',
    ],
    keyObservations: [
      'Look for absolute positions first (A sits at end, B sits 3rd from left)',
      'Note direction indicators (facing, left of, right of)',
      'Count positions between people carefully',
      'In circular: clockwise = right side movement',
      'Check if facing center or facing outward',
    ],
    strategies: [
      StrategyOption(
        name: 'Fixed Position First',
        description: 'Start with clues that give exact positions',
        whenToUse: 'When clues mention specific positions like "3rd from left" or "at the end"',
        steps: [
          'Draw the arrangement structure (boxes for linear, circle for circular)',
          'Place people with fixed positions first',
          'Use relative positions to place others',
          'Verify all conditions are satisfied',
        ],
      ),
      StrategyOption(
        name: 'Group Connection',
        description: 'Group related people and place them together',
        whenToUse: 'When multiple clues connect same people',
        steps: [
          'Identify people mentioned together in clues',
          'Create small groups (A-B, C-D)',
          'Find how groups connect to each other',
          'Place groups in the arrangement',
        ],
      ),
      StrategyOption(
        name: 'Negative Elimination',
        description: 'Eliminate impossible positions',
        whenToUse: 'When there are "not" conditions (A does not sit next to B)',
        steps: [
          'Mark positions where someone CANNOT sit',
          'After placing others, remaining positions become clear',
          'Use process of elimination',
        ],
      ),
    ],
    executionSteps: [
      'Step 1: Draw the base structure (row/circle/two-row)',
      'Step 2: Number the positions (1, 2, 3... or use directions)',
      'Step 3: Read ALL clues once to understand the puzzle',
      'Step 4: Start with definite/fixed positions',
      'Step 5: Apply relative positions (left of, right of, between)',
      'Step 6: Use elimination for remaining people',
      'Step 7: Verify EVERY clue is satisfied',
      'Step 8: Answer the specific question asked',
    ],
    verificationMethods: [
      'Check each clue against final arrangement',
      'Count positions between people as stated',
      'Verify direction (left/right, clockwise/anticlockwise)',
      'Ensure no person appears twice',
      'Confirm total count matches',
    ],
    commonMistakes: [
      CommonMistake(
        mistake: 'Confusing left-right perspective',
        why: 'In some questions, left/right is from person\'s view, in others from our view',
        howToAvoid: 'Check if question says "from left end" (our view) or "to the left of" (relative)',
      ),
      CommonMistake(
        mistake: 'Wrong circular direction',
        why: 'Clockwise direction changes based on facing center or outward',
        howToAvoid: 'If facing center: clockwise = left side of person. If facing out: clockwise = right side',
      ),
      CommonMistake(
        mistake: 'Miscounting positions',
        why: '"Two places to the right" means skip one position',
        howToAvoid: 'Count positions carefully: immediate = 1 place, next = 2 places',
      ),
    ],
    shortcuts: [
      'In linear: Draw boxes and number them immediately',
      'In circular: Mark one position as reference point',
      'Use abbreviations for names (A, B, C)',
      'Mark unknown positions with "?"',
      'Draw arrows for facing direction',
    ],
    averageTime: 180,
  );

  // ==================== BLOOD RELATIONS ====================
  static const bloodRelations = ThinkingGuide(
    questionType: 'Blood Relations',
    subject: 'Reasoning',
    description: 'Questions about family relationships between people',
    recognitionPatterns: [
      RecognitionPattern(
        pattern: 'Direct family relationship',
        indicator: 'A is B\'s father/mother/son/daughter',
        keywords: ['father', 'mother', 'son', 'daughter', 'brother', 'sister', 'parent', 'child'],
      ),
      RecognitionPattern(
        pattern: 'Extended family relationship',
        indicator: 'Relationships involving grandparents, uncles, aunts, cousins',
        keywords: ['grandfather', 'grandmother', 'uncle', 'aunt', 'nephew', 'niece', 'cousin'],
      ),
      RecognitionPattern(
        pattern: 'Spouse relationships',
        indicator: 'Marriage-based relationships',
        keywords: ['husband', 'wife', 'married', 'spouse', 'father-in-law', 'mother-in-law'],
      ),
    ],
    mentalFramework: [
      '1. Draw a family tree (generations as levels)',
      '2. Males on one side, females on other (or use symbols)',
      '3. Connect relationships with lines',
      '4. Use = for marriage, | for parent-child',
      '5. Work generation by generation',
    ],
    keyObservations: [
      'Identify gender of each person first',
      'Father\'s or Mother\'s side determines the relationship term',
      'Cousin can be male or female - check context',
      'Brother/Sister of parent = Uncle/Aunt',
      'Child of Uncle/Aunt = Cousin',
    ],
    strategies: [
      StrategyOption(
        name: 'Family Tree Method',
        description: 'Draw a visual family tree',
        whenToUse: 'Always recommended for complex relationships',
        steps: [
          'Put oldest generation at top',
          'Use ♂ for male, ♀ for female',
          'Connect couples with = sign',
          'Draw children below parents with |',
          'Trace the path between two people for relationship',
        ],
      ),
      StrategyOption(
        name: 'Generation Counting',
        description: 'Count generations to find relationship',
        whenToUse: 'When relationship seems distant',
        steps: [
          'Same generation = siblings/cousins/spouses',
          'One generation up = parent/uncle/aunt',
          'One generation down = child/nephew/niece',
          'Two generations up = grandparent',
        ],
      ),
    ],
    executionSteps: [
      'Step 1: Read the question and identify all people',
      'Step 2: Note gender of each person (crucial!)',
      'Step 3: Draw family tree with oldest at top',
      'Step 4: Place each relationship as given',
      'Step 5: Identify the two people in question',
      'Step 6: Trace path between them',
      'Step 7: Determine relationship based on path',
    ],
    verificationMethods: [
      'Verify gender assignments are correct',
      'Check each stated relationship in tree',
      'Count generations between people',
      'Confirm relationship term matches gender',
    ],
    commonMistakes: [
      CommonMistake(
        mistake: 'Wrong gender assumption',
        why: 'Names like "Ajay", "Pat" can be ambiguous',
        howToAvoid: 'Only assign gender when explicitly stated or clear from relationship',
      ),
      CommonMistake(
        mistake: 'Confusing paternal/maternal side',
        why: 'Uncle on father\'s side vs mother\'s side have same term but different meaning',
        howToAvoid: 'Track which side of family each person belongs to',
      ),
      CommonMistake(
        mistake: 'Forgetting spouse relationships',
        why: 'Husband/wife of parent\'s sibling is also uncle/aunt',
        howToAvoid: 'Include spouses in family tree with = sign',
      ),
    ],
    shortcuts: [
      'Father\'s/Mother\'s father = Grandfather',
      'Father\'s/Mother\'s mother = Grandmother',
      'Brother\'s/Sister\'s son = Nephew',
      'Brother\'s/Sister\'s daughter = Niece',
      'Uncle\'s/Aunt\'s child = Cousin',
      'Son\'s wife = Daughter-in-law',
      'Daughter\'s husband = Son-in-law',
    ],
    averageTime: 90,
  );

  // ==================== CODING-DECODING ====================
  static const codingDecoding = ThinkingGuide(
    questionType: 'Coding-Decoding',
    subject: 'Reasoning',
    description: 'Questions where letters/words are coded using a specific pattern',
    recognitionPatterns: [
      RecognitionPattern(
        pattern: 'Letter shifting',
        indicator: 'Each letter moves by a fixed number',
        keywords: ['coded as', 'written as', 'APPLE = BQQMF'],
      ),
      RecognitionPattern(
        pattern: 'Position-based coding',
        indicator: 'Letters replaced by their position numbers or vice versa',
        keywords: ['A=1, B=2', 'number code', 'CAT = 3 1 20'],
      ),
      RecognitionPattern(
        pattern: 'Reverse alphabet',
        indicator: 'A=Z, B=Y, C=X pattern',
        keywords: ['opposite letter', 'reverse', 'mirror'],
      ),
      RecognitionPattern(
        pattern: 'Symbol-based coding',
        indicator: 'Letters replaced by symbols',
        keywords: ['@, #, \$', 'symbols', 'A = @'],
      ),
    ],
    mentalFramework: [
      '1. Compare given word with its code',
      '2. Check letter by letter for pattern',
      '3. Verify pattern with all given examples',
      '4. Apply same pattern to find answer',
      '5. Double-check with reverse verification',
    ],
    keyObservations: [
      'Check if pattern is same for all letters',
      'Look for +1, +2, -1, -2 shifts first (most common)',
      'Check if vowels and consonants have different rules',
      'Position in word might affect coding',
      'Case sensitivity (upper/lower) might matter',
    ],
    strategies: [
      StrategyOption(
        name: 'Difference Method',
        description: 'Calculate position difference for each letter',
        whenToUse: 'For letter shift patterns',
        steps: [
          'Write position of each letter in original word',
          'Write position of each letter in coded word',
          'Find difference (coded - original)',
          'Check if difference is constant',
          'Apply same shift to decode',
        ],
      ),
      StrategyOption(
        name: 'Reverse Alphabet Check',
        description: 'Check if A↔Z, B↔Y pattern applies',
        whenToUse: 'When shift seems irregular',
        steps: [
          'Use formula: Code = 27 - Position',
          'A(1) ↔ Z(26), B(2) ↔ Y(25), etc.',
          'Verify with given examples',
        ],
      ),
      StrategyOption(
        name: 'Position-Based Decode',
        description: 'Check if letters become numbers',
        whenToUse: 'When code contains numbers',
        steps: [
          'A=1, B=2, ... Z=26',
          'Or A=26, B=25, ... Z=1 (reverse)',
          'Check for arithmetic operations on positions',
        ],
      ),
    ],
    executionSteps: [
      'Step 1: Write original word and code side by side',
      'Step 2: Write position of each letter (A=1, B=2...)',
      'Step 3: Find relationship between positions',
      'Step 4: Check if same rule applies to all letters',
      'Step 5: Note any special rules (vowels, position, etc.)',
      'Step 6: Apply pattern to question word',
      'Step 7: Verify answer makes sense',
    ],
    verificationMethods: [
      'Apply pattern to original word - should get code',
      'Check pattern consistency across all examples',
      'Verify no letters are skipped or repeated wrongly',
    ],
    commonMistakes: [
      CommonMistake(
        mistake: 'Assuming constant shift',
        why: 'Some patterns use increasing shift (+1, +2, +3...)',
        howToAvoid: 'Check shift for each letter position separately',
      ),
      CommonMistake(
        mistake: 'Missing reverse alphabet',
        why: 'A↔Z shift is common but not immediately obvious',
        howToAvoid: 'Always check if sum of positions = 27',
      ),
      CommonMistake(
        mistake: 'Wrong direction (+ vs -)',
        why: 'Forward vs backward shift confusion',
        howToAvoid: 'Verify direction with given example before applying',
      ),
    ],
    shortcuts: [
      'Reverse alphabet: Position + Code Position = 27',
      '+1 shift: A→B, B→C, Z→A',
      '-1 shift: A→Z, B→A, C→B',
      'Quick position: A-J = 1-10, K-T = 11-20, U-Z = 21-26',
      'Vowels (AEIOU) positions: 1, 5, 9, 15, 21',
    ],
    averageTime: 60,
  );

  // ==================== NUMBER SERIES ====================
  static const numberSeries = ThinkingGuide(
    questionType: 'Number Series',
    subject: 'Reasoning',
    description: 'Find the pattern in a sequence of numbers',
    recognitionPatterns: [
      RecognitionPattern(
        pattern: 'Arithmetic progression',
        indicator: 'Constant difference between consecutive terms',
        keywords: ['2, 5, 8, 11', 'increasing by', 'decreasing by'],
      ),
      RecognitionPattern(
        pattern: 'Geometric progression',
        indicator: 'Constant ratio between consecutive terms',
        keywords: ['2, 6, 18, 54', 'multiplied by', 'divided by'],
      ),
      RecognitionPattern(
        pattern: 'Square/Cube series',
        indicator: 'Numbers are squares or cubes',
        keywords: ['1, 4, 9, 16', '1, 8, 27, 64', 'perfect squares', 'perfect cubes'],
      ),
      RecognitionPattern(
        pattern: 'Mixed operations',
        indicator: 'Alternating or combined operations',
        keywords: ['×2+1', '×3-2', 'alternating'],
      ),
    ],
    mentalFramework: [
      '1. Write differences between consecutive terms',
      '2. If differences are constant → AP',
      '3. If differences form a pattern → second level check',
      '4. Check for ×, ÷ patterns if + - don\'t work',
      '5. Look for squares, cubes, primes',
    ],
    keyObservations: [
      'First find differences (d1 = n2-n1)',
      'If differences vary, find difference of differences',
      'Check if numbers are special (squares, cubes, primes)',
      'Look for alternating patterns',
      'Two interleaved series possible',
    ],
    strategies: [
      StrategyOption(
        name: 'Difference Method',
        description: 'Find successive differences',
        whenToUse: 'First approach for any series',
        steps: [
          'Calculate d1 = term2 - term1, d2 = term3 - term2, etc.',
          'If all d are same → AP, answer = last + d',
          'If d values form pattern, find next d',
          'Add that d to last term',
        ],
      ),
      StrategyOption(
        name: 'Ratio Method',
        description: 'Find ratio between consecutive terms',
        whenToUse: 'When differences are irregular but ratios are constant',
        steps: [
          'Calculate r1 = term2/term1, r2 = term3/term2, etc.',
          'If all r are same → GP, answer = last × r',
          'Check for mixed ratio (×2, ×3, ×4...)',
        ],
      ),
      StrategyOption(
        name: 'Pattern Recognition',
        description: 'Identify special number patterns',
        whenToUse: 'When basic methods fail',
        steps: [
          'Check if numbers are squares (1,4,9,16,25...)',
          'Check if numbers are cubes (1,8,27,64...)',
          'Check for n² + n or n² - n patterns',
          'Look for prime numbers',
        ],
      ),
    ],
    executionSteps: [
      'Step 1: Write the series clearly',
      'Step 2: Calculate differences between consecutive terms',
      'Step 3: If constant → AP, if not, calculate second-level differences',
      'Step 4: If differences don\'t work, try ratios',
      'Step 5: Check for squares, cubes, special patterns',
      'Step 6: Apply pattern to find missing term',
      'Step 7: Verify by checking if pattern holds',
    ],
    verificationMethods: [
      'Apply found pattern to verify all terms',
      'Check if answer fits the pattern',
      'Verify operation sequence',
    ],
    commonMistakes: [
      CommonMistake(
        mistake: 'Missing two-level pattern',
        why: 'Differences themselves form a pattern',
        howToAvoid: 'Always check difference of differences',
      ),
      CommonMistake(
        mistake: 'Ignoring alternating series',
        why: 'Two series interleaved (odd and even positions)',
        howToAvoid: 'Check odd and even position terms separately',
      ),
      CommonMistake(
        mistake: 'Wrong operation order',
        why: '×2 then +3 is different from +3 then ×2',
        howToAvoid: 'Test operation order with multiple terms',
      ),
    ],
    shortcuts: [
      'Perfect squares: 1, 4, 9, 16, 25, 36, 49, 64, 81, 100',
      'Perfect cubes: 1, 8, 27, 64, 125, 216, 343, 512',
      'Primes: 2, 3, 5, 7, 11, 13, 17, 19, 23, 29',
      'Triangular: 1, 3, 6, 10, 15, 21 (n(n+1)/2)',
      'Fibonacci: 1, 1, 2, 3, 5, 8, 13 (each = sum of previous two)',
    ],
    averageTime: 45,
  );

  // ==================== DIRECTION SENSE ====================
  static const directionSense = ThinkingGuide(
    questionType: 'Direction Sense',
    subject: 'Reasoning',
    description: 'Questions about movement and final direction/distance',
    recognitionPatterns: [
      RecognitionPattern(
        pattern: 'Movement and direction',
        indicator: 'Person walks/travels in various directions',
        keywords: ['walks', 'travels', 'north', 'south', 'east', 'west', 'turns left', 'turns right'],
      ),
      RecognitionPattern(
        pattern: 'Final position',
        indicator: 'Find distance or direction from starting point',
        keywords: ['from starting point', 'final position', 'how far', 'which direction'],
      ),
    ],
    mentalFramework: [
      '1. Draw coordinate system (N at top, S at bottom, E right, W left)',
      '2. Start at origin point',
      '3. Track each movement step by step',
      '4. Calculate final displacement',
      '5. Use Pythagorean theorem for distance',
    ],
    keyObservations: [
      'Left turn = 90° anticlockwise',
      'Right turn = 90° clockwise',
      'North + Right = East, North + Left = West',
      'Opposite directions cancel out',
      'Track X and Y displacement separately',
    ],
    strategies: [
      StrategyOption(
        name: 'Coordinate Method',
        description: 'Use X-Y coordinates to track movement',
        whenToUse: 'For complex multi-step problems',
        steps: [
          'Set starting point as (0,0)',
          'East/West = X axis, North/South = Y axis',
          'East = +X, West = -X',
          'North = +Y, South = -Y',
          'Final position gives direction and distance',
        ],
      ),
      StrategyOption(
        name: 'Visual Diagram',
        description: 'Draw movement on paper',
        whenToUse: 'For simpler problems',
        steps: [
          'Draw compass (N-S-E-W)',
          'Mark starting point',
          'Draw each movement with length',
          'Connect start to end for final displacement',
        ],
      ),
    ],
    executionSteps: [
      'Step 1: Draw compass directions',
      'Step 2: Mark starting point',
      'Step 3: Follow each movement instruction',
      'Step 4: Track turns (left/right) correctly',
      'Step 5: Calculate total North-South displacement',
      'Step 6: Calculate total East-West displacement',
      'Step 7: Use Pythagoras: Distance = √(NS² + EW²)',
      'Step 8: Determine direction from displacements',
    ],
    verificationMethods: [
      'Retrace the path to verify positions',
      'Check if turns are in correct direction',
      'Verify distance calculation',
    ],
    commonMistakes: [
      CommonMistake(
        mistake: 'Wrong turn direction',
        why: 'Left when facing North ≠ Left when facing South',
        howToAvoid: 'Always track current facing direction before turning',
      ),
      CommonMistake(
        mistake: 'Forgetting diagonal direction',
        why: 'Final position might be NE, NW, SE, SW',
        howToAvoid: 'Check both X and Y displacement signs',
      ),
      CommonMistake(
        mistake: 'Adding instead of subtracting',
        why: 'Opposite direction movements should cancel',
        howToAvoid: 'North-South and East-West are opposite signs',
      ),
    ],
    shortcuts: [
      'North + Left = West, North + Right = East',
      'South + Left = East, South + Right = West',
      'East + Left = North, East + Right = South',
      'West + Left = South, West + Right = North',
      '180° turn = opposite direction',
      'Two left turns = 180° = opposite direction',
    ],
    averageTime: 90,
  );

  // ==================== SYLLOGISM ====================
  static const syllogism = ThinkingGuide(
    questionType: 'Syllogism',
    subject: 'Reasoning',
    description: 'Logical reasoning with statements and conclusions',
    recognitionPatterns: [
      RecognitionPattern(
        pattern: 'All/Some/No statements',
        indicator: 'Universal or particular statements',
        keywords: ['All A are B', 'Some A are B', 'No A is B', 'Some A are not B'],
      ),
      RecognitionPattern(
        pattern: 'Conclusions to evaluate',
        indicator: 'Check if conclusions follow from statements',
        keywords: ['conclusion follows', 'definitely true', 'I. ', 'II. '],
      ),
    ],
    mentalFramework: [
      '1. Identify statement types (All/Some/No/Some not)',
      '2. Draw Venn diagrams for each statement',
      '3. Check if conclusion is ALWAYS true from diagram',
      '4. Consider all possible diagrams',
      '5. Conclusion must be true in ALL cases',
    ],
    keyObservations: [
      'ALL A are B: A circle completely inside B',
      'Some A are B: A and B overlap (but not necessarily all)',
      'No A is B: A and B don\'t touch at all',
      'Some A are not B: Part of A is outside B',
      'Conclusion must be true in EVERY possible diagram',
    ],
    strategies: [
      StrategyOption(
        name: 'Venn Diagram Method',
        description: 'Draw circles representing sets',
        whenToUse: 'Always recommended - most reliable',
        steps: [
          'Draw circle for each term',
          'Position circles based on statements',
          'All A are B: A inside B',
          'Some A are B: A and B overlap',
          'No A is B: A and B separate',
          'Check if conclusion holds in ALL valid diagrams',
        ],
      ),
      StrategyOption(
        name: 'Quick Rules',
        description: 'Apply standard syllogism rules',
        whenToUse: 'For quick solving when patterns match',
        steps: [
          'All + All = All (if middle term connects)',
          'All + Some = Some',
          'No + All = No',
          'Negative + Negative = No conclusion',
          'Particular + Particular = No conclusion',
        ],
      ),
    ],
    executionSteps: [
      'Step 1: Identify all statements (All/Some/No/Some not)',
      'Step 2: Find the middle term (appears in both statements)',
      'Step 3: Draw Venn diagrams',
      'Step 4: Check each conclusion against diagram',
      'Step 5: Try alternative valid diagrams',
      'Step 6: Conclusion is valid ONLY if true in ALL diagrams',
    ],
    verificationMethods: [
      'Draw multiple valid diagrams for statements',
      'Check conclusion in each diagram',
      'If false in ANY diagram, conclusion doesn\'t follow',
    ],
    commonMistakes: [
      CommonMistake(
        mistake: 'Assuming "Some" means "Only Some"',
        why: '"Some" can mean "All" as a possibility',
        howToAvoid: 'Some A are B allows possibility that All A are B',
      ),
      CommonMistake(
        mistake: 'Concluding from single diagram',
        why: 'Multiple diagrams may be valid for given statements',
        howToAvoid: 'Always check all possible valid diagrams',
      ),
      CommonMistake(
        mistake: 'Reversing "All" statements',
        why: 'All A are B does NOT mean All B are A',
        howToAvoid: 'Remember: A inside B ≠ B inside A',
      ),
    ],
    shortcuts: [
      'All A are B + All B are C = All A are C',
      'Some A are B = Some B are A (always)',
      'No A is B = No B is A (always)',
      'All A are B + No B is C = No A is C',
      '"Either I or II" = both cannot be true together',
    ],
    averageTime: 90,
  );

  /// Get all thinking guides
  static List<ThinkingGuide> get all => [
    seatingArrangement,
    bloodRelations,
    codingDecoding,
    numberSeries,
    directionSense,
    syllogism,
  ];

  /// Get thinking guide by question type
  static ThinkingGuide? getByType(String questionType) {
    final type = questionType.toLowerCase();
    if (type.contains('seating') || type.contains('arrangement')) {
      return seatingArrangement;
    } else if (type.contains('blood') || type.contains('relation')) {
      return bloodRelations;
    } else if (type.contains('coding') || type.contains('decoding')) {
      return codingDecoding;
    } else if (type.contains('series') || type.contains('number')) {
      return numberSeries;
    } else if (type.contains('direction')) {
      return directionSense;
    } else if (type.contains('syllogism')) {
      return syllogism;
    }
    return null;
  }
}
