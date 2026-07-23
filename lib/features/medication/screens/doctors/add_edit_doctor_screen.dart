import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app/app_widgets.dart';
import '../../models/doctor_pharmacy.dart';
import '../../services/medicine_storage_service.dart';

class AddEditDoctorScreen extends StatefulWidget {
  final Doctor? editDoctor;

  const AddEditDoctorScreen({super.key, this.editDoctor});

  @override
  State<AddEditDoctorScreen> createState() => _AddEditDoctorScreenState();
}

class _AddEditDoctorScreenState extends State<AddEditDoctorScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _specialtyController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _clinicController;
  late TextEditingController _notesController;
  bool _isPrimary = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.editDoctor?.name);
    _specialtyController = TextEditingController(text: widget.editDoctor?.specialty);
    _phoneController = TextEditingController(text: widget.editDoctor?.phone);
    _emailController = TextEditingController(text: widget.editDoctor?.email);
    _addressController = TextEditingController(text: widget.editDoctor?.address);
    _clinicController = TextEditingController(text: widget.editDoctor?.clinicName);
    _notesController = TextEditingController(text: widget.editDoctor?.notes);
    _isPrimary = widget.editDoctor?.isPrimary ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _specialtyController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _clinicController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveDoctor() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final doctor = Doctor(
        id: widget.editDoctor?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        specialty: _specialtyController.text.trim().isEmpty ? null : _specialtyController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        clinicName: _clinicController.text.trim().isEmpty ? null : _clinicController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        isPrimary: _isPrimary,
      );

      if (widget.editDoctor != null) {
        await MedicineCleanStorageService.updateDoctor(doctor);
      } else {
        await MedicineCleanStorageService.addDoctor(doctor);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.editDoctor != null ? 'Doctor updated' : 'Doctor added'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving doctor: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: Text(widget.editDoctor != null ? 'Edit Doctor' : 'Add Doctor'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : AppColors.textPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Basic Information', isDark),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _nameController,
                label: 'Name',
                hint: 'Dr. John Doe',
                icon: Symbols.person_rounded,
                validator: (v) => v?.trim().isEmpty == true ? 'Name is required' : null,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _specialtyController,
                label: 'Specialty',
                hint: 'Cardiologist, GP, etc.',
                icon: Symbols.medical_services_rounded,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _clinicController,
                label: 'Clinic/Hospital',
                hint: 'City General Hospital',
                icon: Symbols.local_hospital_rounded,
                isDark: isDark,
              ),
              
              const SizedBox(height: 24),
              _buildSectionTitle('Contact Details', isDark),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _phoneController,
                label: 'Phone',
                hint: '+1 234 567 890',
                icon: Symbols.phone_rounded,
                keyboardType: TextInputType.phone,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _emailController,
                label: 'Email',
                hint: 'doctor@hospital.com',
                icon: Symbols.email_rounded,
                keyboardType: TextInputType.emailAddress,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _addressController,
                label: 'Address',
                hint: '123 Medical Dr, Suite 100',
                icon: Symbols.location_on_rounded,
                maxLines: 2,
                isDark: isDark,
              ),

              const SizedBox(height: 24),
              _buildSectionTitle('Additional', isDark),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Primary Care Physician',
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Mark as your main doctor',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                trailing: AppSwitch(
                  value: _isPrimary,
                  onChanged: (val) => setState(() => _isPrimary = val),
                ),
                onTap: () => setState(() => _isPrimary = !_isPrimary),
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _notesController,
                label: 'Notes',
                hint: 'Consultation hours, special instructions...',
                icon: Symbols.note_rounded,
                maxLines: 3,
                isDark: isDark,
              ),
              
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveDoctor,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          widget.editDoctor != null ? 'Save Changes' : 'Add Doctor',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : AppColors.textPrimary,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
    required bool isDark,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: isDark ? Colors.white70 : AppColors.textSecondary),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        labelStyle: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary),
        hintStyle: TextStyle(color: isDark ? Colors.white30 : AppColors.textLight),
      ),
    );
  }
}
