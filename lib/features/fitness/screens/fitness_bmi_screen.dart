import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/fitness_theme.dart';
import '../widgets/fitness_card.dart';
import '../widgets/fitness_button.dart';
import '../services/fitness_storage_service.dart';

class FitnessBmiScreen extends StatefulWidget {
  const FitnessBmiScreen({super.key});

  @override
  State<FitnessBmiScreen> createState() => _FitnessBmiScreenState();
}

class _FitnessBmiScreenState extends State<FitnessBmiScreen> {
  final FitnessStorageService _storage = FitnessStorageService();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  double? _currentBmi;
  String? _bmiCategory;
  List<WeightEntry> _weightHistory = [];
  double? _goalWeight;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final profile = await _storage.getProfile();
    final history = await _storage.getWeightHistory();
    final goal = await _storage.getGoalWeight();

    if (mounted) {
      setState(() {
        if (profile.heightCm != null) {
          _heightController.text = profile.heightCm!.toStringAsFixed(0);
        }
        if (profile.weightKg != null) {
          _weightController.text = profile.weightKg!.toStringAsFixed(1);
        }
        _weightHistory = history;
        _goalWeight = goal;
        _calculateBmi();
        _isLoading = false;
      });
    }
  }

  void _calculateBmi() {
    final height = double.tryParse(_heightController.text);
    final weight = double.tryParse(_weightController.text);

    if (height != null && weight != null && height > 0) {
      final heightM = height / 100;
      final bmi = weight / (heightM * heightM);
      setState(() {
        _currentBmi = bmi;
        _bmiCategory = _getBmiCategory(bmi);
      });
    } else {
      setState(() {
        _currentBmi = null;
        _bmiCategory = null;
      });
    }
  }

  String _getBmiCategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  Color _getBmiColor(double bmi) {
    if (bmi < 18.5) return FitnessTheme.info;
    if (bmi < 25) return FitnessTheme.success;
    if (bmi < 30) return FitnessTheme.warning;
    return FitnessTheme.error;
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: FitnessTheme.themeData,
      child: Scaffold(
        backgroundColor: FitnessTheme.background,
        appBar: AppBar(
          backgroundColor: FitnessTheme.background,
          title: const Text('BMI & Weight', style: FitnessTheme.headingSm),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: FitnessTheme.primary))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(FitnessTheme.spacingMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBmiCalculator(),
                    const SizedBox(height: FitnessTheme.spacingLg),
                    if (_currentBmi != null) _buildBmiResult(),
                    const SizedBox(height: FitnessTheme.spacingLg),
                    _buildWeightInput(),
                    const SizedBox(height: FitnessTheme.spacingLg),
                    if (_weightHistory.isNotEmpty) _buildWeightChart(),
                    const SizedBox(height: FitnessTheme.spacingLg),
                    _buildWeightHistory(),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildBmiCalculator() {
    return FitnessCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Calculate BMI', style: FitnessTheme.titleLg),
          const SizedBox(height: FitnessTheme.spacingMd),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _heightController,
                  keyboardType: TextInputType.number,
                  style: FitnessTheme.bodyMd,
                  onChanged: (_) => _calculateBmi(),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Height',
                    labelStyle: FitnessTheme.bodySm,
                    suffixText: 'cm',
                    filled: true,
                    fillColor: FitnessTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: FitnessTheme.borderRadiusSm,
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: FitnessTheme.spacingMd),
              Expanded(
                child: TextField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: FitnessTheme.bodyMd,
                  onChanged: (_) => _calculateBmi(),
                  decoration: InputDecoration(
                    labelText: 'Weight',
                    labelStyle: FitnessTheme.bodySm,
                    suffixText: 'kg',
                    filled: true,
                    fillColor: FitnessTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: FitnessTheme.borderRadiusSm,
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBmiResult() {
    final bmi = _currentBmi!;
    final color = _getBmiColor(bmi);

    return FitnessCard(
      backgroundColor: color.withValues(alpha: 0.1),
      borderColor: color.withValues(alpha: 0.3),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                bmi.toStringAsFixed(1),
                style: FitnessTheme.headingLg.copyWith(color: color),
              ),
              const SizedBox(width: FitnessTheme.spacingSm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('BMI', style: FitnessTheme.caption),
                  Text(
                    _bmiCategory ?? '',
                    style: FitnessTheme.titleSm.copyWith(color: color),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: FitnessTheme.spacingMd),
          // BMI Scale
          _buildBmiScale(bmi),
          const SizedBox(height: FitnessTheme.spacingMd),
          // Health tips
          _buildHealthTip(),
        ],
      ),
    );
  }

  Widget _buildBmiScale(double bmi) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              height: 8,
              decoration: BoxDecoration(
                borderRadius: FitnessTheme.borderRadiusSm,
                gradient: LinearGradient(
                  colors: [
                    FitnessTheme.info,
                    FitnessTheme.success,
                    FitnessTheme.warning,
                    FitnessTheme.error,
                  ],
                ),
              ),
            ),
            // Indicator
            Positioned(
              left: _getBmiPosition(bmi),
              child: Container(
                width: 16,
                height: 16,
                transform: Matrix4.translationValues(-8, -4, 0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: _getBmiColor(bmi), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: FitnessTheme.spacingSm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('15', style: FitnessTheme.caption),
            Text('18.5', style: FitnessTheme.caption),
            Text('25', style: FitnessTheme.caption),
            Text('30', style: FitnessTheme.caption),
            Text('40', style: FitnessTheme.caption),
          ],
        ),
      ],
    );
  }

  double _getBmiPosition(double bmi) {
    // Map BMI 15-40 to 0-1
    final normalized = ((bmi - 15) / 25).clamp(0.0, 1.0);
    // Assuming container width ~300 (will need to adjust based on actual width)
    return normalized * 280;
  }

  Widget _buildHealthTip() {
    String tip;
    if (_currentBmi! < 18.5) {
      tip = 'Consider eating more nutrient-rich foods and strength training to build healthy weight.';
    } else if (_currentBmi! < 25) {
      tip = 'Great job! Maintain your healthy weight with regular exercise and balanced nutrition.';
    } else if (_currentBmi! < 30) {
      tip = 'Focus on cardio exercises and reducing calorie intake to reach a healthier weight.';
    } else {
      tip = 'Consult a healthcare professional for a personalized weight management plan.';
    }

    return Container(
      padding: const EdgeInsets.all(FitnessTheme.spacingSm),
      decoration: BoxDecoration(
        color: FitnessTheme.surface,
        borderRadius: FitnessTheme.borderRadiusSm,
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline, color: FitnessTheme.primary, size: 20),
          const SizedBox(width: FitnessTheme.spacingSm),
          Expanded(
            child: Text(tip, style: FitnessTheme.bodySm),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightInput() {
    return FitnessCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Track Weight', style: FitnessTheme.titleLg),
              if (_goalWeight != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: FitnessTheme.spacingSm,
                    vertical: FitnessTheme.spacingXs,
                  ),
                  decoration: BoxDecoration(
                    color: FitnessTheme.primary.withValues(alpha: 0.2),
                    borderRadius: FitnessTheme.borderRadiusSm,
                  ),
                  child: Text(
                    'Goal: ${_goalWeight!.toStringAsFixed(1)} kg',
                    style: FitnessTheme.caption.copyWith(color: FitnessTheme.primary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: FitnessTheme.spacingMd),
          Row(
            children: [
              Expanded(
                child: FitnessPrimaryButton(
                  text: 'Log Weight',
                  icon: Icons.add,
                  onPressed: _showLogWeightDialog,
                ),
              ),
              const SizedBox(width: FitnessTheme.spacingSm),
              FitnessOutlineButton(
                text: 'Set Goal',
                onPressed: _showSetGoalDialog,
                width: 100,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeightChart() {
    if (_weightHistory.length < 2) return const SizedBox.shrink();

    final spots = _weightHistory.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.weight);
    }).toList();

    final minWeight = _weightHistory.map((e) => e.weight).reduce((a, b) => a < b ? a : b);
    final maxWeight = _weightHistory.map((e) => e.weight).reduce((a, b) => a > b ? a : b);

    return FitnessCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Weight Progress', style: FitnessTheme.titleLg),
          const SizedBox(height: FitnessTheme.spacingMd),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 5,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: FitnessTheme.surface,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}',
                        style: FitnessTheme.caption,
                      ),
                    ),
                  ),
                  bottomTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minY: minWeight - 5,
                maxY: maxWeight + 5,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: FitnessTheme.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                        radius: 4,
                        color: FitnessTheme.primary,
                        strokeWidth: 2,
                        strokeColor: FitnessTheme.background,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: FitnessTheme.primary.withValues(alpha: 0.1),
                    ),
                  ),
                  if (_goalWeight != null)
                    LineChartBarData(
                      spots: [
                        FlSpot(0, _goalWeight!),
                        FlSpot((_weightHistory.length - 1).toDouble(), _goalWeight!),
                      ],
                      isCurved: false,
                      color: FitnessTheme.success,
                      barWidth: 2,
                      dashArray: [5, 5],
                      dotData: const FlDotData(show: false),
                    ),
                ],
              ),
            ),
          ),
          if (_goalWeight != null)
            Padding(
              padding: const EdgeInsets.only(top: FitnessTheme.spacingSm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 20, height: 2, color: FitnessTheme.success),
                  const SizedBox(width: 4),
                  Text('Goal: ${_goalWeight!.toStringAsFixed(1)} kg', style: FitnessTheme.caption),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWeightHistory() {
    if (_weightHistory.isEmpty) {
      return FitnessCard(
        backgroundColor: FitnessTheme.surface,
        child: Column(
          children: [
            Icon(Icons.monitor_weight_outlined, size: 48, color: FitnessTheme.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: FitnessTheme.spacingMd),
            Text('No weight entries yet', style: FitnessTheme.titleMd.copyWith(color: FitnessTheme.textMuted)),
            const SizedBox(height: FitnessTheme.spacingSm),
            Text('Start tracking your weight progress', style: FitnessTheme.bodySm),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Entries', style: FitnessTheme.titleLg),
        const SizedBox(height: FitnessTheme.spacingMd),
        ..._weightHistory.take(5).map((entry) {
          final change = _weightHistory.indexOf(entry) > 0
              ? entry.weight - _weightHistory[_weightHistory.indexOf(entry) - 1].weight
              : null;

          return FitnessCard(
            margin: const EdgeInsets.only(bottom: FitnessTheme.spacingSm),
            padding: const EdgeInsets.all(FitnessTheme.spacingMd),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: FitnessTheme.primary.withValues(alpha: 0.2),
                    borderRadius: FitnessTheme.borderRadiusSm,
                  ),
                  child: const Icon(Icons.monitor_weight, color: FitnessTheme.primary),
                ),
                const SizedBox(width: FitnessTheme.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${entry.weight.toStringAsFixed(1)} kg', style: FitnessTheme.titleMd),
                      Text(_formatDate(entry.date), style: FitnessTheme.caption),
                    ],
                  ),
                ),
                if (change != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: FitnessTheme.spacingSm,
                      vertical: FitnessTheme.spacingXs,
                    ),
                    decoration: BoxDecoration(
                      color: (change < 0 ? FitnessTheme.success : FitnessTheme.error).withValues(alpha: 0.2),
                      borderRadius: FitnessTheme.borderRadiusSm,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          change < 0 ? Icons.arrow_downward : Icons.arrow_upward,
                          size: 14,
                          color: change < 0 ? FitnessTheme.success : FitnessTheme.error,
                        ),
                        Text(
                          '${change.abs().toStringAsFixed(1)} kg',
                          style: FitnessTheme.caption.copyWith(
                            color: change < 0 ? FitnessTheme.success : FitnessTheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryDate = DateTime(date.year, date.month, date.day);

    if (entryDate == today) return 'Today';
    if (entryDate == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showLogWeightDialog() {
    final controller = TextEditingController(text: _weightController.text);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FitnessTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: FitnessTheme.borderRadiusLg),
        title: Text('Log Weight', style: FitnessTheme.headingSm),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: FitnessTheme.bodyMd,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Weight',
            suffixText: 'kg',
            filled: true,
            fillColor: FitnessTheme.background,
            border: OutlineInputBorder(
              borderRadius: FitnessTheme.borderRadiusSm,
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: FitnessTheme.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              final weight = double.tryParse(controller.text);
              if (weight != null && weight > 0) {
                await _storage.logWeight(weight);
                Navigator.pop(context);
                _loadData();
                HapticFeedback.mediumImpact();
              }
            },
            child: Text('Save', style: TextStyle(color: FitnessTheme.primary)),
          ),
        ],
      ),
    );
  }

  void _showSetGoalDialog() {
    final controller = TextEditingController(
      text: _goalWeight?.toStringAsFixed(1) ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FitnessTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: FitnessTheme.borderRadiusLg),
        title: Text('Set Goal Weight', style: FitnessTheme.headingSm),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: FitnessTheme.bodyMd,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Goal Weight',
            suffixText: 'kg',
            filled: true,
            fillColor: FitnessTheme.background,
            border: OutlineInputBorder(
              borderRadius: FitnessTheme.borderRadiusSm,
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: FitnessTheme.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              final goal = double.tryParse(controller.text);
              if (goal != null && goal > 0) {
                await _storage.setGoalWeight(goal);
                Navigator.pop(context);
                _loadData();
                HapticFeedback.mediumImpact();
              }
            },
            child: Text('Save', style: TextStyle(color: FitnessTheme.primary)),
          ),
        ],
      ),
    );
  }
}

