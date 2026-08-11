import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/widgets/app/app_widgets.dart';
import '../../models/dependent_profile.dart';
import '../../services/medicine_storage_service.dart';

class AddEditDependentScreen extends StatefulWidget {
  final DependentProfile? editDependent;

  const AddEditDependentScreen({super.key, this.editDependent});

  @override
  State<AddEditDependentScreen> createState() => _AddEditDependentScreenState();
}

class _AddEditDependentScreenState extends State<AddEditDependentScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _bloodTypeController;
  late TextEditingController _allergiesController;
  late TextEditingController _notesController;
  late TextEditingController _emergencyContactController;
  late TextEditingController _emergencyPhoneController;

  RelationshipType _relationship = RelationshipType.child;
  DateTime? _dateOfBirth;
  String? _gender; // "Male", "Female", "Other"
  bool _isSaving = false;

  bool get _isEditing => widget.editDependent != null;

  /// The self profile's relationship can't be reassigned to someone else —
  /// it's the anchor `null`-`dependentId` maps to (see ActiveProfileService).
  /// Everything else about it (name, allergies, ...) is editable like any
  /// other profile.
  bool get _isEditingSelf => widget.editDependent?.isSelf ?? false;

  @override
  void initState() {
    super.initState();
    final d = widget.editDependent;
    _nameController = TextEditingController(text: d?.name);
    _bloodTypeController = TextEditingController(text: d?.bloodType);
    _allergiesController = TextEditingController(text: d?.allergies?.join(', '));
    _notesController = TextEditingController(text: d?.notes);
    _emergencyContactController = TextEditingController(text: d?.emergencyContact);
    _emergencyPhoneController = TextEditingController(text: d?.emergencyPhone);
    _relationship = d?.relationship ?? RelationshipType.child;
    _dateOfBirth = d?.dateOfBirth;
    _gender = d?.gender;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bloodTypeController.dispose();
    _allergiesController.dispose();
    _notesController.dispose();
    _emergencyContactController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await AppDatePicker.show(
      context,
      initial: _dateOfBirth ?? DateTime.now(),
      first: DateTime(1900),
      last: DateTime.now(),
      title: 'Date of birth',
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  List<String>? _parseAllergies() {
    final raw = _allergiesController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return raw.isEmpty ? null : raw;
  }

  Future<void> _saveDependent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final ext = AppColorsExt.of(context);

    try {
      // This form has no controls for weight/height/conditions/
      // primaryDoctorId/insuranceInfo/avatarPath at all — carry them forward
      // from the existing record on an edit, or every edit through this
      // screen (even just correcting a name) silently wiped them to null,
      // discarding data this screen simply doesn't expose a way to re-enter.
      final existing = widget.editDependent;
      final dependent = DependentProfile(
        id: existing?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        relationship: _relationship,
        dateOfBirth: _dateOfBirth,
        bloodType: _bloodTypeController.text.trim().isEmpty
            ? null
            : _bloodTypeController.text.trim(),
        gender: _gender,
        weight: existing?.weight,
        height: existing?.height,
        allergies: _parseAllergies(),
        conditions: existing?.conditions,
        emergencyContact: _emergencyContactController.text.trim().isEmpty
            ? null
            : _emergencyContactController.text.trim(),
        emergencyPhone: _emergencyPhoneController.text.trim().isEmpty
            ? null
            : _emergencyPhoneController.text.trim(),
        primaryDoctorId: existing?.primaryDoctorId,
        insuranceInfo: existing?.insuranceInfo,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        avatarPath: existing?.avatarPath,
        isActive: existing?.isActive ?? true,
        createdAt: existing?.createdAt,
      );

      if (_isEditing) {
        await MedicineCleanStorageService.updateDependent(dependent);
      } else {
        await MedicineCleanStorageService.addDependent(dependent);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ext.error.base,
            content: Text('Error saving profile: $e',
                style: TextStyle(color: ext.error.on)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
              title: _isEditing ? 'Edit profile' : 'Add family member',
              icon: Symbols.person_add_rounded,
              accent: med,
              leading: IconButton(
                icon: Icon(Symbols.close_rounded, color: ext.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                AppButton(
                  label: 'Save',
                  size: AppButtonSize.sm,
                  accent: med,
                  loading: _isSaving,
                  onPressed: _saveDependent,
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                    AppSpacing.sm, AppSpacing.gutter, AppSpacing.xxl),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: med.container,
                            shape: BoxShape.circle,
                            border: Border.all(color: med.base, width: 2),
                          ),
                          child: Center(
                            child: Text(_relationship.icon,
                                style: const TextStyle(fontSize: 40)),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      SectionHeader(
                          title: 'Profile info',
                          icon: Symbols.info_rounded,
                          accent: med),
                      const SizedBox(height: AppSpacing.sm),
                      AppTextField(
                        controller: _nameController,
                        label: 'Full name',
                        hint: 'Jane Doe',
                        prefixIcon: Symbols.person_rounded,
                        accent: med,
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Name is required'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (!_isEditingSelf) ...[
                        Text('Relationship',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(color: ext.textSecondary)),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: RelationshipType.values
                              .where((r) => r != RelationshipType.self)
                              .map((r) => AppChip(
                                    label: '${r.icon} ${r.displayName}',
                                    selected: _relationship == r,
                                    accent: med,
                                    onTap: () =>
                                        setState(() => _relationship = r),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      InkWell(
                        onTap: _selectDate,
                        borderRadius: AppRadius.brMd,
                        child: IgnorePointer(
                          child: AppTextField(
                            controller: TextEditingController(
                              text: _dateOfBirth != null
                                  ? '${_dateOfBirth!.year}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.day.toString().padLeft(2, '0')}'
                                  : '',
                            ),
                            label: 'Date of birth',
                            hint: 'YYYY-MM-DD',
                            prefixIcon: Symbols.calendar_today_rounded,
                            accent: med,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      SectionHeader(
                          title: 'Medical info',
                          icon: Symbols.medical_information_rounded,
                          accent: med),
                      const SizedBox(height: AppSpacing.sm),
                      AppTextField(
                        controller: _bloodTypeController,
                        label: 'Blood type',
                        hint: 'O+',
                        prefixIcon: Symbols.bloodtype_rounded,
                        accent: med,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text('Gender',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(color: ext.textSecondary)),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: ['Male', 'Female', 'Other']
                            .map((g) => AppChip(
                                  label: g,
                                  selected: _gender == g,
                                  accent: med,
                                  onTap: () => setState(() => _gender = g),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        controller: _allergiesController,
                        label: 'Allergies',
                        hint: 'Penicillin, Peanuts',
                        helperText:
                            'Comma-separated — checked when adding a medicine',
                        prefixIcon: Symbols.warning_rounded,
                        accent: med,
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      SectionHeader(
                          title: 'Emergency contact',
                          icon: Symbols.contact_emergency_rounded,
                          accent: med),
                      const SizedBox(height: AppSpacing.sm),
                      AppTextField(
                        controller: _emergencyContactController,
                        label: 'Contact name',
                        hint: 'Emergency contact person',
                        prefixIcon: Symbols.person_rounded,
                        accent: med,
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        controller: _emergencyPhoneController,
                        label: 'Phone number',
                        hint: '+1 234 567 890',
                        prefixIcon: Symbols.phone_rounded,
                        accent: med,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      SectionHeader(
                          title: 'Notes',
                          icon: Symbols.sticky_note_2_rounded,
                          accent: med),
                      const SizedBox(height: AppSpacing.sm),
                      AppTextField(
                        controller: _notesController,
                        hint: 'Any additional notes',
                        accent: med,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      AppButton(
                        label: _isEditing ? 'Save changes' : 'Add profile',
                        accent: med,
                        fullWidth: true,
                        size: AppButtonSize.lg,
                        loading: _isSaving,
                        leadingIcon: Symbols.check_rounded,
                        onPressed: _saveDependent,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
