import '../../../exam_prep/models/study_material_model.dart';

/// Comprehensive study materials for CAT (Common Admission Test)
final List<StudyMaterial> catStudyMaterials = [
  // ==================== QUANTITATIVE APTITUDE ====================
  
  StudyMaterial(
    id: 'cat_quant_number_system',
    title: 'Number System - Advanced Concepts',
    description: 'Divisibility, remainders, factors for CAT',
    subjectId: 'quantitative_aptitude',
    topicId: 'number_system',
    type: StudyMaterialType.notes,
    content: '''
# Number System for CAT

## Types of Numbers

### Natural Numbers (N)
1, 2, 3, 4, ... (counting numbers)

### Whole Numbers (W)
0, 1, 2, 3, ... (N ∪ {0})

### Integers (Z)
..., -2, -1, 0, 1, 2, ... (positive, negative, zero)

### Rational Numbers (Q)
p/q where p, q ∈ Z, q ≠ 0

### Irrational Numbers
Cannot be expressed as p/q (√2, π, e)

## Divisibility Rules

| Divisor | Rule |
|---------|------|
| 2 | Last digit even |
| 3 | Sum of digits divisible by 3 |
| 4 | Last 2 digits divisible by 4 |
| 5 | Last digit 0 or 5 |
| 6 | Divisible by both 2 and 3 |
| 7 | Double last digit, subtract from rest |
| 8 | Last 3 digits divisible by 8 |
| 9 | Sum of digits divisible by 9 |
| 11 | Alternating sum of digits divisible by 11 |

## Factors & Multiples

### Number of Factors
If N = p₁^a × p₂^b × p₃^c...
**Number of factors = (a+1)(b+1)(c+1)...**

### Sum of Factors
σ(N) = [(p₁^(a+1) - 1)/(p₁ - 1)] × [(p₂^(b+1) - 1)/(p₂ - 1)]...

### Product of Factors
Product = N^(number of factors / 2)

## Remainder Theorem

### Basic Properties
- (a + b) mod n = [(a mod n) + (b mod n)] mod n
- (a × b) mod n = [(a mod n) × (b mod n)] mod n
- (a - b) mod n = [(a mod n) - (b mod n) + n] mod n

### Fermat's Little Theorem
If p is prime and gcd(a, p) = 1:
**a^(p-1) ≡ 1 (mod p)**

### Euler's Theorem
If gcd(a, n) = 1:
**a^φ(n) ≡ 1 (mod n)**

### Euler's Totient Function
φ(n) = n × (1 - 1/p₁) × (1 - 1/p₂)...
where p₁, p₂... are prime factors of n

## HCF & LCM

### Properties
- HCF × LCM = Product of two numbers
- HCF of fractions = HCF of numerators / LCM of denominators
- LCM of fractions = LCM of numerators / HCF of denominators

### Finding HCF
**Euclidean Algorithm**
HCF(a, b) = HCF(b, a mod b) until remainder = 0

## CAT Shortcuts

### Last Digit Cyclicity
| Digit | Cycle length |
|-------|--------------|
| 0, 1, 5, 6 | 1 |
| 4, 9 | 2 |
| 2, 3, 7, 8 | 4 |

### Successive Division
When N is divided by a, b, c successively with remainders r₁, r₂, r₃:
N = a(bq + r₂) + r₁ = ab(cq + r₃) + ar₂ + r₁
''',
    tags: ['number system', 'divisibility', 'factors', 'remainder', 'cat'],
    estimatedReadTime: 14,
    createdAt: DateTime(2024, 1, 15),
    rating: 4.9,
  ),

  StudyMaterial(
    id: 'cat_quant_algebra',
    title: 'Algebra - Equations & Inequalities',
    description: 'Quadratic equations, progressions, functions',
    subjectId: 'quantitative_aptitude',
    topicId: 'algebra',
    type: StudyMaterialType.notes,
    content: '''
# Algebra for CAT

## Quadratic Equations

### Standard Form
ax² + bx + c = 0

### Roots Formula
x = (-b ± √(b² - 4ac)) / 2a

### Sum & Product of Roots
- Sum: α + β = -b/a
- Product: αβ = c/a

### Nature of Roots (Discriminant D = b² - 4ac)
| D | Nature |
|---|--------|
| D > 0 | Two distinct real roots |
| D = 0 | Two equal real roots |
| D < 0 | Two complex conjugate roots |

### Common Identities
- (a + b)² = a² + 2ab + b²
- (a - b)² = a² - 2ab + b²
- a² - b² = (a + b)(a - b)
- (a + b)³ = a³ + 3a²b + 3ab² + b³
- a³ + b³ = (a + b)(a² - ab + b²)
- a³ - b³ = (a - b)(a² + ab + b²)

## Arithmetic Progression (AP)

### nth Term
aₙ = a + (n-1)d

### Sum of n Terms
Sₙ = n/2 [2a + (n-1)d] = n/2 (first + last)

### Properties
- Middle term = (first + last) / 2
- Sum of equidistant terms from ends is constant

## Geometric Progression (GP)

### nth Term
aₙ = ar^(n-1)

### Sum of n Terms
Sₙ = a(r^n - 1)/(r - 1) for r ≠ 1

### Sum to Infinity (|r| < 1)
S∞ = a/(1 - r)

### Properties
- Product of equidistant terms = Product of extremes

## Harmonic Progression (HP)

If a, b, c are in HP, then 1/a, 1/b, 1/c are in AP.

### Harmonic Mean
HM of a and b = 2ab/(a + b)

### AM-GM-HM Relationship
AM ≥ GM ≥ HM
Equality holds when all numbers are equal.

## Inequalities

### Properties
- If a > b, then a + c > b + c
- If a > b and c > 0, then ac > bc
- If a > b and c < 0, then ac < bc

### Modulus Inequalities
- |x| < a ⟹ -a < x < a
- |x| > a ⟹ x < -a or x > a

### Triangle Inequality
|a| - |b| ≤ |a ± b| ≤ |a| + |b|

## Functions

### Types
- **One-to-one (Injective)**: Different inputs → Different outputs
- **Onto (Surjective)**: Range = Codomain
- **Bijective**: Both one-to-one and onto

### Composition
(f ∘ g)(x) = f(g(x))

### Inverse Function
If y = f(x), then x = f⁻¹(y)
f(f⁻¹(x)) = x
''',
    tags: ['algebra', 'quadratic', 'progressions', 'ap gp', 'cat'],
    estimatedReadTime: 15,
    createdAt: DateTime(2024, 1, 16),
    rating: 4.8,
  ),

  StudyMaterial(
    id: 'cat_quant_geometry',
    title: 'Geometry & Mensuration',
    description: 'Triangles, circles, solid geometry for CAT',
    subjectId: 'quantitative_aptitude',
    topicId: 'geometry',
    type: StudyMaterialType.formula,
    content: '''
# Geometry & Mensuration for CAT

## Triangles

### Area Formulas
- **Base-Height**: A = ½ × base × height
- **Heron's**: A = √[s(s-a)(s-b)(s-c)] where s = (a+b+c)/2
- **Using sides**: A = ½ab sinC

### Important Properties
- Sum of angles = 180°
- Sum of any two sides > Third side
- Exterior angle = Sum of non-adjacent interior angles

### Special Triangles
| Triangle | Sides | Angles |
|----------|-------|--------|
| Equilateral | a = b = c | 60° each |
| Isosceles | Two equal | Two equal |
| 30-60-90 | 1 : √3 : 2 | 30°, 60°, 90° |
| 45-45-90 | 1 : 1 : √2 | 45°, 45°, 90° |

### Centers of Triangle
| Center | Property | Divides median in |
|--------|----------|-------------------|
| Centroid (G) | Medians meet | 2:1 from vertex |
| Incenter (I) | Angle bisectors meet | - |
| Circumcenter (O) | Perpendicular bisectors meet | - |
| Orthocenter (H) | Altitudes meet | - |

### Similarity Rules
- AAA, AA, SAS, SSS (ratios equal)
- Ratio of areas = (Ratio of sides)²

## Circles

### Basic Formulas
- **Circumference**: C = 2πr = πd
- **Area**: A = πr²
- **Arc length**: l = rθ (θ in radians)
- **Sector area**: A = ½r²θ = ½lr

### Important Theorems
- Angle in semicircle = 90°
- Angle at center = 2 × Angle at circumference
- Equal chords are equidistant from center
- Tangent ⊥ Radius at point of contact

### Tangent Properties
- Length from external point: √(d² - r²) where d = distance from center
- Two tangents from external point are equal

## Quadrilaterals

| Shape | Area | Perimeter |
|-------|------|-----------|
| Square (side a) | a² | 4a |
| Rectangle (l, b) | lb | 2(l+b) |
| Parallelogram | base × height | 2(a+b) |
| Rhombus | ½ × d₁ × d₂ | 4a |
| Trapezium | ½(a+b) × h | Sum of sides |

## 3D Mensuration

### Cube (side a)
- Volume: a³
- Surface Area: 6a²
- Diagonal: a√3

### Cuboid (l, b, h)
- Volume: lbh
- Surface Area: 2(lb + bh + lh)
- Diagonal: √(l² + b² + h²)

### Cylinder (r, h)
- Volume: πr²h
- CSA: 2πrh
- TSA: 2πr(r + h)

### Cone (r, h, l)
- Volume: ⅓πr²h
- CSA: πrl where l = √(r² + h²)
- TSA: πr(r + l)

### Sphere (r)
- Volume: (4/3)πr³
- Surface Area: 4πr²

### Hemisphere
- Volume: (2/3)πr³
- CSA: 2πr²
- TSA: 3πr²
''',
    tags: ['geometry', 'mensuration', 'triangles', 'circles', 'cat'],
    estimatedReadTime: 16,
    createdAt: DateTime(2024, 1, 17),
    rating: 4.9,
  ),

  // ==================== VERBAL ABILITY & READING COMPREHENSION ====================
  
  StudyMaterial(
    id: 'cat_verbal_rc_strategy',
    title: 'Reading Comprehension - Strategies',
    description: 'RC techniques, passage types, question patterns',
    subjectId: 'verbal_ability',
    topicId: 'reading_comprehension',
    type: StudyMaterialType.notes,
    content: '''
# Reading Comprehension for CAT

## Passage Types

### By Content
1. **Abstract/Philosophical**: Ideas, theories, concepts
2. **Factual/Scientific**: Data-driven, research-based
3. **Social/Political**: Current affairs, policies
4. **Literary**: Narratives, descriptions

### By Structure
1. **Argumentative**: Author presents viewpoint with evidence
2. **Descriptive**: Explains a topic thoroughly
3. **Comparative**: Contrasts different perspectives
4. **Narrative**: Tells a story or sequence of events

## Reading Strategies

### First Reading (2-3 minutes)
1. Read the passage quickly
2. Identify the main idea/theme
3. Note the author's tone
4. Mark paragraph transitions

### Question Analysis
1. Identify question type
2. Locate relevant portion in passage
3. Eliminate obviously wrong options
4. Choose the best answer (not just correct)

## Question Types

### Main Idea Questions
- "The passage primarily discusses..."
- "The author's main argument is..."
- Look at introduction and conclusion

### Inference Questions
- "It can be inferred that..."
- "The author implies..."
- Answer should be logically derivable, not stated

### Vocabulary in Context
- "The word 'X' most nearly means..."
- Consider context, not dictionary meaning
- Substitute options to check fit

### Author's Tone/Attitude
- Positive: Appreciative, supportive, optimistic
- Negative: Critical, skeptical, pessimistic
- Neutral: Objective, analytical, informative

### Specific Detail Questions
- "According to the passage..."
- Answer is directly stated
- Locate exact reference

## Common Traps

### Extreme Answers
- Words like "always," "never," "all," "none"
- Usually incorrect unless explicitly stated

### Out of Scope
- True information not mentioned in passage
- Cannot be answer to inference questions

### Partial Information
- Only covers part of what's asked
- Misses key aspects

### Opposite Meaning
- Contradicts passage information
- Often tempting due to familiar concepts

## Time Management

### Allocation
- 5 passages × 10-12 minutes each
- Read: 3-4 minutes
- Questions: 6-8 minutes

### Prioritization
1. Attempt easier passages first
2. Skip very difficult passages initially
3. Return to skipped questions if time permits

## Tips for CAT RC

1. **Read actively**: Engage with the material
2. **Don't memorize**: Focus on understanding structure
3. **Practice variety**: Different topics and styles
4. **Build vocabulary**: In context, not isolation
5. **Time yourself**: Simulate exam conditions
6. **Review mistakes**: Understand why wrong answers seemed right
''',
    tags: ['reading comprehension', 'rc strategy', 'verbal', 'cat'],
    estimatedReadTime: 14,
    createdAt: DateTime(2024, 1, 18),
    rating: 4.8,
  ),

  StudyMaterial(
    id: 'cat_verbal_grammar',
    title: 'Grammar & Verbal Ability',
    description: 'Sentence correction, para jumbles, verbal reasoning',
    subjectId: 'verbal_ability',
    topicId: 'grammar',
    type: StudyMaterialType.notes,
    content: '''
# Grammar & Verbal Ability for CAT

## Sentence Correction

### Common Error Types

#### Subject-Verb Agreement
- Singular subject → Singular verb
- Collective nouns: Usually singular
- "Either...or", "Neither...nor": Verb agrees with nearest subject

#### Pronoun Errors
- Clear antecedent required
- Agreement in number and gender
- Avoid ambiguous references

#### Modifier Errors
- **Dangling modifiers**: No logical subject
- **Misplaced modifiers**: Wrong placement changes meaning

#### Parallelism
- Similar ideas in similar grammatical form
- Lists should have consistent structure

#### Tense Consistency
- Maintain consistent tense unless time shift indicated
- Past perfect for "earlier past"

### Idiomatic Usage

| Correct | Incorrect |
|---------|-----------|
| Different from | Different than |
| Compare to (similarities) | Compare against |
| Compare with (detailed) | - |
| Regard as | Regard to be |
| Neither...nor | Neither...or |

## Para Jumbles (Sentence Rearrangement)

### Strategy
1. **Find the opening sentence**: General, introduces topic
2. **Identify mandatory pairs**: Pronouns, conjunctions
3. **Look for logical flow**: Chronological, cause-effect
4. **Check closing sentence**: Concludes the argument

### Linking Words

| Continuation | Contrast | Cause-Effect |
|--------------|----------|--------------|
| Moreover | However | Therefore |
| Furthermore | Nevertheless | Consequently |
| Also | On the other hand | As a result |
| In addition | Despite | Hence |

## Para Summary

### Approach
1. Read the paragraph carefully
2. Identify main idea (not examples)
3. Eliminate options with:
   - Extra information
   - Missing key points
   - Wrong emphasis

## Odd Sentence Out

### Strategy
1. Find the common theme
2. Identify the sentence that doesn't fit
3. Check if removal makes paragraph coherent

### Red Flags
- Different topic
- Contradicting information
- Different perspective

## Vocabulary Building

### Word Roots

| Root | Meaning | Examples |
|------|---------|----------|
| Bene | Good | Benevolent, benefit |
| Mal | Bad | Malevolent, malicious |
| Chron | Time | Chronological, chronic |
| Graph | Write | Biography, autograph |
| Phil | Love | Philosophy, philanthropist |

### Commonly Confused Words

| Word | Meaning |
|------|---------|
| Affect (v) | To influence |
| Effect (n) | Result |
| Principal (n) | Head; (adj) Main |
| Principle (n) | Rule, belief |
| Complement | Complete |
| Compliment | Praise |

## Critical Reasoning

### Argument Structure
- **Premise**: Supporting facts/evidence
- **Conclusion**: Main claim
- **Assumption**: Unstated but necessary

### Question Types
1. **Strengthen**: Which supports the argument?
2. **Weaken**: Which undermines the argument?
3. **Assumption**: What must be true?
4. **Inference**: What can be concluded?
''',
    tags: ['grammar', 'verbal ability', 'sentence correction', 'para jumble', 'cat'],
    estimatedReadTime: 16,
    createdAt: DateTime(2024, 1, 19),
    rating: 4.7,
  ),

  // ==================== DATA INTERPRETATION & LOGICAL REASONING ====================
  
  StudyMaterial(
    id: 'cat_dilr_data_interpretation',
    title: 'Data Interpretation - Complete Guide',
    description: 'Tables, graphs, charts analysis for CAT',
    subjectId: 'data_interpretation',
    topicId: 'di_basics',
    type: StudyMaterialType.notes,
    content: '''
# Data Interpretation for CAT

## Types of Data Representation

### Tables
- Most straightforward
- Direct data extraction
- Watch for row/column totals

### Bar Graphs
- Discrete data comparison
- Can be vertical or horizontal
- Stacked bars show composition

### Line Graphs
- Shows trends over time
- Multiple lines for comparison
- Slope indicates rate of change

### Pie Charts
- Shows proportion/percentage
- Total = 100% or 360°
- Compare relative sizes

### Combination Charts
- Mix of different types
- Requires careful interpretation

## Calculation Techniques

### Percentage Calculations

**Basic Formula**
Percentage = (Part/Whole) × 100

**Percentage Change**
% Change = [(New - Old)/Old] × 100

**Successive Percentage Change**
If changes are a% and b%:
Net change = a + b + (ab/100)%

### Ratio Analysis

**Comparison**
- Express in same units
- Reduce to lowest terms

**Compound Ratios**
a:b and c:d → ac:bd

### Average & Weighted Average

**Simple Average**
Mean = Sum of values / Number of values

**Weighted Average**
= (w₁x₁ + w₂x₂ + ...)/(w₁ + w₂ + ...)

### Growth Rate

**CAGR (Compound Annual Growth Rate)**
CAGR = [(Final/Initial)^(1/n) - 1] × 100

## Speed Calculation Tips

### Approximation
- Round to nearest convenient number
- Use fractions instead of decimals
- 1/3 ≈ 33%, 1/6 ≈ 17%, 1/8 ≈ 12.5%

### Quick Percentages
| Percentage | Calculation |
|------------|-------------|
| 10% | Divide by 10 |
| 5% | Half of 10% |
| 25% | Divide by 4 |
| 50% | Divide by 2 |
| 1% | Divide by 100 |

### Base Method
Calculate everything relative to base value.

## Common Question Types

### Direct Value Questions
- "What is the sales in Year X?"
- Straightforward data reading

### Comparison Questions
- "Which year had highest growth?"
- Compare across categories/time

### Calculation Questions
- "What is the average of...?"
- Requires arithmetic operations

### Inference Questions
- "Which of the following must be true?"
- Logical deduction from data

## CAT DI Strategy

### Set Selection
1. Scan all sets quickly (1-2 min)
2. Identify easier sets (familiar patterns)
3. Attempt 2-3 sets thoroughly

### Time Management
- 8-10 minutes per set
- Don't spend too long on one question
- Mark and move strategy

### Accuracy Focus
- Verify calculations
- Re-read question before answering
- Watch for unit conversions
''',
    tags: ['data interpretation', 'di', 'graphs', 'charts', 'cat'],
    estimatedReadTime: 15,
    createdAt: DateTime(2024, 1, 20),
    rating: 4.8,
  ),

  StudyMaterial(
    id: 'cat_dilr_logical_reasoning',
    title: 'Logical Reasoning - Techniques',
    description: 'Arrangements, puzzles, deductions for CAT',
    subjectId: 'logical_reasoning',
    topicId: 'lr_basics',
    type: StudyMaterialType.notes,
    content: '''
# Logical Reasoning for CAT

## Arrangement Problems

### Linear Arrangement
- People/objects in a row
- One-sided or two-sided seating
- Use notation: _ _ _ _ _

**Approach:**
1. Fix definite positions first
2. Apply relative constraints
3. Eliminate impossibilities

### Circular Arrangement
- No fixed starting point
- Fix one person, arrange others relatively
- Clockwise/counter-clockwise matters

### Matrix/Grid Arrangement
- 2D arrangement (rows × columns)
- Multiple parameters
- Create matrix and fill systematically

## Logical Puzzles

### Blood Relations
- Father, mother, son, daughter, etc.
- Draw family tree
- Gender identification crucial

**Key Terms:**
| Term | Meaning |
|------|---------|
| Siblings | Brothers/Sisters |
| Cousins | Children of parents' siblings |
| Paternal | Father's side |
| Maternal | Mother's side |

### Coding-Decoding
- Letter/number substitution
- Pattern recognition
- Apply same logic consistently

### Direction Sense
- North, South, East, West
- Draw diagram
- Account for turns and distances

## Logical Deductions

### Syllogisms
**Format**: All A are B. All B are C. ∴ All A are C.

**Rules:**
1. Two negatives give no conclusion
2. Two particulars give no conclusion
3. If one premise is particular, conclusion is particular
4. If one premise is negative, conclusion is negative

### Venn Diagrams
- Represent sets graphically
- Useful for "some," "all," "none" statements
- Check all possibilities

### Binary Logic
- True/False, Yes/No conditions
- Process of elimination
- Construct possibility tables

## Games and Tournaments

### Knockout Tournament
- Losers eliminated
- Total matches = n - 1 (for n teams)
- Each round halves participants

### Round Robin
- Everyone plays everyone
- Total matches = n(n-1)/2
- Points table analysis

### League Formats
- Multiple rounds possible
- Track wins, losses, draws
- Goal difference, head-to-head

## CAT LR Strategy

### Reading the Set
1. Read all conditions carefully
2. Identify constraint types
3. Note definite vs. possible conditions

### Solving Approach
1. Start with definite information
2. Build step by step
3. Test with given options if stuck

### Common Traps
- Assuming beyond given data
- Missing negative conditions
- Overlooking "not necessarily true"

### Time Allocation
- 10-12 minutes per set
- Attempt 3-4 complete sets
- Don't leave set partially done

## Newer CAT LR Patterns

### Games & Strategy
- Multi-round scenarios
- Optimal strategy finding
- Combinatorial analysis

### Route Problems
- Network/path finding
- Shortest route
- Constraints on movement

### Scheduling
- Time slot allocation
- Conflict resolution
- Multiple constraints
''',
    tags: ['logical reasoning', 'lr', 'arrangements', 'puzzles', 'cat'],
    estimatedReadTime: 16,
    createdAt: DateTime(2024, 1, 21),
    rating: 4.9,
  ),
];
