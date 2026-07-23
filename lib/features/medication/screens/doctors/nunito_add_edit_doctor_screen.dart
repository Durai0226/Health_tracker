import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/widgets/app/app_widgets.dart';
import '../../models/doctor_pharmacy.dart';
import '../../services/medicine_storage_service.dart';
import '../../../../core/services/haptic_service.dart';

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
  }

  void _loadExistingDoctor() {
    final doc = widget.editDoctor!;
    _nameController.text = doc.name;
    _specialtyController.text = doc.specialty ?? '';
    _phoneController.text = doc.phone ?? '';
    _emailController.text = doc.email ?? '';
    _addressController.text = doc.address ?? '';
    _hospitalController.text = doc.clinicName ?? '';
    _notesController.text = doc.notes ?? '';
    _isPrimary = doc.isPrimary;
  }

  @override
  void dispose() {
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
        notes: _notesController.text.isNotEmpty ? _notesController.text.trim() : null,
        isPrimary: _isPrimary,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
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
              title: _isEditing ? 'Edit Doctor' : 'Add Doctor',
              accent: accent,
              leading: AppIconButton(
                icon: Symbols.close_rounded,
                filled: false,
                accent: accent,
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
                            title: 'Basic Information',
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
                            title: 'Contact Information',
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
                    const SizedBox(height: AppSpacing.xl),

                    // Primary save action
                    AppButton(
                      label: _isEditing ? 'Save Changes' : 'Add Doctor',
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
