/// Study Materials Barrel File
/// Exports all exam-specific study materials

export 'banking_study_materials.dart';
export 'ssc_study_materials.dart';
export 'jee_study_materials.dart';
export 'neet_study_materials.dart';
export 'cat_study_materials.dart';
export 'gate_study_materials.dart';
export 'upsc_study_materials.dart';
export 'clat_study_materials.dart';

import '../../models/study_material_model.dart';
import 'banking_study_materials.dart';
import 'ssc_study_materials.dart';
import 'jee_study_materials.dart';
import 'neet_study_materials.dart';
import 'cat_study_materials.dart';
import 'gate_study_materials.dart';
import 'upsc_study_materials.dart';
import 'clat_study_materials.dart';

/// Combined list of all study materials across all exams
final List<StudyMaterial> allStudyMaterials = [
  ...BankingStudyMaterials.getAll(),
  ...sscStudyMaterials,
  ...jeeStudyMaterials,
  ...neetStudyMaterials,
  ...catStudyMaterials,
  ...gateStudyMaterials,
  ...upscStudyMaterials,
  ...clatStudyMaterials,
];

/// Get study materials by exam type
List<StudyMaterial> getStudyMaterialsByExam(String examId) {
  switch (examId.toLowerCase()) {
    case 'banking':
    case 'ibps':
    case 'sbi':
    case 'rbi':
      return BankingStudyMaterials.getAll();
    case 'ssc':
    case 'ssc_cgl':
    case 'ssc_chsl':
      return sscStudyMaterials;
    case 'jee':
    case 'jee_main':
    case 'jee_advanced':
      return jeeStudyMaterials;
    case 'neet':
    case 'neet_ug':
      return neetStudyMaterials;
    case 'cat':
    case 'mba':
      return catStudyMaterials;
    case 'gate':
    case 'gate_cs':
      return gateStudyMaterials;
    case 'upsc':
    case 'ias':
    case 'civil_services':
      return upscStudyMaterials;
    case 'clat':
    case 'law':
      return clatStudyMaterials;
    default:
      return allStudyMaterials;
  }
}

/// Get study materials by subject
List<StudyMaterial> getStudyMaterialsBySubject(String subjectId) {
  return allStudyMaterials
      .where((material) => material.subjectId == subjectId)
      .toList();
}

/// Get study materials by topic
List<StudyMaterial> getStudyMaterialsByTopic(String topicId) {
  return allStudyMaterials
      .where((material) => material.topicId == topicId)
      .toList();
}

/// Get study materials by type
List<StudyMaterial> getStudyMaterialsByType(StudyMaterialType type) {
  return allStudyMaterials
      .where((material) => material.type == type)
      .toList();
}

/// Search study materials by keyword
List<StudyMaterial> searchStudyMaterials(String query) {
  final lowercaseQuery = query.toLowerCase();
  return allStudyMaterials.where((material) {
    return material.title.toLowerCase().contains(lowercaseQuery) ||
        material.description.toLowerCase().contains(lowercaseQuery) ||
        material.tags.any((tag) => tag.toLowerCase().contains(lowercaseQuery));
  }).toList();
}

/// Get study material by ID
StudyMaterial? getStudyMaterialById(String id) {
  try {
    return allStudyMaterials.firstWhere((material) => material.id == id);
  } catch (e) {
    return null;
  }
}

/// Get top rated study materials
List<StudyMaterial> getTopRatedMaterials({int limit = 10}) {
  final sorted = List<StudyMaterial>.from(allStudyMaterials)
    ..sort((a, b) => b.rating.compareTo(a.rating));
  return sorted.take(limit).toList();
}

/// Get study materials stats
Map<String, dynamic> getStudyMaterialsStats() {
  return {
    'totalMaterials': allStudyMaterials.length,
    'byExam': {
      'banking': BankingStudyMaterials.getAll().length,
      'ssc': sscStudyMaterials.length,
      'jee': jeeStudyMaterials.length,
      'neet': neetStudyMaterials.length,
      'cat': catStudyMaterials.length,
      'gate': gateStudyMaterials.length,
      'upsc': upscStudyMaterials.length,
      'clat': clatStudyMaterials.length,
    },
    'byType': {
      'notes': allStudyMaterials.where((m) => m.type == StudyMaterialType.notes).length,
      'formula': allStudyMaterials.where((m) => m.type == StudyMaterialType.formula).length,
      'shortcut': allStudyMaterials.where((m) => m.type == StudyMaterialType.shortcut).length,
    },
    'totalReadTime': allStudyMaterials.fold<int>(0, (sum, m) => sum + m.estimatedReadTime),
    'averageRating': allStudyMaterials.isEmpty
        ? 0.0
        : allStudyMaterials.fold<double>(0, (sum, m) => sum + m.rating) / allStudyMaterials.length,
  };
}
