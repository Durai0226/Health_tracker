import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../models/dependent_profile.dart';
import '../../services/medicine_storage_service.dart';
import 'add_edit_dependent_screen.dart';

class DependentListScreen extends StatefulWidget {
  final bool isSelectionMode;

  const DependentListScreen({super.key, this.isSelectionMode = false});

  @override
  State<DependentListScreen> createState() => _DependentListScreenState();
}

class _DependentListScreenState extends State<DependentListScreen> {
  List<DependentProfile> _dependents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDependents();
  }

  Future<void> _loadDependents() async {
    setState(() => _isLoading = true);
    try {
      final dependents = await MedicineCleanStorageService.getAllDependents();
      if (mounted) {
        setState(() {
          _dependents = dependents;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading dependents: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToAddEdit({DependentProfile? dependent}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditDependentScreen(editDependent: dependent),
      ),
    );

    if (result == true) {
      _loadDependents();
    }
  }

  Future<void> _deleteDependent(DependentProfile dependent) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Profile'),
        content: Text('Are you sure you want to delete ${dependent.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await MedicineCleanStorageService.deleteDependent(dependent.id);
      _loadDependents();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: Text(widget.isSelectionMode ? 'Select Family Member' : 'Family Profiles'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : AppColors.textPrimary,
        actions: [
          if (!widget.isSelectionMode)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              onPressed: () => _navigateToAddEdit(),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _dependents.isEmpty
              ? _buildEmptyState(isDark)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _dependents.length,
                  itemBuilder: (context, index) {
                    final dependent = _dependents[index];
                    return _buildDependentCard(dependent, isDark);
                  },
                ),
      floatingActionButton: widget.isSelectionMode
          ? FloatingActionButton(
              onPressed: () => _navigateToAddEdit(),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 64,
            color: isDark ? Colors.white24 : AppColors.textLight,
          ),
          const SizedBox(height: 16),
          Text(
            'No family profiles yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add family members to track their meds',
            style: TextStyle(
              color: isDark ? Colors.white38 : AppColors.textLight,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _navigateToAddEdit(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Add Profile', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDependentCard(DependentProfile dependent, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border.withOpacity(0.5),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.isSelectionMode
              ? () => Navigator.pop(context, dependent)
              : () => _navigateToAddEdit(dependent: dependent),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      dependent.relationship.icon,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dependent.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              dependent.relationship.displayName,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          if (dependent.displayAge.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              '• ${dependent.displayAge}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white38 : AppColors.textLight,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (!widget.isSelectionMode)
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: isDark ? Colors.white38 : AppColors.textLight,
                    ),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _navigateToAddEdit(dependent: dependent);
                      } else if (value == 'delete') {
                        _deleteDependent(dependent);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded, size: 20),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_rounded, color: AppColors.error, size: 20),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: AppColors.error)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
