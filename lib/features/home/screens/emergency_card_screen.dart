import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/health/emergency_card.dart';
import '../../../core/services/active_profile_service.dart';
import '../../../core/services/contact_launcher.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../medication/screens/dependents/add_edit_dependent_screen.dart';
import '../services/emergency_card_export.dart';
import '../services/emergency_card_service.dart';
import '../widgets/emergency_card_view.dart';
import '../widgets/emergency_contact_sheet.dart';

/// Allergies, conditions, medicines and who to call, on one card that reads at
/// a glance, with a call button and a picture of it to put on a lock screen.
///
/// It is the card of whoever is active: yours, or the person you look after.
class EmergencyCardScreen extends StatefulWidget {
  const EmergencyCardScreen({super.key});

  @override
  State<EmergencyCardScreen> createState() => _EmergencyCardScreenState();
}

class _EmergencyCardScreenState extends State<EmergencyCardScreen> {
  final _boundary = GlobalKey();
  EmergencyCardData? _data;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await EmergencyCardService.load();
    if (!mounted) return;
    setState(() => _data = data);
  }

  Future<void> _call(EmergencyCardContact contact) async {
    final opened = await ContactLauncher.call(contact.phone);
    if (opened || !mounted) return;
    context.toastError(
      'Could not open the dialer. The number is ${contact.phone}.',
      title: 'Could not call',
    );
  }

  Future<void> _sharePicture() async {
    final data = _data;
    if (data == null || _sharing) return;
    setState(() => _sharing = true);
    try {
      final png = await EmergencyCardExport.capture(_boundary);
      if (png == null) {
        if (mounted) context.toastError('The card is not on screen yet. Try again.');
        return;
      }
      await EmergencyCardExport.share(png, data.card.toPlainText());
    } catch (e) {
      debugPrint('⚠️ Sharing the emergency card failed: $e');
      if (mounted) context.toastError('Could not share the card.');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  /// All of it, in the profile form.
  Future<void> _edit() async {
    final profile = _data?.profile;
    if (profile == null) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => AddEditDependentScreen(editDependent: profile)));
    if (mounted) await _load();
  }

  /// A contact on its own: two fields for yourself, the profile form for
  /// someone you look after (whose contact lives on their profile).
  Future<void> _addContact() async {
    if (ActiveProfileService().isSelfActive) {
      await EmergencyContactSheet.show(context);
      if (mounted) await _load();
    } else {
      await _edit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final data = _data;
    final contact = data?.card.contact;
    return AppScaffold(
      body: Column(
        children: [
          AppHeader(
            title: 'Emergency card',
            leading: AppHeader.backButton(context),
          ),
          Expanded(
            child: data == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.gutter, AppSpacing.md, AppSpacing.gutter, AppSpacing.xxl),
                    children: [
                      RepaintBoundary(
                          key: _boundary, child: EmergencyCardView(card: data.card)),
                      const SizedBox(height: AppSpacing.lg),
                      if (contact != null)
                        AppButton(
                          label: contact.name.isEmpty
                              ? 'Call ${contact.phone}'
                              : 'Call ${contact.name}',
                          leadingIcon: Symbols.call_rounded,
                          fullWidth: true,
                          size: AppButtonSize.lg,
                          accent: ext.error,
                          onPressed: () => _call(contact),
                        )
                      else
                        AppButton(
                          label: 'Add an emergency contact',
                          leadingIcon: Symbols.contact_emergency_rounded,
                          variant: AppButtonVariant.tonal,
                          fullWidth: true,
                          accent: ext.error,
                          onPressed: _addContact,
                        ),
                      const SizedBox(height: AppSpacing.sm),
                      AppButton(
                        label: 'Share as a picture',
                        leadingIcon: Symbols.ios_share_rounded,
                        variant: AppButtonVariant.tonal,
                        fullWidth: true,
                        loading: _sharing,
                        accent: ext.medicine,
                        onPressed: _sharePicture,
                      ),
                      if (data.profile != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        AppButton(
                          label: 'Edit details',
                          leadingIcon: Symbols.edit_rounded,
                          variant: AppButtonVariant.ghost,
                          fullWidth: true,
                          accent: ext.medicine,
                          onPressed: _edit,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Kept on this device. A picture of it can be read by anyone who '
                        'sees your lock screen, or the chat you send it to.',
                        style: tt.bodySmall?.copyWith(color: ext.textTertiary, height: 1.35),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
