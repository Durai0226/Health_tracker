import 'package:flutter/material.dart';

/// Gives its child the incoming viewport height as a MINIMUM instead of a
/// fixed size, and lets it scroll past that.
///
/// Anything dropped into an [Expanded] gets a tight height, which is fine
/// until Dynamic Type grows the content past it — then a centred column of
/// text simply gets clipped ("BOTTOM OVERFLOWED"), which is what an empty
/// state (circle + title + message + button) does at 200%. Because the
/// constraint is only a minimum, layout at default text sizes is
/// byte-for-byte unchanged.
///
/// Lifted from four medication list screens (medicines, doctors, clinics,
/// appointments) that each declared the same private `_ScrollableFill`.
/// `lib/features/reminders` and `lib/features/focus` still hand-roll it.
class ScrollableFill extends StatelessWidget {
  final Widget child;
  const ScrollableFill({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: child,
        ),
      ),
    );
  }
}
