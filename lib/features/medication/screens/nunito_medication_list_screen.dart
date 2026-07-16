import 'package:flutter/material.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../widgets/nunito_pill_visual.dart';
import '../models/enhanced_medicine.dart';
import '../services/medicine_storage_service.dart';
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
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    _hapticService.light();
    setState(() => _selectedTab = index);
    _filterMedicines();
  }

  Future<void> _loadMedicines() async {
    setState(() => _isLoading = true);
    try {
      _medicines = await MedicineCleanStorageService.getAllMedicines();
      _filterMedicines();
    } catch (e) {
      debugPrint('Error loading medicines: $e');
    }
    setState(() => _isLoading = false);
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
    _loadMedicines();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(medicine.isArchived ? 'Medicine restored' : 'Medicine archived'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await MedicineCleanStorageService.saveMedicine(medicine);
              _loadMedicines();
            },
          ),
        ),
      );
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
              icon: Icons.medication_rounded,
              accent: ext.medicine,
              leading: AppIconButton(
                icon: Icons.arrow_back_rounded,
                filled: false,
                accent: ext.medicine,
                onPressed: () => Navigator.pop(context),
              ),
              bottom: Column(
                children: [
                  AppTextField(
                    controller: _searchController,
                    hint: 'Search medications...',
                    prefixIcon: Icons.search_rounded,
                    accent: ext.medicine,
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    suffix: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear_rounded,
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
                      SegmentItem(icon: Icons.medication_rounded, label: 'Active'),
                      SegmentItem(icon: Icons.archive_rounded, label: 'Archived'),
                      SegmentItem(icon: Icons.apps_rounded, label: 'All'),
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
          icon: Icons.add_rounded,
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
      icon: Icons.medication_rounded,
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
        child: Icon(Icons.archive_rounded, color: ext.warning.onContainer),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: ext.error.container,
          borderRadius: AppRadius.brLg,
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(Icons.delete_rounded, color: ext.error.onContainer),
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
                  if (medicine.isLowStock || medicine.isArchived) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        if (medicine.isLowStock)
                          _statusPill(
                            label: medicine.currentStock != null
                                ? 'Low stock · ${medicine.currentStock}'
                                : 'Low stock',
                            icon: Icons.warning_amber_rounded,
                            swatch: ext.warning,
                          ),
                        if (medicine.isArchived)
                          _statusPill(
                            label: 'Archived',
                            icon: Icons.archive_rounded,
                            swatch: ext.info,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.chevron_right_rounded, color: ext.textTertiary),
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
