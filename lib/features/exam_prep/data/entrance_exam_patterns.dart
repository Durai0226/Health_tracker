/// Entrance Exam Patterns - Detailed patterns for JEE, NEET, CAT, GATE, CLAT
/// Contains exam-specific information, syllabus breakdown, and preparation tips

class EntranceExamPattern {
  final String examId;
  final String name;
  final String conductingBody;
  final String eligibility;
  final String examMode;
  final String frequency;
  final List<String> importantDates;
  final List<SyllabusSection> syllabus;
  final List<String> preparationTips;
  final Map<String, double> topicWeightage;
  final List<String> recommendedBooks;
  final int cutoffRange;

  const EntranceExamPattern({
    required this.examId,
    required this.name,
    required this.conductingBody,
    required this.eligibility,
    required this.examMode,
    required this.frequency,
    required this.importantDates,
    required this.syllabus,
    required this.preparationTips,
    required this.topicWeightage,
    required this.recommendedBooks,
    required this.cutoffRange,
  });
}

class SyllabusSection {
  final String subject;
  final List<String> topics;
  final int weightagePercent;

  const SyllabusSection({
    required this.subject,
    required this.topics,
    required this.weightagePercent,
  });
}

class EntranceExamPatterns {
  // JEE Main Pattern
  static const jeeMain = EntranceExamPattern(
    examId: 'jee_main',
    name: 'JEE Main',
    conductingBody: 'National Testing Agency (NTA)',
    eligibility: 'Class 12 passed/appearing with PCM, Age < 25 years',
    examMode: 'Computer Based Test (CBT)',
    frequency: 'Twice a year (January & April)',
    importantDates: [
      'Registration: December/September',
      'Exam: January & April sessions',
      'Results: Within 2 weeks of exam',
    ],
    syllabus: [
      SyllabusSection(
        subject: 'Physics',
        topics: [
          'Mechanics', 'Thermodynamics', 'Electrodynamics',
          'Optics', 'Modern Physics', 'Waves & Oscillations'
        ],
        weightagePercent: 33,
      ),
      SyllabusSection(
        subject: 'Chemistry',
        topics: [
          'Physical Chemistry', 'Organic Chemistry', 'Inorganic Chemistry',
          'Electrochemistry', 'Chemical Bonding', 'Coordination Compounds'
        ],
        weightagePercent: 33,
      ),
      SyllabusSection(
        subject: 'Mathematics',
        topics: [
          'Calculus', 'Algebra', 'Coordinate Geometry',
          'Trigonometry', 'Vectors & 3D', 'Statistics & Probability'
        ],
        weightagePercent: 34,
      ),
    ],
    preparationTips: [
      'Focus on NCERT textbooks for basics',
      'Practice previous year questions daily',
      'Take regular mock tests',
      'Revise formulas every week',
      'Focus on weak areas identified in mocks',
    ],
    topicWeightage: {
      'Mechanics': 12.0,
      'Electrodynamics': 10.0,
      'Modern Physics': 8.0,
      'Organic Chemistry': 12.0,
      'Physical Chemistry': 10.0,
      'Calculus': 15.0,
      'Algebra': 12.0,
      'Coordinate Geometry': 10.0,
    },
    recommendedBooks: [
      'HC Verma - Concepts of Physics',
      'DC Pandey - Understanding Physics',
      'MS Chauhan - Organic Chemistry',
      'RD Sharma - Mathematics',
      'Cengage Series - All Subjects',
    ],
    cutoffRange: 90,
  );

  // JEE Advanced Pattern
  static const jeeAdvanced = EntranceExamPattern(
    examId: 'jee_advanced',
    name: 'JEE Advanced',
    conductingBody: 'IITs (Rotational)',
    eligibility: 'Top 2.5 lakh JEE Main qualifiers',
    examMode: 'Computer Based Test (CBT)',
    frequency: 'Once a year (May/June)',
    importantDates: [
      'Registration: After JEE Main results',
      'Exam: May/June',
      'Results: June',
    ],
    syllabus: [
      SyllabusSection(
        subject: 'Physics',
        topics: [
          'Advanced Mechanics', 'Electromagnetic Induction',
          'Modern Physics', 'Thermodynamics', 'Optics'
        ],
        weightagePercent: 33,
      ),
      SyllabusSection(
        subject: 'Chemistry',
        topics: [
          'Organic Reactions', 'Coordination Chemistry',
          'Electrochemistry', 'Chemical Equilibrium'
        ],
        weightagePercent: 33,
      ),
      SyllabusSection(
        subject: 'Mathematics',
        topics: [
          'Calculus', 'Complex Numbers', 'Matrices',
          'Probability', 'Differential Equations'
        ],
        weightagePercent: 34,
      ),
    ],
    preparationTips: [
      'Master JEE Main level first',
      'Focus on concept clarity over quantity',
      'Solve IIT papers from last 20 years',
      'Practice integer type & matrix match questions',
      'Time management is crucial',
    ],
    topicWeightage: {
      'Mechanics': 15.0,
      'Electromagnetism': 12.0,
      'Organic Chemistry': 14.0,
      'Calculus': 18.0,
      'Algebra': 10.0,
    },
    recommendedBooks: [
      'Irodov - Problems in Physics',
      'MS Chauhan - Advanced Organic Chemistry',
      'Arihant JEE Advanced Previous Years',
    ],
    cutoffRange: 100,
  );

  // NEET UG Pattern
  static const neetUG = EntranceExamPattern(
    examId: 'neet_ug',
    name: 'NEET UG',
    conductingBody: 'National Testing Agency (NTA)',
    eligibility: 'Class 12 passed/appearing with PCB, Age 17-25 years',
    examMode: 'Pen & Paper Based (OMR)',
    frequency: 'Once a year (May)',
    importantDates: [
      'Registration: December-January',
      'Exam: May',
      'Results: June',
    ],
    syllabus: [
      SyllabusSection(
        subject: 'Physics',
        topics: [
          'Mechanics', 'Thermodynamics', 'Electrostatics',
          'Magnetism', 'Optics', 'Modern Physics'
        ],
        weightagePercent: 25,
      ),
      SyllabusSection(
        subject: 'Chemistry',
        topics: [
          'Organic Chemistry', 'Inorganic Chemistry',
          'Physical Chemistry', 'Biomolecules'
        ],
        weightagePercent: 25,
      ),
      SyllabusSection(
        subject: 'Biology',
        topics: [
          'Human Physiology', 'Genetics', 'Ecology',
          'Cell Biology', 'Plant Physiology', 'Reproduction'
        ],
        weightagePercent: 50,
      ),
    ],
    preparationTips: [
      'NCERT is the Bible for NEET',
      'Focus more on Biology (50% weightage)',
      'Practice diagrams for Biology',
      'Memorize reactions for Chemistry',
      'Solve at least 50 questions daily',
    ],
    topicWeightage: {
      'Human Physiology': 12.0,
      'Genetics': 10.0,
      'Ecology': 8.0,
      'Organic Chemistry': 10.0,
      'Mechanics': 6.0,
    },
    recommendedBooks: [
      'NCERT Biology Class 11 & 12',
      'Trueman Biology',
      'MTG NEET Guide',
      'Pradeep Chemistry',
    ],
    cutoffRange: 650,
  );

  // CAT Pattern
  static const cat = EntranceExamPattern(
    examId: 'cat',
    name: 'CAT',
    conductingBody: 'IIMs (Rotational)',
    eligibility: 'Graduate with 50% marks (45% for reserved)',
    examMode: 'Computer Based Test (CBT)',
    frequency: 'Once a year (November)',
    importantDates: [
      'Registration: August-September',
      'Admit Card: October',
      'Exam: November (3rd Sunday)',
      'Results: January',
    ],
    syllabus: [
      SyllabusSection(
        subject: 'VARC',
        topics: [
          'Reading Comprehension', 'Para Jumbles',
          'Para Summary', 'Odd Sentence', 'Critical Reasoning'
        ],
        weightagePercent: 34,
      ),
      SyllabusSection(
        subject: 'DILR',
        topics: [
          'Tables', 'Bar Graphs', 'Pie Charts',
          'Puzzles', 'Arrangements', 'Games & Tournaments'
        ],
        weightagePercent: 32,
      ),
      SyllabusSection(
        subject: 'QA',
        topics: [
          'Arithmetic', 'Algebra', 'Number System',
          'Geometry', 'Modern Math'
        ],
        weightagePercent: 34,
      ),
    ],
    preparationTips: [
      'Read newspapers daily for RC',
      'Practice DILR sets regularly',
      'Speed and accuracy both matter',
      'Take 50+ full-length mocks',
      'Analyze every mock thoroughly',
    ],
    topicWeightage: {
      'Reading Comprehension': 24.0,
      'Puzzles & Arrangements': 20.0,
      'Arithmetic': 15.0,
      'Algebra': 10.0,
    },
    recommendedBooks: [
      'Arun Sharma - Quantitative Aptitude',
      'Arun Sharma - Logical Reasoning',
      'Nishit Sinha - Verbal Ability',
      'Previous Year CAT Papers',
    ],
    cutoffRange: 99,
  );

  // GATE CS Pattern
  static const gateCS = EntranceExamPattern(
    examId: 'gate_cse',
    name: 'GATE Computer Science',
    conductingBody: 'IITs & IISc (Rotational)',
    eligibility: 'BE/BTech in CS/IT or equivalent',
    examMode: 'Computer Based Test (CBT)',
    frequency: 'Once a year (February)',
    importantDates: [
      'Registration: August-September',
      'Exam: February',
      'Results: March',
    ],
    syllabus: [
      SyllabusSection(
        subject: 'Core CS',
        topics: [
          'Data Structures', 'Algorithms', 'DBMS',
          'Operating Systems', 'Computer Networks', 'TOC'
        ],
        weightagePercent: 72,
      ),
      SyllabusSection(
        subject: 'Engineering Mathematics',
        topics: [
          'Discrete Mathematics', 'Linear Algebra',
          'Probability', 'Calculus'
        ],
        weightagePercent: 13,
      ),
      SyllabusSection(
        subject: 'General Aptitude',
        topics: [
          'Verbal Ability', 'Numerical Ability'
        ],
        weightagePercent: 15,
      ),
    ],
    preparationTips: [
      'Master DSA thoroughly',
      'Practice previous year GATE questions',
      'Focus on standard algorithms',
      'Revise discrete math regularly',
      'Take topic-wise tests',
    ],
    topicWeightage: {
      'Data Structures & Algorithms': 15.0,
      'DBMS': 8.0,
      'Operating Systems': 10.0,
      'Computer Networks': 8.0,
      'TOC & Compiler': 12.0,
      'Digital Logic': 5.0,
    },
    recommendedBooks: [
      'Cormen - Introduction to Algorithms',
      'Galvin - Operating Systems',
      'Forouzan - Data Communications',
      'GATE CSE by Kanodia',
    ],
    cutoffRange: 30,
  );

  // CLAT Pattern
  static const clat = EntranceExamPattern(
    examId: 'clat',
    name: 'CLAT',
    conductingBody: 'Consortium of NLUs',
    eligibility: 'Class 12 passed/appearing with 45% marks',
    examMode: 'Computer Based Test (CBT)',
    frequency: 'Once a year (May/December)',
    importantDates: [
      'Registration: January-April',
      'Exam: May/December',
      'Results: Within 3 weeks',
    ],
    syllabus: [
      SyllabusSection(
        subject: 'English',
        topics: [
          'Reading Comprehension', 'Grammar',
          'Vocabulary', 'Critical Reasoning'
        ],
        weightagePercent: 20,
      ),
      SyllabusSection(
        subject: 'Current Affairs & GK',
        topics: [
          'Current Events', 'Static GK',
          'Legal Current Affairs'
        ],
        weightagePercent: 25,
      ),
      SyllabusSection(
        subject: 'Legal Reasoning',
        topics: [
          'Legal Principles', 'Legal Facts',
          'Constitutional Law', 'Legal Maxims'
        ],
        weightagePercent: 25,
      ),
      SyllabusSection(
        subject: 'Logical Reasoning',
        topics: [
          'Critical Reasoning', 'Analogies',
          'Syllogisms', 'Pattern Recognition'
        ],
        weightagePercent: 20,
      ),
      SyllabusSection(
        subject: 'Quantitative Techniques',
        topics: [
          'Basic Mathematics', 'Data Interpretation',
          'Statistics'
        ],
        weightagePercent: 10,
      ),
    ],
    preparationTips: [
      'Read The Hindu & Indian Express daily',
      'Practice legal reasoning passages',
      'Focus on comprehension-based approach',
      'Keep track of landmark judgments',
      'Take weekly mock tests',
    ],
    topicWeightage: {
      'Legal Reasoning': 25.0,
      'Current Affairs': 25.0,
      'English': 20.0,
      'Logical Reasoning': 20.0,
      'Quantitative': 10.0,
    },
    recommendedBooks: [
      'Word Power Made Easy - Norman Lewis',
      'Legal Awareness & Legal Aptitude - AP Bhardwaj',
      'Manorama Yearbook',
      'Universal\'s Guide to CLAT',
    ],
    cutoffRange: 110,
  );

  // UPSC CSE Pattern
  static const upscCSE = EntranceExamPattern(
    examId: 'upsc_cse_prelims',
    name: 'UPSC Civil Services',
    conductingBody: 'Union Public Service Commission',
    eligibility: 'Graduate, Age 21-32 years',
    examMode: 'Pen & Paper (OMR) for Prelims',
    frequency: 'Once a year',
    importantDates: [
      'Notification: February',
      'Prelims: May/June',
      'Mains: September',
      'Interview: February-April',
    ],
    syllabus: [
      SyllabusSection(
        subject: 'General Studies I',
        topics: [
          'History', 'Geography', 'Polity',
          'Economics', 'Environment', 'Science & Tech',
          'Current Affairs'
        ],
        weightagePercent: 50,
      ),
      SyllabusSection(
        subject: 'CSAT (Paper II)',
        topics: [
          'Comprehension', 'Logical Reasoning',
          'Basic Numeracy', 'Decision Making'
        ],
        weightagePercent: 50,
      ),
    ],
    preparationTips: [
      'NCERT books are foundation',
      'Read newspaper daily - The Hindu/IE',
      'Make short notes for revision',
      'Current affairs is key',
      'Answer writing practice for Mains',
    ],
    topicWeightage: {
      'Polity': 15.0,
      'History': 15.0,
      'Geography': 12.0,
      'Economics': 12.0,
      'Environment': 10.0,
      'Science & Tech': 10.0,
      'Current Affairs': 26.0,
    },
    recommendedBooks: [
      'Laxmikanth - Indian Polity',
      'Spectrum - Modern India',
      'Shankar IAS - Environment',
      'Economic Survey',
      'NCERT Class 6-12',
    ],
    cutoffRange: 100,
  );

  static const List<EntranceExamPattern> allPatterns = [
    jeeMain,
    jeeAdvanced,
    neetUG,
    cat,
    gateCS,
    clat,
    upscCSE,
  ];

  static EntranceExamPattern? getPatternById(String examId) {
    try {
      return allPatterns.firstWhere((p) => p.examId == examId);
    } catch (_) {
      return null;
    }
  }

  static List<String> getPreparationTips(String examId) {
    final pattern = getPatternById(examId);
    return pattern?.preparationTips ?? [];
  }

  static List<SyllabusSection> getSyllabus(String examId) {
    final pattern = getPatternById(examId);
    return pattern?.syllabus ?? [];
  }
}
