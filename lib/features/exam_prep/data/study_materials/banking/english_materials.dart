import '../../../models/study_material_model.dart';

/// Banking English Language - Formulas & Shortcuts
/// Grammar rules and vocabulary for banking exams

final List<StudyMaterial> bankingEnglishMaterials = [
  // ==================== GRAMMAR RULES ====================
  
  StudyMaterial(
    id: 'bank_eng_f_tenses',
    title: 'Tense Rules & Usage',
    description: 'Complete guide to English tenses',
    subjectId: 'english_language',
    topicId: 'grammar',
    type: StudyMaterialType.formula,
    content: '''
# Tense Rules & Usage

## Simple Tenses

### Present Simple
**Structure**: Subject + V1 (s/es for 3rd person)
**Use**: Habits, facts, general truths
- He **works** in a bank.
- The sun **rises** in the east.

### Past Simple
**Structure**: Subject + V2
**Use**: Completed actions in past
- She **visited** Delhi last week.
- They **finished** the project.

### Future Simple
**Structure**: Subject + will + V1
**Use**: Predictions, spontaneous decisions
- I **will help** you tomorrow.
- It **will rain** tonight.

## Continuous Tenses

### Present Continuous
**Structure**: Subject + is/am/are + V-ing
**Use**: Actions happening now
- She **is reading** a book.

### Past Continuous
**Structure**: Subject + was/were + V-ing
**Use**: Ongoing action in past
- They **were playing** when I arrived.

### Future Continuous
**Structure**: Subject + will be + V-ing
**Use**: Ongoing action in future
- I **will be working** at 8 PM.

## Perfect Tenses

### Present Perfect
**Structure**: Subject + has/have + V3
**Use**: Past action with present relevance
- She **has completed** the work.

### Past Perfect
**Structure**: Subject + had + V3
**Use**: Action before another past action
- He **had left** before I arrived.

### Future Perfect
**Structure**: Subject + will have + V3
**Use**: Action completed before future time
- They **will have finished** by 5 PM.
''',
    tags: ['grammar', 'tenses'],
    estimatedReadTime: 6,
    createdAt: DateTime.now(),
  ),

  StudyMaterial(
    id: 'bank_eng_f_articles',
    title: 'Article Usage Rules',
    description: 'When to use A, An, The',
    subjectId: 'english_language',
    topicId: 'grammar',
    type: StudyMaterialType.formula,
    content: '''
# Article Usage Rules

## Indefinite Articles: A/An

### Use 'A' before:
- Consonant sounds: a book, a university, a European
- Note: Based on SOUND, not letter

### Use 'An' before:
- Vowel sounds: an apple, an hour, an MBA
- Note: "hour" starts with vowel sound

## Definite Article: The

### Use 'The' with:
| Category | Examples |
|----------|----------|
| Unique things | the sun, the moon, the earth |
| Superlatives | the best, the tallest |
| Ordinals | the first, the second |
| Known nouns | the book (we discussed) |
| Rivers/Oceans | the Ganges, the Pacific |
| Mountain ranges | the Himalayas |
| Countries (plural/republic) | the USA, the Netherlands |
| Newspapers | the Times of India |
| Religious books | the Bible, the Quran |

### No Article (Zero Article)
| Category | Examples |
|----------|----------|
| Meals | breakfast, lunch, dinner |
| Games | cricket, football |
| Languages | English, Hindi |
| Subjects | mathematics, history |
| Proper nouns | India, John |
| Abstract nouns (general) | love, honesty |

## Common Errors
❌ He is best student → ✓ He is **the** best student
❌ I had the breakfast → ✓ I had breakfast
❌ She speaks the English → ✓ She speaks English
''',
    tags: ['grammar', 'articles'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  StudyMaterial(
    id: 'bank_eng_f_prepositions',
    title: 'Preposition Rules',
    description: 'Correct preposition usage',
    subjectId: 'english_language',
    topicId: 'grammar',
    type: StudyMaterialType.formula,
    content: '''
# Preposition Rules

## Time Prepositions

### AT
- Specific time: at 5 o'clock, at noon
- Festivals: at Diwali, at Christmas
- Phrases: at night, at present

### ON
- Days: on Monday, on my birthday
- Dates: on 15th August
- Specific days: on a rainy day

### IN
- Months: in July, in December
- Years: in 2024
- Seasons: in summer, in winter
- Parts of day: in the morning, in the evening
- Longer periods: in a week, in an hour

## Place Prepositions

### AT
- Specific points: at the door, at the station
- Addresses: at 25 Park Street

### IN
- Enclosed spaces: in the room, in Delhi
- Countries: in India

### ON
- Surfaces: on the table, on the wall
- Floors: on the first floor

## Common Preposition Pairs
| Correct | Incorrect |
|---------|-----------|
| agree with (person) | agree to |
| agree to (proposal) | agree with |
| angry with (person) | angry on |
| angry at (thing) | angry upon |
| different from | different than |
| similar to | similar with |
| superior to | superior than |
| prefer X to Y | prefer X over Y |
| consist of | consist in |
| die of (disease) | die from |
''',
    tags: ['grammar', 'prepositions'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  StudyMaterial(
    id: 'bank_eng_f_subject_verb',
    title: 'Subject-Verb Agreement',
    description: 'Rules for correct agreement',
    subjectId: 'english_language',
    topicId: 'grammar',
    type: StudyMaterialType.formula,
    content: '''
# Subject-Verb Agreement

## Basic Rule
**Singular subject → Singular verb**
**Plural subject → Plural verb**

## Special Rules

### With 'And'
Two subjects joined by 'and' = Plural
- Ram **and** Shyam **are** friends.

**Exception**: Single concept
- Bread and butter **is** my breakfast.

### With 'Or/Nor'
Verb agrees with **nearest subject**
- Neither the teacher nor the students **are** present.
- Neither the students nor the teacher **is** present.

### Collective Nouns
Singular when acting as unit:
- The team **is** playing well.
Plural when acting individually:
- The team **are** fighting among themselves.

### Uncountable Nouns
Always singular:
- The news **is** good.
- The furniture **is** expensive.

### 'Each/Every/Either/Neither'
Always singular:
- Each of the boys **is** intelligent.
- Every student **has** a book.

### 'A number of' vs 'The number of'
- **A number of** students **are** absent. (Plural)
- **The number of** students **is** fifty. (Singular)

### Distances/Time/Money
Treated as singular:
- Ten kilometers **is** a long distance.
- Five years **is** a long time.
- Fifty rupees **is** enough.
''',
    tags: ['grammar', 'subject-verb'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  // ==================== ERROR SPOTTING ====================

  StudyMaterial(
    id: 'bank_eng_s_error_spotting',
    title: 'Error Spotting Shortcuts',
    description: 'Quick error identification techniques',
    subjectId: 'english_language',
    topicId: 'error_spotting',
    type: StudyMaterialType.shortcut,
    content: '''
# Error Spotting Shortcuts

## Quick Checklist
1. ☑ Subject-Verb agreement
2. ☑ Tense consistency
3. ☑ Article usage
4. ☑ Preposition choice
5. ☑ Pronoun reference
6. ☑ Parallelism
7. ☑ Modifier placement

## Common Error Patterns

### Singular/Plural Confusion
| Error | Correct |
|-------|---------|
| One of the boy | One of the boys |
| Each boys | Each boy |
| Furnitures | Furniture |
| Informations | Information |

### Wrong Preposition
| Error | Correct |
|-------|---------|
| Different than | Different from |
| Superior than | Superior to |
| Angry on him | Angry with him |
| Good in | Good at |

### Article Errors
| Error | Correct |
|-------|---------|
| He is honest man | He is an honest man |
| The honesty is virtue | Honesty is a virtue |
| I play the cricket | I play cricket |

### Tense Errors
| Error | Correct |
|-------|---------|
| He is working since morning | He has been working |
| I know him for years | I have known him |

## Scan Technique
1. Read entire sentence
2. Check verb forms first
3. Then articles & prepositions
4. Finally, word choice
''',
    tags: ['error-spotting', 'shortcuts'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  // ==================== VOCABULARY ====================

  StudyMaterial(
    id: 'bank_eng_f_synonyms',
    title: 'Important Synonyms',
    description: 'Frequently tested synonym pairs',
    subjectId: 'english_language',
    topicId: 'vocabulary',
    type: StudyMaterialType.formula,
    content: '''
# Important Synonyms

## A-E Words
| Word | Synonyms |
|------|----------|
| Abandon | Desert, Forsake, Relinquish |
| Abate | Decrease, Diminish, Reduce |
| Absurd | Ridiculous, Foolish, Silly |
| Acclaim | Praise, Applaud, Commend |
| Adversity | Hardship, Misfortune, Difficulty |
| Affluent | Wealthy, Rich, Prosperous |
| Ameliorate | Improve, Better, Enhance |
| Arduous | Difficult, Laborious, Strenuous |
| Augment | Increase, Enlarge, Expand |
| Benevolent | Kind, Generous, Charitable |
| Brevity | Shortness, Conciseness |
| Candid | Honest, Frank, Sincere |
| Colossal | Huge, Enormous, Gigantic |
| Contempt | Disdain, Scorn, Disrespect |
| Diligent | Hardworking, Industrious |
| Dubious | Doubtful, Uncertain, Skeptical |
| Eloquent | Articulate, Fluent, Expressive |
| Eminent | Distinguished, Famous, Renowned |
| Ephemeral | Short-lived, Transient, Fleeting |

## F-M Words
| Word | Synonyms |
|------|----------|
| Fallacy | Misconception, Error, Mistake |
| Frugal | Economical, Thrifty, Prudent |
| Gloomy | Depressing, Dismal, Dark |
| Gratitude | Thankfulness, Appreciation |
| Hamper | Hinder, Obstruct, Impede |
| Immense | Vast, Huge, Enormous |
| Inevitable | Unavoidable, Certain, Inescapable |
| Jubilant | Joyful, Elated, Ecstatic |
| Lethargic | Sluggish, Lazy, Inactive |
| Lucid | Clear, Understandable, Coherent |
| Meticulous | Careful, Thorough, Precise |
''',
    tags: ['vocabulary', 'synonyms'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  StudyMaterial(
    id: 'bank_eng_f_antonyms',
    title: 'Important Antonyms',
    description: 'Frequently tested antonym pairs',
    subjectId: 'english_language',
    topicId: 'vocabulary',
    type: StudyMaterialType.formula,
    content: '''
# Important Antonyms

## A-L Words
| Word | Antonym |
|------|---------|
| Abandon | Retain, Keep |
| Abundant | Scarce, Meager |
| Accept | Reject, Refuse |
| Advance | Retreat, Recede |
| Ancient | Modern, Contemporary |
| Artificial | Natural, Genuine |
| Attract | Repel, Deter |
| Benevolent | Malevolent, Cruel |
| Bless | Curse |
| Bold | Timid, Cowardly |
| Bright | Dim, Dull |
| Captivity | Freedom, Liberty |
| Conceal | Reveal, Expose |
| Confident | Doubtful, Uncertain |
| Create | Destroy, Demolish |
| Defend | Attack, Assault |
| Difficult | Easy, Simple |
| Expand | Contract, Shrink |
| Extravagant | Frugal, Thrifty |
| Flexible | Rigid, Inflexible |
| Generous | Stingy, Miserly |
| Harmony | Discord, Conflict |
| Humble | Arrogant, Proud |
| Include | Exclude, Omit |
| Inferior | Superior |
| Knowledge | Ignorance |
| Lazy | Active, Industrious |

## M-Z Words
| Word | Antonym |
|------|---------|
| Maximum | Minimum |
| Optimistic | Pessimistic |
| Permanent | Temporary |
| Praise | Criticize, Blame |
| Profit | Loss |
| Prosperity | Adversity |
| Qualified | Incompetent |
| Rational | Irrational |
| Reward | Punishment |
| Success | Failure |
| Transparent | Opaque |
| Victory | Defeat |
| Voluntary | Compulsory |
| Wisdom | Foolishness |
''',
    tags: ['vocabulary', 'antonyms'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  StudyMaterial(
    id: 'bank_eng_f_idioms',
    title: 'Important Idioms & Phrases',
    description: 'Common idioms for banking exams',
    subjectId: 'english_language',
    topicId: 'vocabulary',
    type: StudyMaterialType.formula,
    content: '''
# Important Idioms & Phrases

## A-H Idioms
| Idiom | Meaning |
|-------|---------|
| A bone of contention | Cause of dispute |
| A piece of cake | Very easy task |
| At the drop of a hat | Immediately |
| Back to square one | Start again from beginning |
| Bark up the wrong tree | Pursue wrong course |
| Beat around the bush | Avoid the main topic |
| Bite the bullet | Face difficulty bravely |
| Blessing in disguise | Benefit from misfortune |
| Break the ice | Start conversation |
| Burn the midnight oil | Work late into night |
| Call it a day | Stop working |
| Cry over spilt milk | Regret past actions |
| Cut corners | Do cheaply/poorly |
| Every cloud has silver lining | Hope in difficulty |
| Face the music | Accept consequences |
| Get out of hand | Go out of control |
| Hit the nail on the head | Exactly correct |
| Hold your horses | Be patient |

## I-Z Idioms
| Idiom | Meaning |
|-------|---------|
| In hot water | In trouble |
| Keep an eye on | Watch carefully |
| Kill two birds with one stone | Achieve two things at once |
| Let the cat out of bag | Reveal a secret |
| Miss the boat | Miss an opportunity |
| No stone unturned | Try every possibility |
| Once in a blue moon | Very rarely |
| Pull someone's leg | Joke with someone |
| Read between lines | Understand hidden meaning |
| See eye to eye | Agree completely |
| The ball is in your court | Your decision now |
| Through thick and thin | In all circumstances |
| Turn a blind eye | Ignore deliberately |
| Under the weather | Feeling unwell |
| When pigs fly | Never |
''',
    tags: ['vocabulary', 'idioms', 'phrases'],
    estimatedReadTime: 6,
    createdAt: DateTime.now(),
  ),

  // ==================== READING COMPREHENSION ====================

  StudyMaterial(
    id: 'bank_eng_s_rc_techniques',
    title: 'RC Quick Reading Techniques',
    description: 'Speed reading for comprehension',
    subjectId: 'english_language',
    topicId: 'reading_comprehension',
    type: StudyMaterialType.shortcut,
    content: '''
# RC Quick Reading Techniques

## Step 1: Skim First
- Read first & last paragraphs carefully
- Read first sentence of middle paragraphs
- Note topic and tone
- Time: 1-2 minutes

## Step 2: Read Questions
- Identify question types
- Note keywords to find
- Don't read options yet

## Step 3: Targeted Reading
- Go to relevant paragraph
- Read carefully around keywords
- Answer factual questions first

## Question Types & Strategies

### Main Idea
- Usually in first/last paragraph
- Look for repeated themes
- Answer: What's the passage ABOUT?

### Detail Questions
- Use keywords to locate
- Answer is stated directly
- Don't over-interpret

### Inference Questions
- "It can be inferred..."
- Slightly beyond stated facts
- Must be logically supported

### Vocabulary in Context
- Read sentence with word
- Substitute options
- Check if meaning fits

## Time Management
| Passage Length | Ideal Time |
|----------------|------------|
| 300-400 words | 8-10 min |
| 400-500 words | 10-12 min |
| 500+ words | 12-15 min |

## Elimination Technique
- Remove obviously wrong options
- Check extreme language (always/never)
- Compare remaining options
''',
    tags: ['reading-comprehension', 'shortcuts'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  // ==================== CLOZE TEST ====================

  StudyMaterial(
    id: 'bank_eng_s_cloze',
    title: 'Cloze Test Solving Strategy',
    description: 'Fill in the blanks techniques',
    subjectId: 'english_language',
    topicId: 'cloze_test',
    type: StudyMaterialType.shortcut,
    content: '''
# Cloze Test Solving Strategy

## Step-by-Step Approach

### Step 1: First Reading
- Read entire passage once
- Understand theme/context
- Don't fill blanks yet

### Step 2: Identify Blank Types
| Type | Look For |
|------|----------|
| Verb | Subject nearby, tense clues |
| Noun | Articles (a, an, the) |
| Adjective | Before nouns |
| Preposition | After verbs, nouns |
| Conjunction | Connecting ideas |

### Step 3: Fill Obvious Ones
- Start with clear context clues
- Build understanding progressively

### Step 4: Tackle Difficult Ones
- Use process of elimination
- Check grammatical fit
- Verify meaning fits context

## Common Patterns

### After Articles
- a/an → Singular countable noun
- the → Specific noun (any type)

### Preposition Clues
| Before | Usually |
|--------|---------|
| interested | in |
| good | at |
| afraid | of |
| different | from |

### Conjunction Clues
| Relation | Conjunctions |
|----------|--------------|
| Addition | and, also, moreover |
| Contrast | but, however, although |
| Cause | because, since, as |
| Result | so, therefore, hence |

## Verification
- Re-read completed passage
- Check flow and meaning
- Ensure grammar is correct
''',
    tags: ['cloze-test', 'shortcuts'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  // ==================== SENTENCE REARRANGEMENT ====================

  StudyMaterial(
    id: 'bank_eng_s_para_jumbles',
    title: 'Para Jumbles Strategy',
    description: 'Sentence arrangement techniques',
    subjectId: 'english_language',
    topicId: 'sentence_rearrangement',
    type: StudyMaterialType.shortcut,
    content: '''
# Para Jumbles Strategy

## Step 1: Find Opening Sentence
Usually contains:
- Introduction of topic/person
- General statement
- No pronouns referring back
- Full forms (not acronyms)

## Step 2: Find Closing Sentence
Usually contains:
- Conclusion or summary
- Final outcome
- "Therefore", "Thus", "Hence"

## Step 3: Create Links

### Pronoun Links
| Pronoun | Must Come After |
|---------|-----------------|
| He/She | Name of person |
| It | Noun being discussed |
| This/That | Specific reference |
| These/Those | Plural reference |

### Transition Words
| Word | Position |
|------|----------|
| However, But | After contrasting idea |
| Therefore, Hence | After cause |
| Moreover, Also | After related point |
| Finally, Lastly | Near end |

### Time/Sequence Markers
First → Then → Next → Finally
Initially → Subsequently → Eventually

## Step 4: Fixed Pairs
Look for sentences that MUST go together:
- Question → Answer
- Problem → Solution
- Cause → Effect

## Verification
- Read in proposed order
- Check logical flow
- Verify all links work
''',
    tags: ['para-jumbles', 'sentence-rearrangement', 'shortcuts'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  // ==================== SENTENCE IMPROVEMENT ====================

  StudyMaterial(
    id: 'bank_eng_s_sentence_improvement',
    title: 'Sentence Improvement Techniques',
    description: 'Fix sentence errors quickly',
    subjectId: 'english_language',
    topicId: 'sentence_improvement',
    type: StudyMaterialType.shortcut,
    content: '''
# Sentence Improvement Techniques

## Quick Check Points
1. Subject-verb agreement
2. Tense consistency
3. Correct preposition
4. Parallelism
5. Modifier placement
6. Redundancy

## Common Improvements

### Wordiness → Concise
| Wordy | Better |
|-------|--------|
| In spite of the fact that | Although |
| At this point in time | Now |
| Due to the fact that | Because |
| In the event that | If |
| For the purpose of | To |

### Active vs Passive
Prefer active when:
- Actor is important
- Sentence should be direct

Use passive when:
- Actor unknown/unimportant
- Object is focus

### Parallelism
❌ She likes reading, writing, and to swim
✓ She likes reading, writing, and swimming

### Dangling Modifiers
❌ Walking down the street, the building was seen
✓ Walking down the street, I saw the building

## Answer Selection
1. Identify the error first
2. Check if option fixes ONLY that error
3. Ensure no new errors introduced
4. "No improvement" if sentence is correct
''',
    tags: ['sentence-improvement', 'shortcuts'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  // ==================== ONE WORD SUBSTITUTION ====================

  StudyMaterial(
    id: 'bank_eng_f_one_word',
    title: 'One Word Substitutions',
    description: 'Important one-word substitutions',
    subjectId: 'english_language',
    topicId: 'vocabulary',
    type: StudyMaterialType.formula,
    content: '''
# One Word Substitutions

## People
| Description | One Word |
|-------------|----------|
| One who loves mankind | Philanthropist |
| One who hates mankind | Misanthrope |
| One who loves books | Bibliophile |
| One who can speak many languages | Polyglot |
| One who walks on foot | Pedestrian |
| One who believes in fate | Fatalist |
| One who doubts existence of God | Agnostic |
| One who doesn't believe in God | Atheist |
| One new to a profession | Novice |
| One who speaks less | Reticent |

## Actions/States
| Description | One Word |
|-------------|----------|
| Murder of one's father | Patricide |
| Murder of one's mother | Matricide |
| Murder of a king | Regicide |
| Murder of an infant | Infanticide |
| Killing oneself | Suicide |
| Act of killing entire race | Genocide |
| Govern by a few | Oligarchy |
| Govern by the rich | Plutocracy |
| Government by people | Democracy |
| Absolute rule by one person | Autocracy |

## Places/Things
| Description | One Word |
|-------------|----------|
| Place where birds are kept | Aviary |
| Place where bees are kept | Apiary |
| Place where animals are slaughtered | Abattoir |
| Study of stars | Astronomy |
| Study of languages | Philology |
| Fear of heights | Acrophobia |
| Fear of closed spaces | Claustrophobia |
| Fear of water | Hydrophobia |
| Words inscribed on tomb | Epitaph |
| Collection of poems | Anthology |
''',
    tags: ['vocabulary', 'one-word'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  // ==================== SPELLING RULES ====================

  StudyMaterial(
    id: 'bank_eng_f_spelling',
    title: 'Spelling Rules & Patterns',
    description: 'Common spelling rules',
    subjectId: 'english_language',
    topicId: 'spelling',
    type: StudyMaterialType.formula,
    content: '''
# Spelling Rules & Patterns

## IE vs EI Rule
**"I before E, except after C"**
- bel**ie**ve, ach**ie**ve, fr**ie**nd
- rec**ei**ve, dec**ei**ve, conc**ei**t

**Exceptions**: weird, seize, neither, leisure

## Doubling Consonants
Double final consonant when:
- One syllable + one vowel + one consonant
- run → running, stop → stopped

Don't double when:
- Two vowels before consonant: beat → beating
- Two consonants at end: help → helped

## Dropping E
Drop silent E before suffix starting with vowel:
- love → loving, make → making

Keep E before suffix starting with consonant:
- love → lovely, hope → hopeful

## Y to I
Change Y to I when:
- Y preceded by consonant: happy → happiness
- Adding suffix (not -ing): carry → carried

Keep Y when:
- Y preceded by vowel: play → played
- Adding -ing: carry → carrying

## Commonly Misspelled Words
| Wrong | Correct |
|-------|---------|
| accomodate | accommodate |
| occassion | occasion |
| occurence | occurrence |
| seperate | separate |
| definately | definitely |
| grammer | grammar |
| pronounciation | pronunciation |
| goverment | government |
| embarass | embarrass |
| millenium | millennium |
''',
    tags: ['spelling', 'grammar'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  // ==================== WORD FORMATION ====================

  StudyMaterial(
    id: 'bank_eng_f_word_formation',
    title: 'Word Formation Patterns',
    description: 'Prefixes, suffixes, and root words',
    subjectId: 'english_language',
    topicId: 'vocabulary',
    type: StudyMaterialType.formula,
    content: '''
# Word Formation Patterns

## Common Prefixes
| Prefix | Meaning | Example |
|--------|---------|---------|
| anti- | against | antisocial |
| auto- | self | autobiography |
| bi- | two | bicycle |
| co- | together | cooperate |
| dis- | not | disagree |
| ex- | former | ex-president |
| il-/im-/in-/ir- | not | illegal, impossible |
| mis- | wrongly | misunderstand |
| pre- | before | preview |
| re- | again | rewrite |
| sub- | under | submarine |
| super- | above | supernatural |
| trans- | across | transport |
| un- | not | unhappy |

## Common Suffixes
| Suffix | Part of Speech | Example |
|--------|----------------|---------|
| -able/-ible | Adjective | readable |
| -al | Adjective | musical |
| -ation/-tion | Noun | education |
| -er/-or | Noun (doer) | teacher |
| -ful | Adjective | beautiful |
| -ify | Verb | simplify |
| -ism | Noun | capitalism |
| -ist | Noun (person) | artist |
| -ity | Noun | activity |
| -ize | Verb | modernize |
| -less | Adjective | careless |
| -ly | Adverb | quickly |
| -ment | Noun | development |
| -ness | Noun | happiness |
| -ous | Adjective | famous |

## Word Families
| Noun | Verb | Adjective | Adverb |
|------|------|-----------|--------|
| beauty | beautify | beautiful | beautifully |
| success | succeed | successful | successfully |
| danger | endanger | dangerous | dangerously |
| strength | strengthen | strong | strongly |
''',
    tags: ['vocabulary', 'word-formation'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),
];
