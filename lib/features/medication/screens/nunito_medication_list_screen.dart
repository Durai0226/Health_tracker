
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../widgets/nunito_pill_visual.dart';
import '../models/enhanced_medicine.dart';
import '../services/medicine_storage_service.dart';
import '../services/medication_reminder_service.dart';
import '../../../core/services/haptic_service.dart';
import 'nunito_medication_detail_screen.dart';
import 'nunito_add_medication_flow.dart';
import 'refill_overview_screen.dart';
import '../widgets/adherence_export_sheet.dart';

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

  void _openRefills() {
    _hapticService.light();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RefillOverviewScreen()),
    ).then((_) => _loadMedicines(showLoader: false));
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
                // Always here. The Medicine screen only offers its refill
                // overview while something is already flagged, so with
                // everything fine there was no way to look at supply at all.
                AppIconButton(
                  icon: Symbols.inventory_2_rounded,
                  filled: false,
                  accent: ext.medicine,
                  tooltip: 'Refill & supply',
                  onPressed: _openRefills,
                ),
                AppIconButton(
                  icon: Symbols.ios_share_rounded,
                  filled: false,
                  accent: ext.medicine,
                  tooltip: 'Share with your doctor',
                  onPressed: () => AdherenceExportSheet.show(context),
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
