import '../../../exam_prep/models/study_material_model.dart';

/// Comprehensive study materials for SSC exams (CGL, CHSL, MTS, CPO)
final List<StudyMaterial> sscStudyMaterials = [
  // ==================== QUANTITATIVE APTITUDE ====================
  
  StudyMaterial(
    id: 'ssc_quant_number_system',
    title: 'Number System - Complete Guide',
    description: 'Master number system concepts for SSC exams with shortcuts',
    subjectId: 'quantitative_aptitude',
    topicId: 'number_system',
    type: StudyMaterialType.notes,
    content: '''
# Number System for SSC Exams

## Types of Numbers

### Natural Numbers (N)
- Counting numbers: 1, 2, 3, 4, ...
- Smallest natural number: **1**
- No largest natural number

### Whole Numbers (W)
- Natural numbers + 0: 0, 1, 2, 3, ...
- Smallest whole number: **0**

### Integers (Z)
- ..., -3, -2, -1, 0, 1, 2, 3, ...
- Includes negative numbers

### Rational Numbers (Q)
- Numbers expressible as p/q where q ≠ 0
- Examples: 1/2, -3/4, 0.75

### Irrational Numbers
- Cannot be expressed as p/q
- Examples: √2, √3, π, e

## Divisibility Rules

| Divisor | Rule |
|---------|------|
| **2** | Last digit is even (0, 2, 4, 6, 8) |
| **3** | Sum of digits divisible by 3 |
| **4** | Last 2 digits divisible by 4 |
| **5** | Last digit is 0 or 5 |
| **6** | Divisible by both 2 and 3 |
| **8** | Last 3 digits divisible by 8 |
| **9** | Sum of digits divisible by 9 |
| **11** | |Odd place sum - Even place sum| divisible by 11 |

## Important Formulas

### Sum Formulas
- Sum of first n natural numbers: **n(n+1)/2**
- Sum of squares: **n(n+1)(2n+1)/6**
- Sum of cubes: **[n(n+1)/2]²**

### Product Shortcuts
- (a+b)² = a² + 2ab + b²
- (a-b)² = a² - 2ab + b²
- a² - b² = (a+b)(a-b)
- (a+b)³ = a³ + b³ + 3ab(a+b)

## HCF and LCM

### Finding HCF
1. **Prime Factorization**: Take common factors with least power
2. **Division Method**: Divide larger by smaller, continue with remainders

### Finding LCM
1. **Prime Factorization**: Take all factors with highest power
2. **Formula**: LCM × HCF = Product of numbers

### Important Relations
- For two numbers a and b: **LCM × HCF = a × b**
- LCM is always ≥ larger number
- HCF is always ≤ smaller number

## SSC Exam Tips
1. **Unit digit problems**: Focus on cyclicity patterns
2. **Remainder problems**: Use remainder theorem
3. **Factor counting**: Use prime factorization formula
4. Memorize squares up to 30 and cubes up to 15
''',
    tags: ['number system', 'divisibility', 'hcf lcm', 'ssc cgl', 'ssc chsl'],
    estimatedReadTime: 15,
    createdAt: DateTime(2024, 1, 15),
    rating: 4.8,
  ),

  StudyMaterial(
    id: 'ssc_quant_percentage',
    title: 'Percentage - Shortcuts & Tricks',
    description: 'Quick calculation methods for percentage problems in SSC',
    subjectId: 'quantitative_aptitude',
    topicId: 'percentage',
    type: StudyMaterialType.shortcut,
    content: '''
# Percentage Shortcuts for SSC

## Basic Conversions (Memorize!)

| Fraction | Percentage |
|----------|------------|
| 1/2 | 50% |
| 1/3 | 33.33% |
| 1/4 | 25% |
| 1/5 | 20% |
| 1/6 | 16.67% |
| 1/7 | 14.28% |
| 1/8 | 12.5% |
| 1/9 | 11.11% |
| 1/10 | 10% |
| 1/11 | 9.09% |
| 1/12 | 8.33% |

## Successive Percentage Change

When value changes by a% then b%:
**Net change = a + b + (ab/100)%**

### Example
- Price increases by 20% then decreases by 10%
- Net change = 20 - 10 + (20×(-10))/100 = 10 - 2 = **8% increase**

## Population Formula

- After n years: **P(1 + r/100)ⁿ**
- Before n years: **P/(1 + r/100)ⁿ**

## Quick Calculation Tricks

### Finding X% of Y
- **10% of any number**: Move decimal one place left
- **5%**: Half of 10%
- **15%**: 10% + 5%
- **20%**: Double of 10%
- **25%**: Divide by 4

### Percentage Increase/Decrease
- If A is x% more than B: **A = B(100+x)/100**
- If A is x% less than B: **A = B(100-x)/100**

## Important Relations

If A is x% more than B, then B is less than A by:
**[x/(100+x)] × 100%**

If A is x% less than B, then B is more than A by:
**[x/(100-x)] × 100%**

## SSC Pattern Questions

### Type 1: Expenditure Problems
- If income increases by 20% and savings remain same
- Expenditure increase = (Income increase × 100)/(100 - Savings%)

### Type 2: Election Problems
- Winner gets W% votes, difference = D
- Total votes = **D × 100 / (2W - 100)**
''',
    tags: ['percentage', 'shortcuts', 'quick math', 'ssc'],
    estimatedReadTime: 12,
    createdAt: DateTime(2024, 1, 16),
    rating: 4.9,
  ),

  StudyMaterial(
    id: 'ssc_quant_algebra',
    title: 'Algebra - Essential Formulas',
    description: 'All algebraic identities and formulas for SSC exams',
    subjectId: 'quantitative_aptitude',
    topicId: 'algebra',
    type: StudyMaterialType.formula,
    content: '''
# Algebra Formulas for SSC

## Basic Identities

### Square Identities
- (a + b)² = a² + 2ab + b²
- (a - b)² = a² - 2ab + b²
- (a + b)² + (a - b)² = 2(a² + b²)
- (a + b)² - (a - b)² = 4ab
- a² - b² = (a + b)(a - b)

### Cube Identities
- (a + b)³ = a³ + b³ + 3ab(a + b)
- (a - b)³ = a³ - b³ - 3ab(a - b)
- a³ + b³ = (a + b)(a² - ab + b²)
- a³ - b³ = (a - b)(a² + ab + b²)
- a³ + b³ + c³ - 3abc = (a + b + c)(a² + b² + c² - ab - bc - ca)

## If a + b + c = 0
Then: **a³ + b³ + c³ = 3abc**

## Special Values

### If x + 1/x = k
- x² + 1/x² = **k² - 2**
- x³ + 1/x³ = **k³ - 3k**
- x⁴ + 1/x⁴ = **(k² - 2)² - 2**

### If x - 1/x = k
- x² + 1/x² = **k² + 2**
- x³ - 1/x³ = **k³ + 3k**

## Factorization Patterns

### Common Patterns
- x² + y² + 2xy = (x + y)²
- x² + y² - 2xy = (x - y)²
- x² - y² = (x + y)(x - y)
- x³ + y³ = (x + y)(x² - xy + y²)
- x³ - y³ = (x - y)(x² + xy + y²)

## Quadratic Equations

### Standard Form: ax² + bx + c = 0

- Sum of roots (α + β) = **-b/a**
- Product of roots (αβ) = **c/a**
- Discriminant (D) = **b² - 4ac**

### Nature of Roots
| Condition | Nature |
|-----------|--------|
| D > 0 | Real and distinct |
| D = 0 | Real and equal |
| D < 0 | Imaginary |
| D = perfect square | Rational |

## SSC Special Tricks

### Quick Substitution
If asked value of expression when x = 999:
- Use x = 1000 - 1
- Apply identities

### Symmetric Functions
If α, β are roots:
- α² + β² = (α + β)² - 2αβ
- α³ + β³ = (α + β)³ - 3αβ(α + β)
''',
    tags: ['algebra', 'formulas', 'identities', 'quadratic', 'ssc'],
    estimatedReadTime: 14,
    createdAt: DateTime(2024, 1, 17),
    rating: 4.7,
  ),

  StudyMaterial(
    id: 'ssc_quant_geometry',
    title: 'Geometry - Complete Concepts',
    description: 'Triangles, circles, and quadrilaterals for SSC',
    subjectId: 'quantitative_aptitude',
    topicId: 'geometry',
    type: StudyMaterialType.notes,
    content: '''
# Geometry for SSC Exams

## Triangle Properties

### Basic Properties
- Sum of angles = **180°**
- Exterior angle = Sum of interior opposite angles
- Sum of any two sides > Third side

### Types by Sides
| Type | Property |
|------|----------|
| Equilateral | All sides equal, all angles 60° |
| Isosceles | Two sides equal |
| Scalene | All sides different |

### Types by Angles
| Type | Property |
|------|----------|
| Acute | All angles < 90° |
| Right | One angle = 90° |
| Obtuse | One angle > 90° |

## Triangle Centers

### Centroid (G)
- Intersection of medians
- Divides median in ratio **2:1** from vertex
- Area of triangle = 3 × Area of smaller triangles

### Incenter (I)
- Intersection of angle bisectors
- Center of inscribed circle
- Equidistant from all sides

### Circumcenter (O)
- Intersection of perpendicular bisectors
- Center of circumscribed circle
- Equidistant from all vertices

### Orthocenter (H)
- Intersection of altitudes
- For acute △: Inside
- For right △: At right angle vertex
- For obtuse △: Outside

## Important Formulas

### Area of Triangle
- Base × Height / 2
- √[s(s-a)(s-b)(s-c)] (Heron's formula, s = semi-perimeter)
- (1/2) × a × b × sin C

### Special Triangles
- **30-60-90**: Sides in ratio 1 : √3 : 2
- **45-45-90**: Sides in ratio 1 : 1 : √2

## Circle Properties

### Basic Formulas
- Circumference = 2πr
- Area = πr²
- Arc length = (θ/360°) × 2πr
- Sector area = (θ/360°) × πr²

### Important Theorems

#### Tangent Properties
- Tangent ⊥ Radius at point of contact
- Two tangents from external point are equal
- PT² = PA × PB (tangent-secant)

#### Chord Properties
- Equal chords are equidistant from center
- Perpendicular from center bisects chord
- Angle in semicircle = 90°

### Cyclic Quadrilateral
- Sum of opposite angles = 180°
- Ptolemy's theorem: AC × BD = AB × CD + AD × BC

## Quadrilateral Properties

| Shape | Area Formula |
|-------|--------------|
| Square | side² |
| Rectangle | length × breadth |
| Parallelogram | base × height |
| Rhombus | (d₁ × d₂)/2 |
| Trapezium | (1/2)(a + b) × h |

## SSC Geometry Tips
1. Draw accurate diagrams
2. Look for similar triangles
3. Use properties of parallel lines
4. Remember angle chase techniques
''',
    tags: ['geometry', 'triangles', 'circles', 'quadrilaterals', 'ssc'],
    estimatedReadTime: 18,
    createdAt: DateTime(2024, 1, 18),
    rating: 4.8,
  ),

  StudyMaterial(
    id: 'ssc_quant_trigonometry',
    title: 'Trigonometry - Quick Revision',
    description: 'All trigonometric ratios, identities and formulas',
    subjectId: 'quantitative_aptitude',
    topicId: 'trigonometry',
    type: StudyMaterialType.formula,
    content: '''
# Trigonometry for SSC

## Basic Ratios

In a right triangle with angle θ:
- sin θ = Opposite / Hypotenuse
- cos θ = Adjacent / Hypotenuse
- tan θ = Opposite / Adjacent
- cot θ = Adjacent / Opposite
- sec θ = Hypotenuse / Adjacent
- cosec θ = Hypotenuse / Opposite

## Standard Values

| Angle | 0° | 30° | 45° | 60° | 90° |
|-------|-----|-----|-----|-----|-----|
| sin | 0 | 1/2 | 1/√2 | √3/2 | 1 |
| cos | 1 | √3/2 | 1/√2 | 1/2 | 0 |
| tan | 0 | 1/√3 | 1 | √3 | ∞ |

## Fundamental Identities

### Pythagorean Identities
- sin²θ + cos²θ = 1
- 1 + tan²θ = sec²θ
- 1 + cot²θ = cosec²θ

### Reciprocal Relations
- sin θ × cosec θ = 1
- cos θ × sec θ = 1
- tan θ × cot θ = 1

### Quotient Relations
- tan θ = sin θ / cos θ
- cot θ = cos θ / sin θ

## Compound Angle Formulas

- sin(A ± B) = sin A cos B ± cos A sin B
- cos(A ± B) = cos A cos B ∓ sin A sin B
- tan(A ± B) = (tan A ± tan B)/(1 ∓ tan A tan B)

## Double Angle Formulas

- sin 2A = 2 sin A cos A
- cos 2A = cos²A - sin²A = 2cos²A - 1 = 1 - 2sin²A
- tan 2A = 2 tan A / (1 - tan²A)

## Half Angle Formulas

- sin(A/2) = √[(1 - cos A)/2]
- cos(A/2) = √[(1 + cos A)/2]
- tan(A/2) = √[(1 - cos A)/(1 + cos A)]

## Height and Distance

### Angle of Elevation
Angle made by line of sight with horizontal when looking UP

### Angle of Depression
Angle made by line of sight with horizontal when looking DOWN

### Key Formulas
- Height = Distance × tan(elevation angle)
- When angles are complementary (sum = 90°): Height = √(d₁ × d₂)

## SSC Shortcuts

### Quick Values
- sin²30° + cos²60° = 1/4 + 1/4 = 1/2
- tan 45° × cot 45° = 1
- sec²45° - tan²45° = 1

### Signs in Quadrants (ASTC Rule)
- Q1: All positive
- Q2: Sin positive
- Q3: Tan positive
- Q4: Cos positive
''',
    tags: ['trigonometry', 'ratios', 'identities', 'height distance', 'ssc'],
    estimatedReadTime: 15,
    createdAt: DateTime(2024, 1, 19),
    rating: 4.9,
  ),

  // ==================== REASONING ====================
  
  StudyMaterial(
    id: 'ssc_reasoning_analogy',
    title: 'Analogy - Complete Guide',
    description: 'Master verbal and non-verbal analogy for SSC',
    subjectId: 'reasoning',
    topicId: 'analogy',
    type: StudyMaterialType.notes,
    content: '''
# Analogy for SSC Reasoning

## What is Analogy?
Analogy means **similarity or comparison**. In these questions, a relationship is given and you need to find a similar relationship.

## Types of Analogies

### 1. Word Analogies

#### Synonym Relationships
- Happy : Joyful :: Sad : Melancholy
- Big : Large :: Small : Tiny

#### Antonym Relationships
- Hot : Cold :: Wet : Dry
- Light : Dark :: Good : Bad

#### Part to Whole
- Page : Book :: Leaf : Tree
- Wheel : Car :: Key : Keyboard

#### Worker to Tool
- Carpenter : Hammer :: Surgeon : Scalpel
- Artist : Brush :: Writer : Pen

#### Product to Raw Material
- Cloth : Cotton :: Paper : Pulp
- Furniture : Wood :: Ornament : Gold

#### Place Relationships
- India : New Delhi :: France : Paris
- Kolkata : West Bengal :: Mumbai : Maharashtra

### 2. Number Analogies

#### Square Relationship
- 4 : 16 :: 5 : 25 (n : n²)

#### Cube Relationship
- 2 : 8 :: 3 : 27 (n : n³)

#### Prime Numbers
- 2 : 3 :: 5 : 7 (consecutive primes)

#### Mathematical Operations
- 12 : 144 :: 13 : 169 (n : n²)
- 6 : 36 : 8 :: 64 (n : n²)

### 3. Letter Analogies

#### Position Based
- A : Z :: B : Y (1st from start : 1st from end)
- C : F :: M : P (difference of 3)

#### Opposite Position
- ACE : ZXV (positions add to 27)

## Solving Strategies

### Step 1: Identify Relationship
Look at the given pair and understand their connection

### Step 2: Apply Same Relationship
Use the same logic for the answer pair

### Step 3: Verify
Check if your answer follows the exact same pattern

## Common Relationships to Remember

| Relationship | Example |
|--------------|---------|
| Male : Female | Bull : Cow |
| Young : Adult | Cub : Lion |
| Sound : Animal | Bark : Dog |
| Group name | Flock : Birds |
| Study of | Botany : Plants |
| Instrument | Doctor : Stethoscope |

## SSC Exam Tips
1. Practice different types daily
2. Build vocabulary for word analogies
3. Know number patterns (squares, cubes, primes)
4. Learn letter positions (A=1, B=2... Z=26)
''',
    tags: ['analogy', 'reasoning', 'verbal', 'non-verbal', 'ssc'],
    estimatedReadTime: 12,
    createdAt: DateTime(2024, 1, 20),
    rating: 4.7,
  ),

  StudyMaterial(
    id: 'ssc_reasoning_coding_decoding',
    title: 'Coding-Decoding - All Patterns',
    description: 'Complete guide to coding-decoding problems',
    subjectId: 'reasoning',
    topicId: 'coding_decoding',
    type: StudyMaterialType.notes,
    content: '''
# Coding-Decoding for SSC

## Types of Coding

### 1. Letter Shifting Codes

#### Forward Shift
Each letter is replaced by letter +n positions
- A→C, B→D (shift +2)
- CAT → ECW (+2 shift)

#### Backward Shift
Each letter is replaced by letter -n positions
- C→A, D→B (shift -2)
- DOG → BME (-2 shift)

#### Variable Shift
Different positions have different shifts
- 1st letter +1, 2nd letter +2, etc.

### 2. Reverse Coding
- COME → EMOC (simple reverse)
- COMPUTER → RETUPMOC

### 3. Position Coding
Letters replaced by their position numbers
- A=1, B=2, C=3... Z=26
- CAT → 3-1-20

### 4. Opposite Letter Coding
Each letter replaced by its opposite
- A↔Z, B↔Y, C↔X...
- Opposite of A (1) = Z (26), sum = 27
- ABC → ZYX

### 5. Symbol/Number Coding
Letters assigned specific symbols or numbers
- If ROPE = @#\$%, then PORE = %#@\$

## Number Coding Patterns

### Pattern 1: Letter Sum
- FACE = 6+1+3+5 = 15
- Each letter's position summed

### Pattern 2: Multiplication
- AB = 1×2 = 2
- CAT = 3×1×20 = 60

### Pattern 3: Coded Values
- If GO = 32, AT = ?
- G(7)+O(15) = 22... find pattern
- Then apply to AT

## Solving Techniques

### Step 1: Compare Given Pairs
Look at the word and its code carefully

### Step 2: Find the Pattern
- Check for shifting
- Check for reversing
- Check for position values

### Step 3: Apply Pattern
Use the same rule on the question

## Quick Reference: Letter Positions

| A-E | F-J | K-O | P-T | U-Z |
|-----|-----|-----|-----|-----|
| A=1 | F=6 | K=11 | P=16 | U=21 |
| B=2 | G=7 | L=12 | Q=17 | V=22 |
| C=3 | H=8 | M=13 | R=18 | W=23 |
| D=4 | I=9 | N=14 | S=19 | X=24 |
| E=5 | J=10 | O=15 | T=20 | Y=25 |
|     |     |     |     | Z=26 |

## Opposite Letters (sum = 27)
A↔Z, B↔Y, C↔X, D↔W, E↔V, F↔U, G↔T, H↔S, I↔R, J↔Q, K↔P, L↔O, M↔N

## SSC Exam Tips
1. Always check the most common patterns first
2. Write out letter positions if needed
3. Look for patterns in the given examples
4. Practice mixed coding types
''',
    tags: ['coding decoding', 'reasoning', 'letter codes', 'ssc'],
    estimatedReadTime: 14,
    createdAt: DateTime(2024, 1, 21),
    rating: 4.8,
  ),

  StudyMaterial(
    id: 'ssc_reasoning_series',
    title: 'Series - Number & Letter',
    description: 'Complete series patterns for SSC reasoning',
    subjectId: 'reasoning',
    topicId: 'series',
    type: StudyMaterialType.notes,
    content: '''
# Series for SSC Reasoning

## Number Series Patterns

### 1. Arithmetic Progression (AP)
Constant difference between terms
- 2, 5, 8, 11, 14 (d = +3)
- 20, 17, 14, 11 (d = -3)

### 2. Geometric Progression (GP)
Constant ratio between terms
- 2, 6, 18, 54 (r = ×3)
- 81, 27, 9, 3 (r = ÷3)

### 3. Square Series
- 1, 4, 9, 16, 25 (n²)
- 4, 9, 16, 25, 36 (starting from 2²)

### 4. Cube Series
- 1, 8, 27, 64, 125 (n³)
- 8, 27, 64, 125, 216 (starting from 2³)

### 5. Fibonacci Pattern
Each term = sum of previous two
- 1, 1, 2, 3, 5, 8, 13, 21

### 6. Two-Level Difference
First find differences, then differences of differences
- 2, 5, 10, 17, 26, ?
- Differences: 3, 5, 7, 9 (AP with d=2)
- Next diff = 11, so answer = 26+11 = **37**

### 7. Alternating Series
Two patterns interleaved
- 2, 3, 4, 6, 6, 9, 8, ?
- Odd positions: 2, 4, 6, 8 (+2)
- Even positions: 3, 6, 9 (+3)
- Answer: **12** (next in even series)

### 8. Prime Number Series
- 2, 3, 5, 7, 11, 13, 17, 19, 23

### 9. Mixed Operations
- ×2+1: 1, 3, 7, 15, 31
- ×2-1: 5, 9, 17, 33, 65

## Letter Series Patterns

### 1. Simple Progression
- A, C, E, G, I (skip 1 letter)
- A, D, G, J, M (skip 2 letters)

### 2. Reverse Order
- Z, Y, X, W, V (backward)
- Z, X, V, T, R (skip 1 backward)

### 3. Grouped Pattern
- ABB, BCC, CDD, DEE (first letter +1, double second)

### 4. Position Based
- AZ, BY, CX, DW (start forward, end backward)

## Alpha-Numeric Series

### Mixed Pattern
- A1, B2, C3, D4 (letter +1, number +1)
- A2, D4, G6, J8 (letter +3, number +2)
- Z1, Y4, X9, W16 (backward letter, square numbers)

## Wrong Number in Series

### Finding the Odd One
1. Identify the pattern
2. Check each term
3. Find which breaks the rule

Example: 2, 5, 10, 17, 24, 37
- Pattern: +3, +5, +7, +9, +11
- Check: 2+3=5✓, 5+5=10✓, 10+7=17✓, 17+9=26≠24✗
- **24 is wrong**, should be 26

## SSC Exam Tips
1. Always find the difference pattern first
2. Check for alternating series
3. Look for prime, square, cube patterns
4. Write out calculations to avoid errors
''',
    tags: ['series', 'number series', 'letter series', 'reasoning', 'ssc'],
    estimatedReadTime: 16,
    createdAt: DateTime(2024, 1, 22),
    rating: 4.9,
  ),

  // ==================== ENGLISH ====================
  
  StudyMaterial(
    id: 'ssc_english_grammar_rules',
    title: 'Essential Grammar Rules',
    description: 'Important grammar rules for SSC English section',
    subjectId: 'english',
    topicId: 'grammar',
    type: StudyMaterialType.notes,
    content: '''
# Grammar Rules for SSC

## Subject-Verb Agreement

### Rule 1: Singular Subject = Singular Verb
- The boy **runs** fast.
- She **is** a doctor.

### Rule 2: Plural Subject = Plural Verb
- The boys **run** fast.
- They **are** doctors.

### Rule 3: Two Subjects with "and"
- Ram and Shyam **are** friends. (plural verb)

### Rule 4: Subjects with "or/nor"
- Neither Ram nor his friends **are** coming. (verb agrees with nearer subject)
- Neither the students nor the teacher **was** present.

### Rule 5: Collective Nouns
- The team **is** playing well. (acting as unit = singular)
- The team **are** arguing among themselves. (acting individually = plural)

### Rule 6: Each/Every/Either/Neither
Always take singular verb
- Each of the boys **has** a book.
- Every student **is** present.
- Either of them **is** correct.

### Rule 7: Uncountable Nouns
Take singular verb
- The news **is** shocking.
- Mathematics **is** interesting.
- The furniture **was** expensive.

## Tense Usage

### Simple Present
- Habitual actions: I **go** to school daily.
- Universal truths: The sun **rises** in the east.

### Present Continuous
- Ongoing action: She **is reading** a book.
- Near future: I **am leaving** tomorrow.

### Present Perfect
- Past action with present relevance: I **have finished** my work.
- Experience: She **has visited** Paris.

### Past Perfect
- Action completed before another past action
- He **had left** before I arrived.

## Common Error Types

### 1. Article Errors
- ❌ He is **a** honest man.
- ✓ He is **an** honest man. (silent 'h')

### 2. Preposition Errors
- ❌ I am angry **on** him.
- ✓ I am angry **with** him.

### 3. Pronoun Errors
- ❌ Each student should bring **their** book.
- ✓ Each student should bring **his/her** book.

## Important Word Pairs

| Correct | Incorrect |
|---------|-----------|
| between two | between three |
| among three+ | among two |
| elder/eldest (family) | older/oldest (general) |
| fewer (countable) | less (uncountable) |

## SSC Exam Tips
1. Read the sentence completely before answering
2. Identify subject-verb relationship
3. Check tense consistency
4. Look for common error patterns
''',
    tags: ['grammar', 'english', 'subject verb', 'tenses', 'ssc'],
    estimatedReadTime: 14,
    createdAt: DateTime(2024, 1, 23),
    rating: 4.8,
  ),

  StudyMaterial(
    id: 'ssc_english_vocabulary',
    title: 'Vocabulary - Synonyms & Antonyms',
    description: 'Important words with synonyms and antonyms for SSC',
    subjectId: 'english',
    topicId: 'vocabulary',
    type: StudyMaterialType.notes,
    content: '''
# Vocabulary for SSC Exams

## Frequently Asked Words

### A-E Words

| Word | Synonym | Antonym |
|------|---------|---------|
| Abandon | Forsake, Desert | Retain, Keep |
| Abate | Decrease, Diminish | Increase, Intensify |
| Acclaim | Praise, Applaud | Criticize, Condemn |
| Adversity | Hardship, Misfortune | Prosperity, Fortune |
| Affluent | Wealthy, Rich | Poor, Destitute |
| Alleviate | Reduce, Ease | Aggravate, Worsen |
| Ambiguous | Vague, Unclear | Clear, Explicit |
| Amiable | Friendly, Pleasant | Hostile, Unfriendly |
| Arduous | Difficult, Strenuous | Easy, Simple |
| Authentic | Genuine, Real | Fake, Counterfeit |
| Benevolent | Kind, Generous | Malevolent, Cruel |
| Brevity | Conciseness, Shortness | Lengthiness, Verbosity |
| Candid | Frank, Honest | Deceptive, Dishonest |
| Cautious | Careful, Wary | Careless, Reckless |
| Consolidate | Strengthen, Unite | Weaken, Divide |
| Contempt | Disdain, Scorn | Respect, Admiration |
| Diligent | Hardworking, Industrious | Lazy, Idle |
| Diminish | Decrease, Reduce | Increase, Expand |
| Eloquent | Articulate, Fluent | Inarticulate, Tongue-tied |
| Ephemeral | Short-lived, Transient | Permanent, Lasting |

### F-O Words

| Word | Synonym | Antonym |
|------|---------|---------|
| Feasible | Possible, Viable | Impossible, Impractical |
| Frugal | Economical, Thrifty | Extravagant, Wasteful |
| Gregarious | Sociable, Friendly | Unsociable, Reserved |
| Hostile | Unfriendly, Aggressive | Friendly, Amicable |
| Immense | Huge, Enormous | Tiny, Minute |
| Impeccable | Flawless, Perfect | Faulty, Imperfect |
| Inevitable | Unavoidable, Certain | Avoidable, Uncertain |
| Meticulous | Careful, Thorough | Careless, Sloppy |
| Mundane | Ordinary, Routine | Extraordinary, Unusual |
| Nocturnal | Night-active | Diurnal (day-active) |
| Obsolete | Outdated, Archaic | Modern, Current |
| Ominous | Threatening, Menacing | Favorable, Auspicious |

### P-Z Words

| Word | Synonym | Antonym |
|------|---------|---------|
| Paramount | Supreme, Chief | Minor, Insignificant |
| Persevere | Persist, Continue | Quit, Give up |
| Pragmatic | Practical, Realistic | Impractical, Idealistic |
| Profound | Deep, Intense | Shallow, Superficial |
| Prudent | Wise, Sensible | Foolish, Reckless |
| Reluctant | Hesitant, Unwilling | Eager, Willing |
| Replenish | Refill, Restore | Deplete, Empty |
| Resilient | Tough, Adaptable | Fragile, Weak |
| Subsequent | Following, Later | Previous, Prior |
| Tedious | Boring, Monotonous | Interesting, Exciting |
| Tranquil | Calm, Peaceful | Turbulent, Agitated |
| Verbose | Wordy, Long-winded | Concise, Brief |
| Wary | Cautious, Alert | Careless, Trusting |
| Zealous | Enthusiastic, Eager | Apathetic, Indifferent |

## One-Word Substitutions

| Phrase | One Word |
|--------|----------|
| One who hates mankind | Misanthrope |
| One who loves mankind | Philanthropist |
| Study of birds | Ornithology |
| Government by the people | Democracy |
| Fear of heights | Acrophobia |
| Fear of water | Hydrophobia |
| One who can use both hands | Ambidextrous |
| Murder of a king | Regicide |
| One who speaks many languages | Polyglot |
''',
    tags: ['vocabulary', 'synonyms', 'antonyms', 'one word', 'ssc'],
    estimatedReadTime: 15,
    createdAt: DateTime(2024, 1, 24),
    rating: 4.7,
  ),

  StudyMaterial(
    id: 'ssc_english_idioms',
    title: 'Idioms & Phrases',
    description: 'Important idioms and phrases for SSC exams',
    subjectId: 'english',
    topicId: 'idioms',
    type: StudyMaterialType.notes,
    content: '''
# Idioms & Phrases for SSC

## Common Idioms (A-D)

| Idiom | Meaning |
|-------|---------|
| A piece of cake | Very easy |
| Add fuel to the fire | Make situation worse |
| At the drop of a hat | Immediately |
| Back to square one | Start again |
| Beat around the bush | Avoid the main topic |
| Bite the bullet | Face difficulty bravely |
| Blessing in disguise | Good thing in bad situation |
| Break the ice | Start conversation |
| Burn the midnight oil | Work late |
| By hook or by crook | By any means |
| Call it a day | Stop working |
| Cry over spilt milk | Regret past mistakes |
| Cut corners | Do cheaply or badly |
| Down to earth | Practical, humble |

## Common Idioms (E-L)

| Idiom | Meaning |
|-------|---------|
| Every cloud has a silver lining | Hope in difficult times |
| Face the music | Accept consequences |
| Get out of hand | Lose control |
| Give the cold shoulder | Ignore someone |
| Hit the nail on the head | Be exactly right |
| In hot water | In trouble |
| Jump on the bandwagon | Follow the trend |
| Keep your chin up | Stay positive |
| Kill two birds with one stone | Accomplish two things at once |
| Last straw | Final problem causing action |
| Let the cat out of the bag | Reveal a secret |
| Look before you leap | Think before acting |

## Common Idioms (M-Z)

| Idiom | Meaning |
|-------|---------|
| Make a mountain out of a molehill | Exaggerate a problem |
| Miss the boat | Miss an opportunity |
| Nip in the bud | Stop at early stage |
| Once in a blue moon | Very rarely |
| Out of the blue | Unexpectedly |
| Over the moon | Extremely happy |
| Pull someone's leg | Joke with someone |
| Put all eggs in one basket | Risk everything on one thing |
| Rain cats and dogs | Rain heavily |
| See eye to eye | Agree completely |
| Speak of the devil | Person appears when mentioned |
| Take with a grain of salt | Don't believe completely |
| The ball is in your court | Your turn to act |
| Through thick and thin | In good and bad times |
| Under the weather | Feeling ill |
| When pigs fly | Never (impossible) |
| Wolf in sheep's clothing | Dangerous person appearing harmless |

## Phrases Often Asked in SSC

| Phrase | Meaning |
|--------|---------|
| At arm's length | Keep distance |
| At daggers drawn | Hostile relationship |
| At one's wit's end | Completely confused |
| By leaps and bounds | Rapidly |
| In a nutshell | Briefly |
| In the nick of time | Just in time |
| On cloud nine | Very happy |
| On the spur of the moment | Spontaneously |
| Out of the woods | Out of danger |
| To make ends meet | Manage with limited money |
| To turn over a new leaf | Start fresh |
| With flying colors | With great success |

## SSC Exam Tips
1. Learn idioms in context, not just meaning
2. Focus on commonly asked phrases
3. Practice using idioms in sentences
4. Understand literal vs figurative meaning
''',
    tags: ['idioms', 'phrases', 'english', 'expressions', 'ssc'],
    estimatedReadTime: 12,
    createdAt: DateTime(2024, 1, 25),
    rating: 4.8,
  ),

  // ==================== GENERAL AWARENESS ====================
  
  StudyMaterial(
    id: 'ssc_gk_polity',
    title: 'Indian Polity - Key Concepts',
    description: 'Constitutional provisions and polity for SSC GK',
    subjectId: 'general_awareness',
    topicId: 'indian_polity',
    type: StudyMaterialType.notes,
    content: '''
# Indian Polity for SSC Exams

## Constitution Basics

### Key Facts
- Adopted: **26 November 1949**
- Came into force: **26 January 1950**
- Original articles: **395** (in 22 Parts, 8 Schedules)
- Current articles: **470+** (in 25 Parts, 12 Schedules)
- Longest written constitution in the world

### Sources of Constitution
| Feature | Source |
|---------|--------|
| Parliamentary system | Britain |
| Fundamental Rights | USA |
| DPSP | Ireland |
| Federal structure | Canada |
| Emergency provisions | Germany |
| Concurrent list | Australia |
| Amendment procedure | South Africa |

## Preamble

### Key Terms
- **Sovereign**: Independent authority
- **Socialist**: Social & economic equality
- **Secular**: No state religion
- **Democratic**: Government by people
- **Republic**: Elected head of state

### Added by 42nd Amendment (1976)
- Socialist
- Secular
- Integrity

## Fundamental Rights (Part III)

### Article 14-18: Right to Equality
- Art 14: Equality before law
- Art 15: No discrimination
- Art 16: Equal opportunity in public employment
- Art 17: Abolition of untouchability
- Art 18: Abolition of titles

### Article 19-22: Right to Freedom
- Art 19: Six freedoms (speech, assembly, association, movement, residence, profession)
- Art 20: Protection in respect of conviction
- Art 21: Right to life and liberty
- Art 21A: Right to education (6-14 years)
- Art 22: Protection against arrest and detention

### Article 23-24: Against Exploitation
- Art 23: Prohibition of trafficking
- Art 24: Prohibition of child labor (below 14)

### Article 25-28: Freedom of Religion
### Article 29-30: Cultural & Educational Rights
### Article 32: Right to Constitutional Remedies

## Parliament

### Lok Sabha
- Maximum strength: **552** (530 states + 20 UTs + 2 Anglo-Indian)
- Term: **5 years**
- Quorum: **1/10th**
- Minimum age: **25 years**
- Speaker: Presiding officer

### Rajya Sabha
- Maximum strength: **250** (238 elected + 12 nominated)
- Term: **6 years** (1/3 retire every 2 years)
- Minimum age: **30 years**
- Chairman: Vice President

## Important Articles

| Article | Subject |
|---------|---------|
| 1 | Name and territory |
| 3 | Formation of new states |
| 14 | Equality before law |
| 17 | Abolition of untouchability |
| 21 | Right to life |
| 32 | Constitutional remedies |
| 44 | Uniform Civil Code |
| 51A | Fundamental Duties |
| 72 | Pardoning power of President |
| 352 | National Emergency |
| 356 | President's Rule |

## SSC Exam Tips
1. Remember important articles and amendments
2. Focus on Fundamental Rights
3. Know Parliament structure and powers
4. Understand Centre-State relations
''',
    tags: ['polity', 'constitution', 'fundamental rights', 'parliament', 'ssc'],
    estimatedReadTime: 16,
    createdAt: DateTime(2024, 1, 26),
    rating: 4.9,
  ),

  StudyMaterial(
    id: 'ssc_gk_geography',
    title: 'Geography - India & World',
    description: 'Important geography concepts for SSC exams',
    subjectId: 'general_awareness',
    topicId: 'geography',
    type: StudyMaterialType.notes,
    content: '''
# Geography for SSC Exams

## India: Physical Features

### Location
- Latitude: 8°4'N to 37°6'N
- Longitude: 68°7'E to 97°25'E
- Standard Meridian: **82°30'E** (passing through Mirzapur, UP)
- Total area: **32,87,263 sq km** (7th largest)
- Land boundary: **15,200 km**
- Coastline: **7,516 km**

### Major Mountain Ranges
| Range | Highest Peak |
|-------|--------------|
| Himalayas | K2 (in POK, 8611m) |
| Karakoram | K2 (Godwin Austin) |
| Aravalli | Guru Shikhar (1722m) |
| Vindhyas | — |
| Satpura | Dhupgarh (1350m) |
| Western Ghats | Anamudi (2695m) |
| Eastern Ghats | Mahendragiri (1501m) |

### Major Rivers
| River | Origin | Drains Into |
|-------|--------|-------------|
| Ganga | Gangotri | Bay of Bengal |
| Yamuna | Yamunotri | Ganga (at Prayagraj) |
| Brahmaputra | Mansarovar | Bay of Bengal |
| Godavari | Trimbakeshwar | Bay of Bengal |
| Krishna | Mahabaleshwar | Bay of Bengal |
| Narmada | Amarkantak | Arabian Sea |
| Tapti | Satpura | Arabian Sea |
| Indus | Mansarovar | Arabian Sea |

## States & Capitals

### Largest States (Area)
1. Rajasthan (342,239 sq km)
2. Madhya Pradesh (308,252 sq km)
3. Maharashtra (307,713 sq km)

### Largest States (Population)
1. Uttar Pradesh
2. Maharashtra
3. Bihar

### Important Facts
- Highest literacy: **Kerala**
- Lowest literacy: **Bihar**
- Maximum forest cover: **Madhya Pradesh**
- Maximum coastline: **Gujarat**

## World Geography

### Continents (by size)
1. Asia
2. Africa
3. North America
4. South America
5. Antarctica
6. Europe
7. Australia

### Oceans (by size)
1. Pacific Ocean
2. Atlantic Ocean
3. Indian Ocean
4. Southern Ocean
5. Arctic Ocean

### Important Lines
| Line | Latitude |
|------|----------|
| Equator | 0° |
| Tropic of Cancer | 23.5°N |
| Tropic of Capricorn | 23.5°S |
| Arctic Circle | 66.5°N |
| Antarctic Circle | 66.5°S |

## Climate

### Monsoons
- **Southwest Monsoon** (June-September): Major rainfall
- **Northeast Monsoon** (October-December): Tamil Nadu rainfall

### Climate Types in India
- Tropical Monsoon (most of India)
- Tropical Wet (Western Ghats, NE India)
- Semi-arid (Rajasthan, Gujarat)
- Alpine (Himalayas)

## SSC Exam Tips
1. Know Indian states, capitals, and boundaries
2. Memorize important rivers and their origins
3. Understand monsoon patterns
4. Learn world geography basics
''',
    tags: ['geography', 'india', 'rivers', 'mountains', 'ssc'],
    estimatedReadTime: 15,
    createdAt: DateTime(2024, 1, 27),
    rating: 4.8,
  ),

  StudyMaterial(
    id: 'ssc_gk_history',
    title: 'History - Quick Revision',
    description: 'Important history events and facts for SSC',
    subjectId: 'general_awareness',
    topicId: 'history',
    type: StudyMaterialType.notes,
    content: '''
# History for SSC Exams

## Ancient India

### Indus Valley Civilization (2500-1500 BCE)
- Also called **Harappan Civilization**
- Major sites: Harappa, Mohenjo-daro, Lothal, Dholavira
- Features: Urban planning, drainage system, standardized weights
- Declined around 1500 BCE

### Vedic Period
- **Rigveda**: Oldest Veda
- **4 Vedas**: Rig, Sama, Yajur, Atharva
- **Upanishads**: Philosophical texts

### Important Dynasties
| Dynasty | Founder | Capital |
|---------|---------|---------|
| Maurya | Chandragupta | Pataliputra |
| Gupta | Sri Gupta | Pataliputra |
| Pallava | Simhavishnu | Kanchi |
| Chola | Vijayalaya | Tanjore |

### Ashoka (268-232 BCE)
- Greatest Mauryan emperor
- Kalinga War (261 BCE) → embraced Buddhism
- Edicts spread Buddhism
- Symbol: Four Lions (National Emblem)

## Medieval India

### Delhi Sultanate (1206-1526)
| Dynasty | Founder |
|---------|---------|
| Slave | Qutub-ud-din Aibak |
| Khilji | Jalal-ud-din Khilji |
| Tughlaq | Ghiyas-ud-din Tughlaq |
| Sayyid | Khizr Khan |
| Lodi | Bahlol Lodi |

### Mughal Empire (1526-1857)
| Emperor | Period | Achievement |
|---------|--------|-------------|
| Babur | 1526-1530 | Founded Mughal Empire, Battle of Panipat |
| Humayun | 1530-1556 | Lost & regained throne |
| Akbar | 1556-1605 | Din-i-Ilahi, Mansabdari, Abolition of Jizya |
| Jahangir | 1605-1627 | Chain of Justice |
| Shah Jahan | 1627-1658 | Taj Mahal, Red Fort |
| Aurangzeb | 1658-1707 | Largest Mughal territory |

## Modern India

### Important Events
| Year | Event |
|------|-------|
| 1757 | Battle of Plassey |
| 1764 | Battle of Buxar |
| 1857 | First War of Independence |
| 1885 | Indian National Congress founded |
| 1905 | Partition of Bengal |
| 1919 | Jallianwala Bagh Massacre |
| 1920 | Non-Cooperation Movement |
| 1930 | Salt March (Dandi March) |
| 1942 | Quit India Movement |
| 1947 | Independence |

### Important Freedom Fighters
| Person | Contribution |
|--------|--------------|
| Mahatma Gandhi | Non-violence, Salt March |
| Jawaharlal Nehru | First PM, Modernization |
| Subhash Chandra Bose | INA, Azad Hind |
| Bhagat Singh | Revolutionary |
| Sardar Patel | Integration of states |
| B.R. Ambedkar | Constitution, Social reform |

### Governor Generals & Viceroys
| Person | Achievement |
|--------|-------------|
| Warren Hastings | First GG, Regulating Act |
| Lord Wellesley | Subsidiary Alliance |
| Lord Dalhousie | Doctrine of Lapse, Railways |
| Lord Curzon | Partition of Bengal |
| Lord Mountbatten | Last Viceroy |

## SSC Exam Tips
1. Focus on chronology of events
2. Remember founders and capitals of dynasties
3. Know important reforms and acts
4. Understand freedom movement timeline
''',
    tags: ['history', 'ancient', 'medieval', 'modern', 'ssc'],
    estimatedReadTime: 16,
    createdAt: DateTime(2024, 1, 28),
    rating: 4.9,
  ),

  StudyMaterial(
    id: 'ssc_gk_science',
    title: 'General Science - Quick Facts',
    description: 'Important science concepts for SSC GK section',
    subjectId: 'general_awareness',
    topicId: 'science',
    type: StudyMaterialType.notes,
    content: '''
# General Science for SSC

## Physics Concepts

### Units & Measurements
| Quantity | SI Unit |
|----------|---------|
| Length | Metre (m) |
| Mass | Kilogram (kg) |
| Time | Second (s) |
| Electric Current | Ampere (A) |
| Temperature | Kelvin (K) |
| Amount of substance | Mole (mol) |
| Luminous intensity | Candela (cd) |

### Laws of Motion (Newton)
1. **First Law**: Object at rest stays at rest (Inertia)
2. **Second Law**: F = ma
3. **Third Law**: Action = Reaction

### Important Physics Facts
- Speed of light: **3 × 10⁸ m/s**
- Speed of sound (air): **343 m/s**
- Acceleration due to gravity: **9.8 m/s²**
- Normal human hearing: **20 Hz to 20,000 Hz**

### Types of Energy
- Kinetic, Potential, Thermal, Chemical, Electrical, Nuclear, Solar

## Chemistry Concepts

### Periodic Table
- Total elements: **118**
- Groups: **18** (vertical)
- Periods: **7** (horizontal)
- Noble gases: Group 18

### Important Elements
| Element | Symbol | Use |
|---------|--------|-----|
| Hydrogen | H | Fuel, Balloons |
| Oxygen | O | Respiration |
| Carbon | C | Organic chemistry |
| Iron | Fe | Construction |
| Gold | Au | Jewelry |
| Silver | Ag | Electronics |

### Acids, Bases & Salts
- **Acids**: pH < 7, sour taste
- **Bases**: pH > 7, bitter taste
- **Neutral**: pH = 7

### Common Chemicals
| Name | Formula | Use |
|------|---------|-----|
| Water | H₂O | Universal solvent |
| Salt | NaCl | Cooking |
| Baking soda | NaHCO₃ | Cooking, cleaning |
| Bleaching powder | CaOCl₂ | Disinfection |

## Biology Concepts

### Human Body Systems
| System | Function |
|--------|----------|
| Digestive | Food breakdown |
| Respiratory | Gas exchange |
| Circulatory | Blood transport |
| Nervous | Control & coordination |
| Skeletal | Support & protection |
| Muscular | Movement |

### Important Facts
- Total bones: **206**
- Total muscles: **600+**
- Blood groups: **A, B, AB, O**
- Universal donor: **O negative**
- Universal recipient: **AB positive**
- Normal body temperature: **37°C (98.6°F)**
- Normal heart rate: **72 beats/min**
- Normal BP: **120/80 mmHg**

### Diseases & Causes
| Disease | Cause |
|---------|-------|
| Malaria | Plasmodium (mosquito) |
| Typhoid | Salmonella bacteria |
| Tuberculosis | Mycobacterium |
| COVID-19 | SARS-CoV-2 virus |
| Diabetes | Insulin deficiency |
| Anemia | Iron deficiency |

### Vitamins
| Vitamin | Source | Deficiency Disease |
|---------|--------|-------------------|
| A | Carrots, liver | Night blindness |
| B1 | Cereals | Beriberi |
| C | Citrus fruits | Scurvy |
| D | Sunlight, fish | Rickets |
| E | Nuts, oils | Infertility |
| K | Green vegetables | Bleeding |

## SSC Exam Tips
1. Focus on SI units and their conversions
2. Remember common diseases and their causes
3. Know important chemical formulas
4. Understand basic physics laws
''',
    tags: ['science', 'physics', 'chemistry', 'biology', 'ssc'],
    estimatedReadTime: 15,
    createdAt: DateTime(2024, 1, 29),
    rating: 4.8,
  ),

  StudyMaterial(
    id: 'ssc_gk_economics',
    title: 'Economics - Basic Concepts',
    description: 'Economic concepts and terms for SSC GK',
    subjectId: 'general_awareness',
    topicId: 'economics',
    type: StudyMaterialType.notes,
    content: '''
# Economics for SSC Exams

## Basic Economic Terms

### GDP & GNP
- **GDP**: Gross Domestic Product - Total value of goods/services produced within country
- **GNP**: Gross National Product - GDP + income from abroad

### Types of Economies
- **Capitalist**: Private ownership (USA)
- **Socialist**: State ownership (Cuba)
- **Mixed**: Both private & public (India)

### Inflation Types
| Type | Rate |
|------|------|
| Creeping | 0-3% |
| Walking | 3-7% |
| Running | 7-10% |
| Hyperinflation | >50% |

### Important Indices
- **WPI**: Wholesale Price Index
- **CPI**: Consumer Price Index (measures retail inflation)
- **HDI**: Human Development Index (UNDP)

## Indian Economy

### Five Year Plans
| Plan | Period | Focus |
|------|--------|-------|
| 1st | 1951-56 | Agriculture |
| 2nd | 1956-61 | Heavy industries |
| 3rd | 1961-66 | Self-reliance |
| 12th | 2012-17 | Faster, sustainable growth |

**NITI Aayog** replaced Planning Commission in 2015

### Economic Reforms 1991
- **LPG**: Liberalization, Privatization, Globalization
- Finance Minister: **Manmohan Singh**
- PM: **P.V. Narasimha Rao**

### Tax Structure
| Direct Tax | Indirect Tax |
|------------|--------------|
| Income Tax | GST |
| Corporate Tax | Customs Duty |
| Wealth Tax | Excise Duty |

### GST (2017)
- **Tax Slabs**: 0%, 5%, 12%, 18%, 28%
- Replaced multiple indirect taxes
- One Nation, One Tax

## Banking & Finance

### RBI (Reserve Bank of India)
- Established: **1935** (Act of 1934)
- Nationalized: **1949**
- Governor: Apex authority
- Functions: Currency issue, Banker's bank, Monetary policy

### Monetary Policy Tools
- **Repo Rate**: Rate at which RBI lends to banks
- **Reverse Repo**: Rate at which banks deposit with RBI
- **CRR**: Cash Reserve Ratio
- **SLR**: Statutory Liquidity Ratio
- **Bank Rate**: Long-term lending rate

### Types of Banks
| Type | Example |
|------|---------|
| Public Sector | SBI, PNB |
| Private | HDFC, ICICI |
| Payment | Paytm, Jio |
| Small Finance | AU Small Finance |
| Regional Rural | Gramin Banks |

### Important Schemes
| Scheme | Purpose |
|--------|---------|
| PM Jan Dhan Yojana | Financial inclusion |
| Mudra Yojana | Small business loans |
| Atal Pension Yojana | Pension for unorganized sector |
| PM Fasal Bima | Crop insurance |
| Make in India | Manufacturing |
| Digital India | E-governance |

## SSC Exam Tips
1. Know current RBI rates
2. Remember important economic schemes
3. Understand GST structure
4. Focus on recent economic developments
''',
    tags: ['economics', 'gdp', 'banking', 'rbi', 'gst', 'ssc'],
    estimatedReadTime: 14,
    createdAt: DateTime(2024, 1, 30),
    rating: 4.7,
  ),
];
