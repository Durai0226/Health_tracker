import '../models/medicine_enums.dart';
import '../models/drug_interaction.dart';
import 'drug_name_catalog.dart';

/// A pluggable interaction data source. The default is the built-in curated
/// on-device table (a general reference — see the disclaimer shown in the UI).
///
/// AUTHORITATIVE-DATA PATH (deliberate, per sourcing research):
/// - There is NO free, structured, commercially-licensed DDI dataset that can
///   ship on-device: RxNav's interaction API was retired (Jan 2024); DrugBank /
///   DDInter open dumps are CC BY-NC (an ad-supported app is commercial, so
///   they're off-limits); openFDA/DailyMed labels are CC0 but unstructured prose
///   needing NLP extraction.
/// - Clinical-grade products (First Databank, Medi-Span, DrugBank/Micromedex
///   APIs) are enterprise-priced AND network APIs (they'd move a drug list
///   off-device, breaking the privacy claim).
/// So an authoritative checker is a business/procurement decision. When one is
/// licensed, implement this interface (e.g. an API-backed or bundled-CC0-dataset
/// source) and call [DrugInteractionService.configureSource] once at startup —
/// no call-site changes.
abstract class DrugInteractionSource {
  List<DrugInteraction> checkAll(List<String> drugNames);
}

/// Premium feature: Drug Interaction Checker Service
/// Provides comprehensive drug interaction checking like Medisafe premium
class DrugInteractionService {
  static final DrugInteractionService _instance = DrugInteractionService._internal();
  factory DrugInteractionService() => _instance;
  DrugInteractionService._internal();

  /// Optional injected source. When set, it overrides the built-in table — the
  /// drop-in seam for a licensed/authoritative data source.
  DrugInteractionSource? _externalSource;
  void configureSource(DrugInteractionSource? source) =>
      _externalSource = source;

  /// Check interactions between two drugs
  List<DrugInteraction> checkInteraction(String drug1, String drug2) {
    final interactions = <DrugInteraction>[];

    for (final interaction in _interactionDatabase) {
      if (_namesMatch(drug1, interaction.drug1Name) &&
          _namesMatch(drug2, interaction.drug2Name)) {
        interactions.add(interaction);
      } else if (_namesMatch(drug1, interaction.drug2Name) &&
          _namesMatch(drug2, interaction.drug1Name)) {
        interactions.add(interaction);
      }
    }

    return interactions;
  }

  /// Check all interactions for a list of medicines. Delegates to an injected
  /// authoritative source when configured, else uses the built-in curated table.
  List<DrugInteraction> checkAllInteractions(List<String> drugNames) {
    final external = _externalSource;
    if (external != null) return external.checkAll(drugNames);

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
    for (final info in _drugDatabase) {
      if (_namesMatch(drugName, info.genericName)) return info;
      for (final brand in info.brandNames) {
        if (_namesMatch(drugName, brand)) return info;
      }
    }
    return null;
  }

  /// A plain-language "what it's for" line for [name] (with an optional known
  /// [genericName]), built from the curated monograph. Resolves brand → generic
  /// via the on-device [DrugNameCatalog] when a direct lookup misses. Returns
  /// null when no monograph matches — the caller then falls back to the user's
  /// own note. GENERAL REFERENCE ONLY: purpose/uses, never dosing advice.
  /// Resolve a medicine to its monograph: direct generic/brand lookup, then a
  /// brand→generic hop via the on-device catalog. Null when uncovered.
  DrugInfo? _resolveInfo(String name, String? genericName) {
    var info = getDrugInfo(genericName ?? name);
    info ??= getDrugInfo(name);
    if (info == null) {
      final resolved = DrugNameCatalog.genericFor(name);
      if (resolved != null) info = getDrugInfo(resolved);
    }
    return info;
  }

  /// Up to [max] primary uses as a short lower-case phrase (e.g. "pain relief,
  /// fever"), or null — for a compact "For: …" line at dose time.
  String? primaryUses({required String name, String? genericName, int max = 2}) {
    final uses = _resolveInfo(name, genericName)?.uses;
    if (uses == null || uses.isEmpty) return null;
    return uses.take(max).map((u) => u.toLowerCase()).join(', ');
  }

  String? purposeSummary({required String name, String? genericName}) {
    final info = _resolveInfo(name, genericName);
    if (info == null) return null;

    final buf = StringBuffer(info.genericName);
    final desc = info.description?.trim();
    buf.write(' · ${(desc != null && desc.isNotEmpty) ? desc : info.drugClass}');
    final uses = info.uses;
    if (uses != null && uses.isNotEmpty) {
      buf.write(
          ' — commonly used for ${uses.take(4).map((u) => u.toLowerCase()).join(', ')}.');
    }
    return buf.toString();
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

  /// Memo caches for the two pure string transforms below.
  ///
  /// `_namesMatch` normalised AND tokenised both of its arguments on every
  /// call, and `checkAllInteractions` calls it twice per (pair × database
  /// entry). With 12 medicines that is 66 pairs × 47 entries × 2 = **6,204**
  /// normalise+tokenise round trips — synchronously, on the UI isolate, every
  /// time any dose is logged anywhere in the app (the medication dashboard
  /// recomputes interactions on every `revision` bump).
  ///
  /// The inputs are a tiny closed set: 47 database entries plus the user's own
  /// medicine names. Caching leaves behaviour identical and makes each of
  /// those 6,204 iterations a map lookup.
  static final Map<String, String> _normalizedCache = {};
  static final Map<String, Set<String>> _tokenCache = {};

  String _normalizeDrugName(String name) {
    return _normalizedCache.putIfAbsent(name,
        () => name.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]'), ''));
  }

  /// Tokens of a name — split on non-alphanumerics, lowercased, non-empty.
  Set<String> _drugTokens(String s) => _tokenCache.putIfAbsent(
      s,
      () => s
          .toLowerCase()
          .split(RegExp(r'[^a-z0-9]+'))
          .where((t) => t.isNotEmpty)
          .toSet());

  /// Generic pharmacy filler words — dosage forms, marketing suffixes, and
  /// common complaint words — that appear in countless UNRELATED product
  /// names. Excluded from the shared-token check below so two products that
  /// only share one of THESE don't falsely register as the same drug (e.g.
  /// a user-typed "Blood Pressure Tablet" vs. the curated interaction row's
  /// "Blood Thinners" used to match on the shared token "blood").
  static const Set<String> _genericFillerTokens = {
    'tablet', 'tablets', 'tab', 'tabs', 'capsule', 'capsules', 'cap', 'caps',
    'syrup', 'drop', 'drops', 'injection', 'cream', 'ointment', 'gel', 'spray',
    'medicine', 'medication', 'drug', 'drugs', 'pill', 'pills', 'dose',
    'doses', 'extra', 'strength', 'forte', 'plus', 'blood', 'pressure',
    'pain', 'relief', 'fever', 'cold', 'flu', 'daily', 'night', 'day',
  };

  /// Whether two drug names refer to the same drug: exact normalized equality,
  /// or a shared WHOLE token of >= 4 chars that isn't a generic filler word
  /// (e.g. "Dolo 650" ~ brand "Dolo"). Replaces loose bidirectional substring
  /// containment, which produced wrong monographs and false interaction
  /// warnings when one short name happened to be a substring of another.
  bool _namesMatch(String a, String b) {
    final na = _normalizeDrugName(a);
    final nb = _normalizeDrugName(b);
    if (na.isEmpty || nb.isEmpty) return false;
    if (na == nb) return true;
    final tb = _drugTokens(b);
    for (final t in _drugTokens(a)) {
      if (t.length >= 4 && !_genericFillerTokens.contains(t) && tb.contains(t)) {
        return true;
      }
    }
    return false;
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
    // 'Antacids' is a class, not a real product name _namesMatch can ever hit
    // against a user's own typed medicine name — one row per common real
    // antacid product, same interaction.
    DrugInteraction(
      id: 'int_011a',
      drug1Name: 'Ciprofloxacin',
      drug2Name: 'Calcium Carbonate',
      severity: InteractionSeverity.moderate,
      description: 'Antacids reduce antibiotic absorption significantly.',
      recommendation: 'Take ciprofloxacin 2 hours before or 6 hours after antacids.',
      mechanism: 'Metal ions in antacids bind to the antibiotic.',
    ),
    DrugInteraction(
      id: 'int_011b',
      drug1Name: 'Ciprofloxacin',
      drug2Name: 'Magnesium Hydroxide',
      severity: InteractionSeverity.moderate,
      description: 'Antacids reduce antibiotic absorption significantly.',
      recommendation: 'Take ciprofloxacin 2 hours before or 6 hours after antacids.',
      mechanism: 'Metal ions in antacids bind to the antibiotic.',
    ),
    DrugInteraction(
      id: 'int_011c',
      drug1Name: 'Ciprofloxacin',
      drug2Name: 'Tums',
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
    // 'Birth Control' is a class, not a real product name — one row per
    // common real oral contraceptive name/brand, same interaction.
    DrugInteraction(
      id: 'int_013a',
      drug1Name: 'Amoxicillin',
      drug2Name: 'Ethinyl Estradiol',
      severity: InteractionSeverity.mild,
      description: 'May slightly reduce contraceptive effectiveness.',
      recommendation: 'Use backup contraception during antibiotic treatment.',
      mechanism: 'Antibiotics may affect gut bacteria that recycle estrogen.',
    ),
    DrugInteraction(
      id: 'int_013b',
      drug1Name: 'Amoxicillin',
      drug2Name: 'Yasmin',
      severity: InteractionSeverity.mild,
      description: 'May slightly reduce contraceptive effectiveness.',
      recommendation: 'Use backup contraception during antibiotic treatment.',
      mechanism: 'Antibiotics may affect gut bacteria that recycle estrogen.',
    ),
    DrugInteraction(
      id: 'int_013c',
      drug1Name: 'Amoxicillin',
      drug2Name: 'Ortho Tri-Cyclen',
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
    // 'SSRI' is a class, not a real drug name (Fluoxetine already has its own
    // real-named row below, int_018) — one row per other common real SSRI.
    DrugInteraction(
      id: 'int_015a',
      drug1Name: 'Tramadol',
      drug2Name: 'Sertraline',
      severity: InteractionSeverity.severe,
      description: 'Risk of serotonin syndrome - potentially life-threatening.',
      recommendation: 'Use alternative pain medication or monitor closely.',
      mechanism: 'Both drugs increase serotonin levels.',
    ),
    DrugInteraction(
      id: 'int_015b',
      drug1Name: 'Tramadol',
      drug2Name: 'Citalopram',
      severity: InteractionSeverity.severe,
      description: 'Risk of serotonin syndrome - potentially life-threatening.',
      recommendation: 'Use alternative pain medication or monitor closely.',
      mechanism: 'Both drugs increase serotonin levels.',
    ),
    DrugInteraction(
      id: 'int_015c',
      drug1Name: 'Tramadol',
      drug2Name: 'Paroxetine',
      severity: InteractionSeverity.severe,
      description: 'Risk of serotonin syndrome - potentially life-threatening.',
      recommendation: 'Use alternative pain medication or monitor closely.',
      mechanism: 'Both drugs increase serotonin levels.',
    ),
    DrugInteraction(
      id: 'int_015d',
      drug1Name: 'Tramadol',
      drug2Name: 'Escitalopram',
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
    // 'MAO Inhibitors' is a class, not a real drug name — one row per common
    // real MAOI.
    DrugInteraction(
      id: 'int_019a',
      drug1Name: 'Sertraline',
      drug2Name: 'Phenelzine',
      severity: InteractionSeverity.contraindicated,
      description: 'Life-threatening serotonin syndrome.',
      recommendation: 'Never combine. Wait 14 days between switching medications.',
      mechanism: 'Extreme serotonin accumulation.',
    ),
    DrugInteraction(
      id: 'int_019b',
      drug1Name: 'Sertraline',
      drug2Name: 'Tranylcypromine',
      severity: InteractionSeverity.contraindicated,
      description: 'Life-threatening serotonin syndrome.',
      recommendation: 'Never combine. Wait 14 days between switching medications.',
      mechanism: 'Extreme serotonin accumulation.',
    ),
    DrugInteraction(
      id: 'int_019c',
      drug1Name: 'Sertraline',
      drug2Name: 'Selegiline',
      severity: InteractionSeverity.contraindicated,
      description: 'Life-threatening serotonin syndrome.',
      recommendation: 'Never combine. Wait 14 days between switching medications.',
      mechanism: 'Extreme serotonin accumulation.',
    ),
    DrugInteraction(
      id: 'int_019d',
      drug1Name: 'Sertraline',
      drug2Name: 'Isocarboxazid',
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
    // 'Blood Thinners' is a class, not a real drug name — one row per common
    // real anticoagulant/antiplatelet (Aspirin/Clopidogrel already appear
    // elsewhere in this table under their own real names).
    DrugInteraction(
      id: 'int_024a',
      drug1Name: 'Melatonin',
      drug2Name: 'Warfarin',
      severity: InteractionSeverity.mild,
      description: 'Melatonin may increase bleeding risk.',
      recommendation: 'Inform your doctor if using both.',
      mechanism: 'Melatonin has mild antiplatelet effects.',
    ),
    DrugInteraction(
      id: 'int_024b',
      drug1Name: 'Melatonin',
      drug2Name: 'Aspirin',
      severity: InteractionSeverity.mild,
      description: 'Melatonin may increase bleeding risk.',
      recommendation: 'Inform your doctor if using both.',
      mechanism: 'Melatonin has mild antiplatelet effects.',
    ),
    DrugInteraction(
      id: 'int_024c',
      drug1Name: 'Melatonin',
      drug2Name: 'Clopidogrel',
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
    // 'Birth Control' is a class, not a real product name — same real-name
    // expansion as int_013 above.
    DrugInteraction(
      id: 'int_027a',
      drug1Name: 'St. John\'s Wort',
      drug2Name: 'Ethinyl Estradiol',
      severity: InteractionSeverity.severe,
      description: 'May significantly reduce contraceptive effectiveness.',
      recommendation: 'Avoid combination. Use backup contraception.',
      mechanism: 'St. John\'s Wort induces drug-metabolizing enzymes.',
    ),
    DrugInteraction(
      id: 'int_027b',
      drug1Name: 'St. John\'s Wort',
      drug2Name: 'Yasmin',
      severity: InteractionSeverity.severe,
      description: 'May significantly reduce contraceptive effectiveness.',
      recommendation: 'Avoid combination. Use backup contraception.',
      mechanism: 'St. John\'s Wort induces drug-metabolizing enzymes.',
    ),
    DrugInteraction(
      id: 'int_027c',
      drug1Name: 'St. John\'s Wort',
      drug2Name: 'Ortho Tri-Cyclen',
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
    // 'NSAIDs' is a class, not a real drug name — one row per common real
    // NSAID (Ibuprofen already appears elsewhere in this table for a
    // different pairing, under its own real name).
    DrugInteraction(
      id: 'int_029a',
      drug1Name: 'Prednisone',
      drug2Name: 'Ibuprofen',
      severity: InteractionSeverity.moderate,
      description: 'Increased risk of GI bleeding and ulcers.',
      recommendation: 'Use with caution. Consider gastroprotection.',
      mechanism: 'Both can damage GI mucosa.',
    ),
    DrugInteraction(
      id: 'int_029b',
      drug1Name: 'Prednisone',
      drug2Name: 'Naproxen',
      severity: InteractionSeverity.moderate,
      description: 'Increased risk of GI bleeding and ulcers.',
      recommendation: 'Use with caution. Consider gastroprotection.',
      mechanism: 'Both can damage GI mucosa.',
    ),
    DrugInteraction(
      id: 'int_029c',
      drug1Name: 'Prednisone',
      drug2Name: 'Diclofenac',
      severity: InteractionSeverity.moderate,
      description: 'Increased risk of GI bleeding and ulcers.',
      recommendation: 'Use with caution. Consider gastroprotection.',
      mechanism: 'Both can damage GI mucosa.',
    ),
    DrugInteraction(
      id: 'int_029d',
      drug1Name: 'Prednisone',
      drug2Name: 'Aspirin',
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
      // 'Paracetamol' is the same drug (non-US name) — include it so lookups by
      // the common Indian/EU name (and brands like Dolo/Calpol) resolve.
      brandNames: ['Tylenol', 'Panadol', 'Crocin', 'Paracetamol', 'Dolo', 'Calpol'],
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
      // Include the chemical/common synonyms so catalog generics resolve.
      brandNames: ['Calcirol', 'Drisdol', 'Cholecalciferol', 'Vitamin D3'],
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
    for (final interaction in _interactionDatabase) {
      if (interaction.severity == InteractionSeverity.severe ||
          interaction.severity == InteractionSeverity.contraindicated) {
        if (_namesMatch(drugName, interaction.drug1Name) ||
            _namesMatch(drugName, interaction.drug2Name)) {
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
