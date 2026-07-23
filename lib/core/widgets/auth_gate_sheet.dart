import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'app/app_widgets.dart';
import '../services/auth_service.dart';
import '../services/haptic_service.dart';

/// Modern, calm sign-in sheet. Centered brand hero, a benefits strip, a clean
/// Google button (no network assets), and a clear primary/secondary hierarchy.
class AuthGateSheet extends StatefulWidget {
  final String featureName;
  final Color featureColor;
  final IconData featureIcon;
  final VoidCallback onContinueAsGuest;
  final VoidCallback onSignedIn;

  const AuthGateSheet({
    super.key,
    required this.featureName,
    required this.featureColor,
    required this.featureIcon,
    required this.onContinueAsGuest,
    required this.onSignedIn,
  });

  static Future<bool> show({
    required BuildContext context,
    required String featureName,
    required Color featureColor,
    required IconData featureIcon,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (context) => AuthGateSheet(
        featureName: featureName,
        featureColor: featureColor,
        featureIcon: featureIcon,
        onContinueAsGuest: () => Navigator.pop(context, true),
        onSignedIn: () => Navigator.pop(context, true),
      ),
    );
    return result ?? false;
  }

  @override
  State<AuthGateSheet> createState() => _AuthGateSheetState();
}

class _AuthGateSheetState extends State<AuthGateSheet>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final HapticService _hapticService = HapticService();

  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: AppMotion.slow,
  )..forward();
  late final Animation<double> _fade =
      CurvedAnimation(parent: _anim, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.10),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _anim, curve: AppMotion.emphasized));

  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    _hapticService.selection();
    try {
      final result = await _authService.signInWithGoogle();
      if (result == null) {
        _hapticService.success();
        if (mounted) widget.onSignedIn();
      } else if (result != 'cancelled') {
        setState(() {
          _error = result;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() {
        _error = 'Sign in failed. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: ext.surfaceElevated,
            borderRadius: AppRadius.brSheet,
            boxShadow: AppShadows.elevated(context),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, 12, AppSpacing.xl, AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Grab handle + close
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: ext.outlineStrong,
                          borderRadius: AppRadius.brFull,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => Navigator.pop(context, false),
                          icon: Icon(Symbols.close_rounded, color: ext.textTertiary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Brand hero
                  const AppLogo.raster(size: 68, radius: 8),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Welcome to ${widget.featureName}',
                      textAlign: TextAlign.center, style: tt.headlineSmall),
                  const SizedBox(height: 6),
                  Text(
                    'Sync your day across devices — or keep everything private on this one.',
                    textAlign: TextAlign.center,
                    style: tt.bodyMedium?.copyWith(color: ext.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Benefits strip
                  Row(
                    children: [
                      _benefit(ext, Symbols.cloud_done_rounded, 'Auto\nsync'),
                      _benefit(ext, Symbols.devices_rounded, 'All\ndevices'),
                      _benefit(ext, Symbols.lock_rounded, 'Private &\nsecure'),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  if (_error != null) ...[
                    _errorBox(ext, tt),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Primary — Google
                  _googleButton(ext, tt),
                  const SizedBox(height: AppSpacing.md),

                  // Secondary — guest
                  AppButton(
                    label: 'Continue as guest',
                    variant: AppButtonVariant.ghost,
                    fullWidth: true,
                    accent: ext.brand,
                    leadingIcon: Symbols.person_rounded,
                    onPressed: () {
                      _hapticService.selection();
                      widget.onContinueAsGuest();
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Symbols.shield_rounded, size: 14, color: ext.textTertiary),
                      const SizedBox(width: 6),
                      Text('Guest data stays on this device',
                          style: tt.bodySmall?.copyWith(color: ext.textTertiary)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _benefit(AppColorsExt ext, IconData icon, String label) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: ext.brand.container,
              borderRadius: AppRadius.brLg,
            ),
            child: Icon(icon, color: ext.brand.onContainer, size: 22),
          ),
          const SizedBox(height: 8),
          Text(label,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: ext.textSecondary, height: 1.2)),
        ],
      ),
    );
  }

  Widget _googleButton(AppColorsExt ext, TextTheme tt) {
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: Material(
        color: ext.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.brMd,
          side: BorderSide(color: ext.outlineStrong),
        ),
        child: InkWell(
          onTap: _isLoading ? null : _handleGoogleSignIn,
          child: Center(
            child: _isLoading
                ? SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: ext.brand.base),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _GoogleGlyph(size: 22),
                      const SizedBox(width: 12),
                      Text('Continue with Google',
                          style: tt.titleLarge?.copyWith(color: ext.textPrimary)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _errorBox(AppColorsExt ext, TextTheme tt) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ext.error.container,
        borderRadius: AppRadius.brMd,
      ),
      child: Row(
        children: [
          Icon(Symbols.error_rounded, color: ext.error.strong, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_error!,
                style: tt.bodySmall?.copyWith(color: ext.error.strong)),
          ),
        ],
      ),
    );
  }
}

/// A tasteful, self-contained Google "G" (Google-blue on white), no network.
class _GoogleGlyph extends StatelessWidget {
  final double size;
  const _GoogleGlyph({this.size = 22});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: Text(
        'G',
        style: TextStyle(
          fontSize: size * 0.82,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF4285F4),
          height: 1.0,
        ),
      ),
    );
  }
}
