import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../theme/nunito_theme.dart';
import '../../widgets/nunito_glass_card.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }

    setState(() => _isLoading = false);
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
          icon: Icon(Icons.close_rounded, color: isDark ? Colors.white : NunitoTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Edit Clinic' : 'Add Clinic',
          style: NunitoTheme.heading2.copyWith(
            color: isDark ? Colors.white : NunitoTheme.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Save',
                    style: NunitoTheme.labelLarge.copyWith(color: NunitoTheme.primary),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(NunitoTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection('Basic Information', [
                _buildTextField(
                  controller: _nameController,
                  label: 'Name *',
                  hint: 'Clinic or hospital name',
                  validator: (v) => v == null || v.isEmpty ? 'Name is required' : null,
                  isDark: isDark,
                ),
                const SizedBox(height: NunitoTheme.spacingM),
                Text('Type', style: NunitoTheme.labelMedium.copyWith(
                  color: isDark ? Colors.white70 : NunitoTheme.textSecondary,
                )),
                const SizedBox(height: NunitoTheme.spacingS),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ClinicType.all.map((type) {
                    final isSelected = _selectedType == type;
                    return GestureDetector(
                      onTap: () {
                        _hapticService.selection();
                        setState(() => _selectedType = type);
                      },
                      child: AnimatedContainer(
                        duration: NunitoTheme.animationFast,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? NunitoTheme.primary : (isDark ? NunitoTheme.cardDark : Colors.white),
                          borderRadius: BorderRadius.circular(NunitoTheme.radiusSmall),
                          border: Border.all(
                            color: isSelected ? NunitoTheme.primary : NunitoTheme.textTertiary.withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          type,
                          style: NunitoTheme.labelMedium.copyWith(
                            color: isSelected ? Colors.white : (isDark ? Colors.white : NunitoTheme.textPrimary),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ], isDark),
              const SizedBox(height: NunitoTheme.spacingL),
              _buildSection('Location & Contact', [
                _buildTextField(
                  controller: _addressController,
                  label: 'Address',
                  hint: 'Full address',
                  maxLines: 2,
                  isDark: isDark,
                ),
                const SizedBox(height: NunitoTheme.spacingM),
                _buildTextField(
                  controller: _phoneController,
                  label: 'Phone',
                  hint: 'Phone number',
                  keyboardType: TextInputType.phone,
                  isDark: isDark,
                ),
                const SizedBox(height: NunitoTheme.spacingM),
                _buildTextField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'Email address',
                  keyboardType: TextInputType.emailAddress,
                  isDark: isDark,
                ),
                const SizedBox(height: NunitoTheme.spacingM),
                _buildTextField(
                  controller: _websiteController,
                  label: 'Website',
                  hint: 'Website URL',
                  keyboardType: TextInputType.url,
                  isDark: isDark,
                ),
              ], isDark),
              const SizedBox(height: NunitoTheme.spacingL),
              _buildSection('Operating Hours', [
                _buildOperatingHoursEditor(isDark),
              ], isDark),
              const SizedBox(height: NunitoTheme.spacingL),
              _buildSection('Additional', [
                _buildTextField(
                  controller: _notesController,
                  label: 'Notes',
                  hint: 'Any additional notes',
                  maxLines: 3,
                  isDark: isDark,
                ),
              ], isDark),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: NunitoTheme.labelLarge.copyWith(
            color: isDark ? Colors.white70 : NunitoTheme.textSecondary,
          ),
        ),
        const SizedBox(height: NunitoTheme.spacingS),
        ...children,
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isDark,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: NunitoTheme.bodyMedium.copyWith(
        color: isDark ? Colors.white : NunitoTheme.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: isDark ? NunitoTheme.cardDark : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NunitoTheme.radiusMedium),
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NunitoTheme.radiusMedium),
          borderSide: BorderSide(color: NunitoTheme.error),
        ),
      ),
    );
  }

  Widget _buildOperatingHoursEditor(bool isDark) {
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

    return NunitoCard(
      padding: const EdgeInsets.all(NunitoTheme.spacingM),
      child: Column(
        children: List.generate(7, (index) {
          final day = days[index];
          final hours = dayHours[index];
          
          return Padding(
            padding: EdgeInsets.only(bottom: index < 6 ? 12 : 0),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    day,
                    style: NunitoTheme.labelMedium.copyWith(
                      color: isDark ? Colors.white : NunitoTheme.textPrimary,
                    ),
                  ),
                ),
                Switch(
                  value: hours.isOpen,
                  onChanged: (v) => _updateDayHours(index, hours.copyWith(isOpen: v)),
                  activeColor: NunitoTheme.primary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 8),
                if (hours.isOpen) ...[
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _selectTime(index, true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: NunitoTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          hours.openTime ?? '09:00',
                          style: NunitoTheme.bodySmall.copyWith(color: NunitoTheme.primary),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('-', style: NunitoTheme.bodySmall),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _selectTime(index, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: NunitoTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          hours.closeTime ?? '17:00',
                          style: NunitoTheme.bodySmall.copyWith(color: NunitoTheme.primary),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ] else
                  Expanded(
                    child: Text(
                      'Closed',
                      style: NunitoTheme.bodySmall.copyWith(color: NunitoTheme.textTertiary),
                    ),
                  ),
              ],
            ),
          );
        }),
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

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (selectedTime != null) {
      final timeStr = '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
      final newHours = isOpenTime
          ? dayHours.copyWith(openTime: timeStr)
          : dayHours.copyWith(closeTime: timeStr);
      _updateDayHours(dayIndex, newHours);
    }
  }
}
