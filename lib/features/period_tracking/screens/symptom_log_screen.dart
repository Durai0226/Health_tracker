import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../models/symptom_log.dart';
import '../services/period_storage_service.dart';

class SymptomLogScreen extends StatefulWidget {
  final DateTime date;

  const SymptomLogScreen({super.key, required this.date});

  @override
  State<SymptomLogScreen> createState() => _SymptomLogScreenState();
}

class _SymptomLogScreenState extends State<SymptomLogScreen> {
  final List<SymptomEntry> _selectedSymptoms = [];
  final List<MoodType> _selectedMoods = [];
  EnergyLevel? _energyLevel;
  SleepQuality? _sleepQuality;
  double _sleepHours = 7.0;
  int _stressLevel = 5;
  bool _hadIntimacy = false;
  bool _usedProtection = false;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadExistingLog();
  }

  void _loadExistingLog() {
    final existing = PeriodStorageService.getSymptomLogForDate(widget.date);
    if (existing != null) {
      _selectedSymptoms.addAll(existing.symptoms);
      _selectedMoods.addAll(existing.moods);
      _energyLevel = existing.energyLevel;
      _sleepQuality = existing.sleepQuality;
      _sleepHours = existing.sleepHours ?? 7.0;
      _stressLevel = existing.stressLevel ?? 5;
      _hadIntimacy = existing.hadIntimacy ?? false;
      _usedProtection = existing.usedProtection ?? false;
      _notesController.text = existing.notes ?? '';
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
      hadIntimacy: _hadIntimacy,
      usedProtection: _usedProtection,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
    );

    await PeriodStorageService.saveSymptomLog(log);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Log saved for ${DateFormat('MMM d').format(widget.date)}'),
          backgroundColor: AppColors.periodPrimary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.periodPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          DateFormat('EEEE, MMM d').format(widget.date),
          style: const TextStyle(color: AppColors.periodPrimary),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save', style: TextStyle(color: AppColors.periodPrimary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Symptoms', Icons.healing_rounded),
            _buildSymptomGrid(),
            const SizedBox(height: 24),
            _buildSectionTitle('Mood', Icons.mood_rounded),
            _buildMoodGrid(),
            const SizedBox(height: 24),
            _buildSectionTitle('Energy Level', Icons.bolt_rounded),
            _buildEnergySelector(),
            const SizedBox(height: 24),
            _buildSectionTitle('Sleep', Icons.bedtime_rounded),
            _buildSleepSection(),
            const SizedBox(height: 24),
            _buildSectionTitle('Stress Level', Icons.psychology_rounded),
            _buildStressSlider(),
            const SizedBox(height: 24),
            _buildSectionTitle('Intimacy', Icons.favorite_rounded),
            _buildIntimacySection(),
            const SizedBox(height: 24),
            _buildSectionTitle('Notes', Icons.note_rounded),
            _buildNotesField(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.periodPrimary, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSymptomGrid() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
          ),
        ],
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: SymptomType.values.map((type) {
          final isSelected = _selectedSymptoms.any((s) => s.type == type);
          return GestureDetector(
            onTap: () => _toggleSymptom(type),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.periodPrimary : AppColors.periodLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getSymptomIcon(type),
                    size: 16,
                    color: isSelected ? Colors.white : AppColors.periodPrimary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _getSymptomDisplayName(type),
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.periodPrimary,
                      fontSize: 13,
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

  void _toggleSymptom(SymptomType type) {
    setState(() {
      final index = _selectedSymptoms.indexWhere((s) => s.type == type);
      if (index >= 0) {
        _selectedSymptoms.removeAt(index);
      } else {
        _showSeverityDialog(type);
      }
    });
  }

  void _showSeverityDialog(SymptomType type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Severity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: SymptomSeverity.values.map((severity) {
            return ListTile(
              title: Text(_getSeverityDisplayName(severity)),
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

  Widget _buildMoodGrid() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
          ),
        ],
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: MoodType.values.map((mood) {
          final isSelected = _selectedMoods.contains(mood);
          return GestureDetector(
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedMoods.remove(mood);
                } else {
                  _selectedMoods.add(mood);
                }
              });
            },
            child: Column(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.periodLight : Colors.grey.shade100,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: AppColors.periodPrimary, width: 2)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      _getMoodEmoji(mood),
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getMoodDisplayName(mood),
                  style: TextStyle(
                    fontSize: 10,
                    color: isSelected ? AppColors.periodPrimary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEnergySelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: EnergyLevel.values.map((level) {
          final isSelected = _energyLevel == level;
          return GestureDetector(
            onTap: () => setState(() => _energyLevel = level),
            child: Column(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isSelected ? _getEnergyColor(level) : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.bolt_rounded,
                      color: isSelected ? Colors.white : Colors.grey,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getEnergyDisplayName(level),
                  style: TextStyle(
                    fontSize: 10,
                    color: isSelected ? _getEnergyColor(level) : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSleepSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Hours of sleep'),
              Text(
                '${_sleepHours.toStringAsFixed(1)} hrs',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Slider(
            value: _sleepHours,
            min: 0,
            max: 14,
            divisions: 28,
            activeColor: AppColors.periodPrimary,
            onChanged: (value) => setState(() => _sleepHours = value),
          ),
          const SizedBox(height: 16),
          const Text('Sleep Quality'),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: SleepQuality.values.map((quality) {
              final isSelected = _sleepQuality == quality;
              return GestureDetector(
                onTap: () => setState(() => _sleepQuality = quality),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.periodPrimary : AppColors.periodLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getSleepQualityDisplayName(quality),
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.periodPrimary,
                      fontSize: 12,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('😌 Calm'),
              Text(
                '$_stressLevel',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: _getStressColor(),
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
            onChanged: (value) => setState(() => _stressLevel = value.round()),
          ),
        ],
      ),
    );
  }

  Widget _buildIntimacySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Had intimacy'),
            value: _hadIntimacy,
            activeThumbColor: AppColors.periodPrimary,
            contentPadding: EdgeInsets.zero,
            onChanged: (value) => setState(() {
              _hadIntimacy = value;
              if (!value) _usedProtection = false;
            }),
          ),
          if (_hadIntimacy)
            SwitchListTile(
              title: const Text('Used protection'),
              value: _usedProtection,
              activeThumbColor: AppColors.periodPrimary,
              contentPadding: EdgeInsets.zero,
              onChanged: (value) => setState(() => _usedProtection = value),
            ),
        ],
      ),
    );
  }

  Widget _buildNotesField() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
          ),
        ],
      ),
      child: TextField(
        controller: _notesController,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: 'Add any notes...',
          border: InputBorder.none,
        ),
      ),
    );
  }

  // Helper methods
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

  String _getSymptomDisplayName(SymptomType type) {
    switch (type) {
      case SymptomType.cramps: return 'Cramps';
      case SymptomType.headache: return 'Headache';
      case SymptomType.backPain: return 'Back Pain';
      case SymptomType.bloating: return 'Bloating';
      case SymptomType.breastTenderness: return 'Breast Tenderness';
      case SymptomType.fatigue: return 'Fatigue';
      case SymptomType.acne: return 'Acne';
      case SymptomType.nausea: return 'Nausea';
      case SymptomType.insomnia: return 'Insomnia';
      case SymptomType.hotFlashes: return 'Hot Flashes';
      case SymptomType.dizziness: return 'Dizziness';
      case SymptomType.cravings: return 'Cravings';
      case SymptomType.constipation: return 'Constipation';
      case SymptomType.diarrhea: return 'Diarrhea';
      case SymptomType.jointPain: return 'Joint Pain';
    }
  }

  String _getSeverityDisplayName(SymptomSeverity severity) {
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

  String _getMoodDisplayName(MoodType mood) {
    switch (mood) {
      case MoodType.happy: return 'Happy';
      case MoodType.calm: return 'Calm';
      case MoodType.energetic: return 'Energetic';
      case MoodType.sensitive: return 'Sensitive';
      case MoodType.anxious: return 'Anxious';
      case MoodType.irritable: return 'Irritable';
      case MoodType.sad: return 'Sad';
      case MoodType.moodSwings: return 'Mood Swings';
      case MoodType.stressed: return 'Stressed';
      case MoodType.tired: return 'Tired';
      case MoodType.focused: return 'Focused';
      case MoodType.confused: return 'Confused';
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

  String _getEnergyDisplayName(EnergyLevel level) {
    switch (level) {
      case EnergyLevel.veryLow: return 'Very Low';
      case EnergyLevel.low: return 'Low';
      case EnergyLevel.medium: return 'Medium';
      case EnergyLevel.high: return 'High';
      case EnergyLevel.veryHigh: return 'Very High';
    }
  }

  String _getSleepQualityDisplayName(SleepQuality quality) {
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
