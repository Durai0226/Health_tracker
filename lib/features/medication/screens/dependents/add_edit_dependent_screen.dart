import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
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
  late TextEditingController _notesController;
  late TextEditingController _emergencyContactController;
  late TextEditingController _emergencyPhoneController;
  
  RelationshipType _relationship = RelationshipType.child;
  DateTime? _dateOfBirth;
  String? _gender; // "Male", "Female", "Other"
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.editDependent?.name);
    _bloodTypeController = TextEditingController(text: widget.editDependent?.bloodType);
    _notesController = TextEditingController(text: widget.editDependent?.notes);
    _emergencyContactController = TextEditingController(text: widget.editDependent?.emergencyContact);
    _emergencyPhoneController = TextEditingController(text: widget.editDependent?.emergencyPhone);
    _relationship = widget.editDependent?.relationship ?? RelationshipType.child;
    _dateOfBirth = widget.editDependent?.dateOfBirth;
    _gender = widget.editDependent?.gender;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bloodTypeController.dispose();
    _notesController.dispose();
    _emergencyContactController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.getSurface(context),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  Future<void> _saveDependent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final dependent = DependentProfile(
        id: widget.editDependent?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        relationship: _relationship,
        dateOfBirth: _dateOfBirth,
        bloodType: _bloodTypeController.text.trim().isEmpty ? null : _bloodTypeController.text.trim(),
        gender: _gender,
        emergencyContact: _emergencyContactController.text.trim().isEmpty ? null : _emergencyContactController.text.trim(),
        emergencyPhone: _emergencyPhoneController.text.trim().isEmpty ? null : _emergencyPhoneController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        isActive: widget.editDependent?.isActive ?? true,
      );

      if (widget.editDependent != null) {
        await MedicineCleanStorageService.updateDependent(dependent);
      } else {
        await MedicineCleanStorageService.addDependent(dependent);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.editDependent != null ? 'Profile updated' : 'Profile added'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
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
        title: Text(widget.editDependent != null ? 'Edit Profile' : 'Add Family Member'),
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
              // Avatar Placeholder
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          _relationship.icon,
                          style: const TextStyle(fontSize: 48),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              _buildSectionTitle('Profile Info', isDark),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _nameController,
                label: 'Full Name',
                hint: 'Jane Doe',
                icon: Icons.person_rounded,
                validator: (v) => v?.trim().isEmpty == true ? 'Name is required' : null,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              
              // Relationship Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.transparent : Colors.transparent),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButtonFormField<RelationshipType>(
                    value: _relationship,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.people_rounded),
                      labelText: 'Relationship',
                    ),
                    items: RelationshipType.values
                        .where((r) => r != RelationshipType.self) // Exclude self if needed, or keep
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(r.displayName),
                            ))
                        .toList(),
                    onChanged: (val) => setState(() => _relationship = val!),
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Date of Birth
              InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(12),
                child: IgnorePointer(
                  child: _buildTextField(
                    controller: TextEditingController(
                      text: _dateOfBirth != null
                          ? '${_dateOfBirth!.year}-${_dateOfBirth!.month}-${_dateOfBirth!.day}'
                          : '',
                    ),
                    label: 'Date of Birth',
                    hint: 'YYYY-MM-DD',
                    icon: Icons.calendar_today_rounded,
                    isDark: isDark,
                  ),
                ),
              ),

              const SizedBox(height: 24),
              _buildSectionTitle('Medical Info', isDark),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _bloodTypeController,
                      label: 'Blood Type',
                      hint: 'O+',
                      icon: Icons.bloodtype_rounded,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButtonFormField<String>(
                          value: _gender,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            labelText: 'Gender',
                          ),
                          items: ['Male', 'Female', 'Other']
                              .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                              .toList(),
                          onChanged: (val) => setState(() => _gender = val),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              _buildSectionTitle('Emergency Contact', isDark),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _emergencyContactController,
                label: 'Contact Name',
                hint: 'Emergency Contact Person',
                icon: Icons.contact_emergency_rounded,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _emergencyPhoneController,
                label: 'Phone Number',
                hint: '+1 234 567 890',
                icon: Icons.phone_rounded,
                keyboardType: TextInputType.phone,
                isDark: isDark,
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveDependent,
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
                          widget.editDependent != null ? 'Save Changes' : 'Add Profile',
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
