import '../../../models/study_material_model.dart';

/// Banking Reasoning Ability - Formulas & Techniques
/// Comprehensive reasoning strategies for banking exams

final List<StudyMaterial> bankingReasoningFormulas = [
  // ==================== SEATING ARRANGEMENT ====================
  
  StudyMaterial(
    id: 'bank_reason_f_linear',
    title: 'Linear Seating Arrangement',
    description: 'Complete guide to linear arrangement problems',
    subjectId: 'reasoning_ability',
    topicId: 'seating_arrangement',
    type: StudyMaterialType.formula,
    content: '''
# Linear Seating Arrangement

## Basic Concepts

### Direction Rules
| Facing | Left of A | Right of A |
|--------|-----------|------------|
| North | West side | East side |
| South | East side | West side |

### Position Notation
- **Immediate left/right**: Adjacent position
- **Second to the left**: One person gap
- **Third from left end**: Position 3

## Key Formulas

### Total Arrangements
**n people in a row = n! ways**
(If no restrictions)

### Fixed Position
If k people fixed: **(n-k)! arrangements**

### Relative Position
If A must be left of B (not necessarily adjacent):
**Total arrangements / 2 = n!/2**

## Problem-Solving Steps
1. Draw the arrangement (line with positions)
2. Mark fixed positions first
3. Use definite clues before uncertain ones
4. Check all conditions after placing

## Common Clue Types
| Clue | Meaning |
|------|---------|
| A sits at extreme end | Position 1 or n |
| A sits exactly in middle | Position (n+1)/2 |
| A sits third from left | Position 3 |
| A sits second from right | Position (n-1) |
''',
    tags: ['seating', 'linear', 'arrangement'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  StudyMaterial(
    id: 'bank_reason_f_circular',
    title: 'Circular Seating Arrangement',
    description: 'Master circular arrangement problems',
    subjectId: 'reasoning_ability',
    topicId: 'seating_arrangement',
    type: StudyMaterialType.formula,
    content: '''
# Circular Seating Arrangement

## Basic Concepts

### Direction in Circle
| Facing | Clockwise | Anti-clockwise |
|--------|-----------|----------------|
| Center | Right | Left |
| Outside | Left | Right |

### Key Formula
**n people in circle = (n-1)! arrangements**
(One person fixed as reference)

## Position Rules

### Opposite Position
In a circle of n people:
- Opposite person is at position: **(n/2) + 1** from any person
- Only possible when n is even

### Distance Between Positions
Going clockwise from A to B:
- If B at position k from A: **k-1 people between**

## Facing Center vs Outside
| All face | Left neighbor | Right neighbor |
|----------|---------------|----------------|
| Center | Anti-clockwise | Clockwise |
| Outside | Clockwise | Anti-clockwise |

## Mixed Facing
- Some face center, some face outside
- Carefully note each person's facing direction
- Left/Right changes based on facing

## Problem-Solving Tips
1. Draw circle with positions numbered
2. Fix one person as reference
3. Mark facing direction (arrow toward/away center)
4. Place definite positions first
''',
    tags: ['seating', 'circular', 'arrangement'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  StudyMaterial(
    id: 'bank_reason_f_rectangular',
    title: 'Rectangular Seating Arrangement',
    description: 'Solve rectangular table arrangements',
    subjectId: 'reasoning_ability',
    topicId: 'seating_arrangement',
    type: StudyMaterialType.formula,
    content: '''
# Rectangular Seating Arrangement

## Basic Setup
```
    [1] [2] [3] [4]  ← North side
West                 East
    [8] [7] [6] [5]  ← South side
```

## Facing Rules
| Sitting on | Faces |
|------------|-------|
| North side | South |
| South side | North |

## Key Concepts

### Corner Positions
- 4 corners: positions 1, 4, 5, 8
- Corner person has only ONE neighbor

### Middle Positions
- 4 middle: positions 2, 3, 6, 7
- Middle person has TWO neighbors

### Opposite Person
| Position | Opposite |
|----------|----------|
| 1 | 8 |
| 2 | 7 |
| 3 | 6 |
| 4 | 5 |

## Direction Reference
| From North side | Left | Right |
|-----------------|------|-------|
| Facing South | East | West |

| From South side | Left | Right |
|-----------------|------|-------|
| Facing North | West | East |

## Problem Approach
1. Draw rectangle with numbered positions
2. Mark North/South sides clearly
3. Identify which side each person sits
4. Apply left/right based on facing direction
''',
    tags: ['seating', 'rectangular', 'arrangement'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  // ==================== BLOOD RELATIONS ====================

  StudyMaterial(
    id: 'bank_reason_f_blood_basic',
    title: 'Blood Relations Fundamentals',
    description: 'Complete blood relation guide',
    subjectId: 'reasoning_ability',
    topicId: 'blood_relations',
    type: StudyMaterialType.formula,
    content: '''
# Blood Relations Fundamentals

## Relationship Chart

### One Generation Up
| Male | Female |
|------|--------|
| Father | Mother |
| Uncle | Aunt |
| Father-in-law | Mother-in-law |

### Same Generation
| Male | Female |
|------|--------|
| Brother | Sister |
| Husband | Wife |
| Brother-in-law | Sister-in-law |
| Cousin | Cousin |

### One Generation Down
| Male | Female |
|------|--------|
| Son | Daughter |
| Nephew | Niece |
| Son-in-law | Daughter-in-law |

## Coded Relationships
| Symbol | Meaning |
|--------|---------|
| + | Male |
| - | Female |
| × | Married to |
| → | Parent of |

## Key Rules
1. **Only child of parents = No siblings**
2. **Brother of mother = Maternal uncle**
3. **Sister of father = Paternal aunt**
4. **Son of uncle/aunt = Cousin**
5. **Spouse relationships are NOT blood relations**

## Generation Counting
- Same generation = 0
- One up = +1 (parent, uncle, aunt)
- One down = -1 (child, nephew, niece)
- Two up = +2 (grandparent)
- Two down = -2 (grandchild)
''',
    tags: ['blood-relations', 'family'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  StudyMaterial(
    id: 'bank_reason_f_blood_coded',
    title: 'Coded Blood Relations',
    description: 'Decode complex family relationships',
    subjectId: 'reasoning_ability',
    topicId: 'blood_relations',
    type: StudyMaterialType.formula,
    content: '''
# Coded Blood Relations

## Common Coding Systems

### Symbol-Based
| Expression | Meaning |
|------------|---------|
| A + B | A is father of B |
| A - B | A is mother of B |
| A × B | A is brother of B |
| A ÷ B | A is sister of B |
| A = B | A is spouse of B |

### Letter-Based
| Expression | Meaning |
|------------|---------|
| A \$ B | A is parent of B |
| A # B | A is sibling of B |
| A @ B | A is spouse of B |
| A % B | A is child of B |

## Solving Strategy

### Step 1: Decode Each Symbol
Create a legend of all symbols

### Step 2: Draw Family Tree
```
    Grandfather ─ Grandmother
         │
    ┌────┴────┐
  Father    Uncle
    │
  ┌─┴─┐
 Son  Daughter
```

### Step 3: Trace the Path
Follow from person A to person B

### Step 4: Determine Relationship
Count generations and gender

## Common Patterns
| Path | Relationship |
|------|--------------|
| Parent's parent | Grandparent |
| Parent's sibling | Uncle/Aunt |
| Sibling's child | Nephew/Niece |
| Parent's sibling's child | Cousin |
''',
    tags: ['blood-relations', 'coded'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  // ==================== DIRECTION & DISTANCE ====================

  StudyMaterial(
    id: 'bank_reason_f_direction',
    title: 'Direction Sense Test',
    description: 'Master direction problems',
    subjectId: 'reasoning_ability',
    topicId: 'direction_distance',
    type: StudyMaterialType.formula,
    content: '''
# Direction Sense Test

## Direction Compass
```
        N
        │
   NW ──┼── NE
        │
W ──────┼────── E
        │
   SW ──┼── SE
        │
        S
```

## Turn Formulas

### Right Turn (Clockwise)
| From | 90° Right | 180° |
|------|-----------|------|
| N | E | S |
| E | S | W |
| S | W | N |
| W | N | E |

### Left Turn (Anti-clockwise)
| From | 90° Left | 180° |
|------|----------|------|
| N | W | S |
| E | N | W |
| S | E | N |
| W | S | E |

## Distance Calculation

### Shortest Distance (Pythagoras)
**d = √(x² + y²)**

Where:
- x = Net East-West displacement
- y = Net North-South displacement

### Movement Recording
| Direction | Effect on (x,y) |
|-----------|-----------------|
| North | y increases |
| South | y decreases |
| East | x increases |
| West | x decreases |

## Shadow Direction
| Time | Shadow Falls |
|------|--------------|
| Morning (before noon) | West |
| Evening (after noon) | East |
| Noon | Shortest, North/South |
''',
    tags: ['direction', 'distance'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  // ==================== CODING-DECODING ====================

  StudyMaterial(
    id: 'bank_reason_f_coding',
    title: 'Coding-Decoding Techniques',
    description: 'All coding patterns explained',
    subjectId: 'reasoning_ability',
    topicId: 'coding_decoding',
    type: StudyMaterialType.formula,
    content: '''
# Coding-Decoding Techniques

## Letter Coding Patterns

### Direct Shift
| Pattern | Example |
|---------|---------|
| +1 | A→B, B→C, CAT→DBU |
| +2 | A→C, B→D, CAT→ECV |
| -1 | B→A, C→B, CAT→BZS |
| Reverse | A→Z, B→Y, CAT→XZG |

### Position Values
A=1, B=2, C=3... Z=26
Reverse: A=26, B=25... Z=1

### Opposite Letters
| Letter | Opposite | Sum |
|--------|----------|-----|
| A | Z | 27 |
| B | Y | 27 |
| M | N | 27 |

**A+Z = B+Y = C+X = 27**

## Number Coding

### Place Value
| Code | Meaning |
|------|---------|
| 123 | ABC |
| 312 | CAB |

### Mathematical Operations
- Square of position
- Reverse of position
- Sum of positions

## Mixed Coding
Letters + Numbers + Symbols combined
Look for:
1. Position-based patterns
2. Sequential changes
3. Grouping patterns

## Problem-Solving Steps
1. Compare coded words with originals
2. Identify letter-by-letter changes
3. Find the consistent pattern
4. Apply pattern to new word
''',
    tags: ['coding', 'decoding'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  // ==================== SYLLOGISM ====================

  StudyMaterial(
    id: 'bank_reason_f_syllogism',
    title: 'Syllogism Rules & Venn Diagrams',
    description: 'Complete syllogism guide',
    subjectId: 'reasoning_ability',
    topicId: 'syllogism',
    type: StudyMaterialType.formula,
    content: '''
# Syllogism Rules

## Statement Types
| Type | Example | Meaning |
|------|---------|---------|
| All A are B | Universal Affirmative | Every A is B |
| No A is B | Universal Negative | No overlap |
| Some A are B | Particular Affirmative | At least one |
| Some A are not B | Particular Negative | At least one A outside B |

## Venn Diagram Representations

### All A are B
```
  ┌─────────────┐
  │     B       │
  │  ┌─────┐    │
  │  │  A  │    │
  │  └─────┘    │
  └─────────────┘
```

### No A is B
```
┌─────┐   ┌─────┐
│  A  │   │  B  │
└─────┘   └─────┘
```

### Some A are B
```
┌─────┬───┬─────┐
│  A  │ X │  B  │
└─────┴───┴─────┘
```

## Conversion Rules
| Original | Valid Conversion |
|----------|------------------|
| All A are B | Some B are A |
| No A is B | No B is A |
| Some A are B | Some B are A |
| Some A are not B | No valid conversion |

## Conclusion Rules
1. **At least one premise must be universal**
2. **If both premises are negative → No conclusion**
3. **If both premises are particular → No conclusion**
4. **Negative premise → Negative conclusion**
''',
    tags: ['syllogism', 'venn-diagram'],
    estimatedReadTime: 6,
    createdAt: DateTime.now(),
  ),

  StudyMaterial(
    id: 'bank_reason_f_syllogism_adv',
    title: 'Advanced Syllogism Techniques',
    description: 'Possibility cases and either-or',
    subjectId: 'reasoning_ability',
    topicId: 'syllogism',
    type: StudyMaterialType.formula,
    content: '''
# Advanced Syllogism Techniques

## Possibility Cases

### "Some A are B" allows:
- All A are B (possible)
- All B are A (possible)
- Some A are not B (possible)

### "All A are B" allows:
- All B are A (possible)
- Some B are not A (possible)

### "No A is B" BLOCKS:
- Some A are B (not possible)
- All A are B (not possible)

## Either-Or Conclusions

### When to use Either-Or:
Both conclusions individually follow OR
Exactly one must be true

### Example:
Statement: Some A are B
Conclusions:
I. All A are B
II. Some A are not B

**Either I or II follows** (but not both definitely)

## Complementary Pairs
| Pair 1 | Pair 2 | Relationship |
|--------|--------|--------------|
| All A are B | Some A are not B | Complementary |
| No A is B | Some A are B | Complementary |

## Problem-Solving Strategy
1. Draw all possible Venn diagrams
2. Check each conclusion in ALL diagrams
3. Conclusion follows only if true in ALL cases
4. For "possibility" - true in at least ONE case
''',
    tags: ['syllogism', 'advanced'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  // ==================== INEQUALITY ====================

  StudyMaterial(
    id: 'bank_reason_f_inequality',
    title: 'Inequality & Ranking',
    description: 'Master coded inequality problems',
    subjectId: 'reasoning_ability',
    topicId: 'inequality',
    type: StudyMaterialType.formula,
    content: '''
# Inequality & Ranking

## Basic Symbols
| Symbol | Meaning |
|--------|---------|
| > | Greater than |
| < | Less than |
| ≥ | Greater than or equal |
| ≤ | Less than or equal |
| = | Equal to |

## Combination Rules

### Definite Conclusions
| If | Then |
|----|------|
| A > B > C | A > C ✓ |
| A ≥ B > C | A > C ✓ |
| A > B ≥ C | A > C ✓ |
| A ≥ B ≥ C | A ≥ C ✓ |

### No Definite Conclusion
| Combination | Result |
|-------------|--------|
| A > B < C | Can't compare A and C |
| A < B > C | Can't compare A and C |
| A > B = C | A > C ✓ |

## Coded Inequality

### Common Codes
| Code | Meaning |
|------|---------|
| @ | > |
| # | < |
| \$ | = |
| % | ≥ |
| & | ≤ |

### Solving Steps
1. Decode all symbols
2. Write in standard form
3. Chain the inequalities
4. Check conclusions

## Key Tips
- **Direction must be consistent** to draw conclusion
- **Mixed directions = No conclusion**
- **Equal sign** preserves the direction
''',
    tags: ['inequality', 'ranking'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  // ==================== PUZZLES ====================

  StudyMaterial(
    id: 'bank_reason_f_floor',
    title: 'Floor Puzzle Techniques',
    description: 'Solve floor-based puzzles systematically',
    subjectId: 'reasoning_ability',
    topicId: 'puzzles',
    type: StudyMaterialType.formula,
    content: '''
# Floor Puzzle Techniques

## Basic Setup
```
Floor 8 ─ Topmost
Floor 7
Floor 6
Floor 5
Floor 4
Floor 3
Floor 2
Floor 1 ─ Ground/Bottommost
```

## Key Terms
| Term | Meaning |
|------|---------|
| Above | Higher floor number |
| Below | Lower floor number |
| Immediately above | Next floor up |
| Immediately below | Next floor down |
| Between A and B | Floors in the middle |

## Problem-Solving Method

### Step 1: Draw Grid
```
Floor | Person | Other Info
──────┼────────┼───────────
  8   │        │
  7   │        │
  ...
```

### Step 2: Use Definite Clues
- "A lives on floor 5" → Fix A at 5
- "A lives on topmost floor" → Fix A at highest

### Step 3: Use Relative Clues
- "B is immediately above A" → B = A + 1
- "3 floors between C and D" → Difference = 4

### Step 4: Use Negative Clues
- "E doesn't live on floor 1" → Eliminate
- "F is not above G" → F ≤ G

## Gap Formula
**"n people/floors between A and B"**
**|Position A - Position B| = n + 1**
''',
    tags: ['puzzles', 'floor'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  StudyMaterial(
    id: 'bank_reason_f_scheduling',
    title: 'Scheduling & Ordering Puzzles',
    description: 'Days, months, time-based puzzles',
    subjectId: 'reasoning_ability',
    topicId: 'puzzles',
    type: StudyMaterialType.formula,
    content: '''
# Scheduling & Ordering Puzzles

## Days of Week
| Day | Code |
|-----|------|
| Monday | 1 |
| Tuesday | 2 |
| Wednesday | 3 |
| Thursday | 4 |
| Friday | 5 |
| Saturday | 6 |
| Sunday | 7 |

## Key Terms
| Term | Meaning |
|------|---------|
| After Monday | Tuesday onwards |
| Before Friday | Thursday or earlier |
| Between Mon-Fri | Tue, Wed, Thu |
| Neither Mon nor Tue | Other 5 days |

## Months of Year
| Month | Days | Code |
|-------|------|------|
| Jan | 31 | 1 |
| Feb | 28/29 | 2 |
| Mar | 31 | 3 |
| ... | ... | ... |
| Dec | 31 | 12 |

## Ordering Rules
1. **"A is before B"** → A comes earlier
2. **"A is immediately before B"** → A, B adjacent
3. **"A is 2 days after B"** → Gap of 1 day
4. **"A is not immediately after B"** → At least 1 gap

## Problem Approach
1. List all positions/days
2. Place fixed/definite items
3. Apply relative constraints
4. Use elimination for remaining
''',
    tags: ['puzzles', 'scheduling', 'ordering'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  // ==================== INPUT-OUTPUT ====================

  StudyMaterial(
    id: 'bank_reason_f_input_output',
    title: 'Input-Output Machine',
    description: 'Decode input-output patterns',
    subjectId: 'reasoning_ability',
    topicId: 'input_output',
    type: StudyMaterialType.formula,
    content: '''
# Input-Output Machine

## Common Operations

### On Words
| Operation | Example |
|-----------|---------|
| Alphabetical sort | dog, cat → cat, dog |
| Reverse alphabetical | cat, dog → dog, cat |
| By length (short first) | apple, cat → cat, apple |
| By length (long first) | cat, apple → apple, cat |

### On Numbers
| Operation | Example |
|-----------|---------|
| Ascending | 5, 2, 8 → 2, 5, 8 |
| Descending | 5, 2, 8 → 8, 5, 2 |
| By digit sum | 29, 15 → 15, 29 |

### Mixed Operations
- Sort words and numbers separately
- Alternate word-number pattern
- Position-based swapping

## Pattern Detection Steps

### Step 1: Count Elements
Input has n elements, output has n elements?

### Step 2: Compare Positions
Which element moved where?

### Step 3: Find Rule
- One element sorted per step?
- Pairs swapped?
- Rotation pattern?

### Step 4: Verify
Apply rule to all steps to confirm

## Common Patterns
1. **Bubble sort**: One element reaches final position per step
2. **Insertion sort**: Elements inserted in sorted order
3. **Swap adjacent**: Pairs exchanged based on rule
''',
    tags: ['input-output', 'machine'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  // ==================== ALPHANUMERIC SERIES ====================

  StudyMaterial(
    id: 'bank_reason_f_alphanumeric',
    title: 'Alphanumeric Series',
    description: 'Letter-number combination patterns',
    subjectId: 'reasoning_ability',
    topicId: 'alphanumeric_series',
    type: StudyMaterialType.formula,
    content: '''
# Alphanumeric Series

## Letter Position Values
| A-E | F-J | K-O | P-T | U-Z |
|-----|-----|-----|-----|-----|
| 1-5 | 6-10 | 11-15 | 16-20 | 21-26 |

**Quick**: L=12, M=13, N=14 (middle letters)

## Common Patterns

### Alternating Pattern
A1B2C3D4E5...
- Letters: Sequential
- Numbers: Sequential

### Skip Pattern
A2D5G8J11...
- Letters: Skip 2 (+3)
- Numbers: Skip 2 (+3)

### Reverse Pattern
Z1Y2X3W4...
- Letters: Reverse order
- Numbers: Sequential

## Position-Based Questions

### "How many...between...and..."
Count elements satisfying the condition

### "Which element is nth from left/right"
- From left: Position n
- From right: Position (total - n + 1)

### "Letters/Numbers between X and Y"
Count excluding X and Y

## Arrangement Questions
String: B4D#9F%2H
- 2nd from left = 4
- 3rd from right = 2
- Numbers between B and H = 4, 9, 2
''',
    tags: ['alphanumeric', 'series'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  // ==================== DATA SUFFICIENCY ====================

  StudyMaterial(
    id: 'bank_reason_f_data_suff',
    title: 'Data Sufficiency Techniques',
    description: 'Systematic data sufficiency approach',
    subjectId: 'reasoning_ability',
    topicId: 'data_sufficiency',
    type: StudyMaterialType.formula,
    content: '''
# Data Sufficiency Techniques

## Answer Options (Standard)
| Option | Meaning |
|--------|---------|
| A | Statement I alone sufficient |
| B | Statement II alone sufficient |
| C | Both together necessary |
| D | Either alone sufficient |
| E | Both together not sufficient |

## Evaluation Process

### Step 1: Analyze Statement I
- Can it answer the question alone?
- Mark: Sufficient (S) or Not Sufficient (NS)

### Step 2: Analyze Statement II
- Can it answer the question alone?
- Mark: Sufficient (S) or Not Sufficient (NS)

### Step 3: Combine if Needed
Only if both are individually NS:
- Use both statements together
- Can they answer now?

## Decision Matrix
| Stmt I | Stmt II | Answer |
|--------|---------|--------|
| S | S | D |
| S | NS | A |
| NS | S | B |
| NS | NS, Combined S | C |
| NS | NS, Combined NS | E |

## Key Tips
1. **Don't solve** - just check sufficiency
2. **Unique answer needed** - not just any answer
3. **Yes/No questions** - must definitively determine
4. **Value questions** - must find exact value
''',
    tags: ['data-sufficiency'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  // ==================== STATEMENT & CONCLUSION ====================

  StudyMaterial(
    id: 'bank_reason_f_statement_conclusion',
    title: 'Statement & Conclusion Analysis',
    description: 'Evaluate logical conclusions',
    subjectId: 'reasoning_ability',
    topicId: 'statement_conclusion',
    type: StudyMaterialType.formula,
    content: '''
# Statement & Conclusion Analysis

## Key Principle
**Conclusion must LOGICALLY follow from statement**
- No assumptions beyond given facts
- No common knowledge unless stated
- Direct inference only

## Types of Conclusions

### Valid Conclusion
- Directly derived from statement
- No external information needed
- Logically necessary

### Invalid Conclusion
- Requires assumption
- Contradicts statement
- Goes beyond statement scope

## Evaluation Method

### Step 1: Understand Statement
- Identify all facts stated
- Note the scope and limitations

### Step 2: Check Each Conclusion
| Ask | If Yes | If No |
|-----|--------|-------|
| Is it directly stated? | Valid | Check further |
| Can it be inferred? | Valid | Check further |
| Does it need assumption? | Invalid | - |
| Does it contradict? | Invalid | - |

## Common Traps
1. **Over-generalization**: "Some" doesn't mean "All"
2. **Assumed knowledge**: Using external facts
3. **Reverse logic**: If A→B, doesn't mean B→A
4. **Degree shift**: "May" is not "Must"

## Answer Options
- Only I follows
- Only II follows
- Both follow
- Neither follows
- Either I or II follows
''',
    tags: ['statement', 'conclusion'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  // ==================== CAUSE & EFFECT ====================

  StudyMaterial(
    id: 'bank_reason_f_cause_effect',
    title: 'Cause & Effect Reasoning',
    description: 'Identify causal relationships',
    subjectId: 'reasoning_ability',
    topicId: 'cause_effect',
    type: StudyMaterialType.formula,
    content: '''
# Cause & Effect Reasoning

## Definition
- **Cause**: Event that produces another event
- **Effect**: Result/outcome of the cause

## Relationship Types

### Independent Events
- No causal connection
- Coincidental occurrence

### Cause-Effect Pair
| Scenario | Example |
|----------|---------|
| I causes II | Rain → Wet roads |
| II causes I | Wet roads ← Rain |
| Common cause | Both caused by third factor |
| Chain effect | A→B→C |

## Identification Criteria

### Cause Indicators
- "Due to", "Because of"
- "As a result of"
- "Owing to"
- Happened BEFORE effect

### Effect Indicators
- "Therefore", "Hence"
- "Consequently"
- "As a result"
- Happened AFTER cause

## Answer Options
| Code | Meaning |
|------|---------|
| A | I is cause, II is effect |
| B | II is cause, I is effect |
| C | Independent events |
| D | Both effects of common cause |
| E | Both causes of common effect |

## Quick Check
1. Which event happened first? (Usually cause)
2. Does one logically lead to other?
3. Could both have independent causes?
''',
    tags: ['cause', 'effect'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  // ==================== VERBAL REASONING ====================

  StudyMaterial(
    id: 'bank_reason_f_course_action',
    title: 'Course of Action Analysis',
    description: 'Evaluate appropriate actions',
    subjectId: 'reasoning_ability',
    topicId: 'course_of_action',
    type: StudyMaterialType.formula,
    content: '''
# Course of Action Analysis

## Definition
Course of Action = Steps to solve/address a problem

## Evaluation Criteria

### Valid Course of Action
1. **Practical**: Can be implemented
2. **Relevant**: Addresses the problem directly
3. **Legal**: Within laws and ethics
4. **Effective**: Likely to solve the issue

### Invalid Course of Action
1. **Impractical**: Cannot be implemented
2. **Irrelevant**: Doesn't address the issue
3. **Extreme**: Disproportionate response
4. **Harmful**: Creates new problems

## Common Question Types

### Government Policy
| Valid | Invalid |
|-------|---------|
| Awareness campaigns | Immediate ban |
| Gradual implementation | Overnight change |
| Stakeholder consultation | Unilateral decision |

### Problem Solving
| Valid | Invalid |
|-------|---------|
| Root cause analysis | Symptomatic fix |
| Preventive measures | Only punitive |
| Sustainable solution | Temporary patch |

## Answer Selection
- Only I follows
- Only II follows
- Both follow
- Neither follows

## Key Principle
**Action should be proportionate and directly related to the problem stated**
''',
    tags: ['course-of-action'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  StudyMaterial(
    id: 'bank_reason_f_assumption',
    title: 'Statement & Assumption',
    description: 'Identify hidden assumptions',
    subjectId: 'reasoning_ability',
    topicId: 'statement_assumption',
    type: StudyMaterialType.formula,
    content: '''
# Statement & Assumption

## Definition
**Assumption**: Unstated belief that must be true for the statement to make sense

## Identification Rules

### Valid Assumption
- Required for statement to hold
- Not directly stated
- Logically necessary
- Within statement scope

### Invalid Assumption
- Already stated (redundant)
- Contradicts statement
- Beyond scope
- Unrelated to statement

## Testing Method

### Negation Test
1. Negate the assumption
2. If statement becomes meaningless/contradictory
3. Then assumption is VALID

### Example
Statement: "Join our coaching for guaranteed success"
Assumption: "Coaching helps in success"
Negation: "Coaching doesn't help"
→ Statement becomes meaningless
→ Assumption is VALID

## Common Assumption Types
| Type | Example |
|------|---------|
| Capability | People can do X |
| Desirability | People want X |
| Feasibility | X is possible |
| Continuity | Situation continues |

## Answer Options
- Only I is implicit
- Only II is implicit
- Both are implicit
- Neither is implicit
- Either I or II is implicit
''',
    tags: ['statement', 'assumption'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  StudyMaterial(
    id: 'bank_reason_f_argument',
    title: 'Strong & Weak Arguments',
    description: 'Evaluate argument strength',
    subjectId: 'reasoning_ability',
    topicId: 'strong_weak_arguments',
    type: StudyMaterialType.formula,
    content: '''
# Strong & Weak Arguments

## Argument Definition
- **Argument**: Reason supporting or opposing a statement
- **Strong**: Valid, relevant, convincing
- **Weak**: Invalid, irrelevant, unconvincing

## Strong Argument Criteria
1. **Relevant**: Directly relates to statement
2. **Factual**: Based on facts, not opinions
3. **Significant**: Substantial impact
4. **Universal**: Applies broadly
5. **Practical**: Realistic consideration

## Weak Argument Indicators
| Indicator | Example |
|-----------|---------|
| Emotional appeal | "Think of the children!" |
| Single example | "My friend had bad experience" |
| Extreme language | "Always", "Never", "Everyone" |
| Unrelated facts | Topic drift |
| Assumptions | "Everyone knows..." |

## Evaluation Process

### For Each Argument:
1. Is it related to the topic?
2. Does it provide substantial reason?
3. Is it based on facts?
4. Is it logically valid?

All YES → **Strong**
Any NO → **Weak**

## Answer Options
- Only I is strong
- Only II is strong
- Both are strong
- Neither is strong
- Either I or II is strong
''',
    tags: ['argument', 'strong', 'weak'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),
];
