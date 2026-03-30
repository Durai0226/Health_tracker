import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stylish_bottom_bar/stylish_bottom_bar.dart';

/// Premium Finance Navigation Bar - Finance Tracker Category
/// Uses: stylish_bottom_bar (BubbleBarStyle) + professional enhancements
/// 
/// Design Features:
/// - Sliding bubble/pill indicator
/// - Mint green accent (#00D09C)
/// - Professional banking aesthetic
/// - Spring physics animation
/// - Badge support for notifications
class PremiumFinanceNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<IconData> activeIcons;
  final List<IconData> inactiveIcons;
  final List<String>? labels;
  final List<int>? badges;

  const PremiumFinanceNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.activeIcons,
    required this.inactiveIcons,
    this.labels,
    this.badges,
  });

  @override
  State<PremiumFinanceNav> createState() => _PremiumFinanceNavState();
}

class _PremiumFinanceNavState extends State<PremiumFinanceNav> {
  
  // Finance theme colors
  static const Color _primaryGreen = Color(0xFF00D09C);
  static const Color _primaryGreenDark = Color(0xFF00B386);
  
  // Default labels
  static const List<String> _defaultLabels = ['Home', 'Finance', 'Relax', 'Settings'];

  void _onTap(int index) {
    HapticFeedback.selectionClick();
    widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labels = widget.labels ?? _defaultLabels;
    final badges = widget.badges;
    
    final bgColor = isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA);
    final surfaceColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        boxShadow: [
          BoxShadow(
            color: _primaryGreen.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          padding: EdgeInsets.only(bottom: bottomPadding > 0 ? 0 : 4),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.08),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: StylishBottomBar(
              option: BubbleBarOptions(
                barStyle: BubbleBarStyle.horizontal,
                bubbleFillStyle: BubbleFillStyle.fill,
                opacity: 0.2,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: [
                BottomBarItem(
                  icon: Icon(
                    widget.inactiveIcons[0],
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.5)
                        : Colors.black.withValues(alpha: 0.4),
                  ),
                  selectedIcon: Icon(
                    widget.activeIcons[0],
                    color: _primaryGreen,
                  ),
                  selectedColor: _primaryGreen,
                  unSelectedColor: isDark
                      ? Colors.white.withValues(alpha: 0.5)
                      : Colors.black.withValues(alpha: 0.4),
                  title: Text(
                    labels[0],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _primaryGreen,
                    ),
                  ),
                  badge: badges != null && badges.isNotEmpty && badges[0] > 0
                      ? Text(
                          badges[0] > 99 ? '99+' : badges[0].toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                  showBadge: badges != null && badges.isNotEmpty && badges[0] > 0,
                  badgeColor: const Color(0xFFFF6B6B),
                  badgePadding: const EdgeInsets.all(4),
                ),
                BottomBarItem(
                  icon: Icon(
                    widget.inactiveIcons[1],
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.5)
                        : Colors.black.withValues(alpha: 0.4),
                  ),
                  selectedIcon: Icon(
                    widget.activeIcons[1],
                    color: _primaryGreen,
                  ),
                  selectedColor: _primaryGreen,
                  unSelectedColor: isDark
                      ? Colors.white.withValues(alpha: 0.5)
                      : Colors.black.withValues(alpha: 0.4),
                  title: Text(
                    labels[1],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _primaryGreen,
                    ),
                  ),
                  badge: badges != null && badges.length > 1 && badges[1] > 0
                      ? Text(
                          badges[1] > 99 ? '99+' : badges[1].toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                  showBadge: badges != null && badges.length > 1 && badges[1] > 0,
                  badgeColor: const Color(0xFFFF6B6B),
                  badgePadding: const EdgeInsets.all(4),
                ),
                BottomBarItem(
                  icon: Icon(
                    widget.inactiveIcons[2],
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.5)
                        : Colors.black.withValues(alpha: 0.4),
                  ),
                  selectedIcon: Icon(
                    widget.activeIcons[2],
                    color: _primaryGreen,
                  ),
                  selectedColor: _primaryGreen,
                  unSelectedColor: isDark
                      ? Colors.white.withValues(alpha: 0.5)
                      : Colors.black.withValues(alpha: 0.4),
                  title: Text(
                    labels[2],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _primaryGreen,
                    ),
                  ),
                ),
                BottomBarItem(
                  icon: Icon(
                    widget.inactiveIcons[3],
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.5)
                        : Colors.black.withValues(alpha: 0.4),
                  ),
                  selectedIcon: Icon(
                    widget.activeIcons[3],
                    color: _primaryGreen,
                  ),
                  selectedColor: _primaryGreen,
                  unSelectedColor: isDark
                      ? Colors.white.withValues(alpha: 0.5)
                      : Colors.black.withValues(alpha: 0.4),
                  title: Text(
                    labels[3],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _primaryGreen,
                    ),
                  ),
                ),
              ],
              currentIndex: widget.currentIndex,
              onTap: _onTap,
              backgroundColor: Colors.transparent,
            ),
          ),
        ),
      ),
    );
  }
}
