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
import '../services/vitals_storage_service.dart';
import '../../../core/services/active_profile_service.dart';
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
    await _loadMedicines();

    if (mounted) {
      context.toastSuccess(
        medicine.isArchived ? 'Medicine restored' : 'Medicine archived',
        action: AppToastAction(
          label: 'Undo',
          onPressed: () async {
            await MedicineCleanStorageService.saveMedicine(medicine);
            await _syncReminders(medicine);
            await _loadMedicines();
          },
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
        context.toastInfo('No active medicines to report yet.');
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

  /// One failure message for both exports — plus the log line that tells
  /// whoever gets the bug report which step actually failed. The friendly
  /// toast used to be all there was: the exception was dropped on the floor.
  void _reportError(Object error) {
    debugPrint('Report export failed: $error');
    if (mounted) {
      context.toastError('Could not create the report. Please try again.');
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

  /// Build a clinician-shareable adherence PDF over the last 30 days. Also
  /// folds in the same window's BP/glucose readings (if any were logged) so a
  /// doctor gets adherence, symptoms AND vitals in one document instead of
  /// three separate exports.
  Future<void> _exportAdherenceReport() async {
    _hapticService.medium();
    // Inside the try: reading every medicine's dose log is the step most
    // likely to fail, and while it sat outside, a storage error escaped as an
    // unhandled exception rather than reaching the catch below.
    try {
      final entries = await _buildReportEntries();
      if (entries == null) return;
      final now = DateTime.now();
      final from = now.subtract(const Duration(days: 30));
      final bpReadings = await VitalsStorageService.getBpForRange(from, now);
      final glucoseReadings =
          await VitalsStorageService.getGlucoseForRange(from, now);
      final bytes = await AdherenceReportService.buildPdf(
        entries: entries,
        from: from,
        to: now,
        bpReadings: bpReadings,
        glucoseReadings: glucoseReadings,
        patientName: await _activePatientName(),
      );
      await Printing.sharePdf(bytes: bytes, filename: 'adherence-report.pdf');
    } catch (e) {
      _reportError(e);
    }
  }

  /// The active dependent's name, or null for self — buildPdf's header omits
  /// the "Patient:" line entirely when null, which is the right default for a
  /// single-person household. Without this, two exported reports for two
  /// different dependents were visually indistinguishable except by reading
  /// every row's medicine names, an easy way to hand a doctor the wrong
  /// child's report.
  Future<String?> _activePatientName() async {
    final id = ActiveProfileService().activeDependentId;
    if (id == null) return null;
    try {
      final deps = await MedicineCleanStorageService.getAllDependents();
      return deps.where((d) => d.id == id).firstOrNull?.name;
    } catch (_) {
      return null;
    }
  }

  /// Export the last-30-day dose log as a CSV via the OS share sheet.
  Future<void> _exportCsv() async {
    _hapticService.medium();
    // Inside the try, for the reason given in _exportAdherenceReport.
    try {
      final entries = await _buildReportEntries();
      if (entries == null) return;
      if (entries.isEmpty) {
        if (mounted) {
          context.toastInfo('No doses logged in the last 30 days');
        }
        return;
      }
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
        subject: 'Medicine log (last 30 days)',
      );
    } catch (e) {
      _reportError(e);
    }
  }

  Future<void> _deleteMedicine(EnhancedMedicine medicine) async {
    // Dismissible, as the dialog it replaces was: a swipe-down or a tap on the
    // scrim returns null, which is not `true` and so deletes nothing. The
    // sheet itself is the detail screen's, so the two ways into this ask the
    // same question — see [NunitoMedicationDetailScreen.confirmDelete].
    final confirm =
        await NunitoMedicationDetailScreen.confirmDelete(context, medicine);

    if (confirm == true) {
      _hapticService.error();
      // Cancel notifications before deleting so a removed medicine can't keep
      // firing orphaned reminders.
      await MedicationReminderService().cancelRemindersById(medicine.id);
      await MedicineCleanStorageService.deleteMedicine(medicine.id);
      await _loadMedicines();
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
              title: 'Medicines',
              leading: AppHeader.backButton(context),
              actions: [
                AppIconButton(
                  icon: Symbols.ios_share_rounded,
                  filled: false,
                  accent: ext.medicine,
                  tooltip: 'Share with your doctor',
                  onPressed: _openExportChooser,
                ),
              ],
              bottom: Column(
                children: [
                  AppSearchField(
                    controller: _searchController,
                    hint: 'Search medicines',
                    accent: ext.medicine,
                    onChanged: _onSearchChanged,
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
    // Hosted in a scroller: the Expanded above hands the empty state exactly
    // the height the header leaves over, and at large Dynamic Type the
    // circle + title + message need more than that (bottom overflow at 200%).
    // See [ScrollableFill] — unchanged whenever it fits.
    return ScrollableFill(
      child: EmptyState(
        icon: Symbols.medication_rounded,
        accent: ext.medicine,
        title: _selectedTab == 0
            ? 'No active medicines'
            : _selectedTab == 1
                ? 'No archived medicines'
                : 'No medicines found',
        message: 'Tap the + button to add a medicine.',
      ),
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
      // Await the action, THEN answer. Firing it off and returning false on
      // the same frame sprang the card back to rest while its confirmation
      // sheet was still open, so a delete the user had just confirmed looked
      // like it had failed — the row only vanished a reload later. `false`
      // stays the right answer afterwards: a row that really went away has
      // already been rebuilt out of the list (Dismissible drops the result
      // once it is unmounted), and one that stayed — archiving from the "All"
      // tab, or a cancelled delete — must spring back.
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await _archiveMedicine(medicine);
        } else {
          await _deleteMedicine(medicine);
        }
        return false;
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
          // Flexible + wrapping: the pill sits in a Wrap inside the card's
          // text column, which on a 320pt phone is only ~170pt wide — narrower
          // than "Low stock · 12" renders even at the DEFAULT text size, so an
          // unflexed label overflowed the chip. Letting it take a second line
          // grows the chip instead of slicing the stock count off.
          Flexible(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: swatch.onContainer),
            ),
          ),
        ],
      ),
    );
  }
}
