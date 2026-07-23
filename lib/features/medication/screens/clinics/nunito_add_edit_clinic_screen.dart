import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/widgets/app/app_widgets.dart';
import '../../models/clinic.dart';
import '../../services/medicine_storage_service.dart';
import '../../../../core/services/haptic_service.dart';

class NunitoAddEditClinicScreen extends StatefulWidget {
  final Clinic? editClinic;

  const NunitoAddEditClinicScreen({super.key, this.editClinic});

  @override
  State<NunitoAddEditClinicScreen> createState() => _NunitoAddEditClinicScreenState();
}

class _NunitoAddEditClinicScreenState extends State<NunitoAddEditClinicScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String _selectedType = ClinicType.clinic;

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _notesController = TextEditingController();

  OperatingHours _operatingHours = OperatingHours.weekdays(
    openTime: '09:00',
    closeTime: '17:00',
  );

  final HapticService _hapticService = HapticService();

  bool get _isEditing => widget.editClinic != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadExistingClinic();
    }
  }

  void _loadExistingClinic() {
    final c = widget.editClinic!;
    _nameController.text = c.name;
    _addressController.text = c.address ?? '';
    _phoneController.text = c.phone ?? '';
    _emailController.text = c.email ?? '';
    _websiteController.text = c.website ?? '';
    _notesController.text = c.notes ?? '';
    _selectedType = c.type ?? ClinicType.clinic;
    if (c.operatingHours != null) {
      _operatingHours = c.operatingHours!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final clinic = Clinic(
        id: _isEditing ? widget.editClinic!.id : const Uuid().v4(),
        name: _nameController.text.trim(),
        address: _addressController.text.isNotEmpty ? _addressController.text.trim() : null,
        phone: _phoneController.text.isNotEmpty ? _phoneController.text.trim() : null,
        email: _emailController.text.isNotEmpty ? _emailController.text.trim() : null,
        website: _websiteController.text.isNotEmpty ? _websiteController.text.trim() : null,
        notes: _notesController.text.isNotEmpty ? _notesController.text.trim() : null,
        type: _selectedType,
        operatingHours: _operatingHours,
        createdAt: _isEditing ? widget.editClinic!.createdAt : DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await MedicineCleanStorageService.saveClinic(clinic);
      _hapticService.success();

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error saving clinic: $e');
      _hapticService.error();
      if (mounted) {
        final ext = AppColorsExt.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ext.error.base,
            content: Text('Error: $e', style: TextStyle(color: ext.error.on)),
          ),
        );
      }
    }

    if (mounted) setState(() => _isLoading = false);
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
              title: _isEditing ? 'Edit Clinic' : 'Add Clinic',
              icon: Symbols.local_hospital_rounded,
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
                  loading: _isLoading,
                  onPressed: _save,
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, AppSpacing.xxl),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ---- Basic Information ----
                      SectionHeader(
                        title: 'Basic Information',
                        icon: Symbols.info_rounded,
                        accent: med,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppTextField(
                        controller: _nameController,
                        label: 'Name',
                        hint: 'Clinic or hospital name',
                        prefixIcon: Symbols.local_hospital_rounded,
                        accent: med,
                        textCapitalization: TextCapitalization.words,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Name is required' : null,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Type',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: ext.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: ClinicType.all.map((type) {
                          return AppChip(
                            label: type,
                            selected: _selectedType == type,
                            accent: med,
                            onTap: () {
                              _hapticService.selection();
                              setState(() => _selectedType = type);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // ---- Location & Contact ----
                      SectionHeader(
                        title: 'Location & Contact',
                        icon: Symbols.place_rounded,
                        accent: med,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppTextField(
                        controller: _addressController,
                        label: 'Address',
                        hint: 'Full address',
                        prefixIcon: Symbols.location_on_rounded,
                        accent: med,
                        maxLines: 2,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        controller: _phoneController,
                        label: 'Phone',
                        hint: 'Phone number',
                        prefixIcon: Symbols.phone_rounded,
                        accent: med,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        controller: _emailController,
                        label: 'Email',
                        hint: 'Email address',
                        prefixIcon: Symbols.email_rounded,
                        accent: med,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        controller: _websiteController,
                        label: 'Website',
                        hint: 'Website URL',
                        prefixIcon: Symbols.language_rounded,
                        accent: med,
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // ---- Operating Hours ----
                      SectionHeader(
                        title: 'Operating Hours',
                        icon: Symbols.schedule_rounded,
                        accent: med,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _buildOperatingHoursEditor(ext, med),
                      const SizedBox(height: AppSpacing.xl),

                      // ---- Additional ----
                      SectionHeader(
                        title: 'Additional',
                        icon: Symbols.sticky_note_2_rounded,
                        accent: med,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppTextField(
                        controller: _notesController,
                        label: 'Notes',
                        hint: 'Any additional notes',
                        accent: med,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // ---- Save ----
                      AppButton(
                        label: _isEditing ? 'Save Changes' : 'Add Clinic',
                        accent: med,
                        fullWidth: true,
                        size: AppButtonSize.lg,
                        loading: _isLoading,
                        leadingIcon: Symbols.check_rounded,
                        onPressed: _save,
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

  Widget _buildOperatingHoursEditor(AppColorsExt ext, AccentSwatch med) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayHours = [
      _operatingHours.monday,
      _operatingHours.tuesday,
      _operatingHours.wednesday,
      _operatingHours.thursday,
      _operatingHours.friday,
      _operatingHours.saturday,
      _operatingHours.sunday,
    ];
    final tt = Theme.of(context).textTheme;

    return AppCard(
      child: Column(
        children: List.generate(7, (index) {
          final day = days[index];
          final hours = dayHours[index];

          return Padding(
            padding: EdgeInsets.only(bottom: index < 6 ? AppSpacing.md : 0),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    day,
                    style: tt.titleLarge?.copyWith(color: ext.textPrimary),
                  ),
                ),
                AppSwitch(
                  value: hours.isOpen,
                  onChanged: (v) {
                    _hapticService.toggle();
                    _updateDayHours(index, hours.copyWith(isOpen: v));
                  },
                  accent: med,
                ),
                const SizedBox(width: AppSpacing.sm),
                if (hours.isOpen) ...[
                  Expanded(
                    child: _buildTimeChip(
                      ext,
                      med,
                      hours.openTime ?? '09:00',
                      () => _selectTime(index, true),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    child: Text('-',
                        style: tt.bodyMedium?.copyWith(color: ext.textTertiary)),
                  ),
                  Expanded(
                    child: _buildTimeChip(
                      ext,
                      med,
                      hours.closeTime ?? '17:00',
                      () => _selectTime(index, false),
                    ),
                  ),
                ] else
                  Expanded(
                    child: Text(
                      'Closed',
                      style: tt.bodyMedium?.copyWith(color: ext.textTertiary),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTimeChip(
      AppColorsExt ext, AccentSwatch med, String value, VoidCallback onTap) {
    return Material(
      color: med.container,
      borderRadius: AppRadius.brSm,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            value,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: med.onContainer),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  void _updateDayHours(int dayIndex, DayHours newHours) {
    setState(() {
      switch (dayIndex) {
        case 0:
          _operatingHours = _operatingHours.copyWith(monday: newHours);
          break;
        case 1:
          _operatingHours = _operatingHours.copyWith(tuesday: newHours);
          break;
        case 2:
          _operatingHours = _operatingHours.copyWith(wednesday: newHours);
          break;
        case 3:
          _operatingHours = _operatingHours.copyWith(thursday: newHours);
          break;
        case 4:
          _operatingHours = _operatingHours.copyWith(friday: newHours);
          break;
        case 5:
          _operatingHours = _operatingHours.copyWith(saturday: newHours);
          break;
        case 6:
          _operatingHours = _operatingHours.copyWith(sunday: newHours);
          break;
      }
    });
  }

  Future<void> _selectTime(int dayIndex, bool isOpenTime) async {
    final dayHours = [
      _operatingHours.monday,
      _operatingHours.tuesday,
      _operatingHours.wednesday,
      _operatingHours.thursday,
      _operatingHours.friday,
      _operatingHours.saturday,
      _operatingHours.sunday,
    ][dayIndex];

    final currentTimeStr = isOpenTime ? (dayHours.openTime ?? '09:00') : (dayHours.closeTime ?? '17:00');
    final parts = currentTimeStr.split(':');
    final initialTime = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );

    final selectedTime = await AppTimePicker.show(context, initial: initialTime);

    if (selectedTime != null) {
      final timeStr = '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
      final newHours = isOpenTime
          ? dayHours.copyWith(openTime: timeStr)
          : dayHours.copyWith(closeTime: timeStr);
      _updateDayHours(dayIndex, newHours);
    }
  }
}
