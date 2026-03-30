/// Banking Study Materials - Comprehensive notes, formulas, and shortcuts
/// Covers IBPS, SBI, RBI, LIC exams

import '../../models/study_material_model.dart';

// Import comprehensive formula and shortcut files
import 'banking/quant_formulas.dart';
import 'banking/quant_shortcuts.dart';
import 'banking/reasoning_formulas.dart';
import 'banking/reasoning_shortcuts.dart';
import 'banking/english_materials.dart';
import 'banking/banking_awareness.dart';

class BankingStudyMaterials {
  static final DateTime _now = DateTime.now();

  /// Get all banking study materials
  static List<StudyMaterial> getAll() => [
    // Original notes
    ...quantitativeAptitude,
    ...reasoningAbility,
    ...englishLanguage,
    ...generalAwareness,
    ...bankingAwareness,
    // Comprehensive formulas and shortcuts
    ...bankingQuantFormulas,
    ...bankingQuantShortcuts,
    ...bankingReasoningFormulas,
    ...bankingReasoningShortcuts,
    ...bankingEnglishMaterials,
    ...bankingAwarenessMaterials,
  ];

  /// Quantitative Aptitude Materials
  static List<StudyMaterial> get quantitativeAptitude => [
    StudyMaterial(
      id: 'bank_quant_percentage_notes',
      title: 'Percentage - Complete Concept Guide',
      description: 'Master percentage calculations with shortcuts and tricks',
      subjectId: 'quant',
      topicId: 'percentage',
      type: StudyMaterialType.notes,
      content: '''
# Percentage - Complete Guide

## What is Percentage?
Percentage means "per hundred" - a way to express a number as a fraction of 100.

## Key Formulas

### Basic Formula
- **Percentage = (Part / Whole) × 100**
- **Part = (Percentage × Whole) / 100**

### Percentage Change
- **% Increase = [(New - Old) / Old] × 100**
- **% Decrease = [(Old - New) / Old] × 100**

### Successive Percentage Changes
If a value changes by x% and then by y%:
- **Net Change = x + y + (xy/100)**

## Fraction-Percentage Equivalents (Memorize!)
| Fraction | Percentage |
|----------|------------|
| 1/2 | 50% |
| 1/3 | 33.33% |
| 1/4 | 25% |
| 1/5 | 20% |
| 1/6 | 16.67% |
| 1/8 | 12.5% |
| 1/10 | 10% |
| 1/12 | 8.33% |

## Quick Shortcuts

### Finding X% of Y
1. **10% of any number** = Move decimal one place left
2. **1% of any number** = Move decimal two places left
3. **5% = Half of 10%**
4. **25% = Quarter of the number**

### Example
Find 15% of 840:
- 10% of 840 = 84
- 5% of 840 = 42
- 15% = 84 + 42 = **126**

## Common Exam Patterns
1. Population increase/decrease problems
2. Price increase with consumption decrease
3. Successive discounts
4. Election problems (votes percentage)
5. Mixture and alligation
''',
      tags: ['percentage', 'quant', 'banking', 'basics'],
      estimatedReadTime: 15,
      createdAt: _now,
    ),
    
    StudyMaterial(
      id: 'bank_quant_profit_loss_notes',
      title: 'Profit & Loss - Complete Mastery',
      description: 'All profit loss concepts with real exam shortcuts',
      subjectId: 'quant',
      topicId: 'profit_loss',
      type: StudyMaterialType.notes,
      content: '''
# Profit & Loss - Complete Guide

## Basic Concepts
- **Cost Price (CP)**: Price at which article is bought
- **Selling Price (SP)**: Price at which article is sold
- **Marked Price (MP)**: Price displayed on article
- **Profit**: SP > CP → Profit = SP - CP
- **Loss**: CP > SP → Loss = CP - SP

## Essential Formulas

### Profit/Loss Calculation
- **Profit% = (Profit/CP) × 100**
- **Loss% = (Loss/CP) × 100**
- **SP = CP × (100 + P%) / 100** (for profit)
- **SP = CP × (100 - L%) / 100** (for loss)

### Discount Formulas
- **Discount = MP - SP**
- **Discount% = (Discount/MP) × 100**
- **SP = MP × (100 - D%) / 100**

### Important Relationships
- **When MP = CP**: Discount% = Profit%
- **CP = MP × (100 - D%) / (100 + P%)**

## Multiplying Factors (Memorize!)
| Profit% | Multiply CP by |
|---------|----------------|
| 10% | 1.10 |
| 15% | 1.15 |
| 20% | 1.20 |
| 25% | 1.25 |
| 33.33% | 4/3 |
| 50% | 1.50 |

## Exam Shortcuts

### Successive Discount
Two discounts of x% and y%:
**Effective Discount = x + y - (xy/100)**

### False Weight Profit
**Profit% = [(True Weight - False Weight) / False Weight] × 100**

### Buy X Get Y Free
**Discount% = [Y / (X + Y)] × 100**

## Sample Problem Types
1. Marked price and discount problems
2. Cost price finding from profit%
3. Successive discounts
4. Dishonest dealer problems
5. Partnership profit sharing
''',
      tags: ['profit-loss', 'quant', 'banking', 'discount'],
      estimatedReadTime: 20,
      createdAt: _now,
    ),

    StudyMaterial(
      id: 'bank_quant_si_ci_notes',
      title: 'Simple & Compound Interest - Bank Exam Special',
      description: 'Interest calculations made easy for banking exams',
      subjectId: 'quant',
      topicId: 'interest',
      type: StudyMaterialType.notes,
      content: '''
# Simple & Compound Interest

## Simple Interest (SI)

### Formula
**SI = (P × R × T) / 100**

Where:
- P = Principal (initial amount)
- R = Rate of interest (per annum)
- T = Time (in years)

### Amount Formula
**A = P + SI = P(1 + RT/100)**

### Finding P, R, or T
- **P = (SI × 100) / (R × T)**
- **R = (SI × 100) / (P × T)**
- **T = (SI × 100) / (P × R)**

## Compound Interest (CI)

### Basic Formula
**A = P(1 + R/100)^T**
**CI = A - P**

### Half-Yearly Compounding
**A = P(1 + R/200)^(2T)**

### Quarterly Compounding
**A = P(1 + R/400)^(4T)**

## CI Shortcuts (2 years)

### Difference Method
**CI - SI = P × (R/100)²** (for 2 years)

### CI for 2 Years Directly
**CI = P × R × (200 + R) / 10000**

## Quick Comparison Table
| R% | 2-Year CI Factor | 3-Year CI Factor |
|----|-----------------|-----------------|
| 5% | 1.1025 | 1.157625 |
| 10% | 1.21 | 1.331 |
| 15% | 1.3225 | 1.520875 |
| 20% | 1.44 | 1.728 |

## Banking Exam Tips
1. For SI, use unitary method for speed
2. CI questions often test 2-3 years only
3. Memorize squares: 11²=121, 12²=144, etc.
4. Difference between CI and SI is a common pattern
5. Effective rate questions appear frequently
''',
      tags: ['interest', 'si', 'ci', 'quant', 'banking'],
      estimatedReadTime: 18,
      createdAt: _now,
    ),

    StudyMaterial(
      id: 'bank_quant_time_work_notes',
      title: 'Time & Work - LCM Method Mastery',
      description: 'Solve time-work problems in seconds using LCM approach',
      subjectId: 'quant',
      topicId: 'time_work',
      type: StudyMaterialType.notes,
      content: '''
# Time & Work - Complete Guide

## Basic Concept
If A completes work in 'n' days:
- **A's 1 day work = 1/n**
- **Work rate = 1/Time**

## LCM Method (Fastest!)

### Step-by-Step
1. Find LCM of all given times
2. LCM = Total work units
3. Calculate each person's daily work
4. Add/subtract rates as needed
5. Time = Total Work / Combined Rate

### Example
A completes in 10 days, B in 15 days. Together?
- LCM(10,15) = 30 units = Total work
- A's daily work = 30/10 = 3 units
- B's daily work = 30/15 = 2 units
- Together = 3 + 2 = 5 units/day
- Time = 30/5 = **6 days**

## Important Formulas

### Two People Working Together
**Time = (A × B) / (A + B)**

### A Starts, B Joins Later
If B joins after x days:
- Work done by A in x days = x/A
- Remaining = 1 - x/A
- Time for remaining = Remaining / Combined Rate

### Alternate Day Work
In 2 days, work done = 1/A + 1/B
Repeat until complete

## Efficiency Relationships
| Efficiency Ratio | Time Ratio |
|-----------------|------------|
| 2:3 | 3:2 |
| 3:4 | 4:3 |
| 1:2 | 2:1 |

## Pipes & Cisterns
- **Inlet Pipe**: Fills tank (positive work)
- **Outlet Pipe**: Empties tank (negative work)
- Combined rate = Inlet rate - Outlet rate

## Common Patterns
1. Two people, different efficiencies
2. Work and wages problems
3. Pipes and cisterns
4. Partial work then helper joins
5. Working on alternate days
''',
      tags: ['time-work', 'quant', 'banking', 'lcm-method'],
      estimatedReadTime: 15,
      createdAt: _now,
    ),

    StudyMaterial(
      id: 'bank_quant_ratio_notes',
      title: 'Ratio, Proportion & Partnership',
      description: 'Master ratio problems for banking exams',
      subjectId: 'quant',
      topicId: 'ratio_proportion',
      type: StudyMaterialType.notes,
      content: '''
# Ratio & Proportion

## Basic Concepts

### Ratio
- Ratio a:b means a/b
- Equivalent ratios: 2:3 = 4:6 = 6:9

### Proportion
If a:b = c:d, then:
- **ad = bc** (Cross multiplication)
- **Mean Proportional of a,b = √(ab)**
- **Third Proportional of a,b = b²/a**

## Componendo & Dividendo
If a/b = c/d, then:
- **(a+b)/(a-b) = (c+d)/(c-d)**

## Mixture & Alligation

### Alligation Rule
For mixing quantities at C1 and C2 to get Cm:
**Ratio = (C2 - Cm) : (Cm - C1)**

### Replacement Formula
If x liters replaced from n liters, k times:
**Final quantity = n × (1 - x/n)^k**

## Partnership

### Simple Partnership
Profit shared in ratio of investments

### Compound Partnership
Profit shared in ratio of (Investment × Time)

**A:B = (I₁ × T₁) : (I₂ × T₂)**

## Quick Tips
1. Always reduce ratios to lowest terms
2. For division problems, multiply ratio by total
3. Age ratio problems use linear equations
4. Partnership = Investment × Time contribution
''',
      tags: ['ratio', 'proportion', 'partnership', 'quant'],
      estimatedReadTime: 12,
      createdAt: _now,
    ),
  ];

  /// Reasoning Ability Materials
  static List<StudyMaterial> get reasoningAbility => [
    StudyMaterial(
      id: 'bank_reason_seating_notes',
      title: 'Seating Arrangement - Complete Strategy',
      description: 'Master linear and circular seating arrangements',
      subjectId: 'reasoning',
      topicId: 'seating_arrangement',
      type: StudyMaterialType.notes,
      content: '''
# Seating Arrangement

## Types of Arrangements
1. **Linear** (Row-based, single/double)
2. **Circular** (Table-based)
3. **Square/Rectangular**
4. **Floor-based** (Multi-level)

## Linear Arrangement Strategy

### Step 1: Identify Direction
- Single row facing North: Left = West, Right = East
- Single row facing South: Left = East, Right = West

### Step 2: Start with Definite Info
- Place people with fixed positions first
- Use conditional clues next

### Step 3: Use Symbols
- X sits left of Y: X_Y
- Between A and B: A_X_B
- Immediate neighbor: Adjacent boxes
- Not adjacent: At least one gap

## Circular Arrangement

### Key Points
- Facing center: Left = Clockwise, Right = Anti-clockwise
- Facing outside: Opposite of above
- "Opposite" means diametrically opposite

### Tips
1. Fix one person's position first
2. Use clockwise counting consistently
3. Draw diagram with positions marked

## Common Conditions Decoded
| Condition | Meaning |
|-----------|---------|
| "Between A and B" | Can be A_X_B or B_X_A |
| "Immediate left" | Directly adjacent on left |
| "Second to the left" | One person between |
| "Not adjacent" | At least one gap |
| "At one of the ends" | First or last position |

## Practice Strategy
1. Start with 5-person puzzles
2. Progress to 7-8 persons
3. Then attempt double rows
4. Finally, combination puzzles
''',
      tags: ['seating', 'reasoning', 'banking', 'puzzles'],
      estimatedReadTime: 20,
      createdAt: _now,
    ),

    StudyMaterial(
      id: 'bank_reason_syllogism_notes',
      title: 'Syllogism - Venn Diagram Method',
      description: 'Solve syllogism using Venn diagrams quickly',
      subjectId: 'reasoning',
      topicId: 'syllogism',
      type: StudyMaterialType.notes,
      content: '''
# Syllogism

## Statement Types

### Universal Affirmative (A)
- "All A are B" → Complete overlap of A inside B
- Conversion: "Some B are A"

### Universal Negative (E)
- "No A is B" → Complete separation
- Conversion: "No B is A"

### Particular Affirmative (I)
- "Some A are B" → Partial overlap
- Conversion: "Some B are A"

### Particular Negative (O)
- "Some A are not B" → Partial exclusion
- NO valid conversion

## Venn Diagram Rules

### Drawing Steps
1. Read all statements
2. Draw circles for each term
3. Apply universal statements first
4. Then particular statements
5. Check if conclusion follows

### Possibilities
Always consider ALL possible diagrams:
- Overlapping
- Touching
- Inside
- Separate

## Quick Rules

### Valid Conclusions
| Premises | Valid Conclusion |
|----------|-----------------|
| All A=B, All B=C | All A=C |
| All A=B, Some B=C | Some A=C (possible) |
| Some A=B, All B=C | Some A=C |
| No A=B, All C=B | No A=C |

### Invalid Patterns
- Two particular premises → No valid conclusion
- Two negative premises → No valid conclusion
- "Some not" → Cannot deduce universal

## Complementary Pair
If asked "Either I or II follows":
Check if both conclusions together cover all possibilities

## Exam Strategy
1. Draw Venn diagrams always
2. Check "possibilities" carefully
3. "Some" includes "All" possibility
4. Practice 3-statement syllogisms
''',
      tags: ['syllogism', 'reasoning', 'banking', 'venn-diagram'],
      estimatedReadTime: 18,
      createdAt: _now,
    ),

    StudyMaterial(
      id: 'bank_reason_coding_notes',
      title: 'Coding-Decoding - All Pattern Types',
      description: 'Decode all types of coding patterns',
      subjectId: 'reasoning',
      topicId: 'coding_decoding',
      type: StudyMaterialType.notes,
      content: '''
# Coding-Decoding

## Type 1: Letter Shifting
Each letter shifted by fixed positions

### Example
If COME = FRPH, each letter +3
- C+3=F, O+3=R, M+3=P, E+3=H

### Quick Method
Compare first letter of word & code to find shift

## Type 2: Reverse Coding
Word reversed, then shifted

### Example
HELP → PLEH → CODE (with shifting)

## Type 3: Position-Based
Letter replaced by its position number
- A=1, B=2, ... Z=26

### Variations
- Position from end: A=26, Z=1
- Vowels/consonants different rules

## Type 4: Symbol/Number Codes
Words/letters mapped to symbols

### Strategy
1. Find words appearing in multiple statements
2. Identify common codes
3. Deduce word-code pairs

## Type 5: Conditions-Based
Different rules for different positions
- First letter: +1
- Last letter: -1
- Middle: No change

## Type 6: New Pattern Coding
Coded based on structure:
- Number of vowels
- Number of consonants
- Position combinations

## Quick Tips
1. Write A-Z with positions (1-26)
2. Know vowel positions: A(1), E(5), I(9), O(15), U(21)
3. Opposite letters: A↔Z, B↔Y, etc.
4. Practice reverse alphabets
''',
      tags: ['coding-decoding', 'reasoning', 'banking'],
      estimatedReadTime: 15,
      createdAt: _now,
    ),
  ];

  /// English Language Materials
  static List<StudyMaterial> get englishLanguage => [
    StudyMaterial(
      id: 'bank_english_rc_notes',
      title: 'Reading Comprehension - Speed Strategy',
      description: 'Read passages faster and answer accurately',
      subjectId: 'english',
      topicId: 'reading_comprehension',
      type: StudyMaterialType.notes,
      content: '''
# Reading Comprehension Strategy

## Question Types

### 1. Main Idea/Title
- Scan first and last paragraphs
- Look for repeated themes
- Avoid too specific or too broad options

### 2. Detail/Fact-Based
- Located in specific paragraph
- Keywords help locate answer
- Answer exactly as stated

### 3. Inference Questions
- "It can be inferred..."
- Answer not directly stated
- Based on logical deduction

### 4. Vocabulary in Context
- Don't use dictionary meaning
- Use surrounding sentences
- Substitute options to check fit

### 5. Author's Tone/Attitude
- Positive: Optimistic, Appreciative
- Negative: Critical, Pessimistic
- Neutral: Objective, Analytical

## Reading Techniques

### Skimming (30 seconds)
1. Read first paragraph fully
2. Read first line of each para
3. Read last paragraph
4. Get main theme

### Scanning (For details)
1. Read question first
2. Find keyword in passage
3. Read surrounding lines
4. Choose answer

## Time Management
- RC: 7-8 minutes per set
- Read questions first: 1 minute
- Read passage: 3-4 minutes
- Answer questions: 2-3 minutes

## Common Traps
- **Too Extreme**: Avoid "always", "never"
- **Partially Correct**: Verify all parts
- **Out of Scope**: Not in passage
- **Opposite Meaning**: Careful reading needed
''',
      tags: ['rc', 'english', 'banking', 'comprehension'],
      estimatedReadTime: 12,
      createdAt: _now,
    ),

    StudyMaterial(
      id: 'bank_english_errors_notes',
      title: 'Error Spotting - Grammar Rules',
      description: 'Common grammar errors in banking exams',
      subjectId: 'english',
      topicId: 'error_spotting',
      type: StudyMaterialType.notes,
      content: '''
# Error Spotting - Grammar Rules

## Subject-Verb Agreement

### Rule 1: Singular/Plural
- Singular subject → Singular verb
- "The list of items IS ready"

### Rule 2: Collective Nouns
- Usually singular: team, committee, jury
- "The team IS playing well"

### Rule 3: Either/Neither
- "Either...or" and "Neither...nor" → verb agrees with nearest subject

## Tense Errors

### Common Mistakes
- Mixing past and present in same sentence
- Using "did" with past form
- ✗ "He did not went"
- ✓ "He did not go"

### Since/For
- Since + point in time (since 2010)
- For + duration (for 5 years)

## Article Errors

### 'A' vs 'An'
Based on SOUND, not spelling:
- A university (yu sound)
- An hour (silent h)
- An MBA (em sound)

### The (Definite Article)
Use with:
- Unique things: the sun, the earth
- Superlatives: the best, the tallest
- Ordinals: the first, the second

## Pronoun Errors

### Agreement
- Singular antecedent → Singular pronoun
- "Everyone should bring HIS/HER book"

### Case
- Subject: I, he, she, we, they
- Object: me, him, her, us, them

## Preposition Errors
| Wrong | Correct |
|-------|---------|
| Discuss about | Discuss |
| Comprise of | Comprise |
| Enter into | Enter |
| Accompany with | Accompany |

## Practice Daily
1. Read 5 error spotting questions
2. Identify rule being tested
3. Note down new rules
4. Review weekly
''',
      tags: ['grammar', 'errors', 'english', 'banking'],
      estimatedReadTime: 15,
      createdAt: _now,
    ),
  ];

  /// General Awareness Materials
  static List<StudyMaterial> get generalAwareness => [
    StudyMaterial(
      id: 'bank_ga_current_affairs_notes',
      title: 'Current Affairs - Last 6 Months Coverage',
      description: 'Important current events for banking exams',
      subjectId: 'gk',
      topicId: 'current_affairs',
      type: StudyMaterialType.notes,
      content: '''
# Current Affairs Strategy

## Categories to Cover

### 1. Banking & Finance
- RBI policies and circulars
- New bank branches/headquarters
- Banking awards
- MoUs and partnerships
- Financial inclusion schemes

### 2. Government Schemes
- Welfare schemes
- Infrastructure projects
- Digital initiatives
- Agricultural schemes

### 3. Appointments
- Banking sector heads
- Government positions
- International organizations

### 4. Awards & Honors
- National awards
- International awards
- Sports achievements

### 5. International Affairs
- Summits and conferences
- Trade agreements
- UN resolutions

## Daily Routine
1. Read newspaper (30 mins)
2. Focus on banking/economy section
3. Note down key facts
4. Monthly revision

## Memory Techniques
- **Acronyms**: Create for schemes
- **Association**: Link facts to dates
- **Categories**: Group similar news
- **Weekly Quiz**: Self-test

## Important Static GK
- Bank establishment dates
- Headquarters locations
- Taglines of banks
- Bank nationalization years
''',
      tags: ['current-affairs', 'gk', 'banking'],
      estimatedReadTime: 10,
      createdAt: _now,
    ),
  ];

  /// Banking Awareness Materials
  static List<StudyMaterial> get bankingAwareness => [
    StudyMaterial(
      id: 'bank_awareness_rbi_notes',
      title: 'RBI - Functions, History & Policies',
      description: 'Complete guide to Reserve Bank of India',
      subjectId: 'banking_awareness',
      topicId: 'rbi',
      type: StudyMaterialType.notes,
      content: '''
# Reserve Bank of India (RBI)

## Basic Facts
- **Established**: April 1, 1935
- **Headquarters**: Mumbai
- **Based on**: RBI Act, 1934
- **Nationalized**: January 1, 1949
- **Current Governor**: [Update as per exam date]

## Main Functions

### 1. Monetary Authority
- Formulates monetary policy
- Controls money supply
- Manages inflation

### 2. Banker to Government
- Manages government accounts
- Issues government securities
- Handles public debt

### 3. Banker's Bank
- Maintains CRR of banks
- Lender of last resort
- Clears inter-bank transactions

### 4. Regulator of Banking
- Issues banking licenses
- Supervises banks
- Ensures financial stability

### 5. Currency Issuer
- Sole authority for currency notes
- Coins issued by Government
- Manages currency in circulation

## Monetary Policy Tools

### Quantitative Tools
- **Repo Rate**: Rate at which RBI lends to banks
- **Reverse Repo**: Rate at which RBI borrows from banks
- **CRR**: Cash with RBI (% of deposits)
- **SLR**: Liquid assets (% of deposits)

### Qualitative Tools
- Margin requirements
- Credit rationing
- Moral suasion
- Direct action

## Important Rates (Update regularly)
| Rate | Purpose |
|------|---------|
| Repo | Inflation control |
| Reverse Repo | Liquidity absorption |
| Bank Rate | Long-term lending |
| MSF | Emergency borrowing |

## Recent Initiatives
- Digital payments push
- Financial inclusion
- Cybersecurity guidelines
- Green finance initiatives
''',
      tags: ['rbi', 'banking-awareness', 'monetary-policy'],
      estimatedReadTime: 20,
      createdAt: _now,
    ),

    StudyMaterial(
      id: 'bank_awareness_types_notes',
      title: 'Types of Banks in India',
      description: 'Classification and functions of different banks',
      subjectId: 'banking_awareness',
      topicId: 'bank_types',
      type: StudyMaterialType.notes,
      content: '''
# Types of Banks in India

## 1. Commercial Banks

### Public Sector Banks (PSBs)
- Government holds majority stake (>50%)
- Examples: SBI, PNB, Bank of Baroda
- Total: 12 PSBs after mergers

### Private Sector Banks
- Majority private ownership
- Examples: HDFC, ICICI, Axis, Kotak

### Foreign Banks
- Headquarters outside India
- Examples: Citi, HSBC, Standard Chartered

## 2. Small Finance Banks
- Focus on unserved sections
- 75% loans to priority sector
- Examples: AU, Equitas, Ujjivan

## 3. Payment Banks
- Cannot lend money
- Maximum deposit: ₹2 lakh
- Examples: Paytm, Airtel, India Post

## 4. Regional Rural Banks (RRBs)
- Serve rural areas
- Sponsored by commercial banks
- Focus on agriculture

## 5. Cooperative Banks
- State Cooperative Banks
- District Central Cooperative Banks
- Primary Agricultural Credit Societies

## 6. Development Banks
- NABARD (Agriculture)
- SIDBI (Small Industries)
- NHB (Housing)
- EXIM Bank (Trade)

## Bank Mergers (Recent)
| Merged Banks | Into |
|--------------|------|
| Dena, Vijaya | Bank of Baroda |
| OBC, United | PNB |
| Syndicate | Canara Bank |
| Andhra, Corporation | Union Bank |

## Key Differences
| Feature | Public | Private |
|---------|--------|---------|
| Ownership | Govt | Private |
| Focus | Social | Profit |
| Technology | Improving | Advanced |
| Network | Wider | Urban-centric |
''',
      tags: ['bank-types', 'banking-awareness', 'psb', 'private-banks'],
      estimatedReadTime: 15,
      createdAt: _now,
    ),
  ];

  /// Get materials by subject
  static List<StudyMaterial> getBySubject(String subjectId) {
    switch (subjectId.toLowerCase()) {
      case 'quant':
      case 'quantitative_aptitude':
        return quantitativeAptitude;
      case 'reasoning':
      case 'reasoning_ability':
        return reasoningAbility;
      case 'english':
      case 'english_language':
        return englishLanguage;
      case 'gk':
      case 'general_awareness':
        return generalAwareness;
      case 'banking_awareness':
        return bankingAwareness;
      default:
        return [];
    }
  }

  /// Get material count
  static int get totalCount => getAll().length;
}
