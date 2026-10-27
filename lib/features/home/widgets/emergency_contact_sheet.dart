import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/services/care_circle.dart';
import '../../../core/services/emergency_contact.dart';
import '../../../core/widgets/app/app_widgets.dart';

/// Who to reach in an emergency — for the account holder, who until now had
/// nowhere to put one.
class EmergencyContactSheet {
  const EmergencyContactSheet._();

  /// Resolves `true` when a contact was saved or removed.
  static Future<bool> show(BuildContext context) async {
    final changed = await AppBottomSheet.show<bool>(
      context,
      title: 'Emergency contact',
      icon: Symbols.contact_emergency_rounded,
      accent: AppColorsExt.of(context).brand,
      builder: (ctx) => EmergencyContactForm(onDone: (c) => Navigator.of(ctx).pop(c)),
    );
    return changed == true;
  }
}

/// The sheet's content, separate so a test can drive it without a route.
class EmergencyContactForm extends StatefulWidget {
  const EmergencyContactForm({super.key, required this.onDone});

  final ValueChanged<bool> onDone;

  @override
  State<EmergencyContactForm> createState() => _EmergencyContactFormState();
}

class _EmergencyContactFormState extends State<EmergencyContactForm> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  bool _saving = false;
  bool _offer = CareCircle.offerOnMissedDose;

  @override
  void initState() {
    super.initState();
    final c = EmergencyContact.get();
    _name = TextEditingController(text: c?.name ?? '');
    _phone = TextEditingController(text: c?.phone ?? '');
    _phone.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool get _valid => EmergencyContact.isDialable(_phone.text);

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    await EmergencyContact.save(name: _name.text, phone: _phone.text);
    widget.onDone(true);
  }

  Future<void> _remove() async {
    await EmergencyContact.clear();
    widget.onDone(true);
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final hasPhone = _phone.text.trim().isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Stored on this phone only. It is what the app will offer to call if '
          'a reading or a dose goes badly.',
          style: tt.bodyMedium?.copyWith(color: ext.textSecondary, height: 1.4),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _name,
          label: 'Name',
          hint: 'Priya',
          accent: ext.brand,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          controller: _phone,
          label: 'Phone number',
          hint: '+91 98765 43210',
          keyboardType: TextInputType.phone,
          accent: ext.brand,
        ),
        if (hasPhone && !_valid) ...[
          const SizedBox(height: AppSpacing.xs),
          Text('Enter a number that can be dialled.',
              style: tt.bodySmall?.copyWith(color: ext.error.strong)),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Save',
          fullWidth: true,
          onPressed: _valid && !_saving ? _save : null,
        ),
        if (EmergencyContact.isSet) ...[
          const SizedBox(height: AppSpacing.sm),
          // An offer on a missed dose, never an action: the app opens a message
          // and the person presses send. Off until they say so.
          AppListTile(
            icon: Symbols.sms_rounded,
            title: 'Offer to text them',
            subtitle: 'When I miss a dose',
            accent: ext.medicine,
            switchValue: _offer,
            onSwitchChanged: (v) {
              setState(() => _offer = v);
              CareCircle.setOfferOnMissedDose(v);
            },
          ),
          const SizedBox(height: AppSpacing.xs),
          AppButton(
            label: 'Remove',
            variant: AppButtonVariant.ghost,
            fullWidth: true,
            onPressed: _remove,
          ),
        ],
      ],
    );
  }
}
