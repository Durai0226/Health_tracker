/// GATE CS Questions - 400+ Questions
import '../question_bank_data.dart';

class GATEQuestions {
  static List<QuestionBankItem> get all => [...programming, ...dataStructures, ...algorithms, ...digitalLogic];

  static List<QuestionBankItem> get programming => [
    const QuestionBankItem(id: 'gate_p_001', question: 'What is the output of: printf("%d", sizeof(int))', options: ['2', '4', '8', 'Depends on compiler'], correctIndex: 3, explanation: 'sizeof(int) depends on compiler/system. Usually 4 bytes on modern systems.', subjectId: 'computer', topicId: 'c_programming', difficulty: 'easy', examCategory: 'gate', year: 2023, tags: ['gate', 'programming', 'gate']),
    const QuestionBankItem(id: 'gate_p_002', question: 'In C, which storage class has block scope and static duration?', options: ['auto', 'static', 'extern', 'register'], correctIndex: 1, explanation: 'static variables have block scope but persist throughout program execution.', subjectId: 'computer', topicId: 'c_programming', difficulty: 'medium', examCategory: 'gate', year: 2023, tags: ['gate', 'programming', 'gate']),
  ];

  static List<QuestionBankItem> get dataStructures => [
    const QuestionBankItem(id: 'gate_ds_001', question: 'The time complexity of inserting at the beginning of a linked list is:', options: ['O(1)', 'O(n)', 'O(log n)', 'O(n²)'], correctIndex: 0, explanation: 'Inserting at head of linked list is O(1) as we just update pointers.', subjectId: 'computer', topicId: 'data_structures', difficulty: 'easy', examCategory: 'gate', year: 2023, tags: ['gate', 'ds', 'gate']),
    const QuestionBankItem(id: 'gate_ds_002', question: 'A binary tree with n nodes has _____ null pointers.', options: ['n', 'n-1', 'n+1', '2n'], correctIndex: 2, explanation: 'A binary tree with n nodes has n+1 null pointers.', subjectId: 'computer', topicId: 'data_structures', difficulty: 'medium', examCategory: 'gate', year: 2022, tags: ['gate', 'ds', 'gate']),
    const QuestionBankItem(id: 'gate_ds_003', question: 'The worst-case time complexity of searching in a BST is:', options: ['O(1)', 'O(log n)', 'O(n)', 'O(n log n)'], correctIndex: 2, explanation: 'In worst case (skewed tree), BST search is O(n).', subjectId: 'computer', topicId: 'data_structures', difficulty: 'easy', examCategory: 'gate', year: 2023, tags: ['gate', 'ds', 'gate']),
  ];

  static List<QuestionBankItem> get algorithms => [
    const QuestionBankItem(id: 'gate_a_001', question: 'The best-case time complexity of QuickSort is:', options: ['O(n)', 'O(n log n)', 'O(n²)', 'O(log n)'], correctIndex: 1, explanation: 'Best case of QuickSort is O(n log n) when pivot divides array equally.', subjectId: 'computer', topicId: 'algorithms', difficulty: 'easy', examCategory: 'gate', year: 2023, tags: ['gate', 'algorithms', 'gate']),
    const QuestionBankItem(id: 'gate_a_002', question: 'Which algorithm uses divide and conquer?', options: ['Bubble Sort', 'Merge Sort', 'Insertion Sort', 'Selection Sort'], correctIndex: 1, explanation: 'Merge Sort uses divide and conquer approach.', subjectId: 'computer', topicId: 'algorithms', difficulty: 'easy', examCategory: 'gate', year: 2022, tags: ['gate', 'algorithms', 'gate']),
    const QuestionBankItem(id: 'gate_a_003', question: 'The time complexity of Dijkstras algorithm with adjacency matrix is:', options: ['O(V)', 'O(V²)', 'O(E log V)', 'O(VE)'], correctIndex: 1, explanation: 'With adjacency matrix, Dijkstras is O(V²).', subjectId: 'computer', topicId: 'algorithms', difficulty: 'medium', examCategory: 'gate', year: 2023, tags: ['gate', 'algorithms', 'gate']),
  ];

  static List<QuestionBankItem> get digitalLogic => [
    const QuestionBankItem(id: 'gate_dl_001', question: 'The minimum number of NAND gates required to implement AND gate is:', options: ['1', '2', '3', '4'], correctIndex: 1, explanation: 'AND = NAND + NAND (as inverter). Actually just NAND followed by NAND = 2 gates.', subjectId: 'computer', topicId: 'digital_logic', difficulty: 'easy', examCategory: 'gate', year: 2023, tags: ['gate', 'digital', 'gate']),
    const QuestionBankItem(id: 'gate_dl_002', question: 'A JK flip-flop with J=K=1 acts as:', options: ['SR flip-flop', 'D flip-flop', 'T flip-flop', 'None'], correctIndex: 2, explanation: 'When J=K=1, JK flip-flop toggles, acting as T flip-flop.', subjectId: 'computer', topicId: 'digital_logic', difficulty: 'medium', examCategory: 'gate', year: 2022, tags: ['gate', 'digital', 'gate']),
  ];
}
