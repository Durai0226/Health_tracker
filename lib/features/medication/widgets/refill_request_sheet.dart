import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/date_formats.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../models/doctor_pharmacy.dart';
import '../models/enhanced_medicine.dart';
import '../screens/refill_overview_screen.dart' show RefillAmountSheet;
import '../services/medicine_storage_service.dart';
import '../services/refill_loop.dart';

/// What the person did in the refill sheet.
enum RefillAction { requested, pickedUp }

/// [phone] reduced to what a dialler wants: digits and a leading `+`. A number
/// saved as "+91 98765 43210" would otherwise go out as `tel:+91%2098765%2043210`.
String dialable(String phone) => phone.replaceAll(RegExp(r'[^0-9+]'), '');

/// The text of a refill request message — what to ask, which prescription.
String refillMessageFor(EnhancedMedicine m) {
  final rx = (m.prescriptionNumber ?? '').trim();
  return 'Hello, could I refill ${m.name}'
      '${m.strength == null || m.strength!.isEmpty ? '' : ' ${m.strength}'}?'
      '${rx.isEmpty ? '' : ' Prescription $rx.'} Thank you.';
}

/// Opens the refill errand for one medicine: the pharmacy to call or message,
/// "I've asked for it", and "Picked up".
class RefillRequestFlow {
  const RefillRequestFlow._();

  /// Lets a test observe what would have been launched, without a platform.
  @visibleForTesting
  static Future<bool> Function(Uri uri) launcher =
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

  static Future<void> run(BuildContext context, String medicineId) async {
    final m = await MedicineCleanStorageService.getMedicine(medicineId);
    if (m == null || !context.mounted) return;
    final pharmacy = m.pharmacyId == null
        ? null
        : await MedicineCleanStorageService.getPharmacy(m.pharmacyId!);
    if (!context.mounted) return;

    final action = await AppBottomSheet.show<RefillAction>(
      context,
      title: 'Refill ${m.name}',
      icon: Symbols.inventory_2_rounded,
      accent: AppColorsExt.of(context).medicine,
      builder: (ctx) => RefillRequestForm(
        medicine: m,
        pharmacy: pharmacy,
        requestedAt: RefillRequestState.requestedAt(m.id),
        launch: launcher,
        onDone: (a) => Navigator.of(ctx).pop(a),
      ),
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case RefillAction.requested:
        await RefillLoop.markRequested(m.id, m.name);
        if (context.mounted) {
          context.toastSuccess(
              "Noted. We'll ask in ${RefillLoop.followUpDays} days whether you "
              'picked it up.');
        }
      case RefillAction.pickedUp:
        final amount = await showModalBottomSheet<int>(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (_) => RefillAmountSheet(medicineName: m.name),
        );
        if (amount == null) return;
        await MedicineCleanStorageService.refillStock(m.id, amount);
        if (context.mounted) context.toastSuccess('Added $amount to ${m.name}');
    }
  }
}

/// The sheet's content, separate so a test can drive it without a route.
class RefillRequestForm extends StatefulWidget {
  const RefillRequestForm({
    super.key,
    required this.medicine,
    required this.pharmacy,
    required this.requestedAt,
    required this.launch,
    required this.onDone,
  });

  final EnhancedMedicine medicine;
  final Pharmacy? pharmacy;

  /// When a refill was already asked for, or null.
  final DateTime? requestedAt;
  final Future<bool> Function(Uri uri) launch;
  final ValueChanged<RefillAction?> onDone;

  @override
  State<RefillRequestForm> createState() => _RefillRequestFormState();
}

class _RefillRequestFormState extends State<RefillRequestForm> {
  bool _launchFailed = false;

  Future<void> _open(Uri uri) async {
    final ok = await widget.launch(uri);
    if (mounted) setState(() => _launchFailed = !ok);
  }

  String? get _phone {
    final p = widget.pharmacy?.phone?.trim();
    return p == null || p.isEmpty ? null : p;
  }

  String? get _email {
    final e = widget.pharmacy?.email?.trim();
    return e == null || e.isEmpty ? null : e;
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final m = widget.medicine;
    final pharmacy = widget.pharmacy;
    final asked = widget.requestedAt;
    final phone = _phone;
    final email = _email;
    final message = refillMessageFor(m);

    final supply = [
      if (m.isStockTracked) '${m.currentStock ?? 0} left',
      if (m.isStockTracked && m.estimatedDaysRemaining >= 0)
        'about ${m.estimatedDaysRemaining} days',
    ].join(' · ');

    Widget gap([double h = AppSpacing.sm]) => SizedBox(height: h);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (supply.isNotEmpty)
          Text(supply, style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
        if (asked != null) ...[
          gap(AppSpacing.xs),
          Text('You asked on ${DateFormats.dayMonth.format(asked)}.',
              style: tt.bodyMedium?.copyWith(color: ext.textPrimary)),
        ],
        gap(AppSpacing.md),
        if (asked != null) ...[
          AppButton(
            label: 'Picked up',
            fullWidth: true,
            accent: ext.medicine,
            onPressed: () => widget.onDone(RefillAction.pickedUp),
          ),
          if (phone != null) ...[
            gap(),
            AppButton(
              label: 'Call ${pharmacy!.name} again',
              variant: AppButtonVariant.tonal,
              fullWidth: true,
              accent: ext.medicine,
              leadingIcon: Symbols.call_rounded,
              onPressed: () => _open(Uri(scheme: 'tel', path: dialable(phone))),
            ),
          ],
        ] else ...[
          if (pharmacy != null) ...[
            Text(pharmacy.name,
                style: tt.titleMedium?.copyWith(color: ext.textPrimary)),
            if ((pharmacy.hours ?? '').trim().isNotEmpty)
              Text(pharmacy.hours!.trim(),
                  style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
            gap(AppSpacing.md),
            if (phone != null) ...[
              AppButton(
                label: 'Call ${pharmacy.name}',
                fullWidth: true,
                accent: ext.medicine,
                leadingIcon: Symbols.call_rounded,
                onPressed: () => _open(Uri(scheme: 'tel', path: dialable(phone))),
              ),
              gap(),
              AppButton(
                label: 'Send a message',
                variant: AppButtonVariant.tonal,
                fullWidth: true,
                accent: ext.medicine,
                leadingIcon: Symbols.sms_rounded,
                onPressed: () => _open(Uri(
                    scheme: 'sms',
                    path: dialable(phone),
                    queryParameters: {'body': message})),
              ),
              gap(),
            ],
            if (email != null) ...[
              AppButton(
                label: 'Email',
                variant: AppButtonVariant.tonal,
                fullWidth: true,
                accent: ext.medicine,
                leadingIcon: Symbols.mail_rounded,
                onPressed: () => _open(Uri(
                    scheme: 'mailto',
                    path: email,
                    queryParameters: {
                      'subject': 'Refill: ${m.name}',
                      'body': message,
                    })),
              ),
              gap(),
            ],
          ] else ...[
            Text(
              'No pharmacy is saved for this medicine. Add one on its page and '
              'the call and message buttons appear here.',
              style: tt.bodyMedium?.copyWith(color: ext.textSecondary, height: 1.4),
            ),
            gap(AppSpacing.md),
          ],
          AppButton(
            label: "I've asked for it",
            variant: pharmacy == null || (phone == null && email == null)
                ? AppButtonVariant.primary
                : AppButtonVariant.tonal,
            fullWidth: true,
            accent: ext.medicine,
            onPressed: () => widget.onDone(RefillAction.requested),
          ),
          gap(),
          AppButton(
            label: 'Already picked up',
            variant: AppButtonVariant.ghost,
            fullWidth: true,
            accent: ext.medicine,
            onPressed: () => widget.onDone(RefillAction.pickedUp),
          ),
        ],
        if (_launchFailed) ...[
          gap(AppSpacing.xs),
          Text("Couldn't open that on this phone.",
              style: tt.bodySmall?.copyWith(color: ext.error.strong)),
        ],
      ],
    );
  }
}
