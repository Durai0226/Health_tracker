/// UPSC & CLAT Exam Question Templates
/// UPSC (Civil Services), CLAT (Law) - Realistic exam pattern questions

import 'dart:math';
import '../../models/problem_solving_approach.dart';
import '../../models/solution_steps.dart';

class UPSCQuestionTemplates {
  static final _random = Random();

  // ==================== GENERAL STUDIES ====================

  /// Generate Indian Polity questions
  static List<EnhancedQuestion> generatePolity(int count) {
    final questions = <EnhancedQuestion>[];
    
    final polityQA = [
      ('Which Article deals with Right to Equality?', 'Article 14', ['Article 14', 'Article 19', 'Article 21', 'Article 32'], 'Article 14: Equality before law and equal protection'),
      ('The President is elected by:', 'Electoral College', ['Electoral College', 'Parliament only', 'State Legislatures', 'Direct election'], 'Electoral College of elected MPs and MLAs'),
      ('Which body resolves disputes between states?', 'Supreme Court', ['Supreme Court', 'President', 'Parliament', 'Governor'], 'Original jurisdiction of Supreme Court under Article 131'),
      ('How many Fundamental Rights are there?', '6', ['6', '7', '5', '8'], 'Right to Equality, Freedom, Against Exploitation, Religion, Cultural, Constitutional Remedies'),
      ('Who appoints the Chief Justice of India?', 'President', ['President', 'Prime Minister', 'Parliament', 'Collegium'], 'President appoints CJI on advice of outgoing CJI'),
      ('Rajya Sabha has how many members max?', '250', ['250', '245', '238', '260'], '238 elected + 12 nominated by President'),
      ('Which Amendment is called Mini Constitution?', '42nd', ['42nd', '44th', '73rd', '74th'], '42nd Amendment (1976) made extensive changes'),
      ('Governor is appointed by:', 'President', ['President', 'Chief Minister', 'Prime Minister', 'Chief Justice'], 'Article 155: Governor appointed by President'),
      ('DPSP are in which Part of Constitution?', 'Part IV', ['Part IV', 'Part III', 'Part V', 'Part VI'], 'Part IV: Articles 36-51 contain DPSP'),
      ('Writ of Habeas Corpus protects:', 'Personal liberty', ['Personal liberty', 'Property rights', 'Freedom of speech', 'Right to vote'], 'Habeas Corpus: produce the body - protects against illegal detention'),
    ];
    
    for (int i = 0; i < count; i++) {
      final data = polityQA[i % polityQA.length];
      final options = List<String>.from(data.$3);
      options.shuffle();
      
      questions.add(EnhancedQuestion(
        id: 'upsc_polity_${i + 1}',
        examType: 'upsc',
        subject: 'General Studies',
        topic: 'Indian Polity',
        question: data.$1,
        options: options,
        correctOptionIndex: options.indexOf(data.$2),
        explanation: data.$4,
        approach: const ProblemSolvingApproach(
          questionType: 'Indian Polity',
          conceptRequired: 'Constitution, Articles, Amendments, Institutions',
          howToRecognize: 'Questions about Constitution, Parliament, Courts',
          thinkingProcess: [
            'Step 1: Identify the constitutional provision',
            'Step 2: Recall the relevant Article/Part',
            'Step 3: Eliminate incorrect options',
            'Step 4: Verify with constitutional text',
          ],
          whatToLookFor: 'Article numbers, institution names, processes',
          commonPatterns: [
            'Fundamental Rights: Part III, Articles 12-35',
            'DPSP: Part IV, Articles 36-51',
            'Fundamental Duties: Part IVA, Article 51A',
          ],
          timeManagement: 'Spend 1 minute. Direct recall questions.',
          avoidMistakes: [
            'Don\'t confuse similar Articles',
            'Remember amendment numbers and years',
          ],
        ),
        difficulty: 'medium',
        marks: 2,
        negativeMarks: 0.66,
        timeInSeconds: 60,
        tags: ['polity', 'upsc', 'constitution', 'prelims'],
      ));
    }
    
    return questions;
  }

  /// Generate History questions
  static List<EnhancedQuestion> generateHistory(int count) {
    final questions = <EnhancedQuestion>[];
    
    final historyQA = [
      ('Who founded the Indian National Congress?', 'A.O. Hume', ['A.O. Hume', 'Dadabhai Naoroji', 'W.C. Bonnerjee', 'Surendranath Banerjee'], 'Allan Octavian Hume founded INC in 1885'),
      ('The Battle of Plassey was fought in:', '1757', ['1757', '1764', '1857', '1761'], 'Battle of Plassey: 1757, Robert Clive defeated Siraj-ud-Daulah'),
      ('Who gave the slogan "Do or Die"?', 'Mahatma Gandhi', ['Mahatma Gandhi', 'Subhas Chandra Bose', 'Jawaharlal Nehru', 'Bal Gangadhar Tilak'], 'Gandhi gave this call during Quit India Movement 1942'),
      ('Quit India Movement was launched in:', '1942', ['1942', '1940', '1930', '1920'], 'August 8, 1942 at Bombay session'),
      ('The Indus Valley Civilization was discovered in:', '1921', ['1921', '1920', '1922', '1930'], 'Harappa discovered by Daya Ram Sahni in 1921'),
      ('Who was the first Governor-General of India?', 'Warren Hastings', ['Warren Hastings', 'Lord Cornwallis', 'Lord Wellesley', 'William Bentinck'], 'Warren Hastings: 1772-1785'),
      ('The Sepoy Mutiny occurred in:', '1857', ['1857', '1858', '1859', '1856'], 'First War of Independence started May 10, 1857'),
      ('Who wrote "Discovery of India"?', 'Jawaharlal Nehru', ['Jawaharlal Nehru', 'Mahatma Gandhi', 'Rabindranath Tagore', 'B.R. Ambedkar'], 'Nehru wrote it in Ahmednagar Fort prison 1944'),
      ('Jallianwala Bagh massacre occurred in:', '1919', ['1919', '1920', '1921', '1918'], 'April 13, 1919 in Amritsar by General Dyer'),
      ('Who started the Home Rule Movement?', 'Annie Besant and Tilak', ['Annie Besant and Tilak', 'Gandhi', 'Nehru', 'Gokhale'], 'Two Home Rule Leagues in 1916'),
    ];
    
    for (int i = 0; i < count; i++) {
      final data = historyQA[i % historyQA.length];
      final options = List<String>.from(data.$3);
      options.shuffle();
      
      questions.add(EnhancedQuestion(
        id: 'upsc_hist_${i + 1}',
        examType: 'upsc',
        subject: 'General Studies',
        topic: 'History',
        question: data.$1,
        options: options,
        correctOptionIndex: options.indexOf(data.$2),
        explanation: data.$4,
        difficulty: 'medium',
        marks: 2,
        negativeMarks: 0.66,
        timeInSeconds: 60,
        tags: ['history', 'upsc', 'modern-india', 'freedom-struggle'],
      ));
    }
    
    return questions;
  }

  /// Generate Geography questions
  static List<EnhancedQuestion> generateGeography(int count) {
    final questions = <EnhancedQuestion>[];
    
    final geoQA = [
      ('The longest river in India is:', 'Ganga', ['Ganga', 'Brahmaputra', 'Godavari', 'Krishna'], 'Ganga: 2525 km in India'),
      ('Which soil is best for cotton cultivation?', 'Black soil', ['Black soil', 'Red soil', 'Alluvial soil', 'Laterite soil'], 'Black/Regur soil retains moisture, rich in calcium'),
      ('The Western Ghats are also known as:', 'Sahyadri', ['Sahyadri', 'Nilgiri', 'Vindhya', 'Satpura'], 'Sahyadri runs along west coast'),
      ('Which state has longest coastline?', 'Gujarat', ['Gujarat', 'Maharashtra', 'Tamil Nadu', 'Andhra Pradesh'], 'Gujarat: 1600 km coastline'),
      ('Chilika Lake is located in:', 'Odisha', ['Odisha', 'Andhra Pradesh', 'West Bengal', 'Tamil Nadu'], 'Chilika: largest brackish water lagoon in Asia'),
      ('Monsoon arrives in India from:', 'South-West', ['South-West', 'North-East', 'North-West', 'South-East'], 'SW Monsoon brings rain June-September'),
      ('The highest peak in India is:', 'Kanchenjunga', ['Kanchenjunga', 'Nanda Devi', 'K2', 'Godwin Austen'], 'K2 is in PoK; Kanchenjunga (8586m) highest in India proper'),
      ('Which river is called "Sorrow of Bengal"?', 'Damodar', ['Damodar', 'Hooghly', 'Brahmaputra', 'Ganga'], 'Damodar caused frequent floods'),
      ('Thar Desert is located in:', 'Rajasthan', ['Rajasthan', 'Gujarat', 'Haryana', 'Punjab'], 'Great Indian Desert mainly in Rajasthan'),
      ('Which is the largest state by area?', 'Rajasthan', ['Rajasthan', 'Madhya Pradesh', 'Maharashtra', 'Uttar Pradesh'], 'Rajasthan: 342,239 sq km'),
    ];
    
    for (int i = 0; i < count; i++) {
      final data = geoQA[i % geoQA.length];
      final options = List<String>.from(data.$3);
      options.shuffle();
      
      questions.add(EnhancedQuestion(
        id: 'upsc_geo_${i + 1}',
        examType: 'upsc',
        subject: 'General Studies',
        topic: 'Geography',
        question: data.$1,
        options: options,
        correctOptionIndex: options.indexOf(data.$2),
        explanation: data.$4,
        difficulty: 'medium',
        marks: 2,
        negativeMarks: 0.66,
        timeInSeconds: 60,
        tags: ['geography', 'upsc', 'indian-geography'],
      ));
    }
    
    return questions;
  }

  /// Generate Economy questions
  static List<EnhancedQuestion> generateEconomy(int count) {
    final questions = <EnhancedQuestion>[];
    
    final econQA = [
      ('RBI was established in:', '1935', ['1935', '1947', '1949', '1950'], 'RBI established April 1, 1935'),
      ('Which bank is called Banker\'s Bank?', 'RBI', ['RBI', 'SBI', 'NABARD', 'IDBI'], 'RBI acts as banker to commercial banks'),
      ('GST was implemented from:', 'July 1, 2017', ['July 1, 2017', 'April 1, 2017', 'January 1, 2017', 'July 1, 2016'], 'GST launched midnight June 30-July 1, 2017'),
      ('NITI Aayog replaced:', 'Planning Commission', ['Planning Commission', 'Finance Commission', 'NABARD', 'SEBI'], 'NITI Aayog formed January 1, 2015'),
      ('Fiscal deficit means:', 'Total expenditure minus total receipts excluding borrowing', ['Total expenditure minus total receipts excluding borrowing', 'Total exports minus imports', 'Government debt', 'Budget deficit'], 'Fiscal deficit = borrowing requirement'),
      ('Who presents Union Budget?', 'Finance Minister', ['Finance Minister', 'Prime Minister', 'RBI Governor', 'President'], 'FM presents budget to Parliament'),
      ('SEBI was established in:', '1988', ['1988', '1992', '1990', '1995'], 'SEBI established 1988, statutory body 1992'),
      ('Indian currency is:', 'Managed float', ['Managed float', 'Fixed', 'Free float', 'Pegged'], 'RBI manages rupee within a band'),
      ('GDP measures:', 'Total value of goods and services', ['Total value of goods and services', 'Total exports', 'Government spending', 'Tax collection'], 'GDP = C + I + G + (X-M)'),
      ('Repo rate is set by:', 'RBI', ['RBI', 'Finance Ministry', 'SEBI', 'NABARD'], 'MPC of RBI decides repo rate'),
    ];
    
    for (int i = 0; i < count; i++) {
      final data = econQA[i % econQA.length];
      final options = List<String>.from(data.$3);
      options.shuffle();
      
      questions.add(EnhancedQuestion(
        id: 'upsc_econ_${i + 1}',
        examType: 'upsc',
        subject: 'General Studies',
        topic: 'Economy',
        question: data.$1,
        options: options,
        correctOptionIndex: options.indexOf(data.$2),
        explanation: data.$4,
        difficulty: 'medium',
        marks: 2,
        negativeMarks: 0.66,
        timeInSeconds: 60,
        tags: ['economy', 'upsc', 'banking', 'fiscal-policy'],
      ));
    }
    
    return questions;
  }

  /// Generate Science & Technology questions
  static List<EnhancedQuestion> generateScienceTech(int count) {
    final questions = <EnhancedQuestion>[];
    
    final stQA = [
      ('ISRO was established in:', '1969', ['1969', '1972', '1975', '1962'], 'ISRO formed August 15, 1969'),
      ('India\'s first satellite was:', 'Aryabhata', ['Aryabhata', 'Bhaskara', 'INSAT', 'Rohini'], 'Aryabhata launched April 19, 1975'),
      ('CRISPR is used for:', 'Gene editing', ['Gene editing', 'Rocket propulsion', 'Solar energy', 'Encryption'], 'CRISPR-Cas9 is a gene editing tool'),
      ('5G operates in which frequency?', 'Millimeter wave', ['Millimeter wave', 'Microwave', 'Radio wave', 'X-ray'], '5G uses sub-6GHz and mmWave bands'),
      ('Chandrayaan-3 landed on Moon in:', '2023', ['2023', '2022', '2024', '2021'], 'August 23, 2023 - South Pole landing'),
      ('Which fuel is used in nuclear reactors?', 'Uranium', ['Uranium', 'Coal', 'Hydrogen', 'Helium'], 'U-235 undergoes fission'),
      ('AI stands for:', 'Artificial Intelligence', ['Artificial Intelligence', 'Automated Input', 'Advanced Interface', 'Audio Integration'], 'AI simulates human intelligence'),
      ('Blockchain is the technology behind:', 'Cryptocurrency', ['Cryptocurrency', 'Cloud computing', 'Social media', 'GPS'], 'Distributed ledger technology'),
      ('India\'s indigenous navigation system:', 'NavIC', ['NavIC', 'GPS', 'GLONASS', 'Galileo'], 'NavIC (IRNSS) - Indian Regional Navigation'),
      ('Gaganyaan is:', 'India\'s manned space mission', ['India\'s manned space mission', 'Mars mission', 'Moon rover', 'Communication satellite'], 'ISRO\'s human spaceflight program'),
    ];
    
    for (int i = 0; i < count; i++) {
      final data = stQA[i % stQA.length];
      final options = List<String>.from(data.$3);
      options.shuffle();
      
      questions.add(EnhancedQuestion(
        id: 'upsc_st_${i + 1}',
        examType: 'upsc',
        subject: 'General Studies',
        topic: 'Science & Technology',
        question: data.$1,
        options: options,
        correctOptionIndex: options.indexOf(data.$2),
        explanation: data.$4,
        difficulty: 'medium',
        marks: 2,
        negativeMarks: 0.66,
        timeInSeconds: 60,
        tags: ['science', 'technology', 'upsc', 'isro', 'current-affairs'],
      ));
    }
    
    return questions;
  }

  /// Generate all UPSC questions
  static List<EnhancedQuestion> generateAllQuestions() {
    return [
      ...generatePolity(600),
      ...generateHistory(500),
      ...generateGeography(500),
      ...generateEconomy(500),
      ...generateScienceTech(400),
    ];
  }

  static int get totalQuestionCount => 2500;
}

// ==================== CLAT ====================

class CLATQuestionTemplates {
  static final _random = Random();

  /// Generate Legal Reasoning questions
  static List<EnhancedQuestion> generateLegalReasoning(int count) {
    final questions = <EnhancedQuestion>[];
    
    final legalQA = [
      (
        'Principle: A person is liable for negligence if they fail to take reasonable care.\nFacts: A doctor operated without proper sterilization and the patient got infected.\nDecision:',
        'Doctor is liable for negligence',
        ['Doctor is liable for negligence', 'Doctor is not liable', 'Hospital is liable', 'Patient assumed risk'],
        'Failure to sterilize is failure of reasonable care'
      ),
      (
        'Principle: No one can be a judge in their own case.\nFacts: A judge heard a case in which his son was the plaintiff.\nDecision:',
        'Judgment is voidable due to bias',
        ['Judgment is voidable due to bias', 'Judgment is valid', 'Judge can decide', 'Case must be dismissed'],
        'Principle of natural justice - nemo judex in causa sua'
      ),
      (
        'Principle: An agreement without consideration is void.\nFacts: X promises to give Y Rs 10,000 without Y giving anything in return.\nDecision:',
        'Agreement is void',
        ['Agreement is void', 'Agreement is valid', 'Y must pay', 'X must pay damages'],
        'Section 25 of Contract Act requires consideration'
      ),
      (
        'Principle: Right to privacy is a fundamental right.\nFacts: Police conducted a search without warrant at midnight.\nDecision:',
        'Search violated fundamental rights',
        ['Search violated fundamental rights', 'Search is valid', 'Police have absolute power', 'Midnight searches are allowed'],
        'Warrant required unless exceptions apply'
      ),
      (
        'Principle: A minor cannot enter into a contract.\nFacts: A 17-year-old purchased a car on installment.\nDecision:',
        'Contract is void ab initio',
        ['Contract is void ab initio', 'Contract is valid', 'Minor must pay', 'Parents must pay'],
        'Minor\'s agreement is void from beginning'
      ),
    ];
    
    for (int i = 0; i < count; i++) {
      final data = legalQA[i % legalQA.length];
      final options = List<String>.from(data.$3);
      options.shuffle();
      
      questions.add(EnhancedQuestion(
        id: 'clat_legal_${i + 1}',
        examType: 'clat',
        subject: 'Legal Reasoning',
        topic: 'Legal Principles',
        question: data.$1,
        options: options,
        correctOptionIndex: options.indexOf(data.$2),
        explanation: data.$4,
        approach: const ProblemSolvingApproach(
          questionType: 'Legal Reasoning',
          conceptRequired: 'Legal principles, application to facts',
          howToRecognize: 'Principle + Facts + Question format',
          thinkingProcess: [
            'Step 1: Understand the legal principle',
            'Step 2: Analyze the facts given',
            'Step 3: Apply principle to facts',
            'Step 4: Derive the logical conclusion',
          ],
          whatToLookFor: 'Key words in principle, relevant facts',
          commonPatterns: [
            'Negligence requires duty + breach + damage',
            'Contract requires offer + acceptance + consideration',
            'Natural justice principles',
          ],
          timeManagement: 'Spend 2-3 minutes. Read principle carefully.',
          avoidMistakes: [
            'Don\'t add facts not given',
            'Stick to the principle provided',
            'Don\'t use external legal knowledge',
          ],
        ),
        difficulty: 'hard',
        marks: 1,
        negativeMarks: 0.25,
        timeInSeconds: 150,
        tags: ['legal-reasoning', 'clat', 'law'],
      ));
    }
    
    return questions;
  }

  /// Generate Legal Knowledge questions
  static List<EnhancedQuestion> generateLegalKnowledge(int count) {
    final questions = <EnhancedQuestion>[];
    
    final lkQA = [
      ('Which Article guarantees Right to Life?', 'Article 21', ['Article 21', 'Article 14', 'Article 19', 'Article 22'], 'Article 21: Protection of life and personal liberty'),
      ('Supreme Court has how many judges including CJI?', '34', ['34', '31', '26', '33'], 'Current strength is 34 (1 CJI + 33 judges)'),
      ('Writ jurisdiction of High Court is under:', 'Article 226', ['Article 226', 'Article 32', 'Article 136', 'Article 227'], 'Article 226: HC writs, Article 32: SC writs'),
      ('IPC came into force in:', '1862', ['1862', '1860', '1947', '1950'], 'IPC enacted 1860, came into force January 1, 1862'),
      ('Who can pardon death sentence?', 'President', ['President', 'Supreme Court', 'Governor', 'Prime Minister'], 'Article 72: President\'s pardoning power'),
      ('PIL stands for:', 'Public Interest Litigation', ['Public Interest Litigation', 'Private Interest Law', 'Public International Law', 'Primary Interest Litigation'], 'PIL allows any person to file for public cause'),
      ('Consumer Protection Act 2019 replaced:', 'Consumer Protection Act 1986', ['Consumer Protection Act 1986', 'Contract Act', 'Sale of Goods Act', 'Competition Act'], 'CPA 2019 replaced 1986 Act'),
      ('RTI Act was enacted in:', '2005', ['2005', '2000', '2002', '2010'], 'Right to Information Act, 2005'),
      ('Which court handles cyber crimes?', 'Designated Cyber Appellate Tribunal', ['Designated Cyber Appellate Tribunal', 'Family Court', 'Labour Court', 'Green Tribunal'], 'IT Act provisions for cyber crimes'),
      ('Minimum age for Lok Sabha membership:', '25 years', ['25 years', '30 years', '21 years', '35 years'], 'Article 84: 25 for LS, 30 for RS'),
    ];
    
    for (int i = 0; i < count; i++) {
      final data = lkQA[i % lkQA.length];
      final options = List<String>.from(data.$3);
      options.shuffle();
      
      questions.add(EnhancedQuestion(
        id: 'clat_lk_${i + 1}',
        examType: 'clat',
        subject: 'Legal Knowledge',
        topic: 'Static GK',
        question: data.$1,
        options: options,
        correctOptionIndex: options.indexOf(data.$2),
        explanation: data.$4,
        difficulty: 'medium',
        marks: 1,
        negativeMarks: 0.25,
        timeInSeconds: 45,
        tags: ['legal-knowledge', 'clat', 'constitution', 'acts'],
      ));
    }
    
    return questions;
  }

  /// Generate Logical Reasoning (CLAT style)
  static List<EnhancedQuestion> generateLogicalReasoning(int count) {
    final questions = <EnhancedQuestion>[];
    
    final lrQA = [
      ('If all lawyers are intelligent and some intelligent people are rich, then:', 'Some lawyers may be rich', ['Some lawyers may be rich', 'All lawyers are rich', 'No lawyer is rich', 'All rich are lawyers'], 'Only possibility, not certainty'),
      ('Statement: Should education be made free? Arguments: Yes - everyone has right to education. No - quality will suffer.', 'Both arguments are strong', ['Both arguments are strong', 'Only Yes is strong', 'Only No is strong', 'Neither is strong'], 'Both present valid perspectives'),
      ('A is father of B. B is mother of C. D is brother of A. How is D related to C?', 'Grand uncle', ['Grand uncle', 'Uncle', 'Grandfather', 'Father'], 'D is A\'s brother, A is grandfather, so D is grand uncle'),
      ('If WATER is coded as YCVGT, then FIRE is coded as:', 'HKTG', ['HKTG', 'GJSF', 'IKTE', 'FJTG'], '+2 coding pattern'),
      ('Find the odd one out: Judge, Lawyer, Court, Plaintiff, Cricket', 'Cricket', ['Cricket', 'Judge', 'Court', 'Plaintiff'], 'Cricket is not related to legal system'),
    ];
    
    for (int i = 0; i < count; i++) {
      final data = lrQA[i % lrQA.length];
      final options = List<String>.from(data.$3);
      options.shuffle();
      
      questions.add(EnhancedQuestion(
        id: 'clat_lr_${i + 1}',
        examType: 'clat',
        subject: 'Logical Reasoning',
        topic: 'Critical Reasoning',
        question: data.$1,
        options: options,
        correctOptionIndex: options.indexOf(data.$2),
        explanation: data.$4,
        difficulty: 'medium',
        marks: 1,
        negativeMarks: 0.25,
        timeInSeconds: 90,
        tags: ['logical-reasoning', 'clat', 'critical-thinking'],
      ));
    }
    
    return questions;
  }

  /// Generate English Comprehension (CLAT style)
  static List<EnhancedQuestion> generateEnglishComprehension(int count) {
    final questions = <EnhancedQuestion>[];
    
    final passages = [
      (
        '''The rule of law is a fundamental principle that ensures equality before the law and prevents 
arbitrary exercise of power. In a democracy, no individual, including those in positions of 
authority, is above the law. This principle forms the bedrock of constitutional governance and 
protects citizens from tyranny.''',
        'Rule of Law',
        [
          ('What does the rule of law prevent?', 'Arbitrary exercise of power', 
           ['Arbitrary exercise of power', 'Democracy', 'Equality', 'Freedom']),
          ('According to the passage, who is bound by law?', 'Everyone including those in authority',
           ['Everyone including those in authority', 'Only citizens', 'Only judges', 'Only politicians']),
        ],
      ),
    ];
    
    for (int i = 0; i < count; i++) {
      final passageData = passages[i % passages.length];
      final qaPair = passageData.$3[i % passageData.$3.length];
      final options = List<String>.from(qaPair.$3);
      options.shuffle();
      
      questions.add(EnhancedQuestion(
        id: 'clat_eng_${i + 1}',
        examType: 'clat',
        subject: 'English',
        topic: 'Reading Comprehension',
        question: 'Read and answer:\n\n"${passageData.$1}"\n\n${qaPair.$1}',
        options: options,
        correctOptionIndex: options.indexOf(qaPair.$2),
        explanation: 'Based on the passage: ${qaPair.$2}',
        difficulty: 'medium',
        marks: 1,
        negativeMarks: 0.25,
        timeInSeconds: 120,
        tags: ['english', 'clat', 'reading-comprehension'],
      ));
    }
    
    return questions;
  }

  /// Generate Current Affairs & GK (CLAT style)
  static List<EnhancedQuestion> generateCurrentAffairs(int count) {
    final questions = <EnhancedQuestion>[];
    
    final caQA = [
      ('Chief Justice of India is appointed by:', 'President', ['President', 'Prime Minister', 'Parliament', 'Law Minister'], 'Collegium recommends, President appoints'),
      ('POCSO Act protects:', 'Children from sexual offenses', ['Children from sexual offenses', 'Women from harassment', 'Elderly from abuse', 'Environment'], 'Protection of Children from Sexual Offences Act'),
      ('National Human Rights Commission is headed by:', 'Retired Chief Justice', ['Retired Chief Justice', 'Sitting Judge', 'Law Minister', 'President'], 'Retired CJI or SC judge heads NHRC'),
      ('Which body appoints CAG?', 'President', ['President', 'Parliament', 'Prime Minister', 'Supreme Court'], 'Article 148: CAG appointed by President'),
      ('Legal aid is guaranteed under which Article?', 'Article 39A', ['Article 39A', 'Article 21', 'Article 14', 'Article 32'], 'Free legal aid to weak sections'),
    ];
    
    for (int i = 0; i < count; i++) {
      final data = caQA[i % caQA.length];
      final options = List<String>.from(data.$3);
      options.shuffle();
      
      questions.add(EnhancedQuestion(
        id: 'clat_ca_${i + 1}',
        examType: 'clat',
        subject: 'Current Affairs',
        topic: 'General Knowledge',
        question: data.$1,
        options: options,
        correctOptionIndex: options.indexOf(data.$2),
        explanation: data.$4,
        difficulty: 'easy',
        marks: 1,
        negativeMarks: 0.25,
        timeInSeconds: 45,
        tags: ['current-affairs', 'clat', 'gk', 'legal-gk'],
      ));
    }
    
    return questions;
  }

  /// Generate all CLAT questions
  static List<EnhancedQuestion> generateAllQuestions() {
    return [
      ...generateLegalReasoning(500),
      ...generateLegalKnowledge(400),
      ...generateLogicalReasoning(400),
      ...generateEnglishComprehension(300),
      ...generateCurrentAffairs(400),
    ];
  }

  static int get totalQuestionCount => 2000;
}
