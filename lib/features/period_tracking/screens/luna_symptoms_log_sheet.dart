import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/luna_theme.dart';
import '../services/period_storage_service.dart';
import '../models/symptom_log.dart';

/// Bottom sheet for logging symptoms
class LunaSymptomsLogSheet extends StatefulWidget {
  final DateTime date;
  final VoidCallback? onSaved;

  const LunaSymptomsLogSheet({
    super.key,
    required this.date,
    this.onSaved,
  });

  @override
  State<LunaSymptomsLogSheet> createState() => _LunaSymptomsLogSheetState();
}

class _LunaSymptomsLogSheetState extends State<LunaSymptomsLogSheet> {
  final Set<SymptomType> _selectedSymptoms = {};
  int _severity = 2;
  EnergyLevel _energyLevel = EnergyLevel.moderate;
  SleepQuality _sleepQuality = SleepQuality.good;
  final _notesController = TextEditingController();

  final List<_SymptomOption> _symptoms = [
    _SymptomOption(SymptomType.cramps, '😣', 'Cramps'),
    _SymptomOption(SymptomType.headache, '🤕', 'Headache'),
    _SymptomOption(SymptomType.bloating, '🫃', 'Bloating'),
    _SymptomOption(SymptomType.fatigue, '😴', 'Fatigue'),
    _SymptomOption(SymptomType.breastTenderness, '💔', 'Tender Breasts'),
    _SymptomOption(SymptomType.backache, '🔙', 'Backache'),
    _SymptomOption(SymptomType.nausea, '🤢', 'Nausea'),
    _SymptomOption(SymptomType.acne, '😖', 'Acne'),
    _SymptomOption(SymptomType.cravings, '🍫', 'Cravings'),
    _SymptomOption(SymptomType.moodSwings, '🎭', 'Mood Swings'),
    _SymptomOption(SymptomType.insomnia, '🌙', 'Insomnia'),
    _SymptomOption(SymptomType.hotFlashes, '🔥', 'Hot Flashes'),
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveSymptoms() async {
    if (_selectedSymptoms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one symptom')),
      );
      return;
    }

    HapticFeedback.mediumImpact();

    // Create symptom log
    final log = SymptomLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: widget.date,
      symptoms: _selectedSymptoms.toList(),
      severity: _severity,
      energyLevel: _energyLevel,
      sleepQuality: _sleepQuality,
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      createdAt: DateTime.now(),
    );

    await PeriodCleanStorageService.addSymptomLog(log);

    if (mounted) {
      Navigator.pop(context);
      widget.onSaved?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_selectedSymptoms.length} symptoms logged'),
          backgroundColor: LunaTheme.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: LunaTheme.getSurface(context),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(LunaTheme.radius2xl),
        ),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: LunaTheme.spacingMd),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: LunaTheme.getDivider(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(LunaTheme.spacingLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.healing, color: LunaTheme.secondaryCoral),
                      const SizedBox(width: LunaTheme.spacingSm),
                      Text(
                        'Log Symptoms',
                        style: LunaTheme.headlineMedium.copyWith(
                          color: LunaTheme.getTextPrimary(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: LunaTheme.spacingLg),

                  // Symptoms grid
                  Text(
                    'What are you experiencing?',
                    style: LunaTheme.titleMedium.copyWith(
                      color: LunaTheme.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: LunaTheme.spacingMd),
                  Wrap(
                    spacing: LunaTheme.spacingSm,
                    runSpacing: LunaTheme.spacingSm,
                    children: _symptoms.map((symptom) {
                      final isSelected = _selectedSymptoms.contains(symptom.type);
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            if (isSelected) {
                              _selectedSymptoms.remove(symptom.type);
                            } else {
                              _selectedSymptoms.add(symptom.type);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? LunaTheme.secondaryCoral.withOpacity(0.2)
                                : LunaTheme.getSurface(context),
                            borderRadius: BorderRadius.circular(LunaTheme.radiusFull),
                            border: Border.all(
                              color: isSelected
                                  ? LunaTheme.secondaryCoral
                                  : LunaTheme.getDivider(context),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(symptom.emoji, style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 6),
                              Text(
                                symptom.label,
                                style: LunaTheme.bodySmall.copyWith(
                                  color: isSelected
                                      ? LunaTheme.secondaryCoral
                                      : LunaTheme.getTextSecondary(context),
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: LunaTheme.spacingXl),

                  // Severity
                  Text(
                    'Overall Severity',
                    style: LunaTheme.titleMedium.copyWith(
                      color: LunaTheme.getTextPrimary(context),
                    ),
                  ),
                  Slider(
                    value: _severity.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    activeColor: LunaTheme.secondaryCoral,
                    label: _getSeverityLabel(_severity),
                    onChanged: (value) {
                      setState(() => _severity = value.round());
                    },
                  ),

                  const SizedBox(height: LunaTheme.spacingLg),

                  // Energy level
                  Text(
                    'Energy Level',
                    style: LunaTheme.titleMedium.copyWith(
                      color: LunaTheme.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: LunaTheme.spacingSm),
                  Row(
                    children: EnergyLevel.values.map((level) {
                      final isSelected = _energyLevel == level;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _energyLevel = level),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? LunaTheme.follicularYellow.withOpacity(0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(LunaTheme.radiusSm),
                              border: Border.all(
                                color: isSelected
                                    ? LunaTheme.follicularYellow
                                    : LunaTheme.getDivider(context),
                              ),
                            ),
                            child: Text(
                              level.name.substring(0, 1).toUpperCase() + level.name.substring(1),
                              textAlign: TextAlign.center,
                              style: LunaTheme.labelSmall.copyWith(
                                color: isSelected
                                    ? LunaTheme.follicularYellow
                                    : LunaTheme.getTextSecondary(context),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: LunaTheme.spacingLg),

                  // Sleep quality
                  Text(
                    'Sleep Quality',
                    style: LunaTheme.titleMedium.copyWith(
                      color: LunaTheme.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: LunaTheme.spacingSm),
                  Row(
                    children: SleepQuality.values.map((quality) {
                      final isSelected = _sleepQuality == quality;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _sleepQuality = quality),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? LunaTheme.ovulationBlue.withOpacity(0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(LunaTheme.radiusSm),
                              border: Border.all(
                                color: isSelected
                                    ? LunaTheme.ovulationBlue
                                    : LunaTheme.getDivider(context),
                              ),
                            ),
                            child: Text(
                              quality.name.substring(0, 1).toUpperCase() + quality.name.substring(1),
                              textAlign: TextAlign.center,
                              style: LunaTheme.labelSmall.copyWith(
                                color: isSelected
                                    ? LunaTheme.ovulationBlue
                                    : LunaTheme.getTextSecondary(context),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: LunaTheme.spacingLg),

                  // Notes
                  TextField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Add notes (optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(LunaTheme.radiusMd),
                      ),
                    ),
                  ),

                  const SizedBox(height: LunaTheme.spacingXl),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveSymptoms,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LunaTheme.secondaryCoral,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(LunaTheme.radiusMd),
                        ),
                      ),
                      child: const Text('Save Symptoms', style: TextStyle(color: Colors.white)),
                    ),
                  ),

                  SafeArea(
                    top: false,
                    child: Container(height: LunaTheme.spacingMd),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getSeverityLabel(int value) {
    switch (value) {
      case 1: return 'Very Mild';
      case 2: return 'Mild';
      case 3: return 'Moderate';
      case 4: return 'Severe';
      case 5: return 'Very Severe';
      default: return 'Moderate';
    }
  }
}

class _SymptomOption {
  final SymptomType type;
  final String emoji;
  final String label;

  const _SymptomOption(this.type, this.emoji, this.label);
}
