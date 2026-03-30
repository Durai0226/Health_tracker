import 'package:flutter/material.dart';
import '../../../core/widgets/bottom_nav/bottom_nav.dart';
import '../../../core/widgets/feature_profile_sheet.dart';
import '../../../core/services/auth_service.dart';
import '../presentation/screens/premium_notes_screen.dart';
import '../presentation/screens/notes_tags_screen.dart';
import '../presentation/screens/notes_tasks_screen.dart';
import '../presentation/screens/notes_notebooks_screen.dart';
import 'settings/notes_editor_settings_screen.dart';
import 'settings/notes_backup_settings_screen.dart';
import 'settings/notes_sorting_settings_screen.dart';
import 'settings/notes_export_settings_screen.dart';
import '../../onboarding/screens/welcome_screen.dart';

/// Notes feature with unique paper fold corner bottom navigation
class NotesMainScreen extends StatefulWidget {
  const NotesMainScreen({super.key});

  @override
  State<NotesMainScreen> createState() => _NotesMainScreenState();
}

class _NotesMainScreenState extends State<NotesMainScreen> {
  final AuthService _authService = AuthService();
  int _currentIndex = 0;
  static const _featureColor = Color(0xFF10B981);

  final List<Widget> _screens = const [
    PremiumNotesScreen(),
    NotesNotebooksScreen(),
    NotesTagsScreen(),
    NotesTasksScreen(),
  ];

  final List<GlassNavItem> _navItems = const [
    GlassNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: 'Dashboard'),
    GlassNavItem(icon: Icons.folder_outlined, activeIcon: Icons.folder_rounded, label: 'Notebooks'),
    GlassNavItem(icon: Icons.label_outline, activeIcon: Icons.label_rounded, label: 'Tags'),
    GlassNavItem(icon: Icons.check_circle_outline, activeIcon: Icons.check_circle_rounded, label: 'Tasks'),
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
      featureName: 'Notes',
      featureColor: _featureColor,
      featureIcon: Icons.note_alt_rounded,
      settings: _profileSettings,
      onSyncTap: () {},
      onSignOut: _handleSignOut,
    );
  }

  List<FeatureSettingItem> get _profileSettings => [
    FeatureSettingItem(
      icon: Icons.text_format_outlined,
      title: 'Editor Settings',
      subtitle: 'Font size, style & more',
      onTap: _openEditor,
    ),
    FeatureSettingItem(
      icon: Icons.backup_outlined,
      title: 'Backup & Restore',
      subtitle: 'Manage note backups',
      onTap: _openBackup,
    ),
    FeatureSettingItem(
      icon: Icons.sort_outlined,
      title: 'Sorting & Display',
      subtitle: 'Customize note order',
      onTap: _openSorting,
    ),
    FeatureSettingItem(
      icon: Icons.download_outlined,
      title: 'Export Notes',
      subtitle: 'Export as PDF or text',
      onTap: _openExport,
    ),
  ];

  void _openEditor() {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const NotesEditorSettingsScreen()));
  }

  void _openBackup() {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const NotesBackupSettingsScreen()));
  }

  void _openSorting() {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const NotesSortingSettingsScreen()));
  }

  void _openExport() {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const NotesExportSettingsScreen()));
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
      bottomNavigationBar: NotesBottomNav(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
        items: _navItems,
        featureColor: _featureColor,
      ),
    );
  }
}
