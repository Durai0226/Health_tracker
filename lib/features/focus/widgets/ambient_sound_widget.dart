import 'package:flutter/material.dart';
import '../models/ambient_sound.dart';
import '../../../core/constants/app_colors.dart';

class AmbientSoundSelector extends StatelessWidget {
  final AmbientSoundType selectedSound;
  final double volume;
  final ValueChanged<AmbientSoundType> onSoundChanged;
  final ValueChanged<double> onVolumeChanged;

  const AmbientSoundSelector({
    super.key,
    required this.selectedSound,
    required this.volume,
    required this.onSoundChanged,
    required this.onVolumeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final categories = _groupByCategory();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Volume slider
        if (selectedSound != AmbientSoundType.none) ...[
          _buildVolumeSlider(),
          const SizedBox(height: 24),
        ],
        
        // Sound categories
        ...categories.entries.map((entry) => _buildCategory(entry.key, entry.value)),
      ],
    );
  }

  Widget _buildVolumeSlider() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: selectedSound.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.volume_down_rounded,
            color: selectedSound.color,
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: selectedSound.color,
                inactiveTrackColor: selectedSound.color.withOpacity(0.2),
                thumbColor: selectedSound.color,
                overlayColor: selectedSound.color.withOpacity(0.2),
              ),
              child: Slider(
                value: volume,
                onChanged: onVolumeChanged,
              ),
            ),
          ),
          Icon(
            Icons.volume_up_rounded,
            color: selectedSound.color,
          ),
        ],
      ),
    );
  }

  Map<String, List<AmbientSoundType>> _groupByCategory() {
    final Map<String, List<AmbientSoundType>> grouped = {};
    for (final sound in AmbientSoundType.values) {
      grouped.putIfAbsent(sound.category, () => []);
      grouped[sound.category]!.add(sound);
    }
    return grouped;
  }

  Widget _buildCategory(String category, List<AmbientSoundType> sounds) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            category,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: sounds.map((sound) => _buildSoundChip(sound)).toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSoundChip(AmbientSoundType sound) {
    final isSelected = selectedSound == sound;
    
    return GestureDetector(
      onTap: () => onSoundChanged(sound),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? sound.color : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? sound.color : Colors.grey.withOpacity(0.2),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: sound.color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              sound.emoji,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(width: 6),
            Text(
              sound.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AmbientSoundMiniPlayer extends StatelessWidget {
  final AmbientSoundType sound;
  final bool isPlaying;
  final double volume;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  const AmbientSoundMiniPlayer({
    super.key,
    required this.sound,
    required this.isPlaying,
    required this.volume,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (sound == AmbientSoundType.none) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.music_note_rounded, color: Colors.grey, size: 20),
              SizedBox(width: 8),
              Text(
                'Add Sound',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sound.color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: sound.color.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(sound.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(
              sound.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: sound.color,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onToggle,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: sound.color,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SoundCategoryTab extends StatelessWidget {
  final String category;
  final bool isSelected;
  final VoidCallback onTap;

  const SoundCategoryTab({
    super.key,
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          category,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
