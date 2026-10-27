import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/widgets/confirmation_bottom_sheet.dart';
import '../services/cycle_privacy.dart';
import '../services/period_service.dart';

/// One screen to keep cycle data private: what is stored and where, private
/// reminder wording, leaving it out of backups, and deleting all of it.
class CyclePrivacyScreen extends StatefulWidget {
  const CyclePrivacyScreen({super.key});

  @override
  State<CyclePrivacyScreen> createState() => _CyclePrivacyScreenState();
}

class _CyclePrivacyScreenState extends State<CyclePrivacyScreen> {
  Future<void> _togglePrivateNotifications(bool on) async {
    await CyclePrivacy.setPrivateNotifications(on);
    if (mounted) setState(() {});
  }

  Future<void> _toggleBackups(bool leaveOut) async {
    await CyclePrivacy.setExcludeFromBackups(leaveOut);
    if (mounted) setState(() {});
  }

  Future<void> _deleteAll() async {
    final confirmed = await ConfirmationBottomSheet.showDelete(
      context: context,
      itemName: 'all cycle data',
      customMessage: 'This permanently removes every day you have logged, your '
          'cycles and your cycle settings from this device. It cannot be '
          'undone. Backups you have already made keep their copy.',
    );
    if (confirmed != true) return;
    try {
      await PeriodService.deleteAllCycleData();
      if (!mounted) return;
      setState(() {});
      context.toastSuccess('Cycle data deleted');
    } catch (_) {
      if (mounted) {
        context.toastError('Could not delete it. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final days = PeriodService.days.length;
    final cycles = PeriodService.getCycles().length;
    final inBackups = !CyclePrivacy.excludeFromBackups;

    return AccentScope(
      feature: FeatureAccent.period,
      child: AppScaffold(
        body: Column(
          children: [
            AppHeader(
              title: 'Cycle privacy',
              leading: AppHeader.backButton(context),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm,
                    AppSpacing.lg, AppSpacing.xxl),
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Symbols.lock_rounded,
                                size: 18, color: ext.mark(ext.period)),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text('What is stored',
                                  style: tt.titleSmall?.copyWith(
                                      color: ext.textPrimary,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          days == 0
                              ? 'Nothing logged.'
                              : '$days logged ${days == 1 ? 'day' : 'days'} '
                                  'and $cycles ${cycles == 1 ? 'cycle' : 'cycles'}, '
                                  'on this device.',
                          style: tt.bodyMedium
                              ?.copyWith(color: ext.textPrimary),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          inBackups
                              ? 'It goes into a backup file or a cloud backup '
                                  'if you make one.'
                              : 'It is left out of backup files and cloud '
                                  'backups.',
                          style: tt.bodyMedium
                              ?.copyWith(color: ext.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SettingsSection(
                    title: 'Reminders',
                    // The explanation lives down here: a row's subtitle is one
                    // line of status, and this wants a sentence or two.
                    footer: 'Private reminders say only "Reminder": nothing '
                        'about cycles, periods or fertility, on the lock '
                        'screen or anywhere else. Reminders that are already '
                        'set are re-set with the new wording straight away.',
                    children: [
                      SettingsTile(
                        icon: Symbols.visibility_off_rounded,
                        title: 'Private reminders',
                        subtitle: CyclePrivacy.privateNotifications
                            ? 'On'
                            : 'Off',
                        accent: ext.period,
                        switchValue: CyclePrivacy.privateNotifications,
                        onSwitchChanged: _togglePrivateNotifications,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SettingsSection(
                    title: 'Backups',
                    footer: 'Backup files and cloud backups skip cycle data. '
                        'Only backups made from now on: a backup you made '
                        'earlier keeps whatever it had.',
                    children: [
                      SettingsTile(
                        icon: Symbols.cloud_off_rounded,
                        title: 'Leave out of backups',
                        subtitle: CyclePrivacy.excludeFromBackups
                            ? 'Left out'
                            : 'Included',
                        accent: ext.period,
                        switchValue: CyclePrivacy.excludeFromBackups,
                        onSwitchChanged: _toggleBackups,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SettingsSection(
                    title: 'Delete',
                    children: [
                      SettingsTile(
                        icon: Symbols.delete_rounded,
                        title: 'Delete all cycle data',
                        subtitle: 'Cannot be undone',
                        accent: ext.error,
                        onTap: days == 0 && cycles == 0 ? null : _deleteAll,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
