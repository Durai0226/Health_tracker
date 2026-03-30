import '../../../exam_prep/models/study_material_model.dart';

/// Comprehensive study materials for UPSC Civil Services
final List<StudyMaterial> upscStudyMaterials = [
  // ==================== INDIAN POLITY ====================
  
  StudyMaterial(
    id: 'upsc_polity_constitution',
    title: 'Indian Constitution - Fundamentals',
    description: 'Preamble, features, sources, amendments',
    subjectId: 'indian_polity',
    topicId: 'constitution',
    type: StudyMaterialType.notes,
    content: '''
# Indian Constitution for UPSC

## Historical Background

### Key Acts
| Year | Act | Significance |
|------|-----|--------------|
| 1773 | Regulating Act | First step to control EIC |
| 1858 | Govt of India Act | Crown rule begins |
| 1919 | Montagu-Chelmsford | Dyarchy introduced |
| 1935 | Govt of India Act | Provincial autonomy |
| 1947 | Independence Act | Partition, independence |

## Making of Constitution

### Constituent Assembly
- Formed: December 1946
- Chairman: Dr. Rajendra Prasad
- Drafting Committee Chairman: Dr. B.R. Ambedkar
- Sessions: 11 (2 years, 11 months, 18 days)
- Adopted: 26 November 1949
- Enacted: 26 January 1950

## Preamble

### Keywords
- **Sovereign**: Independent
- **Socialist**: (42nd Amendment, 1976)
- **Secular**: (42nd Amendment, 1976)
- **Democratic**: People's rule
- **Republic**: Elected head

### Ideals
- Justice: Social, economic, political
- Liberty: Thought, expression, belief, faith, worship
- Equality: Status and opportunity
- Fraternity: Dignity, unity and integrity

### Nature
- Part of Constitution (Kesavananda Bharati case)
- Cannot be amended to destroy basic structure

## Sources of Constitution

| Feature | Source |
|---------|--------|
| Parliamentary system | UK |
| Fundamental Rights | USA |
| DPSP | Ireland |
| Federal structure | Canada |
| Emergency provisions | Germany |
| Amendment procedure | South Africa |
| Fundamental Duties | USSR |
| Concurrent List | Australia |

## Features

### Lengthiest Constitution
- 395 Articles (originally)
- 470+ Articles (currently)
- 12 Schedules
- 25 Parts

### Federal with Unitary Bias
- Single citizenship
- Single judiciary
- All-India services
- Emergency provisions

### Parliamentary System
- Real vs nominal executive
- Collective responsibility
- Dissolution of Lower House

### Rigidity + Flexibility
- Simple majority (some provisions)
- Special majority (fundamental rights)
- Special majority + ratification (federal provisions)

## Schedules

| Schedule | Content |
|----------|---------|
| 1st | States and territories |
| 2nd | Salaries of officials |
| 3rd | Oaths and affirmations |
| 4th | Rajya Sabha seat allocation |
| 5th | Scheduled Areas |
| 6th | Tribal areas (NE states) |
| 7th | Three lists (Union, State, Concurrent) |
| 8th | 22 languages |
| 9th | Land reforms (beyond judicial review) |
| 10th | Anti-defection law |
| 11th | Panchayat powers |
| 12th | Municipality powers |

## Important Amendments

| Amendment | Year | Provision |
|-----------|------|-----------|
| 1st | 1951 | Land reforms, 9th Schedule |
| 7th | 1956 | Reorganization of states |
| 24th | 1971 | Parliament can amend any part |
| 42nd | 1976 | Mini Constitution |
| 44th | 1978 | Right to Property removed |
| 52nd | 1985 | Anti-defection law |
| 61st | 1989 | Voting age 21 to 18 |
| 73rd | 1992 | Panchayati Raj |
| 74th | 1992 | Municipalities |
| 86th | 2002 | Right to Education |
| 101st | 2016 | GST |
''',
    tags: ['polity', 'constitution', 'preamble', 'amendments', 'upsc'],
    estimatedReadTime: 16,
    createdAt: DateTime(2024, 1, 15),
    rating: 4.9,
  ),

  StudyMaterial(
    id: 'upsc_polity_fundamental_rights',
    title: 'Fundamental Rights & Duties',
    description: 'Articles 12-35, fundamental duties, writs',
    subjectId: 'indian_polity',
    topicId: 'fundamental_rights',
    type: StudyMaterialType.notes,
    content: '''
# Fundamental Rights for UPSC

## Overview (Part III, Articles 12-35)

### Six Categories (Originally Seven)
1. Right to Equality (14-18)
2. Right to Freedom (19-22)
3. Right Against Exploitation (23-24)
4. Right to Freedom of Religion (25-28)
5. Cultural & Educational Rights (29-30)
6. Right to Constitutional Remedies (32)

*Right to Property removed by 44th Amendment (now Article 300A)*

## Right to Equality (14-18)

### Article 14: Equality Before Law
- Rule of law
- Reasonable classification allowed

### Article 15: Non-Discrimination
- On grounds of religion, race, caste, sex, place of birth
- State can make special provisions for women, children, SC/ST

### Article 16: Equal Opportunity in Public Employment
- Reservation allowed for backward classes

### Article 17: Abolition of Untouchability
- Offense punishable by law

### Article 18: Abolition of Titles
- No titles except military/academic

## Right to Freedom (19-22)

### Article 19: Six Freedoms
1. Speech and expression
2. Assembly (peaceful, without arms)
3. Association (form unions)
4. Movement (throughout India)
5. Residence (in any part)
6. Profession/occupation

*Reasonable restrictions on grounds of: sovereignty, security, public order, decency, morality, etc.*

### Article 20: Protection Against Conviction
- No ex-post-facto laws
- No double jeopardy
- No self-incrimination

### Article 21: Right to Life & Liberty
- Expanded to include: Dignity, privacy, livelihood, education, health, clean environment

### Article 21A: Right to Education
- Free, compulsory education (6-14 years)
- Added by 86th Amendment (2002)

### Article 22: Protection Against Arrest
- Right to be informed of grounds
- Right to consult lawyer
- Production before magistrate within 24 hours
- *Preventive detention: Exception*

## Right Against Exploitation (23-24)

### Article 23: Prohibition of Traffic & Forced Labor
- Human trafficking prohibited
- Begar and similar forced labor prohibited

### Article 24: Child Labor
- No child below 14 in factories/mines/hazardous employment

## Right to Freedom of Religion (25-28)

### Article 25: Freedom of Conscience
- Practice, profess, propagate religion
- Subject to public order, morality, health

### Article 26: Religious Affairs Management
- Establish religious institutions
- Manage religious affairs
- Own property

### Article 27: No Tax for Religious Promotion

### Article 28: No Religious Instruction in State Schools

## Cultural & Educational Rights (29-30)

### Article 29: Protection of Minorities
- Conserve distinct culture, language, script

### Article 30: Educational Rights of Minorities
- Establish and administer educational institutions

## Right to Constitutional Remedies (32)

### Five Writs

| Writ | Meaning | Purpose |
|------|---------|---------|
| Habeas Corpus | Produce the body | Against illegal detention |
| Mandamus | We command | For public duty |
| Prohibition | To forbid | Against lower courts |
| Certiorari | To be certified | Quash lower court order |
| Quo Warranto | By what authority | Against illegal office |

## Fundamental Duties (Part IVA, Article 51A)

### 11 Duties (Added by 42nd Amendment)
1. Abide by Constitution, flag, anthem
2. Cherish freedom struggle ideals
3. Uphold sovereignty, unity, integrity
4. Defend country, render national service
5. Promote harmony, brotherhood
6. Preserve composite culture
7. Protect natural environment
8. Develop scientific temper
9. Safeguard public property
10. Strive for excellence
11. Provide education to children (86th Amendment)

*Not justiciable but can be enforced through legislation*
''',
    tags: ['fundamental rights', 'duties', 'writs', 'polity', 'upsc'],
    estimatedReadTime: 18,
    createdAt: DateTime(2024, 1, 16),
    rating: 4.9,
  ),

  // ==================== INDIAN HISTORY ====================
  
  StudyMaterial(
    id: 'upsc_history_freedom_struggle',
    title: 'Indian Freedom Struggle',
    description: 'National movement, important events, leaders',
    subjectId: 'history',
    topicId: 'freedom_struggle',
    type: StudyMaterialType.notes,
    content: '''
# Indian Freedom Struggle for UPSC

## Early Phase (1857-1905)

### Revolt of 1857
- **Causes**: Doctrine of Lapse, economic exploitation, social reforms
- **Immediate cause**: Greased cartridges
- **Leaders**: Mangal Pandey, Rani Lakshmibai, Tantia Tope, Nana Sahib
- **Result**: End of EIC rule, Crown takes over

### Formation of INC (1885)
- Founder: A.O. Hume
- First President: W.C. Bonnerjee
- First session: Bombay (1885)

### Moderate Phase (1885-1905)
- **Leaders**: Dadabhai Naoroji, Gokhale, Surendranath Banerjee
- **Methods**: Petitions, prayers, constitutional means
- **Achievements**: Drain theory, awakening

## Extremist Phase (1905-1919)

### Partition of Bengal (1905)
- Viceroy Curzon
- Divided on religious lines
- Triggered Swadeshi movement

### Swadeshi Movement
- Boycott of British goods
- Promotion of indigenous industries
- National education

### Surat Split (1907)
- Moderates vs Extremists
- Extremist leaders: Tilak, Lajpat Rai, Bipin Chandra Pal

### Home Rule Movement (1916)
- Tilak: Maharashtra
- Annie Besant: Rest of India
- Demand for self-governance

### Lucknow Pact (1916)
- INC-Muslim League unity
- Separate electorates accepted

## Gandhian Era (1919-1947)

### Rowlatt Act & Jallianwala Bagh (1919)
- Arrest without trial
- General Dyer's massacre (April 13, 1919)
- Martial law in Punjab

### Non-Cooperation Movement (1920-22)
- **Causes**: Rowlatt Act, Khilafat issue
- **Features**: Boycott of councils, titles, schools
- **End**: Chauri Chaura incident (1922)

### Civil Disobedience Movement (1930-34)
- **Dandi March**: March 12 - April 6, 1930
- Gandhi-Irwin Pact (1931)
- Round Table Conferences

### Quit India Movement (1942)
- **August Kranti**: August 8, 1942
- **Slogan**: "Do or Die"
- Leaders arrested
- Underground movement

## Important Events Timeline

| Year | Event |
|------|-------|
| 1857 | First War of Independence |
| 1885 | INC founded |
| 1905 | Partition of Bengal |
| 1906 | Muslim League founded |
| 1909 | Morley-Minto Reforms |
| 1919 | Jallianwala Bagh |
| 1920 | Non-Cooperation |
| 1928 | Simon Commission boycott |
| 1929 | Lahore Session (Purna Swaraj) |
| 1930 | Dandi March, Civil Disobedience |
| 1931 | Gandhi-Irwin Pact |
| 1935 | Government of India Act |
| 1942 | Quit India |
| 1946 | Cabinet Mission |
| 1947 | Independence |

## Revolutionary Movement

### Key Revolutionaries
- Bhagat Singh, Sukhdev, Rajguru
- Chandrashekhar Azad
- Surya Sen (Chittagong Armory)
- Khudiram Bose, Prafulla Chaki

### Organizations
- Anushilan Samiti
- Hindustan Socialist Republican Association (HSRA)
- Indian Independence League (IIL)

## Subhas Chandra Bose & INA

### Indian National Army
- First formed by Mohan Singh
- Reorganized by Bose (1943)
- "Jai Hind", "Delhi Chalo"
- INA Trials (1945)

### Azad Hind Government
- Established: October 21, 1943
- Capital: Port Blair (symbolically)
''',
    tags: ['history', 'freedom struggle', 'gandhi', 'movements', 'upsc'],
    estimatedReadTime: 18,
    createdAt: DateTime(2024, 1, 17),
    rating: 4.8,
  ),

  // ==================== INDIAN GEOGRAPHY ====================
  
  StudyMaterial(
    id: 'upsc_geography_physical',
    title: 'Physical Geography of India',
    description: 'Physiographic divisions, climate, rivers',
    subjectId: 'geography',
    topicId: 'physical_geography',
    type: StudyMaterialType.notes,
    content: '''
# Physical Geography of India for UPSC

## Location & Extent

### Position
- Latitude: 8°4'N to 37°6'N
- Longitude: 68°7'E to 97°25'E
- Tropic of Cancer passes through 8 states
- Standard Meridian: 82°30'E (Mirzapur, UP)

### Area
- Total: 32.87 lakh sq km (7th largest)
- Land boundary: 15,200 km
- Coastline: 7,516.6 km

## Physiographic Divisions

### 1. The Himalayas

**Three Parallel Ranges:**
| Range | Features | Peaks |
|-------|----------|-------|
| Himadri (Greater) | Highest, continuous | Everest, K2, Kanchenjunga |
| Himachal (Lesser) | Pir Panjal, Dhaula Dhar | - |
| Shiwaliks (Outer) | Youngest, fragile | - |

**Regional Divisions:**
- Punjab Himalayas
- Kumaon Himalayas
- Nepal Himalayas
- Assam Himalayas

### 2. Northern Plains

**Divisions:**
- Bhabar: Pebble zone, streams disappear
- Terai: Marshy, reappearance of streams
- Bhangar: Older alluvium, higher
- Khadar: Newer alluvium, flood plains

**Features:**
- Formed by Indus, Ganga, Brahmaputra
- Highly fertile agricultural land
- Length: ~2400 km, Width: 150-300 km

### 3. Peninsular Plateau

**Two Main Divisions:**
- Central Highlands (north of Narmada)
- Deccan Plateau (south of Narmada)

**Mountain Ranges:**
- Aravalli (oldest, highly eroded)
- Vindhyas (separates North-South India)
- Satpura (between Narmada-Tapi)
- Western Ghats (continuous, higher)
- Eastern Ghats (discontinuous, lower)

### 4. Coastal Plains

**Western Coast:**
- Konkan (Maharashtra)
- Kanara (Karnataka)
- Malabar (Kerala)

**Eastern Coast:**
- Coromandel (Tamil Nadu, AP)
- Northern Circars (north of Coromandel)

### 5. Islands

**Andaman & Nicobar:**
- Bay of Bengal
- Volcanic origin (Barren Island)
- Indira Point (southernmost)

**Lakshadweep:**
- Arabian Sea
- Coral origin
- Kavaratti (capital)

## Rivers

### Himalayan Rivers
| River | Origin | Tributary |
|-------|--------|-----------|
| Indus | Mansarovar | Jhelum, Chenab, Ravi, Beas, Sutlej |
| Ganga | Gangotri | Yamuna, Son, Ghaghara, Gandak, Kosi |
| Brahmaputra | Chemayungdung | Dibang, Lohit, Subansiri |

### Peninsular Rivers

**West-flowing:**
- Narmada (rift valley)
- Tapi (rift valley)
- Mahi, Sabarmati

**East-flowing:**
- Mahanadi, Godavari, Krishna, Kaveri

## Climate

### Factors
- Latitude, Altitude
- Himalayas (barrier)
- Distance from sea
- Monsoons

### Seasons
1. Winter (Dec-Feb): NE monsoon
2. Summer (Mar-May): Hot, dry
3. Southwest Monsoon (Jun-Sep): Rainy
4. Retreating Monsoon (Oct-Nov): NE monsoon begins

### Monsoon Characteristics
- Seasonal reversal of winds
- Burst over Kerala (June 1)
- Arabian Sea branch, Bay of Bengal branch
- Withdrawal begins September
''',
    tags: ['geography', 'physical', 'rivers', 'climate', 'upsc'],
    estimatedReadTime: 17,
    createdAt: DateTime(2024, 1, 18),
    rating: 4.9,
  ),

  // ==================== INDIAN ECONOMY ====================
  
  StudyMaterial(
    id: 'upsc_economy_basics',
    title: 'Indian Economy - Fundamentals',
    description: 'Economic planning, sectors, fiscal policy',
    subjectId: 'economy',
    topicId: 'economic_basics',
    type: StudyMaterialType.notes,
    content: '''
# Indian Economy for UPSC

## Economic Planning

### Planning Commission (1950-2014)
- Chairman: Prime Minister
- Non-constitutional body
- Five Year Plans (12 completed)

### NITI Aayog (2015-present)
- Think tank, not allocative
- Chairperson: PM
- CEO: Appointed by PM
- Cooperative federalism

## National Income

### Key Concepts
- **GDP**: Total value of goods & services within borders
- **GNP**: GDP + Net Factor Income from Abroad
- **NDP**: GDP - Depreciation
- **NNP**: GNP - Depreciation

### GDP Calculation Methods
1. Income Method
2. Expenditure Method: C + I + G + (X-M)
3. Production Method

### Current Statistics
- GDP growth: ~7% (varies)
- Per capita income: ~₹1.5 lakh
- Service sector: ~55% of GDP

## Sectors of Economy

### Primary Sector
- Agriculture, forestry, fishing, mining
- ~15% of GDP
- ~45% of employment

### Secondary Sector
- Manufacturing, construction
- ~25% of GDP
- "Make in India" initiative

### Tertiary Sector
- Services (IT, banking, trade)
- ~55% of GDP
- Fastest growing

## Monetary Policy

### RBI Functions
- Monetary authority
- Banker to government
- Banker to banks
- Currency management
- Foreign exchange management

### Policy Tools
| Tool | Purpose |
|------|---------|
| Repo Rate | Short-term lending rate |
| Reverse Repo | RBI borrowing rate |
| CRR | Reserves with RBI |
| SLR | Liquid assets holding |
| Bank Rate | Long-term lending |
| OMO | Buy/sell securities |

### Monetary Policy Committee
- 6 members (3 RBI + 3 external)
- Target: 4% inflation (±2%)
- Reviews bi-monthly

## Fiscal Policy

### Revenue
**Tax Revenue:**
- Direct: Income tax, Corporate tax
- Indirect: GST, Customs

**Non-Tax Revenue:**
- Dividends, Interest, Fees

### Expenditure
- Revenue expenditure (recurring)
- Capital expenditure (assets)

### Deficits

| Deficit | Formula |
|---------|---------|
| Revenue Deficit | Revenue Expenditure - Revenue Receipts |
| Fiscal Deficit | Total Expenditure - Total Receipts (excl. borrowing) |
| Primary Deficit | Fiscal Deficit - Interest Payments |

### FRBM Act (2003)
- Fiscal responsibility
- Target: 3% fiscal deficit

## Banking

### Types of Banks
- Commercial (Public, Private, Foreign)
- Cooperative
- Regional Rural Banks
- Payments Banks
- Small Finance Banks

### Financial Inclusion
- Jan Dhan Yojana
- Mudra Bank
- PM SVANidhi

## Important Schemes

| Scheme | Purpose |
|--------|---------|
| MGNREGA | Rural employment |
| PM-KISAN | Farmer income support |
| Make in India | Manufacturing |
| Startup India | Entrepreneurship |
| Digital India | E-governance |
| Skill India | Employment |
''',
    tags: ['economy', 'gdp', 'fiscal', 'monetary', 'upsc'],
    estimatedReadTime: 16,
    createdAt: DateTime(2024, 1, 19),
    rating: 4.8,
  ),

  // ==================== ENVIRONMENT ====================
  
  StudyMaterial(
    id: 'upsc_environment_ecology',
    title: 'Environment & Ecology',
    description: 'Ecosystems, biodiversity, climate change',
    subjectId: 'environment',
    topicId: 'ecology',
    type: StudyMaterialType.notes,
    content: '''
# Environment & Ecology for UPSC

## Basic Concepts

### Ecosystem Components
- **Biotic**: Living (producers, consumers, decomposers)
- **Abiotic**: Non-living (water, air, soil, temperature)

### Food Chain & Web
- Producers → Primary consumers → Secondary → Tertiary
- 10% energy transfer rule

### Ecological Pyramids
| Type | Always upright? |
|------|-----------------|
| Numbers | No (parasites) |
| Biomass | No (aquatic) |
| Energy | Always yes |

## Biodiversity

### Types
- **Genetic**: Within species
- **Species**: Between species
- **Ecosystem**: Habitat diversity

### Biodiversity Hotspots (India)
1. Western Ghats
2. Eastern Himalayas
3. Indo-Burma
4. Sundaland (Nicobar)

### Conservation

**In-situ:**
- National Parks (106)
- Wildlife Sanctuaries (567)
- Biosphere Reserves (18)
- Ramsar Sites (75+)

**Ex-situ:**
- Zoos, botanical gardens
- Gene banks, seed banks

## Protected Areas

### Categories
| Type | Features |
|------|----------|
| National Park | Highest protection, no human activity |
| Sanctuary | Some activities allowed |
| Biosphere Reserve | Core, buffer, transition zones |
| Tiger Reserve | Project Tiger |
| Elephant Reserve | Project Elephant |

### Important National Parks
- Kaziranga (Assam): One-horned rhino
- Jim Corbett (Uttarakhand): First NP (1936)
- Sundarbans (WB): Tigers, mangroves
- Gir (Gujarat): Asiatic lions
- Ranthambore (Rajasthan): Tigers

## Climate Change

### Greenhouse Gases
| Gas | Source | GWP |
|-----|--------|-----|
| CO₂ | Fossil fuels | 1 |
| CH₄ | Livestock, rice | 25 |
| N₂O | Fertilizers | 298 |
| CFCs | Refrigerants | High |

### International Agreements

**UNFCCC (1992)**
- Framework convention
- Common but differentiated responsibilities

**Kyoto Protocol (1997)**
- Binding targets for developed countries
- CDM, JI, Emissions trading

**Paris Agreement (2015)**
- Limit warming to 1.5-2°C
- NDCs by each country
- India's target: 45% emission intensity reduction by 2030

### India's Commitments
- 500 GW non-fossil capacity by 2030
- Net zero by 2070
- 50% energy from renewables

## Pollution

### Air Pollution
- Sources: Vehicles, industries, burning
- Effects: Respiratory diseases, acid rain
- National Clean Air Programme

### Water Pollution
- Sources: Industrial, agricultural, domestic
- BOD, COD indicators
- Namami Gange

### Solid Waste
- Solid Waste Management Rules, 2016
- Extended Producer Responsibility
- E-waste Rules

## Environmental Laws

| Law | Purpose |
|-----|---------|
| Wildlife Protection Act, 1972 | Protect wildlife |
| Water Act, 1974 | Prevent water pollution |
| Forest Conservation Act, 1980 | Regulate diversion |
| Air Act, 1981 | Control air pollution |
| Environment Protection Act, 1986 | Umbrella legislation |
| Biodiversity Act, 2002 | Conserve biodiversity |
| NGT Act, 2010 | Environmental tribunal |
''',
    tags: ['environment', 'ecology', 'biodiversity', 'climate', 'upsc'],
    estimatedReadTime: 18,
    createdAt: DateTime(2024, 1, 20),
    rating: 4.9,
  ),
];
