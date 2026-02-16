import 'package:flutter/material.dart';

enum ExamCategory {
  banking,
  engineering,
  medical,
  civil,
  defence,
  teaching,
  stateLevel,
  railway,
  ssc,
  upsc,
  international,
  university,
  other,
}

extension ExamCategoryExtension on ExamCategory {
  String get name {
    switch (this) {
      case ExamCategory.banking:
        return 'Banking';
      case ExamCategory.engineering:
        return 'Engineering';
      case ExamCategory.medical:
        return 'Medical';
      case ExamCategory.civil:
        return 'Civil Services';
      case ExamCategory.defence:
        return 'Defence';
      case ExamCategory.teaching:
        return 'Teaching';
      case ExamCategory.stateLevel:
        return 'State Level';
      case ExamCategory.railway:
        return 'Railway';
      case ExamCategory.ssc:
        return 'SSC';
      case ExamCategory.upsc:
        return 'UPSC';
      case ExamCategory.international:
        return 'International';
      case ExamCategory.university:
        return 'University';
      case ExamCategory.other:
        return 'Other';
    }
  }

  String get emoji {
    switch (this) {
      case ExamCategory.banking:
        return '🏦';
      case ExamCategory.engineering:
        return '⚙️';
      case ExamCategory.medical:
        return '🏥';
      case ExamCategory.civil:
        return '🏛️';
      case ExamCategory.defence:
        return '🎖️';
      case ExamCategory.teaching:
        return '👨‍🏫';
      case ExamCategory.stateLevel:
        return '🏢';
      case ExamCategory.railway:
        return '🚂';
      case ExamCategory.ssc:
        return '📋';
      case ExamCategory.upsc:
        return '🇮🇳';
      case ExamCategory.international:
        return '🌍';
      case ExamCategory.university:
        return '🎓';
      case ExamCategory.other:
        return '📚';
    }
  }

  Color get color {
    switch (this) {
      case ExamCategory.banking:
        return const Color(0xFF1E88E5);
      case ExamCategory.engineering:
        return const Color(0xFF7C3AED);
      case ExamCategory.medical:
        return const Color(0xFFE91E63);
      case ExamCategory.civil:
        return const Color(0xFFFF6F00);
      case ExamCategory.defence:
        return const Color(0xFF2E7D32);
      case ExamCategory.teaching:
        return const Color(0xFF00ACC1);
      case ExamCategory.stateLevel:
        return const Color(0xFF5C6BC0);
      case ExamCategory.railway:
        return const Color(0xFF8D6E63);
      case ExamCategory.ssc:
        return const Color(0xFFEC407A);
      case ExamCategory.upsc:
        return const Color(0xFFFF7043);
      case ExamCategory.international:
        return const Color(0xFF26A69A);
      case ExamCategory.university:
        return const Color(0xFF9C27B0);
      case ExamCategory.other:
        return const Color(0xFF78909C);
    }
  }

  List<String> get popularExams {
    switch (this) {
      case ExamCategory.banking:
        return ['IBPS PO', 'IBPS Clerk', 'SBI PO', 'SBI Clerk', 'RBI Grade B', 'NABARD', 'SEBI'];
      case ExamCategory.engineering:
        return ['JEE Main', 'JEE Advanced', 'GATE', 'BITSAT', 'VITEEE', 'SRMJEEE', 'MHT CET'];
      case ExamCategory.medical:
        return ['NEET UG', 'NEET PG', 'AIIMS', 'JIPMER', 'FMGE', 'NEET SS'];
      case ExamCategory.civil:
        return ['UPSC CSE', 'State PSC', 'IFS', 'IES/ESE', 'CDS', 'NDA'];
      case ExamCategory.defence:
        return ['NDA', 'CDS', 'AFCAT', 'Indian Navy', 'Indian Army', 'CAPF'];
      case ExamCategory.teaching:
        return ['CTET', 'State TET', 'UGC NET', 'CSIR NET', 'SET', 'KVS', 'NVS'];
      case ExamCategory.stateLevel:
        return ['State PSC', 'State Police', 'State SSC', 'Patwari', 'Gram Sevak'];
      case ExamCategory.railway:
        return ['RRB NTPC', 'RRB Group D', 'RRB JE', 'RRB ALP', 'RPF'];
      case ExamCategory.ssc:
        return ['SSC CGL', 'SSC CHSL', 'SSC MTS', 'SSC GD', 'SSC JE', 'SSC Steno'];
      case ExamCategory.upsc:
        return ['UPSC CSE', 'UPSC CMS', 'UPSC IES', 'UPSC CDS', 'UPSC NDA', 'UPSC CAPF'];
      case ExamCategory.international:
        return ['GRE', 'GMAT', 'TOEFL', 'IELTS', 'SAT', 'ACT', 'LSAT', 'MCAT'];
      case ExamCategory.university:
        return ['CUET', 'DUET', 'JNU', 'BHU', 'AMU', 'CLAT', 'AILET'];
      case ExamCategory.other:
        return ['Custom Exam'];
    }
  }
}

class ExamType {
  final String id;
  final String name;
  final ExamCategory category;
  final DateTime? examDate;
  final String? description;
  final List<String> subjects;
  final int? totalMarks;
  final int? passingMarks;
  final int? durationMinutes;
  final bool isActive;
  final DateTime createdAt;

  ExamType({
    required this.id,
    required this.name,
    required this.category,
    this.examDate,
    this.description,
    this.subjects = const [],
    this.totalMarks,
    this.passingMarks,
    this.durationMinutes,
    this.isActive = true,
    required this.createdAt,
  });

  int get daysUntilExam {
    if (examDate == null) return -1;
    return examDate!.difference(DateTime.now()).inDays;
  }

  bool get isUpcoming => examDate != null && examDate!.isAfter(DateTime.now());

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category.index,
        'examDate': examDate?.toIso8601String(),
        'description': description,
        'subjects': subjects,
        'totalMarks': totalMarks,
        'passingMarks': passingMarks,
        'durationMinutes': durationMinutes,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ExamType.fromJson(Map<String, dynamic> json) => ExamType(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        category: ExamCategory.values[json['category'] ?? 0],
        examDate: json['examDate'] != null ? DateTime.parse(json['examDate']) : null,
        description: json['description'],
        subjects: List<String>.from(json['subjects'] ?? []),
        totalMarks: json['totalMarks'],
        passingMarks: json['passingMarks'],
        durationMinutes: json['durationMinutes'],
        isActive: json['isActive'] ?? true,
        createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      );

  ExamType copyWith({
    String? id,
    String? name,
    ExamCategory? category,
    DateTime? examDate,
    String? description,
    List<String>? subjects,
    int? totalMarks,
    int? passingMarks,
    int? durationMinutes,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return ExamType(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      examDate: examDate ?? this.examDate,
      description: description ?? this.description,
      subjects: subjects ?? this.subjects,
      totalMarks: totalMarks ?? this.totalMarks,
      passingMarks: passingMarks ?? this.passingMarks,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
