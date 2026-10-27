import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/widgets/app/app_widgets.dart';
import '../models/enhanced_medicine.dart';
import '../models/medicine_log.dart';
import '../services/medicine_storage_service.dart';
import '../widgets/dose_edit_flow.dart';
import '../widgets/dose_log_row.dart';

/// Every dose recorded for one medicine, newest first, grouped by month. Tap one
/// to change what it says.
///
/// The medicine's own page shows the last five; a dose from two months ago that
/// was written down wrong had nowhere to be seen, let alone corrected.
class MedicineHistoryScreen extends StatefulWidget {
  const MedicineHistoryScreen({super.key, required this.medicine});

  final EnhancedMedicine medicine;

  @override
  State<MedicineHistoryScreen> createState() => _MedicineHistoryScreenState();
}

enum _Filter { all, taken, skipped, missed }

class _MedicineHistoryScreenState extends State<MedicineHistoryScreen> {
  List<MedicineLog> _logs = const [];
  bool _loading = true;
  _Filter _filter = _Filter.all;

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    _load();
    // A dose written from anywhere (a notification, the dashboard) shows up here.
    MedicineCleanStorageService.revision.addListener(_onRevision);
  }

  @override
  void dispose() {
    MedicineCleanStorageService.revision.removeListener(_onRevision);
    super.dispose();
  }

  void _onRevision() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    final logs = MedicineCleanStorageService.dedupeByDose(
        await MedicineCleanStorageService.getLogsForMedicine(widget.medicine.id))
      ..sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
    if (!mounted) return;
    setState(() {
      _logs = logs;
      _loading = false;
    });
  }

  bool _matches(MedicineLog l) => switch (_filter) {
        _Filter.all => !l.isPending,
        _Filter.taken => l.countsAsTaken,
        _Filter.skipped => l.isSkipped,
        _Filter.missed => l.isMissed,
      };

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final shown = [for (final l in _logs) if (_matches(l)) l];
    final taken = _logs.where((l) => l.countsAsTaken).length;
    final skipped = _logs.where((l) => l.isSkipped).length;
    final missed = _logs.where((l) => l.isMissed).length;

    // Month headings between the rows, newest month first.
    final children = <Widget>[];
    String? month;
    for (final l in shown) {
      final m = '${_months[l.scheduledTime.month - 1]} ${l.scheduledTime.year}';
      if (m != month) {
        month = m;
        children.add(Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
          child: Text(m, style: tt.labelLarge?.copyWith(color: ext.textSecondary)),
        ));
      }
      children.add(DoseLogRow(
        log: l,
        onTap: () => DoseEditFlow.run(
          context,
          log: l,
          medicine: widget.medicine,
        ),
      ));
    }

    return AccentScope(
      feature: FeatureAccent.medicine,
      child: AppScaffold(
        body: Column(
          children: [
            AppHeader(
              title: widget.medicine.name,
              leading: AppHeader.backButton(context),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                          AppSpacing.sm, AppSpacing.gutter, AppSpacing.xxl),
                      children: [
                        if (_logs.isEmpty)
                          EmptyState(
                            icon: Symbols.history_rounded,
                            title: 'No doses recorded yet',
                            message: 'Each dose you take or skip is listed here.',
                            accent: ext.medicine,
                          )
                        else ...[
                          Text(
                            '${_logs.length} ${_logs.length == 1 ? 'dose' : 'doses'}'
                            ' · $taken taken · $skipped skipped · $missed missed',
                            style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              for (final (f, label) in [
                                (_Filter.all, 'All'),
                                (_Filter.taken, 'Taken'),
                                (_Filter.skipped, 'Skipped'),
                                (_Filter.missed, 'Missed'),
                              ])
                                AppChip(
                                  label: label,
                                  selected: _filter == f,
                                  accent: ext.medicine,
                                  onTap: () => setState(() => _filter = f),
                                ),
                            ],
                          ),
                          ...children,
                          if (shown.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: AppSpacing.xl),
                              child: Text(
                                'No doses match.',
                                style: tt.bodyMedium?.copyWith(color: ext.textTertiary),
                              ),
                            ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
