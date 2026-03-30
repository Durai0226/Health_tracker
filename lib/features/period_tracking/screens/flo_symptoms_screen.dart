import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/flo_theme.dart';
import '../widgets/widgets.dart';
import '../models/symptom_log.dart';
import '../services/period_storage_service.dart';

/// Modern symptom logging screen with Flo design
class FloSymptomsScreen extends StatefulWidget {
  final DateTime date;

  const FloSymptomsScreen({
    super.key,
    required this.date,
  });

  @override
  State<FloSymptomsScreen> createState() => _FloSymptomsScreenState();
}

class _FloSymptomsScreenState extends State<FloSymptomsScreen> {
  final List<SymptomEntry> _selectedSymptoms = [];
  final List<MoodType> _selectedMoods = [];
  EnergyLevel? _energyLevel;
  SleepQuality? _sleepQuality;
  double _sleepHours = 7.0;
  int _stressLevel = 5;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadExistingLog();
  }

  void _loadExistingLog() {
    final existing = PeriodCleanStorageService.getSymptomLogForDate(widget.date);
    if (existing != null) {
      _selectedSymptoms.addAll(existing.symptoms);
      _selectedMoods.addAll(existing.moods);
      _energyLevel = existing.energyLevel;
      _sleepQuality = existing.sleepQuality;
      _sleepHours = existing.sleepHours ?? 7.0;
      _stressLevel = existing.stressLevel ?? 5;
      _notesController.text = existing.notes ?? '';
      setState(() {});
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final log = SymptomLog(
      id: '${widget.date.year}-${widget.date.month}-${widget.date.day}',
      date: widget.date,
      symptoms: _selectedSymptoms,
      moods: _selectedMoods,
      energyLevel: _energyLevel,
      sleepQuality: _sleepQuality,
      sleepHours: _sleepHours,
      stressLevel: _stressLevel,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
    );

    await PeriodCleanStorageService.saveSymptomLog(log);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Log saved for ${DateFormat('MMM d').format(widget.date)}'),
          backgroundColor: FloTheme.periodPink,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FloTheme.getBackground(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: FloTheme.getTextPrimary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          DateFormat('EEEE, MMM d').format(widget.date),
          style: FloTheme.headlineSmall.copyWith(
            color: FloTheme.getTextPrimary(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              'Save',
              style: FloTheme.titleMedium.copyWith(
                color: FloTheme.periodPink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(FloTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mood section
            _buildSectionTitle('How are you feeling?', Icons.mood_rounded),
            const SizedBox(height: FloTheme.spacingMd),
            _buildMoodGrid(),

            const SizedBox(height: FloTheme.spacing2xl),

            // Symptoms section
            _buildSectionTitle('Any symptoms?', Icons.healing_rounded),
            const SizedBox(height: FloTheme.spacingMd),
            _buildSymptomGrid(),

            const SizedBox(height: FloTheme.spacing2xl),

            // Energy level
            _buildSectionTitle('Energy Level', Icons.bolt_rounded),
            const SizedBox(height: FloTheme.spacingMd),
            _buildEnergySelector(),

            const SizedBox(height: FloTheme.spacing2xl),

            // Sleep section
            _buildSectionTitle('Sleep', Icons.bedtime_rounded),
            const SizedBox(height: FloTheme.spacingMd),
            _buildSleepSection(),

            const SizedBox(height: FloTheme.spacing2xl),

            // Stress level
            _buildSectionTitle('Stress Level', Icons.psychology_rounded),
            const SizedBox(height: FloTheme.spacingMd),
            _buildStressSlider(),

            const SizedBox(height: FloTheme.spacing2xl),

            // Notes
            _buildSectionTitle('Notes', Icons.note_rounded),
            const SizedBox(height: FloTheme.spacingMd),
            _buildNotesField(),

            const SizedBox(height: FloTheme.spacing4xl),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: FloTheme.periodPink, size: 20),
        const SizedBox(width: FloTheme.spacingSm),
        Text(
          title,
          style: FloTheme.headlineSmall.copyWith(
            color: FloTheme.getTextPrimary(context),
          ),
        ),
      ],
    );
  }

  Widget _buildMoodGrid() {
    return FloGlassCard(
      padding: const EdgeInsets.all(FloTheme.spacingLg),
      child: Wrap(
        spacing: FloTheme.spacingMd,
        runSpacing: FloTheme.spacingMd,
        children: MoodType.values.map((mood) {
          final isSelected = _selectedMoods.contains(mood);
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                if (isSelected) {
                  _selectedMoods.remove(mood);
                } else {
                  _selectedMoods.add(mood);
                }
              });
            },
            child: AnimatedContainer(
              duration: FloTheme.animFast,
              padding: const EdgeInsets.all(FloTheme.spacingMd),
              decoration: BoxDecoration(
                color: isSelected
                    ? FloTheme.periodPink.withOpacity(0.1)
                    : FloTheme.getDivider(context),
                borderRadius: BorderRadius.circular(FloTheme.radiusMd),
                border: isSelected
                    ? Border.all(color: FloTheme.periodPink, width: 2)
                    : null,
              ),
              child: Column(
                children: [
                  Text(
                    _getMoodEmoji(mood),
                    style: const TextStyle(fontSize: 28),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getMoodName(mood),
                    style: FloTheme.labelSmall.copyWith(
                      color: isSelected
                          ? FloTheme.periodPink
                          : FloTheme.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSymptomGrid() {
    return FloGlassCard(
      padding: const EdgeInsets.all(FloTheme.spacingLg),
      child: Wrap(
        spacing: FloTheme.spacingSm,
        runSpacing: FloTheme.spacingSm,
        children: SymptomType.values.map((type) {
          final isSelected = _selectedSymptoms.any((s) => s.type == type);
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              if (isSelected) {
                setState(() {
                  _selectedSymptoms.removeWhere((s) => s.type == type);
                });
              } else {
                _showSeverityDialog(type);
              }
            },
            child: AnimatedContainer(
              duration: FloTheme.animFast,
              padding: const EdgeInsets.symmetric(
                horizontal: FloTheme.spacingMd,
                vertical: FloTheme.spacingSm,
              ),
              decoration: BoxDecoration(
                color: isSelected ? FloTheme.periodPink : FloTheme.periodPinkLight,
                borderRadius: BorderRadius.circular(FloTheme.radiusFull),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getSymptomIcon(type),
                    size: 16,
                    color: isSelected ? Colors.white : FloTheme.periodPink,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _getSymptomName(type),
                    style: FloTheme.labelSmall.copyWith(
                      color: isSelected ? Colors.white : FloTheme.periodPink,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showSeverityDialog(SymptomType type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FloTheme.getSurface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FloTheme.radiusXl),
        ),
        title: Text(
          'Severity',
          style: FloTheme.headlineMedium.copyWith(
            color: FloTheme.getTextPrimary(context),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: SymptomSeverity.values.map((severity) {
            return ListTile(
              title: Text(_getSeverityName(severity)),
              leading: Icon(
                _getSeverityIcon(severity),
                color: _getSeverityColor(severity),
              ),
              onTap: () {
                setState(() {
                  _selectedSymptoms.add(SymptomEntry(
                    type: type,
                    severity: severity,
                  ));
                });
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEnergySelector() {
    return FloGlassCard(
      padding: const EdgeInsets.all(FloTheme.spacingLg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: EnergyLevel.values.map((level) {
          final isSelected = _energyLevel == level;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _energyLevel = level);
            },
            child: AnimatedContainer(
              duration: FloTheme.animFast,
              padding: const EdgeInsets.all(FloTheme.spacingMd),
              decoration: BoxDecoration(
                color: isSelected ? _getEnergyColor(level) : FloTheme.getDivider(context),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bolt_rounded,
                color: isSelected ? Colors.white : FloTheme.getTextSecondary(context),
                size: 24,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSleepSection() {
    return FloGlassCard(
      padding: const EdgeInsets.all(FloTheme.spacingLg),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hours of sleep',
                style: FloTheme.bodyMedium.copyWith(
                  color: FloTheme.getTextPrimary(context),
                ),
              ),
              Text(
                '${_sleepHours.toStringAsFixed(1)} hrs',
                style: FloTheme.titleMedium.copyWith(
                  color: FloTheme.periodPink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Slider(
            value: _sleepHours,
            min: 0,
            max: 14,
            divisions: 28,
            activeColor: FloTheme.periodPink,
            inactiveColor: FloTheme.getDivider(context),
            onChanged: (value) => setState(() => _sleepHours = value),
          ),
          const SizedBox(height: FloTheme.spacingMd),
          Text(
            'Sleep Quality',
            style: FloTheme.bodyMedium.copyWith(
              color: FloTheme.getTextPrimary(context),
            ),
          ),
          const SizedBox(height: FloTheme.spacingSm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: SleepQuality.values.map((quality) {
              final isSelected = _sleepQuality == quality;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _sleepQuality = quality);
                },
                child: AnimatedContainer(
                  duration: FloTheme.animFast,
                  padding: const EdgeInsets.symmetric(
                    horizontal: FloTheme.spacingMd,
                    vertical: FloTheme.spacingSm,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? FloTheme.periodPink : FloTheme.periodPinkLight,
                    borderRadius: BorderRadius.circular(FloTheme.radiusFull),
                  ),
                  child: Text(
                    _getSleepQualityName(quality),
                    style: FloTheme.labelSmall.copyWith(
                      color: isSelected ? Colors.white : FloTheme.periodPink,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStressSlider() {
    return FloGlassCard(
      padding: const EdgeInsets.all(FloTheme.spacingLg),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('😌 Calm'),
              Text(
                '$_stressLevel',
                style: FloTheme.headlineMedium.copyWith(
                  color: _getStressColor(),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text('😫 Stressed'),
            ],
          ),
          Slider(
            value: _stressLevel.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            activeColor: _getStressColor(),
            inactiveColor: FloTheme.getDivider(context),
            onChanged: (value) => setState(() => _stressLevel = value.round()),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesField() {
    return FloGlassCard(
      padding: const EdgeInsets.all(FloTheme.spacingLg),
      child: TextField(
        controller: _notesController,
        maxLines: 3,
        style: FloTheme.bodyMedium.copyWith(
          color: FloTheme.getTextPrimary(context),
        ),
        decoration: InputDecoration(
          hintText: 'Add any notes...',
          hintStyle: FloTheme.bodyMedium.copyWith(
            color: FloTheme.getTextSecondary(context),
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }

  // Helper methods
  String _getMoodEmoji(MoodType mood) {
    switch (mood) {
      case MoodType.happy: return '😊';
      case MoodType.calm: return '😌';
      case MoodType.energetic: return '⚡';
      case MoodType.sensitive: return '🥺';
      case MoodType.anxious: return '😰';
      case MoodType.irritable: return '😤';
      case MoodType.sad: return '😢';
      case MoodType.moodSwings: return '🎭';
      case MoodType.stressed: return '😫';
      case MoodType.tired: return '😴';
      case MoodType.focused: return '🎯';
      case MoodType.confused: return '😕';
    }
  }

  String _getMoodName(MoodType mood) {
    return mood.toString().split('.').last.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(1)}',
    ).trim();
  }

  IconData _getSymptomIcon(SymptomType type) {
    switch (type) {
      case SymptomType.cramps: return Icons.flash_on_rounded;
      case SymptomType.headache: return Icons.psychology_rounded;
      case SymptomType.backPain: return Icons.accessibility_rounded;
      case SymptomType.bloating: return Icons.expand_rounded;
      case SymptomType.breastTenderness: return Icons.favorite_rounded;
      case SymptomType.fatigue: return Icons.battery_0_bar_rounded;
      case SymptomType.acne: return Icons.face_rounded;
      case SymptomType.nausea: return Icons.sick_rounded;
      case SymptomType.insomnia: return Icons.bedtime_off_rounded;
      case SymptomType.hotFlashes: return Icons.whatshot_rounded;
      case SymptomType.dizziness: return Icons.rotate_right_rounded;
      case SymptomType.cravings: return Icons.fastfood_rounded;
      case SymptomType.constipation: return Icons.pause_rounded;
      case SymptomType.diarrhea: return Icons.water_rounded;
      case SymptomType.jointPain: return Icons.sports_handball_rounded;
    }
  }

  String _getSymptomName(SymptomType type) {
    return type.toString().split('.').last.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(1)}',
    ).trim();
  }

  String _getSeverityName(SymptomSeverity severity) {
    switch (severity) {
      case SymptomSeverity.mild: return 'Mild';
      case SymptomSeverity.moderate: return 'Moderate';
      case SymptomSeverity.severe: return 'Severe';
    }
  }

  IconData _getSeverityIcon(SymptomSeverity severity) {
    switch (severity) {
      case SymptomSeverity.mild: return Icons.sentiment_satisfied_rounded;
      case SymptomSeverity.moderate: return Icons.sentiment_neutral_rounded;
      case SymptomSeverity.severe: return Icons.sentiment_very_dissatisfied_rounded;
    }
  }

  Color _getSeverityColor(SymptomSeverity severity) {
    switch (severity) {
      case SymptomSeverity.mild: return Colors.green;
      case SymptomSeverity.moderate: return Colors.orange;
      case SymptomSeverity.severe: return Colors.red;
    }
  }

  Color _getEnergyColor(EnergyLevel level) {
    switch (level) {
      case EnergyLevel.veryLow: return Colors.red;
      case EnergyLevel.low: return Colors.orange;
      case EnergyLevel.medium: return Colors.yellow.shade700;
      case EnergyLevel.high: return Colors.lightGreen;
      case EnergyLevel.veryHigh: return Colors.green;
    }
  }

  String _getSleepQualityName(SleepQuality quality) {
    switch (quality) {
      case SleepQuality.poor: return 'Poor';
      case SleepQuality.fair: return 'Fair';
      case SleepQuality.good: return 'Good';
      case SleepQuality.excellent: return 'Excellent';
    }
  }

  Color _getStressColor() {
    if (_stressLevel <= 3) return Colors.green;
    if (_stressLevel <= 6) return Colors.orange;
    return Colors.red;
  }
}
