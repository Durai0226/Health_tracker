import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/luna_theme.dart';
import '../models/luna_community.dart';
import 'luna_glass_card.dart';

/// Community post card widget for Luna Cycle
class LunaCommunityPostCard extends StatelessWidget {
  final LunaCommunityPost post;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onSave;
  final VoidCallback? onShare;

  const LunaCommunityPostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onLike,
    this.onComment,
    this.onSave,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return LunaGlassCard(
      onTap: onTap,
      margin: const EdgeInsets.symmetric(
        horizontal: LunaTheme.spacingLg,
        vertical: LunaTheme.spacingSm,
      ),
      padding: const EdgeInsets.all(LunaTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              // Avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: post.category.color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: post.isAnonymous
                      ? Icon(
                          Icons.person_outline,
                          color: post.category.color,
                          size: 20,
                        )
                      : Text(
                          post.displayName[0].toUpperCase(),
                          style: LunaTheme.titleMedium.copyWith(
                            color: post.category.color,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: LunaTheme.spacingMd),
              // Author info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          post.displayName,
                          style: LunaTheme.titleMedium.copyWith(
                            color: LunaTheme.getTextPrimary(context),
                          ),
                        ),
                        if (post.isVerified) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.verified,
                            color: LunaTheme.primaryPink,
                            size: 14,
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '${post.category.displayName} • ${post.timeAgo}',
                      style: LunaTheme.bodySmall.copyWith(
                        color: LunaTheme.getTextTertiary(context),
                      ),
                    ),
                  ],
                ),
              ),
              // Mood indicator
              if (post.mood != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: LunaTheme.spacingSm,
                    vertical: LunaTheme.spacingXs,
                  ),
                  decoration: BoxDecoration(
                    color: LunaTheme.primaryPinkSoft,
                    borderRadius: BorderRadius.circular(LunaTheme.radiusFull),
                  ),
                  child: Text(
                    post.mood!.emoji,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
            ],
          ),

          const SizedBox(height: LunaTheme.spacingMd),

          // Content
          Text(
            post.content,
            style: LunaTheme.bodyLarge.copyWith(
              color: LunaTheme.getTextPrimary(context),
            ),
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
          ),

          // Tags
          if (post.tags.isNotEmpty) ...[
            const SizedBox(height: LunaTheme.spacingMd),
            Wrap(
              spacing: LunaTheme.spacingSm,
              runSpacing: LunaTheme.spacingXs,
              children: post.tags.take(3).map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: LunaTheme.spacingSm,
                    vertical: LunaTheme.spacingXxs,
                  ),
                  decoration: BoxDecoration(
                    color: LunaTheme.primaryPink.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(LunaTheme.radiusSm),
                  ),
                  child: Text(
                    '#$tag',
                    style: LunaTheme.labelSmall.copyWith(
                      color: LunaTheme.primaryPink,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: LunaTheme.spacingMd),

          // Actions
          Row(
            children: [
              _ActionButton(
                icon: post.isLikedByUser
                    ? Icons.favorite
                    : Icons.favorite_outline,
                label: '${post.likesCount}',
                color: post.isLikedByUser ? LunaTheme.primaryPink : null,
                onTap: onLike,
              ),
              const SizedBox(width: LunaTheme.spacingLg),
              _ActionButton(
                icon: Icons.chat_bubble_outline,
                label: '${post.commentsCount}',
                onTap: onComment,
              ),
              const Spacer(),
              _ActionButton(
                icon: post.isSavedByUser
                    ? Icons.bookmark
                    : Icons.bookmark_outline,
                color: post.isSavedByUser ? LunaTheme.primaryPink : null,
                onTap: onSave,
              ),
              const SizedBox(width: LunaTheme.spacingSm),
              _ActionButton(
                icon: Icons.share_outlined,
                onTap: onShare,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final Color? color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    this.label,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final buttonColor = color ?? LunaTheme.getTextSecondary(context);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: buttonColor, size: 20),
          if (label != null) ...[
            const SizedBox(width: 4),
            Text(
              label!,
              style: LunaTheme.labelMedium.copyWith(color: buttonColor),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact post card for lists
class LunaCommunityPostCardCompact extends StatelessWidget {
  final LunaCommunityPost post;
  final VoidCallback? onTap;

  const LunaCommunityPostCardCompact({
    super.key,
    required this.post,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(LunaTheme.spacingMd),
        decoration: BoxDecoration(
          color: LunaTheme.getSurface(context),
          borderRadius: BorderRadius.circular(LunaTheme.radiusMd),
          border: Border.all(
            color: LunaTheme.getDivider(context),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category indicator
            Container(
              width: 4,
              height: 50,
              decoration: BoxDecoration(
                color: post.category.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: LunaTheme.spacingMd),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.content,
                    style: LunaTheme.bodyMedium.copyWith(
                      color: LunaTheme.getTextPrimary(context),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: LunaTheme.spacingXs),
                  Row(
                    children: [
                      Icon(
                        Icons.favorite,
                        size: 12,
                        color: LunaTheme.getTextTertiary(context),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${post.likesCount}',
                        style: LunaTheme.labelSmall.copyWith(
                          color: LunaTheme.getTextTertiary(context),
                        ),
                      ),
                      const SizedBox(width: LunaTheme.spacingMd),
                      Text(
                        post.timeAgo,
                        style: LunaTheme.labelSmall.copyWith(
                          color: LunaTheme.getTextTertiary(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Support group card
class LunaSupportGroupCard extends StatelessWidget {
  final LunaSupportGroup group;
  final VoidCallback? onTap;
  final VoidCallback? onJoin;
  final bool isJoined;

  const LunaSupportGroupCard({
    super.key,
    required this.group,
    this.onTap,
    this.onJoin,
    this.isJoined = false,
  });

  @override
  Widget build(BuildContext context) {
    return LunaGlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(LunaTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Group icon
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LunaTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(LunaTheme.radiusMd),
                ),
                child: const Center(
                  child: Icon(
                    Icons.people_outline,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: LunaTheme.spacingMd),
              // Group info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: LunaTheme.titleLarge.copyWith(
                        color: LunaTheme.getTextPrimary(context),
                      ),
                    ),
                    Text(
                      '${group.memberCount} members',
                      style: LunaTheme.bodySmall.copyWith(
                        color: LunaTheme.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              // Join button
              if (onJoin != null)
                _JoinButton(isJoined: isJoined, onTap: onJoin!),
            ],
          ),
          const SizedBox(height: LunaTheme.spacingMd),
          Text(
            group.description,
            style: LunaTheme.bodyMedium.copyWith(
              color: LunaTheme.getTextSecondary(context),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _JoinButton extends StatelessWidget {
  final bool isJoined;
  final VoidCallback onTap;

  const _JoinButton({
    required this.isJoined,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: LunaTheme.spacingMd,
          vertical: LunaTheme.spacingSm,
        ),
        decoration: BoxDecoration(
          color: isJoined
              ? LunaTheme.primaryPink.withOpacity(0.1)
              : LunaTheme.primaryPink,
          borderRadius: BorderRadius.circular(LunaTheme.radiusFull),
          border: isJoined
              ? Border.all(color: LunaTheme.primaryPink, width: 1)
              : null,
        ),
        child: Text(
          isJoined ? 'Joined' : 'Join',
          style: LunaTheme.labelMedium.copyWith(
            color: isJoined ? LunaTheme.primaryPink : Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Category filter chip
class LunaCategoryChip extends StatelessWidget {
  final LunaPostCategory category;
  final bool isSelected;
  final VoidCallback onTap;

  const LunaCategoryChip({
    super.key,
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: LunaTheme.animFast,
        padding: const EdgeInsets.symmetric(
          horizontal: LunaTheme.spacingMd,
          vertical: LunaTheme.spacingSm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? category.color : category.color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(LunaTheme.radiusFull),
          border: Border.all(
            color: category.color.withOpacity(isSelected ? 0 : 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              category.icon,
              size: 16,
              color: isSelected ? Colors.white : category.color,
            ),
            const SizedBox(width: LunaTheme.spacingXs),
            Text(
              category.displayName,
              style: LunaTheme.labelMedium.copyWith(
                color: isSelected ? Colors.white : category.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Create post FAB
class LunaCreatePostFAB extends StatelessWidget {
  final VoidCallback onTap;

  const LunaCreatePostFAB({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: LunaTheme.primaryGradient,
          shape: BoxShape.circle,
          boxShadow: LunaTheme.shadowColored(LunaTheme.primaryPink),
        ),
        child: const Icon(
          Icons.edit_outlined,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}
