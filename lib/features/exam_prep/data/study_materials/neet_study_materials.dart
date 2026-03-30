import '../../../exam_prep/models/study_material_model.dart';

/// Comprehensive study materials for NEET (UG)
final List<StudyMaterial> neetStudyMaterials = [
  // ==================== BIOLOGY - BOTANY ====================
  
  StudyMaterial(
    id: 'neet_bio_cell_structure',
    title: 'Cell Structure & Organization',
    description: 'Cell theory, organelles, and cell types for NEET',
    subjectId: 'biology',
    topicId: 'cell_biology',
    type: StudyMaterialType.notes,
    content: '''
# Cell Structure & Organization for NEET

## Cell Theory

### Postulates
1. All living organisms are made of cells
2. Cell is the basic structural and functional unit of life
3. All cells arise from pre-existing cells (Omnis cellula e cellula)

### Exceptions
- Viruses are acellular
- RBCs and sieve tubes lack nucleus
- Muscle fibers are multinucleated

## Prokaryotic vs Eukaryotic Cells

| Feature | Prokaryotic | Eukaryotic |
|---------|-------------|------------|
| Nucleus | Absent (nucleoid) | Present |
| Membrane-bound organelles | Absent | Present |
| Ribosomes | 70S | 80S |
| Cell wall | Present (peptidoglycan) | Present/Absent |
| Size | 1-10 μm | 10-100 μm |
| DNA | Circular, naked | Linear, with histones |
| Examples | Bacteria, Cyanobacteria | Plants, Animals, Fungi |

## Cell Organelles

### Plasma Membrane
- **Fluid Mosaic Model** (Singer & Nicolson)
- Phospholipid bilayer with proteins
- Selective permeability
- Functions: Protection, transport, cell recognition

### Nucleus
- **Nuclear envelope**: Double membrane with pores
- **Nucleolus**: rRNA synthesis
- **Chromatin**: DNA + Histones
- **Nucleoplasm**: Contains enzymes

### Endoplasmic Reticulum
- **RER**: Ribosomes attached, protein synthesis
- **SER**: Lipid synthesis, detoxification

### Golgi Apparatus
- **Cis face**: Receiving side
- **Trans face**: Shipping side
- Functions: Modification, packaging, secretion

### Mitochondria
- **Double membrane**: Outer smooth, inner folded (cristae)
- **Matrix**: Contains 70S ribosomes, circular DNA
- **Function**: ATP synthesis (powerhouse)
- Semiautonomous organelle

### Plastids (Plants only)
| Type | Pigment | Function |
|------|---------|----------|
| Chloroplast | Chlorophyll | Photosynthesis |
| Chromoplast | Carotenoids | Color to flowers/fruits |
| Leucoplast | None | Storage |

### Lysosomes
- **Suicidal bags**: Contain hydrolytic enzymes
- pH ~5 (acidic)
- Autophagy, heterophagy

### Ribosomes
- **70S**: Prokaryotes (50S + 30S)
- **80S**: Eukaryotes (60S + 40S)
- Non-membrane bound
- Protein synthesis

### Cytoskeleton
- **Microtubules**: Tubulin (25 nm)
- **Microfilaments**: Actin (7 nm)
- **Intermediate filaments**: Various proteins (10 nm)

## Cell Junctions

| Type | Function | Location |
|------|----------|----------|
| Tight junction | Prevents leakage | Epithelial cells |
| Adhering junction | Cell adhesion | Heart, skin |
| Gap junction | Cell communication | Neurons, cardiac |
| Plasmodesmata | Cytoplasmic channels | Plant cells |
''',
    tags: ['cell biology', 'organelles', 'prokaryotic', 'eukaryotic', 'neet'],
    estimatedReadTime: 16,
    createdAt: DateTime(2024, 1, 15),
    rating: 4.9,
  ),

  StudyMaterial(
    id: 'neet_bio_biomolecules',
    title: 'Biomolecules - Complete Guide',
    description: 'Carbohydrates, proteins, lipids, nucleic acids',
    subjectId: 'biology',
    topicId: 'biomolecules',
    type: StudyMaterialType.notes,
    content: '''
# Biomolecules for NEET

## Carbohydrates

### Classification
| Type | Units | Examples |
|------|-------|----------|
| Monosaccharides | 1 | Glucose, Fructose, Ribose |
| Disaccharides | 2 | Sucrose, Maltose, Lactose |
| Oligosaccharides | 3-10 | Raffinose |
| Polysaccharides | >10 | Starch, Glycogen, Cellulose |

### Important Monosaccharides
- **Glucose** (C₆H₁₂O₆): Blood sugar, aldohexose
- **Fructose**: Fruit sugar, ketohexose
- **Galactose**: Component of lactose
- **Ribose** (C₅H₁₀O₅): In RNA
- **Deoxyribose**: In DNA

### Polysaccharides
- **Starch**: Storage in plants (amylose + amylopectin)
- **Glycogen**: Storage in animals (liver, muscles)
- **Cellulose**: Structural in plants (β-1,4 linkage)
- **Chitin**: Exoskeleton of arthropods

## Proteins

### Amino Acids
- 20 standard amino acids
- **Essential**: Cannot be synthesized (Phe, Val, Thr, Trp, Ile, Met, His, Leu, Lys)
- General structure: -NH₂ + -COOH + R group

### Protein Structure
| Level | Description | Bonds |
|-------|-------------|-------|
| Primary | Linear sequence | Peptide bonds |
| Secondary | α-helix, β-sheet | H-bonds |
| Tertiary | 3D folding | H, ionic, disulfide, hydrophobic |
| Quaternary | Multiple polypeptides | Same as tertiary |

### Protein Functions
- Enzymes (catalysis)
- Hormones (insulin)
- Structural (collagen, keratin)
- Transport (hemoglobin)
- Defense (antibodies)

## Lipids

### Classification
| Type | Components | Function |
|------|------------|----------|
| Simple (Fats) | Glycerol + Fatty acids | Energy storage |
| Compound | + Phosphate/Sugar | Membrane, signaling |
| Derived | Steroids, Terpenes | Hormones, vitamins |

### Fatty Acids
- **Saturated**: No double bonds (solid at RT)
- **Unsaturated**: Double bonds present (liquid at RT)
- **PUFA**: Omega-3, Omega-6

### Phospholipids
- Hydrophilic head + Hydrophobic tail
- Form cell membranes (bilayer)

## Nucleic Acids

### DNA vs RNA
| Feature | DNA | RNA |
|---------|-----|-----|
| Sugar | Deoxyribose | Ribose |
| Bases | A, T, G, C | A, U, G, C |
| Strands | Double | Usually single |
| Location | Nucleus, mitochondria | Nucleus, cytoplasm |

### Nucleotide Components
- Nitrogenous base + Pentose sugar + Phosphate

### Base Pairing (Chargaff's Rule)
- A = T (2 H-bonds)
- G ≡ C (3 H-bonds)

## Enzymes

### Properties
- Protein catalysts (except ribozymes)
- Highly specific
- Not consumed in reaction
- Lower activation energy

### Factors Affecting Activity
- Temperature (optimum ~37°C for humans)
- pH (specific for each enzyme)
- Substrate concentration
- Enzyme concentration
- Inhibitors

### Inhibition Types
- **Competitive**: Binds to active site
- **Non-competitive**: Binds to allosteric site
''',
    tags: ['biomolecules', 'proteins', 'carbohydrates', 'lipids', 'neet'],
    estimatedReadTime: 18,
    createdAt: DateTime(2024, 1, 16),
    rating: 4.8,
  ),

  StudyMaterial(
    id: 'neet_bio_genetics',
    title: 'Genetics & Molecular Biology',
    description: 'DNA replication, transcription, translation, inheritance',
    subjectId: 'biology',
    topicId: 'genetics',
    type: StudyMaterialType.notes,
    content: '''
# Genetics & Molecular Biology for NEET

## Mendelian Genetics

### Laws of Inheritance

**Law of Dominance**
- In heterozygote, one allele masks the other
- Dominant expressed, recessive hidden

**Law of Segregation**
- Alleles separate during gamete formation
- Each gamete gets one allele

**Law of Independent Assortment**
- Alleles of different genes assort independently
- Valid for genes on different chromosomes

### Monohybrid Cross
Tt × Tt → TT : Tt : tt = 1 : 2 : 1 (genotype)
              Tall : Dwarf = 3 : 1 (phenotype)

### Dihybrid Cross
TtRr × TtRr → 9:3:3:1 ratio
9 Tall-Round : 3 Tall-Wrinkled : 3 Dwarf-Round : 1 Dwarf-Wrinkled

## Deviations from Mendelian Ratios

| Phenomenon | Ratio | Example |
|------------|-------|---------|
| Incomplete dominance | 1:2:1 | Snapdragon flower |
| Codominance | 1:2:1 | ABO blood groups |
| Lethal alleles | 2:1 | Yellow mice |
| Complementary genes | 9:7 | Flower color |
| Epistasis | 9:3:4 | Coat color in mice |

## DNA Replication

### Features
- **Semiconservative**: Each new DNA has one old, one new strand
- **Bidirectional**: Proceeds in both directions from origin
- **Semidiscontinuous**: Leading (continuous), Lagging (Okazaki fragments)

### Enzymes
| Enzyme | Function |
|--------|----------|
| Helicase | Unwinds DNA |
| Topoisomerase | Relieves tension |
| Primase | Synthesizes RNA primer |
| DNA Polymerase III | Synthesizes new strand |
| DNA Polymerase I | Removes primers, fills gaps |
| Ligase | Joins Okazaki fragments |

## Transcription

### Process
DNA → mRNA (in nucleus)

### RNA Polymerase
- Prokaryotes: Single type
- Eukaryotes: I (rRNA), II (mRNA), III (tRNA)

### Steps
1. **Initiation**: Binds to promoter
2. **Elongation**: 5' → 3' synthesis
3. **Termination**: Stop signal

### Post-transcriptional Modifications (Eukaryotes)
- 5' capping
- 3' polyadenylation
- Splicing (introns removed)

## Translation

### Genetic Code
- **Triplet**: 3 nucleotides = 1 codon
- **Degenerate**: Multiple codons for same amino acid
- **Universal**: Same in most organisms
- **Non-overlapping**: Codons read sequentially

### Start/Stop Codons
- Start: AUG (Methionine)
- Stop: UAA, UAG, UGA

### Steps
1. **Initiation**: Small ribosomal subunit binds mRNA
2. **Elongation**: tRNA brings amino acids, peptide bond forms
3. **Termination**: Stop codon reached, polypeptide released

## Chromosomal Basis of Inheritance

### Sex Determination
- **XX-XY**: Humans, Drosophila (male heterogametic)
- **ZZ-ZW**: Birds, butterflies (female heterogametic)
- **XX-XO**: Grasshoppers

### Sex-linked Inheritance
- Color blindness, Hemophilia (X-linked recessive)
- Y-linked: Hypertrichosis
''',
    tags: ['genetics', 'dna replication', 'transcription', 'mendel', 'neet'],
    estimatedReadTime: 20,
    createdAt: DateTime(2024, 1, 17),
    rating: 4.9,
  ),

  // ==================== BIOLOGY - ZOOLOGY ====================
  
  StudyMaterial(
    id: 'neet_bio_human_physiology',
    title: 'Human Physiology - Systems Overview',
    description: 'Digestive, respiratory, circulatory, excretory systems',
    subjectId: 'biology',
    topicId: 'human_physiology',
    type: StudyMaterialType.notes,
    content: '''
# Human Physiology for NEET

## Digestive System

### Organs & Functions
| Organ | Secretion | Enzyme | Substrate |
|-------|-----------|--------|-----------|
| Mouth | Saliva | Salivary amylase | Starch |
| Stomach | Gastric juice | Pepsin | Proteins |
| Liver | Bile | - | Emulsifies fats |
| Pancreas | Pancreatic juice | Trypsin, Lipase, Amylase | Multiple |
| Small intestine | Intestinal juice | Maltase, Lactase | Disaccharides |

### Absorption
- **Small intestine**: Primary absorption site
- **Villi & microvilli**: Increase surface area
- **Amino acids, glucose**: Active transport
- **Fatty acids**: Lacteals (lymph)

## Respiratory System

### Pathway
Nostrils → Pharynx → Larynx → Trachea → Bronchi → Bronchioles → Alveoli

### Lung Volumes
| Volume | Definition | Value |
|--------|------------|-------|
| Tidal Volume (TV) | Normal breath | 500 mL |
| Inspiratory Reserve (IRV) | Extra inhale | 2500-3000 mL |
| Expiratory Reserve (ERV) | Extra exhale | 1000-1100 mL |
| Residual Volume (RV) | Cannot be expelled | 1100-1200 mL |

### Capacities
- **Vital Capacity** = TV + IRV + ERV (~4800 mL)
- **Total Lung Capacity** = VC + RV (~5800 mL)

### Gas Exchange
- Partial pressure gradient drives diffusion
- Hb + O₂ ⇌ HbO₂ (oxyhemoglobin)
- Bohr effect: ↑CO₂ → ↓O₂ affinity

## Circulatory System

### Heart Chambers
- **Right atrium**: Receives deoxygenated blood
- **Right ventricle**: Pumps to lungs
- **Left atrium**: Receives oxygenated blood
- **Left ventricle**: Pumps to body

### Cardiac Cycle
- **Systole**: Contraction (0.3 s)
- **Diastole**: Relaxation (0.5 s)
- Heart rate: ~72 beats/min

### Conduction System
SA node → AV node → Bundle of His → Purkinje fibers

### Blood Pressure
- Normal: 120/80 mmHg
- Systolic/Diastolic

### Blood Groups
| Type | Antigens | Antibodies | Can donate to | Can receive from |
|------|----------|------------|---------------|------------------|
| A | A | Anti-B | A, AB | A, O |
| B | B | Anti-A | B, AB | B, O |
| AB | A, B | None | AB | All (Universal recipient) |
| O | None | Anti-A, Anti-B | All (Universal donor) | O |

## Excretory System

### Nephron Structure
Glomerulus → Bowman's capsule → PCT → Loop of Henle → DCT → Collecting duct

### Urine Formation
1. **Glomerular filtration** (125 mL/min)
2. **Tubular reabsorption** (glucose, amino acids, Na⁺)
3. **Tubular secretion** (H⁺, K⁺, drugs)

### Hormonal Regulation
- **ADH**: Water reabsorption
- **Aldosterone**: Na⁺ reabsorption
- **ANF**: Inhibits Na⁺ reabsorption
''',
    tags: ['human physiology', 'digestion', 'respiration', 'circulation', 'neet'],
    estimatedReadTime: 18,
    createdAt: DateTime(2024, 1, 18),
    rating: 4.9,
  ),

  StudyMaterial(
    id: 'neet_bio_plant_physiology',
    title: 'Plant Physiology - Key Concepts',
    description: 'Photosynthesis, respiration, transport in plants',
    subjectId: 'biology',
    topicId: 'plant_physiology',
    type: StudyMaterialType.notes,
    content: '''
# Plant Physiology for NEET

## Photosynthesis

### Overall Equation
6CO₂ + 12H₂O → C₆H₁₂O₆ + 6O₂ + 6H₂O

### Light Reactions (Thylakoid)
- **Photosystem II** (P680): Water splitting, O₂ evolution
- **Photosystem I** (P700): NADPH formation
- **Electron transport chain**: ATP synthesis

Products: ATP, NADPH, O₂

### Dark Reactions (Stroma) - Calvin Cycle

**Stages:**
1. **Carboxylation**: CO₂ + RuBP → 2 × 3-PGA (Rubisco enzyme)
2. **Reduction**: 3-PGA → G3P (uses ATP, NADPH)
3. **Regeneration**: G3P → RuBP

6 turns produce 1 glucose molecule

### C3 vs C4 vs CAM Plants

| Feature | C3 | C4 | CAM |
|---------|----|----|-----|
| First product | 3-PGA | OAA | OAA |
| CO₂ acceptor | RuBP | PEP | PEP |
| Kranz anatomy | Absent | Present | Absent |
| Photorespiration | High | Low | Low |
| Examples | Rice, Wheat | Maize, Sugarcane | Cacti, Opuntia |

### Factors Affecting Photosynthesis
- Light intensity
- CO₂ concentration
- Temperature
- Water availability

## Respiration

### Glycolysis (Cytoplasm)
Glucose → 2 Pyruvate
Net gain: 2 ATP, 2 NADH

### Krebs Cycle (Mitochondrial matrix)
Acetyl CoA → CO₂ + ATP + NADH + FADH₂
Per glucose: 2 ATP, 6 NADH, 2 FADH₂

### ETC (Inner mitochondrial membrane)
NADH → 3 ATP, FADH₂ → 2 ATP
Total: 32-34 ATP per glucose

### Respiratory Quotient (RQ)
RQ = CO₂ evolved / O₂ consumed
- Carbohydrates: RQ = 1
- Fats: RQ < 1 (~0.7)
- Proteins: RQ ~0.9

## Transport in Plants

### Water Absorption
- **Apoplast pathway**: Through cell walls
- **Symplast pathway**: Through cytoplasm via plasmodesmata

### Ascent of Sap
- **Cohesion-tension theory** (Dixon & Joly)
- Transpiration pull is main driving force
- Water molecules cohesive due to H-bonds

### Transpiration
- **Stomatal** (90-95%): Through stomata
- **Cuticular** (5-10%): Through cuticle
- **Lenticular** (<1%): Through lenticels

### Factors Affecting Transpiration
- Light, Temperature, Humidity, Wind velocity

### Translocation of Solutes
- **Pressure flow hypothesis** (Munch)
- Source (leaves) → Sink (roots, fruits)
- Through phloem sieve tubes
- Bidirectional

## Plant Hormones

| Hormone | Site | Function |
|---------|------|----------|
| Auxin | Shoot tips | Cell elongation, apical dominance |
| Gibberellin | Root/shoot tips | Stem elongation, seed germination |
| Cytokinin | Root tips | Cell division, delay senescence |
| ABA | Leaves, seeds | Stomatal closure, dormancy |
| Ethylene | Ripening fruits | Fruit ripening, senescence |
''',
    tags: ['plant physiology', 'photosynthesis', 'respiration', 'transport', 'neet'],
    estimatedReadTime: 18,
    createdAt: DateTime(2024, 1, 19),
    rating: 4.8,
  ),

  // ==================== PHYSICS ====================
  
  StudyMaterial(
    id: 'neet_physics_optics',
    title: 'Ray Optics & Wave Optics',
    description: 'Reflection, refraction, interference, diffraction',
    subjectId: 'physics',
    topicId: 'optics',
    type: StudyMaterialType.formula,
    content: '''
# Optics for NEET

## Ray Optics

### Reflection
- Angle of incidence = Angle of reflection
- Image in plane mirror: Same size, virtual, laterally inverted

### Mirror Formula
**1/f = 1/v + 1/u**

### Magnification
m = -v/u = h'/h

### Sign Convention
- Distances measured from pole
- Along incident ray: positive
- Against incident ray: negative

### Refraction

**Snell's Law**
n₁ sin θ₁ = n₂ sin θ₂

**Refractive Index**
n = c/v = sin i/sin r

### Critical Angle & TIR
sin θc = n₂/n₁ (n₁ > n₂)
Total internal reflection: θ > θc

### Lens Formula
**1/f = 1/v - 1/u**

### Lens Maker's Formula
1/f = (n-1)(1/R₁ - 1/R₂)

### Power of Lens
P = 1/f (in diopters when f in meters)

### Combination of Lenses
P = P₁ + P₂ (in contact)

## Optical Instruments

### Simple Microscope
M = 1 + D/f (D = 25 cm)

### Compound Microscope
M = (L/f₀)(D/fₑ)
- f₀: Objective focal length
- fₑ: Eyepiece focal length
- L: Tube length

### Telescope (Astronomical)
M = f₀/fₑ
Length = f₀ + fₑ

## Wave Optics

### Huygens' Principle
Every point on wavefront acts as secondary source.

### Young's Double Slit Experiment

**Path difference**
Δx = d sinθ ≈ dy/D

**Bright fringes (constructive)**
Δx = nλ, where n = 0, 1, 2...
yₙ = nλD/d

**Dark fringes (destructive)**
Δx = (2n-1)λ/2
yₙ = (2n-1)λD/2d

**Fringe width**
β = λD/d

### Diffraction

**Single slit minima**
a sinθ = nλ

**Central maximum width**
2λD/a

### Polarization

**Malus' Law**
I = I₀ cos²θ

**Brewster's Angle**
tan θB = n₂/n₁
Reflected ray polarized perpendicular to plane of incidence
''',
    tags: ['optics', 'reflection', 'refraction', 'interference', 'neet'],
    estimatedReadTime: 15,
    createdAt: DateTime(2024, 1, 20),
    rating: 4.8,
  ),

  StudyMaterial(
    id: 'neet_physics_modern',
    title: 'Modern Physics - Atoms & Nuclei',
    description: 'Atomic models, radioactivity, nuclear reactions',
    subjectId: 'physics',
    topicId: 'modern_physics',
    type: StudyMaterialType.notes,
    content: '''
# Modern Physics for NEET

## Atomic Models

### Rutherford Model
- Nucleus: Positive, dense core
- Electrons orbit around nucleus
- Most of atom is empty space

### Bohr Model

**Postulates:**
1. Electrons in stationary orbits
2. Angular momentum quantized: mvr = nℏ
3. Energy emitted/absorbed in transitions: E = hν

**Energy of electron**
Eₙ = -13.6 Z²/n² eV

**Radius of orbit**
rₙ = 0.529 n²/Z Å

**Velocity**
vₙ = 2.18 × 10⁶ Z/n m/s

### Hydrogen Spectrum

| Series | Transition to n | Region |
|--------|-----------------|--------|
| Lyman | 1 | UV |
| Balmer | 2 | Visible |
| Paschen | 3 | IR |
| Brackett | 4 | IR |
| Pfund | 5 | Far IR |

**Rydberg Formula**
1/λ = RZ²(1/n₁² - 1/n₂²)
R = 1.097 × 10⁷ m⁻¹

## Dual Nature of Matter

### Photoelectric Effect

**Einstein's equation**
KE_max = hν - φ

**Threshold frequency**
ν₀ = φ/h

**Stopping potential**
eV₀ = hν - φ

### de Broglie Wavelength
λ = h/mv = h/p

For electron accelerated through V:
λ = 12.27/√V Å

## Radioactivity

### Types of Decay

| Radiation | Nature | Charge | Mass | Penetration |
|-----------|--------|--------|------|-------------|
| α | He nucleus | +2 | 4 amu | Low (paper) |
| β⁻ | Electron | -1 | ~0 | Medium (Al) |
| γ | EM wave | 0 | 0 | High (Pb) |

### Decay Laws

**Activity**
A = λN = A₀e^(-λt)

**Half-life**
T₁/₂ = 0.693/λ

**Mean life**
τ = 1/λ = T₁/₂/0.693

**After n half-lives**
N = N₀/2ⁿ

### Nuclear Reactions

**α-decay**
ᴬ_Z X → ᴬ⁻⁴_Z₋₂ Y + ⁴₂He

**β⁻-decay**
ᴬ_Z X → ᴬ_Z₊₁ Y + e⁻ + ν̄ₑ

**β⁺-decay**
ᴬ_Z X → ᴬ_Z₋₁ Y + e⁺ + νₑ

## Nuclear Physics

### Mass-Energy Equivalence
E = mc²

### Binding Energy
BE = [Zm_p + Nm_n - M]c²
BE per nucleon indicates stability

### Nuclear Fission
Heavy nucleus splits into lighter nuclei
Example: ²³⁵U + n → ¹⁴¹Ba + ⁹²Kr + 3n + Energy

### Nuclear Fusion
Light nuclei combine to form heavier nucleus
Example: ²₁H + ³₁H → ⁴₂He + n + Energy

Fusion releases more energy per nucleon than fission.
''',
    tags: ['modern physics', 'atoms', 'radioactivity', 'nuclear', 'neet'],
    estimatedReadTime: 17,
    createdAt: DateTime(2024, 1, 21),
    rating: 4.9,
  ),

  // ==================== CHEMISTRY ====================
  
  StudyMaterial(
    id: 'neet_chem_organic_reactions',
    title: 'Organic Chemistry - Reaction Mechanisms',
    description: 'Substitution, elimination, addition reactions',
    subjectId: 'chemistry',
    topicId: 'organic_chemistry',
    type: StudyMaterialType.notes,
    content: '''
# Organic Reactions for NEET

## Reaction Types

### Substitution Reactions

**SN1 (Substitution Nucleophilic Unimolecular)**
- Rate = k[substrate]
- Two steps: Carbocation formation, nucleophilic attack
- Favored by: 3° > 2° > 1° substrates, polar protic solvents
- Racemization occurs

**SN2 (Substitution Nucleophilic Bimolecular)**
- Rate = k[substrate][nucleophile]
- Single step, backside attack
- Favored by: 1° > 2° > 3° substrates, polar aprotic solvents
- Inversion of configuration (Walden inversion)

### Elimination Reactions

**E1 (Unimolecular)**
- Rate = k[substrate]
- Carbocation intermediate
- Often competes with SN1

**E2 (Bimolecular)**
- Rate = k[substrate][base]
- Single step, antiperiplanar geometry
- Strong bases favor E2

### Zaitsev's Rule
More substituted alkene is major product (more stable)

### Saytzeff vs Hofmann

| Product | Condition | Example base |
|---------|-----------|--------------|
| Saytzeff | Normal | OH⁻, OR⁻ |
| Hofmann | Bulky base | t-BuO⁻ |

## Addition Reactions

### Electrophilic Addition to Alkenes

**Markovnikov's Rule**
Hydrogen adds to carbon with more H's
(Positive part to more substituted carbon)

**Anti-Markovnikov**
Occurs with HBr + peroxide (radical mechanism)

### Common Additions
| Reagent | Product |
|---------|---------|
| H₂/Pt | Alkane |
| X₂ | Vicinal dihalide |
| HX | Haloalkane |
| H₂O/H⁺ | Alcohol |
| KMnO₄ (cold, dilute) | Diol |

### Addition to Alkynes
- One equivalent: Alkene
- Two equivalents: Saturated product

## Oxidation Reactions

### Alcohols
- 1° → Aldehyde → Carboxylic acid
- 2° → Ketone
- 3° → No reaction (C-C cleavage with strong oxidizers)

### Common Oxidizing Agents
- KMnO₄ (alkaline): Strong
- K₂Cr₂O₇/H⁺: Strong
- PCC: Mild (aldehydes from 1° alcohols)
- Collins reagent: Mild

## Reduction Reactions

### Carbonyl Reduction
| Compound | Product | Reagent |
|----------|---------|---------|
| Aldehyde | 1° Alcohol | NaBH₄, LiAlH₄ |
| Ketone | 2° Alcohol | NaBH₄, LiAlH₄ |
| Carboxylic acid | 1° Alcohol | LiAlH₄ |
| Ester | 1° Alcohol | LiAlH₄ |
| Amide | Amine | LiAlH₄ |

### Clemmensen Reduction
RCHO/RCOR' + Zn-Hg/HCl → RCH₃/RCH₂R'

### Wolff-Kishner Reduction
RCHO/RCOR' + NH₂NH₂/KOH → RCH₃/RCH₂R'

## Named Reactions

| Reaction | Conversion |
|----------|------------|
| Cannizzaro | Aldehyde → Alcohol + Acid |
| Aldol | Aldehyde + Aldehyde → β-hydroxyaldehyde |
| Claisen | Ester + Ester → β-ketoester |
| Friedel-Crafts | Alkylation/Acylation of benzene |
| Wurtz | 2 R-X + 2Na → R-R |
| Sandmeyer | Diazonium → Halide/Cyanide |
''',
    tags: ['organic chemistry', 'reactions', 'mechanisms', 'sn1 sn2', 'neet'],
    estimatedReadTime: 18,
    createdAt: DateTime(2024, 1, 22),
    rating: 4.8,
  ),

  StudyMaterial(
    id: 'neet_chem_coordination',
    title: 'Coordination Compounds',
    description: 'Werner theory, IUPAC naming, isomerism, CFT',
    subjectId: 'chemistry',
    topicId: 'coordination_chemistry',
    type: StudyMaterialType.notes,
    content: '''
# Coordination Compounds for NEET

## Basic Concepts

### Terminology
- **Central metal ion**: Accepts electron pairs
- **Ligands**: Donate electron pairs
- **Coordination number**: Number of bonds from ligands
- **Coordination sphere**: [Metal + Ligands]

### Types of Ligands

| Type | Donor atoms | Examples |
|------|-------------|----------|
| Monodentate | 1 | Cl⁻, NH₃, H₂O |
| Bidentate | 2 | en (ethylenediamine), oxalate |
| Polydentate | >2 | EDTA (hexadentate) |
| Ambidentate | 2 (one at a time) | SCN⁻, NO₂⁻ |

### Chelates
Complexes with polydentate ligands forming rings.
More stable than monodentate complexes (chelate effect).

## Werner's Theory

### Postulates
1. Metals have two types of valencies:
   - Primary (ionic, satisfied by anions)
   - Secondary (coordinate, satisfied by ligands)
2. Secondary valency = Coordination number
3. Ligands directed in space around metal

## IUPAC Nomenclature

### Rules
1. Cation named before anion
2. Ligands in alphabetical order (before metal)
3. Metal name: neutral/cation as-is, anion with -ate
4. Oxidation state in Roman numerals

### Ligand Prefixes
- Neutral: aqua, ammine, carbonyl
- Anionic: chlorido, hydroxido, cyanido

### Examples
- [Co(NH₃)₆]Cl₃: Hexaamminecobalt(III) chloride
- K₄[Fe(CN)₆]: Potassium hexacyanidoferrate(II)
- [Pt(NH₃)₂Cl₂]: Diamminedichloridoplatinum(II)

## Isomerism

### Structural Isomerism

| Type | Description |
|------|-------------|
| Ionization | Different ions in solution |
| Linkage | Different donor atom (ambidentate) |
| Coordination | Exchange of ligands between ions |
| Hydrate | Different number of water molecules |

### Stereoisomerism

**Geometrical (cis-trans)**
- Square planar [MA₂B₂]: cis and trans
- Octahedral [MA₄B₂]: cis (adjacent) and trans (opposite)

**Optical**
- Non-superimposable mirror images
- Common in octahedral complexes with bidentate ligands

## Crystal Field Theory (CFT)

### Splitting in Octahedral Field
- **t₂g**: dxy, dyz, dxz (lower energy)
- **eg**: dx²-y², dz² (higher energy)
- Splitting energy: Δ₀

### Splitting in Tetrahedral Field
- **e**: dx²-y², dz² (lower energy)
- **t₂**: dxy, dyz, dxz (higher energy)
- Δt ≈ 4/9 Δ₀

### Spectrochemical Series
I⁻ < Br⁻ < Cl⁻ < F⁻ < OH⁻ < H₂O < NH₃ < en < NO₂⁻ < CN⁻ < CO

Weak field ←→ Strong field

### High Spin vs Low Spin
- **Weak field ligands**: High spin (unpaired electrons)
- **Strong field ligands**: Low spin (electrons paired)

### Magnetic Properties
- Paramagnetic: Unpaired electrons present
- Diamagnetic: All electrons paired
- μ = √(n(n+2)) BM (n = unpaired electrons)
''',
    tags: ['coordination compounds', 'werner', 'cft', 'isomerism', 'neet'],
    estimatedReadTime: 16,
    createdAt: DateTime(2024, 1, 23),
    rating: 4.7,
  ),
];
