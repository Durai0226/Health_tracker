import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/emergency_contact.dart';
import '../../../../core/widgets/app/app_widgets.dart';
import '../../models/dependent_profile.dart';
import '../../services/medicine_storage_service.dart';
import '../../../../core/utils/date_formats.dart';

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
  late TextEditingController _conditionsController;
  late TextEditingController _notesController;
  late TextEditingController _emergencyContactController;
  late TextEditingController _emergencyPhoneController;
  /// The read-only date-of-birth field's controller. It is a field, not a
  /// `TextEditingController(text: ...)` built inline: that allocated a fresh
  /// controller on every rebuild and disposed none of them.
  late TextEditingController _dobController;

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
    _conditionsController = TextEditingController(text: d?.conditions?.join(', '));
    _notesController = TextEditingController(text: d?.notes);
    // Your own contact is the one the setup checklist and the emergency card
    // read ([EmergencyContact]); this form shows and writes that one.
    final own = (d?.isSelf ?? false) ? EmergencyContact.get() : null;
    _emergencyContactController =
        TextEditingController(text: own?.name ?? d?.emergencyContact);
    _emergencyPhoneController =
        TextEditingController(text: own?.phone ?? d?.emergencyPhone);
    _relationship = d?.relationship ?? RelationshipType.child;
    _dateOfBirth = d?.dateOfBirth;
    _dobController = TextEditingController(text: _formatDob(_dateOfBirth));
    _gender = d?.gender;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bloodTypeController.dispose();
    _allergiesController.dispose();
    _conditionsController.dispose();
    _notesController.dispose();
    _emergencyContactController.dispose();
    _emergencyPhoneController.dispose();
    _dobController.dispose();
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
      setState(() {
        _dateOfBirth = picked;
        _dobController.text = _formatDob(picked);
      });
    }
  }

  /// The date as a person writes it. Empty when no date is set.
  ///
  /// Was a raw `YYYY-MM-DD`, which read as an input mask — but the field is
  /// wrapped in `IgnorePointer` behind a tap-to-pick `InkWell`, so nobody can
  /// ever type into it. It is a DISPLAY of a date the user chose from a picker,
  /// and an ISO string is a machine format shown to a human. Nothing parses
  /// this text back (`_dateOfBirth` is the source of truth), so the format is
  /// free to follow the device.
  static String _formatDob(DateTime? d) =>
      d == null ? '' : DateFormats.dayMonthYear.format(d);

  /// "Penicillin, Peanuts" as a list; null when nothing is written.
  static List<String>? _parseList(TextEditingController c) {
    final raw = c.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return raw.isEmpty ? null : raw;
  }

  Future<void> _saveDependent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // This form has no controls for weight/height/
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
        allergies: _parseList(_allergiesController),
        conditions: _parseList(_conditionsController),
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
      // Your own contact is read from [EmergencyContact], so what is written
      // here goes there as well; emptying both fields removes it.
      if (_isEditingSelf) {
        if (dependent.emergencyPhone == null) {
          await EmergencyContact.clear();
        } else {
          await EmergencyContact.save(
              name: dependent.emergencyContact ?? '', phone: dependent.emergencyPhone!);
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
      if (mounted) {
        context.toastError('Could not save this profile. Please try again.');
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
              leading: AppIconButton(
                icon: Symbols.close_rounded,
                filled: false,
                color: ext.textPrimary,
                tooltip: 'Close',
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
                            child: Icon(relationshipSymbol(_relationship),
                                size: 40, color: med.onContainer),
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
                                    // emoji-content-ok: a chip LABEL, at the
                                    // label's own size — content, not a badge.
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
                            controller: _dobController,
                            label: 'Date of birth',
                            hint: 'Tap to choose',
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
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        controller: _conditionsController,
                        label: 'Conditions',
                        hint: 'Asthma, Type 2 diabetes',
                        helperText: 'Comma-separated — shown on the emergency card',
                        prefixIcon: Symbols.stethoscope_rounded,
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
                        // A number to ring: what cannot be dialled is not saved
                        // as one.
                        validator: (v) => v == null ||
                                v.trim().isEmpty ||
                                EmergencyContact.isDialable(v)
                            ? null
                            : 'Enter a phone number',
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

/// The Material Symbol for a relationship, for the places it is rendered as
/// CHROME — a badge glyph in a decorated avatar. `RelationshipType.icon` (an
/// emoji) is still correct inside a chip label, which is content.
IconData relationshipSymbol(RelationshipType r) {
  switch (r) {
    case RelationshipType.self:
      return Symbols.person_rounded;
    case RelationshipType.child:
      return Symbols.child_care_rounded;
    case RelationshipType.parent:
      return Symbols.family_restroom_rounded;
    case RelationshipType.spouse:
      return Symbols.favorite_rounded;
    case RelationshipType.grandparent:
      return Symbols.elderly_rounded;
    case RelationshipType.sibling:
      return Symbols.group_rounded;
    case RelationshipType.other:
      return Symbols.people_rounded;
  }
}
