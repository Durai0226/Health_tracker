import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/nunito_theme.dart';
import '../../widgets/nunito_glass_card.dart';
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NunitoTheme.radiusMedium),
        ),
        title: Text('Delete Clinic', style: NunitoTheme.heading3),
        content: Text('Are you sure you want to delete ${clinic.name}?'),
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
      await MedicineCleanStorageService.deleteClinic(clinic.id);
      _loadClinics();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? NunitoTheme.backgroundDark : NunitoTheme.backgroundLight,
      appBar: AppBar(
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
          widget.isSelectionMode ? 'Select Clinic' : 'My Clinics',
          style: NunitoTheme.heading2.copyWith(
            color: isDark ? Colors.white : NunitoTheme.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _clinics.isEmpty
              ? _buildEmptyState(isDark)
              : _buildClinicList(isDark),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddEdit(),
        backgroundColor: NunitoTheme.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Add Clinic', style: NunitoTheme.labelLarge.copyWith(color: Colors.white)),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_hospital_rounded,
            size: 64,
            color: NunitoTheme.primary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No clinics added',
            style: NunitoTheme.heading3.copyWith(
              color: NunitoTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add clinics and hospitals you visit',
            style: NunitoTheme.bodyMedium.copyWith(
              color: NunitoTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClinicList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(NunitoTheme.spacingM),
      itemCount: _clinics.length,
      itemBuilder: (context, index) {
        final clinic = _clinics[index];
        return _buildClinicCard(clinic, isDark);
      },
    );
  }

  Widget _buildClinicCard(Clinic clinic, bool isDark) {
    final isOpen = clinic.operatingHours?.isOpenNow ?? false;

    return Dismissible(
      key: Key(clinic.id),
      direction: DismissDirection.endToStart,
      background: Container(
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
        _deleteClinic(clinic);
        return false;
      },
      child: NunitoAnimatedCard(
        onTap: () => _selectClinic(clinic),
        margin: const EdgeInsets.only(bottom: NunitoTheme.spacingS),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: NunitoTheme.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _getClinicIcon(clinic.type),
                    color: NunitoTheme.accent,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clinic.name,
                        style: NunitoTheme.labelLarge.copyWith(
                          color: isDark ? Colors.white : NunitoTheme.textPrimary,
                        ),
                      ),
                      if (clinic.type != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          clinic.displayType,
                          style: NunitoTheme.bodySmall.copyWith(color: NunitoTheme.primary),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isOpen ? NunitoTheme.success : NunitoTheme.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isOpen ? 'Open Now' : 'Closed',
                            style: NunitoTheme.caption.copyWith(
                              color: isOpen ? NunitoTheme.success : NunitoTheme.error,
                            ),
                          ),
                          if (clinic.hasOperatingHours) ...[
                            const SizedBox(width: 8),
                            Text(
                              clinic.operatingHours!.todayHoursText,
                              style: NunitoTheme.caption,
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.location_on_rounded, size: 16, color: NunitoTheme.textTertiary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      clinic.address!,
                      style: NunitoTheme.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (clinic.phone != null && clinic.phone!.isNotEmpty)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _callClinic(clinic),
                      icon: Icon(Icons.phone_rounded, size: 18, color: NunitoTheme.success),
                      label: Text('Call', style: TextStyle(color: NunitoTheme.success)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: NunitoTheme.success.withOpacity(0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                if (clinic.phone != null && clinic.hasLocation)
                  const SizedBox(width: 8),
                if (clinic.hasLocation)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openMap(clinic),
                      icon: Icon(Icons.map_rounded, size: 18, color: NunitoTheme.accentBlue),
                      label: Text('Map', style: TextStyle(color: NunitoTheme.accentBlue)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: NunitoTheme.accentBlue.withOpacity(0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
              ],
            ),
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
