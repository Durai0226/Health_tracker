import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/widgets/app/app_widgets.dart';
import '../../settings/screens/ai_developer_screen.dart';
import 'memories_screen.dart';
import 'ai_privacy_screen.dart';

/// The single home for everything AI. Replaces a cluttered 7-tile settings
/// section with one clear screen: a plain-language "private, on-device, free"
/// explainer, plus Memory and Privacy. Engine choice, online AI, the API key
/// and the model download are advanced/developer controls, hidden behind a
/// "tap the version 7×" gesture (the standard Android progressive-disclosure
/// pattern) so normal users are never confused by internals.
class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  static const String _version = 'v1.0.0';
  static const int _tapsToUnlock = 7;

  int _taps = 0;
  DateTime? _lastTap;

  Future<void> _onVersionTap() async {
    if (AiDeveloperScreen.isUnlocked) return; // already on
    final now = DateTime.now();
    // Reset the run if taps aren't in quick succession.
    if (_lastTap == null ||
        now.difference(_lastTap!) > const Duration(seconds: 2)) {
      _taps = 0;
    }
    _lastTap = now;
    _taps++;

    final remaining = _tapsToUnlock - _taps;
    if (_taps >= _tapsToUnlock) {
      _taps = 0;
      await AiDeveloperScreen.setUnlocked(true);
      if (!mounted) return;
      context.toastSuccess('Developer options unlocked 🛠️');
      setState(() {}); // reveal the Developer row
    } else if (remaining <= 3) {
      context.toastInfo(
          '$remaining ${remaining == 1 ? 'tap' : 'taps'} from developer options');
    }
  }

  List<Widget> _withDividers(AppColorsExt ext, List<Widget> tiles) {
    final out = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      out.add(tiles[i]);
      if (i < tiles.length - 1) {
        out.add(Divider(
            height: 1, indent: 52, endIndent: 8, color: ext.outline));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final accent = ext.focus;
    final tt = Theme.of(context).textTheme;
    final devUnlocked = AiDeveloperScreen.isUnlocked;

    final rows = <Widget>[
      AppListTile(
        icon: Symbols.psychology_rounded,
        iconColor: ext.mark(accent),
        title: 'What it remembers',
        subtitle: 'Things you\'ve asked me to remember · on-device',
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MemoriesScreen())),
      ),
      AppListTile(
        icon: Symbols.shield_rounded,
        iconColor: ext.mark(ext.success),
        title: 'AI & your data',
        subtitle: 'Your data stays on this phone — exactly how',
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AiPrivacyScreen())),
      ),
      if (devUnlocked)
        AppListTile(
          icon: Symbols.code_rounded,
          iconColor: ext.mark(ext.info),
          title: 'Developer options',
          subtitle: 'Advanced · optional on-device model',
          onTap: () async {
            await Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AiDeveloperScreen()));
            if (mounted) setState(() {}); // re-lock may have hidden the row
          },
        ),
    ];

    return AppScaffold(
      safeTop: true,
      body: Column(
        children: [
          AppHeader(
            title: 'AI Assistant',
            accent: accent,
            leading: AppIconButton(
              icon: Symbols.arrow_back_rounded,
              filled: false,
              accent: accent,
              onPressed: () {
                if (Navigator.canPop(context)) Navigator.pop(context);
              },
            ),
            bottom: Container(height: 1, color: ext.outline),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                  AppSpacing.lg, AppSpacing.gutter, AppSpacing.huge),
              children: [
                // Benefit-first explainer (PAIR: benefit → privacy → control).
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AiSeal(size: 40, accent: accent),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text('Your private assistant',
                                style: tt.titleMedium?.copyWith(
                                    color: ext.textPrimary,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Reminders and plain-language answers about your '
                        'medicines, water and sleep — all running on this '
                        'device. No account. Works offline.',
                        style: tt.bodyMedium
                            ?.copyWith(color: ext.textSecondary, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Column(children: _withDividers(ext, rows)),
                ),
                const SizedBox(height: AppSpacing.xl),
                // Reassurance + hidden dev-unlock target (tap version 7×).
                Center(
                  child: Text(
                    'Everything happens on this device.\n'
                    'Your health data never leaves your phone.',
                    textAlign: TextAlign.center,
                    style: tt.bodySmall
                        ?.copyWith(color: ext.textTertiary, height: 1.4),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _onVersionTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm, horizontal: AppSpacing.lg),
                      child: Text('DailyMinder · $_version',
                          style: tt.labelSmall
                              ?.copyWith(color: ext.textTertiary)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
