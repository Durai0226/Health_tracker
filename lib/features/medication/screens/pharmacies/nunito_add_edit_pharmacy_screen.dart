import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/widgets/app/app_widgets.dart';
import '../../models/doctor_pharmacy.dart';
import '../../services/medicine_storage_service.dart';
import '../../../../core/services/haptic_service.dart';

/// Add a pharmacy, or change one.
///
/// A medicine can be linked to one, and "Refill" then offers to call it. The
/// pharmacy table and its storage methods had no screen, so nothing could be linked.
/// Only what is stored is asked for: name, phone, address, opening hours, whether it
/// delivers, and a note.
class NunitoAddEditPharmacyScreen extends StatefulWidget {
  final Pharmacy? editPharmacy;

  const NunitoAddEditPharmacyScreen({super.key, this.editPharmacy});

  @override
  State<NunitoAddEditPharmacyScreen> createState() =>
      _NunitoAddEditPharmacyScreenState();
}

class _NunitoAddEditPharmacyScreenState
    extends State<NunitoAddEditPharmacyScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _hasDelivery = false;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _hoursController = TextEditingController();
  final _notesController = TextEditingController();

  final HapticService _hapticService = HapticService();

  bool get _isEditing => widget.editPharmacy != null;

  @override
  void initState() {
    super.initState();
    final p = widget.editPharmacy;
    if (p != null) {
      _nameController.text = p.name;
      _phoneController.text = p.phone ?? '';
      _addressController.text = p.address ?? '';
      _hoursController.text = p.hours ?? '';
      _notesController.text = p.notes ?? '';
      _hasDelivery = p.hasDelivery;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _hoursController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String? _orNull(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _save() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final pharmacy = Pharmacy(
        id: _isEditing ? widget.editPharmacy!.id : const Uuid().v4(),
        name: _nameController.text.trim(),
        phone: _orNull(_phoneController),
        address: _orNull(_addressController),
        hours: _orNull(_hoursController),
        hasDelivery: _hasDelivery,
        notes: _orNull(_notesController),
      );
      await MedicineCleanStorageService.savePharmacy(pharmacy);
      _hapticService.success();
      if (mounted) Navigator.pop(context, pharmacy);
    } catch (e) {
      debugPrint('Error saving pharmacy: $e');
      _hapticService.error();
      if (mounted) {
        context.toastError('Could not save this pharmacy. Please try again.');
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final accent = ext.medicine;
    final tt = Theme.of(context).textTheme;

    return AccentScope(
      feature: FeatureAccent.medicine,
      child: AppScaffold(
        body: Column(
          children: [
            AppHeader(
              title: _isEditing ? 'Edit pharmacy' : 'Add pharmacy',
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
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionHeader(
                            title: 'Basic information',
                            icon: Symbols.local_pharmacy_rounded,
                            accent: accent,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          AppTextField(
                            controller: _nameController,
                            label: 'Name',
                            hint: "Pharmacy's name",
                            prefixIcon: Symbols.storefront_rounded,
                            accent: accent,
                            textCapitalization: TextCapitalization.words,
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Name is required'
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.lg),
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
                            controller: _addressController,
                            label: 'Address',
                            hint: 'Where it is',
                            prefixIcon: Symbols.location_on_rounded,
                            accent: accent,
                            maxLines: 2,
                            textCapitalization: TextCapitalization.sentences,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AppTextField(
                            controller: _hoursController,
                            label: 'Opening hours',
                            hint: 'e.g. 9 am – 9 pm, or open 24 hours',
                            prefixIcon: Symbols.schedule_rounded,
                            accent: accent,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppCard(
                      onTap: () {
                        _hapticService.toggle();
                        setState(() => _hasDelivery = !_hasDelivery);
                      },
                      child: Row(
                        children: [
                          Icon(Symbols.local_shipping_rounded,
                              color: _hasDelivery
                                  ? ext.mark(accent)
                                  : ext.textTertiary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Delivers',
                                    style: tt.titleLarge
                                        ?.copyWith(color: ext.textPrimary)),
                                Text('They bring medicines to your door',
                                    style: tt.bodySmall
                                        ?.copyWith(color: ext.textSecondary)),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppRowMetrics.trailingGap),
                          AppSwitch(
                            value: _hasDelivery,
                            onChanged: (v) {
                              _hapticService.toggle();
                              setState(() => _hasDelivery = v);
                            },
                            accent: accent,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
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
                            hint: 'Anything worth remembering',
                            prefixIcon: Symbols.sticky_note_2_rounded,
                            accent: accent,
                            maxLines: 3,
                            textCapitalization: TextCapitalization.sentences,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppButton(
                      label: _isEditing ? 'Save changes' : 'Add pharmacy',
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
