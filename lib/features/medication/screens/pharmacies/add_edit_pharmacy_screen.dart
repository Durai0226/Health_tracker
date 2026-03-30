import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../models/doctor_pharmacy.dart';
import '../../services/medicine_storage_service.dart';

class AddEditPharmacyScreen extends StatefulWidget {
  final Pharmacy? editPharmacy;

  const AddEditPharmacyScreen({super.key, this.editPharmacy});

  @override
  State<AddEditPharmacyScreen> createState() => _AddEditPharmacyScreenState();
}

class _AddEditPharmacyScreenState extends State<AddEditPharmacyScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _emailController;
  late TextEditingController _websiteController;
  late TextEditingController _hoursController;
  late TextEditingController _notesController;
  bool _hasDelivery = false;
  bool _isPrimary = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.editPharmacy?.name);
    _phoneController = TextEditingController(text: widget.editPharmacy?.phone);
    _addressController = TextEditingController(text: widget.editPharmacy?.address);
    _emailController = TextEditingController(text: widget.editPharmacy?.email);
    _websiteController = TextEditingController(text: widget.editPharmacy?.website);
    _hoursController = TextEditingController(text: widget.editPharmacy?.hours);
    _notesController = TextEditingController(text: widget.editPharmacy?.notes);
    _hasDelivery = widget.editPharmacy?.hasDelivery ?? false;
    _isPrimary = widget.editPharmacy?.isPrimary ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _hoursController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _savePharmacy() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final pharmacy = Pharmacy(
        id: widget.editPharmacy?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
        hours: _hoursController.text.trim().isEmpty ? null : _hoursController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        hasDelivery: _hasDelivery,
        isPrimary: _isPrimary,
      );

      if (widget.editPharmacy != null) {
        await MedicineCleanStorageService.updatePharmacy(pharmacy);
      } else {
        await MedicineCleanStorageService.addPharmacy(pharmacy);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.editPharmacy != null ? 'Pharmacy updated' : 'Pharmacy added'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving pharmacy: $e'),
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
        title: Text(widget.editPharmacy != null ? 'Edit Pharmacy' : 'Add Pharmacy'),
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
                label: 'Pharmacy Name',
                hint: 'CVS Pharmacy, Walgreens...',
                icon: Icons.local_pharmacy_rounded,
                validator: (v) => v?.trim().isEmpty == true ? 'Name is required' : null,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _hoursController,
                label: 'Opening Hours',
                hint: 'Mon-Fri 9am-9pm',
                icon: Icons.access_time_rounded,
                isDark: isDark,
              ),
              
              const SizedBox(height: 24),
              _buildSectionTitle('Contact Details', isDark),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _phoneController,
                label: 'Phone',
                hint: '+1 234 567 890',
                icon: Icons.phone_rounded,
                keyboardType: TextInputType.phone,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _addressController,
                label: 'Address',
                hint: '123 Main St',
                icon: Icons.location_on_rounded,
                maxLines: 2,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _websiteController,
                label: 'Website',
                hint: 'www.pharmacy.com',
                icon: Icons.language_rounded,
                keyboardType: TextInputType.url,
                isDark: isDark,
              ),

              const SizedBox(height: 24),
              _buildSectionTitle('Additional', isDark),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Home Delivery',
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Offers delivery service',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                value: _hasDelivery,
                onChanged: (val) => setState(() => _hasDelivery = val),
                activeColor: AppColors.primary,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Primary Pharmacy',
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Mark as your main pharmacy',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                value: _isPrimary,
                onChanged: (val) => setState(() => _isPrimary = val),
                activeColor: AppColors.primary,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _notesController,
                label: 'Notes',
                hint: 'Insurance accepted, refill policy...',
                icon: Icons.note_rounded,
                maxLines: 3,
                isDark: isDark,
              ),
              
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _savePharmacy,
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
                          widget.editPharmacy != null ? 'Save Changes' : 'Add Pharmacy',
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
