import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

/// Premium Focus Navigation Bar - Productivity Category
/// Uses: google_nav_bar + custom enhancements
/// 
/// Design Features:
/// - Expanding pill indicator with label (Google style)
/// - Purple gradient (#8B5CF6)
/// - Clean, minimal, distraction-free
/// - Sharp 200ms transitions
/// - Premium shadow on active pill
class PremiumFocusNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<IconData> activeIcons;
  final List<IconData> inactiveIcons;
  final List<String>? labels;

  const PremiumFocusNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.activeIcons,
    required this.inactiveIcons,
    this.labels,
  });

  @override
  State<PremiumFocusNav> createState() => _PremiumFocusNavState();
}

class _PremiumFocusNavState extends State<PremiumFocusNav> {
  
  // Focus theme colors
  static const Color _primaryPurple = Color(0xFF8B5CF6);
  static const Color _primaryPurpleDark = Color(0xFF7C3AED);
  
  // Default labels
  static const List<String> _defaultLabels = ['Home', 'Focus', 'Relax', 'Settings'];

  void _onTap(int index) {
    HapticFeedback.lightImpact();
    widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labels = widget.labels ?? _defaultLabels;
    
    final bgColor = isDark ? const Color(0xFF0A0A0A) : Colors.white;
    
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        boxShadow: [
          BoxShadow(
            color: _primaryPurple.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: bottomPadding > 0 ? 8 : 12,
          ),
          child: GNav(
            gap: 8,
            activeColor: Colors.white,
            iconSize: 24,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            duration: const Duration(milliseconds: 200),
            tabBackgroundColor: _primaryPurple,
            tabBackgroundGradient: const LinearGradient(
              colors: [_primaryPurple, _primaryPurpleDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            color: isDark
                ? Colors.white.withValues(alpha: 0.5)
                : Colors.black.withValues(alpha: 0.4),
            tabs: [
              GButton(
                icon: widget.currentIndex == 0
                    ? widget.activeIcons[0]
                    : widget.inactiveIcons[0],
                text: labels[0],
                iconColor: isDark
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.black.withValues(alpha: 0.4),
                iconActiveColor: Colors.white,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Colors.white,
                ),
                backgroundGradient: const LinearGradient(
                  colors: [_primaryPurple, _primaryPurpleDark],
                ),
                shadow: [
                  BoxShadow(
                    color: _primaryPurple.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              GButton(
                icon: widget.currentIndex == 1
                    ? widget.activeIcons[1]
                    : widget.inactiveIcons[1],
                text: labels[1],
                iconColor: isDark
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.black.withValues(alpha: 0.4),
                iconActiveColor: Colors.white,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Colors.white,
                ),
                backgroundGradient: const LinearGradient(
                  colors: [_primaryPurple, _primaryPurpleDark],
                ),
                shadow: [
                  BoxShadow(
                    color: _primaryPurple.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              GButton(
                icon: widget.currentIndex == 2
                    ? widget.activeIcons[2]
                    : widget.inactiveIcons[2],
                text: labels[2],
                iconColor: isDark
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.black.withValues(alpha: 0.4),
                iconActiveColor: Colors.white,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Colors.white,
                ),
                backgroundGradient: const LinearGradient(
                  colors: [_primaryPurple, _primaryPurpleDark],
                ),
                shadow: [
                  BoxShadow(
                    color: _primaryPurple.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              GButton(
                icon: widget.currentIndex == 3
                    ? widget.activeIcons[3]
                    : widget.inactiveIcons[3],
                text: labels[3],
                iconColor: isDark
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.black.withValues(alpha: 0.4),
                iconActiveColor: Colors.white,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Colors.white,
                ),
                backgroundGradient: const LinearGradient(
                  colors: [_primaryPurple, _primaryPurpleDark],
                ),
                shadow: [
                  BoxShadow(
                    color: _primaryPurple.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ],
            selectedIndex: widget.currentIndex,
            onTabChange: _onTap,
          ),
        ),
      ),
    );
  }
}
