import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/evernote_theme.dart';

/// Modern search bar for Notes feature
/// Clean dark design - NO icon inside input, filter button separate
class NotesSearchBar extends StatefulWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final VoidCallback? onFilterTap;
  final VoidCallback? onVoiceTap;
  final bool autofocus;
  final bool readOnly;
  final bool showFilter;
  final bool showVoice;

  const NotesSearchBar({
    super.key,
    this.controller,
    this.hintText = 'Search notes...',
    this.onChanged,
    this.onTap,
    this.onFilterTap,
    this.onVoiceTap,
    this.autofocus = false,
    this.readOnly = false,
    this.showFilter = true,
    this.showVoice = false,
  });

  @override
  State<NotesSearchBar> createState() => _NotesSearchBarState();
}

class _NotesSearchBarState extends State<NotesSearchBar> {
  late TextEditingController _controller;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Main search input - no icon inside
        Expanded(
          child: GestureDetector(
            onTap: widget.readOnly ? widget.onTap : null,
            child: AnimatedContainer(
              duration: EvernoteTheme.durationFast,
              height: 48,
              decoration: BoxDecoration(
                color: EvernoteTheme.cardBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _hasFocus 
                      ? EvernoteTheme.primary 
                      : EvernoteTheme.cardBorder,
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
                        controller: _controller,
                        autofocus: widget.autofocus,
                        readOnly: widget.readOnly,
                        onChanged: widget.onChanged,
                        onTap: widget.readOnly ? null : widget.onTap,
                        style: EvernoteTheme.bodyMedium.copyWith(
                          color: EvernoteTheme.textPrimary,
                        ),
                        cursorColor: EvernoteTheme.primary,
                        decoration: InputDecoration(
                          hintText: widget.hintText,
                          hintStyle: EvernoteTheme.bodyMedium.copyWith(
                            color: EvernoteTheme.textMuted,
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
                  if (_controller.text.isNotEmpty && !widget.readOnly)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _controller.clear();
                        widget.onChanged?.call('');
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: EvernoteTheme.textTertiary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        
        // Filter button - separate from input
        if (widget.showFilter) ...[
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
                color: EvernoteTheme.cardBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: EvernoteTheme.cardBorder),
              ),
              child: const Icon(
                Icons.tune_rounded,
                size: 20,
                color: EvernoteTheme.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Compact search field for toolbar use
class CompactNotesSearch extends StatelessWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;

  const CompactNotesSearch({
    super.key,
    this.controller,
    this.onChanged,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: EvernoteTheme.surface,
        borderRadius: BorderRadius.circular(EvernoteTheme.radiusFull),
        border: Border.all(color: EvernoteTheme.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            size: 18,
            color: EvernoteTheme.textTertiary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onTap: onTap,
              style: const TextStyle(
                fontSize: 14,
                color: EvernoteTheme.textPrimary,
              ),
              cursorColor: EvernoteTheme.primary,
              decoration: const InputDecoration(
                hintText: 'Search',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: EvernoteTheme.textTertiary,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
