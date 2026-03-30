import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/mood_theme.dart';

/// Mood Themes Settings Screen
class MoodThemesSettingsScreen extends StatefulWidget {
  const MoodThemesSettingsScreen({super.key});

  @override
  State<MoodThemesSettingsScreen> createState() => _MoodThemesSettingsScreenState();
}

class _MoodThemesSettingsScreenState extends State<MoodThemesSettingsScreen> {
  String _selectedTheme = 'purple';
  bool _adaptiveColors = true;
  bool _isLoading = true;

  final List<Map<String, dynamic>> _themes = [
    {'id': 'purple', 'name': 'Lavender Dreams', 'primary': const Color(0xFF9884F3), 'secondary': const Color(0xFFF0EFFE)},
    {'id': 'rose', 'name': 'Rose Garden', 'primary': const Color(0xFFE87FB0), 'secondary': const Color(0xFFFFF0F5)},
    {'id': 'ocean', 'name': 'Ocean Calm', 'primary': const Color(0xFF4ECDC4), 'secondary': const Color(0xFFE8F8F5)},
    {'id': 'sunset', 'name': 'Golden Sunset', 'primary': const Color(0xFFFF9F43), 'secondary': const Color(0xFFFFF5EB)},
    {'id': 'forest', 'name': 'Forest Serenity', 'primary': const Color(0xFF2ECC71), 'secondary': const Color(0xFFE8F8F0)},
    {'id': 'midnight', 'name': 'Midnight Sky', 'primary': const Color(0xFF5650DF), 'secondary': const Color(0xFFEEEEFF)},
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _selectedTheme = prefs.getString('mood_theme') ?? 'purple';
        _adaptiveColors = prefs.getBool('mood_adaptive_colors') ?? true;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mood_theme', _selectedTheme);
    await prefs.setBool('mood_adaptive_colors', _adaptiveColors);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Theme saved!'),
          backgroundColor: MoodTheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MoodTheme.background,
      appBar: AppBar(
        backgroundColor: MoodTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: MoodTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Themes', style: MoodTheme.headingSm.copyWith(color: MoodTheme.textPrimary)),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: MoodTheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(MoodTheme.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Color Theme', style: MoodTheme.titleLg.copyWith(color: MoodTheme.textPrimary)),
                  const SizedBox(height: MoodTheme.spacingSm),
                  Text('Choose your mood journal appearance', 
                    style: MoodTheme.bodySm.copyWith(color: MoodTheme.textMuted)),
                  const SizedBox(height: MoodTheme.spacingMd),
                  _buildThemeGrid(),
                  const SizedBox(height: MoodTheme.spacingLg),
                  _buildAdaptiveColorsCard(),
                  const SizedBox(height: MoodTheme.spacingLg),
                  _buildSaveButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildThemeGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _themes.length,
      itemBuilder: (context, index) {
        final theme = _themes[index];
        final isSelected = _selectedTheme == theme['id'];
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _selectedTheme = theme['id']);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: theme['secondary'],
              borderRadius: MoodTheme.borderRadiusLg,
              border: Border.all(
                color: isSelected ? theme['primary'] : Colors.transparent,
                width: 2,
              ),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: (theme['primary'] as Color).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ] : MoodTheme.softShadow,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme['primary'],
                    shape: BoxShape.circle,
                  ),
                  child: isSelected 
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : null,
                ),
                const SizedBox(height: 8),
                Text(
                  theme['name'],
                  style: MoodTheme.titleSm.copyWith(
                    color: isSelected ? theme['primary'] : MoodTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAdaptiveColorsCard() {
    return Container(
      padding: const EdgeInsets.all(MoodTheme.spacingMd),
      decoration: BoxDecoration(
        color: MoodTheme.surface,
        borderRadius: MoodTheme.borderRadiusLg,
        boxShadow: MoodTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _adaptiveColors ? MoodTheme.purple50 : MoodTheme.beige50,
              borderRadius: MoodTheme.borderRadiusSm,
            ),
            child: Icon(Icons.auto_awesome, 
              color: _adaptiveColors ? MoodTheme.primary : MoodTheme.textMuted),
          ),
          const SizedBox(width: MoodTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Adaptive Colors', style: MoodTheme.titleMd.copyWith(color: MoodTheme.textPrimary)),
                const SizedBox(height: 2),
                Text('Change colors based on your mood', 
                  style: MoodTheme.bodySm.copyWith(color: MoodTheme.textMuted)),
              ],
            ),
          ),
          Switch.adaptive(
            value: _adaptiveColors,
            onChanged: (v) {
              HapticFeedback.lightImpact();
              setState(() => _adaptiveColors = v);
            },
            activeColor: MoodTheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _saveSettings,
        style: ElevatedButton.styleFrom(
          backgroundColor: MoodTheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: MoodTheme.borderRadiusLg),
        ),
        child: Text('Save Theme', style: MoodTheme.titleMd.copyWith(color: Colors.white)),
      ),
    );
  }
}
