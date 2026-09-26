import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/services/app_lock_service.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/widgets/confirmation_bottom_sheet.dart';
import '../../../core/constants/app_strings.dart';

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

  /// Whether to raise the biometric prompt automatically on first build.
  ///
  /// `false` when the caller has JUST prompted and been refused — Settings'
  /// identity check falls through to this screen after its own attempt, and
  /// prompting again 300ms later collided with the still-live session.
  final bool autoPromptBiometrics;

  const PinEntryScreen({
    super.key,
    required this.mode,
    this.onSuccess,
    this.setupTitle,
    this.autoPromptBiometrics = true,
  });

  @override
  State<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends State<PinEntryScreen>
    with WidgetsBindingObserver {
  final _service = AppLockService();

  String _entered = '';
  String? _firstPin; // setup mode: the first of the two confirmation rounds
  String? _error;
  bool _busy = false;
  bool _biometricAvailable = false;

  /// Its own flag, NOT [_busy]. `_busy` disables the keypad, and the keypad
  /// must stay usable while a prompt is up — the PIN is the fallback this whole
  /// feature promises. Before this the auto-fire and the button could overlap:
  /// `_tryBiometrics` read `_busy` and never set it.
  bool _biometricInFlight = false;

  /// Set when the prompt was cancelled by a pause, so [didChangeAppLifecycleState]
  /// can re-offer it exactly once on resume — the one thing `stickyAuth` used
  /// to do for us, without the process-wide flag it left behind.
  bool _reofferOnResume = false;

  /// What is left of [AppLockService.remainingLockout], mirrored into state so
  /// [_lockoutTicker] can count it down. `Duration.zero` means entry is open.
  Duration _lockout = Duration.zero;

  /// Ticks once a second for as long as a lockout is in force, and only then.
  Timer? _lockoutTicker;

  bool get _lockedOut => _lockout > Duration.zero;

  bool get _isSetup => widget.mode == PinEntryMode.setup;

  @override
  void initState() {
    super.initState();
    if (!_isSetup) {
      WidgetsBinding.instance.addObserver(this);
      _loadBiometricAvailability();
      // A lockout survives the screen: it is persisted, so it is already in
      // force on the first build after a relaunch.
      _syncLockout();
    }
  }

  @override
  void dispose() {
    _lockoutTicker?.cancel();
    if (!_isSetup) {
      WidgetsBinding.instance.removeObserver(this);
      // A session must not outlive the screen that started it. When the alarm
      // route suppressed this overlay mid-prompt, the prompt's success landed
      // on a disposed widget and nobody unlocked.
      if (_biometricInFlight) _service.cancelBiometrics();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!mounted) return;
    // Timers are throttled or stopped outright while backgrounded, so the
    // countdown can be minutes stale by the time we are looked at again.
    _syncLockout();
    if (!_reofferOnResume || _biometricInFlight) return;
    _reofferOnResume = false;
    _tryBiometrics();
  }

  /// Re-reads [AppLockService.remainingLockout] and keeps [_lockoutTicker]
  /// running for exactly as long as one is in force.
  ///
  /// Nothing outside the service read `remainingLockout` before, and
  /// [AppLockService.verifyPin] refuses outright while locked out — so the
  /// CORRECT PIN came back `false` and this screen told the user 'Incorrect
  /// PIN' for up to 30 minutes, with nothing to say what to wait for.
  void _syncLockout() {
    final remaining = _service.remainingLockout;
    if (remaining <= Duration.zero) {
      _lockoutTicker?.cancel();
      _lockoutTicker = null;
      // Only clear the message we put there ourselves.
      if (_lockedOut) {
        setState(() {
          _lockout = Duration.zero;
          _error = null;
        });
      }
      return;
    }
    _lockoutTicker ??=
        Timer.periodic(const Duration(seconds: 1), (_) => _syncLockout());
    setState(() {
      _lockout = remaining;
      _error = _lockoutMessage(remaining);
    });
  }

  /// 'Too many attempts — try again in 4m 59s'. Seconds are rounded UP so the
  /// countdown never reads 0s while entry is still refused.
  String _lockoutMessage(Duration remaining) {
    final total = (remaining.inMilliseconds / 1000).ceil();
    final minutes = total ~/ 60;
    final seconds = total % 60;
    return 'Too many attempts — try again in '
        '${minutes > 0 ? '${minutes}m ${seconds}s' : '${seconds}s'}';
  }

  Future<void> _loadBiometricAvailability() async {
    if (!_service.isBiometricPreferred) return;
    final can = await _service.canUseBiometrics();
    if (!mounted) return;
    setState(() => _biometricAvailable = can);
    if (can && widget.autoPromptBiometrics) {
      // Give the screen a beat to render before the OS prompt steals focus.
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) _tryBiometrics();
    }
  }

  Future<void> _tryBiometrics() async {
    if (_biometricInFlight) return;
    setState(() => _biometricInFlight = true);
    final outcome = await _service.authenticateWithBiometrics();
    if (!mounted) return;
    setState(() {
      _biometricInFlight = false;
      // Cancelled by the user or by a pause — re-offer once when we come back.
      // A user who backed out deliberately gets one more prompt after they
      // return from wherever they went, which is what sticky did too.
      _reofferOnResume = outcome == BiometricOutcome.cancelled;
      if (outcome.deservesMessage) {
        _error = switch (outcome) {
          BiometricOutcome.lockedOut =>
            'Too many attempts — use your PIN for now',
          _ => 'Biometrics unavailable — use your PIN',
        };
      }
    });
    if (outcome == BiometricOutcome.success) _handleUnlockSuccess();
  }

  void _onDigit(String digit) {
    // Nothing typed during a lockout can be right — verifyPin refuses every
    // PIN while one stands — so take the keypad out of service rather than
    // answer the user with 'Incorrect PIN' for a PIN that is correct.
    if (_busy || _lockedOut || _entered.length >= kPinLength) return;
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
      return;
    }
    HapticFeedback.heavyImpact();
    setState(() {
      _error = 'Incorrect PIN';
      _entered = '';
    });
    // That miss may have been the one that armed the lockout, and the attempt
    // AFTER it would be refused whatever the user types — so the message stops
    // blaming their typing from here on.
    _syncLockout();
  }

  void _handleUnlockSuccess() {
    _service.unlock();
    widget.onSuccess?.call();
  }

  Future<void> _onForgotPin() async {
    final confirmed = await ConfirmationBottomSheet.show(
      context: context,
      title: 'Reset PIN & erase data?',
      // Sign-out is named because resetForgottenPin() severs the cloud before
      // it wipes anything — otherwise the next sync would download the erased
      // data straight back. A signed-in user must not discover that after the
      // fact, on the one screen whose whole job is informed consent.
      message: "There's no way to recover a forgotten PIN — ${AppStrings.productName} "
          'never stores it, only a one-way hash. Continuing signs you out, '
          'permanently erases every medicine, reminder, water, sleep, period, '
          'step and vitals record on this device, then turns App Lock off. '
          'This cannot be undone.',
      confirmText: 'Erase everything',
      icon: Symbols.warning_amber_rounded,
      isDangerous: true,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await _service.resetForgottenPin();
    } catch (e) {
      // `clearAllPersistentData` rethrows on purpose — its doc says the error
      // is "rethrown for the caller to surface" — and resetForgottenPin's
      // `finally` has already turned the lock off by the time it arrives, so
      // the overlay dismisses itself either way. Caught nowhere, that read as
      // a completed erase: no success toast, no error, just the app.
      debugPrint('PIN reset could not finish erasing: $e');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _entered = '';
        _error = null;
      });
      context.toastError('PIN reset, but some data could not be erased. '
          'Try Settings → Delete all data.');
      return;
    }
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
          : 'Choose a $kPinLength-digit PIN to protect ${AppStrings.productName}';
    } else {
      title = 'Enter your PIN';
      subtitle = '${AppStrings.productName} is locked';
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
                // A minimum, not a fixed height: the message is a whole
                // sentence while a lockout counts down, and even the short
                // 'Incorrect PIN' is taller than 20 logical pixels once the
                // text scale is up. At exactly 20 both were cropped.
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 20),
                  child: _error == null
                      ? const SizedBox(width: double.infinity)
                      : Text(
                          _error!,
                          textAlign: TextAlign.center,
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
                    onPressed: (_busy || _biometricInFlight) ? null : _tryBiometrics,
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
          onTap: (_busy || _lockedOut) ? null : onTap,
          child: SizedBox(width: 72, height: 72, child: Center(child: child)),
        ),
      ),
    );
  }
}
