import '../models/condition_info.dart';

/// Curated, general-education reference for common conditions people track
/// medicines/vitals for in this app. See [ConditionInfo]'s doc: none of this
/// is diagnostic or treatment advice, and it is never a substitute for a
/// clinician who knows the person's actual history.
const List<ConditionInfo> conditionLibrary = [
  ConditionInfo(
    id: 'hypertension',
    name: 'High blood pressure (hypertension)',
    category: ConditionCategory.cardiovascular,
    aliases: ['hypertension', 'bp', 'blood pressure'],
    overview:
        'Blood pressure that stays higher than normal over time, making the '
        'heart and blood vessels work harder. It usually has no symptoms, '
        'which is why regular readings matter more than how someone feels.',
    commonSymptoms: [
      'Usually none — often called a "silent" condition',
      'Occasional headaches',
      'In a severe spike: chest pain, vision changes, or shortness of breath',
    ],
    selfCareTips: [
      'Take readings at a consistent time of day, seated and rested',
      'Reduce added salt and processed foods',
      'Regular activity, even short daily walks, helps over time',
      'Limit alcohol and avoid smoking',
      'Take medicines as prescribed, even once you feel fine',
    ],
    whenToSeekHelp: [
      'A reading in the "crisis" range (very high) — especially with chest '
          'pain, confusion, or trouble speaking',
      'Sudden vision changes or severe headache',
    ],
  ),
  ConditionInfo(
    id: 'afib',
    name: 'Atrial fibrillation',
    category: ConditionCategory.cardiovascular,
    aliases: ['afib', 'a-fib', 'irregular heartbeat'],
    overview:
        'An irregular, often fast heart rhythm starting in the heart\'s '
        'upper chambers. It raises stroke risk, which is why it\'s usually '
        'managed with both rhythm/rate control and clot-prevention medicine.',
    commonSymptoms: [
      'A fluttering, pounding, or racing heartbeat',
      'Fatigue or reduced ability to exercise',
      'Shortness of breath',
      'Dizziness or lightheadedness',
    ],
    selfCareTips: [
      'Take blood thinners exactly as prescribed — missed or doubled doses '
          'both carry real risk',
      'Limit caffeine and alcohol if they seem to trigger episodes',
      'Track episodes (when, how long, how it felt) to share with your care team',
    ],
    whenToSeekHelp: [
      'Chest pain, fainting, or severe shortness of breath',
      'Sudden weakness, numbness, or trouble speaking (possible stroke) — '
          'this is an emergency',
    ],
  ),
  ConditionInfo(
    id: 'high-cholesterol',
    name: 'High cholesterol',
    category: ConditionCategory.cardiovascular,
    aliases: ['cholesterol', 'hyperlipidemia', 'lipids'],
    overview:
        'Higher-than-recommended levels of certain fats in the blood, which '
        'over years can narrow arteries and raise the risk of heart attack '
        'and stroke. Like blood pressure, it typically causes no symptoms.',
    commonSymptoms: [
      'Usually none — found through a blood test',
    ],
    selfCareTips: [
      'Favor whole foods and reduce saturated/trans fats',
      'Regular aerobic activity',
      'Take statins or other lipid medicine consistently — benefits build over time',
      'Recheck levels on the schedule your clinician suggests',
    ],
    whenToSeekHelp: [
      'New chest pain, pressure, or shortness of breath with exertion',
    ],
  ),
  ConditionInfo(
    id: 'type-2-diabetes',
    name: 'Type 2 diabetes',
    category: ConditionCategory.endocrine,
    aliases: ['diabetes', 't2d', 'blood sugar'],
    overview:
        'A condition where the body doesn\'t use insulin well, leading to '
        'higher blood sugar over time. It\'s manageable with a mix of diet, '
        'activity, monitoring, and often medicine.',
    commonSymptoms: [
      'Increased thirst and urination',
      'Fatigue',
      'Blurred vision',
      'Slow-healing cuts or sores',
      'Tingling in hands or feet',
    ],
    selfCareTips: [
      'Check blood sugar on the schedule that works for your treatment',
      'Balance carbohydrate portions across the day rather than skipping meals',
      'Regular activity improves insulin sensitivity',
      'Check feet regularly for cuts or sores that aren\'t healing',
    ],
    whenToSeekHelp: [
      'A very low reading with confusion, shaking, or fainting',
      'A very high reading with vomiting, rapid breathing, or fruity-smelling breath',
      'A wound that isn\'t healing or shows signs of infection',
    ],
  ),
  ConditionInfo(
    id: 'hypothyroidism',
    name: 'Hypothyroidism (underactive thyroid)',
    category: ConditionCategory.endocrine,
    aliases: ['thyroid', 'underactive thyroid'],
    overview:
        'The thyroid gland makes too little thyroid hormone, which slows '
        'down the body\'s metabolism. It\'s usually well controlled with a '
        'daily replacement hormone, dosed by periodic blood tests.',
    commonSymptoms: [
      'Fatigue and feeling cold',
      'Weight gain despite no change in eating',
      'Dry skin and hair thinning',
      'Constipation',
      'Low mood or brain fog',
    ],
    selfCareTips: [
      'Take thyroid medicine on an empty stomach, at a consistent time, as directed',
      'Space it apart from calcium, iron, or antacids — they can block absorption',
      'Keep up with periodic blood tests even once you feel well',
    ],
    whenToSeekHelp: [
      'Severe swelling, confusion, or very slow heart rate (rare, but urgent)',
    ],
  ),
  ConditionInfo(
    id: 'asthma',
    name: 'Asthma',
    category: ConditionCategory.respiratory,
    aliases: ['asthma', 'wheezing'],
    overview:
        'A condition where airways become inflamed and narrowed, often '
        'triggered by allergens, exercise, or irritants. Most people manage '
        'it well with a daily controller and a fast-acting rescue inhaler.',
    commonSymptoms: [
      'Wheezing or a whistling sound when breathing',
      'Shortness of breath',
      'Chest tightness',
      'Coughing, especially at night or early morning',
    ],
    selfCareTips: [
      'Keep the rescue inhaler within reach at all times',
      'Take controller medicine daily even on symptom-free days',
      'Know and avoid your personal triggers where possible',
      'Follow a written asthma action plan if your clinician has given you one',
    ],
    whenToSeekHelp: [
      'Rescue inhaler isn\'t helping or is needed more than usual',
      'Trouble speaking in full sentences due to breathlessness',
      'Lips or fingertips turning blue — call emergency services immediately',
    ],
  ),
  ConditionInfo(
    id: 'copd',
    name: 'COPD (chronic obstructive pulmonary disease)',
    category: ConditionCategory.respiratory,
    aliases: ['copd', 'emphysema', 'chronic bronchitis'],
    overview:
        'A long-term lung condition that makes it progressively harder to '
        'breathe, most often linked to smoking history. Inhaled medicines, '
        'staying active, and avoiding flare-up triggers all help slow it down.',
    commonSymptoms: [
      'Ongoing cough, often with mucus',
      'Shortness of breath that worsens with activity',
      'Wheezing',
      'Frequent chest infections',
    ],
    selfCareTips: [
      'Use inhalers exactly as prescribed, including proper technique',
      'Get recommended vaccinations (flu, pneumonia) to reduce flare-up risk',
      'Pace activity and use breathing techniques your care team has taught you',
      'Avoid smoke and strong fumes',
    ],
    whenToSeekHelp: [
      'A flare-up that isn\'t responding to your usual rescue medicine',
      'Blue-tinged lips or fingertips, or severe breathlessness at rest',
    ],
  ),
  ConditionInfo(
    id: 'anxiety',
    name: 'Anxiety',
    category: ConditionCategory.mentalHealth,
    aliases: ['anxiety disorder', 'panic'],
    overview:
        'Persistent, excessive worry or fear that goes beyond normal '
        'day-to-day stress and affects daily life. It responds well to a '
        'combination of therapy, lifestyle changes, and sometimes medicine.',
    commonSymptoms: [
      'Restlessness or feeling on edge',
      'Racing heart, sweating, or trembling',
      'Trouble concentrating or sleeping',
      'Avoiding situations that trigger worry',
    ],
    selfCareTips: [
      'Slow, deep breathing during a spike can shorten it',
      'Keep a consistent sleep and activity routine',
      'Limit caffeine if it worsens symptoms',
      'Take any prescribed medicine consistently — some take weeks to reach full effect',
    ],
    whenToSeekHelp: [
      'Thoughts of harming yourself — reach out to a crisis line or emergency services now',
      'Panic that includes chest pain (worth ruling out other causes)',
    ],
  ),
  ConditionInfo(
    id: 'depression',
    name: 'Depression',
    category: ConditionCategory.mentalHealth,
    aliases: ['low mood', 'clinical depression'],
    overview:
        'A persistent low mood or loss of interest that lasts weeks and '
        'affects daily functioning — more than an ordinary bad day. It is '
        'treatable, usually with therapy, medicine, or both.',
    commonSymptoms: [
      'Persistent sadness, emptiness, or irritability',
      'Loss of interest in things once enjoyed',
      'Changes in sleep or appetite',
      'Fatigue or low energy',
      'Trouble concentrating',
    ],
    selfCareTips: [
      'Keep taking prescribed medicine even before you notice a difference — '
          'many take several weeks to work',
      'Try to maintain some daily structure, even small routines',
      'Tell your care team about side effects rather than stopping on your own',
      'Stay connected — isolation tends to make things feel worse',
    ],
    whenToSeekHelp: [
      'Thoughts of harming yourself or suicide — reach out to a crisis line '
          'or emergency services now',
      'A sudden, severe change in mood or functioning',
    ],
  ),
  ConditionInfo(
    id: 'gerd',
    name: 'Acid reflux (GERD)',
    category: ConditionCategory.gastrointestinal,
    aliases: ['gerd', 'acid reflux', 'heartburn'],
    overview:
        'Stomach acid regularly flowing back into the esophagus, causing '
        'irritation. Occasional reflux is common; frequent or severe reflux '
        '(GERD) usually needs ongoing management.',
    commonSymptoms: [
      'Heartburn, especially after eating or lying down',
      'A sour or bitter taste in the mouth',
      'Difficulty swallowing',
      'Chronic cough or hoarseness',
    ],
    selfCareTips: [
      'Avoid lying down for 2-3 hours after eating',
      'Smaller, less fatty/spicy meals tend to help',
      'Raising the head of the bed can reduce nighttime symptoms',
      'Take acid-reducing medicine at the time of day it\'s prescribed for',
    ],
    whenToSeekHelp: [
      'Difficulty swallowing, unintended weight loss, or vomiting blood',
      'Chest pain that could be heart-related rather than reflux — when in '
          'doubt, treat it as an emergency',
    ],
  ),
  ConditionInfo(
    id: 'osteoarthritis',
    name: 'Osteoarthritis',
    category: ConditionCategory.musculoskeletal,
    aliases: ['arthritis', 'joint pain'],
    overview:
        'Wear-and-tear breakdown of joint cartilage, most common in knees, '
        'hips, and hands, that causes pain and stiffness that usually '
        'worsens with age or overuse.',
    commonSymptoms: [
      'Joint pain that worsens with activity',
      'Stiffness, especially after rest or in the morning',
      'Swelling or reduced range of motion',
      'A grating sensation with movement',
    ],
    selfCareTips: [
      'Gentle, regular movement often helps more than rest',
      'Maintaining a comfortable weight reduces load on weight-bearing joints',
      'Heat for stiffness, cold for swelling — whichever feels better',
      'Take pain-relief medicine as directed, not just when pain is severe',
    ],
    whenToSeekHelp: [
      'A joint that is suddenly hot, red, and swollen (possible infection or gout)',
      'Sudden inability to bear weight after an injury',
    ],
  ),
  ConditionInfo(
    id: 'osteoporosis',
    name: 'Osteoporosis',
    category: ConditionCategory.musculoskeletal,
    aliases: ['bone density', 'brittle bones'],
    overview:
        'Bones become thinner and more fragile over time, raising fracture '
        'risk from even minor falls. It\'s often silent until a fracture happens.',
    commonSymptoms: [
      'Usually none until a fracture occurs',
      'Gradual loss of height or a stooped posture over time',
      'Back pain from a small, sometimes unnoticed spinal fracture',
    ],
    selfCareTips: [
      'Weight-bearing exercise (walking, light strength work) supports bone health',
      'Adequate calcium and vitamin D intake, per your clinician\'s guidance',
      'Reduce fall risks at home (lighting, loose rugs, clutter)',
      'Take bone-strengthening medicine exactly as directed — timing and posture matter for some',
    ],
    whenToSeekHelp: [
      'Sudden, severe back pain after a minor bump or fall',
      'A fall resulting in inability to bear weight',
    ],
  ),
  ConditionInfo(
    id: 'migraine',
    name: 'Migraine',
    category: ConditionCategory.neurological,
    aliases: ['migraines', 'headache disorder'],
    overview:
        'A neurological condition causing recurring, often severe headaches, '
        'frequently with nausea and light/sound sensitivity. Both preventive '
        'and as-needed medicines are commonly used together.',
    commonSymptoms: [
      'Throbbing pain, often on one side of the head',
      'Nausea or vomiting',
      'Sensitivity to light, sound, or smell',
      'Visual disturbances (aura) in some people, before or during an attack',
    ],
    selfCareTips: [
      'Take as-needed medicine early in an attack — waiting often makes it less effective',
      'Keep a log of triggers (foods, sleep, stress, hormonal patterns)',
      'A dark, quiet room can help during an attack',
      'Stay consistent with preventive medicine if one is prescribed',
    ],
    whenToSeekHelp: [
      'A headache described as the "worst ever" or with sudden onset',
      'Headache with fever, stiff neck, confusion, or weakness on one side — '
          'treat as an emergency',
    ],
  ),
  ConditionInfo(
    id: 'ckd',
    name: 'Chronic kidney disease',
    category: ConditionCategory.renal,
    aliases: ['ckd', 'kidney disease'],
    overview:
        'A gradual loss of kidney function over time, often linked to '
        'diabetes or high blood pressure. Early stages usually have no '
        'symptoms, which is why routine blood/urine tests matter.',
    commonSymptoms: [
      'Often none in early stages',
      'Swelling in legs, ankles, or feet',
      'Fatigue',
      'Changes in urination',
      'Persistent itching',
    ],
    selfCareTips: [
      'Keep blood pressure and blood sugar well controlled — both protect kidney function',
      'Ask before taking NSAIDs (like ibuprofen) or new supplements — many affect the kidneys',
      'Follow any dietary guidance on sodium, potassium, or protein from your care team',
      'Keep up with scheduled blood/urine tests',
    ],
    whenToSeekHelp: [
      'Little or no urination',
      'Severe swelling, confusion, or shortness of breath',
    ],
  ),
];
