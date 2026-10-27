import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/services/app_lock_service.dart';
import '../../../core/widgets/app/app_widgets.dart';
import 'pin_entry_screen.dart';
import '../../../core/constants/app_strings.dart';

/// "App lock" settings: a PIN toggle, "Change PIN", and — only on devices
/// that actually support it — a biometric shortcut switch. PIN is always the
/// base requirement; biometrics are never the only path (see
/// [AppLockService]'s doc comment for why).
class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() =>
      _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final _service = AppLockService();
  bool _canBiometrics = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricAvailability();
  }

  Future<void> _loadBiometricAvailability() async {
    final can = await _service.canUseBiometrics();
    if (mounted) setState(() => _canBiometrics = can);
  }

  /// Pushes [PinEntryScreen] in unlock mode to re-confirm the user's identity
  /// (PIN, or biometrics when available/preferred) before a sensitive action
  /// (turning app lock off, changing the PIN).
  Future<bool> _confirmIdentity() async {
    if (_canBiometrics && _service.isBiometricPreferred) {
      final outcome = await _service.authenticateWithBiometrics(
          reason: 'Confirm to continue');
      // Only a success from THIS call counts. Anything else — including
      // `busy`, which means some other screen's prompt is up — falls back to
      // the PIN rather than being treated as identity confirmed.
      if (outcome == BiometricOutcome.success) return true;
    }
    if (!mounted) return false;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (routeContext) => PinEntryScreen(
          mode: PinEntryMode.unlock,
          // We just prompted and were refused or cancelled. Prompting again
          // 300ms later is what collided with the session still in flight.
          autoPromptBiometrics: false,
          onSuccess: () => Navigator.of(routeContext).pop(true),
        ),
      ),
    );
    return result == true;
  }

  /// The two directions share nothing but the switch — on is a PIN-setup
  /// push, off is an identity check followed by three preference writes — and
  /// they were one method with a `return` in the middle, which put a
  /// `setState` after an `await` that only the OTHER branch performs.
  Future<void> _onToggleLock(bool enable) async {
    if (_busy) return;
    return enable ? _turnLockOn() : _turnLockOff();
  }

  Future<void> _turnLockOn() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (routeContext) => PinEntryScreen(
          mode: PinEntryMode.setup,
          setupTitle: 'Set a PIN',
          onSuccess: () => Navigator.of(routeContext).pop(true),
        ),
      ),
    );
    if (result == true && mounted) {
      context.toastSuccess('App lock is on.');
      setState(() {});
    }
  }

  Future<void> _turnLockOff() async {
    setState(() => _busy = true);
    final confirmed = await _confirmIdentity();
    if (!mounted) return;
    if (confirmed) {
      await _service.disableLock();
      // An early return, not `if (mounted)` around the toast alone: the
      // setState below sits outside this branch, so a screen popped during
      // the write reached it anyway.
      if (!mounted) return;
      context.toastInfo('App lock is off.');
    }
    setState(() => _busy = false);
  }

  Future<void> _onChangePin() async {
    if (_busy) return;
    setState(() => _busy = true);
    final confirmed = await _confirmIdentity();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!confirmed) return;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (routeContext) => PinEntryScreen(
          mode: PinEntryMode.setup,
          setupTitle: 'Change PIN',
          onSuccess: () => Navigator.of(routeContext).pop(true),
        ),
      ),
    );
    if (result == true && mounted) {
      context.toastSuccess('PIN updated.');
      setState(() {});
    }
  }

  Future<void> _onToggleBiometric(bool value) async {
    await _service.setBiometricPreferred(value);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _service.isLockEnabled;

    return AccentScope(
      feature: FeatureAccent.brand,
      child: AppScaffold(
        body: Column(
          children: [
            AppHeader(
              title: 'App lock',
              leading: AppHeader.backButton(context),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                    AppSpacing.sm, AppSpacing.gutter, AppSpacing.xxl),
                children: [
                  SettingsSection(
                    title: 'App lock',
                    footer: enabled
                        ? 'A PIN is required every time ${AppStrings.productName} is '
                          'opened or returned to after being in the '
                          'background for a while. Its screen is also hidden '
                          'in the recent-apps view, which means screenshots are '
                          'blocked while the lock is on (Android).'
                        : 'Require a PIN to open ${AppStrings.productName}.',
                    children: [
                      SettingsTile(
                        icon: Symbols.lock_rounded,
                        title: 'App lock',
                        subtitle: enabled ? 'On' : 'Off',
                        switchValue: enabled,
                        onSwitchChanged: _busy ? null : _onToggleLock,
                      ),
                      if (enabled)
                        SettingsTile(
                          icon: Symbols.password_rounded,
                          title: 'Change PIN',
                          onTap: _busy ? null : _onChangePin,
                        ),
                    ],
                  ),
                  if (enabled && _canBiometrics) ...[
                    const SizedBox(height: AppSpacing.xl),
                    SettingsSection(
                      title: 'Biometrics',
                      footer: 'Use your fingerprint or face as a shortcut. '
                          'Your PIN always still works, even if biometrics '
                          "fail or aren't set up.",
                      children: [
                        SettingsTile(
                          icon: Symbols.fingerprint_rounded,
                          title: 'Use biometrics',
                          switchValue: _service.isBiometricPreferred,
                          onSwitchChanged: _onToggleBiometric,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
