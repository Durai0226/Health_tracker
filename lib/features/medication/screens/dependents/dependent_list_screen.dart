import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../../core/services/active_profile_service.dart';
import '../../../../core/widgets/app/app_widgets.dart';
import '../../models/dependent_profile.dart';
import '../../services/medicine_storage_service.dart';
import 'add_edit_dependent_screen.dart';

/// Manage household members ("Family & caregivers" in Settings), or — when
/// [isSelectionMode] is true — pick which one is currently active (the Today
/// header's profile switcher pushes this and awaits the tapped profile).
/// Either way the list always marks whichever profile
/// [ActiveProfileService] currently has selected.
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
      // Self first, then alphabetical — self is always the anchor profile.
      dependents.sort((a, b) {
        if (a.isSelf != b.isSelf) return a.isSelf ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
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
    final ext = AppColorsExt.of(context);
    final confirm = await AppBottomSheet.confirm(
      context,
      title: 'Delete ${dependent.name}?',
      message:
          'This removes their profile. Their medicines and history stay on '
          'device but will no longer be attributed to them.',
      confirmLabel: 'Delete',
      danger: true,
      icon: Symbols.delete_rounded,
    );
    if (confirm != true) return;

    await MedicineCleanStorageService.deleteDependent(dependent.id);
    // A deleted profile can't stay "active" — fall back to self so nothing
    // points at a dangling id.
    if (ActiveProfileService().activeDependentId == dependent.id) {
      await ActiveProfileService().setActiveDependent(null);
    }
    _loadDependents();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ext.surfaceElevated,
          content: Text('${dependent.name} removed',
              style: TextStyle(color: ext.textPrimary)),
        ),
      );
    }
  }

  Future<void> _selectActive(DependentProfile dependent) async {
    if (widget.isSelectionMode) {
      Navigator.pop(context, dependent);
      return;
    }
    await ActiveProfileService().setActiveDependent(
        dependent.isSelf ? null : dependent.id);
    if (mounted) setState(() {}); // refresh the "current" badge
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final med = ext.medicine;

    return AccentScope(
      feature: FeatureAccent.medicine,
      child: AppScaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppHeader(
              title: widget.isSelectionMode
                  ? 'Switch profile'
                  : 'Family & caregivers',
              icon: Symbols.group_rounded,
              accent: med,
              leading: IconButton(
                icon: Icon(Symbols.arrow_back_rounded, color: ext.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
              // Always offered, even while switching — someone realizing they
              // need to add a new family member shouldn't have to back out
              // to Settings first to find the add flow.
              actions: [
                AppIconButton(
                  icon: Symbols.person_add_rounded,
                  accent: med,
                  tooltip: 'Add family member',
                  onPressed: () => _navigateToAddEdit(),
                ),
              ],
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListenableBuilder(
                      listenable: ActiveProfileService(),
                      builder: (context, _) => ListView.builder(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                            AppSpacing.sm, AppSpacing.gutter, AppSpacing.xxl),
                        itemCount: _dependents.length,
                        itemBuilder: (context, index) =>
                            _buildDependentCard(ext, med, _dependents[index]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDependentCard(
      AppColorsExt ext, AccentSwatch med, DependentProfile dependent) {
    final isActive = dependent.isSelf
        ? ActiveProfileService().isSelfActive
        : ActiveProfileService().activeDependentId == dependent.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: () => widget.isSelectionMode
            ? _selectActive(dependent)
            : _navigateToAddEdit(dependent: dependent),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: med.container, shape: BoxShape.circle),
              child: Center(
                child: Text(dependent.relationship.icon,
                    style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(dependent.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: ext.textPrimary),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (isActive) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Icon(Symbols.check_circle_rounded, size: 18, color: med.strong),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      AppChip(
                        label: dependent.relationship.displayName,
                        accent: med,
                      ),
                      if (dependent.displayAge.isNotEmpty) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Text('· ${dependent.displayAge}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: ext.textTertiary)),
                      ],
                    ],
                  ),
                  // A caregiver scanning this list (e.g. before giving an OTC
                  // medicine outside the app's own add-medicine flow, where
                  // the allergy check runs) previously had no way to see
                  // recorded allergies without opening the edit form and
                  // reading the raw comma-separated field.
                  if (dependent.allergies != null &&
                      dependent.allergies!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Symbols.warning_rounded,
                            size: 14, color: ext.warning.strong),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Allergies: ${dependent.allergies!.join(', ')}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: ext.warning.strong),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (!widget.isSelectionMode)
              PopupMenuButton<String>(
                icon: Icon(Symbols.more_vert_rounded, color: ext.textTertiary),
                onSelected: (value) {
                  if (value == 'edit') {
                    _navigateToAddEdit(dependent: dependent);
                  } else if (value == 'delete') {
                    _deleteDependent(dependent);
                  } else if (value == 'switch') {
                    _selectActive(dependent);
                  }
                },
                itemBuilder: (context) => [
                  if (!isActive)
                    const PopupMenuItem(
                      value: 'switch',
                      child: Row(children: [
                        Icon(Symbols.swap_horiz_rounded, size: 20),
                        SizedBox(width: 8),
                        Text('Switch to this profile'),
                      ]),
                    ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Symbols.edit_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ]),
                  ),
                  // Deleting "self" would remove the switcher's anchor entry
                  // for no benefit — self can't be reassigned to anyone else.
                  if (!dependent.isSelf)
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Symbols.delete_rounded, size: 20, color: ext.error.base),
                        const SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: ext.error.base)),
                      ]),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
