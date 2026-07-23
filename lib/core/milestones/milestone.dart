import 'package:flutter/widgets.dart';

/// A calm, private, self-referential milestone — NOT a points/tier/trophy game.
///
/// Deliberately restrained to fit a medical-trust app: no points economy, no
/// bronze/silver/gold, no cartoon trophies or emoji. Just a quiet record of
/// something you did, earned once and kept for good (persisted locally). The
/// [icon] is a Material Symbol chosen for its meaning, not a reward badge.
@immutable
class Milestone {
  final String id;
  final String title;
  final String description;
  final IconData icon;

  /// Which feature this belongs to ('steps' | 'sleep') — for grouping/filtering.
  final String feature;

  final bool earned;
  final DateTime? earnedAt;

  const Milestone({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.feature,
    this.earned = false,
    this.earnedAt,
  });

  Milestone copyWith({bool? earned, DateTime? earnedAt}) => Milestone(
        id: id,
        title: title,
        description: description,
        icon: icon,
        feature: feature,
        earned: earned ?? this.earned,
        earnedAt: earnedAt ?? this.earnedAt,
      );
}
