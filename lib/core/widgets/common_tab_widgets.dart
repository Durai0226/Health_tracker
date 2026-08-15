import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

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
