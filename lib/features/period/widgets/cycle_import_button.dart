import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';

import '../services/cycle_history_import.dart';
import '../services/cycle_import_source.dart';
import '../services/period_service.dart';
import 'prediction_card.dart' show fmtPeriodShort;

/// "Import from Health Connect": bring past periods in so the predictions start
/// with history instead of learning from the first cycle logged here.
///
/// Offered, never run on its own — the first tap asks the platform for the one
/// permission it needs, what was found is shown before anything is written, and
/// the toast that follows can take it all back.
class CycleImportButton extends StatefulWidget {
  const CycleImportButton({
    super.key,
    this.source = const HealthStoreCycleSource(),
    this.variant = AppButtonVariant.secondary,
  });

  final CycleImportSource source;
  final AppButtonVariant variant;

  /// What the confirmation says is about to be added.
  ///
  /// [fullHistory] false means the platform only shared about the last month, and
  /// the person is told so rather than left to wonder where the rest went.
  static String preview({
    required CycleImportPlan plan,
    required String store,
    required bool fullHistory,
  }) {
    final days = plan.toAdd.length;
    final periods = plan.periods;
    final first = plan.toAdd.first.day;
    final last = plan.toAdd.last.day;
    final span = first == last
        ? 'on ${_withYear(first)}'
        : 'between ${_withYear(first)} and ${_withYear(last)}';
    final out = StringBuffer(
        '$store has ${_days(days)} of bleeding $span, in $periods '
        '${periods == 1 ? 'period' : 'periods'}. ');
    if (plan.alreadyLogged > 0) {
      out.write('${_days(plan.alreadyLogged)} you already logged stay exactly '
          'as you logged them. ');
    }
    if (!fullHistory) {
      out.write('$store only shares about the last 30 days with this app, so '
          'earlier periods are not included. ');
    }
    out.write('You can undo this right after.');
    return out.toString();
  }

  static String _days(int n) => '$n day${n == 1 ? '' : 's'}';

  static String _withYear(DateTime d) => '${fmtPeriodShort(d)}, ${d.year}';

  @override
  State<CycleImportButton> createState() => _CycleImportButtonState();
}

class _CycleImportButtonState extends State<CycleImportButton> {
  bool _busy = false;

  CycleImportSource get _source => widget.source;

  Future<void> _import() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _run();
    } catch (e) {
      debugPrint('CycleImportButton: import failed: $e');
      if (mounted) {
        context.toastError('Could not import from ${_source.storeName}. '
            'Nothing was changed.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _run() async {
    final store = _source.storeName;

    var granted = await _source.allowed();
    granted = await _source.ask();
    if (!mounted) return;
    if (!granted) {
      context.toastInfo('$store did not share your cycle data, so nothing was '
          'imported. You can allow it any time in $store\'s settings.');
      return;
    }

    final fullHistory = await _source.fullHistory();
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final samples =
        await _source.read(today.subtract(CycleHistoryImport.lookback), now);
    if (!mounted) return;
    if (samples == null) {
      context.toastError('Could not read from $store. Please try again.');
      return;
    }

    final found = CycleHistoryImport.daysFrom(samples, now: now);
    if (found.isEmpty) {
      context.toastInfo('No periods found in $store from '
          '${fullHistory ? 'the last two years' : 'the last 30 days'}.');
      return;
    }
    final plan = CycleHistoryImport.plan(found, PeriodService.days);
    if (plan.isEmpty) {
      context.toastInfo('Everything $store has is already logged here.');
      return;
    }

    final go = await AppBottomSheet.confirm(
      context,
      title: 'Import your periods?',
      icon: Symbols.download_rounded,
      message: CycleImportButton.preview(
          plan: plan, store: store, fullHistory: fullHistory),
      confirmLabel: 'Import',
    );
    if (go != true || !mounted) return;

    final result = await CycleHistoryImport.apply(plan);
    if (!mounted) return;
    context.toastSuccess(
      'Imported ${result.days} day${result.days == 1 ? '' : 's'} from $store',
      action: AppToastAction(label: 'Undo', onPressed: () => _undo(result)),
    );
  }

  Future<void> _undo(CycleImportResult result) async {
    try {
      await CycleHistoryImport.undo(result);
    } catch (e) {
      debugPrint('CycleImportButton: undo failed: $e');
      if (mounted) {
        context.toastError('Could not undo the import. Nothing was changed.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: 'Import from ${_source.storeName}',
      variant: widget.variant,
      leadingIcon: Symbols.download_rounded,
      loading: _busy,
      onPressed: _import,
    );
  }
}
