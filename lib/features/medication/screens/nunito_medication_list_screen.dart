import 'package:flutter/material.dart';
import '../theme/nunito_theme.dart';
import '../widgets/nunito_glass_card.dart';
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

class _NunitoMedicationListScreenState extends State<NunitoMedicationListScreen>
    with SingleTickerProviderStateMixin {
  List<EnhancedMedicine> _medicines = [];
  List<EnhancedMedicine> _filteredMedicines = [];
  bool _isLoading = true;
  int _selectedTab = 0;
  String _searchQuery = '';

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final HapticService _hapticService = HapticService();

  final List<String> _tabs = ['Active', 'Archived', 'All'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadMedicines();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() => _selectedTab = _tabController.index);
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NunitoTheme.radiusMedium),
        ),
        title: Text('Delete ${medicine.name}?', style: NunitoTheme.heading3),
        content: Text(
          'This action cannot be undone.',
          style: NunitoTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: NunitoTheme.error),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? NunitoTheme.backgroundDark : NunitoTheme.backgroundLight,
      appBar: _buildAppBar(isDark),
      body: Column(
        children: [
          _buildSearchBar(isDark),
          _buildTabBar(isDark),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredMedicines.isEmpty
                    ? _buildEmptyState(isDark)
                    : _buildMedicineList(isDark),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAdd,
        backgroundColor: NunitoTheme.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Add', style: NunitoTheme.labelLarge.copyWith(color: Colors.white)),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_rounded,
          color: isDark ? Colors.white : NunitoTheme.textPrimary,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'My Medications',
        style: NunitoTheme.heading2.copyWith(
          color: isDark ? Colors.white : NunitoTheme.textPrimary,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(NunitoTheme.spacingM),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: NunitoTheme.bodyMedium.copyWith(
          color: isDark ? Colors.white : NunitoTheme.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: 'Search medications...',
          hintStyle: NunitoTheme.bodyMedium.copyWith(color: NunitoTheme.textTertiary),
          prefixIcon: Icon(Icons.search_rounded, color: NunitoTheme.textTertiary),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded, color: NunitoTheme.textTertiary),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: isDark ? NunitoTheme.cardDark : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(NunitoTheme.radiusMedium),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: NunitoTheme.spacingM),
      decoration: BoxDecoration(
        color: isDark ? NunitoTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(NunitoTheme.radiusMedium),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: NunitoTheme.primary,
          borderRadius: BorderRadius.circular(NunitoTheme.radiusSmall),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: NunitoTheme.textSecondary,
        labelStyle: NunitoTheme.labelMedium,
        tabs: _tabs.map((t) => Tab(text: t)).toList(),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.medication_rounded,
            size: 64,
            color: NunitoTheme.primary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _selectedTab == 0
                ? 'No active medications'
                : _selectedTab == 1
                    ? 'No archived medications'
                    : 'No medications found',
            style: NunitoTheme.heading3.copyWith(
              color: NunitoTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add a medication',
            style: NunitoTheme.bodyMedium.copyWith(
              color: NunitoTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(NunitoTheme.spacingM),
      itemCount: _filteredMedicines.length,
      itemBuilder: (context, index) {
        final medicine = _filteredMedicines[index];
        return _buildMedicineCard(medicine, isDark);
      },
    );
  }

  Widget _buildMedicineCard(EnhancedMedicine medicine, bool isDark) {
    return Dismissible(
      key: Key(medicine.id),
      background: Container(
        margin: const EdgeInsets.only(bottom: NunitoTheme.spacingS),
        decoration: BoxDecoration(
          color: NunitoTheme.warning,
          borderRadius: BorderRadius.circular(NunitoTheme.radiusMedium),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.archive_rounded, color: Colors.white),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: NunitoTheme.spacingS),
        decoration: BoxDecoration(
          color: NunitoTheme.error,
          borderRadius: BorderRadius.circular(NunitoTheme.radiusMedium),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
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
      child: NunitoAnimatedCard(
        onTap: () => _navigateToDetail(medicine),
        margin: const EdgeInsets.only(bottom: NunitoTheme.spacingS),
        child: Row(
          children: [
            NunitoPillIndicator(
              color: medicine.color,
              shape: medicine.shape,
              size: 48,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          medicine.name,
                          style: NunitoTheme.labelLarge.copyWith(
                            color: isDark ? Colors.white : NunitoTheme.textPrimary,
                          ),
                        ),
                      ),
                      if (medicine.isArchived)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: NunitoTheme.warning.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Archived',
                            style: NunitoTheme.caption.copyWith(color: NunitoTheme.warning),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${medicine.displayDosage} • ${medicine.schedule.frequencyType.displayName}',
                    style: NunitoTheme.bodySmall,
                  ),
                  if (medicine.instructions != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      medicine.instructions!,
                      style: NunitoTheme.caption.copyWith(color: NunitoTheme.primary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: NunitoTheme.textTertiary),
          ],
        ),
      ),
    );
  }
}
