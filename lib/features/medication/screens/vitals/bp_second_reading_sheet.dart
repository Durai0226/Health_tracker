import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/design/app_colors_ext.dart';
import '../../../../core/widgets/app/app_widgets.dart';
import '../../models/blood_pressure_reading.dart';

/// "Take a second reading in 60 seconds" — shown once, right after a NEW blood
/// pressure reading is saved.
///
/// One reading is noisy; the guidance for home monitoring is two, about a
/// minute apart, averaged. This offers that and nothing more: the first reading
/// is already saved, "Skip" is always available, and the second one is an
/// ordinary log entry that joins the first through `BpSessions`.
class BpSecondReadingSheet {
  const BpSecondReadingSheet._();

  /// How long to rest before the second reading.
  static const int restSeconds = 60;

  /// Resolves `true` when the user wants to log the second reading now.
  static Future<bool> show(BuildContext context,
      {required BloodPressureReading first,
      required AccentSwatch accent}) async {
    final go = await AppBottomSheet.show<bool>(
      context,
      title: 'Take a second reading?',
      icon: Symbols.timer_rounded,
      accent: accent,
      builder: (ctx) => BpSecondReadingBody(
        first: first,
        onLog: () => Navigator.of(ctx).pop(true),
        onSkip: () => Navigator.of(ctx).pop(false),
      ),
    );
    return go == true;
  }
}

/// The sheet's content, separate so a test can drive it without a screen.
class BpSecondReadingBody extends StatefulWidget {
  const BpSecondReadingBody({
    super.key,
    required this.first,
    required this.onLog,
    required this.onSkip,
    this.seconds = BpSecondReadingSheet.restSeconds,
  });

  final BloodPressureReading first;
  final VoidCallback onLog;
  final VoidCallback onSkip;
  final int seconds;

  @override
  State<BpSecondReadingBody> createState() => _BpSecondReadingBodyState();
}

class _BpSecondReadingBodyState extends State<BpSecondReadingBody> {
  late final DateTime _deadline;
  Timer? _timer;
  late int _remaining;

  @override
  void initState() {
    super.initState();
    _deadline = clock.now().add(Duration(seconds: widget.seconds));
    _remaining = widget.seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  /// Computed from a deadline, not by counting ticks: a backgrounded app skips
  /// timer callbacks, and a count would still say 40 seconds after a minute
  /// away.
  void _tick() {
    final ms = _deadline.difference(clock.now()).inMilliseconds;
    final left = ms <= 0 ? 0 : (ms / 1000).ceil();
    if (!mounted) return;
    final becameReady = left == 0 && _remaining != 0;
    setState(() => _remaining = left);
    if (left == 0) _timer?.cancel();
    if (becameReady) {
      SemanticsService.announce('You can take your second reading now',
          Directionality.of(context));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _clockText =>
      '${_remaining ~/ 60}:${(_remaining % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final ready = _remaining == 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Saved ${widget.first.systolic}/${widget.first.diastolic}. A single '
          'reading can swing. Rest for a minute, stay seated and still, then '
          'measure again. The app will average the two.',
          style: tt.bodyMedium?.copyWith(color: ext.textSecondary, height: 1.4),
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: Semantics(
            label: ready ? 'Ready' : '$_remaining seconds left',
            excludeSemantics: true,
            child: Text(
              ready ? 'Ready' : _clockText,
              style: tt.displaySmall?.copyWith(
                  color: ext.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: AppRadius.brSm,
          child: LinearProgressIndicator(
            value: 1 - (_remaining / widget.seconds),
            minHeight: 6,
            color: ext.medicine.chart,
            backgroundColor: ext.medicine.container,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: ready ? 'Log second reading' : 'Second reading in $_remaining s',
          fullWidth: true,
          onPressed: ready ? widget.onLog : null,
        ),
        const SizedBox(height: AppSpacing.xs),
        AppButton(
          label: 'Skip',
          variant: AppButtonVariant.ghost,
          fullWidth: true,
          onPressed: widget.onSkip,
        ),
      ],
    );
  }
}
