import 'package:flutter/material.dart';
import '../../../core/widgets/bottom_nav/bottom_nav.dart';
import '../../../core/widgets/feature_profile_sheet.dart';
import '../../../core/services/auth_service.dart';
import 'nunito_medication_dashboard.dart';
import 'nunito_medication_list_screen.dart';
import 'medicine_history_screen.dart';
import 'analytics/nunito_adherence_report_screen.dart';
import 'doctors/nunito_doctor_list_screen.dart';
import 'clinics/nunito_clinic_list_screen.dart';
import 'dependents/dependent_list_screen.dart';
import '../../onboarding/screens/welcome_screen.dart';

/// Main medicine screen with unique pill-shaped bottom navigation
class MedicineMainScreen extends StatefulWidget {
  const MedicineMainScreen({super.key});

  @override
  State<MedicineMainScreen> createState() => _MedicineMainScreenState();
}

class _MedicineMainScreenState extends State<MedicineMainScreen> {
  final AuthService _authService = AuthService();
  int _currentIndex = 0;

  static const _featureColor = Color(0xFF6366F1);

  final List<Widget> _screens = const [
    NunitoMedicationDashboard(),
    NunitoMedicationListScreen(),
    MedicineHistoryScreen(),
    NunitoAdherenceReportScreen(),
  ];

  final List<GlassNavItem> _navItems = const [
    GlassNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: 'Dashboard'),
    GlassNavItem(icon: Icons.medication_outlined, activeIcon: Icons.medication_rounded, label: 'Meds'),
    GlassNavItem(icon: Icons.history_outlined, activeIcon: Icons.history_rounded, label: 'History'),
    GlassNavItem(icon: Icons.analytics_outlined, activeIcon: Icons.analytics_rounded, label: 'Analytics'),
    GlassNavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
  ];

  void _onNavTap(int index) {
    if (index == 4) {
      _openProfile();
    } else if (_currentIndex != index) {
      setState(() => _currentIndex = index);
    }
  }

  void _openProfile() {
    FeatureProfileSheet.show(
      context: context,
      featureName: 'Medicine',
      featureColor: _featureColor,
      featureIcon: Icons.medication_rounded,
      settings: _profileSettings,
      onSyncTap: _handleSync,
      onSignOut: _handleSignOut,
    );
  }

  List<FeatureSettingItem> get _profileSettings => [
    FeatureSettingItem(
      icon: Icons.notifications_outlined,
      title: 'Reminder Settings',
      subtitle: 'Configure medication reminders',
      onTap: _openReminders,
    ),
    FeatureSettingItem(
      icon: Icons.medical_services_outlined,
      title: 'Doctors',
      subtitle: 'Manage your doctors',
      onTap: _openDoctors,
    ),
    FeatureSettingItem(
      icon: Icons.local_hospital_outlined,
      title: 'Clinics & Pharmacies',
      subtitle: 'Manage healthcare locations',
      onTap: _openClinics,
    ),
    FeatureSettingItem(
      icon: Icons.people_outline,
      title: 'Dependents',
      subtitle: 'Manage family members',
      onTap: _openDependents,
    ),
    FeatureSettingItem(
      icon: Icons.download_outlined,
      title: 'Export Data',
      subtitle: 'Export medication history',
      onTap: () => _exportData(),
    ),
  ];

  void _openReminders() {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const NunitoAdherenceReportScreen()));
  }

  void _openDoctors() {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const NunitoDoctorListScreen()));
  }

  void _openClinics() {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const NunitoClinicListScreen()));
  }

  void _openDependents() {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const DependentListScreen()));
  }

  void _exportData() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exporting medication data...')),
    );
  }

  void _handleSync() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Syncing medication data to cloud...')),
    );
  }

  void _handleSignOut() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: MedicineBottomNav(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
        items: _navItems,
        featureColor: _featureColor,
      ),
    );
  }
}
