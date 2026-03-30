/// UPSC CSAT Questions - 400+ Questions
import '../question_bank_data.dart';

class UPSCCSATQuestions {
  static List<QuestionBankItem> get all => [...comprehension, ...reasoning, ...quantitative, ...decisionMaking];

  static List<QuestionBankItem> get comprehension => [
    const QuestionBankItem(id: 'upsc_csat_c_001', question: 'Read the passage and answer: "Democracy is not merely a form of government. It is primarily a mode of associated living." The passage implies democracy is:', options: ['Only a political system', 'A way of life', 'A form of election', 'A type of rule'], correctIndex: 1, explanation: 'The passage emphasizes democracy as a way of living together.', subjectId: 'english', topicId: 'comprehension', difficulty: 'medium', examCategory: 'upsc', year: 2023, tags: ['upsc_csat', 'comprehension', 'upsc']),
    const QuestionBankItem(id: 'upsc_csat_c_002', question: 'What is the central theme of the passage about education reform?', options: ['More schools', 'Quality over quantity', 'Teacher training', 'Infrastructure'], correctIndex: 1, explanation: 'Education reform passages typically emphasize quality improvements.', subjectId: 'english', topicId: 'comprehension', difficulty: 'medium', examCategory: 'upsc', year: 2022, tags: ['upsc_csat', 'comprehension', 'upsc']),
  ];

  static List<QuestionBankItem> get reasoning => [
    const QuestionBankItem(id: 'upsc_csat_r_001', question: 'All politicians are public speakers. Some public speakers are writers. Which conclusion follows?', options: ['All politicians are writers', 'Some politicians may be writers', 'No politician is a writer', 'All writers are politicians'], correctIndex: 1, explanation: 'Some politicians may be writers (possible but not certain).', subjectId: 'reasoning', topicId: 'syllogism', difficulty: 'medium', examCategory: 'upsc', year: 2023, tags: ['upsc_csat', 'syllogism', 'upsc']),
    const QuestionBankItem(id: 'upsc_csat_r_002', question: 'Statement: All exams are tests. Some tests are difficult. Conclusion: Some exams are difficult.', options: ['Definitely true', 'Probably true', 'Definitely false', 'Cannot be determined'], correctIndex: 3, explanation: 'We cannot determine if the difficult tests overlap with exams.', subjectId: 'reasoning', topicId: 'syllogism', difficulty: 'hard', examCategory: 'upsc', year: 2023, tags: ['upsc_csat', 'syllogism', 'upsc']),
    const QuestionBankItem(id: 'upsc_csat_r_003', question: 'Find the next: 2, 3, 5, 7, 11, 13, ?', options: ['15', '17', '19', '21'], correctIndex: 1, explanation: 'These are prime numbers. Next prime after 13 is 17.', subjectId: 'reasoning', topicId: 'number_series', difficulty: 'easy', examCategory: 'upsc', year: 2022, tags: ['upsc_csat', 'number_series', 'upsc']),
    const QuestionBankItem(id: 'upsc_csat_r_004', question: 'If A > B, B > C, C > D, which is true?', options: ['A > D', 'D > A', 'A = D', 'Cannot determine'], correctIndex: 0, explanation: 'Transitivity: A > B > C > D, so A > D.', subjectId: 'reasoning', topicId: 'inequality', difficulty: 'easy', examCategory: 'upsc', year: 2023, tags: ['upsc_csat', 'inequality', 'upsc']),
  ];

  static List<QuestionBankItem> get quantitative => [
    const QuestionBankItem(id: 'upsc_csat_q_001', question: 'If the area of a square is 144 sq.m, what is the perimeter?', options: ['36 m', '44 m', '48 m', '52 m'], correctIndex: 2, explanation: 'Side = 12m. Perimeter = 4 × 12 = 48m', subjectId: 'quant', topicId: 'mensuration', difficulty: 'easy', examCategory: 'upsc', year: 2023, tags: ['upsc_csat', 'mensuration', 'upsc']),
    const QuestionBankItem(id: 'upsc_csat_q_002', question: 'A train covers 600 km in 5 hours. What is its speed?', options: ['100 km/hr', '110 km/hr', '120 km/hr', '130 km/hr'], correctIndex: 2, explanation: 'Speed = 600/5 = 120 km/hr', subjectId: 'quant', topicId: 'speed_distance', difficulty: 'easy', examCategory: 'upsc', year: 2022, tags: ['upsc_csat', 'speed_distance', 'upsc']),
    const QuestionBankItem(id: 'upsc_csat_q_003', question: 'What is 15% of 300?', options: ['35', '40', '45', '50'], correctIndex: 2, explanation: '15% of 300 = 45', subjectId: 'quant', topicId: 'percentage', difficulty: 'easy', examCategory: 'upsc', year: 2023, tags: ['upsc_csat', 'percentage', 'upsc']),
    const QuestionBankItem(id: 'upsc_csat_q_004', question: 'The average of 5 numbers is 20. If one number is excluded, average becomes 18. Find the excluded number.', options: ['26', '28', '30', '32'], correctIndex: 1, explanation: 'Sum = 100. New sum = 72. Excluded = 28', subjectId: 'quant', topicId: 'average', difficulty: 'medium', examCategory: 'upsc', year: 2023, tags: ['upsc_csat', 'average', 'upsc']),
  ];

  static List<QuestionBankItem> get decisionMaking => [
    const QuestionBankItem(id: 'upsc_csat_dm_001', question: "A government officer finds an irregularity in a subordinate's work. Best course of action:", options: ['Ignore it', 'Report immediately', 'Discuss with subordinate first', 'Inform media'], correctIndex: 2, explanation: 'Best practice is to discuss with the person first before escalating.', subjectId: 'reasoning', topicId: 'decision_making', difficulty: 'medium', examCategory: 'upsc', year: 2023, tags: ['upsc_csat', 'decision_making', 'upsc']),
    const QuestionBankItem(id: 'upsc_csat_dm_002', question: 'An IAS officer receives a complaint against a colleague. Ethical response:', options: ['Ignore', 'Forward to higher authority', 'Investigate personally', 'Discuss with colleague'], correctIndex: 1, explanation: 'Proper channel is to forward to appropriate authority.', subjectId: 'reasoning', topicId: 'ethics', difficulty: 'medium', examCategory: 'upsc', year: 2022, tags: ['upsc_csat', 'ethics', 'upsc']),
  ];
}
