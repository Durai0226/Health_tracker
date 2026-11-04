import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/widgets/app/app_widgets.dart';
import '../models/reminder_sounds.dart';

/// Replaces the audio player for a preview, which cannot run headless. Receives
/// the asset path that would have been played.
@visibleForTesting
Future<void> Function(String asset)? soundPreviewForTesting;

/// Ask which bundled sound a reminder should ring with.
///
/// The answer is a record so that "Default" (a null key) is distinguishable from
/// the sheet being dismissed (a null record): the first must clear a stored
/// choice, the second must change nothing.
Future<({String? key})?> chooseReminderSound(
  BuildContext context, {
  required String? current,
  required AccentSwatch accent,
}) =>
    AppBottomSheet.show<({String? key})>(
      context,
      title: 'Reminder sound',
      icon: Symbols.music_note_rounded,
      accent: accent,
      builder: (sheetCtx) => _SoundList(
        current: ReminderSounds.isKnown(current) ? current : null,
        accent: accent,
        onPick: (key) => Navigator.of(sheetCtx).pop((key: key)),
      ),
    );

class _SoundList extends StatefulWidget {
  final String? current;
  final AccentSwatch accent;
  final ValueChanged<String?> onPick;

  const _SoundList({
    required this.current,
    required this.accent,
    required this.onPick,
  });

  @override
  State<_SoundList> createState() => _SoundListState();
}

class _SoundListState extends State<_SoundList> {
  /// Made on first use: building a player is needless work for someone who
  /// only wants to pick, and it needs a platform channel.
  AudioPlayer? _player;
  Timer? _stopTimer;
  String? _playing;

  @override
  void dispose() {
    _stopTimer?.cancel();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _toggle(String key) async {
    if (_playing == key) {
      await _stop();
      return;
    }
    try {
      final asset = ReminderSounds.options[key]!['asset']!;
      setState(() => _playing = key);
      final preview = soundPreviewForTesting;
      if (preview != null) {
        await preview(asset);
      } else {
        final player = _player ??= AudioPlayer();
        await player.stop();
        await player.setAsset(asset);
        await player.setVolume(0.85);
        unawaited(player.play());
      }
      _stopTimer?.cancel();
      _stopTimer = Timer(const Duration(seconds: 4), _stop);
    } catch (e) {
      debugPrint('Sound preview error: $e');
      if (mounted) setState(() => _playing = null);
    }
  }

  Future<void> _stop() async {
    _stopTimer?.cancel();
    try {
      await _player?.stop();
    } catch (e) {
      debugPrint('Sound preview stop failed: $e');
    }
    if (mounted) setState(() => _playing = null);
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final selected = widget.current ?? 'default';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in ReminderSounds.options.entries) ...[
          AppListTile(
            icon: entry.key == selected
                ? Symbols.check_circle_rounded
                : Symbols.music_note_rounded,
            title: entry.value['label']!,
            subtitle: entry.key == 'default'
                ? 'The standard alarm sound'
                : entry.value['category'],
            accent: widget.accent,
            // "Default" stores nothing, so the medicine follows the standard
            // sound again if that ever changes.
            onTap: () => widget.onPick(entry.key == 'default' ? null : entry.key),
            trailing: IconButton(
              onPressed: () => _toggle(entry.key),
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: Icon(
                _playing == entry.key
                    ? Symbols.stop_circle_rounded
                    : Symbols.play_circle_rounded,
                color: ext.mark(widget.accent),
              ),
              tooltip: _playing == entry.key
                  ? 'Stop preview'
                  : 'Preview ${entry.value['label']}',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}
