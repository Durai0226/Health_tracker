import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../design/app_design.dart';
import '../../design/app_colors_ext.dart';
import 'app_card.dart';

/// A short, plain-language tip about one feature's numbers.
///
/// Replaces the old `AiInsightCard`, which was a `StatefulWidget` wrapping a
/// `Future<String?>` loader with a spinner, a per-signature cache, an epoch guard
/// and a "Couldn't generate a tip right now. Tap to retry." error state.
///
/// All of that existed for a cloud LLM that might be slow or fail. The text
/// actually comes from `CoachText`, which is **synchronous** — every input is
/// already on hand at the call site — so the machinery bought nothing and cost a
/// visible "Working…" flash on a string computed in microseconds. It is now a
/// stateless card that renders instantly and cannot fail.
class TipCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final AccentSwatch accent;

  /// The tip itself. Markdown is still rendered because several of the
  /// `CoachText` strings use **bold** for the numbers they quote.
  final String text;

  const TipCard({
    super.key,
    required this.title,
    required this.icon,
    required this.accent,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: accent.container, borderRadius: AppRadius.brSm),
                child: Icon(icon, color: accent.onContainer, size: 18),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(title,
                    style: tt.titleMedium?.copyWith(color: ext.textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          MarkdownBody(
            data: text,
            styleSheet: MarkdownStyleSheet(
              p: tt.bodyMedium?.copyWith(color: ext.textPrimary, height: 1.45),
              listBullet: tt.bodyMedium?.copyWith(color: ext.textPrimary),
              strong: tt.bodyMedium
                  ?.copyWith(color: ext.textPrimary, fontWeight: FontWeight.w700),
              h1: tt.titleLarge?.copyWith(color: ext.textPrimary),
              h2: tt.titleMedium?.copyWith(color: ext.textPrimary),
              h3: tt.titleSmall?.copyWith(color: ext.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
