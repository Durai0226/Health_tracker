import '../../../models/study_material_model.dart';

/// Banking Quantitative Aptitude - Formula Sheets
/// Comprehensive formulas for all banking exam topics

final List<StudyMaterial> bankingQuantFormulas = [
  // ==================== NUMBER SYSTEM FORMULAS ====================
  
  StudyMaterial(
    id: 'bank_quant_f_number_basics',
    title: 'Number System - Basic Formulas',
    description: 'Fundamental number properties and formulas',
    subjectId: 'quantitative_aptitude',
    topicId: 'number_system',
    type: StudyMaterialType.formula,
    content: '''
# Number System - Basic Formulas

## Types of Numbers
| Type | Definition | Examples |
|------|-----------|----------|
| Natural (N) | Counting numbers | 1, 2, 3, 4... |
| Whole (W) | N + 0 | 0, 1, 2, 3... |
| Integers (Z) | W + negatives | ...-2, -1, 0, 1, 2... |
| Rational (Q) | p/q form | 1/2, 3/4, 0.5 |
| Irrational | Non-terminating | √2, π, e |

## Sum Formulas
| Formula | Expression |
|---------|------------|
| Sum of first n naturals | **n(n+1)/2** |
| Sum of squares | **n(n+1)(2n+1)/6** |
| Sum of cubes | **[n(n+1)/2]²** |
| Sum of first n odd | **n²** |
| Sum of first n even | **n(n+1)** |

## Product Properties
- Product of n consecutive integers is divisible by **n!**
- Product of 2 consecutive = always even
- Product of 3 consecutive = always divisible by 6
''',
    tags: ['number-system', 'formulas', 'basics'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  StudyMaterial(
    id: 'bank_quant_f_divisibility',
    title: 'Divisibility Rules - Complete',
    description: 'All divisibility rules from 2 to 19',
    subjectId: 'quantitative_aptitude',
    topicId: 'number_system',
    type: StudyMaterialType.formula,
    content: '''
# Divisibility Rules

## Quick Reference Table
| Divisor | Rule |
|---------|------|
| **2** | Last digit even (0,2,4,6,8) |
| **3** | Sum of digits divisible by 3 |
| **4** | Last 2 digits divisible by 4 |
| **5** | Last digit 0 or 5 |
| **6** | Divisible by both 2 AND 3 |
| **7** | Double last digit, subtract from rest |
| **8** | Last 3 digits divisible by 8 |
| **9** | Sum of digits divisible by 9 |
| **10** | Last digit is 0 |
| **11** | |Odd place sum - Even place sum| = 0 or 11 |
| **12** | Divisible by both 3 AND 4 |
| **13** | 4×last + rest, repeat |
| **15** | Divisible by both 3 AND 5 |
| **16** | Last 4 digits divisible by 16 |
| **17** | 5×last - rest, repeat |
| **18** | Divisible by both 2 AND 9 |
| **19** | 2×last + rest, repeat |

## Divisibility by 7 (Detailed)
1. Take last digit, double it
2. Subtract from remaining number
3. Repeat until small number
4. Check if result ÷ 7

**Example**: 364
- 36 - (4×2) = 36 - 8 = 28
- 28 ÷ 7 = 4 ✓
''',
    tags: ['divisibility', 'formulas', 'rules'],
    estimatedReadTime: 6,
    createdAt: DateTime.now(),
  ),

  StudyMaterial(
    id: 'bank_quant_f_hcf_lcm',
    title: 'HCF & LCM - All Formulas',
    description: 'Complete HCF LCM formulas and properties',
    subjectId: 'quantitative_aptitude',
    topicId: 'number_system',
    type: StudyMaterialType.formula,
    content: '''
# HCF & LCM Formulas

## Basic Formulas
| Formula | Expression |
|---------|------------|
| Product Rule | **HCF × LCM = a × b** |
| For fractions HCF | HCF of numerators / LCM of denominators |
| For fractions LCM | LCM of numerators / HCF of denominators |

## Properties
- HCF of co-primes = **1**
- LCM of co-primes = **Product**
- HCF(a,b) always ≤ min(a,b)
- LCM(a,b) always ≥ max(a,b)
- HCF divides LCM

## Finding HCF Methods
1. **Prime Factorization**: Common factors with lowest powers
2. **Division Method**: Divide larger by smaller repeatedly
3. **Subtraction Method**: Subtract smaller from larger

## Finding LCM Methods
1. **Prime Factorization**: All factors with highest powers
2. **Division Method**: Divide by primes simultaneously

## Special Cases
- HCF of (a, a+1) = **1** (consecutive integers)
- LCM of (a, a+1) = **a(a+1)**
- HCF(ka, kb) = k × HCF(a,b)
- LCM(ka, kb) = k × LCM(a,b)
''',
    tags: ['hcf', 'lcm', 'formulas'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  StudyMaterial(
    id: 'bank_quant_f_remainder',
    title: 'Remainder Theorem - Formulas',
    description: 'All remainder theorem formulas',
    subjectId: 'quantitative_aptitude',
    topicId: 'number_system',
    type: StudyMaterialType.formula,
    content: '''
# Remainder Theorem Formulas

## Basic Formula
**Dividend = Divisor × Quotient + Remainder**

## Cyclicity for Remainders
| Last Digit | Cycle Length | Pattern |
|------------|--------------|---------|
| 0, 1, 5, 6 | 1 | Always same |
| 4, 9 | 2 | Alternates |
| 2, 3, 7, 8 | 4 | 4-cycle |

## Power Remainders
- **(aⁿ) mod m** = Find pattern cycle, use (n mod cycle)
- **aⁿ mod (a-1)** = 1 (always)
- **aⁿ mod (a+1)** = 1 if n even, a if n odd

## Fermat's Little Theorem
If p is prime and gcd(a,p) = 1:
**a^(p-1) ≡ 1 (mod p)**

## Wilson's Theorem
If p is prime:
**(p-1)! ≡ -1 (mod p)**

## Chinese Remainder Theorem
For coprime m₁, m₂:
Find x such that x ≡ a₁(mod m₁) and x ≡ a₂(mod m₂)
''',
    tags: ['remainder', 'formulas', 'theorem'],
    estimatedReadTime: 6,
    createdAt: DateTime.now(),
  ),

  // ==================== PERCENTAGE FORMULAS ====================
  
  StudyMaterial(
    id: 'bank_quant_f_percentage_basic',
    title: 'Percentage - Basic Formulas',
    description: 'Core percentage calculation formulas',
    subjectId: 'quantitative_aptitude',
    topicId: 'percentage',
    type: StudyMaterialType.formula,
    content: '''
# Percentage - Basic Formulas

## Core Formulas
| Formula | Expression |
|---------|------------|
| Percentage | **(Part/Whole) × 100** |
| Part | **(Percentage × Whole) / 100** |
| Whole | **(Part × 100) / Percentage** |
| % Change | **[(New-Old)/Old] × 100** |

## Fraction-Percentage Conversion
| Fraction | % | Fraction | % |
|----------|---|----------|---|
| 1/2 | 50% | 1/8 | 12.5% |
| 1/3 | 33.33% | 1/9 | 11.11% |
| 1/4 | 25% | 1/10 | 10% |
| 1/5 | 20% | 1/11 | 9.09% |
| 1/6 | 16.67% | 1/12 | 8.33% |
| 1/7 | 14.28% | 1/15 | 6.67% |

## Decimal Equivalents
| % | Decimal | % | Decimal |
|---|---------|---|---------|
| 10% | 0.1 | 75% | 0.75 |
| 25% | 0.25 | 80% | 0.8 |
| 50% | 0.5 | 100% | 1.0 |
''',
    tags: ['percentage', 'formulas', 'basics'],
    estimatedReadTime: 4,
    createdAt: DateTime.now(),
  ),

  StudyMaterial(
    id: 'bank_quant_f_percentage_change',
    title: 'Percentage Change Formulas',
    description: 'Increase, decrease, successive change formulas',
    subjectId: 'quantitative_aptitude',
    topicId: 'percentage',
    type: StudyMaterialType.formula,
    content: '''
# Percentage Change Formulas

## Single Change
| Type | Formula | Multiplier |
|------|---------|------------|
| Increase by x% | New = Old × (1 + x/100) | (100+x)/100 |
| Decrease by x% | New = Old × (1 - x/100) | (100-x)/100 |

## Successive Changes
**Net % = a + b + (ab/100)**

### Examples:
- 10% ↑ then 10% ↓ = 10 - 10 - 1 = **-1%**
- 20% ↑ then 20% ↑ = 20 + 20 + 4 = **44%**
- 25% ↑ then 20% ↓ = 25 - 20 - 5 = **0%**

## Reverse Percentage
| If increased by | To find original, multiply by |
|-----------------|------------------------------|
| 10% | 100/110 = 10/11 |
| 20% | 100/120 = 5/6 |
| 25% | 100/125 = 4/5 |
| 50% | 100/150 = 2/3 |

| If decreased by | To find original, multiply by |
|-----------------|------------------------------|
| 10% | 100/90 = 10/9 |
| 20% | 100/80 = 5/4 |
| 25% | 100/75 = 4/3 |
| 50% | 100/50 = 2 |
''',
    tags: ['percentage', 'change', 'formulas'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  StudyMaterial(
    id: 'bank_quant_f_percentage_population',
    title: 'Population & Depreciation Formulas',
    description: 'Growth and depreciation compound formulas',
    subjectId: 'quantitative_aptitude',
    topicId: 'percentage',
    type: StudyMaterialType.formula,
    content: '''
# Population & Depreciation Formulas

## Population Growth
**P = P₀(1 + r/100)ⁿ**
- P = Final population
- P₀ = Initial population
- r = Rate of growth %
- n = Number of years

## Depreciation
**V = V₀(1 - r/100)ⁿ**
- V = Final value
- V₀ = Initial value
- r = Rate of depreciation %
- n = Number of years

## Variable Rate Changes
**P = P₀ × (1 + r₁/100) × (1 + r₂/100) × (1 + r₃/100)**

## Quick Calculations
| Growth Rate | After 2 years multiplier |
|-------------|-------------------------|
| 10% | 1.21 |
| 20% | 1.44 |
| 25% | 1.5625 |
| 50% | 2.25 |

## Rule of 72
Time to double = **72 / Rate%**
- At 10% → 7.2 years to double
- At 12% → 6 years to double
''',
    tags: ['population', 'depreciation', 'formulas'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  // ==================== PROFIT & LOSS FORMULAS ====================
  
  StudyMaterial(
    id: 'bank_quant_f_profit_basic',
    title: 'Profit & Loss - Basic Formulas',
    description: 'Core profit and loss formulas',
    subjectId: 'quantitative_aptitude',
    topicId: 'profit_loss',
    type: StudyMaterialType.formula,
    content: '''
# Profit & Loss - Basic Formulas

## Key Terms
- **CP** = Cost Price (buying price)
- **SP** = Selling Price
- **MP** = Marked Price (label price)
- **Profit** = SP - CP (when SP > CP)
- **Loss** = CP - SP (when CP > SP)

## Core Formulas
| Formula | Expression |
|---------|------------|
| Profit % | **(Profit/CP) × 100** |
| Loss % | **(Loss/CP) × 100** |
| SP (profit) | **CP × (100 + P%)/100** |
| SP (loss) | **CP × (100 - L%)/100** |
| CP (from profit) | **SP × 100/(100 + P%)** |
| CP (from loss) | **SP × 100/(100 - L%)** |

## Discount Formulas
| Formula | Expression |
|---------|------------|
| Discount | **MP - SP** |
| Discount % | **(Discount/MP) × 100** |
| SP | **MP × (100 - D%)/100** |

## Relationship
**CP → (+Markup%) → MP → (-Discount%) → SP**
''',
    tags: ['profit', 'loss', 'formulas', 'basics'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  StudyMaterial(
    id: 'bank_quant_f_profit_markup',
    title: 'Markup & Discount Formulas',
    description: 'Combined markup discount profit formulas',
    subjectId: 'quantitative_aptitude',
    topicId: 'profit_loss',
    type: StudyMaterialType.formula,
    content: '''
# Markup & Discount Formulas

## Markup Formula
**Markup % = [(MP - CP)/CP] × 100**

## Combined Formula
If Markup = M% and Discount = D%, then:
**Profit % = M - D - (M×D)/100**

## Quick Reference
| Markup | Discount | Net Effect |
|--------|----------|------------|
| 20% | 10% | +8% profit |
| 25% | 20% | 0% (no profit/loss) |
| 30% | 20% | +4% profit |
| 50% | 30% | +5% profit |
| 40% | 30% | -2% loss |

## False Weight Formula
If a trader uses false weight:
**Profit % = [(True - False)/False] × 100**

Example: Using 900g instead of 1kg
Profit = (1000-900)/900 × 100 = **11.11%**

## Successive Discounts
D₁% then D₂%:
**Net Discount = D₁ + D₂ - (D₁×D₂)/100**
''',
    tags: ['markup', 'discount', 'formulas'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  StudyMaterial(
    id: 'bank_quant_f_profit_special',
    title: 'Special Profit & Loss Cases',
    description: 'Equal SP, same profit-loss, and more',
    subjectId: 'quantitative_aptitude',
    topicId: 'profit_loss',
    type: StudyMaterialType.formula,
    content: '''
# Special Profit & Loss Cases

## Same Selling Price, Same Profit-Loss %
If one item sold at x% profit and another at x% loss, both at same SP:
**Net Loss % = x²/100**

Example: One at 20% profit, one at 20% loss
Net Loss = 400/100 = **4%**

## Cost Price Ratio
If SP same and profit% are P₁ and P₂:
**CP₁ : CP₂ = (100+P₂) : (100+P₁)**

## Selling at Same Price
Two articles at same SP, one at a% profit, other at b% loss:
**Overall % = [(a-b)(100-a-b) - 2ab] / (200-a+b)**

## Break-even Point
When total CP = total SP (no profit, no loss)
If sold n₁ at profit and n₂ at loss:
**n₁ × P% = n₂ × L%**

## Cost Price Recovery
If x% goods spoiled, to maintain same profit:
**New SP increase = [Spoiled%/(100-Spoiled%)] × 100**
''',
    tags: ['profit', 'loss', 'special', 'formulas'],
    estimatedReadTime: 6,
    createdAt: DateTime.now(),
  ),

  // ==================== SIMPLE & COMPOUND INTEREST ====================
  
  StudyMaterial(
    id: 'bank_quant_f_si_basic',
    title: 'Simple Interest - All Formulas',
    description: 'Complete simple interest formulas',
    subjectId: 'quantitative_aptitude',
    topicId: 'simple_interest',
    type: StudyMaterialType.formula,
    content: '''
# Simple Interest Formulas

## Basic Formula
**SI = (P × R × T) / 100**
- P = Principal
- R = Rate per annum
- T = Time in years

## Derived Formulas
| To Find | Formula |
|---------|---------|
| Principal | **SI × 100 / (R × T)** |
| Rate | **SI × 100 / (P × T)** |
| Time | **SI × 100 / (P × R)** |
| Amount | **A = P + SI = P(1 + RT/100)** |

## Time Conversions
- Months to years: T = months/12
- Days to years: T = days/365

## When Principal Doubles
**Time = 100/R years**

## When Principal Triples
**Time = 200/R years**

## When Principal becomes n times
**Time = (n-1) × 100/R years**

## Split Investment
If P split into P₁ and P₂ at R₁% and R₂%:
**Total SI = (P₁×R₁×T + P₂×R₂×T)/100**
''',
    tags: ['simple-interest', 'formulas'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  StudyMaterial(
    id: 'bank_quant_f_ci_basic',
    title: 'Compound Interest - All Formulas',
    description: 'Complete compound interest formulas',
    subjectId: 'quantitative_aptitude',
    topicId: 'compound_interest',
    type: StudyMaterialType.formula,
    content: '''
# Compound Interest Formulas

## Basic Formula
**A = P(1 + R/100)ⁿ**
**CI = A - P = P[(1 + R/100)ⁿ - 1]**

## Compounding Frequencies
| Frequency | Formula |
|-----------|---------|
| Annually | A = P(1 + R/100)ⁿ |
| Half-yearly | A = P(1 + R/200)²ⁿ |
| Quarterly | A = P(1 + R/400)⁴ⁿ |
| Monthly | A = P(1 + R/1200)¹²ⁿ |

## CI vs SI Difference
**For 2 years:**
CI - SI = P(R/100)² = PR²/10000

**For 3 years:**
CI - SI = PR²(300+R)/1000000

## Quick Multipliers (Annual)
| Rate | 2 Years | 3 Years |
|------|---------|---------|
| 5% | 1.1025 | 1.1576 |
| 10% | 1.21 | 1.331 |
| 20% | 1.44 | 1.728 |
| 25% | 1.5625 | 1.9531 |

## Present Value
**PV = A / (1 + R/100)ⁿ**
''',
    tags: ['compound-interest', 'formulas'],
    estimatedReadTime: 6,
    createdAt: DateTime.now(),
  ),

  StudyMaterial(
    id: 'bank_quant_f_installments',
    title: 'Installment & EMI Formulas',
    description: 'Loan installment calculation formulas',
    subjectId: 'quantitative_aptitude',
    topicId: 'compound_interest',
    type: StudyMaterialType.formula,
    content: '''
# Installment & EMI Formulas

## Simple Interest Installment
**Total Amount = n × Installment**
Where: A = P + (P×R×n)/100

## Equal Annual Installments (CI)
**P = I × [(1+r)ⁿ - 1] / [r(1+r)ⁿ]**
Where r = R/100, I = Installment

## EMI Formula
**EMI = P × r × (1+r)ⁿ / [(1+r)ⁿ - 1]**
Where:
- P = Principal loan amount
- r = Monthly interest rate (Annual/12/100)
- n = Number of months

## Present Value of Annuity
**PV = PMT × [1 - (1+r)⁻ⁿ] / r**

## Quick EMI Approximation
For small rates:
**EMI ≈ P/n + P×r×(n+1)/(2n)**

## Flat Rate to Reducing Balance
Effective Rate ≈ Flat Rate × 1.8 to 2.0
''',
    tags: ['installment', 'emi', 'formulas'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  // ==================== TIME & WORK FORMULAS ====================
  
  StudyMaterial(
    id: 'bank_quant_f_time_work_basic',
    title: 'Time & Work - Basic Formulas',
    description: 'Fundamental time and work formulas',
    subjectId: 'quantitative_aptitude',
    topicId: 'time_work',
    type: StudyMaterialType.formula,
    content: '''
# Time & Work - Basic Formulas

## Core Concept
If A can do work in n days:
**A's 1 day work = 1/n**

## Basic Formulas
| Scenario | Formula |
|----------|---------|
| A & B together | 1/A + 1/B = 1/T |
| Work = | Rate × Time |
| Time = | Work / Rate |
| Rate = | Work / Time |

## Combined Work
**Time together = (A×B)/(A+B)**

For three workers:
**Time = (A×B×C)/(AB+BC+CA)**

## LCM Method (Recommended)
1. Take LCM of individual times = Total work units
2. Find per day work of each
3. Add rates for combined time

## Efficiency Ratio
If A is x times as efficient as B:
- A's time : B's time = 1 : x
- A's work : B's work = x : 1
''',
    tags: ['time-work', 'formulas', 'basics'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  StudyMaterial(
    id: 'bank_quant_f_time_work_special',
    title: 'Time & Work - Special Cases',
    description: 'Pipes, alternate work, and special scenarios',
    subjectId: 'quantitative_aptitude',
    topicId: 'time_work',
    type: StudyMaterialType.formula,
    content: '''
# Time & Work - Special Cases

## Pipes & Cisterns
- Inlet fills in A hours: Rate = +1/A
- Outlet empties in B hours: Rate = -1/B
- Combined: 1/A - 1/B

**Time to fill = AB/(B-A)** (when A < B)

## Alternate Day Work
If A works odd days, B works even days:
- Find work in 2-day cycle
- Calculate remaining work

## Work & Wages
**Wages ∝ Work Done**
- More work = More wages
- Wages ratio = Work ratio

If wages are W and work done is in ratio a:b:c
Individual wages = W×a/(a+b+c), W×b/(a+b+c), W×c/(a+b+c)

## Men-Days Concept
**M₁ × D₁ × H₁ / W₁ = M₂ × D₂ × H₂ / W₂**
- M = Men
- D = Days
- H = Hours per day
- W = Work

## Efficiency Change
If B is 50% more efficient than A:
B's time = A's time × 100/150 = 2A/3
''',
    tags: ['time-work', 'pipes', 'formulas'],
    estimatedReadTime: 6,
    createdAt: DateTime.now(),
  ),

  // ==================== TIME, SPEED & DISTANCE ====================
  
  StudyMaterial(
    id: 'bank_quant_f_speed_basic',
    title: 'Speed, Time & Distance - Basics',
    description: 'Fundamental speed distance formulas',
    subjectId: 'quantitative_aptitude',
    topicId: 'speed_distance',
    type: StudyMaterialType.formula,
    content: '''
# Speed, Time & Distance - Basic Formulas

## Core Formula
**Distance = Speed × Time**
**Speed = Distance / Time**
**Time = Distance / Speed**

## Unit Conversions
| Convert | Multiply by |
|---------|-------------|
| km/h to m/s | **5/18** |
| m/s to km/h | **18/5** |

Quick: km/h × 5/18 = m/s

## Average Speed
**For same distance at speeds S₁ and S₂:**
Average = **2×S₁×S₂/(S₁+S₂)**

**For different distances:**
Average = Total Distance / Total Time

## Relative Speed
| Direction | Formula |
|-----------|---------|
| Same direction | S₁ - S₂ |
| Opposite direction | S₁ + S₂ |

## Meeting Point
If A and B start from two points P and Q:
**Meeting point from P = (S_A × Total Distance)/(S_A + S_B)**
''',
    tags: ['speed', 'distance', 'formulas'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  StudyMaterial(
    id: 'bank_quant_f_trains',
    title: 'Trains - All Formulas',
    description: 'Complete train problem formulas',
    subjectId: 'quantitative_aptitude',
    topicId: 'speed_distance',
    type: StudyMaterialType.formula,
    content: '''
# Train Problem Formulas

## Crossing Stationary Objects
| Object | Distance Covered |
|--------|-----------------|
| Pole/Person | Length of train (L) |
| Platform/Bridge | L + Length of object |
| Another train (stationary) | L₁ + L₂ |

**Time = Distance / Speed**

## Crossing Moving Objects
| Direction | Relative Speed | Distance |
|-----------|---------------|----------|
| Same | S₁ - S₂ | L₁ + L₂ |
| Opposite | S₁ + S₂ | L₁ + L₂ |

## Crossing a Person (Moving)
| Direction | Relative Speed | Distance |
|-----------|---------------|----------|
| Same | S_train - S_person | L_train |
| Opposite | S_train + S_person | L_train |

## Two Trains Start Together
If trains of speeds S₁ and S₂ start simultaneously:
- Same direction: **Meeting distance = (S₁×S₂×t)/(S₁-S₂)**
- Opposite: **Meeting time = D/(S₁+S₂)**

## Train Passing Through Tunnel
**Time = (L_train + L_tunnel) / Speed**
''',
    tags: ['trains', 'speed', 'formulas'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  StudyMaterial(
    id: 'bank_quant_f_boats_streams',
    title: 'Boats & Streams - All Formulas',
    description: 'Complete boats and streams formulas',
    subjectId: 'quantitative_aptitude',
    topicId: 'speed_distance',
    type: StudyMaterialType.formula,
    content: '''
# Boats & Streams Formulas

## Key Terms
- **Still water speed** = Speed of boat in calm water (B)
- **Stream speed** = Speed of current (S)
- **Downstream** = With the current
- **Upstream** = Against the current

## Speed Formulas
| Direction | Speed |
|-----------|-------|
| Downstream | **B + S** |
| Upstream | **B - S** |

## Finding B and S
**B = (Downstream + Upstream) / 2**
**S = (Downstream - Upstream) / 2**

## Time to Cover Same Distance
**Downstream : Upstream = (B-S) : (B+S)**

## Round Trip
Time for round trip = D/(B+S) + D/(B-S) = **2BD/(B²-S²)**

## Speed of Current from Times
If upstream time = t₁, downstream time = t₂:
**S = D(t₁-t₂)/(2×t₁×t₂)**

## Man in Still Water
If man rows d km upstream and downstream in same time T each:
**B = d/T** (when S = 0)
''',
    tags: ['boats', 'streams', 'formulas'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  // ==================== RATIO & PROPORTION ====================
  
  StudyMaterial(
    id: 'bank_quant_f_ratio_basic',
    title: 'Ratio & Proportion - Formulas',
    description: 'All ratio and proportion formulas',
    subjectId: 'quantitative_aptitude',
    topicId: 'ratio_proportion',
    type: StudyMaterialType.formula,
    content: '''
# Ratio & Proportion Formulas

## Basic Definitions
**Ratio** a:b = a/b
**Proportion** a:b :: c:d means a/b = c/d

## Properties
- a:b = ka:kb (multiplying)
- a:b = a/k:b/k (dividing)
- If a:b and b:c, then a:c = a:c
- **Product of means = Product of extremes**
  a:b :: c:d → b×c = a×d

## Duplicate & Triplicate Ratios
| Type | Formula |
|------|---------|
| Duplicate of a:b | a²:b² |
| Triplicate of a:b | a³:b³ |
| Sub-duplicate | √a:√b |
| Sub-triplicate | ∛a:∛b |

## Componendo-Dividendo
If a/b = c/d, then:
**(a+b)/(a-b) = (c+d)/(c-d)**

## Finding Values
If a:b = 3:4 and total = 70:
- a = 70 × 3/7 = 30
- b = 70 × 4/7 = 40
''',
    tags: ['ratio', 'proportion', 'formulas'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  StudyMaterial(
    id: 'bank_quant_f_partnership',
    title: 'Partnership - All Formulas',
    description: 'Profit sharing and partnership formulas',
    subjectId: 'quantitative_aptitude',
    topicId: 'ratio_proportion',
    type: StudyMaterialType.formula,
    content: '''
# Partnership Formulas

## Simple Partnership
When all partners invest for **same time**:
**Profit ratio = Investment ratio**
A : B = I_A : I_B

## Compound Partnership
When partners invest for **different times**:
**Profit ratio = (Investment × Time) ratio**
A : B = (I_A × T_A) : (I_B × T_B)

## Working vs Sleeping Partner
- Working partner gets salary + profit share
- Sleeping partner gets only profit share

**Working partner's share = Salary + (Remaining profit × Share)**

## Capital Withdrawal/Addition
Calculate capital-months for each period separately.

Example: A invests 10000, withdraws 2000 after 6 months
A's capital-months = 10000×6 + 8000×6 = 108000

## Admission of New Partner
If new partner P₃ joins with investment I₃ after T months:
P₃'s share calculated for (12-T) months only

## Profit Calculation
Individual profit = Total Profit × (Individual ratio / Sum of ratios)
''',
    tags: ['partnership', 'profit', 'formulas'],
    estimatedReadTime: 6,
    createdAt: DateTime.now(),
  ),

  // ==================== MIXTURE & ALLIGATION ====================
  
  StudyMaterial(
    id: 'bank_quant_f_mixture',
    title: 'Mixture & Alligation - Formulas',
    description: 'Complete mixture and alligation formulas',
    subjectId: 'quantitative_aptitude',
    topicId: 'mixture_alligation',
    type: StudyMaterialType.formula,
    content: '''
# Mixture & Alligation Formulas

## Alligation Rule
**Quantity of cheaper / Quantity of dearer = (Dearer - Mean) / (Mean - Cheaper)**

```
    Cheaper (C)         Dearer (D)
         \\             /
          \\           /
           Mean (M)
          /           \\
         /             \\
     (D-M)             (M-C)
```
Ratio = (D-M) : (M-C)

## Replacement Formula
If x liters removed and replaced with water, repeated n times:
**Final concentration = Original × (1 - x/V)ⁿ**
- V = Total volume
- x = Quantity removed each time
- n = Number of replacements

## Mixture of Two Solutions
If V₁ of C₁% mixed with V₂ of C₂%:
**Final concentration = (V₁×C₁ + V₂×C₂)/(V₁+V₂)**

## Finding Ratio to Mix
To get concentration M from C₁ and C₂:
**V₁ : V₂ = |C₂ - M| : |M - C₁|**
''',
    tags: ['mixture', 'alligation', 'formulas'],
    estimatedReadTime: 6,
    createdAt: DateTime.now(),
  ),

  // ==================== AVERAGES ====================
  
  StudyMaterial(
    id: 'bank_quant_f_averages',
    title: 'Averages - All Formulas',
    description: 'Complete average calculation formulas',
    subjectId: 'quantitative_aptitude',
    topicId: 'averages',
    type: StudyMaterialType.formula,
    content: '''
# Averages Formulas

## Basic Formula
**Average = Sum of observations / Number of observations**
**Sum = Average × Number**

## Weighted Average
**Weighted Avg = (n₁×A₁ + n₂×A₂ + ...) / (n₁ + n₂ + ...)**

## Change in Average
| Action | New Average |
|--------|-------------|
| Add value X | Old avg + (X - Old avg)/(n+1) |
| Remove value X | Old avg + (Old avg - X)/(n-1) |
| Replace X with Y | Old avg + (Y - X)/n |

## Average Speed
For same distance: **2S₁S₂/(S₁+S₂)**
For same time: **(S₁+S₂)/2**

## Average of Consecutive Numbers
- First n naturals: **(n+1)/2**
- Consecutive integers: **(First + Last)/2**
- AP terms: **(First term + Last term)/2**

## When New Member Joins
If average increases by x when new member with value V joins:
**V = Old average + x(n+1)**
''',
    tags: ['averages', 'formulas'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  // ==================== AGES ====================
  
  StudyMaterial(
    id: 'bank_quant_f_ages',
    title: 'Problems on Ages - Formulas',
    description: 'Age problem solving formulas',
    subjectId: 'quantitative_aptitude',
    topicId: 'ages',
    type: StudyMaterialType.formula,
    content: '''
# Problems on Ages - Formulas

## Key Concepts
- Difference of ages **remains constant**
- Ratio of ages **changes** with time

## Basic Setup
| Time | Person A | Person B |
|------|----------|----------|
| x years ago | a - x | b - x |
| Present | a | b |
| x years hence | a + x | b + x |

## Common Patterns

### Pattern 1: Sum and Difference
If A + B = S and A - B = D:
**A = (S + D)/2**
**B = (S - D)/2**

### Pattern 2: Ratio Changes
Present ratio = a:b
After n years ratio = c:d
**Present ages = (a×k) and (b×k)**
where k found by: (ak+n)/(bk+n) = c/d

### Pattern 3: Multiple of Age
"A is twice as old as B was when A was as old as B is now"
Let B's present age = x, A's present age = y
Difference = y - x (constant)
When A was x, B was x - (y-x) = 2x - y
So y = 2(2x - y) → 3y = 4x

## Father-Son Problems
Present: F = kS (Father is k times Son)
After n years: F + n = m(S + n)
Solve: kS + n = mS + mn
''',
    tags: ['ages', 'formulas'],
    estimatedReadTime: 6,
    createdAt: DateTime.now(),
  ),

  // ==================== PERMUTATION & COMBINATION ====================
  
  StudyMaterial(
    id: 'bank_quant_f_pnc',
    title: 'Permutation & Combination - Formulas',
    description: 'Complete P&C formulas',
    subjectId: 'quantitative_aptitude',
    topicId: 'permutation_combination',
    type: StudyMaterialType.formula,
    content: '''
# Permutation & Combination Formulas

## Factorial
**n! = n × (n-1) × (n-2) × ... × 2 × 1**
- 0! = 1
- 1! = 1

## Permutation (Arrangement)
**ⁿPᵣ = n! / (n-r)!**
- Order matters
- nPn = n!
- nP1 = n

## Combination (Selection)
**ⁿCᵣ = n! / [r!(n-r)!]**
- Order doesn't matter
- nC0 = nCn = 1
- nC1 = n
- nCr = nC(n-r)

## Relationship
**ⁿPᵣ = ⁿCᵣ × r!**

## Special Formulas
| Scenario | Formula |
|----------|---------|
| Circular arrangement | (n-1)! |
| Necklace/Bracelet | (n-1)!/2 |
| With repetition allowed | nʳ |
| Identical objects | n!/(p!×q!×...) |

## Important Values
| n | n! |
|---|-----|
| 5 | 120 |
| 6 | 720 |
| 7 | 5040 |
| 8 | 40320 |
''',
    tags: ['permutation', 'combination', 'formulas'],
    estimatedReadTime: 6,
    createdAt: DateTime.now(),
  ),

  // ==================== PROBABILITY ====================
  
  StudyMaterial(
    id: 'bank_quant_f_probability',
    title: 'Probability - All Formulas',
    description: 'Complete probability formulas',
    subjectId: 'quantitative_aptitude',
    topicId: 'probability',
    type: StudyMaterialType.formula,
    content: '''
# Probability Formulas

## Basic Formula
**P(E) = Favorable outcomes / Total outcomes**

## Properties
- 0 ≤ P(E) ≤ 1
- P(E) + P(E') = 1 (complement)
- P(sure event) = 1
- P(impossible event) = 0

## Addition Rules
| Events | Formula |
|--------|---------|
| Mutually exclusive | P(A∪B) = P(A) + P(B) |
| Not mutually exclusive | P(A∪B) = P(A) + P(B) - P(A∩B) |

## Multiplication Rules
| Events | Formula |
|--------|---------|
| Independent | P(A∩B) = P(A) × P(B) |
| Dependent | P(A∩B) = P(A) × P(B|A) |

## Conditional Probability
**P(A|B) = P(A∩B) / P(B)**

## Common Probabilities
| Experiment | Total Outcomes |
|------------|---------------|
| Coin toss | 2 |
| Two coins | 4 |
| Three coins | 8 |
| One die | 6 |
| Two dice | 36 |
| Pack of cards | 52 |

## Cards Probability
- Hearts/Diamonds/Clubs/Spades: 13 each
- Face cards: 12 (4 each J,Q,K)
- Aces: 4
''',
    tags: ['probability', 'formulas'],
    estimatedReadTime: 6,
    createdAt: DateTime.now(),
  ),

  // ==================== DATA INTERPRETATION ====================
  
  StudyMaterial(
    id: 'bank_quant_f_di_basics',
    title: 'Data Interpretation - Formulas',
    description: 'DI calculation formulas',
    subjectId: 'quantitative_aptitude',
    topicId: 'data_interpretation',
    type: StudyMaterialType.formula,
    content: '''
# Data Interpretation Formulas

## Percentage Calculations
- **% increase** = (Increase/Original) × 100
- **% of total** = (Part/Total) × 100
- **Value from %** = (% × Total) / 100

## Pie Chart Formulas
- **Angle = (Value/Total) × 360°**
- **Value = (Angle/360) × Total**
- **Percentage = (Angle/360) × 100**

## Bar/Line Graph
- **Growth rate** = [(New-Old)/Old] × 100
- **Average** = Sum of values / Number of values
- **Ratio** = Value₁ : Value₂

## CAGR (Compound Annual Growth Rate)
**CAGR = [(Final/Initial)^(1/n) - 1] × 100**

## Table Calculations
- **Row total** = Sum of row values
- **Column total** = Sum of column values
- **% contribution** = (Cell/Row or Column total) × 100

## Quick Percentage Tricks
| Fraction | % Equivalent |
|----------|-------------|
| 1/8 | 12.5% |
| 3/8 | 37.5% |
| 5/8 | 62.5% |
| 7/8 | 87.5% |
''',
    tags: ['data-interpretation', 'formulas'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  // ==================== MENSURATION ====================
  
  StudyMaterial(
    id: 'bank_quant_f_mensuration_2d',
    title: '2D Mensuration - All Formulas',
    description: 'Area and perimeter of 2D shapes',
    subjectId: 'quantitative_aptitude',
    topicId: 'mensuration',
    type: StudyMaterialType.formula,
    content: '''
# 2D Mensuration Formulas

## Rectangle
- **Area = Length × Breadth**
- **Perimeter = 2(L + B)**
- **Diagonal = √(L² + B²)**

## Square
- **Area = Side² = Diagonal²/2**
- **Perimeter = 4 × Side**
- **Diagonal = Side × √2**

## Triangle
- **Area = ½ × Base × Height**
- **Area = √[s(s-a)(s-b)(s-c)]** (Heron's formula)
  where s = (a+b+c)/2
- **Equilateral: Area = (√3/4) × Side²**

## Circle
- **Area = πr²**
- **Circumference = 2πr**
- **Sector Area = (θ/360) × πr²**
- **Arc Length = (θ/360) × 2πr**

## Trapezium
- **Area = ½ × (Sum of parallel sides) × Height**

## Parallelogram
- **Area = Base × Height**

## Rhombus
- **Area = ½ × d₁ × d₂** (product of diagonals)
''',
    tags: ['mensuration', '2d', 'formulas'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  StudyMaterial(
    id: 'bank_quant_f_mensuration_3d',
    title: '3D Mensuration - All Formulas',
    description: 'Volume and surface area of 3D shapes',
    subjectId: 'quantitative_aptitude',
    topicId: 'mensuration',
    type: StudyMaterialType.formula,
    content: '''
# 3D Mensuration Formulas

## Cube (side = a)
- **Volume = a³**
- **TSA = 6a²**
- **LSA = 4a²**
- **Diagonal = a√3**

## Cuboid (l, b, h)
- **Volume = l × b × h**
- **TSA = 2(lb + bh + hl)**
- **LSA = 2h(l + b)**
- **Diagonal = √(l² + b² + h²)**

## Cylinder (r, h)
- **Volume = πr²h**
- **CSA = 2πrh**
- **TSA = 2πr(r + h)**

## Cone (r, h, l)
- **Volume = ⅓πr²h**
- **CSA = πrl**
- **TSA = πr(r + l)**
- **l = √(r² + h²)**

## Sphere (r)
- **Volume = (4/3)πr³**
- **Surface Area = 4πr²**

## Hemisphere (r)
- **Volume = (2/3)πr³**
- **CSA = 2πr²**
- **TSA = 3πr²**

## Prism
- **Volume = Area of base × Height**
- **LSA = Perimeter of base × Height**
''',
    tags: ['mensuration', '3d', 'formulas'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  // ==================== QUADRATIC EQUATIONS ====================
  
  StudyMaterial(
    id: 'bank_quant_f_quadratic',
    title: 'Quadratic Equations - Formulas',
    description: 'All quadratic equation formulas',
    subjectId: 'quantitative_aptitude',
    topicId: 'quadratic_equations',
    type: StudyMaterialType.formula,
    content: '''
# Quadratic Equations Formulas

## Standard Form
**ax² + bx + c = 0** (a ≠ 0)

## Quadratic Formula
**x = [-b ± √(b²-4ac)] / 2a**

## Discriminant (D)
**D = b² - 4ac**

| D Value | Nature of Roots |
|---------|-----------------|
| D > 0 | Real & distinct |
| D = 0 | Real & equal |
| D < 0 | Imaginary |
| D = perfect square | Rational |

## Sum & Product of Roots
If α and β are roots:
- **α + β = -b/a**
- **α × β = c/a**

## Forming Equation from Roots
**x² - (α + β)x + (αβ) = 0**

## Relationship Between Roots
| Condition | Relationship |
|-----------|--------------|
| Equal roots | α = β |
| One root = 0 | c = 0 |
| Roots reciprocal | c = a |
| Roots equal & opposite | b = 0 |
| Both roots positive | b/a < 0, c/a > 0 |
| Both roots negative | b/a > 0, c/a > 0 |
''',
    tags: ['quadratic', 'equations', 'formulas'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  // ==================== NUMBER SERIES ====================
  
  StudyMaterial(
    id: 'bank_quant_f_series',
    title: 'Number Series - Formulas',
    description: 'AP, GP, and series formulas',
    subjectId: 'quantitative_aptitude',
    topicId: 'number_series',
    type: StudyMaterialType.formula,
    content: '''
# Number Series Formulas

## Arithmetic Progression (AP)
- **nth term: aₙ = a + (n-1)d**
- **Sum of n terms: Sₙ = n/2[2a + (n-1)d]**
- **Sum = n/2(First + Last)**
- **Common difference: d = a₂ - a₁**

## Geometric Progression (GP)
- **nth term: aₙ = arⁿ⁻¹**
- **Sum of n terms: Sₙ = a(rⁿ-1)/(r-1)** when r > 1
- **Sum of n terms: Sₙ = a(1-rⁿ)/(1-r)** when r < 1
- **Sum to infinity: S∞ = a/(1-r)** when |r| < 1
- **Common ratio: r = a₂/a₁**

## Harmonic Progression (HP)
Reciprocals form an AP
- **nth term = 1/[a + (n-1)d]** where a, d are of corresponding AP

## Special Sums
| Series | Sum |
|--------|-----|
| 1+2+3+...+n | n(n+1)/2 |
| 1²+2²+3²+...+n² | n(n+1)(2n+1)/6 |
| 1³+2³+3³+...+n³ | [n(n+1)/2]² |
| 2+4+6+...+2n | n(n+1) |
| 1+3+5+...+(2n-1) | n² |
''',
    tags: ['series', 'ap', 'gp', 'formulas'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  // ==================== SIMPLIFICATION ====================
  
  StudyMaterial(
    id: 'bank_quant_f_simplification',
    title: 'Simplification - Key Formulas',
    description: 'BODMAS and simplification techniques',
    subjectId: 'quantitative_aptitude',
    topicId: 'simplification',
    type: StudyMaterialType.formula,
    content: '''
# Simplification Formulas

## BODMAS Rule
**B** - Brackets (first)
**O** - Orders/Powers
**D** - Division
**M** - Multiplication
**A** - Addition
**S** - Subtraction

## Bracket Priority
1. Vinculum (—)
2. Parentheses ( )
3. Braces { }
4. Square brackets [ ]

## Algebraic Identities
| Identity | Expansion |
|----------|-----------|
| (a+b)² | a² + 2ab + b² |
| (a-b)² | a² - 2ab + b² |
| (a+b)(a-b) | a² - b² |
| (a+b)³ | a³ + 3a²b + 3ab² + b³ |
| (a-b)³ | a³ - 3a²b + 3ab² - b³ |
| a³ + b³ | (a+b)(a² - ab + b²) |
| a³ - b³ | (a-b)(a² + ab + b²) |

## Square Roots
- √(a×b) = √a × √b
- √(a/b) = √a / √b
- (√a)² = a

## Cube Roots
- ∛(a×b) = ∛a × ∛b
- ∛(a/b) = ∛a / ∛b
''',
    tags: ['simplification', 'bodmas', 'formulas'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  // ==================== SURDS & INDICES ====================
  
  StudyMaterial(
    id: 'bank_quant_f_surds_indices',
    title: 'Surds & Indices - Formulas',
    description: 'Complete surds and indices formulas',
    subjectId: 'quantitative_aptitude',
    topicId: 'surds_indices',
    type: StudyMaterialType.formula,
    content: '''
# Surds & Indices Formulas

## Laws of Indices
| Law | Formula |
|-----|---------|
| Multiplication | aᵐ × aⁿ = aᵐ⁺ⁿ |
| Division | aᵐ ÷ aⁿ = aᵐ⁻ⁿ |
| Power of power | (aᵐ)ⁿ = aᵐⁿ |
| Product power | (ab)ⁿ = aⁿbⁿ |
| Quotient power | (a/b)ⁿ = aⁿ/bⁿ |
| Zero power | a⁰ = 1 |
| Negative power | a⁻ⁿ = 1/aⁿ |
| Fractional power | a^(m/n) = ⁿ√(aᵐ) |

## Laws of Surds
| Operation | Formula |
|-----------|---------|
| Multiplication | √a × √b = √(ab) |
| Division | √a ÷ √b = √(a/b) |
| Power | (√a)ⁿ = √(aⁿ) |
| Rationalization | √a × √a = a |

## Rationalization
- (√a + √b)(√a - √b) = a - b
- 1/(√a + √b) × (√a - √b)/(√a - √b) = (√a - √b)/(a - b)

## Comparison of Surds
To compare ⁿ√a and ᵐ√b:
1. Find LCM of n and m
2. Raise both to LCM power
3. Compare results
''',
    tags: ['surds', 'indices', 'formulas'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),
];
