import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/services/clean_storage_service.dart';
import 'on_device_ai_screen.dart';

/// Hidden developer area, unlocked by tapping the version line 7× on the AI
/// Assistant screen. The cloud/online-AI + API-key concept was removed entirely
/// (the assistant answers from on-device RAG + your data + memory — no key, no
/// account, nothing leaves the device), so the only advanced control left is the
/// optional, experimental on-device model download (Android only).
class AiDeveloperScreen extends StatelessWidget {
  const AiDeveloperScreen({super.key});

  /// Persisted unlock flag (reuses the app's generic preference store, the same
  /// mechanism as `isFirstLaunch`). Read synchronously from the loaded cache.
  static const String prefKey = 'developerModeUnlocked';
  static bool get isUnlocked =>
      CleanStorageService.getAppPreference(prefKey, false) == true;
  static Future<void> setUnlocked(bool value) =>
      CleanStorageService.setAppPreference(prefKey, value);

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final accent = ext.info;
    final tt = Theme.of(context).textTheme;

    Future<void> lock() async {
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      await AiDeveloperScreen.setUnlocked(false);
      messenger.showSnackBar(
          const SnackBar(content: Text('Developer options locked')));
      navigator.pop();
    }

    return AppScaffold(
      safeTop: true,
      body: Column(
        children: [
          AppHeader(
            title: 'Developer options',
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
                AppCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Symbols.info_rounded,
                          size: 20, color: ext.mark(ext.info)),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Experimental options most people don\'t need. The '
                          'assistant already answers privately on-device — this '
                          'just adds an optional offline model (Android only).',
                          style: tt.bodyMedium?.copyWith(
                              color: ext.textSecondary, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: AppListTile(
                    icon: Symbols.memory_rounded,
                    iconColor: ext.mark(ext.info),
                    title: 'On-device model',
                    subtitle: 'Optional offline model · Android · experimental',
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const OnDeviceAiScreen())),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Lock developer options',
                  variant: AppButtonVariant.ghost,
                  accent: ext.error,
                  fullWidth: true,
                  onPressed: lock,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
