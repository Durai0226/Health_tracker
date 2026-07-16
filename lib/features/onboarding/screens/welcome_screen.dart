import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/clean_storage_service.dart';
import '../../../core/widgets/auth_gate_sheet.dart';
import '../../home/screens/app_shell.dart';

/// Calm Clarity entry screen: a clean wordmark, an honest snapshot of the four
/// features, and one calm call to action. Entrance-only motion, dark-aware.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    duration: const Duration(milliseconds: 900),
    vsync: this,
  );
  late final Animation<double> _fade =
      CurvedAnimation(parent: _enter, curve: const Interval(0.0, 0.6, curve: Curves.easeOut));
  late final Animation<double> _slide =
      Tween<double>(begin: 28, end: 0).animate(
          CurvedAnimation(parent: _enter, curve: const Interval(0.1, 1.0, curve: Curves.easeOutCubic)));

  @override
  void initState() {
    super.initState();
    _enter.forward();
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  Future<void> _getStarted() async {
    HapticFeedback.mediumImpact();
    final auth = AuthService();
    if (!auth.isAuthenticated) {
      final proceed = await AuthGateSheet.show(
        context: context,
        featureName: 'DailyMinder',
        featureColor: AppColorsExt.of(context).brand.base,
        featureIcon: Icons.event_available_rounded,
      );
      if (proceed != true) return;
    }
    // Mark onboarding complete so returning users land straight on Home.
    await CleanStorageService.setFirstLaunchComplete();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: AppMotion.slow,
        pageBuilder: (_, __, ___) => const AppShell(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;

    return AppScaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: AnimatedBuilder(
            animation: _slide,
            builder: (context, child) =>
                Transform.translate(offset: Offset(0, _slide.value), child: child),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  _brandmark(ext, tt),
                  const Spacer(flex: 2),
                  _featureRow(ext, tt),
                  const Spacer(flex: 3),
                  AppButton(
                    label: 'Get started',
                    trailingIcon: Icons.arrow_forward_rounded,
                    fullWidth: true,
                    size: AppButtonSize.lg,
                    accent: ext.brand,
                    onPressed: _getStarted,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Private by default · no account required',
                    style: tt.bodySmall?.copyWith(color: ext.textTertiary),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _brandmark(AppColorsExt ext, TextTheme tt) {
    return Column(
      children: [
        // Original brand logo — shown as-is (no tinted background), 8px rounded.
        const AppLogo.raster(size: 132, radius: 8),
        const SizedBox(height: AppSpacing.lg),
        Text('DailyMinder', style: tt.displayMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Medicine, water, focus & reminders —\nyour day, gently in order.',
          textAlign: TextAlign.center,
          style: tt.bodyLarge?.copyWith(color: ext.textSecondary, height: 1.4),
        ),
      ],
    );
  }

  Widget _featureRow(AppColorsExt ext, TextTheme tt) {
    final features = <(IconData, String, AccentSwatch)>[
      (Icons.medication_rounded, 'Medicine', ext.medicine),
      (Icons.water_drop_rounded, 'Water', ext.water),
      (Icons.self_improvement_rounded, 'Focus', ext.focus),
      (Icons.notifications_rounded, 'Reminders', ext.reminders),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final (icon, label, s) in features)
          Column(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: s.container,
                  borderRadius: AppRadius.brLg,
                ),
                child: Icon(icon, color: s.onContainer, size: 26),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(label, style: tt.labelMedium?.copyWith(color: ext.textSecondary)),
            ],
          ),
      ],
    );
  }
}
