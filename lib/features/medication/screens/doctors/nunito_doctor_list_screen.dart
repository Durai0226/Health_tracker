import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/widgets/app/app_widgets.dart';
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
    final ext = AppColorsExt.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ext.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brLg),
        title: Text('Delete Doctor',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(color: ext.textPrimary)),
        content: Text('Are you sure you want to delete Dr. ${doctor.name}?',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: ext.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(color: ext.textSecondary)),
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
      await MedicineCleanStorageService.deleteDoctor(doctor.id);
      _loadDoctors();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final accent = ext.medicine;

    return AccentScope(
      feature: FeatureAccent.medicine,
      child: AppScaffold(
        floatingActionButton: AppFab(
          icon: Icons.add_rounded,
          label: 'Add Doctor',
          accent: accent,
          onPressed: () => _navigateToAddEdit(),
        ),
        body: Column(
          children: [
            AppHeader(
              title: widget.isSelectionMode ? 'Select Doctor' : 'Doctors',
              accent: accent,
              leading: AppIconButton(
                icon: Icons.arrow_back_rounded,
                filled: false,
                accent: accent,
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _doctors.isEmpty
                      ? EmptyState(
                          icon: Icons.person_add_rounded,
                          title: 'No doctors added',
                          message: 'Add your doctors to keep their info handy.',
                          accent: accent,
                          action: AppButton(
                            label: 'Add Doctor',
                            accent: accent,
                            leadingIcon: Icons.add_rounded,
                            onPressed: () => _navigateToAddEdit(),
                          ),
                        )
                      : _buildDoctorList(ext, accent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorList(AppColorsExt ext, AccentSwatch accent) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, 96),
      itemCount: _doctors.length,
      itemBuilder: (context, index) {
        final doctor = _doctors[index];
        return _buildDoctorCard(doctor, ext, accent);
      },
    );
  }

  Widget _buildDoctorCard(Doctor doctor, AppColorsExt ext, AccentSwatch accent) {
    final tt = Theme.of(context).textTheme;
    return Dismissible(
      key: Key(doctor.id),
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
        _deleteDoctor(doctor);
        return false;
      },
      child: AppCard(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        onTap: () => _selectDoctor(doctor),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: accent.container,
                borderRadius: AppRadius.brLg,
              ),
              child: Center(
                child: Text(
                  _getInitials(doctor.name),
                  style: tt.titleLarge?.copyWith(
                    color: accent.onContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
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
                        child: Text(
                          'Dr. ${doctor.name}',
                          style: tt.titleLarge?.copyWith(color: ext.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (doctor.isPrimary) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: ext.success.container,
                            borderRadius: AppRadius.brSm,
                          ),
                          child: Text(
                            'Primary',
                            style: tt.labelSmall?.copyWith(
                              color: ext.success.onContainer,
                              fontWeight: FontWeight.w700,
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
                      style: tt.bodySmall?.copyWith(color: ext.mark(accent)),
                    ),
                  ],
                  if (doctor.clinicName != null && doctor.clinicName!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      doctor.clinicName!,
                      style: tt.bodySmall?.copyWith(color: ext.textTertiary),
                    ),
                  ],
                ],
              ),
            ),
            if (doctor.phone != null && doctor.phone!.isNotEmpty)
              IconButton(
                onPressed: () => _callDoctor(doctor),
                icon: Icon(Icons.phone_rounded,
                    color: ext.success.strong, size: 22),
                tooltip: 'Call',
              ),
            if (doctor.email != null && doctor.email!.isNotEmpty)
              IconButton(
                onPressed: () => _emailDoctor(doctor),
                icon: Icon(Icons.email_rounded,
                    color: ext.mark(accent), size: 22),
                tooltip: 'Email',
              ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    // Split on whitespace runs and drop empties so a double space
    // ("John  Smith") doesn't yield an empty token → RangeError on [0].
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.isNotEmpty ? parts[0][0].toUpperCase() : '?';
  }
}
