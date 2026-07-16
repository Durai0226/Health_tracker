import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/widgets/app/app_widgets.dart';
import '../../models/clinic.dart';
import '../../services/medicine_storage_service.dart';
import '../../../../core/services/haptic_service.dart';
import 'nunito_add_edit_clinic_screen.dart';

class NunitoClinicListScreen extends StatefulWidget {
  final bool isSelectionMode;

  const NunitoClinicListScreen({super.key, this.isSelectionMode = false});

  @override
  State<NunitoClinicListScreen> createState() => _NunitoClinicListScreenState();
}

class _NunitoClinicListScreenState extends State<NunitoClinicListScreen> {
  List<Clinic> _clinics = [];
  bool _isLoading = true;

  final HapticService _hapticService = HapticService();

  @override
  void initState() {
    super.initState();
    _loadClinics();
  }

  Future<void> _loadClinics() async {
    setState(() => _isLoading = true);
    try {
      final clinics = await MedicineCleanStorageService.getAllClinics();
      if (mounted) {
        setState(() {
          _clinics = clinics;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading clinics: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToAddEdit({Clinic? clinic}) async {
    _hapticService.light();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NunitoAddEditClinicScreen(editClinic: clinic),
      ),
    );

    if (result == true) {
      _loadClinics();
    }
  }

  void _selectClinic(Clinic clinic) {
    if (widget.isSelectionMode) {
      Navigator.pop(context, clinic);
    } else {
      _navigateToAddEdit(clinic: clinic);
    }
  }

  Future<void> _callClinic(Clinic clinic) async {
    if (clinic.phone == null || clinic.phone!.isEmpty) return;

    final uri = Uri.parse('tel:${clinic.phone}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openMap(Clinic clinic) async {
    if (!clinic.hasLocation) return;

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${clinic.latitude},${clinic.longitude}'
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _deleteClinic(Clinic clinic) async {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ext.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brCard),
        title: Text('Delete Clinic',
            style: tt.headlineSmall?.copyWith(color: ext.textPrimary)),
        content: Text('Are you sure you want to delete ${clinic.name}?',
            style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: tt.labelLarge?.copyWith(color: ext.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: ext.mark(ext.error)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _hapticService.error();
      await MedicineCleanStorageService.deleteClinic(clinic.id);
      _loadClinics();
    }
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
              title: widget.isSelectionMode ? 'Select Clinic' : 'Clinics',
              icon: Icons.local_hospital_rounded,
              accent: med,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: ext.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: ext.mark(med)))
                  : _clinics.isEmpty
                      ? EmptyState(
                          icon: Icons.local_hospital_rounded,
                          title: 'No clinics added',
                          message: 'Add clinics and hospitals you visit',
                          accent: med,
                        )
                      : _buildClinicList(ext, med),
            ),
          ],
        ),
        floatingActionButton: AppFab(
          icon: Icons.add_rounded,
          label: 'Add Clinic',
          accent: med,
          onPressed: () => _navigateToAddEdit(),
        ),
      ),
    );
  }

  Widget _buildClinicList(AppColorsExt ext, AccentSwatch med) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, AppSpacing.xxl * 2),
      itemCount: _clinics.length,
      itemBuilder: (context, index) {
        final clinic = _clinics[index];
        return _buildClinicCard(clinic, ext, med);
      },
    );
  }

  Widget _buildClinicCard(Clinic clinic, AppColorsExt ext, AccentSwatch med) {
    final tt = Theme.of(context).textTheme;
    final isOpen = clinic.operatingHours?.isOpenNow ?? false;
    final statusSwatch = isOpen ? ext.success : ext.error;

    return Dismissible(
      key: Key(clinic.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: ext.error.base,
          borderRadius: AppRadius.brCard,
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete_rounded, color: ext.error.on),
      ),
      confirmDismiss: (direction) async {
        _deleteClinic(clinic);
        return false;
      },
      child: AppCard(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        onTap: () => _selectClinic(clinic),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: med.container,
                    borderRadius: AppRadius.brMd,
                  ),
                  child: Icon(
                    _getClinicIcon(clinic.type),
                    color: med.onContainer,
                    size: 28,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clinic.name,
                        style: tt.titleLarge?.copyWith(color: ext.textPrimary),
                      ),
                      if (clinic.type != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          clinic.displayType,
                          style: tt.bodyMedium?.copyWith(color: ext.mark(med)),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusSwatch.base,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isOpen ? 'Open Now' : 'Closed',
                            style: tt.bodySmall
                                ?.copyWith(color: ext.mark(statusSwatch)),
                          ),
                          if (clinic.hasOperatingHours) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                clinic.operatingHours!.todayHoursText,
                                style: tt.bodySmall
                                    ?.copyWith(color: ext.textTertiary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (clinic.address != null && clinic.address!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Icon(Icons.location_on_rounded,
                      size: 16, color: ext.textTertiary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      clinic.address!,
                      style: tt.bodySmall?.copyWith(color: ext.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if ((clinic.phone != null && clinic.phone!.isNotEmpty) ||
                clinic.hasLocation) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  if (clinic.phone != null && clinic.phone!.isNotEmpty)
                    Expanded(
                      child: AppButton(
                        label: 'Call',
                        leadingIcon: Icons.phone_rounded,
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.sm,
                        accent: ext.success,
                        onPressed: () => _callClinic(clinic),
                      ),
                    ),
                  if (clinic.phone != null && clinic.hasLocation)
                    const SizedBox(width: AppSpacing.sm),
                  if (clinic.hasLocation)
                    Expanded(
                      child: AppButton(
                        label: 'Map',
                        leadingIcon: Icons.map_rounded,
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.sm,
                        accent: ext.info,
                        onPressed: () => _openMap(clinic),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getClinicIcon(String? type) {
    switch (type) {
      case ClinicType.hospital:
        return Icons.local_hospital_rounded;
      case ClinicType.pharmacy:
        return Icons.local_pharmacy_rounded;
      case ClinicType.lab:
        return Icons.science_rounded;
      case ClinicType.imaging:
        return Icons.medical_information_rounded;
      case ClinicType.urgent:
        return Icons.emergency_rounded;
      default:
        return Icons.local_hospital_rounded;
    }
  }
}
