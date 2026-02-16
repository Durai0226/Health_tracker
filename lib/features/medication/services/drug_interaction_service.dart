import '../models/medicine_enums.dart';
import '../models/drug_interaction.dart';

/// Premium feature: Drug Interaction Checker Service
/// Provides comprehensive drug interaction checking like Medisafe premium
class DrugInteractionService {
  static final DrugInteractionService _instance = DrugInteractionService._internal();
  factory DrugInteractionService() => _instance;
  DrugInteractionService._internal();

  /// Check interactions between two drugs
  List<DrugInteraction> checkInteraction(String drug1, String drug2) {
    final interactions = <DrugInteraction>[];
    final d1 = _normalizeDrugName(drug1);
    final d2 = _normalizeDrugName(drug2);

    for (final interaction in _interactionDatabase) {
      final name1 = _normalizeDrugName(interaction.drug1Name);
      final name2 = _normalizeDrugName(interaction.drug2Name);

      if ((d1.contains(name1) || name1.contains(d1)) && 
          (d2.contains(name2) || name2.contains(d2))) {
        interactions.add(interaction);
      } else if ((d1.contains(name2) || name2.contains(d1)) && 
                 (d2.contains(name1) || name1.contains(d2))) {
        interactions.add(interaction);
      }
    }

    return interactions;
  }

  /// Check all interactions for a list of medicines
  List<DrugInteraction> checkAllInteractions(List<String> drugNames) {
    final interactions = <DrugInteraction>[];
    final checked = <String>{};

    for (int i = 0; i < drugNames.length; i++) {
      for (int j = i + 1; j < drugNames.length; j++) {
        final key = '${drugNames[i]}_${drugNames[j]}';
        if (!checked.contains(key)) {
          checked.add(key);
          interactions.addAll(checkInteraction(drugNames[i], drugNames[j]));
        }
      }
    }

    // Sort by severity (most severe first)
    interactions.sort((a, b) => b.severity.index.compareTo(a.severity.index));
    return interactions;
  }

  /// Get drug information
  DrugInfo? getDrugInfo(String drugName) {
    final normalized = _normalizeDrugName(drugName);
    for (final info in _drugDatabase) {
      if (_normalizeDrugName(info.genericName).contains(normalized) ||
          normalized.contains(_normalizeDrugName(info.genericName))) {
        return info;
      }
      for (final brand in info.brandNames) {
        if (_normalizeDrugName(brand).contains(normalized) ||
            normalized.contains(_normalizeDrugName(brand))) {
          return info;
        }
      }
    }
    return null;
  }

  /// Search drugs by name
  List<DrugInfo> searchDrugs(String query) {
    if (query.isEmpty) return [];
    final normalized = _normalizeDrugName(query);
    
    return _drugDatabase.where((info) {
      if (_normalizeDrugName(info.genericName).contains(normalized)) return true;
      for (final brand in info.brandNames) {
        if (_normalizeDrugName(brand).contains(normalized)) return true;
      }
      return false;
    }).toList();
  }

  /// Check food interactions
  List<String> checkFoodInteractions(String drugName) {
    final info = getDrugInfo(drugName);
    return info?.foodInteractions ?? [];
  }

  String _normalizeDrugName(String name) {
    return name.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  // ============ DRUG INTERACTION DATABASE ============
  // Comprehensive database of common drug interactions
  static final List<DrugInteraction> _interactionDatabase = [
    // Blood Thinners
    DrugInteraction(
      id: 'int_001',
      drug1Name: 'Warfarin',
      drug2Name: 'Aspirin',
      severity: InteractionSeverity.severe,
      description: 'Increased risk of bleeding when taken together.',
      recommendation: 'Avoid combination unless specifically prescribed. Monitor for signs of bleeding.',
      mechanism: 'Both drugs affect blood clotting through different mechanisms.',
    ),
    DrugInteraction(
      id: 'int_002',
      drug1Name: 'Warfarin',
      drug2Name: 'Ibuprofen',
      severity: InteractionSeverity.severe,
      description: 'NSAIDs increase bleeding risk with warfarin.',
      recommendation: 'Avoid NSAIDs. Use acetaminophen for pain relief instead.',
      mechanism: 'NSAIDs inhibit platelet function and may cause GI bleeding.',
    ),
    DrugInteraction(
      id: 'int_003',
      drug1Name: 'Warfarin',
      drug2Name: 'Vitamin K',
      severity: InteractionSeverity.moderate,
      description: 'Vitamin K can reduce warfarin effectiveness.',
      recommendation: 'Maintain consistent vitamin K intake. Inform your doctor about diet changes.',
      mechanism: 'Vitamin K is essential for clotting factor synthesis.',
    ),
    
    // Statins
    DrugInteraction(
      id: 'int_004',
      drug1Name: 'Simvastatin',
      drug2Name: 'Grapefruit',
      severity: InteractionSeverity.moderate,
      description: 'Grapefruit juice increases statin levels significantly.',
      recommendation: 'Avoid grapefruit and grapefruit juice.',
      mechanism: 'Grapefruit inhibits CYP3A4 enzyme that metabolizes the drug.',
    ),
    DrugInteraction(
      id: 'int_005',
      drug1Name: 'Atorvastatin',
      drug2Name: 'Clarithromycin',
      severity: InteractionSeverity.severe,
      description: 'Increased risk of muscle damage (rhabdomyolysis).',
      recommendation: 'Consider temporary statin discontinuation or use azithromycin.',
      mechanism: 'Clarithromycin inhibits statin metabolism.',
    ),

    // Blood Pressure Medications
    DrugInteraction(
      id: 'int_006',
      drug1Name: 'Lisinopril',
      drug2Name: 'Potassium',
      severity: InteractionSeverity.moderate,
      description: 'Risk of dangerously high potassium levels.',
      recommendation: 'Monitor potassium levels. Avoid potassium supplements unless prescribed.',
      mechanism: 'ACE inhibitors reduce potassium excretion.',
    ),
    DrugInteraction(
      id: 'int_007',
      drug1Name: 'Amlodipine',
      drug2Name: 'Simvastatin',
      severity: InteractionSeverity.moderate,
      description: 'Increased statin levels may cause muscle problems.',
      recommendation: 'Limit simvastatin dose to 20mg daily when combined.',
      mechanism: 'Amlodipine inhibits statin metabolism.',
    ),
    DrugInteraction(
      id: 'int_008',
      drug1Name: 'Metoprolol',
      drug2Name: 'Verapamil',
      severity: InteractionSeverity.severe,
      description: 'Risk of severe bradycardia and heart block.',
      recommendation: 'Avoid combination. Monitor heart rate closely if used together.',
      mechanism: 'Both drugs slow heart rate and conduction.',
    ),

    // Diabetes Medications
    DrugInteraction(
      id: 'int_009',
      drug1Name: 'Metformin',
      drug2Name: 'Alcohol',
      severity: InteractionSeverity.moderate,
      description: 'Increased risk of lactic acidosis.',
      recommendation: 'Limit alcohol intake. Avoid binge drinking.',
      mechanism: 'Both affect lactate metabolism.',
    ),
    DrugInteraction(
      id: 'int_010',
      drug1Name: 'Glipizide',
      drug2Name: 'Aspirin',
      severity: InteractionSeverity.mild,
      description: 'May enhance blood sugar lowering effect.',
      recommendation: 'Monitor blood sugar more frequently.',
      mechanism: 'Aspirin may increase insulin sensitivity.',
    ),

    // Antibiotics
    DrugInteraction(
      id: 'int_011',
      drug1Name: 'Ciprofloxacin',
      drug2Name: 'Antacids',
      severity: InteractionSeverity.moderate,
      description: 'Antacids reduce antibiotic absorption significantly.',
      recommendation: 'Take ciprofloxacin 2 hours before or 6 hours after antacids.',
      mechanism: 'Metal ions in antacids bind to the antibiotic.',
    ),
    DrugInteraction(
      id: 'int_012',
      drug1Name: 'Metronidazole',
      drug2Name: 'Alcohol',
      severity: InteractionSeverity.severe,
      description: 'Severe nausea, vomiting, flushing, and headache.',
      recommendation: 'Avoid alcohol during treatment and 3 days after.',
      mechanism: 'Disulfiram-like reaction inhibits alcohol metabolism.',
    ),
    DrugInteraction(
      id: 'int_013',
      drug1Name: 'Amoxicillin',
      drug2Name: 'Birth Control',
      severity: InteractionSeverity.mild,
      description: 'May slightly reduce contraceptive effectiveness.',
      recommendation: 'Use backup contraception during antibiotic treatment.',
      mechanism: 'Antibiotics may affect gut bacteria that recycle estrogen.',
    ),
    DrugInteraction(
      id: 'int_014',
      drug1Name: 'Doxycycline',
      drug2Name: 'Calcium',
      severity: InteractionSeverity.moderate,
      description: 'Calcium reduces antibiotic absorption.',
      recommendation: 'Take doxycycline 2 hours before or after calcium supplements/dairy.',
      mechanism: 'Calcium forms insoluble complexes with the antibiotic.',
    ),

    // Pain Medications
    DrugInteraction(
      id: 'int_015',
      drug1Name: 'Tramadol',
      drug2Name: 'SSRI',
      severity: InteractionSeverity.severe,
      description: 'Risk of serotonin syndrome - potentially life-threatening.',
      recommendation: 'Use alternative pain medication or monitor closely.',
      mechanism: 'Both drugs increase serotonin levels.',
    ),
    DrugInteraction(
      id: 'int_016',
      drug1Name: 'Ibuprofen',
      drug2Name: 'Aspirin',
      severity: InteractionSeverity.moderate,
      description: 'Ibuprofen may reduce aspirin\'s heart-protective effect.',
      recommendation: 'Take aspirin 30 minutes before ibuprofen.',
      mechanism: 'Ibuprofen blocks aspirin\'s access to platelets.',
    ),
    DrugInteraction(
      id: 'int_017',
      drug1Name: 'Acetaminophen',
      drug2Name: 'Alcohol',
      severity: InteractionSeverity.moderate,
      description: 'Increased risk of liver damage.',
      recommendation: 'Avoid or limit alcohol. Do not exceed 2g acetaminophen daily with alcohol.',
      mechanism: 'Both are metabolized by the liver.',
    ),

    // Antidepressants
    DrugInteraction(
      id: 'int_018',
      drug1Name: 'Fluoxetine',
      drug2Name: 'Tramadol',
      severity: InteractionSeverity.severe,
      description: 'Risk of serotonin syndrome and seizures.',
      recommendation: 'Avoid combination. Use alternative pain medication.',
      mechanism: 'Both increase serotonin. Fluoxetine inhibits tramadol metabolism.',
    ),
    DrugInteraction(
      id: 'int_019',
      drug1Name: 'Sertraline',
      drug2Name: 'MAO Inhibitors',
      severity: InteractionSeverity.contraindicated,
      description: 'Life-threatening serotonin syndrome.',
      recommendation: 'Never combine. Wait 14 days between switching medications.',
      mechanism: 'Extreme serotonin accumulation.',
    ),
    DrugInteraction(
      id: 'int_020',
      drug1Name: 'Citalopram',
      drug2Name: 'Omeprazole',
      severity: InteractionSeverity.moderate,
      description: 'Omeprazole may increase citalopram levels.',
      recommendation: 'May need citalopram dose adjustment. Monitor for side effects.',
      mechanism: 'Omeprazole inhibits CYP2C19 metabolism.',
    ),

    // Thyroid Medications
    DrugInteraction(
      id: 'int_021',
      drug1Name: 'Levothyroxine',
      drug2Name: 'Calcium',
      severity: InteractionSeverity.moderate,
      description: 'Calcium reduces thyroid medication absorption.',
      recommendation: 'Take levothyroxine 4 hours before or after calcium.',
      mechanism: 'Calcium binds to levothyroxine in the gut.',
    ),
    DrugInteraction(
      id: 'int_022',
      drug1Name: 'Levothyroxine',
      drug2Name: 'Iron',
      severity: InteractionSeverity.moderate,
      description: 'Iron reduces thyroid medication absorption.',
      recommendation: 'Take levothyroxine 4 hours before or after iron supplements.',
      mechanism: 'Iron forms insoluble complexes with levothyroxine.',
    ),

    // Sleep Medications
    DrugInteraction(
      id: 'int_023',
      drug1Name: 'Zolpidem',
      drug2Name: 'Alcohol',
      severity: InteractionSeverity.severe,
      description: 'Extreme drowsiness, respiratory depression, risk of falls.',
      recommendation: 'Never combine. Avoid alcohol when taking sleep medications.',
      mechanism: 'Both depress the central nervous system.',
    ),
    DrugInteraction(
      id: 'int_024',
      drug1Name: 'Melatonin',
      drug2Name: 'Blood Thinners',
      severity: InteractionSeverity.mild,
      description: 'Melatonin may increase bleeding risk.',
      recommendation: 'Inform your doctor if using both.',
      mechanism: 'Melatonin has mild antiplatelet effects.',
    ),

    // Allergy Medications
    DrugInteraction(
      id: 'int_025',
      drug1Name: 'Diphenhydramine',
      drug2Name: 'Alcohol',
      severity: InteractionSeverity.moderate,
      description: 'Increased drowsiness and impaired motor function.',
      recommendation: 'Avoid alcohol when taking antihistamines.',
      mechanism: 'Both cause CNS depression.',
    ),

    // Proton Pump Inhibitors
    DrugInteraction(
      id: 'int_026',
      drug1Name: 'Omeprazole',
      drug2Name: 'Clopidogrel',
      severity: InteractionSeverity.moderate,
      description: 'Reduced effectiveness of clopidogrel.',
      recommendation: 'Consider pantoprazole as an alternative PPI.',
      mechanism: 'Omeprazole inhibits CYP2C19 which activates clopidogrel.',
    ),

    // Supplements
    DrugInteraction(
      id: 'int_027',
      drug1Name: 'St. John\'s Wort',
      drug2Name: 'Birth Control',
      severity: InteractionSeverity.severe,
      description: 'May significantly reduce contraceptive effectiveness.',
      recommendation: 'Avoid combination. Use backup contraception.',
      mechanism: 'St. John\'s Wort induces drug-metabolizing enzymes.',
    ),
    DrugInteraction(
      id: 'int_028',
      drug1Name: 'Ginkgo Biloba',
      drug2Name: 'Aspirin',
      severity: InteractionSeverity.moderate,
      description: 'Increased risk of bleeding.',
      recommendation: 'Avoid combination or monitor for bleeding signs.',
      mechanism: 'Both have antiplatelet effects.',
    ),

    // Additional Common Interactions
    DrugInteraction(
      id: 'int_029',
      drug1Name: 'Prednisone',
      drug2Name: 'NSAIDs',
      severity: InteractionSeverity.moderate,
      description: 'Increased risk of GI bleeding and ulcers.',
      recommendation: 'Use with caution. Consider gastroprotection.',
      mechanism: 'Both can damage GI mucosa.',
    ),
    DrugInteraction(
      id: 'int_030',
      drug1Name: 'Digoxin',
      drug2Name: 'Amiodarone',
      severity: InteractionSeverity.severe,
      description: 'Dangerously increased digoxin levels.',
      recommendation: 'Reduce digoxin dose by 50%. Monitor levels closely.',
      mechanism: 'Amiodarone inhibits digoxin elimination.',
    ),
  ];

  // ============ DRUG INFORMATION DATABASE ============
  static final List<DrugInfo> _drugDatabase = [
    DrugInfo(
      genericName: 'Acetaminophen',
      brandNames: ['Tylenol', 'Panadol', 'Crocin'],
      drugClass: 'Analgesic/Antipyretic',
      description: 'Pain reliever and fever reducer.',
      uses: ['Pain relief', 'Fever reduction', 'Headache', 'Muscle aches'],
      warnings: ['Do not exceed 4g daily', 'Avoid with alcohol', 'Check other medications for acetaminophen'],
      sideEffects: [
        SideEffect(name: 'Nausea', frequency: 'uncommon'),
        SideEffect(name: 'Liver damage', frequency: 'rare', isSerious: true),
      ],
      storage: 'Store at room temperature away from moisture',
      foodInteractions: ['Alcohol - increased liver damage risk'],
    ),
    DrugInfo(
      genericName: 'Ibuprofen',
      brandNames: ['Advil', 'Motrin', 'Brufen'],
      drugClass: 'NSAID',
      description: 'Non-steroidal anti-inflammatory drug for pain and inflammation.',
      uses: ['Pain relief', 'Inflammation', 'Fever', 'Arthritis', 'Menstrual cramps'],
      warnings: ['Take with food', 'May cause stomach bleeding', 'Avoid if kidney problems'],
      sideEffects: [
        SideEffect(name: 'Stomach upset', frequency: 'common'),
        SideEffect(name: 'Heartburn', frequency: 'common'),
        SideEffect(name: 'GI bleeding', frequency: 'rare', isSerious: true),
      ],
      storage: 'Store at room temperature',
      foodInteractions: ['Take with food or milk to reduce stomach upset'],
    ),
    DrugInfo(
      genericName: 'Metformin',
      brandNames: ['Glucophage', 'Fortamet', 'Glycomet'],
      drugClass: 'Biguanide (Antidiabetic)',
      description: 'First-line medication for type 2 diabetes.',
      uses: ['Type 2 diabetes', 'PCOS', 'Prediabetes'],
      warnings: ['Take with food', 'Stay hydrated', 'Stop before contrast dye procedures'],
      sideEffects: [
        SideEffect(name: 'Nausea', frequency: 'common'),
        SideEffect(name: 'Diarrhea', frequency: 'common'),
        SideEffect(name: 'Lactic acidosis', frequency: 'rare', isSerious: true),
      ],
      contraindications: ['Kidney disease', 'Liver disease', 'Heart failure'],
      storage: 'Store at room temperature',
      foodInteractions: ['Take with meals', 'Limit alcohol'],
    ),
    DrugInfo(
      genericName: 'Lisinopril',
      brandNames: ['Zestril', 'Prinivil'],
      drugClass: 'ACE Inhibitor',
      description: 'Blood pressure medication that protects heart and kidneys.',
      uses: ['High blood pressure', 'Heart failure', 'Diabetic kidney protection'],
      warnings: ['May cause cough', 'Avoid if pregnant', 'Monitor potassium levels'],
      sideEffects: [
        SideEffect(name: 'Dry cough', frequency: 'common'),
        SideEffect(name: 'Dizziness', frequency: 'common'),
        SideEffect(name: 'Angioedema', frequency: 'rare', isSerious: true),
      ],
      pregnancyCategory: 'D - Avoid in pregnancy',
      storage: 'Store at room temperature',
      foodInteractions: ['Avoid potassium-rich foods in excess', 'Limit salt substitutes'],
    ),
    DrugInfo(
      genericName: 'Atorvastatin',
      brandNames: ['Lipitor', 'Atorva'],
      drugClass: 'Statin',
      description: 'Cholesterol-lowering medication.',
      uses: ['High cholesterol', 'Heart disease prevention', 'Stroke prevention'],
      warnings: ['Avoid grapefruit', 'Report muscle pain immediately', 'Monitor liver function'],
      sideEffects: [
        SideEffect(name: 'Muscle pain', frequency: 'common'),
        SideEffect(name: 'Headache', frequency: 'common'),
        SideEffect(name: 'Rhabdomyolysis', frequency: 'rare', isSerious: true),
      ],
      storage: 'Store at room temperature',
      foodInteractions: ['Avoid grapefruit and grapefruit juice'],
    ),
    DrugInfo(
      genericName: 'Omeprazole',
      brandNames: ['Prilosec', 'Omez', 'Losec'],
      drugClass: 'Proton Pump Inhibitor',
      description: 'Reduces stomach acid production.',
      uses: ['GERD', 'Ulcers', 'H. pylori infection', 'Zollinger-Ellison syndrome'],
      warnings: ['Long-term use may affect bone health', 'May reduce B12 absorption'],
      sideEffects: [
        SideEffect(name: 'Headache', frequency: 'common'),
        SideEffect(name: 'Nausea', frequency: 'common'),
        SideEffect(name: 'Bone fractures', frequency: 'rare', isSerious: true),
      ],
      storage: 'Store at room temperature away from moisture',
      foodInteractions: ['Take before meals'],
    ),
    DrugInfo(
      genericName: 'Levothyroxine',
      brandNames: ['Synthroid', 'Levoxyl', 'Thyronorm'],
      drugClass: 'Thyroid Hormone',
      description: 'Synthetic thyroid hormone for hypothyroidism.',
      uses: ['Hypothyroidism', 'Thyroid cancer', 'Goiter'],
      warnings: ['Take on empty stomach', 'Separate from other medications', 'Consistent timing important'],
      sideEffects: [
        SideEffect(name: 'Hair loss (temporary)', frequency: 'common'),
        SideEffect(name: 'Weight changes', frequency: 'common'),
        SideEffect(name: 'Heart palpitations', frequency: 'uncommon'),
      ],
      storage: 'Store at room temperature away from light and moisture',
      foodInteractions: [
        'Take 30-60 minutes before breakfast',
        'Avoid taking with calcium, iron, or antacids',
        'Soy and fiber may reduce absorption',
      ],
    ),
    DrugInfo(
      genericName: 'Amlodipine',
      brandNames: ['Norvasc', 'Amlod'],
      drugClass: 'Calcium Channel Blocker',
      description: 'Blood pressure and angina medication.',
      uses: ['High blood pressure', 'Angina', 'Coronary artery disease'],
      warnings: ['May cause swelling in ankles', 'Do not stop abruptly'],
      sideEffects: [
        SideEffect(name: 'Ankle swelling', frequency: 'common'),
        SideEffect(name: 'Flushing', frequency: 'common'),
        SideEffect(name: 'Dizziness', frequency: 'common'),
      ],
      storage: 'Store at room temperature',
      foodInteractions: ['Can be taken with or without food', 'Limit grapefruit'],
    ),
    DrugInfo(
      genericName: 'Sertraline',
      brandNames: ['Zoloft', 'Lustral'],
      drugClass: 'SSRI Antidepressant',
      description: 'Antidepressant and anti-anxiety medication.',
      uses: ['Depression', 'Anxiety', 'PTSD', 'OCD', 'Panic disorder'],
      warnings: ['May increase suicidal thoughts initially', 'Do not stop abruptly', 'Avoid alcohol'],
      sideEffects: [
        SideEffect(name: 'Nausea', frequency: 'common'),
        SideEffect(name: 'Insomnia', frequency: 'common'),
        SideEffect(name: 'Sexual dysfunction', frequency: 'common'),
        SideEffect(name: 'Serotonin syndrome', frequency: 'rare', isSerious: true),
      ],
      storage: 'Store at room temperature',
      foodInteractions: ['Can be taken with or without food'],
    ),
    DrugInfo(
      genericName: 'Amoxicillin',
      brandNames: ['Amoxil', 'Moxatag', 'Novamox'],
      drugClass: 'Penicillin Antibiotic',
      description: 'Broad-spectrum antibiotic for bacterial infections.',
      uses: ['Respiratory infections', 'Ear infections', 'Skin infections', 'UTI'],
      warnings: ['Complete full course', 'Check for penicillin allergy', 'May cause diarrhea'],
      sideEffects: [
        SideEffect(name: 'Diarrhea', frequency: 'common'),
        SideEffect(name: 'Nausea', frequency: 'common'),
        SideEffect(name: 'Allergic reaction', frequency: 'uncommon', isSerious: true),
      ],
      storage: 'Store at room temperature or refrigerate liquid',
      foodInteractions: ['Can be taken with or without food'],
    ),
    DrugInfo(
      genericName: 'Aspirin',
      brandNames: ['Bayer', 'Ecotrin', 'Disprin'],
      drugClass: 'NSAID/Antiplatelet',
      description: 'Pain reliever and blood thinner for heart protection.',
      uses: ['Pain relief', 'Heart attack prevention', 'Stroke prevention', 'Fever'],
      warnings: ['May cause bleeding', 'Avoid before surgery', 'Not for children with viral illness'],
      sideEffects: [
        SideEffect(name: 'Stomach upset', frequency: 'common'),
        SideEffect(name: 'GI bleeding', frequency: 'uncommon', isSerious: true),
      ],
      contraindications: ['Active bleeding', 'Aspirin allergy', 'Children with fever'],
      storage: 'Store at room temperature',
      foodInteractions: ['Take with food to reduce stomach upset'],
    ),
    DrugInfo(
      genericName: 'Vitamin D',
      brandNames: ['Calcirol', 'Drisdol'],
      drugClass: 'Vitamin Supplement',
      description: 'Essential vitamin for bone health and immune function.',
      uses: ['Vitamin D deficiency', 'Osteoporosis prevention', 'Bone health'],
      warnings: ['Do not exceed recommended dose', 'Check calcium levels'],
      sideEffects: [
        SideEffect(name: 'Nausea', frequency: 'uncommon'),
        SideEffect(name: 'Hypercalcemia', frequency: 'rare', isSerious: true),
      ],
      storage: 'Store at room temperature away from light',
      foodInteractions: ['Take with fatty food for better absorption'],
    ),
  ];

  /// Get all drugs in database for autocomplete
  List<String> getAllDrugNames() {
    final names = <String>{};
    for (final info in _drugDatabase) {
      names.add(info.genericName);
      names.addAll(info.brandNames);
    }
    return names.toList()..sort();
  }

  /// Check if a drug has any known severe interactions
  bool hasSevereInteractions(String drugName) {
    final normalized = _normalizeDrugName(drugName);
    for (final interaction in _interactionDatabase) {
      if (interaction.severity == InteractionSeverity.severe ||
          interaction.severity == InteractionSeverity.contraindicated) {
        final n1 = _normalizeDrugName(interaction.drug1Name);
        final n2 = _normalizeDrugName(interaction.drug2Name);
        if (normalized.contains(n1) || n1.contains(normalized) ||
            normalized.contains(n2) || n2.contains(normalized)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Get interaction summary for display
  Map<InteractionSeverity, int> getInteractionSummary(List<String> drugNames) {
    final interactions = checkAllInteractions(drugNames);
    final summary = <InteractionSeverity, int>{};
    
    for (final interaction in interactions) {
      summary[interaction.severity] = (summary[interaction.severity] ?? 0) + 1;
    }
    
    return summary;
  }
}
