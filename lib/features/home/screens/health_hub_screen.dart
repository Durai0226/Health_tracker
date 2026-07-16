import 'package:flutter/material.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../medication/screens/nunito_medication_dashboard.dart';
import '../../water/screens/aqua_water_dashboard.dart';

/// Groups Medicine + Water behind ONE header + a segmented toggle, so the
/// bottom nav stays at four clean destinations. The two dashboards render as
/// header-less embedded bodies — no double header, no nested chrome.
class HealthHubScreen extends StatefulWidget {
  final int initialTab;
  final ValueChanged<FeatureAccent>? onAccentChanged;
  final ValueChanged<int>? onTabChanged;

  const HealthHubScreen({
    super.key,
    this.initialTab = 0,
    this.onAccentChanged,
    this.onTabChanged,
  });

  @override
  State<HealthHubScreen> createState() => _HealthHubScreenState();
}

class _HealthHubScreenState extends State<HealthHubScreen> {
  late int _tab = widget.initialTab.clamp(0, 1);

  FeatureAccent get _feature =>
      _tab == 1 ? FeatureAccent.water : FeatureAccent.medicine;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onAccentChanged?.call(_feature);
    });
  }

  void _select(int i) {
    if (i == _tab) return;
    setState(() => _tab = i);
    widget.onAccentChanged?.call(_feature);
    // Keep the shell's tracked tab in sync so Home's Medicine/Water shortcuts
    // always land on the intended sub-tab.
    widget.onTabChanged?.call(i);
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final swatch = ext.accent(_feature);

    return AccentScope(
      feature: _feature,
      child: AppScaffold(
        body: Column(
          children: [
            AppHeader(
              title: 'Health',
              accent: swatch,
              bottom: SegmentedToggle(
                accent: swatch,
                index: _tab,
                onChanged: _select,
                items: const [
                  SegmentItem(icon: Icons.medication_rounded, label: 'Medicine'),
                  SegmentItem(icon: Icons.water_drop_rounded, label: 'Water'),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: const [
                  NunitoMedicationDashboard(embedded: true),
                  AquaWaterDashboard(embedded: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
