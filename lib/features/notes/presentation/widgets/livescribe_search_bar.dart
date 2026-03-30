import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/livescribe_theme.dart';

/// Modern search bar for Livescribe Notes
/// Clean design - NO icon inside input, filter button separate
class LivescribeSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final VoidCallback? onTap;
  final bool autofocus;
  final bool showFilterButton;
  final VoidCallback? onFilterTap;

  const LivescribeSearchBar({
    super.key,
    required this.controller,
    this.hintText = 'Search...',
    this.onChanged,
    this.onClear,
    this.onTap,
    this.autofocus = false,
    this.showFilterButton = false,
    this.onFilterTap,
  });

  @override
  State<LivescribeSearchBar> createState() => _LivescribeSearchBarState();
}

class _LivescribeSearchBarState extends State<LivescribeSearchBar> {
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        // Main search input - NO icon inside
        Expanded(
          child: AnimatedContainer(
            duration: LivescribeTheme.durationFast,
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : LivescribeTheme.surfaceGray,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _hasFocus 
                    ? LivescribeTheme.primary 
                    : (isDark ? const Color(0xFF2E2E2E) : LivescribeTheme.borderLight),
                width: _hasFocus ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                // Input field - no icon, just text
                Expanded(
                  child: Focus(
                    onFocusChange: (focused) {
                      setState(() => _hasFocus = focused);
                    },
                    child: TextField(
                      controller: widget.controller,
                      autofocus: widget.autofocus,
                      onChanged: widget.onChanged,
                      onTap: widget.onTap,
                      style: LivescribeTheme.bodyMedium.copyWith(
                        color: isDark ? Colors.white : LivescribeTheme.textPrimary,
                      ),
                      cursorColor: LivescribeTheme.primary,
                      decoration: InputDecoration(
                        hintText: widget.hintText,
                        hintStyle: LivescribeTheme.bodyMedium.copyWith(
                          color: isDark ? const Color(0xFF808080) : LivescribeTheme.textTertiary,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Clear button (only when has text)
                if (widget.controller.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      widget.controller.clear();
                      widget.onClear?.call();
                      widget.onChanged?.call('');
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: isDark ? const Color(0xFF808080) : LivescribeTheme.textTertiary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        
        // Filter button - separate from input
        if (widget.showFilterButton) ...[
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onFilterTap?.call();
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : LivescribeTheme.surfaceGray,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF2E2E2E) : LivescribeTheme.borderLight,
                ),
              ),
              child: Icon(
                Icons.tune_rounded,
                size: 20,
                color: isDark ? const Color(0xFFB0B0B0) : LivescribeTheme.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Compact search field for toolbar use
class CompactSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;

  const CompactSearchField({
    super.key,
    required this.controller,
    this.hintText = 'Search',
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            size: 16,
            color: isDark ? LivescribeTheme.darkTextSecondary : LivescribeTheme.textTertiary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: (_) => onSubmitted?.call(),
              style: TextStyle(
                fontSize: 13,
                color: isDark ? LivescribeTheme.darkTextPrimary : LivescribeTheme.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? LivescribeTheme.darkTextSecondary : LivescribeTheme.textTertiary,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                controller.clear();
                onChanged?.call('');
              },
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: isDark ? LivescribeTheme.darkTextSecondary : LivescribeTheme.textTertiary,
              ),
            ),
        ],
      ),
    );
  }
}
