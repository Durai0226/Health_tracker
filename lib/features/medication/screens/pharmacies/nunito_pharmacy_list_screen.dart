import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../../core/widgets/app/app_widgets.dart';
import '../../../../core/widgets/confirmation_bottom_sheet.dart';
import '../../models/doctor_pharmacy.dart';
import '../../services/medicine_storage_service.dart';
import '../../../../core/services/contact_launcher.dart';
import '../../../../core/services/haptic_service.dart';
import 'nunito_add_edit_pharmacy_screen.dart';

/// The pharmacies a person uses, one tap from calling them. In selection mode a tap
/// returns the pharmacy instead of opening it, so a medicine can be linked to one.
class NunitoPharmacyListScreen extends StatefulWidget {
  final bool isSelectionMode;

  const NunitoPharmacyListScreen({super.key, this.isSelectionMode = false});

  @override
  State<NunitoPharmacyListScreen> createState() =>
      _NunitoPharmacyListScreenState();
}

class _NunitoPharmacyListScreenState extends State<NunitoPharmacyListScreen> {
  List<Pharmacy> _pharmacies = [];
  bool _isLoading = true;

  final HapticService _hapticService = HapticService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final all = await MedicineCleanStorageService.getAllPharmacies();
      if (mounted) {
        setState(() {
          _pharmacies = all;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading pharmacies: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addOrEdit({Pharmacy? pharmacy}) async {
    _hapticService.light();
    final result = await Navigator.push<Pharmacy>(
      context,
      MaterialPageRoute(
          builder: (_) => NunitoAddEditPharmacyScreen(editPharmacy: pharmacy)),
    );
    if (result == null || !mounted) return;
    await _load();
    // Picking for a medicine and having to add the pharmacy first: the one just made
    // is the one they came for.
    if (widget.isSelectionMode && pharmacy == null && mounted) {
      Navigator.pop(context, result);
    }
  }

  void _select(Pharmacy pharmacy) {
    if (widget.isSelectionMode) {
      Navigator.pop(context, pharmacy);
    } else {
      _addOrEdit(pharmacy: pharmacy);
    }
  }

  Future<void> _call(Pharmacy pharmacy) async {
    final phone = pharmacy.phone;
    if (phone == null || phone.isEmpty) return;
    // Digits only, through the one launcher the refill errand uses: a number typed as
    // "+91 98765 43210 #2" is not a URI as it stands.
    if (await ContactLauncher.call(phone)) return;
    if (!mounted) return;
    context.toastError('No phone app is available on this device.');
  }

  Future<void> _delete(Pharmacy pharmacy) async {
    final confirm = await ConfirmationBottomSheet.showDelete(
      context: context,
      itemName: 'pharmacy',
      customMessage:
          'Delete ${pharmacy.name}? Medicines linked to it will no longer have a pharmacy.',
    );
    if (confirm != true) return;
    _hapticService.error();
    try {
      await MedicineCleanStorageService.deletePharmacy(pharmacy.id);
    } catch (e) {
      debugPrint('Error deleting pharmacy: $e');
      if (mounted) context.toastError("Couldn't delete the pharmacy. Please try again.");
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final accent = ext.medicine;

    return AccentScope(
      feature: FeatureAccent.medicine,
      child: AppScaffold(
        // One primary action per state: the empty state carries the same button.
        floatingActionButton: _pharmacies.isEmpty
            ? null
            : AppFab(
                icon: Symbols.add_rounded,
                label: 'Add pharmacy',
                accent: accent,
                onPressed: () => _addOrEdit(),
              ),
        body: Column(
          children: [
            AppHeader(
              title: widget.isSelectionMode ? 'Select pharmacy' : 'Pharmacies',
              leading: AppHeader.backButton(context),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _pharmacies.isEmpty
                      ? ScrollableFill(
                          child: EmptyState(
                            icon: Symbols.local_pharmacy_rounded,
                            title: 'No pharmacies added',
                            message:
                                'Add the pharmacy you use, and a refill can call it for you.',
                            accent: accent,
                            action: AppButton(
                              label: 'Add pharmacy',
                              accent: accent,
                              leadingIcon: Symbols.add_rounded,
                              onPressed: () => _addOrEdit(),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                              AppSpacing.sm, AppSpacing.gutter, 96),
                          itemCount: _pharmacies.length,
                          itemBuilder: (context, i) =>
                              _card(_pharmacies[i], ext, accent),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(Pharmacy pharmacy, AppColorsExt ext, AccentSwatch accent) {
    final tt = Theme.of(context).textTheme;
    final detail = [
      if (pharmacy.hours != null && pharmacy.hours!.isNotEmpty) pharmacy.hours!,
      if (pharmacy.address != null && pharmacy.address!.isNotEmpty)
        pharmacy.address!,
    ].join(' · ');
    return Dismissible(
      key: Key(pharmacy.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: ext.error.base,
          borderRadius: AppRadius.brCard,
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Symbols.delete_rounded, color: ext.error.on),
      ),
      // Await the answer, THEN spring back: a confirm that is still open must not
      // have the card already settled.
      confirmDismiss: (direction) async {
        await _delete(pharmacy);
        return false;
      },
      child: AppCard(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        onTap: () => _select(pharmacy),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: accent.container,
                borderRadius: AppRadius.brLg,
              ),
              child: Icon(Symbols.local_pharmacy_rounded,
                  color: accent.onContainer, size: 28),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        pharmacy.name,
                        style: tt.titleLarge?.copyWith(color: ext.textPrimary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (pharmacy.hasDelivery)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: ext.success.container,
                            borderRadius: AppRadius.brSm,
                          ),
                          child: Text(
                            'Delivers',
                            maxLines: 1,
                            style: tt.labelSmall?.copyWith(
                              color: ext.success.onContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (detail.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: tt.bodySmall?.copyWith(color: ext.textTertiary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (pharmacy.phone != null && pharmacy.phone!.isNotEmpty)
              IconButton(
                onPressed: () => _call(pharmacy),
                icon: Icon(Symbols.phone_rounded,
                    color: ext.success.strong, size: 22),
                tooltip: 'Call',
              ),
          ],
        ),
      ),
    );
  }
}
