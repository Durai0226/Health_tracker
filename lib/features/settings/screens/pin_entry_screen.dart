import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/services/app_lock_service.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/widgets/confirmation_bottom_sheet.dart';

/// How many digits a PIN must be. Fixed app-wide so the keypad, the dot
/// indicator, and the auto-submit-on-last-digit logic all agree.
const int kPinLength = 4;

enum PinEntryMode { setup, unlock }

/// Numeric PIN pad — used both as the full-screen app-lock overlay
/// ([PinEntryMode.unlock], pushed by [AppLockGate]) and as a normal pushed
/// route for first-time setup / "Change PIN" ([PinEntryMode.setup]) and for
/// re-confirming identity before turning app lock off.
///
/// Deliberately does not touch `Navigator` for its main success path — when
/// used as the [AppLockGate] overlay there is no ancestor `Navigator` above
/// it (the overlay sits beside the app's own Navigator in a `Stack`, not
/// inside it). Callers that push this screen as a normal route pass
/// [onSuccess] and pop themselves.
class PinEntryScreen extends StatefulWidget {
  final PinEntryMode mode;

  /// Called after a correct PIN (or biometric) confirms identity — for
  /// [PinEntryMode.unlock] that's a successful unlock; for
  /// [PinEntryMode.setup] that's a freshly-confirmed new PIN having been
  /// saved. Optional: the app-lock overlay leaves this null since
  /// [AppLockService.isLockedNotifier] flipping is what dismisses it.
  final VoidCallback? onSuccess;

  /// Setup mode only: shown as the screen's title/subtitle context, e.g.
  /// "Change PIN" vs the default "Set a PIN".
  final String? setupTitle;

  const PinEntryScreen({
    super.key,
    required this.mode,
    this.onSuccess,
    this.setupTitle,
  });

  @override
  State<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends State<PinEntryScreen> {
  final _service = AppLockService();

  String _entered = '';
  String? _firstPin; // setup mode: the first of the two confirmation rounds
  String? _error;
  bool _busy = false;
  bool _biometricAvailable = false;

  bool get _isSetup => widget.mode == PinEntryMode.setup;

  @override
  void initState() {
    super.initState();
    if (!_isSetup) _loadBiometricAvailability();
  }

  Future<void> _loadBiometricAvailability() async {
    if (!_service.isBiometricPreferred) return;
    final can = await _service.canUseBiometrics();
    if (!mounted) return;
    setState(() => _biometricAvailable = can);
    if (can) {
      // Give the screen a beat to render before the OS prompt steals focus.
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) _tryBiometrics();
    }
  }

  Future<void> _tryBiometrics() async {
    if (_busy) return;
    final ok = await _service.authenticateWithBiometrics();
    if (ok && mounted) _handleUnlockSuccess();
  }

  void _onDigit(String digit) {
    if (_busy || _entered.length >= kPinLength) return;
    HapticFeedback.selectionClick();
    setState(() {
      _entered += digit;
      _error = null;
    });
    if (_entered.length == kPinLength) _submit();
  }

  void _onBackspace() {
    if (_busy || _entered.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  Future<void> _submit() async {
    if (_isSetup) {
      await _submitSetup();
    } else {
      _submitUnlock();
    }
  }

  Future<void> _submitSetup() async {
    if (_firstPin == null) {
      setState(() {
        _firstPin = _entered;
        _entered = '';
      });
      return;
    }
    if (_entered != _firstPin) {
      HapticFeedback.heavyImpact();
      setState(() {
        _error = "PINs didn't match — try again";
        _entered = '';
        _firstPin = null;
      });
      return;
    }
    setState(() => _busy = true);
    await _service.setPin(_entered);
    if (!mounted) return;
    setState(() => _busy = false);
    widget.onSuccess?.call();
  }

  void _submitUnlock() {
    if (_service.verifyPin(_entered)) {
      _handleUnlockSuccess();
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _error = 'Incorrect PIN';
        _entered = '';
      });
    }
  }

  void _handleUnlockSuccess() {
    _service.unlock();
    widget.onSuccess?.call();
  }

  Future<void> _onForgotPin() async {
    final confirmed = await ConfirmationBottomSheet.show(
      context: context,
      title: 'Reset PIN & erase data?',
      message: "There's no way to recover a forgotten PIN — DailyMinder "
          'never stores it, only a one-way hash. Continuing permanently '
          'erases every medicine, reminder, water, sleep, period, step and '
          'vitals record on this device, then turns App Lock off. This '
          'cannot be undone.',
      confirmText: 'Erase everything',
      icon: Symbols.warning_amber_rounded,
      isDangerous: true,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    await _service.resetForgottenPin();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _entered = '';
      _error = null;
    });
    context.toastInfo('PIN reset. All local data was erased.');
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final canPop = Navigator.maybeOf(context)?.canPop() ?? false;
    final confirming = _isSetup && _firstPin != null;

    final String title;
    final String subtitle;
    if (_isSetup) {
      title = confirming
          ? 'Confirm your PIN'
          : (widget.setupTitle ?? 'Set a PIN');
      subtitle = confirming
          ? 'Enter it once more to confirm'
          : 'Choose a $kPinLength-digit PIN to protect DailyMinder';
    } else {
      title = 'Enter your PIN';
      subtitle = 'DailyMinder is locked';
    }

    return AccentScope(
      feature: FeatureAccent.brand,
      child: AppScaffold(
        dismissKeyboardOnTap: false,
        // A SingleChildScrollView (rather than Expanded/Spacer) keeps this
        // screen safe on short viewports — a small phone, a tablet split-
        // screen, or a test surface — instead of overflowing the keypad off
        // the bottom of the screen.
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canPop)
                  Align(
                    alignment: Alignment.topLeft,
                    child: AppIconButton(
                      icon: Symbols.close_rounded,
                      filled: false,
                      accent: ext.brand,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  )
                else
                  const SizedBox(height: 44),
                const SizedBox(height: AppSpacing.lg),
                Icon(Symbols.lock_rounded, size: 40, color: ext.mark(ext.brand)),
                const SizedBox(height: AppSpacing.md),
                Text(title, style: tt.headlineLarge, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.xs),
                Text(subtitle,
                    style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
                    textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.xl),
                _buildDots(ext),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 20,
                  child: _error == null
                      ? null
                      : Text(
                          _error!,
                          style:
                              tt.bodyMedium?.copyWith(color: ext.mark(ext.error)),
                        ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildKeypad(ext),
                if (!_isSetup && _biometricAvailable) ...[
                  const SizedBox(height: AppSpacing.sm),
                  TextButton.icon(
                    key: const Key('pinBiometricButton'),
                    onPressed: _busy ? null : _tryBiometrics,
                    icon: Icon(Symbols.fingerprint_rounded,
                        color: ext.mark(ext.brand)),
                    label: Text('Use biometrics',
                        style: tt.labelLarge?.copyWith(color: ext.mark(ext.brand))),
                  ),
                ],
                if (!_isSetup) ...[
                  const SizedBox(height: AppSpacing.xs),
                  TextButton(
                    key: const Key('pinForgotLink'),
                    onPressed: _busy ? null : _onForgotPin,
                    child: Text('Forgot PIN?',
                        style: tt.labelLarge?.copyWith(color: ext.textSecondary)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDots(AppColorsExt ext) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(kPinLength, (i) {
        final filled = i < _entered.length;
        return Container(
          key: Key('pinDot_$i${filled ? '_filled' : ''}'),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? ext.mark(ext.brand) : Colors.transparent,
            border: Border.all(color: ext.outlineStrong, width: 1.5),
          ),
        );
      }),
    );
  }

  Widget _buildKeypad(AppColorsExt ext) {
    const rows = <List<String>>[
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'back'],
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((key) {
              if (key.isEmpty) return const SizedBox(width: 72, height: 72);
              if (key == 'back') {
                return _keypadButton(
                  ext,
                  keyId: 'pinBackspace',
                  child: Icon(Symbols.backspace_rounded, color: ext.textPrimary),
                  onTap: _onBackspace,
                );
              }
              return _keypadButton(
                ext,
                keyId: 'pinDigit_$key',
                child: Text(key,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(color: ext.textPrimary)),
                onTap: () => _onDigit(key),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _keypadButton(
    AppColorsExt ext, {
    required String keyId,
    required Widget child,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Material(
        key: Key(keyId),
        color: ext.surfaceVariant,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _busy ? null : onTap,
          child: SizedBox(width: 72, height: 72, child: Center(child: child)),
        ),
      ),
    );
  }
}
