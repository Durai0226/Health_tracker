import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/widgets/app/app_widgets.dart';
import '../../models/clinic.dart';
import '../../models/doctor_pharmacy.dart';
import '../clinics/nunito_clinic_list_screen.dart';
import '../../services/medicine_storage_service.dart';
import '../../../../core/services/active_profile_service.dart';
import '../../../../core/services/haptic_service.dart';
import '../../widgets/share_with_family_card.dart';

class NunitoAddEditDoctorScreen extends StatefulWidget {
  final Doctor? editDoctor;

  const NunitoAddEditDoctorScreen({super.key, this.editDoctor});

  @override
  State<NunitoAddEditDoctorScreen> createState() => _NunitoAddEditDoctorScreenState();
}

class _NunitoAddEditDoctorScreenState extends State<NunitoAddEditDoctorScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isPrimary = false;

  /// A doctor added now belongs to the person in view alone, unless shared.
  bool _sharedWithFamily = false;

  /// The clinic record chosen for "Hospital / Clinic", when one was chosen rather than
  /// a name typed, and its name as it was chosen. Typing over the name unlinks it.
  String? _clinicId;
  String? _linkedClinicName;
  bool _hasClinics = false;

  final _nameController = TextEditingController();
  final _specialtyController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _notesController = TextEditingController();

  final HapticService _hapticService = HapticService();

  bool get _isEditing => widget.editDoctor != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadExistingDoctor();
    }
    _hospitalController.addListener(_onHospitalTyped);
    _checkForClinics();
  }

  /// Whether there is a clinic to choose from, and — on an edit — what the linked one is
  /// called now (it may have been renamed, or deleted, since).
  Future<void> _checkForClinics() async {
    try {
      final clinics = await MedicineCleanStorageService.getAllClinics();
      if (!mounted) return;
      final linked = _clinicId == null
          ? null
          : clinics.where((c) => c.id == _clinicId).firstOrNull;
      setState(() {
        _hasClinics = clinics.isNotEmpty;
        if (linked != null) {
          // Shown under the clinic's name now, as the list shows it.
          _linkedClinicName = linked.name;
          _hospitalController.text = linked.name;
        } else if (clinics.isNotEmpty) {
          // There are clinics and this is not one of them: it was deleted. (An empty
          // list proves nothing — it is also what a clinic list that could not be
          // read looks like — so a link is only dropped when there is something to
          // compare it with.)
          _clinicId = null;
          _linkedClinicName = null;
        }
      });
    } catch (e) {
      debugPrint('Looking for clinics failed: $e');
    }
  }

  /// A name typed over the chosen clinic's is a different place: the link goes.
  void _onHospitalTyped() {
    if (_clinicId != null && _hospitalController.text != _linkedClinicName) {
      setState(() {
        _clinicId = null;
        _linkedClinicName = null;
      });
    }
  }

  Future<void> _chooseClinic() async {
    _hapticService.selection();
    final picked = await Navigator.push<Clinic>(
      context,
      MaterialPageRoute(
          builder: (_) => const NunitoClinicListScreen(isSelectionMode: true)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _clinicId = picked.id;
      _linkedClinicName = picked.name;
      _hospitalController.text = picked.name;
    });
  }

  void _loadExistingDoctor() {
    final doc = widget.editDoctor!;
    _nameController.text = doc.name;
    _specialtyController.text = doc.specialty ?? '';
    _phoneController.text = doc.phone ?? '';
    _emailController.text = doc.email ?? '';
    _addressController.text = doc.address ?? '';
    _hospitalController.text = doc.clinicName ?? '';
    _clinicId = doc.clinicId;
    _notesController.text = doc.notes ?? '';
    _isPrimary = doc.isPrimary;
    _sharedWithFamily = doc.sharedWithFamily;
  }

  @override
  void dispose() {
    _hospitalController.removeListener(_onHospitalTyped);
    _nameController.dispose();
    _specialtyController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _hospitalController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final doctor = Doctor(
        id: _isEditing ? widget.editDoctor!.id : const Uuid().v4(),
        name: _nameController.text.trim(),
        specialty: _specialtyController.text.isNotEmpty ? _specialtyController.text.trim() : null,
        phone: _phoneController.text.isNotEmpty ? _phoneController.text.trim() : null,
        email: _emailController.text.isNotEmpty ? _emailController.text.trim() : null,
        address: _addressController.text.isNotEmpty ? _addressController.text.trim() : null,
        clinicName: _hospitalController.text.isNotEmpty ? _hospitalController.text.trim() : null,
        clinicId: _clinicId,
        notes: _notesController.text.isNotEmpty ? _notesController.text.trim() : null,
        isPrimary: _isPrimary,
        // Whose doctor this is is fixed when it is added: an edit made while another
        // profile is in view must not hand it over.
        dependentId: _isEditing
            ? widget.editDoctor!.dependentId
            : ActiveProfileService().activeDependentId,
        sharedWithFamily: _sharedWithFamily,
      );

      await MedicineCleanStorageService.saveDoctor(doctor);
      _hapticService.success();

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error saving doctor: $e');
      _hapticService.error();
      if (mounted) {
        context.toastError('Could not save this doctor. Please try again.');
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final accent = ext.medicine;

    return AccentScope(
      feature: FeatureAccent.medicine,
      child: AppScaffold(
        body: Column(
          children: [
            AppHeader(
              title: _isEditing ? 'Edit doctor' : 'Add doctor',
              leading: AppIconButton(
                icon: Symbols.close_rounded,
                filled: false,
                accent: accent,
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                AppButton(
                  label: 'Save',
                  size: AppButtonSize.sm,
                  variant: AppButtonVariant.tonal,
                  accent: accent,
                  loading: _isLoading,
                  onPressed: _isLoading ? null : _save,
                ),
              ],
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, 40),
                  children: [
                    // Basic Information
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionHeader(
                            title: 'Basic information',
                            icon: Symbols.badge_rounded,
                            accent: accent,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          AppTextField(
                            controller: _nameController,
                            label: 'Name',
                            hint: "Doctor's name",
                            prefixIcon: Symbols.person_rounded,
                            accent: accent,
                            textCapitalization: TextCapitalization.words,
                            validator: (v) =>
                                v == null || v.trim().isEmpty ? 'Name is required' : null,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AppTextField(
                            controller: _specialtyController,
                            label: 'Specialty',
                            hint: 'e.g., Cardiologist, General Physician',
                            prefixIcon: Symbols.medical_services_rounded,
                            accent: accent,
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AppTextField(
                            controller: _hospitalController,
                            label: 'Hospital / Clinic',
                            hint: 'Where they practice',
                            prefixIcon: Symbols.local_hospital_rounded,
                            accent: accent,
                            textCapitalization: TextCapitalization.words,
                          ),
                          if (_hasClinics) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: AppButton(
                                label: _clinicId == null
                                    ? 'Choose from my clinics'
                                    : 'Change clinic',
                                size: AppButtonSize.sm,
                                variant: AppButtonVariant.tonal,
                                accent: accent,
                                leadingIcon: _clinicId == null
                                    ? Symbols.local_hospital_rounded
                                    : Symbols.link_rounded,
                                onPressed: _chooseClinic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Contact Information
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionHeader(
                            title: 'Contact information',
                            icon: Symbols.contact_phone_rounded,
                            accent: accent,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          AppTextField(
                            controller: _phoneController,
                            label: 'Phone',
                            hint: 'Phone number',
                            prefixIcon: Symbols.phone_rounded,
                            accent: accent,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AppTextField(
                            controller: _emailController,
                            label: 'Email',
                            hint: 'Email address',
                            prefixIcon: Symbols.email_rounded,
                            accent: accent,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AppTextField(
                            controller: _addressController,
                            label: 'Address',
                            hint: 'Office address',
                            prefixIcon: Symbols.location_on_rounded,
                            accent: accent,
                            maxLines: 2,
                            textCapitalization: TextCapitalization.sentences,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Additional
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionHeader(
                            title: 'Additional',
                            icon: Symbols.notes_rounded,
                            accent: accent,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          AppTextField(
                            controller: _notesController,
                            label: 'Notes',
                            hint: 'Any additional notes',
                            prefixIcon: Symbols.sticky_note_2_rounded,
                            accent: accent,
                            maxLines: 3,
                            textCapitalization: TextCapitalization.sentences,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Primary doctor toggle
                    AppCard(
                      onTap: () {
                        _hapticService.toggle();
                        setState(() => _isPrimary = !_isPrimary);
                      },
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: ext.warning.container,
                              borderRadius: AppRadius.brSm,
                            ),
                            child: Icon(
                              _isPrimary ? Symbols.star_rounded : Symbols.star_rounded,
                              color: ext.warning.onContainer,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Primary Doctor',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        color: ext.textPrimary,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Mark as your main healthcare provider',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: ext.textSecondary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          AppSwitch(
                            value: _isPrimary,
                            onChanged: (v) {
                              _hapticService.toggle();
                              setState(() => _isPrimary = v);
                            },
                            accent: accent,
                          ),
                        ],
                      ),
                    ),
                    ShareWithFamilyCard(
                      kind: 'doctor',
                      value: _sharedWithFamily,
                      accent: accent,
                      onChanged: (v) => setState(() => _sharedWithFamily = v),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Primary save action
                    AppButton(
                      label: _isEditing ? 'Save changes' : 'Add doctor',
                      accent: accent,
                      fullWidth: true,
                      size: AppButtonSize.lg,
                      leadingIcon: Symbols.check_rounded,
                      loading: _isLoading,
                      onPressed: _isLoading ? null : _save,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
