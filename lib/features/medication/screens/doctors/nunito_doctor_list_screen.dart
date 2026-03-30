import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/nunito_theme.dart';
import '../../widgets/nunito_glass_card.dart';
import '../../models/doctor_pharmacy.dart';
import '../../services/medicine_storage_service.dart';
import '../../../../core/services/haptic_service.dart';
import 'nunito_add_edit_doctor_screen.dart';

class NunitoDoctorListScreen extends StatefulWidget {
  final bool isSelectionMode;

  const NunitoDoctorListScreen({super.key, this.isSelectionMode = false});

  @override
  State<NunitoDoctorListScreen> createState() => _NunitoDoctorListScreenState();
}

class _NunitoDoctorListScreenState extends State<NunitoDoctorListScreen> {
  List<Doctor> _doctors = [];
  bool _isLoading = true;

  final HapticService _hapticService = HapticService();

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    setState(() => _isLoading = true);
    try {
      final doctors = await MedicineCleanStorageService.getAllDoctors();
      if (mounted) {
        setState(() {
          _doctors = doctors;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading doctors: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToAddEdit({Doctor? doctor}) async {
    _hapticService.light();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NunitoAddEditDoctorScreen(editDoctor: doctor),
      ),
    );

    if (result == true) {
      _loadDoctors();
    }
  }

  void _selectDoctor(Doctor doctor) {
    if (widget.isSelectionMode) {
      Navigator.pop(context, doctor);
    } else {
      _navigateToAddEdit(doctor: doctor);
    }
  }

  Future<void> _callDoctor(Doctor doctor) async {
    if (doctor.phone == null || doctor.phone!.isEmpty) return;
    
    final uri = Uri.parse('tel:${doctor.phone}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _emailDoctor(Doctor doctor) async {
    if (doctor.email == null || doctor.email!.isEmpty) return;
    
    final uri = Uri.parse('mailto:${doctor.email}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _deleteDoctor(Doctor doctor) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NunitoTheme.radiusMedium),
        ),
        title: Text('Delete Doctor', style: NunitoTheme.heading3),
        content: Text('Are you sure you want to delete Dr. ${doctor.name}?'),
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
      await MedicineCleanStorageService.deleteDoctor(doctor.id);
      _loadDoctors();
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
          widget.isSelectionMode ? 'Select Doctor' : 'My Doctors',
          style: NunitoTheme.heading2.copyWith(
            color: isDark ? Colors.white : NunitoTheme.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _doctors.isEmpty
              ? _buildEmptyState(isDark)
              : _buildDoctorList(isDark),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddEdit(),
        backgroundColor: NunitoTheme.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Add Doctor', style: NunitoTheme.labelLarge.copyWith(color: Colors.white)),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_add_rounded,
            size: 64,
            color: NunitoTheme.primary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No doctors added',
            style: NunitoTheme.heading3.copyWith(
              color: NunitoTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your doctors to keep their info handy',
            style: NunitoTheme.bodyMedium.copyWith(
              color: NunitoTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(NunitoTheme.spacingM),
      itemCount: _doctors.length,
      itemBuilder: (context, index) {
        final doctor = _doctors[index];
        return _buildDoctorCard(doctor, isDark);
      },
    );
  }

  Widget _buildDoctorCard(Doctor doctor, bool isDark) {
    return Dismissible(
      key: Key(doctor.id),
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
        _deleteDoctor(doctor);
        return false;
      },
      child: NunitoAnimatedCard(
        onTap: () => _selectDoctor(doctor),
        margin: const EdgeInsets.only(bottom: NunitoTheme.spacingS),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: NunitoTheme.accentBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  _getInitials(doctor.name),
                  style: NunitoTheme.heading3.copyWith(
                    color: NunitoTheme.accentBlue,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Dr. ${doctor.name}',
                        style: NunitoTheme.labelLarge.copyWith(
                          color: isDark ? Colors.white : NunitoTheme.textPrimary,
                        ),
                      ),
                      if (doctor.isPrimary) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: NunitoTheme.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Primary',
                            style: NunitoTheme.caption.copyWith(
                              color: NunitoTheme.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (doctor.specialty != null && doctor.specialty!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      doctor.specialty!,
                      style: NunitoTheme.bodySmall.copyWith(color: NunitoTheme.primary),
                    ),
                  ],
                  if (doctor.clinicName != null && doctor.clinicName!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      doctor.clinicName!,
                      style: NunitoTheme.caption,
                    ),
                  ],
                ],
              ),
            ),
            if (doctor.phone != null && doctor.phone!.isNotEmpty)
              IconButton(
                onPressed: () => _callDoctor(doctor),
                icon: Icon(Icons.phone_rounded, color: NunitoTheme.success, size: 22),
                tooltip: 'Call',
              ),
            if (doctor.email != null && doctor.email!.isNotEmpty)
              IconButton(
                onPressed: () => _emailDoctor(doctor),
                icon: Icon(Icons.email_rounded, color: NunitoTheme.accentBlue, size: 22),
                tooltip: 'Email',
              ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
