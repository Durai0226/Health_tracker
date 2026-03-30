import '../../../models/study_material_model.dart';

/// Banking Awareness - Formulas, Facts & Shortcuts
/// Essential banking knowledge for exams

final List<StudyMaterial> bankingAwarenessMaterials = [
  // ==================== RBI & MONETARY POLICY ====================
  
  StudyMaterial(
    id: 'bank_aware_f_rbi',
    title: 'RBI Structure & Functions',
    description: 'Complete guide to Reserve Bank of India',
    subjectId: 'banking_awareness',
    topicId: 'rbi',
    type: StudyMaterialType.formula,
    content: '''
# RBI Structure & Functions

## Basic Information
| Fact | Detail |
|------|--------|
| Established | 1st April 1935 |
| Nationalized | 1st January 1949 |
| Headquarters | Mumbai |
| Regional Offices | 31 |
| Current Governor | Shaktikanta Das (25th) |

## RBI Functions

### As Banker to Government
- Manages government accounts
- Handles public debt
- Issues government securities

### As Banker's Bank
- Maintains CRR deposits
- Lender of last resort
- Clearing house function

### As Currency Authority
- Sole authority to issue currency (except ₹1 coins)
- Manages currency distribution
- Controls money supply

### As Regulator
- Regulates banks and NBFCs
- Issues banking licenses
- Supervises financial system

## RBI Subsidiaries
| Subsidiary | Function |
|------------|----------|
| NABARD | Rural & agri development |
| NHB | Housing finance regulation |
| DICGC | Deposit insurance |
| BRBNMPL | Currency printing |

## Important Committees
| Committee | Subject |
|-----------|---------|
| Narasimham | Banking reforms |
| Tarapore | Capital account |
| Khan | Harmonization of roles |
| Usha Thorat | Financial inclusion |
''',
    tags: ['rbi', 'banking-awareness'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  StudyMaterial(
    id: 'bank_aware_f_monetary_policy',
    title: 'Monetary Policy Tools',
    description: 'RBI monetary policy instruments',
    subjectId: 'banking_awareness',
    topicId: 'monetary_policy',
    type: StudyMaterialType.formula,
    content: '''
# Monetary Policy Tools

## Policy Rates

### Repo Rate
- Rate at which RBI lends to banks
- Against government securities
- **Impact**: ↑ Repo = ↑ Loan rates = ↓ Money supply

### Reverse Repo Rate
- Rate at which RBI borrows from banks
- Banks park excess funds
- **Impact**: ↑ Reverse Repo = Banks park more = ↓ Lending

### Bank Rate
- Long-term lending rate to banks
- No collateral required
- Higher than repo rate

### MSF (Marginal Standing Facility)
- Emergency borrowing window
- Rate = Repo + 0.25%
- Against SLR securities

## Reserve Ratios

### CRR (Cash Reserve Ratio)
- Cash with RBI as % of NDTL
- No interest earned
- **Formula**: CRR = (Cash with RBI / NDTL) × 100

### SLR (Statutory Liquidity Ratio)
- Liquid assets as % of NDTL
- G-Secs, Gold, Cash
- **Formula**: SLR = (Liquid Assets / NDTL) × 100

## Current Rates (Update as needed)
| Rate | Value |
|------|-------|
| Repo Rate | 6.50% |
| Reverse Repo | 3.35% |
| MSF | 6.75% |
| Bank Rate | 6.75% |
| CRR | 4.50% |
| SLR | 18% |
''',
    tags: ['monetary-policy', 'rates'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  // ==================== BANKING TERMS ====================

  StudyMaterial(
    id: 'bank_aware_f_terms',
    title: 'Essential Banking Terms',
    description: 'Important banking terminology',
    subjectId: 'banking_awareness',
    topicId: 'banking_terms',
    type: StudyMaterialType.formula,
    content: '''
# Essential Banking Terms

## Account Types
| Term | Meaning |
|------|---------|
| CASA | Current Account Savings Account |
| NRE | Non-Resident External (rupee, repatriable) |
| NRO | Non-Resident Ordinary (rupee, non-repatriable) |
| FCNR | Foreign Currency Non-Resident |
| RFC | Resident Foreign Currency |

## Loan Terms
| Term | Meaning |
|------|---------|
| EMI | Equated Monthly Installment |
| MCLR | Marginal Cost of Funds Lending Rate |
| RLLR | Repo Linked Lending Rate |
| Base Rate | Minimum rate for loans |
| PLR | Prime Lending Rate |
| NPA | Non-Performing Asset |

## Transaction Terms
| Term | Meaning |
|------|---------|
| NEFT | National Electronic Funds Transfer |
| RTGS | Real Time Gross Settlement |
| IMPS | Immediate Payment Service |
| UPI | Unified Payments Interface |
| NACH | National Automated Clearing House |
| ECS | Electronic Clearing Service |

## Risk Terms
| Term | Meaning |
|------|---------|
| CRAR | Capital to Risk-weighted Assets Ratio |
| LCR | Liquidity Coverage Ratio |
| NSFR | Net Stable Funding Ratio |
| PCR | Provision Coverage Ratio |
| GNPA | Gross NPA |
| NNPA | Net NPA |

## Other Important Terms
| Term | Meaning |
|------|---------|
| NDTL | Net Demand and Time Liabilities |
| LAF | Liquidity Adjustment Facility |
| OMO | Open Market Operations |
| G-Sec | Government Security |
| T-Bill | Treasury Bill |
''',
    tags: ['banking-terms', 'abbreviations'],
    estimatedReadTime: 6,
    createdAt: DateTime.now(),
  ),

  // ==================== NPA & CAPITAL ADEQUACY ====================

  StudyMaterial(
    id: 'bank_aware_f_npa',
    title: 'NPA Classification & Norms',
    description: 'Non-performing asset guidelines',
    subjectId: 'banking_awareness',
    topicId: 'npa',
    type: StudyMaterialType.formula,
    content: '''
# NPA Classification & Norms

## NPA Definition
Asset becomes NPA when:
- Interest/principal overdue for **90 days**
- Agricultural loans: Overdue for **2 crop seasons**

## NPA Categories

### Sub-Standard Assets
- NPA for ≤ 12 months
- Provision: 15%

### Doubtful Assets
- NPA for > 12 months
- Provision: 25-100% (based on security)

### Loss Assets
- Identified as uncollectible
- Provision: 100%

## NPA Formulas

### Gross NPA Ratio
**GNPA = (Gross NPAs / Gross Advances) × 100**

### Net NPA Ratio
**NNPA = (Net NPAs / Net Advances) × 100**
Where: Net NPA = Gross NPA - Provisions

### Provision Coverage Ratio
**PCR = (Provisions / Gross NPAs) × 100**

## Recovery Mechanisms
| Method | Details |
|--------|---------|
| SARFAESI | Securitisation Act, 2002 |
| DRT | Debt Recovery Tribunal |
| Lok Adalat | Up to ₹20 lakh |
| IBC | Insolvency & Bankruptcy Code |
| ARC | Asset Reconstruction Company |

## Loan Write-off
- Removed from balance sheet
- Legal right to recover remains
- Tax benefit available
''',
    tags: ['npa', 'provisioning'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  StudyMaterial(
    id: 'bank_aware_f_basel',
    title: 'Basel Norms & Capital Adequacy',
    description: 'Basel framework for banks',
    subjectId: 'banking_awareness',
    topicId: 'basel_norms',
    type: StudyMaterialType.formula,
    content: '''
# Basel Norms & Capital Adequacy

## Basel Evolution
| Version | Focus |
|---------|-------|
| Basel I (1988) | Credit Risk |
| Basel II (2004) | 3 Pillars approach |
| Basel III (2010) | Post-crisis reforms |

## Basel III Pillars
1. **Minimum Capital Requirements**
2. **Supervisory Review**
3. **Market Discipline**

## Capital Requirements (Basel III)

### Minimum Capital Ratios
| Component | Requirement |
|-----------|-------------|
| CET1 (Common Equity Tier 1) | 5.5% |
| Tier 1 Capital | 7% |
| Total Capital (CRAR) | 9% |
| Capital Conservation Buffer | 2.5% |
| Total with CCB | 11.5% |

### CRAR Formula
**CRAR = (Tier 1 + Tier 2 Capital) / RWA × 100**
RWA = Risk Weighted Assets

## Tier 1 vs Tier 2 Capital

### Tier 1 (Core Capital)
- Equity capital
- Disclosed reserves
- Retained earnings

### Tier 2 (Supplementary)
- Undisclosed reserves
- Revaluation reserves
- Subordinated debt

## Liquidity Ratios
| Ratio | Purpose | Minimum |
|-------|---------|---------|
| LCR | Short-term liquidity | 100% |
| NSFR | Long-term stability | 100% |
''',
    tags: ['basel', 'capital-adequacy', 'crar'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  // ==================== PAYMENT SYSTEMS ====================

  StudyMaterial(
    id: 'bank_aware_f_payments',
    title: 'Payment Systems in India',
    description: 'NEFT, RTGS, UPI and more',
    subjectId: 'banking_awareness',
    topicId: 'payment_systems',
    type: StudyMaterialType.formula,
    content: '''
# Payment Systems in India

## NEFT
| Feature | Detail |
|---------|--------|
| Full Form | National Electronic Funds Transfer |
| Settlement | Batch-wise (half-hourly) |
| Timing | 24x7 (from Dec 2019) |
| Min/Max Amount | No limit |
| Charges | Nil for savings accounts |

## RTGS
| Feature | Detail |
|---------|--------|
| Full Form | Real Time Gross Settlement |
| Settlement | Individual, real-time |
| Timing | 24x7 (from Dec 2020) |
| Minimum | ₹2 lakh |
| Maximum | No limit |

## IMPS
| Feature | Detail |
|---------|--------|
| Full Form | Immediate Payment Service |
| Timing | 24x7x365 |
| Limit | ₹5 lakh per transaction |
| Settlement | Instant |

## UPI
| Feature | Detail |
|---------|--------|
| Full Form | Unified Payments Interface |
| Launched | 2016 by NPCI |
| Limit | ₹1 lakh (₹2 lakh for some) |
| Uses | VPA (Virtual Payment Address) |

## Comparison Table
| Feature | NEFT | RTGS | IMPS | UPI |
|---------|------|------|------|-----|
| Speed | Batch | Real-time | Instant | Instant |
| Min Amt | None | ₹2L | None | None |
| Available | 24x7 | 24x7 | 24x7 | 24x7 |

## NPCI Products
- UPI, IMPS, NACH, BHIM
- RuPay, AePS, BBPS
- NETC (FASTag), UPI 2.0
''',
    tags: ['payments', 'neft', 'rtgs', 'upi'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  // ==================== FINANCIAL INCLUSION ====================

  StudyMaterial(
    id: 'bank_aware_f_inclusion',
    title: 'Financial Inclusion Schemes',
    description: 'Government schemes for banking access',
    subjectId: 'banking_awareness',
    topicId: 'financial_inclusion',
    type: StudyMaterialType.formula,
    content: '''
# Financial Inclusion Schemes

## Jan Dhan Yojana (PMJDY)
| Feature | Detail |
|---------|--------|
| Launched | 28 Aug 2014 |
| Objective | Banking for all |
| Overdraft | ₹10,000 (after 6 months) |
| RuPay Card | Free with insurance |
| Insurance | ₹1 lakh accident cover |

## MUDRA Yojana (PMMY)
| Category | Loan Amount |
|----------|-------------|
| Shishu | Up to ₹50,000 |
| Kishore | ₹50,001 to ₹5 lakh |
| Tarun | ₹5 lakh to ₹10 lakh |
- No collateral required
- Target: Small businesses

## Stand Up India
- For SC/ST and women entrepreneurs
- Loan: ₹10 lakh to ₹1 crore
- Greenfield enterprises

## Atal Pension Yojana (APY)
| Entry Age | Pension at 60 |
|-----------|---------------|
| 18 years | ₹1,000-5,000/month |
| Monthly contribution varies by age |

## Sukanya Samriddhi Yojana
- For girl child (0-10 years)
- Interest: ~8% (tax-free)
- Lock-in: 21 years
- Min deposit: ₹250/year

## PM Jeevan Jyoti Bima (PMJJBY)
- Premium: ₹436/year
- Cover: ₹2 lakh (death)
- Age: 18-55 years

## PM Suraksha Bima (PMSBY)
- Premium: ₹20/year
- Cover: ₹2 lakh (accident death)
- Age: 18-70 years
''',
    tags: ['financial-inclusion', 'schemes'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  // ==================== PRIORITY SECTOR LENDING ====================

  StudyMaterial(
    id: 'bank_aware_f_psl',
    title: 'Priority Sector Lending Norms',
    description: 'PSL categories and targets',
    subjectId: 'banking_awareness',
    topicId: 'priority_sector',
    type: StudyMaterialType.formula,
    content: '''
# Priority Sector Lending Norms

## PSL Targets
| Bank Type | Target |
|-----------|--------|
| Domestic Banks | 40% of ANBC |
| Foreign Banks (>20 branches) | 40% of ANBC |
| Foreign Banks (<20 branches) | 40% of ANBC |
| Regional Rural Banks | 75% of ANBC |
| Small Finance Banks | 75% of ANBC |

## Sub-Targets
| Category | Target |
|----------|--------|
| Agriculture | 18% |
| Micro Enterprises | 7.5% |
| Weaker Sections | 12% |

## PSL Categories
1. **Agriculture**
   - Farm credit
   - Agriculture infrastructure
   - Agri-business

2. **Micro, Small & Medium Enterprises**
   - Manufacturing
   - Services

3. **Export Credit**
   - Incremental export credit

4. **Education**
   - Loans for studies in India/abroad

5. **Housing**
   - Up to ₹35 lakh (Metro)
   - Up to ₹25 lakh (Other)

6. **Social Infrastructure**
   - Schools, hospitals
   - Water, sanitation

7. **Renewable Energy**
   - Solar, wind projects

8. **Others**
   - Weaker sections
   - Distressed persons

## Non-Achievement Penalty
- Contribute to RIDF (NABARD)
- Or other funds specified by RBI
''',
    tags: ['psl', 'priority-sector'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  // ==================== INDIAN BANKING STRUCTURE ====================

  StudyMaterial(
    id: 'bank_aware_f_structure',
    title: 'Indian Banking Structure',
    description: 'Types of banks in India',
    subjectId: 'banking_awareness',
    topicId: 'banking_structure',
    type: StudyMaterialType.formula,
    content: '''
# Indian Banking Structure

## Scheduled Commercial Banks

### Public Sector Banks (12)
- SBI + 11 Nationalized Banks
- Government holds majority stake

### Private Sector Banks
- HDFC, ICICI, Axis, Kotak, etc.
- Governed by Banking Regulation Act

### Foreign Banks
- HSBC, Citi, Standard Chartered
- Operate as branches in India

### Small Finance Banks (12)
- Focus: Unserved/underserved sections
- 75% to PSL, 50% < ₹25 lakh loans
- Examples: AU, Equitas, Ujjivan

### Payments Banks (6)
- No lending allowed
- Deposits up to ₹2 lakh
- Examples: Paytm, Airtel, India Post

## Regional Rural Banks (43)
- Sponsor Bank + State + Central Govt
- Shareholding: 50:15:35
- Focus: Rural credit

## Cooperative Banks

### Urban Cooperative
- Tier 1: Up to ₹100 crore deposits
- Tier 2: > ₹100 crore deposits

### Rural Cooperative
- State Cooperative Banks (SCBs)
- District Central Coop Banks (DCCBs)
- Primary Agricultural Credit Societies

## Development Banks
- NABARD, SIDBI, NHB, EXIM
- Provide long-term finance
''',
    tags: ['banking-structure', 'types'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  // ==================== IMPORTANT ACTS ====================

  StudyMaterial(
    id: 'bank_aware_f_acts',
    title: 'Important Banking Acts',
    description: 'Key legislation for banking',
    subjectId: 'banking_awareness',
    topicId: 'banking_acts',
    type: StudyMaterialType.formula,
    content: '''
# Important Banking Acts

## RBI Act, 1934
- Established RBI
- Currency issue authority
- Defines monetary policy framework
- Governs RBI operations

## Banking Regulation Act, 1949
- Licensing of banks
- Branch authorization
- Capital adequacy norms
- Inspection powers

## Negotiable Instruments Act, 1881
- Defines promissory notes, bills, cheques
- Rules for endorsement
- Dishonor of cheques (Section 138)

## SARFAESI Act, 2002
- Securitisation and Reconstruction
- Banks can take possession of collateral
- Without court intervention
- For NPAs > ₹1 lakh

## IBC, 2016 (Insolvency & Bankruptcy Code)
- Time-bound resolution: 180+90 days
- NCLT for companies
- DRT for individuals
- Waterfall mechanism for distribution

## PMLA, 2002 (Prevention of Money Laundering)
- KYC requirements
- Reporting suspicious transactions
- Customer Due Diligence

## FEMA, 1999
- Foreign exchange transactions
- Replaced FERA
- Current account convertibility

## Consumer Protection Act, 2019
- Banking ombudsman
- Consumer rights
- Grievance redressal
''',
    tags: ['acts', 'legislation'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  // ==================== FINANCIAL MARKETS ====================

  StudyMaterial(
    id: 'bank_aware_f_markets',
    title: 'Financial Markets Overview',
    description: 'Money market and capital market',
    subjectId: 'banking_awareness',
    topicId: 'financial_markets',
    type: StudyMaterialType.formula,
    content: '''
# Financial Markets Overview

## Money Market (Short-term)

### Instruments
| Instrument | Tenure | Issuer |
|------------|--------|--------|
| T-Bills | 91/182/364 days | Govt |
| Commercial Paper | 7 days-1 year | Corporates |
| Certificate of Deposit | 7 days-1 year | Banks |
| Repo | Overnight-14 days | RBI/Banks |
| Call Money | 1 day | Banks |
| Notice Money | 2-14 days | Banks |

### T-Bill Types
- 91-day, 182-day, 364-day
- Issued at discount
- Zero coupon

## Capital Market (Long-term)

### Primary Market
- IPO (Initial Public Offering)
- FPO (Follow-on Public Offer)
- Rights Issue
- Private Placement

### Secondary Market
- Stock exchanges (NSE, BSE)
- Trading of existing securities

## Government Securities
| Type | Tenure |
|------|--------|
| Dated Securities | 5-40 years |
| State Development Loans | Medium-long term |
| Treasury Bills | Up to 1 year |

## Market Regulators
| Market | Regulator |
|--------|-----------|
| Stock Market | SEBI |
| Money Market | RBI |
| Insurance | IRDAI |
| Pension | PFRDA |
| Commodity | SEBI (merged) |
''',
    tags: ['markets', 'money-market', 'capital-market'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  // ==================== BANKING RATIOS ====================

  StudyMaterial(
    id: 'bank_aware_s_ratios',
    title: 'Important Banking Ratios',
    description: 'Quick reference for banking ratios',
    subjectId: 'banking_awareness',
    topicId: 'banking_ratios',
    type: StudyMaterialType.shortcut,
    content: '''
# Important Banking Ratios

## Profitability Ratios

### Net Interest Margin (NIM)
**NIM = (Interest Income - Interest Expense) / Average Earning Assets × 100**
Higher is better (typically 2.5-4%)

### Return on Assets (ROA)
**ROA = Net Profit / Average Total Assets × 100**
Ideal: > 1%

### Return on Equity (ROE)
**ROE = Net Profit / Average Shareholders' Equity × 100**
Ideal: > 15%

### Cost to Income Ratio
**= Operating Expenses / Operating Income × 100**
Lower is better (< 50% ideal)

## Asset Quality Ratios

### Gross NPA Ratio
**= Gross NPAs / Gross Advances × 100**
Lower is better (< 5% acceptable)

### Net NPA Ratio
**= Net NPAs / Net Advances × 100**
Lower is better (< 2% good)

### Provision Coverage Ratio
**= Total Provisions / Gross NPAs × 100**
Higher is better (> 70% good)

## Capital Ratios

### CRAR
**= (Tier 1 + Tier 2) / RWA × 100**
Minimum: 9%

### Tier 1 Ratio
**= Tier 1 Capital / RWA × 100**
Minimum: 7%

## Liquidity Ratios

### Credit-Deposit Ratio
**= Total Advances / Total Deposits × 100**
Ideal: 70-80%

### CASA Ratio
**= (Current + Savings Deposits) / Total Deposits × 100**
Higher is better (low-cost deposits)
''',
    tags: ['ratios', 'shortcuts'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  // ==================== CURRENT AFFAIRS FOCUS ====================

  StudyMaterial(
    id: 'bank_aware_s_current',
    title: 'Banking Current Affairs Focus Areas',
    description: 'What to track for exams',
    subjectId: 'banking_awareness',
    topicId: 'current_affairs',
    type: StudyMaterialType.shortcut,
    content: '''
# Banking Current Affairs Focus Areas

## Track Regularly

### RBI Updates
- Policy rate changes
- New circulars/guidelines
- Regulatory changes
- Governor statements

### Bank Mergers/Acquisitions
- Recent consolidations
- New bank formations
- License updates

### New Schemes
- Government schemes
- Bank-specific products
- Digital initiatives

### Appointments
- Bank heads (CMD, MD, CEO)
- RBI officials
- Regulatory body chiefs

## Key Numbers to Remember

### Current Rates (Check Latest)
- Repo Rate
- CRR, SLR
- Bank Rate
- MSF Rate

### Limits
- Deposit insurance: ₹5 lakh
- RTGS minimum: ₹2 lakh
- UPI limit: ₹1 lakh
- Payments bank deposit: ₹2 lakh

### Bank Rankings
- Largest PSB: SBI
- Largest Private: HDFC
- Most branches: SBI
- Oldest bank: SBI (1806 as Bank of Calcutta)

## Exam Pattern Tips
1. 5-10 questions on current banking
2. Focus on last 6 months
3. RBI circulars are important
4. Know recent appointments
5. Track merger announcements
''',
    tags: ['current-affairs', 'shortcuts'],
    estimatedReadTime: 4,
    createdAt: DateTime.now(),
  ),

  // ==================== INTERNATIONAL ORGANIZATIONS ====================

  StudyMaterial(
    id: 'bank_aware_f_intl_orgs',
    title: 'International Financial Organizations',
    description: 'IMF, World Bank, and others',
    subjectId: 'banking_awareness',
    topicId: 'international_organizations',
    type: StudyMaterialType.formula,
    content: '''
# International Financial Organizations

## IMF (International Monetary Fund)
| Fact | Detail |
|------|--------|
| Established | 1945 |
| HQ | Washington D.C. |
| Members | 190 countries |
| MD | Kristalina Georgieva |
| India's Quota | 2.76% |
| Currency | SDR |

**Functions**: Exchange rate stability, balance of payments support, technical assistance

## World Bank Group
| Institution | Focus |
|-------------|-------|
| IBRD | Middle-income countries |
| IDA | Poorest countries |
| IFC | Private sector |
| MIGA | Investment guarantees |
| ICSID | Dispute resolution |

- HQ: Washington D.C.
- President: Ajay Banga

## ADB (Asian Development Bank)
- HQ: Manila, Philippines
- Members: 68 (49 regional)
- Focus: Asia-Pacific development
- India is founding member

## BIS (Bank for International Settlements)
- HQ: Basel, Switzerland
- "Central bank of central banks"
- Issues Basel norms
- Members: 63 central banks

## AIIB (Asian Infrastructure Investment Bank)
- HQ: Beijing, China
- Established: 2016
- Members: 100+
- India: 2nd largest shareholder

## NDB (New Development Bank)
- HQ: Shanghai, China
- By BRICS nations
- Established: 2014
''',
    tags: ['international', 'organizations'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  // ==================== CARDS & DIGITAL BANKING ====================

  StudyMaterial(
    id: 'bank_aware_f_digital',
    title: 'Cards & Digital Banking',
    description: 'Card types and digital initiatives',
    subjectId: 'banking_awareness',
    topicId: 'digital_banking',
    type: StudyMaterialType.formula,
    content: '''
# Cards & Digital Banking

## Card Types

### Debit Cards
- Linked to bank account
- Spends from available balance
- RuPay, Visa, Mastercard

### Credit Cards
- Pre-approved credit limit
- Interest on outstanding
- Billing cycle: ~45 days

### Prepaid Cards
- Pre-loaded value
- No bank account needed
- Gift cards, travel cards

## Card Networks
| Network | Origin |
|---------|--------|
| RuPay | India (NPCI) |
| Visa | USA |
| Mastercard | USA |
| American Express | USA |
| Diners Club | USA |

## Digital Banking Initiatives

### BHIM App
- UPI-based payments
- Launched: 2016
- By NPCI

### DigiLocker
- Digital document storage
- Government issued IDs
- Paperless verification

### e-RUPI
- Prepaid digital voucher
- Person/purpose specific
- Launched: Aug 2021

### CBDC (Digital Rupee)
- Central Bank Digital Currency
- e₹ Wholesale: Nov 2022
- e₹ Retail: Dec 2022

## Security Features
- CVV/CVC for online
- PIN for ATM/POS
- OTP for transactions
- 3D Secure authentication
- Tokenization
''',
    tags: ['digital', 'cards'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),

  // ==================== KYC & COMPLIANCE ====================

  StudyMaterial(
    id: 'bank_aware_f_kyc',
    title: 'KYC & Compliance Norms',
    description: 'Know Your Customer requirements',
    subjectId: 'banking_awareness',
    topicId: 'kyc',
    type: StudyMaterialType.formula,
    content: '''
# KYC & Compliance Norms

## KYC Documents

### Officially Valid Documents (OVD)
1. Passport
2. Driving License
3. Voter ID
4. Aadhaar
5. NREGA Job Card
6. Letter from NPR

### Address Proof (Additional)
- Utility bills (< 2 months old)
- Bank statement
- Ration card

## Customer Categories
| Category | Risk Level | KYC Frequency |
|----------|------------|---------------|
| Low | Minimal | 10 years |
| Medium | Normal | 8 years |
| High | Enhanced | 2 years |

## Small Accounts
- Aadhaar-based opening
- Balance limit: ₹50,000
- Annual credit: ₹1 lakh
- Valid: 12 months (24 with partial KYC)

## Video KYC (V-CIP)
- Remote customer onboarding
- Live video interaction
- Geo-tagging required
- Aadhaar + OTP verification

## Compliance Requirements

### PMLA Compliance
- Customer Due Diligence (CDD)
- Enhanced Due Diligence (EDD)
- Suspicious Transaction Reports (STR)
- Cash Transaction Reports (CTR)

### CTR Threshold
- Cash > ₹10 lakh/month
- Report to FIU-IND

### STR Triggers
- Unusual transaction patterns
- High-value transactions
- Inconsistent with profile
''',
    tags: ['kyc', 'compliance'],
    estimatedReadTime: 5,
    createdAt: DateTime.now(),
  ),
];
