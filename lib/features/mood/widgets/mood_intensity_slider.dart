import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/mood_theme.dart';
import '../models/mood_type.dart';

/// Custom intensity slider for mood entry
class MoodIntensitySlider extends StatefulWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final MoodType? mood;

  const MoodIntensitySlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.mood,
  });

  @override
  State<MoodIntensitySlider> createState() => _MoodIntensitySliderState();
}

class _MoodIntensitySliderState extends State<MoodIntensitySlider> {
  late int _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value;
  }

  @override
  void didUpdateWidget(MoodIntensitySlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _currentValue = widget.value;
    }
  }

  Color get _activeColor {
    if (widget.mood != null) {
      return MoodTheme.getMoodColor(widget.mood!.value);
    }
    return MoodTheme.primary;
  }

  String get _intensityLabel {
    switch (_currentValue) {
      case 1:
        return 'Very Low';
      case 2:
        return 'Low';
      case 3:
        return 'Moderate';
      case 4:
        return 'High';
      case 5:
        return 'Very High';
      default:
        return 'Moderate';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Intensity',
              style: MoodTheme.titleMd.copyWith(
                color: MoodTheme.textPrimary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: _activeColor.withOpacity(0.15),
                borderRadius: MoodTheme.borderRadiusRound,
              ),
              child: Text(
                _intensityLabel,
                style: MoodTheme.titleSm.copyWith(
                  color: _activeColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: MoodTheme.spacingMd),
        
        // Intensity circles
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(5, (index) {
            final value = index + 1;
            final isSelected = value <= _currentValue;
            final isActive = value == _currentValue;
            
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _currentValue = value);
                widget.onChanged(value);
              },
              child: AnimatedContainer(
                duration: MoodTheme.animationFast,
                width: isActive ? 52 : 44,
                height: isActive ? 52 : 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? _activeColor.withOpacity(isActive ? 1.0 : 0.3)
                      : MoodTheme.backgroundSecondary,
                  border: Border.all(
                    color: isSelected
                        ? _activeColor
                        : MoodTheme.textMuted.withOpacity(0.3),
                    width: isActive ? 3 : 2,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: _activeColor.withOpacity(0.4),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    '$value',
                    style: MoodTheme.titleMd.copyWith(
                      color: isSelected
                          ? (isActive ? Colors.white : _activeColor)
                          : MoodTheme.textMuted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        
        // Labels
        const SizedBox(height: MoodTheme.spacingSm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Low',
              style: MoodTheme.caption.copyWith(
                color: MoodTheme.textMuted,
              ),
            ),
            Text(
              'High',
              style: MoodTheme.caption.copyWith(
                color: MoodTheme.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Alternative: Modern slider version
class MoodIntensityModernSlider extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final MoodType? mood;

  const MoodIntensityModernSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.mood,
  });

  Color get _activeColor {
    if (mood != null) {
      return MoodTheme.getMoodColor(mood!.value);
    }
    return MoodTheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Intensity',
              style: MoodTheme.titleMd,
            ),
            Text(
              '$value/5',
              style: MoodTheme.titleLg.copyWith(
                color: _activeColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: MoodTheme.spacingMd),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: _activeColor,
            inactiveTrackColor: _activeColor.withOpacity(0.2),
            thumbColor: _activeColor,
            overlayColor: _activeColor.withOpacity(0.2),
            trackHeight: 8,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 14,
              elevation: 4,
            ),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
          ),
          child: Slider(
            value: value.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onChanged(v.round());
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('Mild', style: TextStyle(color: MoodTheme.textMuted, fontSize: 12)),
            Text('Intense', style: TextStyle(color: MoodTheme.textMuted, fontSize: 12)),
          ],
        ),
      ],
    );
  }
}
