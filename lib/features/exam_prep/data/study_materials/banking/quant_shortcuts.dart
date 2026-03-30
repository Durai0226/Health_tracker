import '../../../models/study_material_model.dart';

/// Banking Quantitative Aptitude - Shortcuts & Tricks
/// Quick calculation methods for banking exams

final List<StudyMaterial> bankingQuantShortcuts = [
  // ==================== NUMBER SYSTEM SHORTCUTS ====================
  
  StudyMaterial(
    id: 'bank_quant_s_squares',
    title: 'Square Calculation Shortcuts',
    description: 'Calculate squares mentally in seconds',
    subjectId: 'quantitative_aptitude',
    topicId: 'number_system',
    type: StudyMaterialType.shortcut,
    content: '''
# Square Calculation Shortcuts

## Numbers ending in 5
**Formula: n5² = n(n+1) | 25**
- 25² = 2×3 | 25 = **625**
- 35² = 3×4 | 25 = **1225**
- 75² = 7×8 | 25 = **5625**
- 115² = 11×12 | 25 = **13225**

## Numbers near 50
**Formula: (50±n)² = (25±n) | n²**
- 48² = 25-2 | 04 = **2304**
- 52² = 25+2 | 04 = **2704**
- 53² = 25+3 | 09 = **2809**

## Numbers near 100
**Formula: (100±n)² = (100±2n) | n²**
- 97² = 100-6 | 09 = **9409**
- 103² = 100+6 | 09 = **10609**
- 108² = 100+16 | 64 = **11664**

## Any two-digit number (a|b)²
**= a² | 2ab | b²** (carry if needed)
- 23² = 4 | 12 | 9 = **529**
- 34² = 9 | 24 | 16 = **1156**
''',
    tags: ['squares', 'shortcuts', 'vedic-math'],
    estimatedReadTime: 4,
    createdAt: DateTime.now(),
  ),

  StudyMaterial(
    id: 'bank_quant_s_cubes',
    title: 'Cube Calculation Shortcuts',
    description: 'Quick cube calculations',
    subjectId: 'quantitative_aptitude',
    topicId: 'number_system',
    type: StudyMaterialType.shortcut,
    content: '''
# Cube Calculation Shortcuts

## Memorize These Cubes
| n | n³ | n | n³ |
|---|-----|---|-----|
| 1 | 1 | 6 | 216 |
| 2 | 8 | 7 | 343 |
| 3 | 27 | 8 | 512 |
| 4 | 64 | 9 | 729 |
| 5 | 125 | 10 | 1000 |

## Last Digit Pattern
| Last digit of n | Last digit of n³ |
|-----------------|------------------|
| 1 | 1 |
| 2 | 8 |
| 3 | 7 |
| 4 | 4 |
| 5 | 5 |
| 6 | 6 |
| 7 | 3 |
| 8 | 2 |
| 9 | 9 |
| 0 | 0 |

## Finding Cube Root
For perfect cubes up to 1000000:
1. Last digit gives unit digit (use table above)
2. Ignore last 3 digits, nearest cube gives tens digit

**Example**: ∛39304
- Last digit 4 → unit = 4
- 39 is between 27(3³) and 64(4³) → tens = 3
- Answer: **34**
''',
    tags: ['cubes', 'shortcuts'],
    estimatedReadTime: 4,
    createdAt: DateTime.now(),
  ),

  StudyMaterial(
    id: 'bank_quant_s_multiplication',
    title: 'Fast Multiplication Tricks',
    description: 'Vedic math multiplication shortcuts',
    subjectId: 'quantitative_aptitude',
    topicId: 'simplification',
    type: StudyMaterialType.shortcut,
    content: '''
# Fast Multiplication Tricks

## Multiply by 11
**Add adjacent digits, put in middle**
- 23 × 11 = 2 | (2+3) | 3 = **253**
- 45 × 11 = 4 | (4+5) | 5 = **495**
- 67 × 11 = 6 | (6+7) | 7 = 6|13|7 = **737**

## Multiply by 5
**Divide by 2, multiply by 10**
- 48 × 5 = 48/2 × 10 = **240**
- 126 × 5 = 126/2 × 10 = **630**

## Multiply by 25
**Divide by 4, multiply by 100**
- 48 × 25 = 48/4 × 100 = **1200**
- 84 × 25 = 84/4 × 100 = **2100**

## Multiply by 125
**Divide by 8, multiply by 1000**
- 48 × 125 = 48/8 × 1000 = **6000**

## Numbers near 100
**(100-a)(100-b) = (100-a-b) | ab**
- 97 × 96 = (97-4) | 12 = **9312**
- 98 × 93 = (98-7) | 14 = **9114**

## Cross Multiplication (Any 2-digit)
**ab × cd = ac | (ad+bc) | bd**
- 23 × 14 = 2×1 | (2×4+3×1) | 3×4 = 2|11|12 = **322**
''',
    tags: ['multiplication', 'vedic-math', 'shortcuts'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  StudyMaterial(
    id: 'bank_quant_s_division',
    title: 'Quick Division Tricks',
    description: 'Fast division calculation methods',
    subjectId: 'quantitative_aptitude',
    topicId: 'simplification',
    type: StudyMaterialType.shortcut,
    content: '''
# Quick Division Tricks

## Divide by 5
**Multiply by 2, divide by 10**
- 235 ÷ 5 = 235 × 2 / 10 = **47**
- 480 ÷ 5 = 480 × 2 / 10 = **96**

## Divide by 25
**Multiply by 4, divide by 100**
- 450 ÷ 25 = 450 × 4 / 100 = **18**
- 625 ÷ 25 = 625 × 4 / 100 = **25**

## Divide by 125
**Multiply by 8, divide by 1000**
- 375 ÷ 125 = 375 × 8 / 1000 = **3**

## Divide by 50
**Multiply by 2, divide by 100**
- 350 ÷ 50 = 350 × 2 / 100 = **7**

## Check Divisibility Quickly
| Divisor | Quick Check |
|---------|-------------|
| 4 | Last 2 digits ÷ 4 |
| 8 | Last 3 digits ÷ 8 |
| 9 | Digit sum ÷ 9 |
| 11 | Alternate sum difference |

## Remainder Shortcut
**To find remainder when ÷ 9:**
Just add all digits repeatedly!
- 5834 ÷ 9: 5+8+3+4 = 20, 2+0 = **2** remainder
''',
    tags: ['division', 'shortcuts'],
    estimatedReadTime: 4,
    createdAt: DateTime.now(),
  ),

  // ==================== PERCENTAGE SHORTCUTS ====================

  StudyMaterial(
    id: 'bank_quant_s_percentage_calc',
    title: 'Percentage Calculation Tricks',
    description: 'Calculate percentages mentally',
    subjectId: 'quantitative_aptitude',
    topicId: 'percentage',
    type: StudyMaterialType.shortcut,
    content: '''
# Percentage Calculation Tricks

## Base Method
**X% of Y = Y% of X**
- 16% of 25 = 25% of 16 = **4**
- 8% of 50 = 50% of 8 = **4**
- 4% of 75 = 75% of 4 = **3**

## Building Block Method
| Base % | How to Find |
|--------|-------------|
| 10% | Divide by 10 |
| 5% | Half of 10% |
| 1% | Divide by 100 |
| 20% | 10% × 2 |
| 25% | Divide by 4 |
| 50% | Divide by 2 |

## Quick Calculations
**15% = 10% + 5%**
- 15% of 80 = 8 + 4 = **12**

**17.5% = 10% + 5% + 2.5%**
- 17.5% of 200 = 20 + 10 + 5 = **35**

## Fraction to % (memorize)
| Fraction | % |
|----------|---|
| 1/6 | 16.67% |
| 1/7 | 14.28% |
| 1/8 | 12.5% |
| 1/9 | 11.11% |
| 1/11 | 9.09% |
| 1/12 | 8.33% |
''',
    tags: ['percentage', 'shortcuts', 'mental-math'],
    estimatedReadTime: 4,
    createdAt: DateTime.now(),
  ),

  StudyMaterial(
    id: 'bank_quant_s_percentage_change',
    title: 'Percentage Change Shortcuts',
    description: 'Quick successive change calculations',
    subjectId: 'quantitative_aptitude',
    topicId: 'percentage',
    type: StudyMaterialType.shortcut,
    content: '''
# Percentage Change Shortcuts

## Net Effect Table (Memorize)
| Up then Down | Net Change |
|--------------|------------|
| 10% ↑ then 10% ↓ | -1% |
| 20% ↑ then 20% ↓ | -4% |
| 25% ↑ then 25% ↓ | -6.25% |
| 50% ↑ then 50% ↓ | -25% |

## Quick Successive Change
**Formula: a + b + ab/100**
- 20% up, 10% up = 20+10+2 = **32%**
- 30% down, 20% down = -30-20+6 = **-44%**

## Price-Consumption Rule
If price ↑ by x%, to maintain same expenditure:
**Consumption ↓ by [x/(100+x)] × 100%**

| Price ↑ | Consumption ↓ |
|---------|---------------|
| 10% | 9.09% (1/11) |
| 20% | 16.67% (1/6) |
| 25% | 20% (1/5) |
| 50% | 33.33% (1/3) |

## Reverse Percentage
To find original after x% increase:
**Multiply by 100/(100+x)**
| Increase | Multiplier |
|----------|------------|
| 10% | 10/11 |
| 20% | 5/6 |
| 25% | 4/5 |
| 50% | 2/3 |
''',
    tags: ['percentage', 'change', 'shortcuts'],
    estimatedReadTime: 4,
    createdAt: DateTime.now(),
  ),

  // ==================== PROFIT & LOSS SHORTCUTS ====================

  StudyMaterial(
    id: 'bank_quant_s_profit_loss',
    title: 'Profit & Loss Quick Methods',
    description: 'Fast profit loss calculations',
    subjectId: 'quantitative_aptitude',
    topicId: 'profit_loss',
    type: StudyMaterialType.shortcut,
    content: '''
# Profit & Loss Quick Methods

## Multiplier Method
| Profit/Loss | SP Multiplier |
|-------------|---------------|
| 10% profit | 1.1 or 11/10 |
| 20% profit | 1.2 or 6/5 |
| 25% profit | 1.25 or 5/4 |
| 10% loss | 0.9 or 9/10 |
| 20% loss | 0.8 or 4/5 |
| 25% loss | 0.75 or 3/4 |

## Quick CP from SP
| Profit % | CP = SP × |
|----------|-----------|
| 10% | 10/11 |
| 20% | 5/6 |
| 25% | 4/5 |
| 33.33% | 3/4 |

## Markup-Discount Net Effect
**Profit% = M - D - MD/100**
| Markup | Discount | Net |
|--------|----------|-----|
| 20% | 10% | 8% profit |
| 25% | 20% | 0% |
| 30% | 10% | 17% profit |
| 40% | 20% | 12% profit |

## False Weight Profit
**Profit% = (Error/True-Error) × 100**
| Uses | Instead of | Profit% |
|------|------------|---------|
| 900g | 1kg | 11.11% |
| 950g | 1kg | 5.26% |
| 800g | 1kg | 25% |
''',
    tags: ['profit-loss', 'shortcuts'],
    estimatedReadTime: 4,
    createdAt: DateTime.now(),
  ),

  // ==================== INTEREST SHORTCUTS ====================

  StudyMaterial(
    id: 'bank_quant_s_interest',
    title: 'Interest Calculation Shortcuts',
    description: 'Quick SI and CI calculations',
    subjectId: 'quantitative_aptitude',
    topicId: 'simple_interest',
    type: StudyMaterialType.shortcut,
    content: '''
# Interest Calculation Shortcuts

## Quick SI Calculation
**SI = P × R × T / 100**
Trick: Cancel zeros first!
- SI on 5000 at 6% for 3 years
- = 50 × 6 × 3 = **900**

## CI-SI Difference (2 years)
**Diff = SI for 1 year × R/100**
Or: **Diff = PR²/10000**

## CI-SI Difference (3 years)
**Diff = PR²(300+R)/1000000**

## Doubling Time
| Rate | Years to Double |
|------|-----------------|
| 5% | 20 years |
| 10% | 10 years |
| 12% | 8.33 years |
| 15% | 6.67 years |
| 20% | 5 years |

## Rule of 72 (for CI)
**Years to double ≈ 72/Rate%**
- At 8%: 72/8 = 9 years
- At 12%: 72/12 = 6 years

## Amount Multipliers (CI)
| Rate | 2 Years | 3 Years |
|------|---------|---------|
| 10% | 1.21 | 1.331 |
| 20% | 1.44 | 1.728 |
| 25% | 1.5625 | 1.953 |
''',
    tags: ['interest', 'si', 'ci', 'shortcuts'],
    estimatedReadTime: 4,
    createdAt: DateTime.now(),
  ),

  // ==================== TIME & WORK SHORTCUTS ====================

  StudyMaterial(
    id: 'bank_quant_s_time_work',
    title: 'Time & Work LCM Method',
    description: 'Solve time-work problems instantly',
    subjectId: 'quantitative_aptitude',
    topicId: 'time_work',
    type: StudyMaterialType.shortcut,
    content: '''
# Time & Work - LCM Method

## The Method
1. Take LCM of all times = Total Work Units
2. Individual rate = Total Work / Individual Time
3. Combined rate = Sum of individual rates
4. Combined time = Total Work / Combined rate

## Example
A does in 12 days, B does in 15 days. Together?
1. LCM(12,15) = 60 units = Total work
2. A's rate = 60/12 = 5 units/day
3. B's rate = 60/15 = 4 units/day
4. Together = 9 units/day
5. Time = 60/9 = **6.67 days**

## Quick Ratios
| Times | Combined Time |
|-------|---------------|
| A, B days | AB/(A+B) |
| 2, 3 days | 6/5 = 1.2 |
| 3, 4 days | 12/7 = 1.71 |
| 4, 5 days | 20/9 = 2.22 |
| 5, 6 days | 30/11 = 2.73 |

## Efficiency Shortcut
If A is twice as efficient as B:
- A takes half the time of B
- In same time, A does double work
''',
    tags: ['time-work', 'lcm', 'shortcuts'],
    estimatedReadTime: 4,
    createdAt: DateTime.now(),
  ),

  StudyMaterial(
    id: 'bank_quant_s_pipes',
    title: 'Pipes & Cisterns Shortcuts',
    description: 'Quick pipe problem solutions',
    subjectId: 'quantitative_aptitude',
    topicId: 'time_work',
    type: StudyMaterialType.shortcut,
    content: '''
# Pipes & Cisterns Shortcuts

## Basic Concept
- Inlet = Positive rate
- Outlet = Negative rate

## Combined Time Formula
**One inlet (A), one outlet (B):**
Time = AB/(B-A) when A fills, B empties

## Quick Solutions
| Inlet | Outlet | Time to Fill |
|-------|--------|--------------|
| 4h | 6h | 12h |
| 6h | 8h | 24h |
| 3h | 4h | 12h |
| 5h | 10h | 10h |

## LCM Method for Pipes
Same as Time & Work:
1. LCM = Total capacity
2. Inlet rate = +ve
3. Outlet rate = -ve
4. Net rate = Inlet - Outlet
5. Time = Capacity / Net rate

## Leak Problems
If pipe fills in A hours, but with leak takes B hours:
**Leak empties in = AB/(B-A) hours**

## Alternating Pipes
If A fills for 1 min, B empties for 1 min alternately:
Calculate net work in 2 min cycle
''',
    tags: ['pipes', 'cisterns', 'shortcuts'],
    estimatedReadTime: 4,
    createdAt: DateTime.now(),
  ),

  // ==================== SPEED, TIME & DISTANCE SHORTCUTS ====================

  StudyMaterial(
    id: 'bank_quant_s_speed_basics',
    title: 'Speed Calculation Shortcuts',
    description: 'Quick speed time distance tricks',
    subjectId: 'quantitative_aptitude',
    topicId: 'speed_distance',
    type: StudyMaterialType.shortcut,
    content: '''
# Speed Calculation Shortcuts

## Unit Conversion Tricks
**km/h to m/s: Multiply by 5/18**
- 36 km/h = 36 × 5/18 = **10 m/s**
- 72 km/h = 72 × 5/18 = **20 m/s**
- 90 km/h = 90 × 5/18 = **25 m/s**

**Quick Table (Memorize)**
| km/h | m/s |
|------|-----|
| 18 | 5 |
| 36 | 10 |
| 54 | 15 |
| 72 | 20 |
| 90 | 25 |
| 108 | 30 |

## Average Speed Shortcut
**Same distance at speeds a and b:**
Avg = **2ab/(a+b)** (NOT (a+b)/2!)

| Speeds | Average |
|--------|---------|
| 20, 30 | 24 |
| 30, 60 | 40 |
| 40, 60 | 48 |
| 60, 90 | 72 |

## Meeting Point
From A and B with speeds S₁, S₂:
**Distance ratio = Speed ratio**
Meeting point divides in ratio S₁:S₂
''',
    tags: ['speed', 'conversion', 'shortcuts'],
    estimatedReadTime: 4,
    createdAt: DateTime.now(),
  ),

  StudyMaterial(
    id: 'bank_quant_s_trains',
    title: 'Train Problem Shortcuts',
    description: 'Solve train problems quickly',
    subjectId: 'quantitative_aptitude',
    topicId: 'speed_distance',
    type: StudyMaterialType.shortcut,
    content: '''
# Train Problem Shortcuts

## Distance Covered Quick Reference
| Crosses | Distance = |
|---------|------------|
| Pole/Man | Train length |
| Platform | Train + Platform |
| Another train | Train₁ + Train₂ |

## Relative Speed
| Direction | Speed |
|-----------|-------|
| Same | S₁ - S₂ |
| Opposite | S₁ + S₂ |

## Quick Formula
**Time = Total Distance / Relative Speed**

## Common Patterns
1. **Train crosses pole:**
   Time = Length / Speed

2. **Train crosses platform:**
   Time = (L_train + L_platform) / Speed

3. **Two trains cross (opposite):**
   Time = (L₁ + L₂) / (S₁ + S₂)

4. **Two trains cross (same direction):**
   Time = (L₁ + L₂) / (S₁ - S₂)

## Man on Platform
Train crosses man standing on platform:
Distance = Train length only
(Man's length negligible)
''',
    tags: ['trains', 'shortcuts'],
    estimatedReadTime: 4,
    createdAt: DateTime.now(),
  ),

  StudyMaterial(
    id: 'bank_quant_s_boats',
    title: 'Boats & Streams Shortcuts',
    description: 'Quick boat problem solutions',
    subjectId: 'quantitative_aptitude',
    topicId: 'speed_distance',
    type: StudyMaterialType.shortcut,
    content: '''
# Boats & Streams Shortcuts

## Speed Formulas
- **Downstream = B + S**
- **Upstream = B - S**
- **B = (D + U) / 2**
- **S = (D - U) / 2**

## Time Ratio
For same distance:
**T_upstream : T_downstream = (B+S) : (B-S)**

## Round Trip
**Total time = 2BD/(B² - S²)**
Or: Time = D/(B+S) + D/(B-S)

## Quick Pattern Recognition
| Downstream | Upstream | Boat Speed | Stream |
|------------|----------|------------|--------|
| 15 km/h | 5 km/h | 10 km/h | 5 km/h |
| 20 km/h | 12 km/h | 16 km/h | 4 km/h |
| 24 km/h | 18 km/h | 21 km/h | 3 km/h |

## Still Water Distance
If boat rows d km downstream and upstream in same total time:
Average speed = (B² - S²) / B
''',
    tags: ['boats', 'streams', 'shortcuts'],
    estimatedReadTime: 4,
    createdAt: DateTime.now(),
  ),

  // ==================== RATIO & PROPORTION SHORTCUTS ====================

  StudyMaterial(
    id: 'bank_quant_s_ratio',
    title: 'Ratio Problem Shortcuts',
    description: 'Quick ratio calculations',
    subjectId: 'quantitative_aptitude',
    topicId: 'ratio_proportion',
    type: StudyMaterialType.shortcut,
    content: '''
# Ratio Problem Shortcuts

## Combining Ratios
**a:b and b:c → a:b:c**
Make b same in both:
- 2:3 and 4:5 → 8:12:15

## Splitting by Ratio
If total = T in ratio a:b:c
- First part = T × a/(a+b+c)
- Second = T × b/(a+b+c)

## Age Ratio Changes
Present ratio a:b, after n years c:d
**Present ages = an/(c-a) × each ratio**

## Quick Calculations
| Ratio | First part of 100 |
|-------|-------------------|
| 1:1 | 50 |
| 1:3 | 25 |
| 2:3 | 40 |
| 3:4 | ~43 |
| 3:7 | 30 |

## Partnership Shortcuts
**Profit ∝ Capital × Time**
If A invests for 12 months, B for 6 months:
B's effective investment = B × 6/12 = B/2
''',
    tags: ['ratio', 'proportion', 'shortcuts'],
    estimatedReadTime: 4,
    createdAt: DateTime.now(),
  ),

  // ==================== MIXTURE & ALLIGATION SHORTCUTS ====================

  StudyMaterial(
    id: 'bank_quant_s_alligation',
    title: 'Alligation Criss-Cross Method',
    description: 'Solve mixture problems visually',
    subjectId: 'quantitative_aptitude',
    topicId: 'mixture_alligation',
    type: StudyMaterialType.shortcut,
    content: '''
# Alligation Criss-Cross Method

## The Rule
```
Cheaper(C)     Dearer(D)
    \\           /
     \\         /
      Mean(M)
     /         \\
    /           \\
 (D-M)        (M-C)
```
**Ratio = (D-M) : (M-C)**

## Example
Mix milk at Rs 20/L with milk at Rs 30/L to get Rs 24/L
- Ratio = (30-24) : (24-20) = 6:4 = **3:2**

## Replacement Formula
After n operations of removing x from V liters:
**Final = Original × (1 - x/V)ⁿ**

## Quick Solutions
| Remove % | After 1 | After 2 | After 3 |
|----------|---------|---------|---------|
| 10% | 90% | 81% | 72.9% |
| 20% | 80% | 64% | 51.2% |
| 25% | 75% | 56.25% | 42.2% |
| 50% | 50% | 25% | 12.5% |

## Water Addition
To reduce concentration from C₁ to C₂:
**Water to add = Quantity × (C₁ - C₂)/C₂**
''',
    tags: ['mixture', 'alligation', 'shortcuts'],
    estimatedReadTime: 4,
    createdAt: DateTime.now(),
  ),

  // ==================== AVERAGE SHORTCUTS ====================

  StudyMaterial(
    id: 'bank_quant_s_averages',
    title: 'Average Calculation Shortcuts',
    description: 'Quick average problem solutions',
    subjectId: 'quantitative_aptitude',
    topicId: 'averages',
    type: StudyMaterialType.shortcut,
    content: '''
# Average Calculation Shortcuts

## Deviation Method
Use assumed mean, add average of deviations
Avg of 45,52,48,47,50 (assume 48):
Deviations: -3,+4,0,-1,+2 = +2
Avg deviation = 2/5 = 0.4
Actual avg = 48 + 0.4 = **48.4**

## New Average Formulas
| Change | New Average |
|--------|-------------|
| Add x to n items | Old + (x-Old)/(n+1) |
| Remove x from n | Old + (Old-x)/(n-1) |
| Replace x by y | Old + (y-x)/n |

## Consecutive Numbers
**Average = Middle term**
- Avg of 3,4,5,6,7 = **5**
- Avg of 10,12,14,16,18 = **14**

## Weighted Average Position
If avg of group A is closer to combined avg:
Group A has MORE items

## Age-Related
When n years pass:
**Everyone's age ↑ n years**
**Average also ↑ n years**
**Difference stays same**
''',
    tags: ['averages', 'shortcuts'],
    estimatedReadTime: 4,
    createdAt: DateTime.now(),
  ),

  // ==================== AGE PROBLEM SHORTCUTS ====================

  StudyMaterial(
    id: 'bank_quant_s_ages',
    title: 'Age Problem Shortcuts',
    description: 'Solve age problems quickly',
    subjectId: 'quantitative_aptitude',
    topicId: 'ages',
    type: StudyMaterialType.shortcut,
    content: '''
# Age Problem Shortcuts

## Key Insight
**Age difference NEVER changes!**
If A is 5 years older than B now:
- 10 years ago: A was 5 years older
- 20 years hence: A will be 5 years older

## Ratio Method
Present ratio a:b becomes c:d after n years
**Present age = ratio unit × n/(ratio change)**

Example: Present 2:3, after 10 years 3:4
Ratio unit = 10/(1) = 10
Ages = 20 and 30

## Quick Patterns
| Scenario | Method |
|----------|--------|
| Sum & Difference given | (Sum+Diff)/2 = Elder |
| Ratio & Difference | Diff/(Ratio diff) = unit |
| Ratio changes | Years/(Ratio change) = unit |

## Father-Son Problems
If F = kS now, after n years F = mS
**n = S(k-m)/(m-1)**

## Combined Ages
Total of n people = Sum
One leaves, avg changes by x
**Leaver's age = Sum/n ± nx**
''',
    tags: ['ages', 'shortcuts'],
    estimatedReadTime: 4,
    createdAt: DateTime.now(),
  ),

  // ==================== P&C AND PROBABILITY SHORTCUTS ====================

  StudyMaterial(
    id: 'bank_quant_s_pnc',
    title: 'P&C Quick Tricks',
    description: 'Permutation combination shortcuts',
    subjectId: 'quantitative_aptitude',
    topicId: 'permutation_combination',
    type: StudyMaterialType.shortcut,
    content: '''
# P&C Quick Tricks

## When to Use What
- **Permutation**: Arrangement matters (positions, ranks)
- **Combination**: Selection only (teams, committees)

## Quick Values (Memorize)
| n! | Value |
|----|-------|
| 5! | 120 |
| 6! | 720 |
| 7! | 5040 |
| 8! | 40320 |

## nCr Quick Calc
**nC2 = n(n-1)/2**
**nC3 = n(n-1)(n-2)/6**

## Common Combinations
| Select | From | Ways |
|--------|------|------|
| 2 | 5 | 10 |
| 2 | 6 | 15 |
| 2 | 10 | 45 |
| 3 | 5 | 10 |
| 3 | 6 | 20 |
| 3 | 10 | 120 |

## Word Arrangement
With repeated letters:
**n! / (p! × q! × ...)**
MISSISSIPPI = 11!/(4!×4!×2!)
''',
    tags: ['permutation', 'combination', 'shortcuts'],
    estimatedReadTime: 4,
    createdAt: DateTime.now(),
  ),

  StudyMaterial(
    id: 'bank_quant_s_probability',
    title: 'Probability Quick Methods',
    description: 'Solve probability problems fast',
    subjectId: 'quantitative_aptitude',
    topicId: 'probability',
    type: StudyMaterialType.shortcut,
    content: '''
# Probability Quick Methods

## Total Outcomes (Memorize)
| Experiment | Outcomes |
|------------|----------|
| 1 coin | 2 |
| 2 coins | 4 |
| 3 coins | 8 |
| n coins | 2ⁿ |
| 1 die | 6 |
| 2 dice | 36 |
| Cards | 52 |

## Card Probabilities
| Event | Probability |
|-------|-------------|
| Any suit | 13/52 = 1/4 |
| Face card | 12/52 = 3/13 |
| Ace | 4/52 = 1/13 |
| Red card | 26/52 = 1/2 |
| King | 4/52 = 1/13 |

## Dice Probabilities
**Two dice sum:**
| Sum | Ways | Probability |
|-----|------|-------------|
| 2 | 1 | 1/36 |
| 7 | 6 | 6/36 = 1/6 |
| 12 | 1 | 1/36 |

## At Least One = 1 - None
P(at least one) = 1 - P(none)
Much easier for "at least" problems!
''',
    tags: ['probability', 'shortcuts'],
    estimatedReadTime: 4,
    createdAt: DateTime.now(),
  ),

  // ==================== DI SHORTCUTS ====================

  StudyMaterial(
    id: 'bank_quant_s_di',
    title: 'Data Interpretation Tricks',
    description: 'Quick DI calculation methods',
    subjectId: 'quantitative_aptitude',
    topicId: 'data_interpretation',
    type: StudyMaterialType.shortcut,
    content: '''
# Data Interpretation Tricks

## Percentage Approximations
| Fraction | Approx % |
|----------|----------|
| 1/6 | 17% |
| 1/7 | 14% |
| 1/8 | 12.5% |
| 1/9 | 11% |
| 2/7 | 28.5% |
| 3/7 | 43% |
| 4/9 | 44% |

## Pie Chart Degree → %
**Degree × 100/360 = %**
| Degrees | % |
|---------|---|
| 36° | 10% |
| 72° | 20% |
| 90° | 25% |
| 108° | 30% |
| 180° | 50% |

## Growth Rate Shortcut
**% Change = (Diff/Base) × 100**
Approximate: Round to nearest easy number

## Comparison Tricks
- Cross multiply to compare fractions
- Convert to common base for %
- Use approximations liberally

## Speed Techniques
1. Eliminate obviously wrong options
2. Round numbers to 10s/100s
3. Use benchmark comparisons
4. Last digit analysis for exact answers
''',
    tags: ['di', 'data-interpretation', 'shortcuts'],
    estimatedReadTime: 4,
    createdAt: DateTime.now(),
  ),

  // ==================== MENSURATION SHORTCUTS ====================

  StudyMaterial(
    id: 'bank_quant_s_mensuration',
    title: 'Mensuration Quick Formulas',
    description: 'Area volume calculation shortcuts',
    subjectId: 'quantitative_aptitude',
    topicId: 'mensuration',
    type: StudyMaterialType.shortcut,
    content: '''
# Mensuration Quick Shortcuts

## Square Diagonals
**Diagonal = Side × √2 ≈ Side × 1.414**
**Side = Diagonal / √2 ≈ Diagonal × 0.707**

## Circle Shortcuts
**Area ≈ 3.14 × r²**
**Circumference ≈ 6.28 × r**

Quick: If r doubles:
- Area becomes 4×
- Circumference becomes 2×

## Cube vs Sphere
Same surface area:
**Cube edge : Sphere radius = √(π/6) ≈ 0.72**

## Volume Ratios
Same height:
**Cylinder : Cone : Sphere = 3 : 1 : 2**

## Surface Area Patterns
| Shape | SA if edge/radius doubles |
|-------|---------------------------|
| Cube | 4× |
| Sphere | 4× |
| Cylinder | ~4× |

## Quick π Values
- π ≈ 22/7 = 3.14
- π² ≈ 10
- √π ≈ 1.77
''',
    tags: ['mensuration', 'shortcuts'],
    estimatedReadTime: 4,
    createdAt: DateTime.now(),
  ),

  // ==================== QUADRATIC SHORTCUTS ====================

  StudyMaterial(
    id: 'bank_quant_s_quadratic',
    title: 'Quadratic Equation Shortcuts',
    description: 'Quick quadratic solutions',
    subjectId: 'quantitative_aptitude',
    topicId: 'quadratic_equations',
    type: StudyMaterialType.shortcut,
    content: '''
# Quadratic Equation Shortcuts

## Factorization Method
For ax² + bx + c = 0:
Find two numbers that:
- Multiply to give a×c
- Add to give b

## Sign Rules for Roots
| Signs | Roots |
|-------|-------|
| +,+,+ | Both negative |
| +,-,+ | Both positive |
| +,+,- | One +ve, one -ve (|+ve| > |-ve|) |
| +,-,- | One +ve, one -ve (|-ve| > |+ve|) |

## Quick Root Check
**Sum = -b/a**
**Product = c/a**

## Comparing Roots
Without solving, compare:
| If | Relation |
|----|----------|
| Roots opposite signs | c/a < 0 |
| Both roots positive | -b/a > 0, c/a > 0 |
| Both roots negative | -b/a < 0, c/a > 0 |

## Common Factor Pairs
| Product | Pairs |
|---------|-------|
| 6 | (1,6), (2,3) |
| 12 | (1,12), (2,6), (3,4) |
| 24 | (1,24), (2,12), (3,8), (4,6) |
''',
    tags: ['quadratic', 'equations', 'shortcuts'],
    estimatedReadTime: 4,
    createdAt: DateTime.now(),
  ),

  // ==================== SERIES & SEQUENCE SHORTCUTS ====================

  StudyMaterial(
    id: 'bank_quant_s_series',
    title: 'Number Series Shortcuts',
    description: 'Identify series patterns quickly',
    subjectId: 'quantitative_aptitude',
    topicId: 'number_series',
    type: StudyMaterialType.shortcut,
    content: '''
# Number Series Shortcuts

## Pattern Recognition
1. **First check differences**
2. **Then check ratios**
3. **Then check squares/cubes**
4. **Finally, mixed patterns**

## Common Patterns
| Pattern | Example |
|---------|---------|
| +2,+2,+2 | 3,5,7,9,11 |
| ×2 | 2,4,8,16,32 |
| Squares | 1,4,9,16,25 |
| Cubes | 1,8,27,64,125 |
| Prime | 2,3,5,7,11,13 |

## Difference Patterns
| If differences are | Series type |
|-------------------|-------------|
| Constant | AP |
| In AP | Quadratic |
| In GP | Exponential |

## Quick Sums (Memorize)
| Sum | Value |
|-----|-------|
| 1 to 10 | 55 |
| 1 to 20 | 210 |
| 1 to 50 | 1275 |
| 1 to 100 | 5050 |

## Fibonacci Pattern
1, 1, 2, 3, 5, 8, 13, 21, 34...
Each = Sum of previous two
''',
    tags: ['series', 'sequence', 'shortcuts'],
    estimatedReadTime: 4,
    createdAt: DateTime.now(),
  ),

  // ==================== SIMPLIFICATION SHORTCUTS ====================

  StudyMaterial(
    id: 'bank_quant_s_simplification',
    title: 'BODMAS & Simplification Tricks',
    description: 'Quick simplification methods',
    subjectId: 'quantitative_aptitude',
    topicId: 'simplification',
    type: StudyMaterialType.shortcut,
    content: '''
# BODMAS & Simplification Tricks

## Order of Operations
**B**rackets → **O**rders → **D**ivision → **M**ultiplication → **A**ddition → **S**ubtraction

## Algebraic Identities (Use These!)
- (a+b)² = a² + 2ab + b²
- (a-b)² = a² - 2ab + b²
- a² - b² = (a+b)(a-b)
- a³ + b³ = (a+b)(a² - ab + b²)
- a³ - b³ = (a-b)(a² + ab + b²)

## Quick Squares
| Number | Square |
|--------|--------|
| 11 | 121 |
| 12 | 144 |
| 13 | 169 |
| 14 | 196 |
| 15 | 225 |
| 16 | 256 |
| 17 | 289 |
| 18 | 324 |
| 19 | 361 |
| 20 | 400 |
| 25 | 625 |

## Approximation Rules
- Round to nearest easy number
- Calculate, then adjust
- Use fractions when easier than decimals
''',
    tags: ['simplification', 'bodmas', 'shortcuts'],
    estimatedReadTime: 4,
    createdAt: DateTime.now(),
  ),

  StudyMaterial(
    id: 'bank_quant_s_surds',
    title: 'Surds & Indices Shortcuts',
    description: 'Quick surds calculations',
    subjectId: 'quantitative_aptitude',
    topicId: 'surds_indices',
    type: StudyMaterialType.shortcut,
    content: '''
# Surds & Indices Shortcuts

## Square Root Approximations
| √n | Approx |
|----|--------|
| √2 | 1.414 |
| √3 | 1.732 |
| √5 | 2.236 |
| √6 | 2.449 |
| √7 | 2.646 |
| √8 | 2.828 |
| √10 | 3.162 |

## Index Laws (Quick)
- aᵐ × aⁿ = aᵐ⁺ⁿ
- aᵐ ÷ aⁿ = aᵐ⁻ⁿ
- (aᵐ)ⁿ = aᵐⁿ
- a⁰ = 1
- a⁻ⁿ = 1/aⁿ

## Rationalization
Multiply by conjugate:
- 1/(√a + √b) × (√a - √b)/(√a - √b)
- = (√a - √b)/(a - b)

## Comparing Surds
To compare ⁿ√a and ᵐ√b:
Raise both to power LCM(n,m)

## Quick Powers of 2
| 2ⁿ | Value |
|----|-------|
| 2⁵ | 32 |
| 2⁶ | 64 |
| 2⁷ | 128 |
| 2⁸ | 256 |
| 2⁹ | 512 |
| 2¹⁰ | 1024 |
''',
    tags: ['surds', 'indices', 'shortcuts'],
    estimatedReadTime: 4,
    createdAt: DateTime.now(),
  ),
];
