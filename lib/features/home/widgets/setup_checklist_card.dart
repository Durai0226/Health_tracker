import 'package:flutter/material.dart';

import '../../../core/services/clean_storage_service.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../services/setup_checklist.dart';
import '../../backup/presentation/screens/backup_settings_screen.dart';
import 'emergency_contact_sheet.dart';

/// "2 of 4 set up" on Today, until everything that makes reminders reliable is
/// on. Lists only what is still off, each with a one-tap fix, and renders
/// nothing once the list is complete, was hidden, or hasn't loaded yet.
///
/// Re-checks when the app resumes: the Android fixes happen in system settings,
/// and the user should come back to a card that has ticked itself over.
class SetupChecklistCard extends StatefulWidget {
  const SetupChecklistCard({super.key, this.service});

  /// Injected by tests; the real platform checks otherwise.
  final SetupChecklistService? service;

  /// Preference key for the Hide button.
  static const hiddenKey = 'setup_checklist_hidden';

  @override
  State<SetupChecklistCard> createState() => _SetupChecklistCardState();
}

class _SetupChecklistCardState extends State<SetupChecklistCard>
    with WidgetsBindingObserver {
  late final SetupChecklistService _service =
      widget.service ?? SetupChecklistService();

  SetupChecklist? _list;
  String? _working;
  bool _hidden = false;

  @override
  void initState() {
    super.initState();
    _hidden = CleanStorageService.getAppPreference(
            SetupChecklistCard.hiddenKey, false) ==
        true;
    WidgetsBinding.instance.addObserver(this);
    // Off the first frame, like the nudge: these are platform-channel calls
    // and the card is ambient.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    if (_hidden) return;
    try {
      final list = await _service.check();
      if (mounted) setState(() => _list = list);
    } catch (_) {/* best-effort: no card is better than a broken one */}
  }

  Future<void> _fix(SetupStep step) async {
    if (_working != null) return;
    setState(() => _working = step.id);
    try {
      switch (step.id) {
        // Two steps are screens rather than platform requests, so the card —
        // which has a BuildContext — opens them; the re-check below picks up
        // whatever the user did there.
        case SetupStepId.emergencyContact:
          await EmergencyContactSheet.show(context);
        case SetupStepId.backup:
          await Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const BackupSettingsScreen()));
        default:
          await _service.fix(step.id);
      }
    } catch (_) {/* the re-check below reports the truth */} finally {
      if (mounted) setState(() => _working = null);
    }
    await _refresh();
  }

  Future<void> _hide() async {
    setState(() => _hidden = true);
    await CleanStorageService.setAppPreference(SetupChecklistCard.hiddenKey, true);
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    if (_hidden || list == null || list.complete) return const SizedBox.shrink();

    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text('${list.doneCount} of ${list.total} set up',
                    style: tt.titleSmall?.copyWith(
                        color: ext.textPrimary, fontWeight: FontWeight.w700)),
              ),
              TextButton(
                onPressed: _hide,
                style: TextButton.styleFrom(
                    foregroundColor: ext.textTertiary,
                    visualDensity: VisualDensity.compact),
                child: const Text('Hide'),
              ),
            ]),
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: AppRadius.brSm,
              child: LinearProgressIndicator(
                value: list.doneCount / list.total,
                minHeight: 6,
                color: ext.brand.chart,
                backgroundColor: ext.brand.container,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final step in list.pending)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(step.title,
                              style: tt.bodyMedium?.copyWith(
                                  color: ext.textPrimary,
                                  fontWeight: FontWeight.w600)),
                          Text(step.detail,
                              style: tt.bodySmall?.copyWith(
                                  color: ext.textSecondary, height: 1.35)),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    TextButton(
                      onPressed: _working == null ? () => _fix(step) : null,
                      child: Text(step.fixLabel),
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
