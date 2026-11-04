import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/services/health_data_service.dart';
import '../../../core/services/health_store_name.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/widgets/health_import_turn_on.dart';
import '../services/vitals_health_import.dart';

/// Where blood-pressure and blood-sugar readings are brought in from: the
/// phone's health store.
///
/// A seam, so the flow that asks, reads and reports can be driven without the
/// platform plugin, which headless tests cannot reach.
abstract class VitalsImportSource {
  /// "Health Connect" or "Apple Health".
  String get storeName;

  /// Whether readings may already be read: true or false when the platform says,
  /// null when it could not be asked right now. Null is not "no" — a caller that
  /// switches the person's choice off must do it on a no, not on a failed look.
  Future<bool?> allowed();

  /// Ask to read them — and to READ, nothing more. True only when the grant is
  /// confirmed.
  Future<bool> ask();

  /// Read, keep what is new, and say what was kept.
  Future<VitalsImportResult> run();
}

/// The real source: [VitalsHealthImport] over [HealthDataService].
class HealthStoreVitalsSource implements VitalsImportSource {
  const HealthStoreVitalsSource();

  @override
  String get storeName => healthStoreName();

  @override
  Future<bool?> allowed() => HealthDataService.instance.vitalsReadAccess();

  /// Reading blood pressure and sugar is all the import does, so that is all it
  /// asks for: no writing, no weight. (It used to ask for the sharing switch's
  /// grant, and showed a sheet asking to write to a person who only wanted a
  /// cuff's readings brought in.) The answer is checked afterwards, where the
  /// platform will say, rather than taken from the request.
  @override
  Future<bool> ask() => HealthDataService.instance.requestVitalsReadPermission();

  @override
  Future<VitalsImportResult> run() => VitalsHealthImport.run();
}

/// "Import from Health Connect" and the switch that makes it automatic: ask once,
/// read, say what happened, and offer to take it back.
class VitalsImportFlow {
  const VitalsImportFlow._();

  /// One import, on the person's say-so. Null when nothing was brought in.
  static Future<VitalsImportResult?> run(
    BuildContext context, {
    VitalsImportSource source = const HealthStoreVitalsSource(),
  }) async {
    final store = source.storeName;
    try {
      var granted = await source.allowed() == true;
      if (!granted) granted = await source.ask();
      if (!context.mounted) return null;
      if (!granted) {
        _declined(context, store);
        return null;
      }
      final result = await source.run();
      if (!context.mounted) return result.isEmpty ? null : result;
      _report(context, result, store);
      return result.isEmpty ? null : result;
    } on HealthReadException catch (e) {
      debugPrint('VitalsImportFlow: the health store could not be read: $e');
      if (context.mounted) {
        context.toastError('$store did not answer just now. Nothing was '
            'imported — try again in a moment.');
      }
      return null;
    } catch (e) {
      debugPrint('VitalsImportFlow: import failed: $e');
      if (context.mounted) {
        context.toastError('Could not import from $store. Please try again.');
      }
      return null;
    }
  }

  /// The switch turned on: ask if needed, remember it, and read straight away.
  /// True when it is now on. The order of events, and what a failed first read
  /// does to the choice, are [HealthImportTurnOn]'s, shared with the other imports.
  static Future<bool> turnOn(
    BuildContext context, {
    VitalsImportSource source = const HealthStoreVitalsSource(),
  }) {
    final store = source.storeName;
    return HealthImportTurnOn.run<VitalsImportResult>(
      context,
      name: 'VitalsImportFlow',
      allowed: () async => await source.allowed() == true,
      ask: source.ask,
      setEnabled: VitalsHealthImport.setEnabled,
      read: source.run,
      declinedMessage: _declinedMessage(store),
      silentMessage: 'Switched on, but $store did not answer just now. '
          'New readings will appear when it does.',
      report: (context, result) {
        if (result.isEmpty) {
          context.toastInfo('Switched on. New readings from $store will appear '
              'here by themselves.');
        } else {
          _report(context, result, store);
        }
      },
    );
  }

  static String _declinedMessage(String store) =>
      '$store did not share your readings, so nothing was imported. You can '
      'allow it any time in $store\'s settings.';

  static void _declined(BuildContext context, String store) =>
      context.toastInfo(_declinedMessage(store));

  static void _report(BuildContext context, VitalsImportResult r, String store) {
    if (r.isEmpty) {
      context.toastInfo('No new readings in $store.');
      return;
    }
    context.toastSuccess(
      'Brought in ${r.describe()} from $store',
      action: AppToastAction(
        label: 'Undo',
        onPressed: () => VitalsHealthImport.undo(r),
      ),
    );
  }
}

/// A button for an empty tracker: the readings may already be in the health app.
class VitalsImportButton extends StatefulWidget {
  const VitalsImportButton({
    super.key,
    this.source = const HealthStoreVitalsSource(),
  });

  final VitalsImportSource source;

  @override
  State<VitalsImportButton> createState() => _VitalsImportButtonState();
}

class _VitalsImportButtonState extends State<VitalsImportButton> {
  bool _busy = false;

  Future<void> _import() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await VitalsImportFlow.run(context, source: widget.source);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: 'Import from ${widget.source.storeName}',
      variant: AppButtonVariant.secondary,
      leadingIcon: Symbols.download_rounded,
      fullWidth: true,
      loading: _busy,
      onPressed: _import,
    );
  }
}
