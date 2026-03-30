/// Comprehensive exam categories and subjects for competitive exam preparation
/// Covers Banking, SSC, Railways, UPSC, State PSC, Defense, Teaching, Insurance
/// Plus Entrance Exams: JEE, NEET, CAT, GATE, CLAT and more

class ExamCategory {
  final String id;
  final String name;
  final String shortName;
  final String description;
  final String icon;
  final String colorHex;
  final List<ExamType> exams;
  final List<String> subjects;

  const ExamCategory({
    required this.id,
    required this.name,
    required this.shortName,
    required this.description,
    required this.icon,
    required this.colorHex,
    required this.exams,
    required this.subjects,
  });
}

class ExamType {
  final String id;
  final String name;
  final String fullName;
  final String categoryId;
  final String description;
  final int totalQuestions;
  final int durationMinutes;
  final List<ExamSection> sections;
  final bool isPopular;

  const ExamType({
    required this.id,
    required this.name,
    required this.fullName,
    required this.categoryId,
    required this.description,
    required this.totalQuestions,
    required this.durationMinutes,
    required this.sections,
    this.isPopular = false,
  });
}

class ExamSection {
  final String name;
  final int questionCount;
  final int durationMinutes;
  final double maxMarks;
  final double negativeMarking;

  const ExamSection({
    required this.name,
    required this.questionCount,
    required this.durationMinutes,
    required this.maxMarks,
    this.negativeMarking = 0.25,
  });
}

class Subject {
  final String id;
  final String name;
  final String shortName;
  final String icon;
  final String colorHex;
  final List<Topic> topics;

  const Subject({
    required this.id,
    required this.name,
    required this.shortName,
    required this.icon,
    required this.colorHex,
    required this.topics,
  });
}

class Topic {
  final String id;
  final String name;
  final String subjectId;
  final int questionCount;
  final String difficulty;

  const Topic({
    required this.id,
    required this.name,
    required this.subjectId,
    required this.questionCount,
    this.difficulty = 'medium',
  });
}

/// All exam categories
class ExamData {
  static const List<ExamCategory> categories = [
    // Banking Exams
    ExamCategory(
      id: 'banking',
      name: 'Banking Exams',
      shortName: 'Banking',
      description: 'IBPS, SBI, RBI & other bank recruitment exams',
      icon: 'account_balance',
      colorHex: '#0EA5E9',
      exams: bankingExams,
      subjects: ['Quantitative Aptitude', 'Reasoning', 'English', 'General Awareness', 'Computer'],
    ),
    // SSC Exams
    ExamCategory(
      id: 'ssc',
      name: 'SSC Exams',
      shortName: 'SSC',
      description: 'Staff Selection Commission exams',
      icon: 'work',
      colorHex: '#22C55E',
      exams: sscExams,
      subjects: ['Quantitative Aptitude', 'Reasoning', 'English', 'General Awareness'],
    ),
    // Railways Exams
    ExamCategory(
      id: 'railways',
      name: 'Railway Exams',
      shortName: 'Railways',
      description: 'RRB NTPC, Group D, ALP & other railway exams',
      icon: 'train',
      colorHex: '#EF4444',
      exams: railwayExams,
      subjects: ['Mathematics', 'Reasoning', 'General Science', 'General Awareness'],
    ),
    // State PSC
    ExamCategory(
      id: 'state_psc',
      name: 'State PSC',
      shortName: 'PSC',
      description: 'State Public Service Commission exams',
      icon: 'assured_workload',
      colorHex: '#F97316',
      exams: statePscExams,
      subjects: ['General Studies', 'CSAT', 'English', 'Regional Language'],
    ),
    // Defense Exams
    ExamCategory(
      id: 'defense',
      name: 'Defense Exams',
      shortName: 'Defense',
      description: 'CDS, NDA, AFCAT & other defense exams',
      icon: 'military_tech',
      colorHex: '#14B8A6',
      exams: defenseExams,
      subjects: ['Mathematics', 'English', 'General Knowledge'],
    ),
    // Teaching Exams
    ExamCategory(
      id: 'teaching',
      name: 'Teaching Exams',
      shortName: 'Teaching',
      description: 'CTET, State TET & other teaching exams',
      icon: 'school',
      colorHex: '#A855F7',
      exams: teachingExams,
      subjects: ['Child Development', 'Language', 'Mathematics', 'Environmental Studies'],
    ),
    // UPSC Exams
    ExamCategory(
      id: 'upsc',
      name: 'UPSC Exams',
      shortName: 'UPSC',
      description: 'Civil Services, CAPF, CDS & other UPSC exams',
      icon: 'account_balance',
      colorHex: '#DC2626',
      exams: upscExams,
      subjects: ['History', 'Polity', 'Geography', 'Economics', 'Environment', 'Current Affairs'],
    ),
    // Insurance Exams
    ExamCategory(
      id: 'insurance',
      name: 'Insurance Exams',
      shortName: 'Insurance',
      description: 'LIC, GIC, NIACL & other insurance exams',
      icon: 'health_and_safety',
      colorHex: '#0891B2',
      exams: insuranceExams,
      subjects: ['Quantitative Aptitude', 'Reasoning', 'English', 'General Awareness', 'Insurance Awareness'],
    ),
    // JEE & Engineering Entrance
    ExamCategory(
      id: 'jee',
      name: 'JEE & Engineering',
      shortName: 'JEE',
      description: 'JEE Main, JEE Advanced, BITSAT & other engineering entrances',
      icon: 'engineering',
      colorHex: '#7C3AED',
      exams: jeeExams,
      subjects: ['Physics', 'Chemistry', 'Mathematics'],
    ),
    // NEET & Medical Entrance
    ExamCategory(
      id: 'neet',
      name: 'NEET & Medical',
      shortName: 'NEET',
      description: 'NEET UG, AIIMS & other medical entrances',
      icon: 'medical_services',
      colorHex: '#059669',
      exams: neetExams,
      subjects: ['Physics', 'Chemistry', 'Biology'],
    ),
    // CAT & Management Entrance
    ExamCategory(
      id: 'cat',
      name: 'CAT & Management',
      shortName: 'CAT',
      description: 'CAT, XAT, MAT, SNAP & other MBA entrances',
      icon: 'business_center',
      colorHex: '#D97706',
      exams: catExams,
      subjects: ['Quantitative Aptitude', 'Verbal Ability', 'Data Interpretation', 'Logical Reasoning'],
    ),
    // GATE & Engineering PG
    ExamCategory(
      id: 'gate',
      name: 'GATE & ESE',
      shortName: 'GATE',
      description: 'GATE, ESE/IES & other engineering PG exams',
      icon: 'precision_manufacturing',
      colorHex: '#4F46E5',
      exams: gateExams,
      subjects: ['Engineering Mathematics', 'General Aptitude', 'Core Subject'],
    ),
    // CLAT & Law Entrance
    ExamCategory(
      id: 'clat',
      name: 'CLAT & Law',
      shortName: 'CLAT',
      description: 'CLAT, AILET, LSAT & other law entrances',
      icon: 'gavel',
      colorHex: '#BE185D',
      exams: clatExams,
      subjects: ['Legal Reasoning', 'Logical Reasoning', 'English', 'Current Affairs', 'Quantitative Techniques'],
    ),
  ];

  // Banking Exams
  static const List<ExamType> bankingExams = [
    ExamType(
      id: 'ibps_po',
      name: 'IBPS PO',
      fullName: 'IBPS Probationary Officer',
      categoryId: 'banking',
      description: 'Bank PO recruitment by IBPS',
      totalQuestions: 100,
      durationMinutes: 60,
      isPopular: true,
      sections: [
        ExamSection(name: 'Reasoning', questionCount: 35, durationMinutes: 20, maxMarks: 35),
        ExamSection(name: 'Quantitative Aptitude', questionCount: 35, durationMinutes: 20, maxMarks: 35),
        ExamSection(name: 'English', questionCount: 30, durationMinutes: 20, maxMarks: 30),
      ],
    ),
    ExamType(
      id: 'ibps_clerk',
      name: 'IBPS Clerk',
      fullName: 'IBPS Clerical Cadre',
      categoryId: 'banking',
      description: 'Bank Clerk recruitment by IBPS',
      totalQuestions: 100,
      durationMinutes: 60,
      isPopular: true,
      sections: [
        ExamSection(name: 'Reasoning', questionCount: 35, durationMinutes: 20, maxMarks: 35),
        ExamSection(name: 'Quantitative Aptitude', questionCount: 35, durationMinutes: 20, maxMarks: 35),
        ExamSection(name: 'English', questionCount: 30, durationMinutes: 20, maxMarks: 30),
      ],
    ),
    ExamType(
      id: 'sbi_po',
      name: 'SBI PO',
      fullName: 'State Bank of India PO',
      categoryId: 'banking',
      description: 'SBI Probationary Officer exam',
      totalQuestions: 100,
      durationMinutes: 60,
      isPopular: true,
      sections: [
        ExamSection(name: 'Reasoning & Computer', questionCount: 35, durationMinutes: 20, maxMarks: 35),
        ExamSection(name: 'Data Analysis', questionCount: 35, durationMinutes: 20, maxMarks: 35),
        ExamSection(name: 'English', questionCount: 30, durationMinutes: 20, maxMarks: 30),
      ],
    ),
    ExamType(
      id: 'sbi_clerk',
      name: 'SBI Clerk',
      fullName: 'State Bank of India Clerk',
      categoryId: 'banking',
      description: 'SBI Junior Associate exam',
      totalQuestions: 100,
      durationMinutes: 60,
      sections: [
        ExamSection(name: 'Reasoning', questionCount: 35, durationMinutes: 20, maxMarks: 35),
        ExamSection(name: 'Numerical Ability', questionCount: 35, durationMinutes: 20, maxMarks: 35),
        ExamSection(name: 'English', questionCount: 30, durationMinutes: 20, maxMarks: 30),
      ],
    ),
    ExamType(
      id: 'rbi_assistant',
      name: 'RBI Assistant',
      fullName: 'Reserve Bank of India Assistant',
      categoryId: 'banking',
      description: 'RBI Assistant recruitment',
      totalQuestions: 100,
      durationMinutes: 60,
      sections: [
        ExamSection(name: 'Reasoning', questionCount: 35, durationMinutes: 20, maxMarks: 35),
        ExamSection(name: 'Quantitative Aptitude', questionCount: 35, durationMinutes: 20, maxMarks: 35),
        ExamSection(name: 'English', questionCount: 30, durationMinutes: 20, maxMarks: 30),
      ],
    ),
    ExamType(
      id: 'ibps_rrb_po',
      name: 'IBPS RRB PO',
      fullName: 'IBPS Regional Rural Bank PO',
      categoryId: 'banking',
      description: 'RRB Officer Scale-I exam',
      totalQuestions: 80,
      durationMinutes: 45,
      sections: [
        ExamSection(name: 'Reasoning', questionCount: 40, durationMinutes: 23, maxMarks: 40),
        ExamSection(name: 'Quantitative Aptitude', questionCount: 40, durationMinutes: 22, maxMarks: 40),
      ],
    ),
  ];

  // SSC Exams
  static const List<ExamType> sscExams = [
    ExamType(
      id: 'ssc_cgl',
      name: 'SSC CGL',
      fullName: 'Combined Graduate Level',
      categoryId: 'ssc',
      description: 'Group B & C posts under Central Government',
      totalQuestions: 100,
      durationMinutes: 60,
      isPopular: true,
      sections: [
        ExamSection(name: 'General Intelligence', questionCount: 25, durationMinutes: 15, maxMarks: 50),
        ExamSection(name: 'General Awareness', questionCount: 25, durationMinutes: 15, maxMarks: 50),
        ExamSection(name: 'Quantitative Aptitude', questionCount: 25, durationMinutes: 15, maxMarks: 50),
        ExamSection(name: 'English', questionCount: 25, durationMinutes: 15, maxMarks: 50),
      ],
    ),
    ExamType(
      id: 'ssc_chsl',
      name: 'SSC CHSL',
      fullName: 'Combined Higher Secondary Level',
      categoryId: 'ssc',
      description: 'LDC, DEO & other 10+2 level posts',
      totalQuestions: 100,
      durationMinutes: 60,
      isPopular: true,
      sections: [
        ExamSection(name: 'General Intelligence', questionCount: 25, durationMinutes: 15, maxMarks: 50),
        ExamSection(name: 'General Awareness', questionCount: 25, durationMinutes: 15, maxMarks: 50),
        ExamSection(name: 'Quantitative Aptitude', questionCount: 25, durationMinutes: 15, maxMarks: 50),
        ExamSection(name: 'English', questionCount: 25, durationMinutes: 15, maxMarks: 50),
      ],
    ),
    ExamType(
      id: 'ssc_mts',
      name: 'SSC MTS',
      fullName: 'Multi Tasking Staff',
      categoryId: 'ssc',
      description: 'Group C non-technical posts',
      totalQuestions: 100,
      durationMinutes: 90,
      sections: [
        ExamSection(name: 'Numerical Aptitude', questionCount: 25, durationMinutes: 23, maxMarks: 25),
        ExamSection(name: 'General Intelligence', questionCount: 25, durationMinutes: 22, maxMarks: 25),
        ExamSection(name: 'English', questionCount: 25, durationMinutes: 23, maxMarks: 25),
        ExamSection(name: 'General Awareness', questionCount: 25, durationMinutes: 22, maxMarks: 25),
      ],
    ),
    ExamType(
      id: 'ssc_gd',
      name: 'SSC GD',
      fullName: 'SSC GD Constable',
      categoryId: 'ssc',
      description: 'Constable in CAPFs, NIA, SSF & Rifleman',
      totalQuestions: 80,
      durationMinutes: 60,
      sections: [
        ExamSection(name: 'General Intelligence', questionCount: 20, durationMinutes: 15, maxMarks: 40),
        ExamSection(name: 'General Knowledge', questionCount: 20, durationMinutes: 15, maxMarks: 40),
        ExamSection(name: 'Elementary Mathematics', questionCount: 20, durationMinutes: 15, maxMarks: 40),
        ExamSection(name: 'English/Hindi', questionCount: 20, durationMinutes: 15, maxMarks: 40),
      ],
    ),
  ];

  // Railway Exams
  static const List<ExamType> railwayExams = [
    ExamType(
      id: 'rrb_ntpc',
      name: 'RRB NTPC',
      fullName: 'Non-Technical Popular Categories',
      categoryId: 'railways',
      description: 'Junior Clerk, Commercial Apprentice, etc.',
      totalQuestions: 100,
      durationMinutes: 90,
      isPopular: true,
      sections: [
        ExamSection(name: 'General Awareness', questionCount: 40, durationMinutes: 36, maxMarks: 40),
        ExamSection(name: 'Mathematics', questionCount: 30, durationMinutes: 27, maxMarks: 30),
        ExamSection(name: 'General Intelligence', questionCount: 30, durationMinutes: 27, maxMarks: 30),
      ],
    ),
    ExamType(
      id: 'rrb_group_d',
      name: 'RRB Group D',
      fullName: 'Railway Group D',
      categoryId: 'railways',
      description: 'Track Maintainer, Helper & other Group D posts',
      totalQuestions: 100,
      durationMinutes: 90,
      isPopular: true,
      sections: [
        ExamSection(name: 'General Science', questionCount: 25, durationMinutes: 23, maxMarks: 25),
        ExamSection(name: 'Mathematics', questionCount: 25, durationMinutes: 22, maxMarks: 25),
        ExamSection(name: 'General Intelligence', questionCount: 30, durationMinutes: 23, maxMarks: 30),
        ExamSection(name: 'General Awareness', questionCount: 20, durationMinutes: 22, maxMarks: 20),
      ],
    ),
    ExamType(
      id: 'rrb_alp',
      name: 'RRB ALP',
      fullName: 'Assistant Loco Pilot',
      categoryId: 'railways',
      description: 'Assistant Loco Pilot & Technician',
      totalQuestions: 75,
      durationMinutes: 60,
      sections: [
        ExamSection(name: 'Mathematics', questionCount: 20, durationMinutes: 16, maxMarks: 20),
        ExamSection(name: 'General Intelligence', questionCount: 25, durationMinutes: 20, maxMarks: 25),
        ExamSection(name: 'General Science', questionCount: 20, durationMinutes: 16, maxMarks: 20),
        ExamSection(name: 'General Awareness', questionCount: 10, durationMinutes: 8, maxMarks: 10),
      ],
    ),
    ExamType(
      id: 'rrb_je',
      name: 'RRB JE',
      fullName: 'Junior Engineer',
      categoryId: 'railways',
      description: 'Junior Engineer & DMS posts',
      totalQuestions: 100,
      durationMinutes: 90,
      sections: [
        ExamSection(name: 'Mathematics', questionCount: 25, durationMinutes: 23, maxMarks: 25),
        ExamSection(name: 'General Intelligence', questionCount: 25, durationMinutes: 22, maxMarks: 25),
        ExamSection(name: 'General Awareness', questionCount: 15, durationMinutes: 14, maxMarks: 15),
        ExamSection(name: 'General Science', questionCount: 35, durationMinutes: 31, maxMarks: 35),
      ],
    ),
  ];

  // State PSC Exams
  static const List<ExamType> statePscExams = [
    ExamType(
      id: 'upsc_prelims',
      name: 'UPSC Prelims',
      fullName: 'UPSC Civil Services Preliminary',
      categoryId: 'state_psc',
      description: 'IAS/IPS/IFS Preliminary examination',
      totalQuestions: 100,
      durationMinutes: 120,
      isPopular: true,
      sections: [
        ExamSection(name: 'General Studies Paper I', questionCount: 100, durationMinutes: 120, maxMarks: 200, negativeMarking: 0.33),
      ],
    ),
    ExamType(
      id: 'upsc_csat',
      name: 'UPSC CSAT',
      fullName: 'Civil Services Aptitude Test',
      categoryId: 'state_psc',
      description: 'Paper II of UPSC Prelims',
      totalQuestions: 80,
      durationMinutes: 120,
      sections: [
        ExamSection(name: 'CSAT', questionCount: 80, durationMinutes: 120, maxMarks: 200, negativeMarking: 0.33),
      ],
    ),
    ExamType(
      id: 'state_pcs',
      name: 'State PCS',
      fullName: 'State Public Civil Service',
      categoryId: 'state_psc',
      description: 'State level civil services exam',
      totalQuestions: 150,
      durationMinutes: 120,
      sections: [
        ExamSection(name: 'General Studies', questionCount: 150, durationMinutes: 120, maxMarks: 150),
      ],
    ),
  ];

  // Defense Exams
  static const List<ExamType> defenseExams = [
    ExamType(
      id: 'cds',
      name: 'CDS',
      fullName: 'Combined Defence Services',
      categoryId: 'defense',
      description: 'Officers Training Academy entry',
      totalQuestions: 100,
      durationMinutes: 120,
      isPopular: true,
      sections: [
        ExamSection(name: 'English', questionCount: 120, durationMinutes: 120, maxMarks: 100),
        ExamSection(name: 'General Knowledge', questionCount: 120, durationMinutes: 120, maxMarks: 100),
        ExamSection(name: 'Elementary Mathematics', questionCount: 100, durationMinutes: 120, maxMarks: 100),
      ],
    ),
    ExamType(
      id: 'nda',
      name: 'NDA',
      fullName: 'National Defence Academy',
      categoryId: 'defense',
      description: 'NDA & NA entrance examination',
      totalQuestions: 150,
      durationMinutes: 150,
      isPopular: true,
      sections: [
        ExamSection(name: 'Mathematics', questionCount: 120, durationMinutes: 150, maxMarks: 300),
        ExamSection(name: 'General Ability Test', questionCount: 150, durationMinutes: 150, maxMarks: 600),
      ],
    ),
    ExamType(
      id: 'afcat',
      name: 'AFCAT',
      fullName: 'Air Force Common Admission Test',
      categoryId: 'defense',
      description: 'Indian Air Force officer entry',
      totalQuestions: 100,
      durationMinutes: 120,
      sections: [
        ExamSection(name: 'General Awareness', questionCount: 25, durationMinutes: 30, maxMarks: 75),
        ExamSection(name: 'Verbal Ability', questionCount: 25, durationMinutes: 30, maxMarks: 75),
        ExamSection(name: 'Numerical Ability', questionCount: 25, durationMinutes: 30, maxMarks: 75),
        ExamSection(name: 'Reasoning', questionCount: 25, durationMinutes: 30, maxMarks: 75),
      ],
    ),
  ];

  // Teaching Exams
  static const List<ExamType> teachingExams = [
    ExamType(
      id: 'ctet_paper1',
      name: 'CTET Paper 1',
      fullName: 'Central Teacher Eligibility Test Paper 1',
      categoryId: 'teaching',
      description: 'For Classes I to V (Primary Stage)',
      totalQuestions: 150,
      durationMinutes: 150,
      isPopular: true,
      sections: [
        ExamSection(name: 'Child Development', questionCount: 30, durationMinutes: 30, maxMarks: 30, negativeMarking: 0),
        ExamSection(name: 'Language I', questionCount: 30, durationMinutes: 30, maxMarks: 30, negativeMarking: 0),
        ExamSection(name: 'Language II', questionCount: 30, durationMinutes: 30, maxMarks: 30, negativeMarking: 0),
        ExamSection(name: 'Mathematics', questionCount: 30, durationMinutes: 30, maxMarks: 30, negativeMarking: 0),
        ExamSection(name: 'Environmental Studies', questionCount: 30, durationMinutes: 30, maxMarks: 30, negativeMarking: 0),
      ],
    ),
    ExamType(
      id: 'ctet_paper2',
      name: 'CTET Paper 2',
      fullName: 'Central Teacher Eligibility Test Paper 2',
      categoryId: 'teaching',
      description: 'For Classes VI to VIII (Elementary Stage)',
      totalQuestions: 150,
      durationMinutes: 150,
      sections: [
        ExamSection(name: 'Child Development', questionCount: 30, durationMinutes: 30, maxMarks: 30, negativeMarking: 0),
        ExamSection(name: 'Language I', questionCount: 30, durationMinutes: 30, maxMarks: 30, negativeMarking: 0),
        ExamSection(name: 'Language II', questionCount: 30, durationMinutes: 30, maxMarks: 30, negativeMarking: 0),
        ExamSection(name: 'Mathematics/Science or Social Studies', questionCount: 60, durationMinutes: 60, maxMarks: 60, negativeMarking: 0),
      ],
    ),
  ];

  // UPSC Exams
  static const List<ExamType> upscExams = [
    ExamType(
      id: 'upsc_cse_prelims',
      name: 'UPSC CSE Prelims',
      fullName: 'Civil Services Examination Preliminary',
      categoryId: 'upsc',
      description: 'IAS/IPS/IFS Preliminary Examination',
      totalQuestions: 100,
      durationMinutes: 120,
      isPopular: true,
      sections: [
        ExamSection(name: 'General Studies I', questionCount: 100, durationMinutes: 120, maxMarks: 200, negativeMarking: 0.33),
      ],
    ),
    ExamType(
      id: 'upsc_csat',
      name: 'UPSC CSAT',
      fullName: 'Civil Services Aptitude Test',
      categoryId: 'upsc',
      description: 'Paper II - Qualifying Paper',
      totalQuestions: 80,
      durationMinutes: 120,
      isPopular: true,
      sections: [
        ExamSection(name: 'CSAT', questionCount: 80, durationMinutes: 120, maxMarks: 200, negativeMarking: 0.33),
      ],
    ),
    ExamType(
      id: 'upsc_capf',
      name: 'UPSC CAPF',
      fullName: 'Central Armed Police Forces',
      categoryId: 'upsc',
      description: 'Assistant Commandants in CAPF',
      totalQuestions: 125,
      durationMinutes: 120,
      sections: [
        ExamSection(name: 'General Ability & Intelligence', questionCount: 125, durationMinutes: 120, maxMarks: 250),
      ],
    ),
    ExamType(
      id: 'upsc_epfo',
      name: 'UPSC EPFO',
      fullName: 'Enforcement Officer/Accounts Officer',
      categoryId: 'upsc',
      description: 'EPFO recruitment exam',
      totalQuestions: 120,
      durationMinutes: 120,
      sections: [
        ExamSection(name: 'General Studies', questionCount: 40, durationMinutes: 40, maxMarks: 40),
        ExamSection(name: 'Industrial Relations', questionCount: 40, durationMinutes: 40, maxMarks: 40),
        ExamSection(name: 'Quantitative Aptitude', questionCount: 40, durationMinutes: 40, maxMarks: 40),
      ],
    ),
  ];

  // Insurance Exams
  static const List<ExamType> insuranceExams = [
    ExamType(
      id: 'lic_aao',
      name: 'LIC AAO',
      fullName: 'LIC Assistant Administrative Officer',
      categoryId: 'insurance',
      description: 'LIC AAO recruitment exam',
      totalQuestions: 100,
      durationMinutes: 120,
      isPopular: true,
      sections: [
        ExamSection(name: 'Reasoning', questionCount: 30, durationMinutes: 25, maxMarks: 90),
        ExamSection(name: 'Quantitative Aptitude', questionCount: 30, durationMinutes: 25, maxMarks: 90),
        ExamSection(name: 'General Knowledge', questionCount: 30, durationMinutes: 25, maxMarks: 90),
        ExamSection(name: 'English', questionCount: 30, durationMinutes: 25, maxMarks: 90),
        ExamSection(name: 'Insurance & Financial Awareness', questionCount: 30, durationMinutes: 20, maxMarks: 60),
      ],
    ),
    ExamType(
      id: 'lic_ado',
      name: 'LIC ADO',
      fullName: 'LIC Apprentice Development Officer',
      categoryId: 'insurance',
      description: 'LIC ADO recruitment exam',
      totalQuestions: 100,
      durationMinutes: 120,
      sections: [
        ExamSection(name: 'Reasoning', questionCount: 30, durationMinutes: 30, maxMarks: 60),
        ExamSection(name: 'Quantitative Aptitude', questionCount: 30, durationMinutes: 30, maxMarks: 60),
        ExamSection(name: 'English', questionCount: 40, durationMinutes: 30, maxMarks: 80),
        ExamSection(name: 'General Knowledge', questionCount: 50, durationMinutes: 30, maxMarks: 100),
      ],
    ),
    ExamType(
      id: 'niacl_ao',
      name: 'NIACL AO',
      fullName: 'New India Assurance Administrative Officer',
      categoryId: 'insurance',
      description: 'NIACL AO recruitment',
      totalQuestions: 100,
      durationMinutes: 120,
      sections: [
        ExamSection(name: 'Reasoning', questionCount: 35, durationMinutes: 30, maxMarks: 35),
        ExamSection(name: 'English', questionCount: 30, durationMinutes: 30, maxMarks: 30),
        ExamSection(name: 'Quantitative Aptitude', questionCount: 35, durationMinutes: 30, maxMarks: 35),
      ],
    ),
    ExamType(
      id: 'gic_ao',
      name: 'GIC AO',
      fullName: 'GIC Scale I Officer',
      categoryId: 'insurance',
      description: 'General Insurance Corporation exam',
      totalQuestions: 120,
      durationMinutes: 120,
      sections: [
        ExamSection(name: 'Reasoning', questionCount: 30, durationMinutes: 30, maxMarks: 60),
        ExamSection(name: 'English', questionCount: 30, durationMinutes: 30, maxMarks: 60),
        ExamSection(name: 'Quantitative Aptitude', questionCount: 30, durationMinutes: 30, maxMarks: 60),
        ExamSection(name: 'General Awareness', questionCount: 30, durationMinutes: 30, maxMarks: 60),
      ],
    ),
  ];

  // JEE & Engineering Entrance Exams
  static const List<ExamType> jeeExams = [
    ExamType(
      id: 'jee_main',
      name: 'JEE Main',
      fullName: 'Joint Entrance Examination Main',
      categoryId: 'jee',
      description: 'Engineering entrance for NITs, IIITs & CFTIs',
      totalQuestions: 90,
      durationMinutes: 180,
      isPopular: true,
      sections: [
        ExamSection(name: 'Physics', questionCount: 30, durationMinutes: 60, maxMarks: 100, negativeMarking: 1),
        ExamSection(name: 'Chemistry', questionCount: 30, durationMinutes: 60, maxMarks: 100, negativeMarking: 1),
        ExamSection(name: 'Mathematics', questionCount: 30, durationMinutes: 60, maxMarks: 100, negativeMarking: 1),
      ],
    ),
    ExamType(
      id: 'jee_advanced',
      name: 'JEE Advanced',
      fullName: 'Joint Entrance Examination Advanced',
      categoryId: 'jee',
      description: 'Engineering entrance for IITs',
      totalQuestions: 54,
      durationMinutes: 180,
      isPopular: true,
      sections: [
        ExamSection(name: 'Physics', questionCount: 18, durationMinutes: 60, maxMarks: 60),
        ExamSection(name: 'Chemistry', questionCount: 18, durationMinutes: 60, maxMarks: 60),
        ExamSection(name: 'Mathematics', questionCount: 18, durationMinutes: 60, maxMarks: 60),
      ],
    ),
    ExamType(
      id: 'bitsat',
      name: 'BITSAT',
      fullName: 'BITS Admission Test',
      categoryId: 'jee',
      description: 'Entrance for BITS Pilani campuses',
      totalQuestions: 130,
      durationMinutes: 180,
      sections: [
        ExamSection(name: 'Physics', questionCount: 40, durationMinutes: 45, maxMarks: 120),
        ExamSection(name: 'Chemistry', questionCount: 40, durationMinutes: 45, maxMarks: 120),
        ExamSection(name: 'Mathematics', questionCount: 45, durationMinutes: 45, maxMarks: 135),
        ExamSection(name: 'English & Logical Reasoning', questionCount: 25, durationMinutes: 45, maxMarks: 75),
      ],
    ),
    ExamType(
      id: 'viteee',
      name: 'VITEEE',
      fullName: 'VIT Engineering Entrance Exam',
      categoryId: 'jee',
      description: 'VIT University entrance exam',
      totalQuestions: 125,
      durationMinutes: 150,
      sections: [
        ExamSection(name: 'Physics', questionCount: 35, durationMinutes: 40, maxMarks: 35),
        ExamSection(name: 'Chemistry', questionCount: 35, durationMinutes: 40, maxMarks: 35),
        ExamSection(name: 'Mathematics', questionCount: 40, durationMinutes: 45, maxMarks: 40),
        ExamSection(name: 'Aptitude', questionCount: 15, durationMinutes: 25, maxMarks: 15),
      ],
    ),
  ];

  // NEET & Medical Entrance Exams
  static const List<ExamType> neetExams = [
    ExamType(
      id: 'neet_ug',
      name: 'NEET UG',
      fullName: 'National Eligibility cum Entrance Test',
      categoryId: 'neet',
      description: 'Medical entrance for MBBS/BDS courses',
      totalQuestions: 200,
      durationMinutes: 200,
      isPopular: true,
      sections: [
        ExamSection(name: 'Physics', questionCount: 50, durationMinutes: 50, maxMarks: 200, negativeMarking: 1),
        ExamSection(name: 'Chemistry', questionCount: 50, durationMinutes: 50, maxMarks: 200, negativeMarking: 1),
        ExamSection(name: 'Biology', questionCount: 100, durationMinutes: 100, maxMarks: 400, negativeMarking: 1),
      ],
    ),
    ExamType(
      id: 'aiims_mbbs',
      name: 'AIIMS MBBS',
      fullName: 'AIIMS MBBS Entrance',
      categoryId: 'neet',
      description: 'AIIMS medical entrance (now merged with NEET)',
      totalQuestions: 200,
      durationMinutes: 210,
      sections: [
        ExamSection(name: 'Physics', questionCount: 60, durationMinutes: 53, maxMarks: 60, negativeMarking: 0.33),
        ExamSection(name: 'Chemistry', questionCount: 60, durationMinutes: 52, maxMarks: 60, negativeMarking: 0.33),
        ExamSection(name: 'Biology', questionCount: 60, durationMinutes: 52, maxMarks: 60, negativeMarking: 0.33),
        ExamSection(name: 'General Knowledge', questionCount: 10, durationMinutes: 26, maxMarks: 10, negativeMarking: 0.33),
        ExamSection(name: 'Aptitude', questionCount: 10, durationMinutes: 27, maxMarks: 10, negativeMarking: 0.33),
      ],
    ),
    ExamType(
      id: 'jipmer',
      name: 'JIPMER',
      fullName: 'JIPMER MBBS Entrance',
      categoryId: 'neet',
      description: 'JIPMER medical entrance (now merged with NEET)',
      totalQuestions: 200,
      durationMinutes: 150,
      sections: [
        ExamSection(name: 'Physics', questionCount: 60, durationMinutes: 45, maxMarks: 60),
        ExamSection(name: 'Chemistry', questionCount: 60, durationMinutes: 45, maxMarks: 60),
        ExamSection(name: 'Biology', questionCount: 60, durationMinutes: 45, maxMarks: 60),
        ExamSection(name: 'English & Comprehension', questionCount: 10, durationMinutes: 8, maxMarks: 10),
        ExamSection(name: 'Logical & Quantitative', questionCount: 10, durationMinutes: 7, maxMarks: 10),
      ],
    ),
  ];

  // CAT & Management Entrance Exams
  static const List<ExamType> catExams = [
    ExamType(
      id: 'cat',
      name: 'CAT',
      fullName: 'Common Admission Test',
      categoryId: 'cat',
      description: 'MBA entrance for IIMs',
      totalQuestions: 66,
      durationMinutes: 120,
      isPopular: true,
      sections: [
        ExamSection(name: 'Verbal Ability & Reading Comprehension', questionCount: 24, durationMinutes: 40, maxMarks: 72),
        ExamSection(name: 'Data Interpretation & Logical Reasoning', questionCount: 20, durationMinutes: 40, maxMarks: 60),
        ExamSection(name: 'Quantitative Ability', questionCount: 22, durationMinutes: 40, maxMarks: 66),
      ],
    ),
    ExamType(
      id: 'xat',
      name: 'XAT',
      fullName: 'Xavier Aptitude Test',
      categoryId: 'cat',
      description: 'MBA entrance for XLRI & XIM',
      totalQuestions: 100,
      durationMinutes: 180,
      isPopular: true,
      sections: [
        ExamSection(name: 'Verbal & Logical Ability', questionCount: 26, durationMinutes: 50, maxMarks: 26, negativeMarking: 0.25),
        ExamSection(name: 'Decision Making', questionCount: 21, durationMinutes: 40, maxMarks: 21, negativeMarking: 0.25),
        ExamSection(name: 'Quantitative Ability & Data Interpretation', questionCount: 28, durationMinutes: 50, maxMarks: 28, negativeMarking: 0.25),
        ExamSection(name: 'General Knowledge', questionCount: 25, durationMinutes: 40, maxMarks: 25),
      ],
    ),
    ExamType(
      id: 'mat',
      name: 'MAT',
      fullName: 'Management Aptitude Test',
      categoryId: 'cat',
      description: 'MBA entrance for multiple B-schools',
      totalQuestions: 200,
      durationMinutes: 150,
      sections: [
        ExamSection(name: 'Language Comprehension', questionCount: 40, durationMinutes: 30, maxMarks: 40),
        ExamSection(name: 'Intelligence & Critical Reasoning', questionCount: 40, durationMinutes: 30, maxMarks: 40),
        ExamSection(name: 'Data Analysis & Sufficiency', questionCount: 40, durationMinutes: 30, maxMarks: 40),
        ExamSection(name: 'Mathematical Skills', questionCount: 40, durationMinutes: 30, maxMarks: 40),
        ExamSection(name: 'Indian & Global Environment', questionCount: 40, durationMinutes: 30, maxMarks: 40),
      ],
    ),
    ExamType(
      id: 'snap',
      name: 'SNAP',
      fullName: 'Symbiosis National Aptitude Test',
      categoryId: 'cat',
      description: 'MBA entrance for Symbiosis institutes',
      totalQuestions: 60,
      durationMinutes: 60,
      sections: [
        ExamSection(name: 'General English', questionCount: 15, durationMinutes: 15, maxMarks: 45),
        ExamSection(name: 'Quantitative, DI & DS', questionCount: 20, durationMinutes: 20, maxMarks: 60),
        ExamSection(name: 'Analytical & Logical Reasoning', questionCount: 25, durationMinutes: 25, maxMarks: 75),
      ],
    ),
    ExamType(
      id: 'cmat',
      name: 'CMAT',
      fullName: 'Common Management Admission Test',
      categoryId: 'cat',
      description: 'MBA entrance by NTA',
      totalQuestions: 100,
      durationMinutes: 180,
      sections: [
        ExamSection(name: 'Quantitative Techniques', questionCount: 25, durationMinutes: 45, maxMarks: 100),
        ExamSection(name: 'Logical Reasoning', questionCount: 25, durationMinutes: 45, maxMarks: 100),
        ExamSection(name: 'Language Comprehension', questionCount: 25, durationMinutes: 45, maxMarks: 100),
        ExamSection(name: 'General Awareness', questionCount: 25, durationMinutes: 45, maxMarks: 100),
      ],
    ),
  ];

  // GATE & Engineering PG Exams
  static const List<ExamType> gateExams = [
    ExamType(
      id: 'gate_cse',
      name: 'GATE CS',
      fullName: 'GATE Computer Science',
      categoryId: 'gate',
      description: 'PG entrance for CS/IT engineering',
      totalQuestions: 65,
      durationMinutes: 180,
      isPopular: true,
      sections: [
        ExamSection(name: 'General Aptitude', questionCount: 10, durationMinutes: 30, maxMarks: 15),
        ExamSection(name: 'Engineering Mathematics', questionCount: 13, durationMinutes: 40, maxMarks: 13),
        ExamSection(name: 'Core Subject', questionCount: 42, durationMinutes: 110, maxMarks: 72),
      ],
    ),
    ExamType(
      id: 'gate_ece',
      name: 'GATE EC',
      fullName: 'GATE Electronics & Communication',
      categoryId: 'gate',
      description: 'PG entrance for ECE engineering',
      totalQuestions: 65,
      durationMinutes: 180,
      isPopular: true,
      sections: [
        ExamSection(name: 'General Aptitude', questionCount: 10, durationMinutes: 30, maxMarks: 15),
        ExamSection(name: 'Engineering Mathematics', questionCount: 13, durationMinutes: 40, maxMarks: 13),
        ExamSection(name: 'Core Subject', questionCount: 42, durationMinutes: 110, maxMarks: 72),
      ],
    ),
    ExamType(
      id: 'gate_me',
      name: 'GATE ME',
      fullName: 'GATE Mechanical Engineering',
      categoryId: 'gate',
      description: 'PG entrance for Mechanical engineering',
      totalQuestions: 65,
      durationMinutes: 180,
      sections: [
        ExamSection(name: 'General Aptitude', questionCount: 10, durationMinutes: 30, maxMarks: 15),
        ExamSection(name: 'Engineering Mathematics', questionCount: 13, durationMinutes: 40, maxMarks: 13),
        ExamSection(name: 'Core Subject', questionCount: 42, durationMinutes: 110, maxMarks: 72),
      ],
    ),
    ExamType(
      id: 'gate_ee',
      name: 'GATE EE',
      fullName: 'GATE Electrical Engineering',
      categoryId: 'gate',
      description: 'PG entrance for Electrical engineering',
      totalQuestions: 65,
      durationMinutes: 180,
      sections: [
        ExamSection(name: 'General Aptitude', questionCount: 10, durationMinutes: 30, maxMarks: 15),
        ExamSection(name: 'Engineering Mathematics', questionCount: 13, durationMinutes: 40, maxMarks: 13),
        ExamSection(name: 'Core Subject', questionCount: 42, durationMinutes: 110, maxMarks: 72),
      ],
    ),
    ExamType(
      id: 'ese_prelims',
      name: 'ESE Prelims',
      fullName: 'Engineering Services Examination',
      categoryId: 'gate',
      description: 'UPSC ESE for engineering services',
      totalQuestions: 200,
      durationMinutes: 180,
      sections: [
        ExamSection(name: 'General Studies & Aptitude', questionCount: 100, durationMinutes: 120, maxMarks: 200),
        ExamSection(name: 'Engineering Discipline', questionCount: 100, durationMinutes: 180, maxMarks: 300),
      ],
    ),
  ];

  // CLAT & Law Entrance Exams
  static const List<ExamType> clatExams = [
    ExamType(
      id: 'clat',
      name: 'CLAT',
      fullName: 'Common Law Admission Test',
      categoryId: 'clat',
      description: 'Law entrance for NLUs',
      totalQuestions: 150,
      durationMinutes: 120,
      isPopular: true,
      sections: [
        ExamSection(name: 'English Language', questionCount: 28, durationMinutes: 22, maxMarks: 28, negativeMarking: 0.25),
        ExamSection(name: 'Current Affairs & GK', questionCount: 35, durationMinutes: 28, maxMarks: 35, negativeMarking: 0.25),
        ExamSection(name: 'Legal Reasoning', questionCount: 35, durationMinutes: 28, maxMarks: 35, negativeMarking: 0.25),
        ExamSection(name: 'Logical Reasoning', questionCount: 28, durationMinutes: 22, maxMarks: 28, negativeMarking: 0.25),
        ExamSection(name: 'Quantitative Techniques', questionCount: 14, durationMinutes: 10, maxMarks: 14, negativeMarking: 0.25),
      ],
    ),
    ExamType(
      id: 'ailet',
      name: 'AILET',
      fullName: 'All India Law Entrance Test',
      categoryId: 'clat',
      description: 'NLU Delhi law entrance',
      totalQuestions: 150,
      durationMinutes: 90,
      isPopular: true,
      sections: [
        ExamSection(name: 'English', questionCount: 35, durationMinutes: 21, maxMarks: 35),
        ExamSection(name: 'General Knowledge', questionCount: 35, durationMinutes: 21, maxMarks: 35),
        ExamSection(name: 'Legal Aptitude', questionCount: 35, durationMinutes: 21, maxMarks: 35),
        ExamSection(name: 'Reasoning', questionCount: 35, durationMinutes: 21, maxMarks: 35),
        ExamSection(name: 'Mathematics', questionCount: 10, durationMinutes: 6, maxMarks: 10),
      ],
    ),
    ExamType(
      id: 'lsat',
      name: 'LSAT India',
      fullName: 'Law School Admission Test India',
      categoryId: 'clat',
      description: 'International law school entrance',
      totalQuestions: 92,
      durationMinutes: 140,
      sections: [
        ExamSection(name: 'Analytical Reasoning', questionCount: 23, durationMinutes: 35, maxMarks: 23),
        ExamSection(name: 'Logical Reasoning I', questionCount: 23, durationMinutes: 35, maxMarks: 23),
        ExamSection(name: 'Logical Reasoning II', questionCount: 23, durationMinutes: 35, maxMarks: 23),
        ExamSection(name: 'Reading Comprehension', questionCount: 23, durationMinutes: 35, maxMarks: 23),
      ],
    ),
    ExamType(
      id: 'mh_cet_law',
      name: 'MH CET Law',
      fullName: 'Maharashtra CET Law',
      categoryId: 'clat',
      description: 'Maharashtra law entrance',
      totalQuestions: 150,
      durationMinutes: 120,
      sections: [
        ExamSection(name: 'Legal Aptitude', questionCount: 40, durationMinutes: 32, maxMarks: 40),
        ExamSection(name: 'Logical & Analytical Reasoning', questionCount: 40, durationMinutes: 32, maxMarks: 40),
        ExamSection(name: 'General Knowledge', questionCount: 30, durationMinutes: 24, maxMarks: 30),
        ExamSection(name: 'English', questionCount: 40, durationMinutes: 32, maxMarks: 40),
      ],
    ),
  ];

  // All subjects with topics
  static const List<Subject> subjects = [
    // Quantitative Aptitude
    Subject(
      id: 'quant',
      name: 'Quantitative Aptitude',
      shortName: 'Quant',
      icon: 'calculate',
      colorHex: '#3B82F6',
      topics: [
        Topic(id: 'number_system', name: 'Number System', subjectId: 'quant', questionCount: 50),
        Topic(id: 'percentage', name: 'Percentage', subjectId: 'quant', questionCount: 40),
        Topic(id: 'profit_loss', name: 'Profit & Loss', subjectId: 'quant', questionCount: 35),
        Topic(id: 'si_ci', name: 'Simple & Compound Interest', subjectId: 'quant', questionCount: 35),
        Topic(id: 'ratio_proportion', name: 'Ratio & Proportion', subjectId: 'quant', questionCount: 30),
        Topic(id: 'average', name: 'Average', subjectId: 'quant', questionCount: 25),
        Topic(id: 'time_work', name: 'Time & Work', subjectId: 'quant', questionCount: 40),
        Topic(id: 'time_distance', name: 'Time, Speed & Distance', subjectId: 'quant', questionCount: 40),
        Topic(id: 'algebra', name: 'Algebra', subjectId: 'quant', questionCount: 35),
        Topic(id: 'geometry', name: 'Geometry', subjectId: 'quant', questionCount: 30),
        Topic(id: 'mensuration', name: 'Mensuration', subjectId: 'quant', questionCount: 35),
        Topic(id: 'data_interpretation', name: 'Data Interpretation', subjectId: 'quant', questionCount: 50, difficulty: 'hard'),
        Topic(id: 'number_series', name: 'Number Series', subjectId: 'quant', questionCount: 30),
        Topic(id: 'simplification', name: 'Simplification', subjectId: 'quant', questionCount: 25, difficulty: 'easy'),
      ],
    ),
    // Reasoning
    Subject(
      id: 'reasoning',
      name: 'Reasoning Ability',
      shortName: 'Reasoning',
      icon: 'psychology',
      colorHex: '#8B5CF6',
      topics: [
        Topic(id: 'coding_decoding', name: 'Coding-Decoding', subjectId: 'reasoning', questionCount: 40),
        Topic(id: 'blood_relation', name: 'Blood Relations', subjectId: 'reasoning', questionCount: 35),
        Topic(id: 'direction_sense', name: 'Direction Sense', subjectId: 'reasoning', questionCount: 30),
        Topic(id: 'syllogism', name: 'Syllogism', subjectId: 'reasoning', questionCount: 40),
        Topic(id: 'seating_arrangement', name: 'Seating Arrangement', subjectId: 'reasoning', questionCount: 50, difficulty: 'hard'),
        Topic(id: 'puzzle', name: 'Puzzles', subjectId: 'reasoning', questionCount: 50, difficulty: 'hard'),
        Topic(id: 'inequality', name: 'Inequality', subjectId: 'reasoning', questionCount: 35),
        Topic(id: 'order_ranking', name: 'Order & Ranking', subjectId: 'reasoning', questionCount: 25),
        Topic(id: 'analogy', name: 'Analogy', subjectId: 'reasoning', questionCount: 30),
        Topic(id: 'classification', name: 'Classification', subjectId: 'reasoning', questionCount: 25, difficulty: 'easy'),
        Topic(id: 'series', name: 'Alphabet & Number Series', subjectId: 'reasoning', questionCount: 35),
        Topic(id: 'input_output', name: 'Input-Output', subjectId: 'reasoning', questionCount: 30),
        Topic(id: 'statement_conclusion', name: 'Statement & Conclusion', subjectId: 'reasoning', questionCount: 25),
        Topic(id: 'data_sufficiency', name: 'Data Sufficiency', subjectId: 'reasoning', questionCount: 30, difficulty: 'hard'),
      ],
    ),
    // English
    Subject(
      id: 'english',
      name: 'English Language',
      shortName: 'English',
      icon: 'abc',
      colorHex: '#10B981',
      topics: [
        Topic(id: 'reading_comprehension', name: 'Reading Comprehension', subjectId: 'english', questionCount: 50),
        Topic(id: 'cloze_test', name: 'Cloze Test', subjectId: 'english', questionCount: 35),
        Topic(id: 'error_spotting', name: 'Error Spotting', subjectId: 'english', questionCount: 40),
        Topic(id: 'fill_blanks', name: 'Fill in the Blanks', subjectId: 'english', questionCount: 35),
        Topic(id: 'para_jumbles', name: 'Para Jumbles', subjectId: 'english', questionCount: 30),
        Topic(id: 'sentence_improvement', name: 'Sentence Improvement', subjectId: 'english', questionCount: 35),
        Topic(id: 'synonyms_antonyms', name: 'Synonyms & Antonyms', subjectId: 'english', questionCount: 30),
        Topic(id: 'one_word', name: 'One Word Substitution', subjectId: 'english', questionCount: 25),
        Topic(id: 'idioms_phrases', name: 'Idioms & Phrases', subjectId: 'english', questionCount: 30),
        Topic(id: 'sentence_rearrangement', name: 'Sentence Rearrangement', subjectId: 'english', questionCount: 25),
        Topic(id: 'vocabulary', name: 'Vocabulary', subjectId: 'english', questionCount: 40),
        Topic(id: 'grammar', name: 'Grammar Rules', subjectId: 'english', questionCount: 35),
      ],
    ),
    // General Awareness
    Subject(
      id: 'gk',
      name: 'General Awareness',
      shortName: 'GK',
      icon: 'public',
      colorHex: '#F59E0B',
      topics: [
        Topic(id: 'current_affairs', name: 'Current Affairs', subjectId: 'gk', questionCount: 80),
        Topic(id: 'banking_awareness', name: 'Banking Awareness', subjectId: 'gk', questionCount: 50),
        Topic(id: 'indian_economy', name: 'Indian Economy', subjectId: 'gk', questionCount: 40),
        Topic(id: 'indian_history', name: 'Indian History', subjectId: 'gk', questionCount: 35),
        Topic(id: 'indian_polity', name: 'Indian Polity', subjectId: 'gk', questionCount: 35),
        Topic(id: 'geography', name: 'Geography', subjectId: 'gk', questionCount: 30),
        Topic(id: 'science_tech', name: 'Science & Technology', subjectId: 'gk', questionCount: 25),
        Topic(id: 'sports', name: 'Sports', subjectId: 'gk', questionCount: 20),
        Topic(id: 'awards_honors', name: 'Awards & Honours', subjectId: 'gk', questionCount: 20),
        Topic(id: 'books_authors', name: 'Books & Authors', subjectId: 'gk', questionCount: 15),
        Topic(id: 'national_international', name: 'National & International', subjectId: 'gk', questionCount: 30),
        Topic(id: 'static_gk', name: 'Static GK', subjectId: 'gk', questionCount: 40),
      ],
    ),
    // Computer
    Subject(
      id: 'computer',
      name: 'Computer Awareness',
      shortName: 'Computer',
      icon: 'computer',
      colorHex: '#06B6D4',
      topics: [
        Topic(id: 'computer_basics', name: 'Computer Fundamentals', subjectId: 'computer', questionCount: 40),
        Topic(id: 'hardware', name: 'Hardware', subjectId: 'computer', questionCount: 25),
        Topic(id: 'software', name: 'Software', subjectId: 'computer', questionCount: 30),
        Topic(id: 'networking', name: 'Networking & Internet', subjectId: 'computer', questionCount: 35),
        Topic(id: 'ms_office', name: 'MS Office', subjectId: 'computer', questionCount: 30),
        Topic(id: 'dbms', name: 'Database (DBMS)', subjectId: 'computer', questionCount: 20),
        Topic(id: 'security', name: 'Computer Security', subjectId: 'computer', questionCount: 20),
        Topic(id: 'shortcuts', name: 'Keyboard Shortcuts', subjectId: 'computer', questionCount: 15),
        Topic(id: 'os', name: 'Operating Systems', subjectId: 'computer', questionCount: 25),
        Topic(id: 'abbreviations', name: 'Computer Abbreviations', subjectId: 'computer', questionCount: 20),
      ],
    ),
    // General Science
    Subject(
      id: 'science',
      name: 'General Science',
      shortName: 'Science',
      icon: 'science',
      colorHex: '#EC4899',
      topics: [
        Topic(id: 'physics', name: 'Physics', subjectId: 'science', questionCount: 50),
        Topic(id: 'chemistry', name: 'Chemistry', subjectId: 'science', questionCount: 45),
        Topic(id: 'biology', name: 'Biology', subjectId: 'science', questionCount: 50),
        Topic(id: 'human_body', name: 'Human Body', subjectId: 'science', questionCount: 25),
        Topic(id: 'diseases', name: 'Diseases & Health', subjectId: 'science', questionCount: 20),
        Topic(id: 'inventions', name: 'Inventions & Discoveries', subjectId: 'science', questionCount: 20),
        Topic(id: 'environment', name: 'Environment', subjectId: 'science', questionCount: 25),
        Topic(id: 'space', name: 'Space Science', subjectId: 'science', questionCount: 15),
      ],
    ),
    // Physics (Advanced) - JEE/NEET/GATE level
    Subject(
      id: 'physics_adv',
      name: 'Physics (Advanced)',
      shortName: 'Physics',
      icon: 'bolt',
      colorHex: '#F97316',
      topics: [
        Topic(id: 'mechanics', name: 'Mechanics', subjectId: 'physics_adv', questionCount: 120, difficulty: 'hard'),
        Topic(id: 'thermodynamics', name: 'Thermodynamics', subjectId: 'physics_adv', questionCount: 80),
        Topic(id: 'waves_oscillations', name: 'Waves & Oscillations', subjectId: 'physics_adv', questionCount: 70),
        Topic(id: 'optics', name: 'Optics', subjectId: 'physics_adv', questionCount: 90),
        Topic(id: 'electrostatics', name: 'Electrostatics', subjectId: 'physics_adv', questionCount: 80, difficulty: 'hard'),
        Topic(id: 'current_electricity', name: 'Current Electricity', subjectId: 'physics_adv', questionCount: 70),
        Topic(id: 'magnetism', name: 'Magnetism & EMI', subjectId: 'physics_adv', questionCount: 80),
        Topic(id: 'modern_physics', name: 'Modern Physics', subjectId: 'physics_adv', questionCount: 100, difficulty: 'hard'),
        Topic(id: 'semiconductors', name: 'Semiconductors', subjectId: 'physics_adv', questionCount: 50),
        Topic(id: 'rotational_mechanics', name: 'Rotational Mechanics', subjectId: 'physics_adv', questionCount: 60, difficulty: 'hard'),
      ],
    ),
    // Chemistry (Advanced) - JEE/NEET/GATE level
    Subject(
      id: 'chemistry_adv',
      name: 'Chemistry (Advanced)',
      shortName: 'Chemistry',
      icon: 'biotech',
      colorHex: '#14B8A6',
      topics: [
        Topic(id: 'atomic_structure', name: 'Atomic Structure', subjectId: 'chemistry_adv', questionCount: 60),
        Topic(id: 'periodic_table', name: 'Periodic Table & Periodicity', subjectId: 'chemistry_adv', questionCount: 50),
        Topic(id: 'chemical_bonding', name: 'Chemical Bonding', subjectId: 'chemistry_adv', questionCount: 80, difficulty: 'hard'),
        Topic(id: 'organic_chemistry', name: 'Organic Chemistry', subjectId: 'chemistry_adv', questionCount: 150, difficulty: 'hard'),
        Topic(id: 'inorganic_chemistry', name: 'Inorganic Chemistry', subjectId: 'chemistry_adv', questionCount: 100),
        Topic(id: 'physical_chemistry', name: 'Physical Chemistry', subjectId: 'chemistry_adv', questionCount: 120, difficulty: 'hard'),
        Topic(id: 'electrochemistry', name: 'Electrochemistry', subjectId: 'chemistry_adv', questionCount: 60),
        Topic(id: 'chemical_kinetics', name: 'Chemical Kinetics', subjectId: 'chemistry_adv', questionCount: 50),
        Topic(id: 'thermodynamics_chem', name: 'Thermodynamics', subjectId: 'chemistry_adv', questionCount: 70),
        Topic(id: 'coordination_compounds', name: 'Coordination Compounds', subjectId: 'chemistry_adv', questionCount: 50, difficulty: 'hard'),
      ],
    ),
    // Biology - NEET/UPSC level
    Subject(
      id: 'biology',
      name: 'Biology',
      shortName: 'Biology',
      icon: 'eco',
      colorHex: '#22C55E',
      topics: [
        Topic(id: 'cell_biology', name: 'Cell Biology', subjectId: 'biology', questionCount: 80),
        Topic(id: 'genetics', name: 'Genetics & Evolution', subjectId: 'biology', questionCount: 100, difficulty: 'hard'),
        Topic(id: 'human_physiology', name: 'Human Physiology', subjectId: 'biology', questionCount: 150),
        Topic(id: 'plant_physiology', name: 'Plant Physiology', subjectId: 'biology', questionCount: 80),
        Topic(id: 'ecology', name: 'Ecology & Environment', subjectId: 'biology', questionCount: 100),
        Topic(id: 'biotechnology', name: 'Biotechnology', subjectId: 'biology', questionCount: 70, difficulty: 'hard'),
        Topic(id: 'reproduction', name: 'Reproduction', subjectId: 'biology', questionCount: 80),
        Topic(id: 'diversity_living', name: 'Diversity in Living World', subjectId: 'biology', questionCount: 90),
        Topic(id: 'structural_org', name: 'Structural Organization', subjectId: 'biology', questionCount: 60),
        Topic(id: 'microorganisms', name: 'Microorganisms', subjectId: 'biology', questionCount: 50),
      ],
    ),
    // Mathematics (Higher) - JEE/CAT/GATE level
    Subject(
      id: 'math_higher',
      name: 'Mathematics (Higher)',
      shortName: 'Math',
      icon: 'functions',
      colorHex: '#6366F1',
      topics: [
        Topic(id: 'calculus', name: 'Calculus', subjectId: 'math_higher', questionCount: 150, difficulty: 'hard'),
        Topic(id: 'algebra_higher', name: 'Algebra', subjectId: 'math_higher', questionCount: 120, difficulty: 'hard'),
        Topic(id: 'coordinate_geometry', name: 'Coordinate Geometry', subjectId: 'math_higher', questionCount: 100),
        Topic(id: 'trigonometry', name: 'Trigonometry', subjectId: 'math_higher', questionCount: 80),
        Topic(id: 'vectors_3d', name: 'Vectors & 3D Geometry', subjectId: 'math_higher', questionCount: 80, difficulty: 'hard'),
        Topic(id: 'probability_stats', name: 'Probability & Statistics', subjectId: 'math_higher', questionCount: 100),
        Topic(id: 'matrices_determinants', name: 'Matrices & Determinants', subjectId: 'math_higher', questionCount: 70),
        Topic(id: 'complex_numbers', name: 'Complex Numbers', subjectId: 'math_higher', questionCount: 60, difficulty: 'hard'),
        Topic(id: 'differential_equations', name: 'Differential Equations', subjectId: 'math_higher', questionCount: 70, difficulty: 'hard'),
        Topic(id: 'permutation_combination', name: 'Permutation & Combination', subjectId: 'math_higher', questionCount: 60),
      ],
    ),
    // Indian History - UPSC/SSC/PSC
    Subject(
      id: 'history',
      name: 'Indian History',
      shortName: 'History',
      icon: 'history_edu',
      colorHex: '#A855F7',
      topics: [
        Topic(id: 'ancient_india', name: 'Ancient India', subjectId: 'history', questionCount: 100),
        Topic(id: 'medieval_india', name: 'Medieval India', subjectId: 'history', questionCount: 80),
        Topic(id: 'modern_india', name: 'Modern India', subjectId: 'history', questionCount: 120),
        Topic(id: 'freedom_struggle', name: 'Freedom Struggle', subjectId: 'history', questionCount: 100),
        Topic(id: 'post_independence', name: 'Post Independence', subjectId: 'history', questionCount: 50),
        Topic(id: 'art_culture', name: 'Art & Culture', subjectId: 'history', questionCount: 80),
        Topic(id: 'world_history', name: 'World History', subjectId: 'history', questionCount: 60),
        Topic(id: 'indian_heritage', name: 'Indian Heritage', subjectId: 'history', questionCount: 40),
      ],
    ),
    // Indian Polity - UPSC/SSC/PSC
    Subject(
      id: 'polity',
      name: 'Indian Polity',
      shortName: 'Polity',
      icon: 'account_balance',
      colorHex: '#DC2626',
      topics: [
        Topic(id: 'constitution', name: 'Indian Constitution', subjectId: 'polity', questionCount: 100),
        Topic(id: 'fundamental_rights', name: 'Fundamental Rights & Duties', subjectId: 'polity', questionCount: 60),
        Topic(id: 'parliament', name: 'Parliament', subjectId: 'polity', questionCount: 50),
        Topic(id: 'executive', name: 'Executive', subjectId: 'polity', questionCount: 50),
        Topic(id: 'judiciary', name: 'Judiciary', subjectId: 'polity', questionCount: 60),
        Topic(id: 'federalism', name: 'Federalism', subjectId: 'polity', questionCount: 40),
        Topic(id: 'local_govt', name: 'Local Government', subjectId: 'polity', questionCount: 40),
        Topic(id: 'constitutional_bodies', name: 'Constitutional Bodies', subjectId: 'polity', questionCount: 50),
        Topic(id: 'amendments', name: 'Constitutional Amendments', subjectId: 'polity', questionCount: 40),
        Topic(id: 'governance', name: 'Governance & Administration', subjectId: 'polity', questionCount: 50),
      ],
    ),
    // Geography - UPSC/SSC/Railways
    Subject(
      id: 'geography',
      name: 'Geography',
      shortName: 'Geography',
      icon: 'public',
      colorHex: '#0EA5E9',
      topics: [
        Topic(id: 'physical_geo', name: 'Physical Geography', subjectId: 'geography', questionCount: 80),
        Topic(id: 'indian_geo', name: 'Indian Geography', subjectId: 'geography', questionCount: 100),
        Topic(id: 'world_geo', name: 'World Geography', subjectId: 'geography', questionCount: 60),
        Topic(id: 'economic_geo', name: 'Economic Geography', subjectId: 'geography', questionCount: 50),
        Topic(id: 'climatology', name: 'Climatology', subjectId: 'geography', questionCount: 40),
        Topic(id: 'oceanography', name: 'Oceanography', subjectId: 'geography', questionCount: 30),
        Topic(id: 'human_geo', name: 'Human Geography', subjectId: 'geography', questionCount: 40),
        Topic(id: 'agriculture', name: 'Agriculture', subjectId: 'geography', questionCount: 50),
        Topic(id: 'industries_resources', name: 'Industries & Resources', subjectId: 'geography', questionCount: 50),
      ],
    ),
    // Economics - UPSC/RBI/Insurance
    Subject(
      id: 'economics',
      name: 'Economics',
      shortName: 'Economics',
      icon: 'trending_up',
      colorHex: '#059669',
      topics: [
        Topic(id: 'micro_economics', name: 'Microeconomics', subjectId: 'economics', questionCount: 60),
        Topic(id: 'macro_economics', name: 'Macroeconomics', subjectId: 'economics', questionCount: 70),
        Topic(id: 'indian_economy', name: 'Indian Economy', subjectId: 'economics', questionCount: 100),
        Topic(id: 'banking_finance', name: 'Banking & Finance', subjectId: 'economics', questionCount: 80),
        Topic(id: 'monetary_policy', name: 'Monetary Policy', subjectId: 'economics', questionCount: 50),
        Topic(id: 'fiscal_policy', name: 'Fiscal Policy', subjectId: 'economics', questionCount: 40),
        Topic(id: 'international_trade', name: 'International Trade', subjectId: 'economics', questionCount: 40),
        Topic(id: 'economic_planning', name: 'Economic Planning', subjectId: 'economics', questionCount: 40),
        Topic(id: 'budget', name: 'Budget & Taxation', subjectId: 'economics', questionCount: 50),
      ],
    ),
    // Environment - UPSC/SSC
    Subject(
      id: 'environment',
      name: 'Environment & Ecology',
      shortName: 'Environment',
      icon: 'forest',
      colorHex: '#16A34A',
      topics: [
        Topic(id: 'ecology_basics', name: 'Ecology Basics', subjectId: 'environment', questionCount: 50),
        Topic(id: 'biodiversity', name: 'Biodiversity', subjectId: 'environment', questionCount: 60),
        Topic(id: 'climate_change', name: 'Climate Change', subjectId: 'environment', questionCount: 50),
        Topic(id: 'pollution', name: 'Pollution', subjectId: 'environment', questionCount: 40),
        Topic(id: 'environmental_laws', name: 'Environmental Laws', subjectId: 'environment', questionCount: 40),
        Topic(id: 'conservation', name: 'Conservation', subjectId: 'environment', questionCount: 50),
        Topic(id: 'sustainable_dev', name: 'Sustainable Development', subjectId: 'environment', questionCount: 40),
        Topic(id: 'environmental_agreements', name: 'International Agreements', subjectId: 'environment', questionCount: 30),
      ],
    ),
    // Legal Aptitude - CLAT/AILET
    Subject(
      id: 'legal',
      name: 'Legal Aptitude',
      shortName: 'Legal',
      icon: 'gavel',
      colorHex: '#BE185D',
      topics: [
        Topic(id: 'legal_reasoning', name: 'Legal Reasoning', subjectId: 'legal', questionCount: 80),
        Topic(id: 'constitution_law', name: 'Constitutional Law', subjectId: 'legal', questionCount: 60),
        Topic(id: 'contract_law', name: 'Contract Law', subjectId: 'legal', questionCount: 50),
        Topic(id: 'tort_law', name: 'Law of Torts', subjectId: 'legal', questionCount: 40),
        Topic(id: 'criminal_law', name: 'Criminal Law', subjectId: 'legal', questionCount: 50),
        Topic(id: 'family_law', name: 'Family Law', subjectId: 'legal', questionCount: 30),
        Topic(id: 'ipc_crpc', name: 'IPC & CrPC', subjectId: 'legal', questionCount: 50),
        Topic(id: 'legal_maxims', name: 'Legal Maxims', subjectId: 'legal', questionCount: 30),
        Topic(id: 'current_legal', name: 'Current Legal Affairs', subjectId: 'legal', questionCount: 40),
      ],
    ),
    // Logical Reasoning (CAT) - CAT/XAT/SNAP
    Subject(
      id: 'lr_cat',
      name: 'Logical Reasoning (CAT)',
      shortName: 'LR-CAT',
      icon: 'psychology_alt',
      colorHex: '#7C3AED',
      topics: [
        Topic(id: 'arrangements', name: 'Arrangements', subjectId: 'lr_cat', questionCount: 80, difficulty: 'hard'),
        Topic(id: 'puzzles_cat', name: 'Puzzles', subjectId: 'lr_cat', questionCount: 100, difficulty: 'hard'),
        Topic(id: 'games_tournaments', name: 'Games & Tournaments', subjectId: 'lr_cat', questionCount: 50, difficulty: 'hard'),
        Topic(id: 'venn_diagrams', name: 'Venn Diagrams', subjectId: 'lr_cat', questionCount: 40),
        Topic(id: 'binary_logic', name: 'Binary Logic', subjectId: 'lr_cat', questionCount: 40, difficulty: 'hard'),
        Topic(id: 'logical_connectives', name: 'Logical Connectives', subjectId: 'lr_cat', questionCount: 30),
        Topic(id: 'constraints', name: 'Constraint-based Problems', subjectId: 'lr_cat', questionCount: 50, difficulty: 'hard'),
        Topic(id: 'critical_reasoning', name: 'Critical Reasoning', subjectId: 'lr_cat', questionCount: 60),
        Topic(id: 'decision_making', name: 'Decision Making', subjectId: 'lr_cat', questionCount: 50),
      ],
    ),
    // Data Interpretation (Advanced) - CAT/GATE/Banking
    Subject(
      id: 'di_advanced',
      name: 'Data Interpretation (Adv)',
      shortName: 'DI-Adv',
      icon: 'bar_chart',
      colorHex: '#D97706',
      topics: [
        Topic(id: 'tables_di', name: 'Tables', subjectId: 'di_advanced', questionCount: 60),
        Topic(id: 'bar_charts', name: 'Bar Charts', subjectId: 'di_advanced', questionCount: 50),
        Topic(id: 'pie_charts', name: 'Pie Charts', subjectId: 'di_advanced', questionCount: 40),
        Topic(id: 'line_graphs', name: 'Line Graphs', subjectId: 'di_advanced', questionCount: 50),
        Topic(id: 'mixed_graphs', name: 'Mixed Graphs', subjectId: 'di_advanced', questionCount: 60, difficulty: 'hard'),
        Topic(id: 'caselets', name: 'Caselets', subjectId: 'di_advanced', questionCount: 70, difficulty: 'hard'),
        Topic(id: 'data_sufficiency', name: 'Data Sufficiency', subjectId: 'di_advanced', questionCount: 50, difficulty: 'hard'),
        Topic(id: 'radar_funnel', name: 'Radar & Funnel Charts', subjectId: 'di_advanced', questionCount: 30),
      ],
    ),
  ];

  // Get subject by ID
  static Subject? getSubjectById(String id) {
    try {
      return subjects.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  // Get category by ID
  static ExamCategory? getCategoryById(String id) {
    try {
      return categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  // Get exam by ID
  static ExamType? getExamById(String id) {
    for (final category in categories) {
      try {
        return category.exams.firstWhere((e) => e.id == id);
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  // Get popular exams
  static List<ExamType> getPopularExams() {
    List<ExamType> popular = [];
    for (final category in categories) {
      popular.addAll(category.exams.where((e) => e.isPopular));
    }
    return popular;
  }

  // Get all exams
  static List<ExamType> getAllExams() {
    List<ExamType> all = [];
    for (final category in categories) {
      all.addAll(category.exams);
    }
    return all;
  }

  // Get topics by subject
  static List<Topic> getTopicsBySubject(String subjectId) {
    final subject = getSubjectById(subjectId);
    return subject?.topics ?? [];
  }
}
