import '../../../models/study_material_model.dart';

/// Banking Reasoning Ability - Shortcuts & Tricks
/// Quick solving methods for reasoning problems

final List<StudyMaterial> bankingReasoningShortcuts = [
  // ==================== SEATING ARRANGEMENT SHORTCUTS ====================
  
  StudyMaterial(
    id: 'bank_reason_s_linear_tricks',
    title: 'Linear Arrangement Quick Tricks',
    description: 'Solve linear seating in 2-3 minutes',
    subjectId: 'reasoning_ability',
    topicId: 'seating_arrangement',
    type: StudyMaterialType.shortcut,
    content: '''
# Linear Arrangement Quick Tricks

## Priority Order for Clues
1. **Definite positions** (A sits at end)
2. **Relative + Fixed** (B is 2nd from A who is at end)
3. **Relative positions** (C is left of D)
4. **Negative clues** (E is not at position 3)

## Visual Shorthand
```
Left End ←───────────→ Right End
[1] [2] [3] [4] [5] [6] [7] [8]
```
Use X for elimination, ✓ for confirmed

## Quick Position Finder
| Clue | Position |
|------|----------|
| 3rd from left | 3 |
| 3rd from right (of 8) | 6 |
| Exactly in middle (of 7) | 4 |
| 2nd from extreme left | 2 |

## "Between" Shortcut
"X persons between A and B"
→ **Gap = X + 1 positions**
→ 3 between → 4 positions apart

## Direction Trick
All facing North:
- Left of A = Towards West
- Right of A = Towards East

## Elimination Method
When stuck:
1. List all possibilities
2. Apply one more clue
3. Strike out invalid options
''',
    tags: ['seating', 'linear', 'shortcuts'],
    estimatedReadTime: 4,
    createdAt: DateTime.now(),
  ),

  StudyMaterial(
    id: 'bank_reason_s_circular_tricks',
    title: 'Circular Arrangement Shortcuts',
    description: 'Quick circular puzzle solutions',
    subjectId: 'reasoning_ability',
    topicId: 'seating_arrangement',
    type: StudyMaterialType.shortcut,
    content: '''
# Circular Arrangement Shortcuts

## Quick Setup
```
       1
    8     2
  7         3
    6     4
       5
```
Fix position 1 as reference point

## Opposite Position Formula
**In n-seat circle: Opposite = Current + n/2**
- 8 seats: 1↔5, 2↔6, 3↔7, 4↔8
- 6 seats: 1↔4, 2↔5, 3↔6

## Facing Direction Quick Check
| All Face | Your Left | Your Right |
|----------|-----------|------------|
| Center | Anti-clock | Clockwise |
| Outside | Clockwise | Anti-clock |

## Neighbor Counting
"2 people between A and B"
Count spaces, not people at ends
A _ _ B (clockwise) or B _ _ A (anticlockwise)

## Mixed Facing Trick
Draw arrows:
- → Facing center
- ← Facing outside

Then apply left/right based on arrow direction

## Quick Solve Method
1. Fix one person (usually most constrained)
2. Place definite positions
3. Use opposite pairs
4. Fill remaining by elimination
''',
    tags: ['seating', 'circular', 'shortcuts'],
    estimatedReadTime: 4,
    createdAt: DateTime.now(),
  ),

  // ==================== BLOOD RELATION SHORTCUTS ====================

  StudyMaterial(
    id: 'bank_reason_s_blood_tricks',
    title: 'Blood Relation Quick Methods',
    description: 'Solve family trees instantly',
    subjectId: 'reasoning_ability',
    topicId: 'blood_relations',
    type: StudyMaterialType.shortcut,
    content: '''
# Blood Relation Quick Methods

## Generation Counting
| Relationship | Generation |
|--------------|------------|
| Grandparent | +2 |
| Parent/Uncle/Aunt | +1 |
| Self/Sibling/Cousin | 0 |
| Child/Nephew/Niece | -1 |
| Grandchild | -2 |

## Quick Relationship Finder
**Mother's/Father's...**
| Relation | Is your |
|----------|---------|
| Brother | Uncle |
| Sister | Aunt |
| Father | Grandfather |
| Mother | Grandmother |
| Son/Daughter | Sibling |

**Brother's/Sister's...**
| Relation | Is your |
|----------|---------|
| Son | Nephew |
| Daughter | Niece |
| Wife/Husband | Sibling-in-law |

## Tree Drawing Shortcut
```
    Male──Female
        │
   ┌────┴────┐
   │         │
 Son      Daughter
```
- Horizontal line = Married
- Vertical line = Parent-child

## "Only" Keyword
- "A is only son" → No brothers
- "A is only child" → No siblings
- "Only son of only son" → Single male line

## Pointer Words
- "Himself/Herself" → Points to the person
- "His/Her" → Shows gender
- "Pointing to a photograph" → Third person involved
''',
    tags: ['blood-relations', 'shortcuts'],
    estimatedReadTime: 4,
    createdAt: DateTime.now(),
  ),

  // ==================== DIRECTION SHORTCUTS ====================

  StudyMaterial(
    id: 'bank_reason_s_direction_tricks',
    title: 'Direction Sense Shortcuts',
    description: 'Solve direction problems quickly',
    subjectId: 'reasoning_ability',
    topicId: 'direction_distance',
    type: StudyMaterialType.shortcut,
    content: '''
# Direction Sense Shortcuts

## Quick Turn Calculator
| Turn | From N | From E | From S | From W |
|------|--------|--------|--------|--------|
| Right 90° | E | S | W | N |
| Left 90° | W | N | E | S |
| 180° | S | W | N | E |

## Coordinate Tracking
Start: (0, 0)
| Move | Effect |
|------|--------|
| North +5 | (0, +5) |
| South -3 | (0, +2) |
| East +4 | (+4, +2) |
| West -2 | (+2, +2) |

## Distance Formula
**Shortest = √(x² + y²)**
If final position is (+3, +4):
Distance = √(9+16) = √25 = **5 km**

## Shadow Quick Reference
| Time | Sun Position | Shadow Falls |
|------|--------------|--------------|
| 6 AM | East | West |
| 12 PM | Overhead | Below (shortest) |
| 6 PM | West | East |

## "Towards" vs "Facing"
- Walking towards North = Moving North
- Facing North then right turn = Now facing East

## Shortcut for Complex Routes
Draw on paper:
1. Use ↑↓←→ for directions
2. Mark distances on arrows
3. Final position = Net displacement
''',
    tags: ['direction', 'shortcuts'],
    estimatedReadTime: 4,
    createdAt: DateTime.now(),
  ),

  // ==================== CODING-DECODING SHORTCUTS ====================

  StudyMaterial(
    id: 'bank_reason_s_coding_tricks',
    title: 'Coding-Decoding Quick Tricks',
    description: 'Crack codes in seconds',
    subjectId: 'reasoning_ability',
    topicId: 'coding_decoding',
    type: StudyMaterialType.shortcut,
    content: '''
# Coding-Decoding Quick Tricks

## Letter Position Quick Reference
| Letter | Position | Reverse |
|--------|----------|---------|
| A | 1 | 26 |
| E | 5 | 22 |
| I | 9 | 18 |
| M | 13 | 14 |
| O | 15 | 12 |
| U | 21 | 6 |
| Z | 26 | 1 |

## Pattern Recognition Steps
1. Count letters (same in word & code?)
2. Check first letter change
3. Check pattern consistency
4. Verify with another word

## Common Shift Patterns
| Original | +1 | +2 | -1 | Reverse |
|----------|----|----|----|---------| 
| CAT | DBU | ECV | BZS | XZG |
| DOG | EPH | FQI | CNF | WLT |

## Opposite Letter Pairs
A↔Z, B↔Y, C↔X, D↔W, E↔V, F↔U
G↔T, H↔S, I↔R, J↔Q, K↔P, L↔O
M↔N

**Quick Check: Position sum = 27**

## Number-Letter Coding
| A-J | K-T | U-Z |
|-----|-----|-----|
| 1-10 | 11-20 | 21-26 |

## Condition-Based Coding
Read conditions carefully:
- "If vowel at start"
- "If consonant at end"
- Apply only matching conditions
''',
    tags: ['coding', 'decoding', 'shortcuts'],
    estimatedReadTime: 4,
    createdAt: DateTime.now(),
  ),

  // ==================== SYLLOGISM SHORTCUTS ====================

  StudyMaterial(
    id: 'bank_reason_s_syllogism_tricks',
    title: 'Syllogism Quick Methods',
    description: 'Solve syllogism without Venn diagrams',
    subjectId: 'reasoning_ability',
    topicId: 'syllogism',
    type: StudyMaterialType.shortcut,
    content: '''
# Syllogism Quick Methods

## Statement-Conclusion Quick Match

### "All A are B" gives:
| Definite | Possible |
|----------|----------|
| Some A are B ✓ | All B are A |
| Some B are A ✓ | Some B are not A |

### "No A is B" gives:
| Definite | Possible |
|----------|----------|
| No B is A ✓ | - |
| Some A are not B ✓ | - |
| Some B are not A ✓ | - |

### "Some A are B" gives:
| Definite | Possible |
|----------|----------|
| Some B are A ✓ | All A are B |
|  | All B are A |
|  | Some A are not B |

## No Conclusion Cases
1. Both statements negative
2. Both statements particular
3. Middle term not distributed

## Either-Or Trigger
When two conclusions are:
- Complementary (All vs Some not)
- And neither definitely follows
→ **Either I or II follows**

## Quick Venn Sketch
```
All A are B:    Some A are B:    No A is B:
  ┌──[A]──┐       [A]∩[B]        [A] [B]
  │  [B]  │
  └───────┘
```
''',
    tags: ['syllogism', 'shortcuts'],
    estimatedReadTime: 4,
    createdAt: DateTime.now(),
  ),

  // ==================== INEQUALITY SHORTCUTS ====================

  StudyMaterial(
    id: 'bank_reason_s_inequality_tricks',
    title: 'Inequality Quick Solve',
    description: 'Master coded inequalities fast',
    subjectId: 'reasoning_ability',
    topicId: 'inequality',
    type: StudyMaterialType.shortcut,
    content: '''
# Inequality Quick Solve

## Direction Rule
**Same direction → Conclusion possible**
**Opposite direction → No conclusion**

| Chain | Conclusion |
|-------|------------|
| A > B > C | A > C ✓ |
| A > B < C | Can't compare A,C |
| A < B < C | A < C ✓ |
| A < B > C | Can't compare A,C |

## Equal Sign Rule
**Equal preserves direction**
| Chain | Conclusion |
|-------|------------|
| A ≥ B > C | A > C ✓ |
| A > B ≥ C | A > C ✓ |
| A ≥ B ≥ C | A ≥ C ✓ |

## Decode Then Chain
1. Write symbol meanings
2. Substitute in expression
3. Chain from left to right
4. Check if direction consistent

## Quick Symbol Reference
Common coding:
| Symbol | Possible Meanings |
|--------|-------------------|
| @ | > or = |
| # | < or ≤ |
| \$ | ≥ or ≤ |
| % | > or < |
| & | = or ≠ |

## Answer Checking
For conclusion X > Y:
- Need chain leading X...>...Y
- All arrows must point same way
- One ≥ or ≤ becomes > overall
''',
    tags: ['inequality', 'shortcuts'],
    estimatedReadTime: 4,
    createdAt: DateTime.now(),
  ),

  // ==================== PUZZLE SHORTCUTS ====================

  StudyMaterial(
    id: 'bank_reason_s_puzzle_tricks',
    title: 'Puzzle Solving Strategies',
    description: 'Systematic puzzle approach',
    subjectId: 'reasoning_ability',
    topicId: 'puzzles',
    type: StudyMaterialType.shortcut,
    content: '''
# Puzzle Solving Strategies

## Grid Setup
Create table with:
- Rows: People/Items
- Columns: Attributes (floor, city, color, etc.)

## Clue Priority
| Priority | Clue Type | Example |
|----------|-----------|---------|
| 1 | Direct | A is on floor 5 |
| 2 | Relative fixed | B is above A |
| 3 | Relative | C is above D |
| 4 | Negative | E is not on floor 1 |
| 5 | Either-or | F is on 2 or 3 |

## Floor Puzzle Quick Math
"X floors between A and B"
→ |Floor_A - Floor_B| = X + 1

| Between | Gap |
|---------|-----|
| 1 person | 2 floors |
| 2 persons | 3 floors |
| 3 persons | 4 floors |

## Day Puzzle Quick Reference
| Day | Code | From Sunday |
|-----|------|-------------|
| Sun | 1 | 0 |
| Mon | 2 | 1 |
| Tue | 3 | 2 |
| Wed | 4 | 3 |
| Thu | 5 | 4 |
| Fri | 6 | 5 |
| Sat | 7 | 6 |

## Elimination Tracking
Use ✓ for confirmed, ✗ for eliminated
Fill grid systematically
''',
    tags: ['puzzles', 'shortcuts'],
    estimatedReadTime: 4,
    createdAt: DateTime.now(),
  ),

  // ==================== INPUT-OUTPUT SHORTCUTS ====================

  StudyMaterial(
    id: 'bank_reason_s_input_output_tricks',
    title: 'Input-Output Pattern Detection',
    description: 'Crack I/O machines quickly',
    subjectId: 'reasoning_ability',
    topicId: 'input_output',
    type: StudyMaterialType.shortcut,
    content: '''
# Input-Output Pattern Detection

## Step-by-Step Analysis
1. **Count elements**: Same in input and output?
2. **Identify final positions**: Where does each element end up?
3. **Track one element**: Follow its journey through steps
4. **Find the rule**: What operation happens each step?

## Common Sorting Patterns

### Ascending Sort (One per step)
Step 1: Smallest moves to position 1
Step 2: 2nd smallest to position 2
...and so on

### Descending Sort (One per step)
Step 1: Largest moves to position 1
Step 2: 2nd largest to position 2

### Alternating Pattern
Words and numbers sorted separately
Final: word, number, word, number...

## Position Prediction
If pattern moves nth element to final position:
**Steps to complete = Total elements - 1**

## Quick Questions
| Question | Find |
|----------|------|
| How many steps? | Count until stable |
| Step n output | Apply rule n times |
| What was input? | Reverse the operations |

## Reverse Engineering
For "what was input" questions:
1. Identify the sorting rule
2. Apply reverse operation
3. Work backwards from output
''',
    tags: ['input-output', 'shortcuts'],
    estimatedReadTime: 4,
    createdAt: DateTime.now(),
  ),

  // ==================== RANKING SHORTCUTS ====================

  StudyMaterial(
    id: 'bank_reason_s_ranking_tricks',
    title: 'Ranking & Order Shortcuts',
    description: 'Quick ranking problem solutions',
    subjectId: 'reasoning_ability',
    topicId: 'ranking',
    type: StudyMaterialType.shortcut,
    content: '''
# Ranking & Order Shortcuts

## Basic Formula
**Total = Left + Right - 1**
Or: **Total = Top + Bottom - 1**

| Rank from Top | Rank from Bottom | Total |
|---------------|------------------|-------|
| 5th | 8th | 12 |
| 3rd | 6th | 8 |
| 7th | 4th | 10 |

## People Between
**Between = |Rank1 - Rank2| - 1**

| 3rd and 7th | Between = 3 |
| 5th and 12th | Between = 6 |

## Interchange Problems
After A and B swap positions:
- A gets B's old rank
- B gets A's old rank

## Class Rank Problems
If A is 15th from top and 20th from bottom:
**Class size = 15 + 20 - 1 = 34**

## Multiple Conditions
"A is ahead of B" + "B is ahead of C"
→ Order: A...B...C

## Row/Column Problems
| Position | Formula |
|----------|---------|
| From left + right | Total columns |
| From top + bottom | Total rows |
| Total students | Rows × Columns |
''',
    tags: ['ranking', 'order', 'shortcuts'],
    estimatedReadTime: 4,
    createdAt: DateTime.now(),
  ),

  // ==================== SERIES SHORTCUTS ====================

  StudyMaterial(
    id: 'bank_reason_s_series_tricks',
    title: 'Number & Letter Series Tricks',
    description: 'Identify series patterns instantly',
    subjectId: 'reasoning_ability',
    topicId: 'series',
    type: StudyMaterialType.shortcut,
    content: '''
# Number & Letter Series Tricks

## First Check: Differences
5, 8, 11, 14, ?
Diff: +3, +3, +3 → **AP, answer: 17**

## Second Check: Second Difference
2, 5, 10, 17, 26, ?
Diff1: 3, 5, 7, 9 → Diff2: +2, +2, +2
Next diff: 11, Answer: **37**

## Third Check: Ratios
3, 6, 12, 24, ?
Ratio: ×2, ×2, ×2 → **GP, answer: 48**

## Fourth Check: Patterns
1, 4, 9, 16, 25, ?
Recognize: 1², 2², 3², 4², 5² → **36**

## Letter Series Patterns
| Pattern | Example |
|---------|---------|
| Skip 1 | A, C, E, G (vowels) |
| Skip 2 | A, D, G, J |
| Reverse | Z, Y, X, W |
| Alternate | A, Z, B, Y, C |

## Mixed Series
A2, B4, C6, D8, ?
Letters: +1 each
Numbers: +2 each
→ **E10**

## Wrong Number Detection
Find which number breaks the pattern
Check differences/ratios at that point
''',
    tags: ['series', 'shortcuts'],
    estimatedReadTime: 4,
    createdAt: DateTime.now(),
  ),

  // ==================== STATEMENT ANALYSIS SHORTCUTS ====================

  StudyMaterial(
    id: 'bank_reason_s_statement_tricks',
    title: 'Statement Analysis Quick Methods',
    description: 'Evaluate conclusions and assumptions fast',
    subjectId: 'reasoning_ability',
    topicId: 'statement_conclusion',
    type: StudyMaterialType.shortcut,
    content: '''
# Statement Analysis Quick Methods

## Conclusion Validity Check
Ask these questions:
1. Is it DIRECTLY stated? → Valid
2. Can it be LOGICALLY inferred? → Valid
3. Does it need ASSUMPTION? → Invalid
4. Does it GO BEYOND scope? → Invalid

## Assumption Identification
**Negation Test**:
1. Negate the assumption
2. Does statement still make sense?
3. If NO → Assumption is VALID

## Course of Action Check
| Valid | Invalid |
|-------|---------|
| Practical | Impractical |
| Proportionate | Extreme |
| Addresses cause | Only treats symptom |
| Legal/Ethical | Illegal/Unethical |

## Argument Strength
**Strong if**:
- Factual (not emotional)
- Relevant to statement
- Universal application
- Significant impact

**Weak if**:
- Based on examples only
- Uses "always/never"
- Emotional appeal
- Unrelated to core issue

## Quick Elimination
- "Obviously" → Usually wrong
- Extreme words → Usually wrong
- Direct restatement → Check carefully
- Beyond scope → Wrong
''',
    tags: ['statement', 'analysis', 'shortcuts'],
    estimatedReadTime: 4,
    createdAt: DateTime.now(),
  ),

  // ==================== DATA SUFFICIENCY SHORTCUTS ====================

  StudyMaterial(
    id: 'bank_reason_s_ds_tricks',
    title: 'Data Sufficiency Quick Method',
    description: 'Solve DS problems systematically',
    subjectId: 'reasoning_ability',
    topicId: 'data_sufficiency',
    type: StudyMaterialType.shortcut,
    content: '''
# Data Sufficiency Quick Method

## The 12-TEN Approach
1. **Test Statement 1 alone**
2. **Test Statement 2 alone**
3. **Evaluate together if needed**
4. **Note your answer**

## Quick Decision Tree
```
      Statement 1 Sufficient?
         /           \\
       YES            NO
        │              │
   Statement 2     Statement 2
   Sufficient?     Sufficient?
    /     \\        /      \\
  YES     NO     YES      NO
   │       │      │        │
   D       A      B    Both Together?
                        /        \\
                      YES        NO
                       │          │
                       C          E
```

## Sufficiency Check
For YES/NO questions:
- Can you definitively say YES? → Sufficient
- Can you definitively say NO? → Sufficient
- Could be either? → NOT sufficient

For VALUE questions:
- Get unique value? → Sufficient
- Multiple values possible? → NOT sufficient

## Common Traps
1. **Redundant info**: Same fact stated differently
2. **Hidden sufficiency**: Info that seems incomplete but isn't
3. **Over-solving**: You don't need actual answer, just sufficiency
''',
    tags: ['data-sufficiency', 'shortcuts'],
    estimatedReadTime: 4,
    createdAt: DateTime.now(),
  ),

  // ==================== ALPHANUMERIC SHORTCUTS ====================

  StudyMaterial(
    id: 'bank_reason_s_alphanumeric_tricks',
    title: 'Alphanumeric Series Tricks',
    description: 'Quick alphanumeric problem solving',
    subjectId: 'reasoning_ability',
    topicId: 'alphanumeric_series',
    type: StudyMaterialType.shortcut,
    content: '''
# Alphanumeric Series Tricks

## Quick Position Finder
String: R3K@9M#2PD%7
Total: 12 characters

| From Left | From Right |
|-----------|------------|
| 1st = R | 12th = 7 |
| 5th = 9 | 8th = 2 |

**Right position = Total - Left + 1**

## Counting Questions
"How many letters between K and P?"
1. Find positions of K and P
2. Count characters between (exclusive)

## Swap/Reverse Questions
"If first and last are swapped..."
- Just swap mentally
- Apply the question condition

## Common Question Types

### Letters immediately followed by number
Scan: R**3**, K@9, M#2, P, D%**7**
Answer: R, D (2 letters)

### Numbers immediately preceded by symbol
Scan: R3, K@**9**, M#**2**, PD%**7**
Answer: 9, 2, 7 (3 numbers)

### Vowels followed by consonant
Check each vowel: Is next character consonant?

## Quick Scan Technique
For large strings:
1. Read question carefully
2. Scan left to right ONCE
3. Mark qualifying elements
4. Count marks
''',
    tags: ['alphanumeric', 'shortcuts'],
    estimatedReadTime: 4,
    createdAt: DateTime.now(),
  ),

  // ==================== CRITICAL REASONING SHORTCUTS ====================

  StudyMaterial(
    id: 'bank_reason_s_critical_tricks',
    title: 'Critical Reasoning Shortcuts',
    description: 'Quick logical reasoning methods',
    subjectId: 'reasoning_ability',
    topicId: 'critical_reasoning',
    type: StudyMaterialType.shortcut,
    content: '''
# Critical Reasoning Shortcuts

## Strengthen Questions
Look for answer that:
- Provides additional evidence
- Eliminates alternative explanations
- Supports the conclusion directly

## Weaken Questions
Look for answer that:
- Provides counter-evidence
- Shows alternative explanation
- Breaks the logic chain

## Assumption Questions
**Necessary Assumption**: Must be true for argument to work
**Sufficient Assumption**: If true, guarantees conclusion

## Inference Questions
Must be TRUE based on passage
- Don't go beyond what's stated
- "Must be true" not "could be true"

## Quick Elimination
| Eliminate if answer... |
|------------------------|
| Uses extreme language |
| Introduces new concepts |
| Contradicts passage |
| Is out of scope |
| Makes unsupported comparisons |

## Cause-Effect Analysis
Statement: A caused B
Strengthen: Show A always leads to B
Weaken: Show B happens without A

## Common Wrong Answer Traps
1. **Reverse logic**: Conclusion as premise
2. **Scope shift**: Shifts the topic
3. **Extreme**: Uses absolute terms
4. **Irrelevant**: True but doesn't affect argument
''',
    tags: ['critical-reasoning', 'shortcuts'],
    estimatedReadTime: 4,
    createdAt: DateTime.now(),
  ),
];
