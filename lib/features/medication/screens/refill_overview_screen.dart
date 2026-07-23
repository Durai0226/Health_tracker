import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/widgets/app/app_widgets.dart';
import '../models/enhanced_medicine.dart';
import '../services/medicine_storage_service.dart';

/// A calm supply overview: per-medicine days-of-supply, low-stock and expiry
/// flags, and a one-tap "Refill". All computed locally from the user's own
/// stock + schedule — no pharmacy account, no network.
class RefillOverviewScreen extends StatefulWidget {
  const RefillOverviewScreen({super.key});

  @override
  State<RefillOverviewScreen> createState() => _RefillOverviewScreenState();
}

class _RefillOverviewScreenState extends State<RefillOverviewScreen> {
  List<EnhancedMedicine> _meds = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await MedicineCleanStorageService.init();
    final all = await MedicineCleanStorageService.getAllMedicines();
    // Only meds where supply/expiry is meaningful. currentStock is persisted
    // NOT-NULL (untracked coerces to 0), so `!= null` matched everything and the
    // "No supply tracked" empty state was unreachable — gate on a positive stock
    // count (or an expiry) instead so untracked meds drop out.
    final tracked = all
        .where((m) =>
            m.isActive &&
            !m.isArchived &&
            ((m.currentStock ?? 0) > 0 || m.expiryDate != null))
        .toList();
    // Flagged (low / expiring / expired) first, then by days remaining.
    int rank(EnhancedMedicine m) {
      if (m.isExpired) return 0;
      if (m.isLowStock) return 1;
      if (m.isExpiringSoon) return 2;
      return 3;
    }

    tracked.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      if (r != 0) return r;
      return a.estimatedDaysRemaining.compareTo(b.estimatedDaysRemaining);
    });
    if (mounted) {
      setState(() {
        _meds = tracked;
        _loading = false;
      });
    }
  }

  Future<void> _refill(EnhancedMedicine m) async {
    final amount = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _RefillAmountSheet(medicineName: m.name),
    );
    if (amount == null) return;
    await MedicineCleanStorageService.refillStock(m.id, amount);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Added $amount to ${m.name}'),
        behavior: SnackBarBehavior.floating,
      ));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    return AccentScope(
      feature: FeatureAccent.medicine,
      child: AppScaffold(
        body: Column(
          children: [
            AppHeader(
              title: 'Refill & supply',
              icon: Symbols.inventory_2_rounded,
              accent: ext.medicine,
              leading: AppIconButton(
                icon: Symbols.arrow_back_rounded,
                filled: false,
                tooltip: 'Back',
                accent: ext.medicine,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _meds.isEmpty
                      ? _empty(context)
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                              AppSpacing.md, AppSpacing.gutter, AppSpacing.xxl),
                          itemCount: _meds.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (_, i) => _tile(context, _meds[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: EmptyState(
          icon: Symbols.inventory_2_rounded,
          title: 'No supply tracked',
          message:
              'Add a stock count (and optional expiry) to a medicine to see '
              'days-of-supply and refill reminders here.',
          accent: AppColorsExt.of(context).medicine,
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, EnhancedMedicine m) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;

    // Status chip (most urgent wins), reserved status colours + a label.
    ({String label, AccentSwatch swatch})? flag;
    if (m.isExpired) {
      flag = (label: 'Expired', swatch: ext.error);
    } else if (m.isLowStock) {
      flag = (label: 'Low stock', swatch: ext.warning);
    } else if (m.isExpiringSoon) {
      flag = (label: 'Expiring soon', swatch: ext.warning);
    }

    final days = m.estimatedDaysRemaining;
    final supply = <String>[
      if (m.currentStock != null) '${m.currentStock} left',
      if (m.currentStock != null && days >= 0) '~$days days',
      if (m.expiryDate != null)
        'exp ${m.expiryDate!.day}/${m.expiryDate!.month}/${m.expiryDate!.year}',
    ].join(' · ');

    return AppCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (flag?.swatch ?? ext.medicine).container,
              borderRadius: AppRadius.brMd,
            ),
            child: Icon(Symbols.medication_rounded,
                size: 20, color: (flag?.swatch ?? ext.medicine).onContainer),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(m.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.titleMedium),
                    ),
                    if (flag != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: flag.swatch.container,
                          borderRadius: AppRadius.brFull,
                        ),
                        child: Text(flag.label,
                            style: tt.labelSmall?.copyWith(
                                color: flag.swatch.onContainer,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
                if (supply.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(supply,
                      style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppButton(
            label: 'Refill',
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.sm,
            accent: ext.medicine,
            leadingIcon: Symbols.add_rounded,
            onPressed: () => _refill(m),
          ),
        ],
      ),
    );
  }
}

/// Preset stock-add amounts.
class _RefillAmountSheet extends StatelessWidget {
  final String medicineName;
  const _RefillAmountSheet({required this.medicineName});

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    return AppBottomSheet(
      title: 'Refill $medicineName',
      icon: Symbols.inventory_2_rounded,
      accent: ext.medicine,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('How many units did you add?',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: ext.textSecondary)),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final n in const [10, 30, 60, 90])
                AppChip(
                  label: '+$n',
                  accent: ext.medicine,
                  onTap: () => Navigator.of(context).pop(n),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
