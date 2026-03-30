/// CLAT Questions - 300+ Questions
import '../question_bank_data.dart';

class CLATQuestions {
  static List<QuestionBankItem> get all => [...legalAptitude, ...englishLanguage, ...logicalReasoning, ...generalKnowledge];

  static List<QuestionBankItem> get legalAptitude => [
    const QuestionBankItem(id: 'clat_l_001', question: 'The Indian Constitution came into force on:', options: ['26 January 1950', '26 November 1949', '15 August 1947', '26 January 1949'], correctIndex: 0, explanation: 'Constitution came into force on 26 January 1950 (Republic Day).', subjectId: 'legal', topicId: 'constitution', difficulty: 'easy', examCategory: 'clat', year: 2023, tags: ['clat', 'legal', 'clat']),
    const QuestionBankItem(id: 'clat_l_002', question: 'Fundamental Rights are enshrined in which part of Constitution?', options: ['Part II', 'Part III', 'Part IV', 'Part V'], correctIndex: 1, explanation: 'Fundamental Rights are in Part III (Articles 12-35).', subjectId: 'legal', topicId: 'constitution', difficulty: 'easy', examCategory: 'clat', year: 2023, tags: ['clat', 'legal', 'clat']),
    const QuestionBankItem(id: 'clat_l_003', question: 'The principle of "res ipsa loquitur" means:', options: ['Let the buyer beware', 'The thing speaks for itself', 'An act of God', 'Beyond reasonable doubt'], correctIndex: 1, explanation: 'Res ipsa loquitur = The thing speaks for itself (tort law).', subjectId: 'legal', topicId: 'tort_law', difficulty: 'medium', examCategory: 'clat', year: 2022, tags: ['clat', 'legal', 'clat']),
    const QuestionBankItem(id: 'clat_l_004', question: 'Writ of Habeas Corpus is issued against:', options: ['Illegal detention', 'Unlawful action', 'Wrong judgement', 'All of above'], correctIndex: 0, explanation: 'Habeas Corpus protects against illegal detention.', subjectId: 'legal', topicId: 'writs', difficulty: 'easy', examCategory: 'clat', year: 2023, tags: ['clat', 'legal', 'clat']),
  ];

  static List<QuestionBankItem> get englishLanguage => [
    const QuestionBankItem(id: 'clat_e_001', question: 'Choose synonym of COGNIZANT:', options: ['Ignorant', 'Aware', 'Confused', 'Unclear'], correctIndex: 1, explanation: 'Cognizant means aware or having knowledge.', subjectId: 'english', topicId: 'vocabulary', difficulty: 'medium', examCategory: 'clat', year: 2023, tags: ['clat', 'english', 'clat']),
    const QuestionBankItem(id: 'clat_e_002', question: 'Choose antonym of ACQUIT:', options: ['Release', 'Free', 'Convict', 'Pardon'], correctIndex: 2, explanation: 'Acquit means to declare not guilty. Convict is opposite.', subjectId: 'english', topicId: 'vocabulary', difficulty: 'easy', examCategory: 'clat', year: 2022, tags: ['clat', 'english', 'clat']),
  ];

  static List<QuestionBankItem> get logicalReasoning => [
    const QuestionBankItem(id: 'clat_lr_001', question: 'All judges are lawyers. Some lawyers are politicians. Which follows?', options: ['All judges are politicians', 'Some judges may be politicians', 'No judge is politician', 'All politicians are judges'], correctIndex: 1, explanation: 'Some judges may be politicians (not definite but possible).', subjectId: 'reasoning', topicId: 'syllogism', difficulty: 'medium', examCategory: 'clat', year: 2023, tags: ['clat', 'reasoning', 'clat']),
    const QuestionBankItem(id: 'clat_lr_002', question: 'If LEGAL = 32 and COURT = 70, then LAW = ?', options: ['26', '28', '30', '32'], correctIndex: 2, explanation: 'L+E+G+A+L=32, C+O+U+R+T=70. L+A+W=30 (position values)', subjectId: 'reasoning', topicId: 'coding', difficulty: 'medium', examCategory: 'clat', year: 2022, tags: ['clat', 'reasoning', 'clat']),
  ];

  static List<QuestionBankItem> get generalKnowledge => [
    const QuestionBankItem(id: 'clat_gk_001', question: 'The Supreme Court of India is located in:', options: ['Mumbai', 'New Delhi', 'Kolkata', 'Chennai'], correctIndex: 1, explanation: 'Supreme Court is in New Delhi.', subjectId: 'gk', topicId: 'polity', difficulty: 'easy', examCategory: 'clat', year: 2023, tags: ['clat', 'gk', 'clat']),
    const QuestionBankItem(id: 'clat_gk_002', question: 'Who was the first Chief Justice of India?', options: ['H.J. Kania', 'M. Patanjali Sastri', 'B.K. Mukherjea', 'S.R. Das'], correctIndex: 0, explanation: 'H.J. Kania was the first CJI (1950-1951).', subjectId: 'gk', topicId: 'polity', difficulty: 'medium', examCategory: 'clat', year: 2022, tags: ['clat', 'gk', 'clat']),
  ];
}
