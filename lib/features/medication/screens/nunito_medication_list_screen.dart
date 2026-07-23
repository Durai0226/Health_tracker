import 'dart:io';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../widgets/nunito_pill_visual.dart';
import '../models/enhanced_medicine.dart';
import '../services/medicine_storage_service.dart';
import '../services/medication_reminder_service.dart';
import '../services/adherence_report_service.dart';
import '../../../core/services/haptic_service.dart';
import 'nunito_medication_detail_screen.dart';
import 'nunito_add_medication_flow.dart';

class NunitoMedicationListScreen extends StatefulWidget {
  const NunitoMedicationListScreen({super.key});

  @override
  State<NunitoMedicationListScreen> createState() => _NunitoMedicationListScreenState();
}

class _NunitoMedicationListScreenState extends State<NunitoMedicationListScreen> {
  List<EnhancedMedicine> _medicines = [];
  List<EnhancedMedicine> _filteredMedicines = [];
  bool _isLoading = true;
  int _selectedTab = 0;
  String _searchQuery = '';

  final TextEditingController _searchController = TextEditingController();
  final HapticService _hapticService = HapticService();

  @override
  void initState() {
    super.initState();
    _loadMedicines();
    // Live refresh when a medicine/dose changes anywhere (detail edit, delete,
    // dose taken) — keeps this list in sync without relying on pop callbacks.
    MedicineCleanStorageService.revision.addListener(_onMedicineRevision);
  }

  void _onMedicineRevision() {
    if (mounted) _loadMedicines(showLoader: false);
  }

  @override
  void dispose() {
    MedicineCleanStorageService.revision.removeListener(_onMedicineRevision);
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    _hapticService.light();
    setState(() => _selectedTab = index);
    _filterMedicines();
  }

  Future<void> _loadMedicines({bool showLoader = true}) async {
    if (showLoader) setState(() => _isLoading = true);
    try {
      _medicines = await MedicineCleanStorageService.getAllMedicines();
      _filterMedicines();
    } catch (e) {
      debugPrint('Error loading medicines: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _filterMedicines() {
    List<EnhancedMedicine> filtered;

    switch (_selectedTab) {
      case 0: // Active
        filtered = _medicines.where((m) => m.isActive && !m.isArchived).toList();
        break;
      case 1: // Archived
        filtered = _medicines.where((m) => m.isArchived).toList();
        break;
      default: // All
        filtered = List.from(_medicines);
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((m) =>
        m.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (m.genericName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
      ).toList();
    }

    setState(() => _filteredMedicines = filtered);
  }

  void _onSearchChanged(String query) {
    _searchQuery = query;
    _filterMedicines();
  }

  void _navigateToDetail(EnhancedMedicine medicine) {
    _hapticService.light();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NunitoMedicationDetailScreen(medicine: medicine),
      ),
    ).then((_) => _loadMedicines());
  }

  void _navigateToAdd() {
    _hapticService.light();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NunitoAddMedicationFlow()),
    ).then((result) {
      if (result == true) _loadMedicines();
    });
  }

  Future<void> _archiveMedicine(EnhancedMedicine medicine) async {
    _hapticService.warning();
    final updated = medicine.copyWith(isArchived: !medicine.isArchived);
    await MedicineCleanStorageService.saveMedicine(updated);
    // Reconcile notifications: an archived medicine must stop firing reminders;
    // a restored one gets them back. (Scheduling itself no-ops for archived.)
    await _syncReminders(updated);
    _loadMedicines();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(medicine.isArchived ? 'Medicine restored' : 'Medicine archived'),
          // SnackBar.persist defaults to `action != null`, which would pin this
          // toast open forever; force auto-dismiss while keeping Undo.
          persist: false,
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await MedicineCleanStorageService.saveMedicine(medicine);
              await _syncReminders(medicine);
              _loadMedicines();
            },
          ),
        ),
      );
    }
  }

  /// Cancel or (re)schedule a medicine's reminders to match its archived state.
  Future<void> _syncReminders(EnhancedMedicine medicine) async {
    final service = MedicationReminderService();
    if (medicine.isArchived) {
      await service.cancelReminders(medicine);
    } else {
      await service.scheduleReminders(medicine);
    }
  }

  Future<List<MedicineReportEntry>?> _buildReportEntries() async {
    final active = _medicines.where((m) => m.isActive && !m.isArchived).toList();
    if (active.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active medications to report yet.')),
        );
      }
      return null;
    }
    final entries = <MedicineReportEntry>[];
    for (final m in active) {
      final logs = await MedicineCleanStorageService.getLogsForMedicine(m.id);
      entries.add(MedicineReportEntry(medicine: m, logs: logs));
    }
    return entries;
  }

  void _reportError() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create the report. Please try again.')),
      );
    }
  }

  /// Let the user share their last-30-day record with a doctor/caregiver as a
  /// polished PDF or a spreadsheet CSV. Strictly local — the OS share sheet
  /// decides where it goes; nothing is uploaded by the app.
  void _openExportChooser() {
    _hapticService.light();
    final ext = AppColorsExt.of(context);
    AppBottomSheet.show<void>(
      context,
      title: 'Share with your doctor',
      icon: Symbols.ios_share_rounded,
      accent: ext.medicine,
      builder: (sheetCtx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppListTile(
            icon: Symbols.picture_as_pdf_rounded,
            title: 'Adherence report (PDF)',
            subtitle: 'A clean summary for a doctor visit',
            accent: ext.medicine,
            onTap: () {
              Navigator.of(sheetCtx).pop();
              _exportAdherenceReport();
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          AppListTile(
            icon: Symbols.table_rows_rounded,
            title: 'Dose log (CSV)',
            subtitle: 'Every dose as a spreadsheet',
            accent: ext.medicine,
            onTap: () {
              Navigator.of(sheetCtx).pop();
              _exportCsv();
            },
          ),
        ],
      ),
    );
  }

  /// Build a clinician-shareable adherence PDF over the last 30 days.
  Future<void> _exportAdherenceReport() async {
    _hapticService.medium();
    final entries = await _buildReportEntries();
    if (entries == null) return;
    try {
      final now = DateTime.now();
      final bytes = await AdherenceReportService.buildPdf(
        entries: entries,
        from: now.subtract(const Duration(days: 30)),
        to: now,
      );
      await Printing.sharePdf(bytes: bytes, filename: 'adherence-report.pdf');
    } catch (e) {
      _reportError();
    }
  }

  /// Export the last-30-day dose log as a CSV via the OS share sheet.
  Future<void> _exportCsv() async {
    _hapticService.medium();
    final entries = await _buildReportEntries();
    if (entries == null) return;
    if (entries.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No doses logged in the last 30 days')),
        );
      }
      return;
    }
    try {
      final now = DateTime.now();
      final csv = AdherenceReportService.buildCsv(
        entries: entries,
        from: now.subtract(const Duration(days: 30)),
        to: now,
      );
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/medication-log.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Medication log (last 30 days)',
      );
    } catch (e) {
      _reportError();
    }
  }

  Future<void> _deleteMedicine(EnhancedMedicine medicine) async {
    final ext = AppColorsExt.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ext.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brLg),
        title: Text('Delete ${medicine.name}?',
            style: Theme.of(context).textTheme.headlineSmall),
        content: Text(
          'This action cannot be undone.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: ext.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: ext.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: ext.error.strong),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _hapticService.error();
      // Cancel notifications before deleting so a removed medicine can't keep
      // firing orphaned reminders.
      await MedicationReminderService().cancelRemindersById(medicine.id);
      await MedicineCleanStorageService.deleteMedicine(medicine.id);
      _loadMedicines();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);

    return AccentScope(
      feature: FeatureAccent.medicine,
      child: AppScaffold(
        body: Column(
          children: [
            AppHeader(
              title: 'Medications',
              icon: Symbols.medication_rounded,
              accent: ext.medicine,
              leading: AppIconButton(
                icon: Symbols.arrow_back_rounded,
                filled: false,
                accent: ext.medicine,
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                AppIconButton(
                  icon: Symbols.ios_share_rounded,
                  filled: false,
                  accent: ext.medicine,
                  onPressed: _openExportChooser,
                ),
              ],
              bottom: Column(
                children: [
                  AppTextField(
                    controller: _searchController,
                    hint: 'Search medications...',
                    prefixIcon: Symbols.search_rounded,
                    accent: ext.medicine,
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    suffix: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Symbols.clear_rounded,
                                color: ext.textTertiary),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SegmentedToggle(
                    index: _selectedTab,
                    onChanged: _onTabChanged,
                    accent: ext.medicine,
                    items: const [
                      SegmentItem(icon: Symbols.medication_rounded, label: 'Active'),
                      SegmentItem(icon: Symbols.archive_rounded, label: 'Archived'),
                      SegmentItem(icon: Symbols.apps_rounded, label: 'All'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredMedicines.isEmpty
                      ? _buildEmptyState()
                      : _buildMedicineList(),
            ),
          ],
        ),
        floatingActionButton: AppFab(
          icon: Symbols.add_rounded,
          label: 'Add',
          accent: ext.medicine,
          onPressed: _navigateToAdd,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final ext = AppColorsExt.of(context);
    return EmptyState(
      icon: Symbols.medication_rounded,
      accent: ext.medicine,
      title: _selectedTab == 0
          ? 'No active medications'
          : _selectedTab == 1
              ? 'No archived medications'
              : 'No medications found',
      message: 'Tap the + button to add a medication.',
    );
  }

  Widget _buildMedicineList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter, AppSpacing.md, AppSpacing.gutter, 96),
      itemCount: _filteredMedicines.length,
      itemBuilder: (context, index) {
        final medicine = _filteredMedicines[index];
        return _buildMedicineCard(medicine);
      },
    );
  }

  Widget _buildMedicineCard(EnhancedMedicine medicine) {
    final ext = AppColorsExt.of(context);
    return Dismissible(
      key: Key(medicine.id),
      background: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: ext.warning.container,
          borderRadius: AppRadius.brLg,
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        child: Icon(Symbols.archive_rounded, color: ext.warning.onContainer),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: ext.error.container,
          borderRadius: AppRadius.brLg,
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(Symbols.delete_rounded, color: ext.error.onContainer),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          _archiveMedicine(medicine);
          return false;
        } else {
          _deleteMedicine(medicine);
          return false;
        }
      },
      child: AppCard(
        onTap: () => _navigateToDetail(medicine),
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            NunitoPillIndicator(
              color: medicine.color,
              shape: medicine.shape,
              size: 48,
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medicine.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: ext.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${medicine.displayDosage} • ${medicine.schedule.frequencyType.displayName}',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: ext.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (medicine.instructions != null &&
                      medicine.instructions!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      medicine.instructions!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: ext.mark(ext.medicine)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  // Only warn on low stock when stock is actually being tracked.
                  // Untracked meds persist as currentStock 0 (NOT NULL column),
                  // which previously showed a false "Low stock · 0" on every one.
                  if ((medicine.isLowStock && (medicine.currentStock ?? 0) > 0) ||
                      medicine.isArchived) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        if (medicine.isLowStock && (medicine.currentStock ?? 0) > 0)
                          _statusPill(
                            label: 'Low stock · ${medicine.currentStock}',
                            icon: Symbols.warning_amber_rounded,
                            swatch: ext.warning,
                          ),
                        if (medicine.isArchived)
                          _statusPill(
                            label: 'Archived',
                            icon: Symbols.archive_rounded,
                            swatch: ext.info,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(Symbols.chevron_right_rounded, color: ext.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _statusPill({
    required String label,
    required IconData icon,
    required AccentSwatch swatch,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: swatch.container,
        borderRadius: AppRadius.brSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: swatch.onContainer),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: swatch.onContainer),
          ),
        ],
      ),
    );
  }
}
