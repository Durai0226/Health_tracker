import '../../../exam_prep/models/study_material_model.dart';

/// Comprehensive study materials for JEE Main & Advanced
final List<StudyMaterial> jeeStudyMaterials = [
  // ==================== PHYSICS ====================
  
  StudyMaterial(
    id: 'jee_physics_mechanics',
    title: 'Mechanics - Complete Guide',
    description: 'Kinematics, Laws of Motion, Work-Energy for JEE',
    subjectId: 'physics',
    topicId: 'mechanics',
    type: StudyMaterialType.notes,
    content: '''
# Mechanics for JEE

## Kinematics

### Equations of Motion (Constant Acceleration)
- v = u + at
- s = ut + ½at²
- v² = u² + 2as
- s = ½(u + v)t
- sₙ = u + a(n - ½) [distance in nth second]

### Projectile Motion
- **Time of flight**: T = 2u sinθ/g
- **Maximum height**: H = u² sin²θ/2g
- **Range**: R = u² sin2θ/g
- **Maximum range**: At θ = 45°, R_max = u²/g

### Relative Motion
- **v_AB** = v_A - v_B (velocity of A w.r.t. B)
- Rain-man problems: Use vector subtraction

## Newton's Laws of Motion

### First Law (Inertia)
Object remains at rest or uniform motion unless acted upon by external force.

### Second Law
**F = ma** (in vector form: F⃗ = m a⃗)

### Third Law
Every action has equal and opposite reaction.

### Friction
- **Static friction**: f_s ≤ μ_s N
- **Kinetic friction**: f_k = μ_k N
- μ_s > μ_k always

### Pseudo Force
In non-inertial frame: **F_pseudo = -ma** (opposite to acceleration of frame)

## Work, Energy & Power

### Work Done
- W = F⃗ · s⃗ = Fs cosθ
- Work by variable force: W = ∫F dx

### Kinetic Energy
- KE = ½mv²
- Work-Energy Theorem: W_net = ΔKE

### Potential Energy
- Gravitational: PE = mgh
- Spring: PE = ½kx²

### Conservation of Energy
- Total mechanical energy constant when only conservative forces act
- E = KE + PE = constant

### Power
- P = W/t = F⃗ · v⃗ = Fv cosθ
- Unit: Watt (W)

## Circular Motion

### Angular Quantities
- ω = dθ/dt (angular velocity)
- α = dω/dt (angular acceleration)
- v = rω, a_t = rα

### Centripetal Acceleration
- a_c = v²/r = ω²r (towards center)
- Centripetal force: F_c = mv²/r

### Banking of Roads
- tanθ = v²/rg (without friction)
- For safe speed range with friction: Use force analysis

## JEE Tips
1. Draw free body diagrams for every problem
2. Choose appropriate reference frame
3. Apply conservation laws when possible
4. Practice numerical problems with units
''',
    tags: ['mechanics', 'kinematics', 'newton laws', 'physics', 'jee'],
    estimatedReadTime: 18,
    createdAt: DateTime(2024, 1, 15),
    rating: 4.9,
  ),

  StudyMaterial(
    id: 'jee_physics_electrostatics',
    title: 'Electrostatics - Key Concepts',
    description: 'Coulombs law, electric field, potential for JEE',
    subjectId: 'physics',
    topicId: 'electrostatics',
    type: StudyMaterialType.notes,
    content: '''
# Electrostatics for JEE

## Coulomb's Law

### Force Between Point Charges
**F = kq₁q₂/r²** where k = 1/4πε₀ = 9 × 10⁹ Nm²/C²

### Vector Form
F⃗₁₂ = kq₁q₂/r² r̂₁₂

## Electric Field

### Definition
**E⃗ = F⃗/q₀** (force per unit positive test charge)

### Due to Point Charge
E = kq/r² (radially outward for +ve)

### Due to Continuous Distribution
- **Line charge**: E = λ/2πε₀r (infinite line)
- **Infinite plane**: E = σ/2ε₀
- **Charged sphere**: E = kQ/r² (outside), E = kQr/R³ (inside uniformly charged)

### Electric Field Lines
- Start from +ve, end at -ve
- Tangent gives direction of E⃗
- Density ∝ field strength
- Never intersect

## Electric Potential

### Definition
**V = W/q₀** (work done per unit charge from ∞ to point)

### Due to Point Charge
V = kq/r

### Relation with E⃗
- E = -dV/dr
- V = -∫E⃗ · dr⃗

### Equipotential Surfaces
- V constant on surface
- E⃗ perpendicular to surface
- Work done = 0 along surface

## Gauss's Law

### Statement
**∮E⃗ · dA⃗ = q_enclosed/ε₀**

### Applications
| Configuration | Electric Field |
|---------------|----------------|
| Infinite line | λ/2πε₀r |
| Infinite plane | σ/2ε₀ |
| Sphere (outside) | Q/4πε₀r² |
| Sphere (inside, uniform) | ρr/3ε₀ |

## Capacitors

### Parallel Plate Capacitor
C = ε₀A/d (with dielectric: C = κε₀A/d)

### Combinations
- **Series**: 1/C_eq = Σ(1/Cᵢ)
- **Parallel**: C_eq = ΣCᵢ

### Energy Stored
U = ½CV² = ½QV = Q²/2C

## JEE Advanced Tips
1. Use symmetry arguments
2. Apply Gauss's law for symmetric charge distributions
3. Remember boundary conditions for conductors
4. Practice integration for continuous distributions
''',
    tags: ['electrostatics', 'coulomb law', 'electric field', 'capacitor', 'jee'],
    estimatedReadTime: 16,
    createdAt: DateTime(2024, 1, 16),
    rating: 4.8,
  ),

  StudyMaterial(
    id: 'jee_physics_thermodynamics',
    title: 'Thermodynamics - Essential Formulas',
    description: 'Laws of thermodynamics and heat engines for JEE',
    subjectId: 'physics',
    topicId: 'thermodynamics',
    type: StudyMaterialType.formula,
    content: '''
# Thermodynamics Formulas for JEE

## Zeroth Law
If A is in thermal equilibrium with B, and B with C, then A is in equilibrium with C.

## First Law of Thermodynamics
**ΔU = Q - W** or **dU = δQ - δW**
- ΔU: Change in internal energy
- Q: Heat added to system
- W: Work done by system

## Ideal Gas Equations

### Equation of State
**PV = nRT** (R = 8.314 J/mol·K)

### Internal Energy
- Monoatomic: U = (3/2)nRT
- Diatomic: U = (5/2)nRT
- ΔU = nCᵥΔT

## Thermodynamic Processes

### Isothermal (ΔT = 0)
- PV = constant
- ΔU = 0
- W = nRT ln(V₂/V₁) = nRT ln(P₁/P₂)
- Q = W

### Isobaric (ΔP = 0)
- V/T = constant
- W = PΔV = nRΔT
- Q = nCₚΔT

### Isochoric (ΔV = 0)
- P/T = constant
- W = 0
- Q = ΔU = nCᵥΔT

### Adiabatic (Q = 0)
- PVᵞ = constant
- TVᵞ⁻¹ = constant
- W = (P₁V₁ - P₂V₂)/(γ-1) = nCᵥ(T₁ - T₂)
- ΔU = -W

## Specific Heats

### Molar Specific Heats
- At constant volume: Cᵥ = (f/2)R
- At constant pressure: Cₚ = Cᵥ + R
- γ = Cₚ/Cᵥ = 1 + 2/f

| Gas Type | f | Cᵥ | Cₚ | γ |
|----------|---|-----|-----|---|
| Monoatomic | 3 | (3/2)R | (5/2)R | 5/3 |
| Diatomic | 5 | (5/2)R | (7/2)R | 7/5 |
| Polyatomic | 6 | 3R | 4R | 4/3 |

## Second Law

### Kelvin-Planck Statement
No engine can convert all heat into work.

### Clausius Statement
Heat cannot flow from cold to hot without external work.

### Carnot Engine
- **Efficiency**: η = 1 - T_cold/T_hot = W/Q_hot
- Most efficient engine between two temperatures

## Heat Engines & Refrigerators

### Heat Engine
- η = W/Q_H = (Q_H - Q_C)/Q_H

### Refrigerator (COP)
- COP = Q_C/W = Q_C/(Q_H - Q_C)
- COP_Carnot = T_C/(T_H - T_C)
''',
    tags: ['thermodynamics', 'heat', 'carnot', 'laws', 'jee'],
    estimatedReadTime: 15,
    createdAt: DateTime(2024, 1, 17),
    rating: 4.9,
  ),

  // ==================== CHEMISTRY ====================
  
  StudyMaterial(
    id: 'jee_chem_atomic_structure',
    title: 'Atomic Structure - Complete Guide',
    description: 'Quantum numbers, orbitals, electronic configuration',
    subjectId: 'chemistry',
    topicId: 'atomic_structure',
    type: StudyMaterialType.notes,
    content: '''
# Atomic Structure for JEE

## Quantum Numbers

### Principal Quantum Number (n)
- Determines shell/energy level
- Values: 1, 2, 3, 4... (K, L, M, N...)
- Max electrons in shell: 2n²

### Azimuthal Quantum Number (l)
- Determines subshell shape
- Values: 0 to (n-1)
- l = 0 (s), 1 (p), 2 (d), 3 (f)

### Magnetic Quantum Number (mₗ)
- Determines orbital orientation
- Values: -l to +l (2l + 1 values)

### Spin Quantum Number (mₛ)
- Values: +½ or -½

## Shapes of Orbitals

| Orbital | Shape | Nodes |
|---------|-------|-------|
| s | Spherical | n-1 radial |
| p | Dumbbell | 1 nodal plane |
| d | Double dumbbell | 2 nodal planes |

### Radial Nodes
Number = n - l - 1

### Angular Nodes
Number = l

### Total Nodes
Number = n - 1

## Electronic Configuration

### Aufbau Principle
Fill orbitals in order of increasing energy:
1s → 2s → 2p → 3s → 3p → 4s → 3d → 4p → 5s...

### (n + l) Rule
Lower (n + l) filled first; if equal, lower n first.

### Pauli Exclusion Principle
No two electrons can have all four quantum numbers same.
Max 2 electrons per orbital with opposite spins.

### Hund's Rule
Electrons fill degenerate orbitals singly first with parallel spins.

## Exceptions
- **Cr**: [Ar] 3d⁵ 4s¹ (not 3d⁴ 4s²)
- **Cu**: [Ar] 3d¹⁰ 4s¹ (not 3d⁹ 4s²)
- Half-filled and fully-filled d orbitals are extra stable.

## Bohr Model

### Energy of Electron
E_n = -13.6 Z²/n² eV

### Radius of Orbit
r_n = 0.529 n²/Z Å

### Velocity
v_n = 2.18 × 10⁶ Z/n m/s

### Energy Relations
- E₂ - E₁ = hν (absorption)
- E₁ - E₂ = hν (emission)

## Photoelectric Effect

### Einstein's Equation
KE_max = hν - φ (work function)

### Threshold Frequency
ν₀ = φ/h

## de Broglie Wavelength
λ = h/mv = h/p

## Heisenberg Uncertainty
Δx · Δp ≥ ℏ/2
''',
    tags: ['atomic structure', 'quantum numbers', 'orbitals', 'chemistry', 'jee'],
    estimatedReadTime: 16,
    createdAt: DateTime(2024, 1, 18),
    rating: 4.8,
  ),

  StudyMaterial(
    id: 'jee_chem_chemical_bonding',
    title: 'Chemical Bonding - Key Concepts',
    description: 'VSEPR, hybridization, molecular orbital theory',
    subjectId: 'chemistry',
    topicId: 'chemical_bonding',
    type: StudyMaterialType.notes,
    content: '''
# Chemical Bonding for JEE

## Types of Bonds

### Ionic Bond
- Transfer of electrons
- High melting point, conducts in molten/aqueous state
- Lattice energy ∝ charge, ∝ 1/size

### Covalent Bond
- Sharing of electrons
- Directional bonds
- σ (sigma) and π (pi) bonds

### Coordinate Bond
- One atom donates both electrons
- Example: NH₄⁺, BF₄⁻

## VSEPR Theory

### Formula
**AXₙEₘ** where:
- A = Central atom
- X = Bonding pairs
- E = Lone pairs

### Geometries

| Type | Geometry | Example | Bond Angle |
|------|----------|---------|------------|
| AX₂ | Linear | BeCl₂ | 180° |
| AX₃ | Trigonal planar | BF₃ | 120° |
| AX₄ | Tetrahedral | CH₄ | 109.5° |
| AX₃E | Trigonal pyramidal | NH₃ | 107° |
| AX₂E₂ | Bent | H₂O | 104.5° |
| AX₅ | Trigonal bipyramidal | PCl₅ | 90°, 120° |
| AX₆ | Octahedral | SF₆ | 90° |

### Lone Pair Effect
Lone pairs repel more than bonding pairs.
LP-LP > LP-BP > BP-BP repulsion

## Hybridization

### Steric Number
SN = (bonding pairs) + (lone pairs on central atom)

| SN | Hybridization | Geometry |
|----|---------------|----------|
| 2 | sp | Linear |
| 3 | sp² | Trigonal planar |
| 4 | sp³ | Tetrahedral |
| 5 | sp³d | Trigonal bipyramidal |
| 6 | sp³d² | Octahedral |

### Bond Character
- More s character → shorter, stronger bond
- sp > sp² > sp³ (in terms of s character)

## Molecular Orbital Theory

### Linear Combination
ψ_bonding = ψ_A + ψ_B
ψ_antibonding = ψ_A - ψ_B

### Bond Order
**BO = (Nb - Na)/2**
- Nb = electrons in bonding MO
- Na = electrons in antibonding MO

### Energy Order
- For O₂, F₂: σ2s < σ*2s < σ2p < π2p < π*2p < σ*2p
- For N₂, C₂: σ2s < σ*2s < π2p < σ2p < π*2p < σ*2p

### Magnetic Properties
- Paramagnetic: unpaired electrons (O₂)
- Diamagnetic: all paired (N₂)

## Dipole Moment
μ = q × d (Debye units)
- Vector quantity
- Zero for symmetric molecules
''',
    tags: ['chemical bonding', 'vsepr', 'hybridization', 'mot', 'jee'],
    estimatedReadTime: 15,
    createdAt: DateTime(2024, 1, 19),
    rating: 4.7,
  ),

  StudyMaterial(
    id: 'jee_chem_equilibrium',
    title: 'Chemical Equilibrium - Formulas',
    description: 'Equilibrium constants, Le Chateliers principle',
    subjectId: 'chemistry',
    topicId: 'equilibrium',
    type: StudyMaterialType.formula,
    content: '''
# Chemical Equilibrium for JEE

## Law of Mass Action

For reaction: aA + bB ⇌ cC + dD

### Equilibrium Constant
**Kc = [C]^c[D]^d / [A]^a[B]^b**

### In Terms of Pressure
**Kp = (P_C)^c(P_D)^d / (P_A)^a(P_B)^b**

### Relation
**Kp = Kc(RT)^Δn** where Δn = (c+d) - (a+b)

## Reaction Quotient (Q)

- Q < K: Forward reaction favored
- Q > K: Backward reaction favored
- Q = K: At equilibrium

## Le Chatelier's Principle

### Effect of Concentration
- Increase reactant → Forward shift
- Increase product → Backward shift

### Effect of Pressure
- Increase P → Shift to fewer moles side
- Decrease P → Shift to more moles side

### Effect of Temperature
- Exothermic: ↑T → K decreases
- Endothermic: ↑T → K increases

### Catalyst Effect
- No change in K
- Equilibrium reached faster

## Degree of Dissociation (α)

For A ⇌ nB:
- Initial: 1, 0
- At equilibrium: (1-α), nα
- Total moles: 1 + (n-1)α

## Ionic Equilibrium

### Weak Acid (HA)
Ka = [H⁺][A⁻]/[HA] = Cα²/(1-α) ≈ Cα² (if α << 1)

### Weak Base (BOH)
Kb = [B⁺][OH⁻]/[BOH]

### Relation
**Ka × Kb = Kw** = 10⁻¹⁴ at 25°C

## pH Scale

### Definitions
- pH = -log[H⁺]
- pOH = -log[OH⁻]
- **pH + pOH = 14** (at 25°C)

### Buffer Solutions
**Henderson-Hasselbalch Equation**
- Acidic buffer: pH = pKa + log([Salt]/[Acid])
- Basic buffer: pOH = pKb + log([Salt]/[Base])

## Solubility Product (Ksp)

For salt: AₘBₙ ⇌ mA^n+ + nB^m-
**Ksp = [A^n+]^m[B^m-]^n**

### Solubility (s)
Ksp = (ms)^m(ns)^n

### Precipitation
- Q > Ksp: Precipitate forms
- Q < Ksp: No precipitate
''',
    tags: ['equilibrium', 'kc kp', 'le chatelier', 'ionic', 'jee'],
    estimatedReadTime: 14,
    createdAt: DateTime(2024, 1, 20),
    rating: 4.9,
  ),

  // ==================== MATHEMATICS ====================
  
  StudyMaterial(
    id: 'jee_math_calculus',
    title: 'Calculus - Differentiation & Integration',
    description: 'Complete calculus concepts for JEE',
    subjectId: 'mathematics',
    topicId: 'calculus',
    type: StudyMaterialType.notes,
    content: '''
# Calculus for JEE

## Limits

### Standard Limits
- lim(x→0) sinx/x = 1
- lim(x→0) tanx/x = 1
- lim(x→0) (1-cosx)/x² = 1/2
- lim(x→0) (eˣ-1)/x = 1
- lim(x→0) ln(1+x)/x = 1
- lim(x→∞) (1 + 1/x)ˣ = e

### L'Hôpital's Rule
For 0/0 or ∞/∞ forms:
lim f(x)/g(x) = lim f'(x)/g'(x)

## Differentiation

### Basic Rules
- d/dx(xⁿ) = nxⁿ⁻¹
- d/dx(eˣ) = eˣ
- d/dx(aˣ) = aˣ ln(a)
- d/dx(ln x) = 1/x
- d/dx(sin x) = cos x
- d/dx(cos x) = -sin x
- d/dx(tan x) = sec²x

### Chain Rule
d/dx[f(g(x))] = f'(g(x)) · g'(x)

### Product Rule
d/dx(uv) = u'v + uv'

### Quotient Rule
d/dx(u/v) = (u'v - uv')/v²

### Implicit Differentiation
Differentiate both sides w.r.t. x, treating y as function of x.

### Parametric Differentiation
If x = f(t), y = g(t):
dy/dx = (dy/dt)/(dx/dt)

## Applications of Derivatives

### Maxima & Minima
- f'(x) = 0 at critical points
- f''(x) > 0 → Local minimum
- f''(x) < 0 → Local maximum

### Rate of Change
dy/dt = (dy/dx)(dx/dt)

### Tangent & Normal
- Slope of tangent = dy/dx
- Slope of normal = -dx/dy

## Integration

### Basic Integrals
- ∫xⁿ dx = xⁿ⁺¹/(n+1) + C
- ∫eˣ dx = eˣ + C
- ∫1/x dx = ln|x| + C
- ∫sin x dx = -cos x + C
- ∫cos x dx = sin x + C
- ∫sec²x dx = tan x + C

### Integration by Parts
∫u dv = uv - ∫v du
ILATE rule: Inverse, Log, Algebraic, Trig, Exponential

### Substitution
∫f(g(x))g'(x) dx = ∫f(u) du where u = g(x)

### Partial Fractions
Break rational functions into simpler fractions.

## Definite Integrals

### Properties
- ∫[a to b] f(x) dx = -∫[b to a] f(x) dx
- ∫[a to b] f(x) dx = ∫[a to c] f(x) dx + ∫[c to b] f(x) dx
- ∫[0 to a] f(x) dx = ∫[0 to a] f(a-x) dx

### King Property
∫[a to b] f(x) dx = ∫[a to b] f(a+b-x) dx

### Even/Odd Functions
- Even: ∫[-a to a] f(x) dx = 2∫[0 to a] f(x) dx
- Odd: ∫[-a to a] f(x) dx = 0
''',
    tags: ['calculus', 'differentiation', 'integration', 'limits', 'jee'],
    estimatedReadTime: 18,
    createdAt: DateTime(2024, 1, 21),
    rating: 4.9,
  ),

  StudyMaterial(
    id: 'jee_math_coordinate',
    title: 'Coordinate Geometry - All Formulas',
    description: 'Straight lines, circles, conics for JEE',
    subjectId: 'mathematics',
    topicId: 'coordinate_geometry',
    type: StudyMaterialType.formula,
    content: '''
# Coordinate Geometry for JEE

## Straight Lines

### Distance Formula
d = √[(x₂-x₁)² + (y₂-y₁)²]

### Section Formula
Internal: ((mx₂+nx₁)/(m+n), (my₂+ny₁)/(m+n))
External: ((mx₂-nx₁)/(m-n), (my₂-ny₁)/(m-n))

### Slope
m = (y₂-y₁)/(x₂-x₁) = tanθ

### Equation Forms
- **Point-slope**: y - y₁ = m(x - x₁)
- **Slope-intercept**: y = mx + c
- **Two-point**: (y-y₁)/(y₂-y₁) = (x-x₁)/(x₂-x₁)
- **Intercept**: x/a + y/b = 1
- **Normal**: x cosα + y sinα = p

### Distance from Point to Line
d = |ax₁ + by₁ + c|/√(a² + b²)

### Angle Between Lines
tanθ = |m₁ - m₂|/(1 + m₁m₂)

## Circles

### Standard Form
(x - h)² + (y - k)² = r²
Center: (h, k), Radius: r

### General Form
x² + y² + 2gx + 2fy + c = 0
Center: (-g, -f), Radius: √(g² + f² - c)

### Tangent at Point (x₁, y₁)
xx₁ + yy₁ + g(x+x₁) + f(y+y₁) + c = 0

### Length of Tangent
L = √(x₁² + y₁² + 2gx₁ + 2fy₁ + c)

### Chord of Contact
xx₁ + yy₁ + g(x+x₁) + f(y+y₁) + c = 0

## Parabola

### Standard Forms
| Form | Focus | Directrix | Axis |
|------|-------|-----------|------|
| y² = 4ax | (a, 0) | x = -a | x-axis |
| y² = -4ax | (-a, 0) | x = a | x-axis |
| x² = 4ay | (0, a) | y = -a | y-axis |
| x² = -4ay | (0, -a) | y = a | y-axis |

### Parametric Form
x = at², y = 2at

### Tangent
y = mx + a/m (for y² = 4ax)

## Ellipse

### Standard Form
x²/a² + y²/b² = 1 (a > b)

### Key Elements
- Foci: (±ae, 0) where e = √(1 - b²/a²)
- Directrix: x = ±a/e
- Major axis: 2a
- Minor axis: 2b

### Parametric Form
x = a cosθ, y = b sinθ

### Tangent
x cosθ/a + y sinθ/b = 1

## Hyperbola

### Standard Form
x²/a² - y²/b² = 1

### Key Elements
- Foci: (±ae, 0) where e = √(1 + b²/a²)
- Asymptotes: y = ±(b/a)x
- Rectangular: a = b (e = √2)

### Parametric Form
x = a secθ, y = b tanθ
''',
    tags: ['coordinate geometry', 'lines', 'circles', 'conics', 'jee'],
    estimatedReadTime: 16,
    createdAt: DateTime(2024, 1, 22),
    rating: 4.8,
  ),

  StudyMaterial(
    id: 'jee_math_vectors',
    title: 'Vectors & 3D Geometry',
    description: 'Vector algebra and 3D coordinate geometry',
    subjectId: 'mathematics',
    topicId: 'vectors',
    type: StudyMaterialType.notes,
    content: '''
# Vectors & 3D Geometry for JEE

## Vector Basics

### Representation
a⃗ = aₓî + aᵧĵ + a_zk̂

### Magnitude
|a⃗| = √(aₓ² + aᵧ² + a_z²)

### Unit Vector
â = a⃗/|a⃗|

## Vector Operations

### Addition
a⃗ + b⃗ = (aₓ+bₓ)î + (aᵧ+bᵧ)ĵ + (a_z+b_z)k̂

### Dot Product (Scalar)
a⃗ · b⃗ = |a||b| cosθ = aₓbₓ + aᵧbᵧ + a_zb_z

Properties:
- Commutative: a⃗ · b⃗ = b⃗ · a⃗
- If perpendicular: a⃗ · b⃗ = 0

### Cross Product (Vector)
a⃗ × b⃗ = |a||b| sinθ n̂

|a⃗ × b⃗| = |î  ĵ  k̂|
          |aₓ aᵧ a_z|
          |bₓ bᵧ b_z|

Properties:
- Anti-commutative: a⃗ × b⃗ = -b⃗ × a⃗
- If parallel: a⃗ × b⃗ = 0⃗

### Triple Products
- **Scalar**: [a⃗ b⃗ c⃗] = a⃗ · (b⃗ × c⃗) = Volume of parallelepiped
- **Vector**: a⃗ × (b⃗ × c⃗) = (a⃗ · c⃗)b⃗ - (a⃗ · b⃗)c⃗

## 3D Coordinate Geometry

### Distance Formula
d = √[(x₂-x₁)² + (y₂-y₁)² + (z₂-z₁)²]

### Section Formula
P = ((mx₂+nx₁)/(m+n), (my₂+ny₁)/(m+n), (mz₂+nz₁)/(m+n))

## Direction Ratios & Cosines

### Direction Cosines
l = cosα, m = cosβ, n = cosγ
l² + m² + n² = 1

### Relation
l = a/√(a²+b²+c²), etc.

## Straight Line in 3D

### Vector Form
r⃗ = a⃗ + λb⃗

### Cartesian Form
(x-x₁)/l = (y-y₁)/m = (z-z₁)/n

### Two Points
(x-x₁)/(x₂-x₁) = (y-y₁)/(y₂-y₁) = (z-z₁)/(z₂-z₁)

## Plane

### General Form
ax + by + cz + d = 0

### Normal Vector
n⃗ = aî + bĵ + ck̂

### Vector Form
r⃗ · n⃗ = d

### Distance from Point
d = |ax₁ + by₁ + cz₁ + d|/√(a² + b² + c²)

## Important Results

### Angle Between
- Lines: cosθ = |l₁l₂ + m₁m₂ + n₁n₂|
- Planes: cosθ = |a₁a₂ + b₁b₂ + c₁c₂|/(√(a₁²+b₁²+c₁²)·√(a₂²+b₂²+c₂²))
- Line & Plane: sinθ = |al + bm + cn|/(√(a²+b²+c²)·√(l²+m²+n²))

### Coplanarity
Four points A, B, C, D coplanar if:
[AB⃗  AC⃗  AD⃗] = 0
''',
    tags: ['vectors', '3d geometry', 'dot product', 'cross product', 'jee'],
    estimatedReadTime: 17,
    createdAt: DateTime(2024, 1, 23),
    rating: 4.8,
  ),

  StudyMaterial(
    id: 'jee_math_probability',
    title: 'Probability & Statistics',
    description: 'Probability distributions and statistics for JEE',
    subjectId: 'mathematics',
    topicId: 'probability',
    type: StudyMaterialType.notes,
    content: '''
# Probability & Statistics for JEE

## Basic Probability

### Definitions
- **Experiment**: Activity with uncertain outcomes
- **Sample Space (S)**: Set of all possible outcomes
- **Event**: Subset of sample space

### Probability Formula
P(E) = n(E)/n(S) = Favorable outcomes / Total outcomes

### Properties
- 0 ≤ P(E) ≤ 1
- P(S) = 1
- P(φ) = 0
- P(E') = 1 - P(E)

## Addition Theorem

### Mutually Exclusive Events
P(A ∪ B) = P(A) + P(B)

### General Formula
P(A ∪ B) = P(A) + P(B) - P(A ∩ B)

### For Three Events
P(A ∪ B ∪ C) = P(A) + P(B) + P(C) - P(A∩B) - P(B∩C) - P(A∩C) + P(A∩B∩C)

## Conditional Probability

### Definition
P(A|B) = P(A ∩ B)/P(B)

### Multiplication Theorem
P(A ∩ B) = P(A) · P(B|A) = P(B) · P(A|B)

### Independent Events
P(A ∩ B) = P(A) · P(B)
P(A|B) = P(A)

## Bayes' Theorem

P(Aᵢ|B) = P(Aᵢ) · P(B|Aᵢ) / Σ[P(Aⱼ) · P(B|Aⱼ)]

## Permutations & Combinations

### Factorial
n! = n × (n-1) × (n-2) × ... × 1

### Permutations
- ⁿPᵣ = n!/(n-r)!
- With repetition: nʳ
- Circular: (n-1)!

### Combinations
- ⁿCᵣ = n!/[r!(n-r)!]
- ⁿCᵣ = ⁿCₙ₋ᵣ
- ⁿC₀ + ⁿC₁ + ... + ⁿCₙ = 2ⁿ

## Probability Distributions

### Binomial Distribution
P(X = r) = ⁿCᵣ pʳ qⁿ⁻ʳ
- Mean: μ = np
- Variance: σ² = npq
- Standard deviation: σ = √(npq)

### Poisson Distribution
P(X = k) = e⁻λ λᵏ/k!
- Mean = Variance = λ

## Statistics

### Mean
- **Arithmetic**: x̄ = Σxᵢ/n
- **Weighted**: x̄ = Σwᵢxᵢ/Σwᵢ

### Median
Middle value when data is arranged in order.
For grouped data: Median = L + [(n/2 - cf)/f] × h

### Mode
Most frequent value.
Mode = L + [(f₁ - f₀)/(2f₁ - f₀ - f₂)] × h

### Variance
σ² = Σ(xᵢ - x̄)²/n = (Σxᵢ²/n) - (x̄)²

### Standard Deviation
σ = √variance

### Coefficient of Variation
CV = (σ/x̄) × 100%
''',
    tags: ['probability', 'statistics', 'binomial', 'permutation', 'jee'],
    estimatedReadTime: 16,
    createdAt: DateTime(2024, 1, 24),
    rating: 4.7,
  ),

  StudyMaterial(
    id: 'jee_math_complex',
    title: 'Complex Numbers - Complete Guide',
    description: 'Complex number operations, argand plane, roots',
    subjectId: 'mathematics',
    topicId: 'complex_numbers',
    type: StudyMaterialType.notes,
    content: '''
# Complex Numbers for JEE

## Basic Definitions

### Imaginary Unit
i = √(-1), i² = -1, i³ = -i, i⁴ = 1

### Complex Number
z = a + ib (a = real part, b = imaginary part)

### Conjugate
z̄ = a - ib

### Modulus
|z| = √(a² + b²)

### Argument
θ = tan⁻¹(b/a)
Principal argument: -π < θ ≤ π

## Polar Form

### Representation
z = r(cosθ + i sinθ) = re^(iθ)
where r = |z|, θ = arg(z)

### Euler's Formula
e^(iθ) = cosθ + i sinθ

## Operations

### Addition/Subtraction
(a + ib) ± (c + id) = (a ± c) + i(b ± d)

### Multiplication
(a + ib)(c + id) = (ac - bd) + i(ad + bc)

### Division
(a + ib)/(c + id) = [(a + ib)(c - id)]/[c² + d²]

### Properties
- z · z̄ = |z|²
- |z₁z₂| = |z₁||z₂|
- arg(z₁z₂) = arg(z₁) + arg(z₂)
- |z₁/z₂| = |z₁|/|z₂|
- arg(z₁/z₂) = arg(z₁) - arg(z₂)

## De Moivre's Theorem

### Statement
(cosθ + i sinθ)ⁿ = cos(nθ) + i sin(nθ)

### Applications
- Finding powers of complex numbers
- Finding roots of complex numbers

## nth Roots of Unity

### Definition
Solutions of zⁿ = 1

### Formula
zₖ = e^(2πik/n) = cos(2πk/n) + i sin(2πk/n)
for k = 0, 1, 2, ..., n-1

### Properties
- Sum of all nth roots = 0
- Product of all nth roots = (-1)^(n+1)
- Roots are equally spaced on unit circle

### Cube Roots of Unity
1, ω, ω² where ω = (-1 + i√3)/2
- 1 + ω + ω² = 0
- ω³ = 1

## Geometry of Complex Numbers

### Distance
|z₁ - z₂| = distance between z₁ and z₂

### Section Formula
z = (mz₂ + nz₁)/(m + n)

### Triangle Centroid
G = (z₁ + z₂ + z₃)/3

### Rotation
z' = z · e^(iθ) rotates z by angle θ about origin

### Circle
|z - z₀| = r → Circle with center z₀, radius r

### Line
Re(az + b) = 0 or |z - z₁| = |z - z₂| (perpendicular bisector)

## Important Inequalities

### Triangle Inequality
||z₁| - |z₂|| ≤ |z₁ + z₂| ≤ |z₁| + |z₂|
||z₁| - |z₂|| ≤ |z₁ - z₂| ≤ |z₁| + |z₂|
''',
    tags: ['complex numbers', 'argand', 'de moivre', 'roots of unity', 'jee'],
    estimatedReadTime: 15,
    createdAt: DateTime(2024, 1, 25),
    rating: 4.8,
  ),
];
