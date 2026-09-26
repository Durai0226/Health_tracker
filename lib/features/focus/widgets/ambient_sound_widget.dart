import 'package:flutter/material.dart';
import '../../../core/design/app_design.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/services/audio_service.dart';
import '../models/ambient_sound.dart';

class AmbientSoundSelector extends StatelessWidget {
  final AmbientSoundType selectedSound;
  final double volume;
  final ValueChanged<AmbientSoundType> onSoundChanged;
  final ValueChanged<double> onVolumeChanged;

  /// Called once when the thumb is released, for the caller to PERSIST.
  ///
  /// Separate from [onVolumeChanged] because the two have different costs:
  /// [onVolumeChanged] fires every drag frame and should only move the audio
  /// volume, while this fires once and is where a write belongs. Optional so the
  /// widget still works with one callback; falls back to [onVolumeChanged].
  final ValueChanged<double>? onVolumeCommitted;

  const AmbientSoundSelector({
    super.key,
    required this.selectedSound,
    required this.volume,
    required this.onSoundChanged,
    required this.onVolumeChanged,
    this.onVolumeCommitted,
  });

  @override
  Widget build(BuildContext context) {
    final categories = _groupByCategory();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Volume slider
        if (selectedSound != AmbientSoundType.none) ...[
          _buildVolumeSlider(context),
          const SizedBox(height: AppSpacing.xl),
        ],
        
        // Sound categories
        ...categories.entries.map((entry) => _buildCategory(context, entry.key, entry.value)),
      ],
    );
  }

  Widget _buildVolumeSlider(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final mark = ext.mark(ext.focus);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: selectedSound.color.withOpacity(0.1),
        borderRadius: AppRadius.brLg,
      ),
      child: Row(
        children: [
          Icon(Symbols.volume_down_rounded, color: mark),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: mark,
                inactiveTrackColor: mark.withOpacity(0.2),
                thumbColor: mark,
                overlayColor: mark.withOpacity(0.2),
              ),
              child: Slider(
                value: volume,
                // Live feedback while dragging: audio volume follows the thumb.
                onChanged: onVolumeChanged,
                // …but the PERSIST happens once, on release. `onChanged` alone
                // meant every drag frame ran a Drift write; the service now
                // writes a single key, and this makes it a single write.
                onChangeEnd: onVolumeCommitted ?? onVolumeChanged,
              ),
            ),
          ),
          Icon(Symbols.volume_up_rounded, color: mark),
        ],
      ),
    );
  }

  /// Only the sounds that actually play, grouped by category.
  ///
  /// This used to walk `AmbientSoundType.values` unfiltered, so the picker
  /// offered fifteen chips while three files existed: tapping twelve of them set
  /// `AudioService.lastError` and played silence, with the session running on as
  /// if nothing were wrong. A category that ends up empty is dropped rather than
  /// rendered as a header over nothing.
  ///
  /// As each wave of CC0 audio lands (see `docs/audio-sourcing.md`), its chips
  /// reappear here with no change to this file.
  Map<String, List<AmbientSoundType>> _groupByCategory() {
    final Map<String, List<AmbientSoundType>> grouped = {};
    for (final sound in AmbientSoundType.values) {
      if (!AudioService.hasAmbientAudio(sound)) continue;
      grouped.putIfAbsent(sound.category, () => []);
      grouped[sound.category]!.add(sound);
    }
    return grouped;
  }

  Widget _buildCategory(BuildContext context, String category, List<AmbientSoundType> sounds) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
              left: AppSpacing.xs, bottom: AppSpacing.md),
          child: Text(
            category,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColorsExt.of(context).textSecondary,
                ),
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: sounds.map((sound) => _buildSoundChip(context, sound)).toList(),
        ),
        const SizedBox(height: AppSpacing.gutter),
      ],
    );
  }

  Widget _buildSoundChip(BuildContext context, AmbientSoundType sound) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final isSelected = selectedSound == sound;

    return GestureDetector(
      onTap: () => onSoundChanged(sound),
      child: AnimatedContainer(
        duration: AppMotion.base,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          // Selected used to fill with `sound.color` and put white on it, which
          // for the green/amber/cyan soundscapes measures 2.2–2.6:1. The Focus
          // fill pair is 5.70:1 light / 5.60:1 dark; the sound still reads by
          // its own glyph.
          color: isSelected ? ext.fillBg(ext.focus) : ext.surface,
          borderRadius: AppRadius.brLg,
          border: Border.all(
            color: isSelected ? ext.fillBg(ext.focus) : ext.outline,
          ),
          boxShadow: isSelected ? AppShadows.resting(context) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // emoji-content-ok: one glyph per soundscape, from the catalogue
            Text(sound.emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text(
              sound.name,
              style: tt.labelLarge?.copyWith(
                color: isSelected ? ext.fillFg(ext.focus) : ext.textPrimary,
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
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    if (sound == AmbientSoundType.none) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: 10),
          decoration: BoxDecoration(
            color: ext.surfaceVariant,
            borderRadius: AppRadius.brCard,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Symbols.music_note_rounded,
                  color: ext.textSecondary, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Add Sound',
                style: tt.labelLarge?.copyWith(color: ext.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: sound.color.withOpacity(0.15),
          borderRadius: AppRadius.brCard,
          border: Border.all(color: sound.color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // emoji-content-ok: the soundscape's own glyph
            Text(sound.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: AppSpacing.sm),
            Text(
              sound.name,
              style: tt.labelLarge?.copyWith(color: ext.textPrimary),
            ),
            const SizedBox(width: AppSpacing.sm),
            Semantics(
              button: true,
              label: isPlaying ? 'Pause ambient sound' : 'Play ambient sound',
              child: GestureDetector(
                onTap: onToggle,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: ext.fillBg(ext.focus),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? Symbols.pause_rounded : Symbols.play_arrow_rounded,
                    color: ext.fillFg(ext.focus),
                    size: 16,
                  ),
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
        duration: AppMotion.base,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColorsExt.of(context).fillBg(AppColorsExt.of(context).focus)
              : Colors.transparent,
          borderRadius: AppRadius.brCard,
        ),
        child: Text(
          category,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: isSelected
                    ? AppColorsExt.of(context)
                        .fillFg(AppColorsExt.of(context).focus)
                    : AppColorsExt.of(context).textSecondary,
              ),
        ),
      ),
    );
  }
}
