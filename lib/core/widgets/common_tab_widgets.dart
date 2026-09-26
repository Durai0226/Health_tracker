import 'package:flutter/material.dart';

import '../design/app_design.dart';

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
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: ext.surface,
        border: Border(
          bottom: BorderSide(
            // One hairline for both themes. Dark read `ext.outline`; light read
            // `Colors.grey.withOpacity(0.1)`, i.e. the only separator in the
            // app that did not come from the token — and a fifth of the
            // token's weight (1.09:1 against white, where `outline` is
            // 1.25:1), so the tab strip's bottom edge effectively vanished on
            // light.
            color: ext.outline,
            width: 1,
          ),
        ),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: isScrollable,
        labelColor: labelColor ?? ext.mark(ext.brand),
        unselectedLabelColor: unselectedLabelColor ?? ext.textSecondary,
        indicatorColor: indicatorColor ?? ext.mark(ext.brand),
        indicatorWeight: indicatorWeight!,
        indicatorSize: indicatorSize ?? TabBarIndicatorSize.tab,
        labelPadding: labelPadding ?? const EdgeInsets.symmetric(horizontal: 16),
        // Kept rather than deleted, and now derived from the scale.
        //
        // `tabBarTheme` already supplies `labelStyle: tt.labelLarge`, so the
        // sizes here were redundant — a prior reviewer measured the difference
        // and refuted it. What was NOT redundant is that `TabBar` *replaces*
        // its label style rather than merging it, so a bare `TextStyle` dropped
        // the family too: tab labels rendered in the platform default instead
        // of Inter, and lost the scale's line height.
        //
        // The weight pair stays explicit because it is the selected/unselected
        // contrast this widget exists for, which no theme expresses.
        labelStyle: tt.labelLarge?.copyWith(letterSpacing: 0.3),
        unselectedLabelStyle: tt.labelLarge?.copyWith(fontWeight: FontWeight.w500),
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
      color: backgroundColor ?? AppColorsExt.of(context).background,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(StickyTabBarDelegate oldDelegate) {
    return true;
  }
}
