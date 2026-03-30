import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/evernote_theme.dart';

/// Header widget with menu, avatar, greeting, and notification bell
/// Matches Evernote's dark theme design with lime green accent
class NotesHeader extends StatelessWidget {
  final VoidCallback? onMenuTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onNotificationTap;
  final String? userName;
  final String? avatarUrl;
  final int notificationCount;

  const NotesHeader({
    super.key,
    this.onMenuTap,
    this.onProfileTap,
    this.onNotificationTap,
    this.userName,
    this.avatarUrl,
    this.notificationCount = 0,
  });

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 16,
        16,
        20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            EvernoteTheme.background,
            EvernoteTheme.background.withOpacity(0.95),
          ],
        ),
      ),
      child: Row(
        children: [
          // Hamburger menu button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onMenuTap?.call();
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: EvernoteTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: EvernoteTheme.border,
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.menu_rounded,
                size: 22,
                color: EvernoteTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Profile avatar
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onProfileTap?.call();
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: EvernoteTheme.primaryGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: EvernoteTheme.shadowSm,
              ),
              child: avatarUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildDefaultAvatar(),
                      ),
                    )
                  : _buildDefaultAvatar(),
            ),
          ),
          const SizedBox(width: 14),
          
          // Greeting text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting,
                  style: EvernoteTheme.bodySmall.copyWith(
                    color: EvernoteTheme.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  userName ?? 'Welcome back!',
                  style: EvernoteTheme.headlineSmall.copyWith(
                    color: EvernoteTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          
          // Notification bell
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onNotificationTap?.call();
            },
            child: Stack(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: EvernoteTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: EvernoteTheme.border,
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.notifications_outlined,
                    size: 22,
                    color: EvernoteTheme.textSecondary,
                  ),
                ),
                if (notificationCount > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: EvernoteTheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          notificationCount > 9 ? '9+' : '$notificationCount',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: EvernoteTheme.textOnPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Center(
      child: Text(
        (userName?.isNotEmpty == true ? userName![0] : 'U').toUpperCase(),
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: EvernoteTheme.textOnPrimary,
        ),
      ),
    );
  }
}
