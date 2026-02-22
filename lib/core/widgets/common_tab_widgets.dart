import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';

/// Modern, compact TabBar widget with consistent styling
class CommonTabBar extends StatelessWidget implements PreferredSizeWidget {
  final List<String> tabs;
  final TabController? controller;
  final Color? indicatorColor;
  final Color? labelColor;
  final Color? unselectedLabelColor;
  final double? indicatorWeight;
  final EdgeInsetsGeometry? labelPadding;
  final bool isScrollable;
  final TabBarIndicatorSize? indicatorSize;
  final double? height;

  const CommonTabBar({
    super.key,
    required this.tabs,
    this.controller,
    this.indicatorColor,
    this.labelColor,
    this.unselectedLabelColor,
    this.indicatorWeight = 3,
    this.labelPadding,
    this.isScrollable = false,
    this.indicatorSize,
    this.height = 44,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.getCardBg(context),
        border: Border(
          bottom: BorderSide(
            color: isDark 
                ? AppColors.darkBorder.withOpacity(0.3)
                : Colors.grey.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: isScrollable,
        labelColor: labelColor ?? AppColors.primary,
        unselectedLabelColor: unselectedLabelColor ?? AppColors.getTextSecondary(context),
        indicatorColor: indicatorColor ?? AppColors.primary,
        indicatorWeight: indicatorWeight!,
        indicatorSize: indicatorSize ?? TabBarIndicatorSize.tab,
        labelPadding: labelPadding ?? const EdgeInsets.symmetric(horizontal: 16),
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        tabs: tabs.map((tab) => Tab(text: tab)).toList(),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(height!);
}

/// Modern TabBar with icons
class CommonIconTabBar extends StatelessWidget implements PreferredSizeWidget {
  final List<TabItem> tabs;
  final TabController? controller;
  final Color? indicatorColor;
  final Color? labelColor;
  final Color? unselectedLabelColor;
  final double? indicatorWeight;
  final bool isScrollable;
  final double? height;

  const CommonIconTabBar({
    super.key,
    required this.tabs,
    this.controller,
    this.indicatorColor,
    this.labelColor,
    this.unselectedLabelColor,
    this.indicatorWeight = 3,
    this.isScrollable = false,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.getCardBg(context),
        border: Border(
          bottom: BorderSide(
            color: isDark 
                ? AppColors.darkBorder.withOpacity(0.3)
                : Colors.grey.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: isScrollable,
        labelColor: labelColor ?? AppColors.primary,
        unselectedLabelColor: unselectedLabelColor ?? AppColors.getTextSecondary(context),
        indicatorColor: indicatorColor ?? AppColors.primary,
        indicatorWeight: indicatorWeight!,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        tabs: tabs.map((item) => Tab(
          icon: Icon(item.icon, size: 22),
          text: item.label,
        )).toList(),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(height!);
}

/// Compact pill-style tab selector
class PillTabBar extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final Color? selectedColor;
  final Color? unselectedColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const PillTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    this.selectedColor,
    this.unselectedColor,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: padding ?? const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark 
            ? AppColors.darkSurface.withOpacity(0.5)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = index == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onTabSelected(index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? (selectedColor ?? AppColors.primary)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  tabs[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected 
                        ? Colors.white
                        : (unselectedColor ?? AppColors.getTextSecondary(context)),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Segmented control style tab bar
class SegmentedTabBar extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final EdgeInsetsGeometry? margin;

  const SegmentedTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primary, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Row(
          children: List.generate(tabs.length, (index) {
            final isSelected = index == selectedIndex;
            final isLast = index == tabs.length - 1;

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onTabSelected(index);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    border: Border(
                      right: !isLast 
                          ? const BorderSide(color: AppColors.primary, width: 1)
                          : BorderSide.none,
                    ),
                  ),
                  child: Text(
                    tabs[index],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.primary,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Modern tab view wrapper with smooth transitions
class CommonTabView extends StatelessWidget {
  final TabController controller;
  final List<Widget> children;
  final ScrollPhysics? physics;

  const CommonTabView({
    super.key,
    required this.controller,
    required this.children,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    return TabBarView(
      controller: controller,
      physics: physics ?? const BouncingScrollPhysics(),
      children: children,
    );
  }
}

/// Persistent tab bar delegate for SliverPersistentHeader
class StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final PreferredSizeWidget tabBar;
  final Color? backgroundColor;

  StickyTabBarDelegate({
    required this.tabBar,
    this.backgroundColor,
  });

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: backgroundColor ?? AppColors.getBackground(context),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(StickyTabBarDelegate oldDelegate) {
    return true;
  }
}

/// Modal bottom sheet with tabs
class TabBarModal extends StatefulWidget {
  final List<TabItem> tabs;
  final List<Widget> tabViews;
  final String? title;
  final int initialIndex;
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;

  const TabBarModal({
    super.key,
    required this.tabs,
    required this.tabViews,
    this.title,
    this.initialIndex = 0,
    this.initialChildSize = 0.7,
    this.minChildSize = 0.5,
    this.maxChildSize = 0.95,
  });

  @override
  State<TabBarModal> createState() => _TabBarModalState();

  static Future<T?> show<T>({
    required BuildContext context,
    required List<TabItem> tabs,
    required List<Widget> tabViews,
    String? title,
    int initialIndex = 0,
    double initialChildSize = 0.7,
    double minChildSize = 0.5,
    double maxChildSize = 0.95,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TabBarModal(
        tabs: tabs,
        tabViews: tabViews,
        title: title,
        initialIndex: initialIndex,
        initialChildSize: initialChildSize,
        minChildSize: minChildSize,
        maxChildSize: maxChildSize,
      ),
    );
  }
}

class _TabBarModalState extends State<TabBarModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.tabs.length,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: widget.initialChildSize,
      minChildSize: widget.minChildSize,
      maxChildSize: widget.maxChildSize,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.getBackground(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag handle
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              if (widget.title != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title!,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: AppColors.getTextSecondary(context),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Tab bar
              CommonIconTabBar(
                tabs: widget.tabs,
                controller: _tabController,
              ),

              // Tab views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: widget.tabViews,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Tab item model for icon tabs
class TabItem {
  final String label;
  final IconData icon;
  final int? badgeCount;

  const TabItem({
    required this.label,
    required this.icon,
    this.badgeCount,
  });
}

/// Compact tab screen wrapper with DefaultTabController
class TabScreen extends StatelessWidget {
  final List<String> tabs;
  final List<Widget> tabViews;
  final String? title;
  final Widget? leading;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final int initialIndex;
  final Widget? floatingActionButton;
  final bool useSliverAppBar;

  const TabScreen({
    super.key,
    required this.tabs,
    required this.tabViews,
    this.title,
    this.leading,
    this.actions,
    this.backgroundColor,
    this.initialIndex = 0,
    this.floatingActionButton,
    this.useSliverAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: tabs.length,
      initialIndex: initialIndex,
      child: Scaffold(
        backgroundColor: backgroundColor ?? AppColors.getBackground(context),
        appBar: useSliverAppBar ? null : AppBar(
          title: title != null ? Text(title!) : null,
          leading: leading,
          actions: actions,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: CommonTabBar(tabs: tabs),
        ),
        body: useSliverAppBar
            ? NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverAppBar(
                    title: title != null ? Text(title!) : null,
                    leading: leading,
                    actions: actions,
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    floating: true,
                    pinned: true,
                    snap: false,
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: StickyTabBarDelegate(
                      tabBar: TabBar(
                        labelColor: AppColors.primary,
                        unselectedLabelColor: AppColors.textSecondary,
                        indicatorColor: AppColors.primary,
                        tabs: tabs.map((tab) => Tab(text: tab)).toList(),
                      ),
                    ),
                  ),
                ],
                body: TabBarView(children: tabViews),
              )
            : TabBarView(children: tabViews),
        floatingActionButton: floatingActionButton,
      ),
    );
  }
}

/// Icon tab screen with icons
class IconTabScreen extends StatelessWidget {
  final List<TabItem> tabs;
  final List<Widget> tabViews;
  final String? title;
  final Widget? leading;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final int initialIndex;
  final Widget? floatingActionButton;

  const IconTabScreen({
    super.key,
    required this.tabs,
    required this.tabViews,
    this.title,
    this.leading,
    this.actions,
    this.backgroundColor,
    this.initialIndex = 0,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: tabs.length,
      initialIndex: initialIndex,
      child: Scaffold(
        backgroundColor: backgroundColor ?? AppColors.getBackground(context),
        appBar: AppBar(
          title: title != null ? Text(title!) : null,
          leading: leading,
          actions: actions,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: CommonIconTabBar(tabs: tabs),
        ),
        body: TabBarView(children: tabViews),
        floatingActionButton: floatingActionButton,
      ),
    );
  }
}
