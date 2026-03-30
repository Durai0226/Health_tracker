import '../../../exam_prep/models/study_material_model.dart';

/// Comprehensive study materials for CLAT (Common Law Admission Test)
final List<StudyMaterial> clatStudyMaterials = [
  // ==================== LEGAL REASONING ====================
  
  StudyMaterial(
    id: 'clat_legal_constitutional',
    title: 'Constitutional Law - Basics',
    description: 'Fundamental concepts of Indian Constitution for CLAT',
    subjectId: 'legal_reasoning',
    topicId: 'constitutional_law',
    type: StudyMaterialType.notes,
    content: '''
# Constitutional Law for CLAT

## Structure of Constitution

### Key Features
- Lengthiest written constitution
- Parliamentary form of government
- Federal with unitary features
- Independent judiciary
- Fundamental Rights & Duties

### Parts & Articles
- **Part III** (12-35): Fundamental Rights
- **Part IV** (36-51): DPSP
- **Part IVA** (51A): Fundamental Duties
- **Part V** (52-151): The Union
- **Part VI** (152-237): The States

## Fundamental Rights

### Right to Equality (14-18)
- **Article 14**: Equal protection of law
- **Article 15**: Non-discrimination
- **Article 16**: Equal opportunity in public employment
- **Article 17**: Abolition of untouchability
- **Article 18**: Abolition of titles

### Right to Freedom (19-22)
- **Article 19**: Six freedoms (speech, assembly, association, movement, residence, profession)
- **Article 20**: Protection against conviction
- **Article 21**: Right to life and liberty
- **Article 22**: Protection against arrest

### Right Against Exploitation (23-24)
- **Article 23**: Prohibition of traffic and forced labor
- **Article 24**: Prohibition of child labor

### Right to Religion (25-28)
- Freedom of conscience and religion
- Subject to public order, morality, health

### Cultural & Educational Rights (29-30)
- Protection of minorities
- Right to establish educational institutions

### Right to Constitutional Remedies (32)
- **Habeas Corpus**: Against illegal detention
- **Mandamus**: Command to perform duty
- **Prohibition**: Stop lower court proceeding
- **Certiorari**: Quash lower court decision
- **Quo Warranto**: Challenge to public office

## Directive Principles (DPSP)

### Nature
- Not enforceable by courts
- Fundamental in governance
- Directive to state

### Categories
**Socialistic:**
- Article 38: Social order for welfare
- Article 39: Equal pay, resources distribution
- Article 41: Right to work, education

**Gandhian:**
- Article 40: Panchayati Raj
- Article 43: Cottage industries
- Article 47: Prohibition

**Liberal:**
- Article 44: Uniform Civil Code
- Article 45: Early childhood care
- Article 48: Agriculture and animal husbandry

## Amendment Procedure (Article 368)

### Types
1. **Simple majority**: Ordinary laws
2. **Special majority**: 2/3 of members present + majority of total membership
3. **Special + Ratification**: Federal provisions (half states)

### Important Amendments
| Amendment | Provision |
|-----------|-----------|
| 1st | Land reforms, 9th Schedule |
| 42nd | Socialist, secular added |
| 44th | Right to property removed |
| 73rd | Panchayati Raj |
| 74th | Municipalities |
| 86th | Right to Education |

## Basic Structure Doctrine

### Kesavananda Bharati Case (1973)
- Parliament can amend any provision
- Cannot alter basic structure
- Judiciary determines basic structure

### Elements of Basic Structure
- Supremacy of Constitution
- Republican and democratic form
- Federal character
- Secular character
- Separation of powers
- Judicial review
- Rule of law
''',
    tags: ['legal reasoning', 'constitutional law', 'rights', 'clat'],
    estimatedReadTime: 16,
    createdAt: DateTime(2024, 1, 15),
    rating: 4.9,
  ),

  StudyMaterial(
    id: 'clat_legal_contracts',
    title: 'Law of Contracts - Essentials',
    description: 'Indian Contract Act fundamentals for CLAT',
    subjectId: 'legal_reasoning',
    topicId: 'contract_law',
    type: StudyMaterialType.notes,
    content: '''
# Law of Contracts for CLAT

## Introduction

### Definition (Section 2(h))
An agreement enforceable by law is a contract.
**Contract = Agreement + Enforceability**

### Agreement (Section 2(e))
Every promise and set of promises forming consideration for each other.
**Agreement = Offer + Acceptance**

## Essential Elements of Valid Contract

### 1. Offer & Acceptance
- Clear and definite offer
- Unconditional acceptance
- Communication required

### 2. Intention to Create Legal Relations
- Business agreements: Presumed
- Social/domestic agreements: Not presumed

### 3. Lawful Consideration (Section 2(d))
- Past, present, or future
- Need not be adequate
- Must be lawful

### 4. Capacity to Contract (Section 11)
- Age of majority (18 years)
- Sound mind
- Not disqualified by law

### 5. Free Consent (Section 14)
Consent is free when not caused by:
- **Coercion** (Section 15): Force or threat
- **Undue Influence** (Section 16): Dominant position
- **Fraud** (Section 17): Intentional deception
- **Misrepresentation** (Section 18): Innocent false statement
- **Mistake** (Section 20-22): Error of fact

### 6. Lawful Object (Section 23)
Object is unlawful if:
- Forbidden by law
- Against public policy
- Fraudulent
- Injurious to person or property
- Immoral

### 7. Not Expressly Declared Void

## Types of Contracts

### Based on Validity
| Type | Features |
|------|----------|
| Valid | All essentials satisfied |
| Void | Not enforceable (Section 2(j)) |
| Voidable | At option of one party (Section 2(i)) |
| Illegal | Against law |
| Unenforceable | Good but not enforceable |

### Based on Formation
- **Express**: Written or oral
- **Implied**: Inferred from conduct
- **Quasi**: Imposed by law

### Based on Performance
- **Executed**: Both parties performed
- **Executory**: To be performed
- **Unilateral**: One party's promise
- **Bilateral**: Mutual promises

## Void Agreements (Sections 24-30)

- Agreements without consideration
- In restraint of marriage
- In restraint of trade
- In restraint of legal proceedings
- Agreements with uncertain meaning
- Wagering agreements

## Discharge of Contract

### By Performance
- Actual performance
- Attempted performance (tender)

### By Agreement
- Novation: New contract
- Rescission: Cancellation
- Alteration: Change in terms
- Remission: Accept lesser performance

### By Impossibility
- Initial impossibility: Void ab initio
- Subsequent impossibility: Frustrated

### By Breach
- Anticipatory breach
- Actual breach

## Remedies for Breach

1. **Damages**: Monetary compensation
   - Ordinary damages
   - Special damages
   - Exemplary damages

2. **Specific Performance**: Actual performance

3. **Injunction**: Restraining order

4. **Quantum Meruit**: Reasonable remuneration
''',
    tags: ['contracts', 'legal reasoning', 'indian contract act', 'clat'],
    estimatedReadTime: 17,
    createdAt: DateTime(2024, 1, 16),
    rating: 4.8,
  ),

  StudyMaterial(
    id: 'clat_legal_torts',
    title: 'Law of Torts - Key Concepts',
    description: 'Tort law principles and cases for CLAT',
    subjectId: 'legal_reasoning',
    topicId: 'tort_law',
    type: StudyMaterialType.notes,
    content: '''
# Law of Torts for CLAT

## Introduction

### Definition
A tort is a civil wrong for which remedy is an action for unliquidated damages.

### Tort vs Crime vs Contract
| Aspect | Tort | Crime | Contract |
|--------|------|-------|----------|
| Nature | Civil wrong | Public wrong | Breach of agreement |
| Remedy | Damages | Punishment | Damages/Specific performance |
| Parties | Plaintiff vs Defendant | State vs Accused | Parties to contract |
| Consent | Not defense | Not defense | Basis |

## Essential Elements

### 1. Wrongful Act
- Commission or omission
- Violation of legal right

### 2. Legal Damage
- Injuria sine damno: Legal injury without actual damage (actionable)
- Damnum sine injuria: Damage without legal injury (not actionable)

### 3. Legal Remedy
- Ubi jus ibi remedium (Where there is a right, there is a remedy)

## Types of Torts

### Intentional Torts
- **Assault**: Threat of force
- **Battery**: Actual physical contact
- **False Imprisonment**: Unlawful restraint
- **Defamation**: Harming reputation
- **Trespass**: Interference with property

### Negligence
- **Duty of care**: Reasonable person standard
- **Breach of duty**: Failure to meet standard
- **Causation**: Cause-in-fact and proximate cause
- **Damages**: Actual harm

### Strict Liability
- Liability without fault
- Rylands v Fletcher rule
- Dangerous activities

## Important Principles

### Vicarious Liability
Liability for another's act
- Master-servant relationship
- Principal-agent relationship
- Within scope of employment

### Contributory Negligence
Plaintiff's own negligence contributing to harm
- Defense reducing damages

### Volenti Non Fit Injuria
Voluntary assumption of risk
- Complete defense

### Res Ipsa Loquitur
"The thing speaks for itself"
- Presumption of negligence

## Defamation

### Elements
1. False statement
2. Publication to third party
3. About plaintiff
4. Causing harm to reputation

### Types
- **Libel**: Written (actionable per se)
- **Slander**: Spoken (requires special damage)

### Defenses
- Truth (Justification)
- Fair comment
- Privilege (absolute/qualified)

## Nuisance

### Public Nuisance
- Affects community
- Criminal offense
- Action by Attorney General

### Private Nuisance
- Affects individual
- Interference with use of land
- Remedies: Damages, injunction, abatement

## Negligence

### Landmark Cases
- **Donoghue v Stevenson**: Duty of care, neighbor principle
- **M.C. Mehta v Union of India**: Absolute liability in India

### Professional Negligence
- Medical negligence
- Legal malpractice
- Standard of reasonable professional

## Remedies

### Judicial Remedies
- Damages (compensatory, punitive)
- Injunction (mandatory, prohibitory)
- Specific restitution

### Extra-Judicial Remedies
- Self-defense
- Abatement of nuisance
- Re-entry on land
''',
    tags: ['torts', 'legal reasoning', 'negligence', 'defamation', 'clat'],
    estimatedReadTime: 16,
    createdAt: DateTime(2024, 1, 17),
    rating: 4.8,
  ),

  // ==================== LOGICAL REASONING ====================
  
  StudyMaterial(
    id: 'clat_logical_reasoning',
    title: 'Logical Reasoning - Fundamentals',
    description: 'Arguments, syllogisms, critical reasoning',
    subjectId: 'logical_reasoning',
    topicId: 'logic_basics',
    type: StudyMaterialType.notes,
    content: '''
# Logical Reasoning for CLAT

## Arguments

### Structure
- **Premise**: Supporting statements
- **Conclusion**: Main claim
- **Assumption**: Unstated premise

### Types of Arguments

**Deductive:**
- If premises true, conclusion must be true
- General to specific
- Example: All men are mortal. Socrates is a man. Therefore, Socrates is mortal.

**Inductive:**
- Premises support but don't guarantee conclusion
- Specific to general
- Example: Every swan I've seen is white. Therefore, all swans are white.

## Syllogisms

### Standard Form
- Major premise (contains predicate)
- Minor premise (contains subject)
- Conclusion

### Validity Rules
1. Three terms only (major, minor, middle)
2. Middle term distributed at least once
3. Term distributed in conclusion must be distributed in premise
4. Two negatives give no conclusion
5. Two particulars give no conclusion
6. Negative premise → negative conclusion

### Common Forms
| Form | Example |
|------|---------|
| All A are B | Universal affirmative |
| No A are B | Universal negative |
| Some A are B | Particular affirmative |
| Some A are not B | Particular negative |

## Logical Fallacies

### Formal Fallacies
- **Affirming the consequent**: If A then B. B. Therefore A.
- **Denying the antecedent**: If A then B. Not A. Therefore not B.
- **Undistributed middle**: All A are B. All C are B. Therefore A are C.

### Informal Fallacies

**Appeal Fallacies:**
- Ad hominem: Attack on person
- Appeal to authority: Because expert says
- Appeal to emotion: Playing on feelings
- Appeal to ignorance: Can't disprove, so true

**Causal Fallacies:**
- Post hoc: After, therefore because of
- Slippery slope: Chain of unlikely consequences
- False cause: Wrong causal connection

**Structural Fallacies:**
- Straw man: Misrepresenting argument
- False dichotomy: Only two options
- Circular reasoning: Conclusion as premise
- Red herring: Irrelevant distraction

## Critical Reasoning

### Strengthen Questions
Find option that supports the conclusion.
- Additional evidence
- Ruling out alternatives
- Strengthening assumptions

### Weaken Questions
Find option that undermines the conclusion.
- Counter-evidence
- Alternative explanations
- Breaking causal links

### Assumption Questions
Find unstated but necessary premise.
- Test: Negation destroys argument
- Bridge between premise and conclusion

### Inference Questions
What must be true based on passage?
- Supported by evidence
- Not too broad/extreme

## Analytical Reasoning

### Approach
1. Read conditions carefully
2. Create visual representations
3. Make deductions
4. Test against options

### Common Types
- Linear arrangements
- Circular arrangements
- Grouping/Selection
- Matching/Pairing

## Tips for CLAT LR

1. Read passage/argument carefully
2. Identify conclusion first
3. Note explicit assumptions
4. Eliminate extreme options
5. Watch for scope shifts
6. Practice timed sections
''',
    tags: ['logical reasoning', 'arguments', 'syllogisms', 'fallacies', 'clat'],
    estimatedReadTime: 15,
    createdAt: DateTime(2024, 1, 18),
    rating: 4.9,
  ),

  // ==================== ENGLISH LANGUAGE ====================
  
  StudyMaterial(
    id: 'clat_english_comprehension',
    title: 'English - Reading Comprehension',
    description: 'RC strategies and vocabulary for CLAT',
    subjectId: 'english',
    topicId: 'reading_comprehension',
    type: StudyMaterialType.notes,
    content: '''
# English Language for CLAT

## Reading Comprehension

### Passage Types
1. **Legal passages**: Court judgments, legal articles
2. **Social issues**: Current affairs, policy debates
3. **Abstract/Philosophical**: Theories, concepts
4. **Historical**: Events, personalities

### Reading Strategy

**First Reading (3-4 minutes):**
- Skim for main idea
- Identify author's stance
- Note paragraph themes

**Question Analysis:**
- Identify question type
- Locate relevant portion
- Eliminate wrong answers

### Question Types

**Main Idea:**
- "The passage primarily discusses..."
- Focus on overall theme, not details

**Inference:**
- "It can be inferred that..."
- Must be logically derivable
- Not directly stated

**Vocabulary in Context:**
- "The word X most nearly means..."
- Consider context, not dictionary meaning

**Author's Tone:**
- Positive, negative, neutral
- Analytical, critical, supportive

**Specific Detail:**
- "According to the passage..."
- Answer directly stated

## Vocabulary Building

### Word Roots

| Root | Meaning | Words |
|------|---------|-------|
| Jur | Law | Jurisdiction, jury, perjury |
| Leg | Law | Legal, legislate, legitimate |
| Dict | Say | Verdict, dictate, predict |
| Jud | Judge | Judicial, prejudice, adjudicate |
| Cred | Believe | Credible, credence, incredulous |

### Legal Vocabulary

| Term | Meaning |
|------|---------|
| Acquittal | Found not guilty |
| Affidavit | Sworn written statement |
| Bail | Security for release |
| Contempt | Disrespect to court |
| Defamation | Harming reputation |
| Injunction | Court order to act/refrain |
| Litigation | Legal proceedings |
| Plaintiff | Person bringing suit |
| Precedent | Past decision as guide |
| Statute | Written law |

### Commonly Confused Words

| Word | Meaning |
|------|---------|
| Affect (v) | Influence |
| Effect (n) | Result |
| Allusion | Indirect reference |
| Illusion | False perception |
| Eminent | Distinguished |
| Imminent | About to happen |
| Immanent | Inherent |

## Grammar Essentials

### Subject-Verb Agreement
- Singular subject → Singular verb
- Collective nouns: Usually singular
- "Either...or": Agree with nearest

### Tense Consistency
- Past perfect for "earlier past"
- Maintain tense unless time shift

### Parallelism
- Similar ideas in similar form
- Lists should be consistent

### Modifiers
- Place near what they modify
- Avoid dangling modifiers

## Idioms & Phrases

| Idiom | Meaning |
|-------|---------|
| Prima facie | At first glance |
| Bona fide | Genuine, in good faith |
| De facto | In practice |
| De jure | By law |
| Ex parte | One-sided |
| Inter alia | Among other things |
| Ipso facto | By that very fact |
| Mala fide | In bad faith |
| Pro bono | Free service |
| Ultra vires | Beyond legal power |

## Tips for CLAT English

1. **Read actively**: Engage with content
2. **Build legal vocabulary**: Context-based learning
3. **Practice varied passages**: Different topics and styles
4. **Time management**: Don't spend too long on one question
5. **Eliminate options**: Use process of elimination
''',
    tags: ['english', 'reading comprehension', 'vocabulary', 'clat'],
    estimatedReadTime: 15,
    createdAt: DateTime(2024, 1, 19),
    rating: 4.8,
  ),

  // ==================== QUANTITATIVE TECHNIQUES ====================
  
  StudyMaterial(
    id: 'clat_quant_basics',
    title: 'Quantitative Techniques - Essentials',
    description: 'Basic math and data interpretation for CLAT',
    subjectId: 'quantitative',
    topicId: 'quant_basics',
    type: StudyMaterialType.notes,
    content: '''
# Quantitative Techniques for CLAT

## Number System

### Types of Numbers
- **Natural**: 1, 2, 3...
- **Whole**: 0, 1, 2, 3...
- **Integers**: ...-2, -1, 0, 1, 2...
- **Rational**: p/q (q ≠ 0)
- **Irrational**: Non-repeating decimals

### Divisibility Rules
| Number | Rule |
|--------|------|
| 2 | Last digit even |
| 3 | Sum of digits divisible by 3 |
| 4 | Last 2 digits divisible by 4 |
| 5 | Last digit 0 or 5 |
| 9 | Sum of digits divisible by 9 |
| 11 | Alternating sum divisible by 11 |

### HCF & LCM
- HCF × LCM = Product of numbers
- HCF: Common prime factors (lowest power)
- LCM: All prime factors (highest power)

## Percentages

### Basic Formula
Percentage = (Part/Whole) × 100

### Percentage Change
Change% = [(New - Old)/Old] × 100

### Successive Change
Net = a + b + (ab/100)%

### Quick Conversions
| Fraction | Percentage |
|----------|------------|
| 1/2 | 50% |
| 1/3 | 33.33% |
| 1/4 | 25% |
| 1/5 | 20% |
| 1/8 | 12.5% |

## Ratio & Proportion

### Ratio
a:b = a/b

### Proportion
a:b = c:d ⟹ a×d = b×c

### Componendo-Dividendo
If a/b = c/d, then (a+b)/(a-b) = (c+d)/(c-d)

## Averages

### Arithmetic Mean
Average = Sum of values / Number of values

### Weighted Average
= (w₁x₁ + w₂x₂ + ...)/(w₁ + w₂ + ...)

## Profit & Loss

### Formulas
- Profit = SP - CP
- Loss = CP - SP
- Profit% = (Profit/CP) × 100
- SP = CP × (1 + Profit%/100)
- SP = CP × (1 - Loss%/100)

## Simple & Compound Interest

### Simple Interest
SI = (P × R × T)/100
Amount = P + SI

### Compound Interest
A = P(1 + R/100)^T
CI = A - P

## Data Interpretation

### Tables
- Direct reading
- Calculations between rows/columns

### Bar Graphs
- Compare heights
- Calculate differences/ratios

### Line Graphs
- Identify trends
- Calculate changes

### Pie Charts
- Proportions add to 100%
- Convert to actual values

### Calculation Tips

**Approximation:**
- Round to convenient numbers
- Use fractions instead of decimals

**Quick Percentages:**
- 10%: Divide by 10
- 5%: Half of 10%
- 25%: Divide by 4
- 1%: Divide by 100

## CLAT Quant Strategy

1. **Focus on DI**: Major portion of CLAT quant
2. **Practice calculations**: Mental math
3. **Know shortcuts**: Save time
4. **Read carefully**: Avoid careless errors
5. **Manage time**: Don't get stuck on one question
''',
    tags: ['quantitative', 'math', 'data interpretation', 'clat'],
    estimatedReadTime: 14,
    createdAt: DateTime(2024, 1, 20),
    rating: 4.7,
  ),

  // ==================== CURRENT AFFAIRS & GK ====================
  
  StudyMaterial(
    id: 'clat_gk_static',
    title: 'General Knowledge - Static GK',
    description: 'Important facts for CLAT GK section',
    subjectId: 'general_knowledge',
    topicId: 'static_gk',
    type: StudyMaterialType.notes,
    content: '''
# General Knowledge for CLAT

## Indian Legal System

### Hierarchy of Courts
1. Supreme Court (Apex)
2. High Courts (State level)
3. District Courts
4. Subordinate Courts

### Supreme Court
- **Chief Justice**: Appointed by President
- **Judges**: Maximum 34 (including CJI)
- **Original Jurisdiction**: Article 131
- **Appellate Jurisdiction**: Articles 132-136
- **Advisory Jurisdiction**: Article 143

### High Courts
- One for each state (some shared)
- Chief Justice appointed by President
- Writ jurisdiction: Article 226

### Important Legal Bodies
| Body | Function |
|------|----------|
| Law Commission | Law reform recommendations |
| NALSA | Legal aid |
| Bar Council | Legal education, enrollment |
| NITI Aayog | Policy think tank |

## Constitutional Bodies

### Election Commission
- Article 324
- CEC and ECs (equal powers)
- Free and fair elections

### CAG (Comptroller & Auditor General)
- Article 148
- Audits government accounts
- Reports to Parliament

### UPSC
- Article 315
- Recruitment to civil services
- Advisory role

### Finance Commission
- Article 280
- Revenue distribution
- Every five years

## International Organizations

### United Nations
- Founded: 1945
- HQ: New York
- Agencies: UNESCO, UNICEF, WHO, WTO

### India in International Bodies
| Organization | Membership |
|--------------|------------|
| UN | Founding member (1945) |
| WTO | Member since 1995 |
| BRICS | Founding (2006) |
| G20 | Member |
| SCO | Member since 2017 |

## Important Awards

### National Awards
| Award | Field |
|-------|-------|
| Bharat Ratna | Highest civilian |
| Padma Awards | Various fields |
| Param Vir Chakra | Military (wartime) |
| Ashoka Chakra | Military (peacetime) |

### International Awards
| Award | Field |
|-------|-------|
| Nobel Prize | Various (Sweden/Norway) |
| Booker Prize | Literature |
| Pulitzer Prize | Journalism |
| Fields Medal | Mathematics |

## Indian Geography Facts

### Rivers
| River | Origin | Mouth |
|-------|--------|-------|
| Ganga | Gangotri | Bay of Bengal |
| Brahmaputra | Tibet | Bay of Bengal |
| Indus | Tibet | Arabian Sea |
| Narmada | Amarkantak | Arabian Sea |

### Highest/Longest
- Highest peak: K2 (8,611 m)
- Longest river: Ganga
- Largest state: Rajasthan
- Most populous: Uttar Pradesh

## Important Days

| Date | Day |
|------|-----|
| January 26 | Republic Day |
| August 15 | Independence Day |
| October 2 | Gandhi Jayanti |
| November 14 | Children's Day |
| November 26 | Constitution Day |

## Books & Authors

| Book | Author |
|------|--------|
| The Discovery of India | Jawaharlal Nehru |
| My Experiments with Truth | Mahatma Gandhi |
| Wings of Fire | APJ Abdul Kalam |
| Annihilation of Caste | B.R. Ambedkar |

## Tips for CLAT GK

1. **Read newspapers daily**: The Hindu, Indian Express
2. **Follow legal news**: Bar & Bench, LiveLaw
3. **Monthly magazines**: Pratiyogita Darpan
4. **Static GK**: Lucent's GK
5. **Current affairs**: Last 1 year focus
''',
    tags: ['general knowledge', 'current affairs', 'static gk', 'clat'],
    estimatedReadTime: 14,
    createdAt: DateTime(2024, 1, 21),
    rating: 4.7,
  ),
];
