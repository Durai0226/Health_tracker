import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/luna_theme.dart';
import '../services/period_storage_service.dart';
import '../models/symptom_log.dart';

/// Bottom sheet for logging mood
class LunaMoodLogSheet extends StatefulWidget {
  final DateTime date;
  final VoidCallback? onSaved;

  const LunaMoodLogSheet({
    super.key,
    required this.date,
    this.onSaved,
  });

  @override
  State<LunaMoodLogSheet> createState() => _LunaMoodLogSheetState();
}

class _LunaMoodLogSheetState extends State<LunaMoodLogSheet> {
  MoodType? _selectedMood;
  int _intensity = 3;
  final _notesController = TextEditingController();

  final List<_MoodOption> _moods = [
    _MoodOption(MoodType.happy, '😊', 'Happy'),
    _MoodOption(MoodType.calm, '😌', 'Calm'),
    _MoodOption(MoodType.energetic, '⚡', 'Energetic'),
    _MoodOption(MoodType.sensitive, '🥺', 'Sensitive'),
    _MoodOption(MoodType.anxious, '😰', 'Anxious'),
    _MoodOption(MoodType.sad, '😢', 'Sad'),
    _MoodOption(MoodType.irritable, '😤', 'Irritable'),
    _MoodOption(MoodType.tired, '😴', 'Tired'),
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveMood() async {
    if (_selectedMood == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a mood')),
      );
      return;
    }

    HapticFeedback.mediumImpact();

    // Create symptom log with mood
    final log = SymptomLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: widget.date,
      mood: _selectedMood!,
      moodIntensity: _intensity,
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      createdAt: DateTime.now(),
    );

    await PeriodCleanStorageService.addSymptomLog(log);

    if (mounted) {
      Navigator.pop(context);
      widget.onSaved?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mood logged: ${_moods.firstWhere((m) => m.type == _selectedMood).label}'),
          backgroundColor: LunaTheme.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: LunaTheme.getSurface(context),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(LunaTheme.radius2xl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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

          Padding(
            padding: const EdgeInsets.all(LunaTheme.spacingLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.mood, color: LunaTheme.accentPurple),
                    const SizedBox(width: LunaTheme.spacingSm),
                    Text(
                      'How are you feeling?',
                      style: LunaTheme.headlineMedium.copyWith(
                        color: LunaTheme.getTextPrimary(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: LunaTheme.spacingLg),

                // Mood grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: LunaTheme.spacingSm,
                    crossAxisSpacing: LunaTheme.spacingSm,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: _moods.length,
                  itemBuilder: (context, index) {
                    final mood = _moods[index];
                    final isSelected = _selectedMood == mood.type;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _selectedMood = mood.type);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? LunaTheme.accentPurple.withOpacity(0.2)
                              : LunaTheme.getSurface(context),
                          borderRadius: BorderRadius.circular(LunaTheme.radiusMd),
                          border: Border.all(
                            color: isSelected
                                ? LunaTheme.accentPurple
                                : LunaTheme.getDivider(context),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(mood.emoji, style: const TextStyle(fontSize: 28)),
                            const SizedBox(height: 4),
                            Text(
                              mood.label,
                              style: LunaTheme.labelSmall.copyWith(
                                color: isSelected
                                    ? LunaTheme.accentPurple
                                    : LunaTheme.getTextSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: LunaTheme.spacingLg),

                // Intensity slider
                Text(
                  'Intensity',
                  style: LunaTheme.titleMedium.copyWith(
                    color: LunaTheme.getTextPrimary(context),
                  ),
                ),
                Slider(
                  value: _intensity.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  activeColor: LunaTheme.accentPurple,
                  label: _getIntensityLabel(_intensity),
                  onChanged: (value) {
                    setState(() => _intensity = value.round());
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Mild', style: LunaTheme.labelSmall.copyWith(
                      color: LunaTheme.getTextTertiary(context),
                    )),
                    Text('Intense', style: LunaTheme.labelSmall.copyWith(
                      color: LunaTheme.getTextTertiary(context),
                    )),
                  ],
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
                    onPressed: _saveMood,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LunaTheme.accentPurple,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(LunaTheme.radiusMd),
                      ),
                    ),
                    child: const Text('Save Mood', style: TextStyle(color: Colors.white)),
                  ),
                ),

                SafeArea(
                  top: false,
                  child: Container(height: LunaTheme.spacingMd),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getIntensityLabel(int value) {
    switch (value) {
      case 1: return 'Very Mild';
      case 2: return 'Mild';
      case 3: return 'Moderate';
      case 4: return 'Strong';
      case 5: return 'Very Intense';
      default: return 'Moderate';
    }
  }
}

class _MoodOption {
  final MoodType type;
  final String emoji;
  final String label;

  const _MoodOption(this.type, this.emoji, this.label);
}
