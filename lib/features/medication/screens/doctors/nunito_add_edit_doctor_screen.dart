import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../theme/nunito_theme.dart';
import '../../widgets/nunito_glass_card.dart';
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
          _isEditing ? 'Edit Doctor' : 'Add Doctor',
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
                  hint: 'Doctor\'s name',
                  validator: (v) => v == null || v.isEmpty ? 'Name is required' : null,
                  isDark: isDark,
                ),
                const SizedBox(height: NunitoTheme.spacingM),
                _buildTextField(
                  controller: _specialtyController,
                  label: 'Specialty',
                  hint: 'e.g., Cardiologist, General Physician',
                  isDark: isDark,
                ),
                const SizedBox(height: NunitoTheme.spacingM),
                _buildTextField(
                  controller: _hospitalController,
                  label: 'Hospital/Clinic',
                  hint: 'Where they practice',
                  isDark: isDark,
                ),
              ], isDark),
              const SizedBox(height: NunitoTheme.spacingL),
              _buildSection('Contact Information', [
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
                  controller: _addressController,
                  label: 'Address',
                  hint: 'Office address',
                  maxLines: 2,
                  isDark: isDark,
                ),
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
                const SizedBox(height: NunitoTheme.spacingM),
                NunitoCard(
                  onTap: () {
                    _hapticService.toggle();
                    setState(() => _isPrimary = !_isPrimary);
                  },
                  child: Row(
                    children: [
                      Icon(
                        _isPrimary ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: _isPrimary ? NunitoTheme.warning : NunitoTheme.textTertiary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Primary Doctor',
                              style: NunitoTheme.labelLarge.copyWith(
                                color: isDark ? Colors.white : NunitoTheme.textPrimary,
                              ),
                            ),
                            Text(
                              'Mark as your main healthcare provider',
                              style: NunitoTheme.caption,
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isPrimary,
                        onChanged: (v) {
                          _hapticService.toggle();
                          setState(() => _isPrimary = v);
                        },
                        activeColor: NunitoTheme.warning,
                      ),
                    ],
                  ),
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
}
