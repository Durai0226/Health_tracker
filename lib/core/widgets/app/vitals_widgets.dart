import 'package:flutter/material.dart';
import '../../design/app_design.dart';
import '../../design/app_colors_ext.dart';
import 'app_card.dart';
import 'progress_ring.dart';

/// The glance-and-understand centerpiece for a vitals tracker: a big color ring
/// with the latest reading, a band chip (color + icon + label), and a
/// plain-language meaning line. Generic across BP and glucose.
class VitalsStatusHero extends StatelessWidget {
  final String bigValue; // "150/95" or "6.8"
  final String? unitLabel; // "mmHg" or "mmol/L"
  final double ringProgress; // 0..1
  final Color bandColor;
  final IconData categoryIcon;
  final String categoryLabel;
  final String meaning;
  final String? subtitle; // "Last reading · 2h ago"

  const VitalsStatusHero({
    super.key,
    required this.bigValue,
    this.unitLabel,
    required this.ringProgress,
    required this.bandColor,
    required this.categoryIcon,
    required this.categoryLabel,
    required this.meaning,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;

    return AppCard(
      child: Row(
        children: [
          ProgressRing(
            progress: ringProgress.clamp(0.0, 1.0),
            size: 104,
            stroke: 10,
            fillColor: bandColor,
            trackColor: bandColor.withOpacity(0.14),
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  bigValue,
                  style: tt.headlineSmall?.copyWith(
                      color: ext.textPrimary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5),
                ),
                if (unitLabel != null)
                  Text(unitLabel!,
                      style: tt.labelSmall?.copyWith(color: ext.textTertiary)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BandChip(
                    color: bandColor, icon: categoryIcon, label: categoryLabel),
                const SizedBox(height: AppSpacing.sm),
                Text(meaning,
                    style: tt.bodyMedium?.copyWith(
                        color: ext.textSecondary, height: 1.35)),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(subtitle!,
                      style: tt.bodySmall?.copyWith(color: ext.textTertiary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A color + icon + label pill for a classification band (accessible: never
/// color alone).
class _BandChip extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  const _BandChip({required this.color, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: AppRadius.brFull,
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.labelMedium
                    ?.copyWith(color: color, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// Non-dismissible, high-contrast emergency card for a hypertensive crisis or a
/// severe low. Impossible to miss; shown only for genuine red-flag readings.
class VitalsEmergencyCard extends StatelessWidget {
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const VitalsEmergencyCard({
    super.key,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    const danger = Color(0xFF991B1B);
    final tt = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB91C1C), Color(0xFF7F1D1D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.brLg,
        boxShadow: [
          BoxShadow(color: danger.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emergency_rounded, color: Colors.white, size: 24),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(title,
                    style: tt.titleMedium?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(message,
              style: tt.bodyMedium
                  ?.copyWith(color: Colors.white.withOpacity(0.95), height: 1.4)),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                // Explicit white-on-dark-red button (max contrast on the red
                // field, both themes).
                child: FilledButton.icon(
                  onPressed: onPrimary,
                  icon: const Icon(Icons.call_rounded, size: 18),
                  label: Text(primaryLabel),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF7F1D1D),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
                  ),
                ),
              ),
              if (secondaryLabel != null && onSecondary != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSecondary,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
                    ),
                    child: Text(secondaryLabel!),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
