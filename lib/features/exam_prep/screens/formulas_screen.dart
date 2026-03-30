/// Formulas & Shortcuts Screen
/// Quick reference for important formulas organized by subject

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/exam_prep_theme.dart';

class FormulasScreen extends StatefulWidget {
  const FormulasScreen({super.key});

  @override
  State<FormulasScreen> createState() => _FormulasScreenState();
}

class _FormulasScreenState extends State<FormulasScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _bookmarkedFormulas = {};

  final List<Map<String, dynamic>> _subjects = [
    {'id': 'quant', 'name': 'Quantitative', 'icon': Icons.calculate, 'color': ExamPrepTheme.quantitative},
    {'id': 'reasoning', 'name': 'Reasoning', 'icon': Icons.psychology, 'color': ExamPrepTheme.reasoning},
    {'id': 'science', 'name': 'Science', 'icon': Icons.science, 'color': ExamPrepTheme.generalScience},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _subjects.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: ExamPrepTheme.getBackground(context),
      appBar: AppBar(
        backgroundColor: ExamPrepTheme.quantitative,
        elevation: 0,
        title: const Text('Formulas & Shortcuts', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_outline, color: Colors.white),
            onPressed: () => _showBookmarked(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: _subjects.map((s) => Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(s['icon'] as IconData, size: 18),
                const SizedBox(width: 6),
                Text(s['name'] as String),
              ],
            ),
          )).toList(),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(context, isDark),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildQuantFormulas(context, isDark),
                _buildReasoningFormulas(context, isDark),
                _buildScienceFormulas(context, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          decoration: InputDecoration(
            hintText: 'Search formulas...',
            hintStyle: TextStyle(color: ExamPrepTheme.getTextSecondary(context)),
            prefixIcon: Icon(Icons.search, color: ExamPrepTheme.getTextSecondary(context)),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildQuantFormulas(BuildContext context, bool isDark) {
    final formulas = _getQuantFormulas();
    return _buildFormulasList(context, isDark, formulas, ExamPrepTheme.quantitative);
  }

  Widget _buildReasoningFormulas(BuildContext context, bool isDark) {
    final formulas = _getReasoningFormulas();
    return _buildFormulasList(context, isDark, formulas, ExamPrepTheme.reasoning);
  }

  Widget _buildScienceFormulas(BuildContext context, bool isDark) {
    final formulas = _getScienceFormulas();
    return _buildFormulasList(context, isDark, formulas, ExamPrepTheme.generalScience);
  }

  Widget _buildFormulasList(BuildContext context, bool isDark, List<Map<String, dynamic>> formulas, Color color) {
    final filtered = _searchQuery.isEmpty
        ? formulas
        : formulas.where((f) =>
            f['title'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
            f['formula'].toString().toLowerCase().contains(_searchQuery.toLowerCase())
          ).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 60, color: ExamPrepTheme.getTextSecondary(context).withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'No formulas found',
              style: TextStyle(color: ExamPrepTheme.getTextPrimary(context), fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final formula = filtered[index];
        final isBookmarked = _bookmarkedFormulas.contains(formula['id']);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _showFormulaDetail(context, formula, color),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            formula['category'] as String,
                            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              if (isBookmarked) {
                                _bookmarkedFormulas.remove(formula['id']);
                              } else {
                                _bookmarkedFormulas.add(formula['id'] as String);
                              }
                            });
                          },
                          child: Icon(
                            isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
                            color: isBookmarked ? color : ExamPrepTheme.getTextSecondary(context),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _copyFormula(context, formula['formula'] as String),
                          child: Icon(Icons.copy, color: ExamPrepTheme.getTextSecondary(context), size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      formula['title'] as String,
                      style: TextStyle(
                        color: ExamPrepTheme.getTextPrimary(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: color.withOpacity(0.2)),
                      ),
                      child: Text(
                        formula['formula'] as String,
                        style: TextStyle(
                          color: ExamPrepTheme.getTextPrimary(context),
                          fontFamily: 'monospace',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (formula['note'] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        formula['note'] as String,
                        style: TextStyle(
                          color: ExamPrepTheme.getTextSecondary(context),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showFormulaDetail(BuildContext context, Map<String, dynamic> formula, Color color) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  formula['category'] as String,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                formula['title'] as String,
                style: TextStyle(
                  color: ExamPrepTheme.getTextPrimary(context),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text(
                  formula['formula'] as String,
                  style: TextStyle(
                    color: ExamPrepTheme.getTextPrimary(context),
                    fontFamily: 'monospace',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (formula['example'] != null) ...[
                const SizedBox(height: 20),
                Text(
                  'Example',
                  style: TextStyle(
                    color: ExamPrepTheme.getTextPrimary(context),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  formula['example'] as String,
                  style: TextStyle(
                    color: ExamPrepTheme.getTextSecondary(context),
                    fontSize: 14,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _copyFormula(context, formula['formula'] as String),
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: color),
                        foregroundColor: color,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _bookmarkedFormulas.add(formula['id'] as String));
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Formula bookmarked!'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.bookmark_add),
                      label: const Text('Bookmark'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _copyFormula(BuildContext context, String formula) {
    Clipboard.setData(ClipboardData(text: formula));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Formula copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _showBookmarked(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_bookmarkedFormulas.length} formulas bookmarked'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<Map<String, dynamic>> _getQuantFormulas() {
    return [
      {'id': 'q1', 'category': 'Percentage', 'title': 'Percentage Formula', 'formula': 'Percentage = (Part/Whole) × 100', 'note': 'Basic percentage calculation', 'example': 'If 25 out of 100 students passed, percentage = (25/100) × 100 = 25%'},
      {'id': 'q2', 'category': 'Percentage', 'title': 'Percentage Change', 'formula': 'Change% = [(New - Old)/Old] × 100', 'note': 'For increase/decrease calculations'},
      {'id': 'q3', 'category': 'Profit & Loss', 'title': 'Profit Percentage', 'formula': 'Profit% = (Profit/CP) × 100', 'note': 'CP = Cost Price'},
      {'id': 'q4', 'category': 'Profit & Loss', 'title': 'Loss Percentage', 'formula': 'Loss% = (Loss/CP) × 100'},
      {'id': 'q5', 'category': 'Profit & Loss', 'title': 'Selling Price', 'formula': 'SP = CP × (100 + Profit%)/100', 'note': 'For profit scenarios'},
      {'id': 'q6', 'category': 'Simple Interest', 'title': 'Simple Interest', 'formula': 'SI = (P × R × T)/100', 'note': 'P=Principal, R=Rate, T=Time'},
      {'id': 'q7', 'category': 'Compound Interest', 'title': 'Compound Interest', 'formula': 'A = P(1 + R/100)^T', 'note': 'A=Amount, P=Principal'},
      {'id': 'q8', 'category': 'Time & Work', 'title': 'Work Done', 'formula': 'Work = Time × Efficiency', 'note': 'Assume total work = LCM of days'},
      {'id': 'q9', 'category': 'Time & Work', 'title': 'Combined Work', 'formula': '1/T = 1/T₁ + 1/T₂', 'note': 'T = Time taken together'},
      {'id': 'q10', 'category': 'Speed Distance', 'title': 'Speed Formula', 'formula': 'Speed = Distance/Time'},
      {'id': 'q11', 'category': 'Speed Distance', 'title': 'Average Speed', 'formula': 'Avg Speed = 2×S₁×S₂/(S₁+S₂)', 'note': 'For equal distances'},
      {'id': 'q12', 'category': 'Speed Distance', 'title': 'Relative Speed (Same)', 'formula': 'Relative Speed = S₁ - S₂', 'note': 'Same direction'},
      {'id': 'q13', 'category': 'Speed Distance', 'title': 'Relative Speed (Opp)', 'formula': 'Relative Speed = S₁ + S₂', 'note': 'Opposite direction'},
      {'id': 'q14', 'category': 'Algebra', 'title': 'Square of Sum', 'formula': '(a+b)² = a² + 2ab + b²'},
      {'id': 'q15', 'category': 'Algebra', 'title': 'Square of Difference', 'formula': '(a-b)² = a² - 2ab + b²'},
      {'id': 'q16', 'category': 'Algebra', 'title': 'Difference of Squares', 'formula': 'a² - b² = (a+b)(a-b)'},
      {'id': 'q17', 'category': 'Geometry', 'title': 'Area of Circle', 'formula': 'A = πr²'},
      {'id': 'q18', 'category': 'Geometry', 'title': 'Circumference', 'formula': 'C = 2πr'},
      {'id': 'q19', 'category': 'Geometry', 'title': 'Area of Triangle', 'formula': 'A = ½ × base × height'},
      {'id': 'q20', 'category': 'Geometry', 'title': 'Pythagorean Theorem', 'formula': 'a² + b² = c²', 'note': 'For right triangles'},
    ];
  }

  List<Map<String, dynamic>> _getReasoningFormulas() {
    return [
      {'id': 'r1', 'category': 'Series', 'title': 'AP nth Term', 'formula': 'aₙ = a + (n-1)d', 'note': 'a=first term, d=common difference'},
      {'id': 'r2', 'category': 'Series', 'title': 'AP Sum', 'formula': 'Sₙ = n/2[2a + (n-1)d]'},
      {'id': 'r3', 'category': 'Series', 'title': 'GP nth Term', 'formula': 'aₙ = arⁿ⁻¹', 'note': 'r=common ratio'},
      {'id': 'r4', 'category': 'Series', 'title': 'GP Sum', 'formula': 'Sₙ = a(rⁿ-1)/(r-1)', 'note': 'For r>1'},
      {'id': 'r5', 'category': 'Alphabet', 'title': 'Opposite Letters', 'formula': 'Sum of positions = 27', 'note': 'A↔Z, B↔Y, C↔X...', 'example': 'A(1) + Z(26) = 27'},
      {'id': 'r6', 'category': 'Coding', 'title': 'Reverse Alphabet', 'formula': 'Position = 27 - Original', 'note': 'A=26, B=25, C=24...'},
      {'id': 'r7', 'category': 'Clock', 'title': 'Angle Formula', 'formula': 'Angle = |30H - 5.5M|', 'note': 'H=hours, M=minutes'},
      {'id': 'r8', 'category': 'Clock', 'title': 'Overlap Time', 'formula': 'Time = 12H × 60/11 min', 'note': 'Hands overlap every 65.45 min'},
      {'id': 'r9', 'category': 'Calendar', 'title': 'Odd Days', 'formula': 'Ordinary Year = 1 odd day\nLeap Year = 2 odd days'},
      {'id': 'r10', 'category': 'Calendar', 'title': 'Century Odd Days', 'formula': '100 years = 5 odd days\n200 years = 3 odd days\n300 years = 1 odd day\n400 years = 0 odd days'},
    ];
  }

  List<Map<String, dynamic>> _getScienceFormulas() {
    return [
      {'id': 's1', 'category': 'Physics', 'title': 'Newton\'s 2nd Law', 'formula': 'F = ma', 'note': 'Force = mass × acceleration'},
      {'id': 's2', 'category': 'Physics', 'title': 'Kinetic Energy', 'formula': 'KE = ½mv²'},
      {'id': 's3', 'category': 'Physics', 'title': 'Potential Energy', 'formula': 'PE = mgh', 'note': 'g = 9.8 m/s²'},
      {'id': 's4', 'category': 'Physics', 'title': 'Ohm\'s Law', 'formula': 'V = IR', 'note': 'V=Voltage, I=Current, R=Resistance'},
      {'id': 's5', 'category': 'Physics', 'title': 'Power', 'formula': 'P = VI = I²R = V²/R'},
      {'id': 's6', 'category': 'Physics', 'title': 'Equations of Motion', 'formula': 'v = u + at\ns = ut + ½at²\nv² = u² + 2as'},
      {'id': 's7', 'category': 'Chemistry', 'title': 'Molarity', 'formula': 'M = moles/volume(L)'},
      {'id': 's8', 'category': 'Chemistry', 'title': 'Ideal Gas Law', 'formula': 'PV = nRT', 'note': 'R = 8.314 J/mol·K'},
      {'id': 's9', 'category': 'Chemistry', 'title': 'pH Formula', 'formula': 'pH = -log[H⁺]'},
      {'id': 's10', 'category': 'Biology', 'title': 'Photosynthesis', 'formula': '6CO₂ + 6H₂O → C₆H₁₂O₆ + 6O₂', 'note': 'Requires sunlight & chlorophyll'},
    ];
  }
}
